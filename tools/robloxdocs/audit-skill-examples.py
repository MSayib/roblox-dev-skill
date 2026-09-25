#!/usr/bin/env python3
"""Audit Luau code examples in a skill's reference markdown against the Roblox API dump.

Catches the class of defect that shipped undetected in roblox-dev-skill for three months:
a code example that cannot execute under the security model the docs claim.

Usage:
    audit-skill-examples.py [REFERENCE_DIR] [--dump PATH] [--quiet]

Exit code 1 if any DEFECT is found (sections A/C/D/E), 0 otherwise.
Section B is informational and never fails the run.

Heuristics, and why they are safe:
  * Luau types are not inferred, so a member name is resolved across ALL classes. A name is only
    reported as elevated when EVERY class defining it requires elevated access -- so a collision
    with an ordinary member can never produce a false report.
  * Receivers assigned from require() and a small allowlist of community libraries are skipped,
    because DataStore2:Get() is not an engine call even though `Get` exists in the engine.
  * Section E checks METHOD CALLS only. Indexing a service for a developer-created child
    (ReplicatedStorage.Remotes) is ordinary Luau and would otherwise be endless noise.
"""
import json, re, glob, os, sys, collections

# Windows pipes default to a legacy code page (cp1252) that cannot encode emoji; without this a
# final "✅" print crashed split-api-dump.py AFTER it had written every file (found by CI).
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(errors="replace")
    except (AttributeError, ValueError):   # Python 3.6, or a stream that cannot be reconfigured
        pass

DEFAULT_DUMP = os.path.expanduser('~/RobloxDocs/RobloxAPI/dumps/latest.json')

# Community libraries whose method names may collide with engine member names.
THIRD_PARTY = {
    'DataStore2', 'ProfileStore', 'ProfileService', 'Profile', 'Promise', 'Signal', 'Janitor',
    'Trove', 'Maid', 'Knit', 'Roact', 'Fusion', 'Matter', 'Net', 'oldStore', 'store',
}

def parse_args(argv):
    refdir, dump, quiet = 'references', DEFAULT_DUMP, False
    rest = []
    i = 0
    while i < len(argv):
        if argv[i] == '--dump':
            dump = argv[i + 1]; i += 2; continue
        if argv[i] == '--quiet':
            quiet = True; i += 1; continue
        rest.append(argv[i]); i += 1
    if rest:
        refdir = rest[0]
    return refdir, dump, quiet


def load_dump(path):
    if not os.path.exists(path):
        sys.exit(f"audit: API dump not found at {path}\n"
                 f"       run ~/RobloxDocs/scripts/roblox-api-monitor.sh first")
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def build_index(dump):
    classes = {c['Name']: c for c in dump['Classes']}
    enums = {e['Name']: {i['Name'] for i in e.get('Items', [])} for e in dump['Enums']}
    members = collections.defaultdict(list)
    for c in dump['Classes']:
        for m in c.get('Members', []):
            sec = m.get('Security')
            rs, ws = (sec.get('Read'), sec.get('Write')) if isinstance(sec, dict) else (sec, sec)
            caps = m.get('Capabilities') or {}
            if isinstance(caps, dict):
                rcaps, wcaps = tuple(caps.get('Read') or ()), tuple(caps.get('Write') or ())
            else:
                rcaps = wcaps = tuple(caps)
            members[m['Name']].append(
                dict(cls=c['Name'], kind=m.get('MemberType'), read=rs, write=ws,
                     rcaps=rcaps, wcaps=wcaps))
    return classes, enums, members


def inherited_members(classes, cn):
    out, seen = set(), set()
    while cn in classes and cn not in seen:
        seen.add(cn)
        out |= {m['Name'] for m in classes[cn].get('Members', [])}
        cn = classes[cn].get('Superclass')
    return out


CODE     = re.compile(r'```(?:luau|lua)\n(.*?)```', re.S)
WRITE    = re.compile(r'(?<![\w.])([A-Za-z_][\w.\[\]"\']*)\.([A-Z]\w+)\s*=(?!=)')
CALL     = re.compile(r'(?<![\w.]):?([A-Za-z_][\w.\[\]"\']*):([A-Z]\w+)\s*\(')
GETSVC   = re.compile(r'GetService\(\s*["\'](\w+)["\']\s*\)')
INSTNEW  = re.compile(r'Instance\.new\(\s*["\'](\w+)["\']')
ENUMREF  = re.compile(r'\bEnum\.(\w+)\.(\w+)')
# bind ONLY when GetService(...) ends the expression -- `= game:GetService("Players").LocalPlayer`
# must not bind the variable to Players.
BIND     = re.compile(r'local\s+(\w+)\s*(?::\s*[\w.]+)?\s*=\s*game:GetService\(\s*["\'](\w+)["\']\s*\)\s*(?![.\w:])')
REQUIRED = re.compile(r'local\s+(\w+)\s*(?::\s*[\w.]+)?\s*=\s*require\s*\(')
PLUGINCTX = re.compile(r'\bplugin\b|PluginSecurity|command bar|:GetMouse\(|CoreGui|PluginGui|Toolbar|PluginAction', re.I)


def elevated(s):
    return s not in (None, 'None')


def audit(refdir, classes, enums, members):
    A, B, C, D, E = [], [], [], [], []
    memcache = {}
    any_member = set(members)

    for path in sorted(glob.glob(os.path.join(refdir, '*.md'))):
        fname = os.path.basename(path)
        with open(path, encoding='utf-8') as f:
            text = f.read()
        for block in CODE.findall(text):
            plugin_ok = bool(PLUGINCTX.search(block)) or fname == 'studio-plugins-and-limits.md'
            skip = set(THIRD_PARTY) | set(REQUIRED.findall(block))

            # ---- A: elevated security -------------------------------------------------
            for kind, rx, field in (('write', WRITE, 'write'), ('call', CALL, 'read')):
                for recv, name in rx.findall(block):
                    if recv.split('.')[0].split('[')[0] in skip:
                        continue
                    defs = members.get(name)
                    if not defs or not all(elevated(d[field]) for d in defs):
                        continue
                    A.append(dict(file=fname, kind=kind, recv=recv, member=name,
                                  sec=sorted({str(d[field]) for d in defs}),
                                  classes=sorted({d['cls'] for d in defs})[:4],
                                  expected=plugin_ok))

            # ---- B: capability-gated writes (informational) ---------------------------
            for recv, name in WRITE.findall(block):
                if recv.split('.')[0].split('[')[0] in skip:
                    continue
                defs = members.get(name)
                if not defs:
                    continue
                gated = [d for d in defs if not elevated(d['write']) and d['wcaps']]
                plain = [d for d in defs if not elevated(d['write']) and not d['wcaps']]
                if gated and not plain:
                    B.append(dict(file=fname, recv=recv, member=name,
                                  caps=sorted({c for d in gated for c in d['wcaps']}),
                                  classes=sorted({d['cls'] for d in gated})[:4]))

            # ---- C: unknown class ----------------------------------------------------
            for cn in set(GETSVC.findall(block)) | set(INSTNEW.findall(block)):
                if cn not in classes:
                    C.append(dict(file=fname, cls=cn))

            # ---- D: unknown enum / item ----------------------------------------------
            for en, item in set(ENUMREF.findall(block)):
                if en not in enums:
                    D.append(dict(file=fname, ref=f'Enum.{en}', why='enum does not exist'))
                elif item not in enums[en]:
                    near = sorted(enums[en])[:6]
                    D.append(dict(file=fname, ref=f'Enum.{en}.{item}',
                                  why=f'not an item; valid: {", ".join(near)}'))

            # ---- E: method call not on the resolved service class ---------------------
            for var, cls in BIND.findall(block):
                if cls not in classes:
                    continue
                if cls not in memcache:
                    memcache[cls] = inherited_members(classes, cls)
                for recv, name in CALL.findall(block):
                    if recv != var:
                        continue
                    if name not in memcache[cls]:
                        E.append(dict(file=fname, cls=cls, var=var, member=name,
                                      why='exists on another class' if name in any_member
                                          else 'NOWHERE in the API'))
    return A, B, C, D, E


def main():
    refdir, dumppath, quiet = parse_args(sys.argv[1:])
    dump = load_dump(dumppath)
    classes, enums, members = build_index(dump)
    A, B, C, D, E = audit(refdir, classes, enums, members)

    ver = os.path.basename(os.path.realpath(dumppath)).replace('-Full-API-Dump.json', '')
    unexpected_A = [f for f in A if not f['expected']]

    def head(t):
        print(f"\n{'=' * 78}\n{t}\n{'=' * 78}")

    print(f"Auditing {refdir}/*.md against API dump {ver}")

    head("A. ELEVATED-SECURITY MEMBERS IN EXAMPLES (not reachable from a plain Script)")
    if not A:
        print("  none")
    for f in sorted({(x['file'], x['kind'], x['recv'], x['member'],
                      '/'.join(x['sec']), tuple(x['classes']), x['expected']) for x in A}):
        fl, kind, recv, mem, sec, cls, exp = f
        tag = "[plugin context — expected]" if exp else "*** DEFECT ***"
        print(f"  {fl:<32} {kind:<5} {recv}.{mem:<26} {sec:<22} {list(cls)} {tag}")

    head("B. CAPABILITY-GATED WRITES — informational, only bites inside a sandboxed container")
    if not B:
        print("  none")
    for f in sorted({(x['file'], x['recv'], x['member'], tuple(x['caps'])) for x in B}):
        print(f"  {f[0]:<32} {f[1]}.{f[2]:<26} needs capability {list(f[3])}")

    head("C. UNKNOWN CLASS in GetService() / Instance.new()")
    print("  none" if not C else "")
    for f in sorted({(x['file'], x['cls']) for x in C}):
        print(f"  {f[0]:<32} {f[1]:<28} *** DEFECT: class not in the dump ***")

    head("D. UNKNOWN ENUM or ENUM ITEM")
    print("  none" if not D else "")
    for f in sorted({(x['file'], x['ref'], x['why']) for x in D}):
        print(f"  {f[0]:<32} {f[1]:<36} *** DEFECT: {f[2]} ***")

    head("E. METHOD CALL NOT ON THE RESOLVED SERVICE CLASS")
    print("  none" if not E else "")
    for f in sorted({(x['file'], x['cls'], x['var'], x['member'], x['why']) for x in E}):
        print(f"  {f[0]:<32} {f[1]}:{f[3]:<24} (as `{f[2]}`) *** DEFECT: {f[4]} ***")

    defects = len(unexpected_A) + len(C) + len(D) + len(E)
    print(f"\n{'-' * 78}")
    print(f"DEFECTS: {defects}   (informational capability notes: {len({(x['file'], x['member']) for x in B})})")
    return 1 if defects else 0


if __name__ == '__main__':
    sys.exit(main())
