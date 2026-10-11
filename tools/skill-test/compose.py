"""Compose a block with its prelude(s) and expectation(s) into the source that is analysed and run.

A fragment of the skill uses names from the reader's project (`screenGui`, `playerStore`). A
PRELUDE supplies them without changing the text the reader sees; an EXPECTATION asserts what the
example must do (a pool is back to 10, a receipt is granted once). Both live in this directory:

    preludes/<name>.luau   prepended; may itself declare `--@skilltest: prelude <dep>`, `client`,
                           `plugin` or `varargs <expr>` (the block is then called with those values,
                           for a block that starts `local player: Player = ...`)
    expect/<name>.luau     appended; sees the block's top-level locals, and `skilltestModule` (what
                           the block returns) when the block ends with a top-level `return`: that
                           line becomes `local skilltestModule = <value>` (a function wrapper
                           would make the block's `export type` illegal)
    expect/_lib.luau       the check() / eq() / done() helpers, prepended when a block has an expect

The composed source keeps the block's own lines contiguous; `Composed.block_line()` maps a line of
the composed source back to the block (or returns None for a prelude / expectation line).
"""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
PRELUDES = os.path.join(HERE, 'preludes')
EXPECTS = os.path.join(HERE, 'expect')
DIRECTIVE = re.compile(r'--@skilltest:[ \t]*([\w-]+)(?:[ \t]+(.*))?$', re.M)
MODE = re.compile(r'--!(strict|nonstrict|nocheck)\s*$')
# A top-level `return` (column 0) as the last statement: the block is a module.
TOP_RETURN = re.compile(r'^return\b')


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def directives_of(src):
    out = {}
    for key, val in DIRECTIVE.findall(src):
        val = (val or '').strip()
        if key in out and val and out[key] is not True:
            out[key] = f'{out[key]} {val}'
        else:
            out[key] = val or True
    return out


def names(directives, key):
    v = directives.get(key)
    return v.split() if isinstance(v, str) else []


def resolve_preludes(roots):
    """Preludes in dependency order (a prelude's own `prelude` directive lists its dependencies)."""
    order, seen = [], set()

    def visit(name, stack):
        if name in seen:
            return
        if name in stack:
            raise ValueError(f'prelude cycle: {" -> ".join(stack + [name])}')
        path = os.path.join(PRELUDES, name + '.luau')
        if not os.path.exists(path):
            raise FileNotFoundError(f'unknown prelude {name!r} ({path})')
        src = _read(path)
        for dep in names(directives_of(src), 'prelude'):
            visit(dep, stack + [name])
        seen.add(name)
        order.append((name, src))

    for r in roots:
        visit(r, [])
    return order


def module_return(lines):
    """Index of the block's final top-level `return` line, or None."""
    for i in range(len(lines) - 1, -1, -1):
        s = lines[i].strip()
        if s and not s.startswith('--'):
            return i if TOP_RETURN.match(lines[i]) else None
    return None


class Composed:
    def __init__(self, text, block_start, block_lines, directives, region):
        self.text = text                  # full source
        self.block_start = block_start    # composed line number of the block's first line
        self.block_lines = block_lines
        self.directives = directives      # block directives merged with every prelude's
        self.region = region              # [(first composed line, last, label)] for non-block lines

    def block_line(self, line):
        off = line - self.block_start + 1
        return off if 1 <= off <= self.block_lines else None

    def label(self, line):
        for a, b, lab in self.region:
            if a <= line <= b:
                return lab
        return 'composition'


def compose(src, directives, force_strict=True):
    """Return a Composed for a block. Without prelude/expect, the block itself (plus --!strict)."""
    preludes = resolve_preludes(names(directives, 'prelude'))
    expects = names(directives, 'expect')
    merged = dict(directives)
    for _, psrc in preludes:
        for k, v in directives_of(psrc).items():
            if k != 'prelude' and k not in merged:
                merged[k] = v
    lines = src.rstrip('\n').split('\n')
    mode = None
    if lines and MODE.match(lines[0].strip()):
        mode = lines[0].strip()
        lines = ['-- (mode directive moved to line 1)'] + lines[1:]
    out, region = [], []

    def add(text, label):
        start = len(out) + 1
        out.extend(text.rstrip('\n').split('\n'))
        region.append((start, len(out), label))

    out.append(mode or ('--!strict' if force_strict else '-- (no mode directive)'))
    region.append((1, 1, 'mode line'))
    if expects:
        add(_read(os.path.join(EXPECTS, '_lib.luau')), 'expect/_lib.luau')
    for name, psrc in preludes:
        add(psrc, f'preludes/{name}.luau')
    varargs = merged.get('varargs')
    ret = module_return(lines) if expects else None
    if ret is not None:
        lines[ret] = TOP_RETURN.sub('local skilltestModule =', lines[ret], count=1)
    wrap = isinstance(varargs, str)
    if wrap:
        add('local function skilltestBlock(...)', 'wrapper')
    block_start = len(out) + 1
    out.extend(lines)
    if wrap:
        add(f'end\nskilltestBlock({varargs})', 'wrapper')
    for e in expects:
        add(_read(os.path.join(EXPECTS, e + '.luau')), f'expect/{e}.luau')
    if expects:
        add('__skilltest.done()', 'expect/_lib.luau')
    return Composed('\n'.join(out) + '\n', block_start, len(lines), merged, region)
