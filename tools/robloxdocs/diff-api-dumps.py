#!/usr/bin/env python3
"""Member-level diff between two Roblox Full-API-Dump.json files.

roblox-api-monitor.sh historically compared class and enum COUNTS only. That cannot see
metadata changes on existing members -- and in 0.739 -> 0.740 that blind spot hid six
Security changes, one of which proved a shipped code example had never been executable.

Reports, with developer-visible changes triaged ahead of internal ones:
  * added / removed classes and enums
  * added / removed members
  * changed Security, Capabilities, Tags (Deprecated!, ReadOnly) and signatures
  * optional grep-back: which skill reference files mention each changed identifier

Usage:
    diff-api-dumps.py OLD.json NEW.json [--refs DIR] [--json OUT.json] [--quiet]
"""
import json, sys, os, re, collections

# Windows pipes default to a legacy code page (cp1252) that cannot encode emoji; without this a
# final "✅" print crashed split-api-dump.py AFTER it had written every file (found by CI).
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(errors="replace")
    except (AttributeError, ValueError):   # Python 3.6, or a stream that cannot be reconfigured
        pass

def load(p):
    with open(p, encoding='utf-8') as f:
        return json.load(f)

def norm_tags(x):
    out = set()
    for t in (x.get('Tags') or []):
        out.add(t if isinstance(t, str) else json.dumps(t, sort_keys=True))
    return out

def sec_pair(m):
    s = m.get('Security')
    return (s.get('Read'), s.get('Write')) if isinstance(s, dict) else (s, s)

def caps_pair(m):
    c = m.get('Capabilities') or {}
    if isinstance(c, dict):
        return tuple(sorted(c.get('Read') or ())), tuple(sorted(c.get('Write') or ()))
    return tuple(sorted(c)), tuple(sorted(c))

def sig(m):
    return json.dumps({k: m.get(k) for k in ('ValueType', 'ReturnType', 'Parameters')}, sort_keys=True)

def elevated(s):
    return s not in (None, 'None')

def developer_visible(entry):
    """Would a game developer notice this? Filters out RobloxScriptSecurity churn."""
    for key in ('security_before', 'security_after'):
        v = entry.get(key)
        if v and any(x in ('None', None) for x in (v if isinstance(v, tuple) else (v,))):
            return True
    if entry.get('kind') in ('class_removed', 'enum_removed', 'enum_item_removed'):
        return True
    if 'Deprecated' in str(entry.get('tags_gained', '')):
        return True
    if entry.get('security') in (None, 'None') or entry.get('security') == ('None', 'None'):
        return True
    return False


def diff(old, new):
    oc = {c['Name']: c for c in old['Classes']}
    nc = {c['Name']: c for c in new['Classes']}
    oe = {e['Name']: e for e in old['Enums']}
    ne = {e['Name']: e for e in new['Enums']}
    ev = []

    for n in sorted(set(nc) - set(oc)):
        ev.append(dict(kind='class_added', target=n,
                       detail=f"super={nc[n].get('Superclass')} members={len(nc[n].get('Members', []))}"))
    for n in sorted(set(oc) - set(nc)):
        ev.append(dict(kind='class_removed', target=n, detail='REMOVED'))

    for cn in sorted(set(oc) & set(nc)):
        om = {m['Name']: m for m in oc[cn].get('Members', [])}
        nm = {m['Name']: m for m in nc[cn].get('Members', [])}
        for k in sorted(set(nm) - set(om)):
            m = nm[k]
            r, w = sec_pair(m)
            ev.append(dict(kind='member_added', target=f'{cn}.{k}',
                           detail=f"{m.get('MemberType')} sec={r}/{w} tags={sorted(norm_tags(m))}",
                           security=(r, w)))
        for k in sorted(set(om) - set(nm)):
            m = om[k]
            r, w = sec_pair(m)
            ev.append(dict(kind='member_removed', target=f'{cn}.{k}',
                           detail=f"was {m.get('MemberType')} sec={r}/{w}", security=(r, w)))
        for k in sorted(set(om) & set(nm)):
            a, b = om[k], nm[k]
            sa, sb = sec_pair(a), sec_pair(b)
            ca, cb = caps_pair(a), caps_pair(b)
            ta, tb = norm_tags(a), norm_tags(b)
            if sa != sb:
                ev.append(dict(kind='security_changed', target=f'{cn}.{k}',
                               detail=f'Security read/write {sa[0]}/{sa[1]} -> {sb[0]}/{sb[1]}',
                               security_before=sa, security_after=sb))
            if ca != cb:
                ev.append(dict(kind='capabilities_changed', target=f'{cn}.{k}',
                               detail=f'Capabilities read/write {ca} -> {cb}',
                               security=sec_pair(b)))
            if ta != tb:
                ev.append(dict(kind='tags_changed', target=f'{cn}.{k}',
                               detail=f'tags +{sorted(tb - ta)} -{sorted(ta - tb)}',
                               tags_gained=sorted(tb - ta), security=sec_pair(b)))
            if sig(a) != sig(b):
                ev.append(dict(kind='signature_changed', target=f'{cn}.{k}',
                               detail='signature changed', security=sec_pair(b)))

    for n in sorted(set(ne) - set(oe)):
        ev.append(dict(kind='enum_added', target=f'Enum.{n}',
                       detail=str([i['Name'] for i in ne[n].get('Items', [])])))
    for n in sorted(set(oe) - set(ne)):
        ev.append(dict(kind='enum_removed', target=f'Enum.{n}', detail='REMOVED'))
    for n in sorted(set(oe) & set(ne)):
        a = {i['Name'] for i in oe[n].get('Items', [])}
        b = {i['Name'] for i in ne[n].get('Items', [])}
        if a != b:
            if b - a:
                ev.append(dict(kind='enum_item_added', target=f'Enum.{n}', detail=f'+{sorted(b - a)}'))
            if a - b:
                ev.append(dict(kind='enum_item_removed', target=f'Enum.{n}', detail=f'-{sorted(a - b)}'))
    return ev


def grep_back(events, refdir):
    """Which reference files mention each changed identifier? This is the step that closes the
    loop between 'the API changed' and 'our docs talk about it'. Pure Python, so it also works
    on Windows where there is no grep."""
    if not refdir or not os.path.isdir(refdir):
        return
    texts = {}
    for name in sorted(os.listdir(refdir)):
        if name.endswith('.md'):
            with open(os.path.join(refdir, name), encoding='utf-8', errors='replace') as f:
                texts[name] = f.read()
    for e in events:
        leaf = e['target'].split('.')[-1]
        if len(leaf) < 4:
            continue
        hits = [name for name, text in texts.items() if leaf in text]
        if hits:
            e['mentioned_in'] = hits


def main():
    argv = sys.argv[1:]
    refdir = jsonout = None
    quiet = False
    rest = []
    i = 0
    while i < len(argv):
        if argv[i] == '--refs':
            refdir = argv[i + 1]; i += 2; continue
        if argv[i] == '--json':
            jsonout = argv[i + 1]; i += 2; continue
        if argv[i] == '--quiet':
            quiet = True; i += 1; continue
        rest.append(argv[i]); i += 1
    if len(rest) != 2:
        sys.exit(__doc__)

    oldp, newp = rest
    events = diff(load(oldp), load(newp))
    grep_back(events, refdir)

    vis = [e for e in events if developer_visible(e)]
    internal = [e for e in events if not developer_visible(e)]
    touching = [e for e in events if e.get('mentioned_in')]

    def label(p):
        return os.path.basename(p).replace('-Full-API-Dump.json', '')

    if not quiet:
        print(f"API diff {label(oldp)} -> {label(newp)}")
        print(f"  {len(events)} changes total: {len(vis)} developer-visible, {len(internal)} internal\n")

        print("=" * 78)
        print("DEVELOPER-VISIBLE CHANGES — review every one of these")
        print("=" * 78)
        if not vis:
            print("  none")
        for e in sorted(vis, key=lambda x: (x['kind'], x['target'])):
            mark = '  <-- MENTIONED IN ' + ', '.join(e['mentioned_in']) if e.get('mentioned_in') else ''
            print(f"  [{e['kind']:<20}] {e['target']:<48} {e['detail']}{mark}")

        print()
        print("=" * 78)
        print("CHANGES TOUCHING DOCUMENTED IDENTIFIERS — these need a doc edit")
        print("=" * 78)
        if not touching:
            print("  none")
        for e in sorted(touching, key=lambda x: x['target']):
            print(f"  {e['target']:<48} {', '.join(e['mentioned_in'])}")
            print(f"      {e['kind']}: {e['detail']}")

        print()
        print(f"(internal / RobloxScriptSecurity-only changes suppressed: {len(internal)}; "
              f"use --json to see everything)")

    if jsonout:
        os.makedirs(os.path.dirname(jsonout), exist_ok=True)
        with open(jsonout, 'w', encoding='utf-8') as f:
            json.dump(dict(old=label(oldp), new=label(newp), total=len(events),
                           developer_visible=len(vis), events=events), f, indent=2)
        if not quiet:
            print(f"\nFull machine-readable diff: {jsonout}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
