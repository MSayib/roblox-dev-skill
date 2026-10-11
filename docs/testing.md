# How the skill is tested

[← README](../README.md)

Every Luau example in this skill is checked four ways before a release, and its prose against a
claims register. Each check exists because
an earlier version shipped a defect the others could not see; [CHANGELOG.md](../CHANGELOG.md) names
them.

| Layer | What it catches | Command |
|---|---|---|
| **Static** (`tools/skill-test/run_static.py`) | Syntax errors, type errors under `--!strict` with the New Type Solver, members that do not exist, deprecated APIs, members a game Script may not touch | `python3 tools/skill-test/run_static.py OUT --strict` |
| **Runtime in Studio** (`tools/skill-test/studio/`) | What only running shows: capability gates, features present but not enabled, logic bugs, compile errors the Roblox compiler raises | see below |
| **API audit** (`tools/robloxdocs/audit-skill-examples.py`) | Examples and prose that name elevated, `NotScriptable`, capability-gated (`PluginOrOpenCloud`), deprecated or missing members | `python3 tools/robloxdocs/audit-skill-examples.py references` |
| **Evals** (`evals/evals.json`) | Whether an agent using the skill answers correctly, including the traps the defects above came from | see below |
| **Claims register** (`tools/skill-test/claims.json`) | Prose claims: what each says, how it was verified, and whether text verified wrong has come back | `python3 tools/skill-test/check_claims.py --strict --report docs/claims.md` |

## Static analysis

```bash
OUT=$(mktemp -d)
python3 tools/skill-test/extract_blocks.py "$OUT"          # every ```luau / ```lua block -> a file
python3 tools/skill-test/run_static.py "$OUT" --strict     # luau-lsp, exit 1 on any unexplained finding
```

`run_static.py` needs [`luau-lsp`](https://github.com/JohnnyMorganz/luau-lsp) (it finds a rokit or
aftman install, or pass `--luau-lsp PATH`) and downloads the current Roblox definitions. It analyses
**every block in strict mode** (nonstrict mode does not report unknown globals, so a fragment would
look complete) against what a **game Script** may touch; blocks marked `plugin` are checked against
plugin-level definitions instead.

A block that uses names from the reader's own project (`playerStore`, `screenGui`, …) is a
**fragment**. A **prelude** supplies those names (see [Preludes and expectations](#preludes-and-expectations)),
and the block is analysed together with it, so the reader's names have real types. A fragment
without a prelude still gets every other check, and an error on a line that uses one of its
unknown names is treated as a knock-on effect; `run_static.py` reports how many are left
(`with unresolved names`).

## Runtime in Studio

The runtime layer runs each complete example the way a developer would paste it, in a real place,
during a playtest. It is synced with **Rojo on port 34871**:

```bash
python3 tools/skill-test/build_suite.py "$OUT"   # after run_static.py; writes studio/generated/
cd tools/skill-test/studio
rojo serve default.project.json --port 34871
```

Then in Studio: connect the Rojo plugin to port 34871, start a playtest, and read the console.
`SkillTestHarness` (server) and `SkillTestClientHarness` (client) print one line per failing case
and end with

```
[SKILLTEST] DONE server cases=N ok=N runtime-error=0 infinite-yield=0 late=0 expect-pass=E expect-fail=0
[SKILLTEST] DONE client cases=N ok=N runtime-error=0 infinite-yield=0 late=0 expect-pass=E expect-fail=0
```

A case fails on a runtime error, on an expectation that did not pass, or on an `Infinite yield`
whose child never arrived (the block never ran to its end). A yield whose child arrived later
(a ScreenGui after a slow first spawn) is counted as `late`, not as a failure.

Plugin-level blocks cannot run as a game Script. With Studio in Edit mode, run
`tools/skill-test/studio/run_plugin_cases.luau` through MCP `execute_luau` (or the command bar);
it returns `[SKILLTEST] DONE plugin cases=N ok=N expect-pass=E expect-fail=0`.

- Each server block becomes its own `Script` (game-Script identity, so security and capability
  gates apply; MCP `execute_luau` runs at plugin level and would hide them). Client blocks become
  `LocalScript`s, and blocks marked `actor` run inside an `Actor`.
- The project supplies what the examples `WaitForChild` for: the remotes they cast to, an IAS
  context with actions, a `ShopGui`, a `Coins` folder, an `NPCTemplate`, and the modules they
  `require` (the official ProfileStore from its repository, plus the skill's own `ObjectPool`,
  `ReceiptHandler` and `PlayerDataSchema` blocks).
- Nothing in the place is removed: services are listed without `$path`, so Rojo leaves their
  existing children alone. Use a throwaway place: some examples write to DataStores.
- Check the console for `Infinite yield` warnings too. A block stuck on `WaitForChild` did not run
  to the end and is not tested.

Blocks that must not run (they ban, prompt a purchase, or teleport), and blocks that only show a
legacy, anti-pattern or beta form, are skipped with a reason recorded in
`generated/SkillTestSuite.luau`.

## Preludes and expectations

A **prelude** (`tools/skill-test/preludes/<name>.luau`) is placed before a block and declares the
names a reader would already have: `screenGui` in their PlayerGui, `playerStore`, a `player` from
`PlayerAdded`. An **expectation** (`tools/skill-test/expect/<name>.luau`) is placed after it and
asserts what the example must do, with `__skilltest.check(label, ok)` and
`__skilltest.eq(label, actual, expected)`: the pool is back to 10 after acquire/release, two new
players do not share an Inventory, a receipt is granted once, a v1 save migrates to v3. An
expectation sees the block's top-level locals; when the block is a module, its final
`return X` becomes `local skilltestModule = X` (a function wrapper would make `export type`
illegal). `compose.py` builds the combined source, which both the static and the Studio layer use.

A prelude may declare its own directives: `prelude <dependency>`, `client`, `plugin`, or
`varargs <expr>` (the block is called with those values, for a block that starts
`local player: Player = ...`). A prelude lifts the `project-tree` and `placeholder` skips, because
it builds what they refer to.

The worked examples' own **Verification** sections were also executed as written, through MCP
(`execute_luau` on the Server and Client datamodels, `user_keyboard_input` for real key presses).

## Directives

A block can declare what it is with a comment inside it, or with an HTML comment on the line
directly above its fence, which the rendered page does not show and a reader does not copy with
the code (items separated by `;`):

```markdown
<!-- skilltest: prelude screen-gui; expect per-corner-radius -->
```

Use the HTML form for anything that only concerns the tests (`prelude`, `expect`, `requires`,
`provides`); keep the in-block form for what also tells the reader something (`legacy`,
`plugin`, `client`).

| Directive | Meaning |
|---|---|
| `--@skilltest: legacy` | A "do not do this" form kept to be recognised; deprecated calls are expected |
| `--@skilltest: antipattern` | Same, for a pattern that is wrong rather than deprecated |
| `--@skilltest: beta-syntax` | Syntax that only exists behind a Studio beta (`if local`) |
| `--@skilltest: plugin` | Runs at plugin / command-bar level, not as a game Script |
| `--@skilltest: client` | A `LocalScript` |
| `--@skilltest: actor` | Must run inside an `Actor` (Parallel Luau) |
| `--@skilltest: project-tree` | Uses instances from the reader's place (`workspace.SomeNPC`) |
| `--@skilltest: placeholder` | Contains `<placeholders>` to fill in |
| `--@skilltest: prelude A B` | Supply the reader's names from `preludes/A.luau`, `preludes/B.luau` |
| `--@skilltest: expect A` | Assert behaviour with `expect/A.luau` after the block |
| `--@skilltest: requires X` | Needs module `X`, which the test project provides |
| `--@skilltest: provides X` | This block is module `X` for other blocks |
| `--@skilltest: fragment` / `skip <why>` | Not a complete program / do not run |

## Claims register

Code is checked by running it; prose is checked against the register. Each entry anchors to an
exact quote of the text and records its status: **studio** (run in Studio), **docs** (official
documentation), **dump** (the API dump), **source** (Luau/Roblox source, release notes, published
flags), **advice** (a recommendation, nothing to verify), **unverified**, or **false** (verified
wrong and fixed; the old wrong text must not come back). `check_claims.py`:

- fails on a **stale** claim (its quote is no longer in the text: re-verify and update it);
- finds every **high-risk line** (numbers and limits, versions, "cannot / only / not enabled /
  deprecated") that no claim covers; `--seed` adds them as `unverified`;
- checks every `Class.Member` named in prose against the API dump;
- writes [`claims.md`](claims.md), the per-file status table and the evidence for every verified
  claim.

A claim that cannot be verified must say so in the text, or go.

## Evals

`evals/evals.json` holds prompts with the expected references and what a correct answer must and
must not do. Run them against a local install with your agent (for Claude Code:
`claude -p "<prompt>"` from any directory), and compare the answer with the `notes`.

## Contributing

1. **Ground every claim** in official Roblox documentation, the API dump, or a test you ran. If you
   could not run it, say so in the text.
2. **Use `--!strict`** in code examples, with nothing else on the directive line.
3. **Pass all four layers above** with 0 unexplained findings, and run new examples in Studio.
4. **Update `metadata.json` and `CHANGELOG.md`** with what changed and how it was verified.
5. **Validate against the spec:**
   `uvx --from "git+https://github.com/agentskills/agentskills#subdirectory=skills-ref" skills-ref validate "$PWD"`
6. **Run the installer suites:** `bash tests/install/test_unix.sh`,
   `pwsh -File tests/install/test_powershell.ps1` and `python3 tests/lint/check_sources.py`. They use
   throwaway homes and never touch your real agent folders. CI runs them on Linux, macOS and Windows.
