#!/usr/bin/env python3
"""Check the claims register (tools/skill-test/claims.json) against the skill's text.

Usage:
    check_claims.py [--dump PATH] [--seed] [--report PATH] [--strict]

The register lists every factual claim the skill makes that a reader could act on wrongly: what
it says (`quote`, an exact substring of the line in `file`), and how it was verified:

    status   studio      run in Roblox Studio (a playtest Script or execute_luau), see `evidence`
             docs        stated by official documentation (create.roblox.com / Roblox/creator-docs)
             dump        read from the API dump (existence, security, tags, capabilities)
             source      read from Luau / Roblox source, release notes or published flags
             advice      an instruction or recommendation, not a statement of fact (nothing to verify)
             unverified  not verified yet; the text must not present it as tested
             false       verified wrong and fixed: `quote` is the OLD wrong text, and it must NOT
                         appear in `file` again (a regression guard; see `evidence` for the test)

This script:
  * reports a claim as STALE when its quote is no longer in its file (the text changed: re-verify
    it and update the quote, or delete the entry if the claim is gone);
  * finds the HIGH-RISK lines (numbers and limits, versions, "cannot / only / not enabled /
    deprecated ...") that no claim covers, and with --seed adds them as `unverified`;
  * checks every `Class.Member` / `Class:Method()` named in prose against the API dump (it exists,
    or is listed in the register's `api_not_members` with why: a removed API the text documents as
    removed, a path to a child; deprecated and RobloxScriptSecurity members are counted, the API
    audit decides if that is a defect);
  * prints counts per file and status, and with --report writes a Markdown view (docs/claims.md).

With --strict, exit 1 on any stale claim, any uncovered high-risk line, or any prose API mention
that does not exist in the dump.
"""
import glob, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
REGISTER = os.path.join(HERE, 'claims.json')
DEFAULT_DUMP = os.path.expanduser('~/RobloxDocs/RobloxAPI/dumps/latest.json')
STATUSES = ('studio', 'docs', 'dump', 'source', 'advice', 'unverified', 'false')

NEGATIVE = re.compile(r"\b(cannot|can't|can not|not enabled|not available|only|never|does not|doesn't|"
                      r"is not|isn't|must not|no longer|removed|deprecated|not supported|fails?|errors?|"
                      r"rejected|PluginOrOpenCloud|NotScriptable)\b", re.I)
NUMBER = re.compile(r"\b\d+(\.\d+)?\s*(ms|s|seconds?|minutes?|MB|KB|KiB|MiB|bytes?|requests?|per|×|x|%|"
                    r"studs|characters?|chars|calls?|players?|items?|entries|Hz|fps)\b|\b0\.\d{3}\b|\b20\d\d\b", re.I)
API = re.compile(r"`([A-Z]\w+)([.:])(\w+)(?:\(\))?`")


def files():
    return ['SKILL.md'] + sorted(os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, 'references', '*.md')))


def prose_lines(rel):
    """(line number, text) for every non-code, non-blank, non-heading line of a file."""
    out, in_code = [], False
    with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
        for n, line in enumerate(f, 1):
            s = line.strip()
            if s.startswith('```'):
                in_code = not in_code
                continue
            if in_code or not s or s.startswith('#') or s.startswith('<!--') or set(s) <= set('|-: '):
                continue
            out.append((n, line.rstrip('\n')))
    return out


def norm(s):
    return re.sub(r'\s+', ' ', s).strip()


def quote_of(line):
    """The part of a line a seeded claim anchors to: the line without list / quote / table markup."""
    return norm(re.sub(r'^\s*(?:[-*>]|\d+\.)\s+', '', line).strip('| '))


def load_dump(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as f:
        d = json.load(f)
    members, supers = {}, {}
    for c in d['Classes']:
        supers[c['Name']] = c.get('Superclass')
        for m in c['Members']:
            members[(c['Name'], m['Name'])] = m
    enums = {e['Name']: {i['Name'] for i in e['Items']} for e in d['Enums']}
    return members, supers, enums


def find_member(dump, cls, name):
    members, supers, _ = dump
    while cls:
        if (cls, name) in members:
            return members[(cls, name)]
        cls = supers.get(cls)
    return None


def main(argv):
    opt = lambda k, d=None: argv[argv.index(k) + 1] if k in argv else d
    with open(REGISTER, encoding='utf-8') as f:
        register = json.load(f)
    claims = register['claims']
    text = {rel: prose_lines(rel) for rel in files()}
    joined = {rel: norm(' '.join(t for _, t in lines)) for rel, lines in text.items()}
    raw = {}
    for rel in text:
        with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
            raw[rel] = norm(f.read())

    problems = []
    ids = set()
    for c in claims:
        if c['id'] in ids:
            problems.append(f"duplicate id {c['id']}")
        ids.add(c['id'])
        if c['status'] not in STATUSES:
            problems.append(f"{c['id']}: unknown status {c['status']!r}")
        if c['status'] not in ('unverified', 'advice') and not c.get('evidence'):
            problems.append(f"{c['id']}: status {c['status']} without evidence")
        if c['status'] == 'false':
            if c['file'] in raw and norm(c['quote']) in raw[c['file']]:
                problems.append(f"REGRESSION {c['id']} ({c['file']}): text verified wrong is back: {c['quote'][:90]!r}")
        elif c['file'] not in raw or norm(c['quote']) not in raw[c['file']]:
            problems.append(f"STALE {c['id']} ({c['file']}): quote no longer in the text: {c['quote'][:90]!r}")

    # High-risk lines no claim covers.
    covered = {}
    for c in claims:
        if c['status'] != 'false':
            covered.setdefault(c['file'], []).append(norm(c['quote']))
    uncovered = []
    for rel, lines in text.items():
        for n, line in lines:
            if not (NEGATIVE.search(line) or NUMBER.search(line)):
                continue
            nl = norm(line)
            if not any(q and q in nl for q in covered.get(rel, [])):
                uncovered.append((rel, n, line))

    if '--seed' in argv and uncovered:
        per_file = {}
        for c in claims:
            per_file[c['file']] = per_file.get(c['file'], 0) + 1
        for rel, n, line in uncovered:
            stem = os.path.splitext(os.path.basename(rel))[0]
            per_file[rel] = per_file.get(rel, 0) + 1
            cid = f'{stem}-{per_file[rel]:03d}'
            while cid in ids:
                per_file[rel] += 1
                cid = f'{stem}-{per_file[rel]:03d}'
            ids.add(cid)
            claims.append(dict(id=cid, file=rel, quote=quote_of(line), status='unverified',
                               kind='negative' if NEGATIVE.search(line) else 'number',
                               source='', evidence='', checked=''))
        with open(REGISTER, 'w', encoding='utf-8') as f:
            json.dump(register, f, indent=1, ensure_ascii=False)
            f.write('\n')
        print(f'seeded {len(uncovered)} high-risk lines as unverified')
        uncovered = []

    # Prose API mentions against the dump.
    dump = load_dump(opt('--dump', DEFAULT_DUMP))
    api_ok, api_flag, api_missing = 0, [], []
    if dump:
        seen = set()
        for rel, lines in text.items():
            for n, line in lines:
                for cls, sep, name in API.findall(line):
                    if (rel, cls, name) in seen:
                        continue
                    seen.add((rel, cls, name))
                    if cls == 'Enum' or cls in dump[2]:
                        continue  # Enum.X / enum names: the API audit checks them
                    if cls not in dump[1]:
                        continue  # not a class name (a module, a type, a library)
                    m = find_member(dump, cls, name)
                    if not m and f'{cls}{sep}{name}' in register.get('api_not_members', {}):
                        continue
                    if not m:
                        api_missing.append(f'{rel}:{n} {cls}{sep}{name} is not a member')
                        continue
                    tags = [t for t in (m.get('Tags') or []) if isinstance(t, str)]
                    sec = m.get('Security')
                    sec = sec if isinstance(sec, str) else (sec or {}).get('Read')
                    if 'Deprecated' in tags or sec not in (None, 'None'):
                        api_flag.append(f'{rel}:{n} {cls}{sep}{name} [{", ".join(tags + ([sec] if sec not in (None, "None") else []))}]')
                    else:
                        api_ok += 1

    by_status = {s: 0 for s in STATUSES}
    by_file = {}
    for c in claims:
        by_status[c['status']] += 1
        row = by_file.setdefault(c['file'], {s: 0 for s in STATUSES})
        row[c['status']] += 1

    for p in problems:
        print('  ' + p)
    for rel, n, line in uncovered[:40]:
        print(f'  UNCOVERED {rel}:{n}: {norm(line)[:110]}')
    if len(uncovered) > 40:
        print(f'  ... and {len(uncovered) - 40} more uncovered high-risk lines')
    for m in api_missing:
        print('  API MISSING ' + m)
    if dump is None:
        print('  (no API dump: prose API mentions not checked; pass --dump)')
    summary = ' '.join(f'{s}={n}' for s, n in by_status.items())
    print(f'claims: {len(claims)} ({summary}); stale/invalid={len(problems)}; uncovered high-risk lines={len(uncovered)}')
    if dump:
        print(f'prose API mentions: {api_ok} plain, {len(api_flag)} deprecated/elevated (audit decides), {len(api_missing)} missing')

    if opt('--report'):
        out = ['# Claims register', '',
               '[← README](../README.md) · generated by `tools/skill-test/check_claims.py --report`; '
               'edit `tools/skill-test/claims.json`, not this file.', '',
               'Every factual claim a reader could act on wrongly, with how it was verified. '
               '**studio**: run in Roblox Studio; **docs**: official documentation; **dump**: the API dump; '
               '**source**: Luau/Roblox source, release notes or published flags; **advice**: a recommendation, '
               'not a fact; **unverified**: not yet; '
               '**false**: verified wrong and fixed in the text.', '',
               '| File | ' + ' | '.join(STATUSES) + ' |', '|---|' + '---|' * len(STATUSES)]
        for rel in files():
            row = by_file.get(rel, {s: 0 for s in STATUSES})
            out.append(f'| `{rel}` | ' + ' | '.join(str(row[s]) for s in STATUSES) + ' |')
        out.append(f'| **total** | ' + ' | '.join(f'**{by_status[s]}**' for s in STATUSES) + ' |')
        out += ['', '## Verified claims', '', '| Claim | Status | Evidence |', '|---|---|---|']
        for c in claims:
            if c['status'] in ('unverified', 'advice'):
                continue
            q = c['quote'].replace('|', '\\|')
            ev = (c.get('evidence') or '').replace('|', '\\|')
            src = f" ({c['source']})" if c.get('source') else ''
            out.append(f"| `{c['file']}`: {q[:160]} | {c['status']} | {ev}{src} |")
        with open(os.path.join(ROOT, opt('--report')), 'w', encoding='utf-8') as f:
            f.write('\n'.join(out) + '\n')

    bad = problems or uncovered or api_missing
    return 1 if (bad and '--strict' in argv) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
