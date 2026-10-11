#!/usr/bin/env python3
"""Type-check and lint every Luau block of the skill with luau-lsp, the way Studio's --!strict would.

Usage:
    run_static.py OUT_DIR [--luau-lsp PATH] [--defs PATH] [--strict]

Expects OUT_DIR from extract_blocks.py. Downloads the current Roblox definitions (security level
None, i.e. what a game Script may touch) into OUT_DIR/defs if --defs is not given, runs
`luau-lsp analyze` with the New Type Solver, and writes OUT_DIR/static.json:

    { "<block id>": { "fragment": bool, "findings": [ {line, col, code, message, allowed} ] } }

A block is a FRAGMENT when it references a global or a require path that only exists in the
reader's project; fragments still get every other check. A finding is ALLOWED when the block
declares it with a directive (see extract_blocks.py), e.g. a "Legacy" example that must use
`wait()`, or the `if local` beta syntax. With --strict, exit 1 if any finding is not allowed.

A block with a prelude or an expectation (see compose.py) is analysed as composed, so the
reader's names have real types; a finding in a prelude or expectation is a defect of the test
suite and is reported against that file. A block whose prelude still leaves an unknown name is a
finding too: the prelude is incomplete.
"""
import json, os, re, shutil, subprocess, sys, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import compose  # noqa: E402

DEFS_URL = 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau'
LINE = re.compile(r'(?:blocks|strict)/(?P<id>[^/]+?)\.luau\((?P<line>\d+),(?P<col>\d+)\): (?P<code>\w+): (?P<msg>.*)$')
# Never defects: they describe the reader's project, or are style lints that do not change behaviour
# in a documentation snippet.
FRAGMENT = re.compile(r"^Unknown global '|^Unknown require")
NOISE = {'LocalUnused', 'FunctionUnused', 'ImportUnused', 'SameLineStatement', 'LocalShadow'}
# What each directive excuses.
ALLOW = {
    'legacy':        re.compile(r'^DeprecatedApi'),
    'beta-syntax':   re.compile(r'^SyntaxError'),
    'placeholder':   re.compile(r"Invalid service name|Unknown type"),
    'antipattern':   re.compile(r'^TypeError'),   # a "❌ do not do this" example, kept to be recognised
    'project-tree':  re.compile(r"^TypeError: Key '\w+' not found in external type '(Workspace|ReplicatedStorage|ServerStorage|ServerScriptService|StarterGui)'"),
}


def find_luau_lsp(explicit):
    cands = [explicit] if explicit else []
    cands += [shutil.which('luau-lsp') or '']
    home = os.path.expanduser('~')
    for base in (f'{home}/.rokit/tool-storage/johnnymorganz/luau-lsp', f'{home}/.aftman/tool-storage/JohnnyMorganz/luau-lsp'):
        if os.path.isdir(base):
            for v in sorted(os.listdir(base), reverse=True):
                cands.append(os.path.join(base, v, 'luau-lsp'))
    for c in cands:
        if c and os.path.isfile(c) and os.access(c, os.X_OK):
            try:
                r = subprocess.run([c, 'analyze', '--help'], capture_output=True, text=True, timeout=30)
                if 'luau-analyze' in (r.stdout + r.stderr):
                    return c
            except (OSError, subprocess.TimeoutExpired):
                pass
    sys.exit('run_static: luau-lsp not found (install with rokit/aftman, or pass --luau-lsp PATH)')


def main(argv):
    if not argv:
        sys.exit(__doc__)
    out = argv[0]
    opt = lambda k: argv[argv.index(k) + 1] if k in argv else None
    lsp = find_luau_lsp(opt('--luau-lsp'))
    defs = {}
    for level in ('None', 'PluginSecurity'):
        path = opt('--defs') if (level == 'None' and opt('--defs')) else os.path.join(out, 'defs', f'globalTypes.{level}.d.luau')
        if not os.path.exists(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            urllib.request.urlretrieve(DEFS_URL.replace('None', level), path)
        defs[level] = os.path.abspath(path)
    manifest = json.load(open(os.path.join(out, 'manifest.json'), encoding='utf-8'))
    directives = {b['id']: b['directives'] for b in manifest}
    # Analyse every block in strict mode, the skill's standard. A block that does not start with a
    # mode directive gets "--!strict" prepended: nonstrict mode does not report unknown globals, so a
    # fragment would pass as complete. compose() also adds any prelude / expectation.
    os.makedirs(os.path.join(out, 'strict'), exist_ok=True)
    comp, lines = {}, {}
    for b in manifest:
        src = open(os.path.join(out, 'blocks', b['id'] + '.luau'), encoding='utf-8').read()
        comp[b['id']] = c = compose(src, directives[b['id']])
        directives[b['id']] = c.directives
        lines[b['id']] = src.split('\n')
        with open(os.path.join(out, 'strict', b['id'] + '.luau'), 'w', encoding='utf-8') as f:
            f.write(c.text)
    # Plugin blocks are checked against what a plugin may touch, everything else against what a
    # game Script may touch, so a PluginSecurity call in a game example is a finding.
    groups = {'PluginSecurity': [b['id'] for b in manifest if 'plugin' in directives[b['id']]]}
    groups['None'] = [b['id'] for b in manifest if b['id'] not in groups['PluginSecurity']]
    output = ''
    for level, ids in groups.items():
        if not ids:
            continue
        proc = subprocess.run([lsp, 'analyze', '--no-flags-enabled', '--flag:LuauSolverV2=true',
                               '--platform', 'roblox', '--defs', f'@roblox={defs[level]}',
                               *[os.path.join('strict', i + '.luau') for i in ids]],
                              cwd=out, capture_output=True, text=True, encoding='utf-8', errors='replace')
        output += proc.stdout + proc.stderr
    report = {b['id']: dict(file=b['file'], line=b['line'], fragment=False, missing=[], findings=[],
                            composed=bool({'prelude', 'expect'} & set(directives[b['id']])))
              for b in manifest}
    pending = []
    for raw in output.splitlines():
        m = LINE.search(raw.replace('\\', '/'))
        if not m:
            continue
        bid, code, msg = m['id'], m['code'], m['msg']
        if bid not in report or code in NOISE:
            continue
        c, cline = comp[bid], int(m['line'])
        bline = c.block_line(cline)
        if bline is None:
            # A line of a prelude, an expectation or the wrapper: the test suite's own defect.
            pending.append((bid, None, int(m['col']), code, f'[{c.label(cline)}] {msg}'))
            continue
        if FRAGMENT.search(msg):
            report[bid]['fragment'] = True
            name = re.search(r"Unknown global '(\w+)'|Unknown require: (.*)$", msg)
            report[bid]['missing'].append(name.group(1) or 'require:' + name.group(2).strip())
            if 'prelude' in directives[bid] and name.group(1):
                pending.append((bid, bline, int(m['col']), code, f'{msg} (not supplied by its prelude)'))
            continue
        pending.append((bid, bline, int(m['col']), code, msg))
    for bid, line, col, code, msg in pending:
        text = f'{code}: {msg}'
        if line is None:
            report[bid]['findings'].append(dict(line=0, col=col, code=code, message=msg, allowed=False))
            continue
        allowed = any(k in directives[bid] and rx.search(text) for k, rx in ALLOW.items())
        # In a fragment, an error on a line that uses one of the reader's own names is a knock-on
        # effect of that name having no type here, not a defect of the example.
        src_line = lines[bid][line - 1] if 0 < line <= len(lines[bid]) else ''
        if not allowed and 'not supplied by its prelude' not in msg and any(re.search(rf'\b{re.escape(n)}\b', src_line)
                               for n in report[bid]['missing'] if not n.startswith('require:')):
            allowed = True
        report[bid]['findings'].append(dict(line=line, col=col, code=code, message=msg, allowed=allowed))
    with open(os.path.join(out, 'static.json'), 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=1)

    bad = [(bid, x) for bid, r in report.items() for x in r['findings'] if not x['allowed']]
    # Unresolved: a name from the reader's project that no prelude supplies (a require of a module
    # the test project provides, declared with `requires`, does not count).
    frag = sum(any(not n.startswith('require:') for n in r['missing']) for r in report.values())
    composed = sum(r['composed'] for r in report.values())
    for bid, x in bad:
        r = report[bid]
        where = f"{r['file']}:{r['line'] + x['line'] - 1}" if x['line'] else f"{r['file']}:{r['line']} (test suite)"
        print(f"  {where}  [{bid}] {x['code']}: {x['message']}")
    print(f'static: {len(report)} blocks ({composed} with prelude/expect, {frag} with unresolved names), '
          f'{len(bad)} unexplained findings')
    return 1 if (bad and '--strict' in argv) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
