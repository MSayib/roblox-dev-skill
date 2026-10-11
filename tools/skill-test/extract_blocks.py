#!/usr/bin/env python3
"""Extract every Luau/Lua code block from the skill into standalone files plus a manifest.

Usage:
    extract_blocks.py OUT_DIR [--root REPO]

Writes OUT_DIR/blocks/<id>.luau and OUT_DIR/manifest.json. Each manifest entry records where the
block lives (file, first line), its fence language, and the directives found in its comments, so
the static and Studio runners can decide what to do with it without guessing.

Directives are ordinary Luau comments placed anywhere in a block, or an HTML comment on the line(s)
directly above the fence, which the rendered page does not show and a reader does not copy:
    <!-- skilltest: prelude screen-gui; expect pool-returns-to-ten -->
(items separated by `;`). In a block:
    --@skilltest: fragment        not a complete program (refers to names defined elsewhere)
    --@skilltest: plugin          runs at plugin / command-bar level, not as a game Script
    --@skilltest: client          a LocalScript
    --@skilltest: skip <reason>   do not run in Studio (e.g. it bans players, prompts a purchase)
    --@skilltest: prelude <names>  supply the reader's own names (tools/skill-test/preludes/)
    --@skilltest: expect <names>   assert behaviour after the block (tools/skill-test/expect/)
A block without directives is treated as a complete server Script. docs/testing.md lists them all.
"""
import json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import directives_of  # noqa: E402

HTML_DIRECTIVE = re.compile(r'^\s*<!--\s*skilltest:\s*(.*?)\s*-->\s*$')
FENCE = re.compile(r'^```(\w*)\s*$')
LUAU_LANGS = {'luau', 'lua'}


def html_directives(lines):
    """`<!-- skilltest: a x; b y -->` -> '--@skilltest: a x' lines, merged like in-block ones."""
    return '\n'.join(f'--@skilltest: {item.strip()}' for l in lines
                     for item in HTML_DIRECTIVE.match(l).group(1).split(';') if item.strip())


def blocks_in(path, rel):
    out, lang, start, buf, pending, html = [], None, 0, [], [], []
    with open(path, encoding='utf-8') as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip('\n')
            m = FENCE.match(line.strip()) if line.lstrip().startswith('```') else None
            if lang is None and m:
                lang, start, buf, html, pending = m.group(1).lower(), n + 1, [], pending, []
            elif lang is not None and line.strip() == '```':
                if lang in LUAU_LANGS:
                    out.append((rel, start, lang, '\n'.join(buf) + '\n', html_directives(html)))
                elif html:
                    sys.exit(f'{rel}:{start - 1}: skilltest comment above a non-Luau block')
                lang = None
            elif lang is not None:
                buf.append(line)
            else:
                pending = pending + [line] if HTML_DIRECTIVE.match(line) else []
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
        for rel_, line, lang, src, html in blocks_in(os.path.join(root, rel), rel):
            stem = os.path.splitext(os.path.basename(rel_))[0]
            bid = f'{stem}__L{line}'
            directives = directives_of(src + '\n' + html)
            with open(os.path.join(out_dir, 'blocks', bid + '.luau'), 'w', encoding='utf-8') as f:
                f.write(src)
            manifest.append(dict(id=bid, file=rel_, line=line, lang=lang,
                                 lines=src.count('\n'), directives=directives))
    with open(os.path.join(out_dir, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=1)
    print(f'{len(manifest)} Luau/Lua blocks -> {out_dir}')


if __name__ == '__main__':
    main(sys.argv[1:])
