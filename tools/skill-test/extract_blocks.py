#!/usr/bin/env python3
"""Extract every Luau/Lua code block from the skill into standalone files plus a manifest.

Usage:
    extract_blocks.py OUT_DIR [--root REPO]

Writes OUT_DIR/blocks/<id>.luau and OUT_DIR/manifest.json. Each manifest entry records where the
block lives (file, first line), its fence language, and the directives found in its comments, so
the static and Studio runners can decide what to do with it without guessing.

Directives are ordinary Luau comments placed anywhere in a block:
    --@skilltest: fragment        not a complete program (refers to names defined elsewhere)
    --@skilltest: plugin          runs at plugin / command-bar level, not as a game Script
    --@skilltest: client          a LocalScript
    --@skilltest: skip <reason>   do not run in Studio (e.g. it bans players, prompts a purchase)
    --@skilltest: expect-error    the block demonstrates something that MUST fail ("Not this")
A block without directives is treated as a complete server Script.
"""
import json, os, re, sys

FENCE = re.compile(r'^```(\w*)\s*$')
DIRECTIVE = re.compile(r'--@skilltest:\s*([\w-]+)(?:\s+(.*))?$', re.M)
LUAU_LANGS = {'luau', 'lua'}


def blocks_in(path, rel):
    out, lang, start, buf = [], None, 0, []
    with open(path, encoding='utf-8') as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip('\n')
            m = FENCE.match(line.strip()) if line.lstrip().startswith('```') else None
            if lang is None and m:
                lang, start, buf = m.group(1).lower(), n + 1, []
            elif lang is not None and line.strip() == '```':
                if lang in LUAU_LANGS:
                    out.append((rel, start, lang, '\n'.join(buf) + '\n'))
                lang = None
            elif lang is not None:
                buf.append(line)
    return out


def main(argv):
    if not argv:
        sys.exit(__doc__)
    out_dir = argv[0]
    root = argv[argv.index('--root') + 1] if '--root' in argv else os.getcwd()
    files = ['SKILL.md'] + sorted(
        os.path.join('references', f) for f in os.listdir(os.path.join(root, 'references'))
        if f.endswith('.md'))
    os.makedirs(os.path.join(out_dir, 'blocks'), exist_ok=True)
    manifest = []
    for rel in files:
        for rel_, line, lang, src in blocks_in(os.path.join(root, rel), rel):
            stem = os.path.splitext(os.path.basename(rel_))[0]
            bid = f'{stem}__L{line}'
            directives = {}
            for key, val in DIRECTIVE.findall(src):
                directives[key] = (val or '').strip() or True
            with open(os.path.join(out_dir, 'blocks', bid + '.luau'), 'w', encoding='utf-8') as f:
                f.write(src)
            manifest.append(dict(id=bid, file=rel_, line=line, lang=lang,
                                 lines=src.count('\n'), directives=directives))
    with open(os.path.join(out_dir, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=1)
    print(f'{len(manifest)} Luau/Lua blocks -> {out_dir}')


if __name__ == '__main__':
    main(sys.argv[1:])
