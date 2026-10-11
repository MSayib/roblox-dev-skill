#!/usr/bin/env python3
"""Turn the extracted blocks into Rojo-syncable files for the Studio runtime harness.

Usage:
    build_suite.py OUT_DIR

Reads OUT_DIR/manifest.json and OUT_DIR/static.json (run extract_blocks.py and run_static.py
first) and writes tools/skill-test/studio/generated/:

    SkillTestSuite.luau      ModuleScript: every case with its mode (server / client / skip:<why>)
    server/<id>.server.luau  one Script per server case
    client/<id>.client.luau  one LocalScript per client case
    actor/<id>.server.luau   one Script inside an Actor per actor case
    PluginCases.luau         ModuleScript: the plugin-level cases, run by run_plugin_cases.luau
                             through MCP execute_luau (a game Script cannot reach them)

Each case is the block composed with its prelude(s) and expectation(s) (compose.py). A case with an
expectation gets a SkillTestExpect attribute, so the harness reports it as FAIL unless every check
passed and the expectation ran to its end.

Mode, in order: a `--@skilltest: skip <why>` directive; a fragment (static analysis found names
from the reader's project that no prelude supplies) -> skip:fragment; `plugin` -> plugin; a block
marked beta-syntax / legacy / antipattern / placeholder / project-tree -> skip:<that> (a prelude
lifts placeholder and project-tree: it builds what they refer to); anything that bans, teleports or
prompts a purchase -> skip:side-effect; actor; client (directive, or the source uses LocalPlayer /
UserInputService / PlayerGui / CurrentCamera) -> client; else server.
"""
import json, os, re, shutil, sys, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import compose  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
# Third-party modules the skill teaches, fetched from their official repository at build time so a
# block that requires them runs against the real thing (never committed: see .gitignore).
VENDOR = {
    'ProfileStore': 'https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/main/ProfileStore.luau',
}
GEN = os.path.join(HERE, 'studio', 'generated')
CLIENT = re.compile(r'\.client\.luau|\bLocalPlayer\b|UserInputService|ContextActionService|PlayerGui|CurrentCamera')
SIDE_EFFECT = re.compile(r'BanAsync|Prompt\w*Purchase|PromptRobuxTransfer|TeleportAsync')


def mode_of(d, st, src):
    if 'skip' in d:
        return f"skip:{d['skip'] if d['skip'] is not True else 'directive'}"
    if 'fragment' in d:
        return 'skip:fragment'
    if st.get('fragment'):
        # A block whose only unresolved names are requires of modules the test project provides
        # (`--@skilltest: requires X`) still runs; anything else is the reader's own code.
        provided = 'requires' in d and all(n.startswith('require:') for n in st.get('missing', []))
        if not provided:
            return 'skip:fragment'
    if 'plugin' in d:
        return 'plugin'
    lifted = {'placeholder', 'project-tree'} if 'prelude' in d else set()
    for key in ('beta-syntax', 'placeholder', 'project-tree', 'antipattern', 'legacy'):
        if key in d and key not in lifted:
            return f'skip:{key}'
    if SIDE_EFFECT.search(src):
        return 'skip:side-effect'
    if 'actor' in d:
        return 'actor'
    if 'client' in d or CLIENT.search(src):
        return 'client'
    return 'server'


def long_string(s):
    lvl = 0
    while f']{"=" * lvl}]' in s or s.endswith(']' + '=' * lvl):
        lvl += 1
    return f'[{"=" * lvl}[{s}]{"=" * lvl}]'


def main(argv):
    if not argv:
        sys.exit(__doc__)
    out = argv[0]
    manifest = json.load(open(os.path.join(out, 'manifest.json'), encoding='utf-8'))
    static = json.load(open(os.path.join(out, 'static.json'), encoding='utf-8'))
    shutil.rmtree(GEN, ignore_errors=True)
    os.makedirs(os.path.join(GEN, 'client'))
    os.makedirs(os.path.join(GEN, 'server'))
    os.makedirs(os.path.join(GEN, 'actor'))
    with open(os.path.join(GEN, 'actor', 'init.meta.json'), 'w', encoding='utf-8') as f:
        f.write('{ "className": "Actor" }\n')
    os.makedirs(os.path.join(GEN, 'modules'))
    for name, url in VENDOR.items():
        urllib.request.urlretrieve(url, os.path.join(GEN, 'modules', name + '.luau'))
    rows, counts, plugin_rows = [], {}, []
    for b in manifest:
        src = open(os.path.join(out, 'blocks', b['id'] + '.luau'), encoding='utf-8').read()
        c = compose(src, b['directives'], force_strict=False)
        mode = mode_of(c.directives, static.get(b['id'], {}), c.text)
        expects = 'expect' in c.directives
        counts[mode.split(':')[0]] = counts.get(mode.split(':')[0], 0) + 1
        rows.append(f'\t{{ id = "{b["id"]}", file = "{b["file"]}", line = {b["line"]}, '
                    f'mode = "{mode}", expect = {str(expects).lower()}, src = {long_string(src)} }},')
        if 'provides' in b['directives']:
            with open(os.path.join(GEN, 'modules', b['directives']['provides'] + '.luau'), 'w', encoding='utf-8') as f:
                f.write(src)
        if mode == 'plugin':
            plugin_rows.append(f'\t{{ id = "{b["id"]}", expect = {str(expects).lower()}, src = {long_string(c.text)} }},')
        if mode in ('client', 'server', 'actor'):
            # The file name becomes the instance name, so a console line or a ScriptContext.Error
            # source names the block. The header comment goes AFTER the first line so a leading
            # --!strict stays a directive.
            first, _, rest = c.text.partition('\n')
            header = f'-- skilltest case {b["id"]} ({b["file"]}:{b["line"]}, block starts at line {c.block_start + 1})'
            kind = 'client' if mode == 'client' else 'server'
            with open(os.path.join(GEN, mode, f'{b["id"]}.{kind}.luau'), 'w', encoding='utf-8') as f:
                f.write(f'{first}\n{header}\n{rest}')
            if expects:
                with open(os.path.join(GEN, mode, f'{b["id"]}.meta.json'), 'w', encoding='utf-8') as f:
                    json.dump({'attributes': {'SkillTestExpect': True}}, f)
    with open(os.path.join(GEN, 'PluginCases.luau'), 'w', encoding='utf-8') as f:
        f.write('-- Generated by tools/skill-test/build_suite.py. Do not edit.\nreturn {\n')
        f.write('\n'.join(plugin_rows))
        f.write('\n}\n')
    with open(os.path.join(GEN, 'SkillTestSuite.luau'), 'w', encoding='utf-8') as f:
        f.write('-- Generated by tools/skill-test/build_suite.py. Do not edit.\nreturn {\n')
        f.write('\n'.join(rows))
        f.write('\n}\n')
    print(f'suite: {len(rows)} cases ' + ' '.join(f'{k}={v}' for k, v in sorted(counts.items())))


if __name__ == '__main__':
    main(sys.argv[1:])
