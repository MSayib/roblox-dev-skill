# Changelog

All notable changes to `roblox-dev-skill`. Newest first.

The README carries only the **three most recent** versions; this file is the full history.
Machine-readable entries, with the verification method used for each, live in
[`metadata.json`](metadata.json) under `update_history`.

**Version numbers track this skill, not Roblox.** An entry's engine/Luau version records what the
reference content was verified against at that time.

---

## 2.13.1 — Sep 25, 2026

**CI that verifies every installer on every OS — and the six bugs it found on its first runs.**
No engine or content change.

### Fixed — `install.sh` failed on its GitHub download path

The v2.13.0 one-liner died immediately for anyone who ran it: bash 3.2 in a UTF-8 locale reads a
non-ASCII byte right after a variable name as part of that name, so an unbraced `REF` followed by an
ellipsis in a progress message looked up a variable called `REF\xe2…`, and `set -u` killed the run.

**Why no test caught it:** every test used `--source`, which returns *before* that line. The
download path — the only path real users take — had never executed. CI now runs the README
one-liners against the commit under test, downloading it from GitHub exactly as a user would, and
`tests/lint/check_sources.py` rejects the pattern.

### Fixed — five bugs that exist only on Windows, found by the first real-Windows CI runs

| Bug | Effect on a user | Fix |
|---|---|---|
| `split-api-dump.py` printed an emoji into a **cp1252** pipe | Crashed *after* writing every file; the monitor reported a failed split and the example audit never ran | Every Python tool sets `errors="replace"`; CI runs the live audit under `PYTHONIOENCODING=cp1252` |
| `audit-skill-examples.py` / `diff-api-dumps.py` used `open()` without an encoding | Windows decoded UTF-8 Markdown as cp1252 and crashed on byte `0x8f` | Every `open()` names `utf-8`; a lint rule forbids omitting it |
| Under Git Bash, `install.sh` wrote `SKILL_REFS=/c/Users/…` | Native Windows Python cannot resolve MSYS paths, so the audit was **always** skipped for Git Bash users | MSYS converts arguments and environment variables, never file contents — the config now uses `cygpath -m` |
| Windows PowerShell 5.1 turns captured native stderr into error records | Under `Stop`, the first Python warning would abort `install.ps1` | Native calls run under `Continue` |
| `echo` in `cmd.exe` does not reset `ERRORLEVEL` | (test only) the failure-path check inherited the expected failure | explicit `exit /b 0` |

A seventh was mine and caught in minutes: adding the `ROBLOX_SKILL_LINK` hook split a `local`
declaration across two lines, so `ACTION` was never set. Syntax-valid, ShellCheck-clean, and the new
functional suite failed 33 checks on its first run.

### Added — CI (`.github/workflows/ci.yml`)

Runs on every push to `master`, every pull request, and **weekly**, because Roblox ships weekly and
a month-old green build says little about today.

| Job | Verifies |
|---|---|
| Lint & spec | source hygiene (ASCII for PS 5.1, CRLF for `install.cmd`, LF for scripts, the bash-3.2 name trap, `open()` encodings, truncation safety), ShellCheck, PSScriptAnalyzer for PowerShell 5.1 + 7.0 syntax, and the official `skills-ref` validator on the repo **and** on the payload the installer produces |
| Examples vs live Roblox API | ingests the current engine dump and audits every code example in **strict** mode, under a cp1252 code page |
| `install.sh` — Linux, macOS (`/bin/bash` 3.2) | 47-check functional suite, then the README one-liner downloading this commit from GitHub, including RobloxDocs |
| `install.ps1` — Windows PowerShell 5.1, PowerShell 7 | 38-check suite including **junction mode** and the check that removing a junction leaves its target intact, then `irm \| iex` downloading this commit |
| `install.cmd` — `cmd.exe` | the README CMD one-liner, and that a failure returns a non-zero exit code |
| `install.sh` — Git Bash on Windows | the suite on a platform where `ln -s` silently copies |

The suites are ordinary scripts (`tests/install/test_unix.sh`, `tests/install/test_powershell.ps1`)
that run against throwaway homes, so contributors can run them locally without touching their real
agent folders. On failure they print the installer's own output for that scenario.

### Added — installer environment variables

- **`ROBLOX_SKILL_REF`** — the version to install. Under `irm | iex` this is the only way to pin
  one, since that form cannot take options. `install.cmd` honours it too.
- **`ROBLOX_SKILL_LINK=symlink|junction|copy`** — pin the link method. CI needs it: GitHub's Windows
  runners are administrators, so symlinks always succeed and junctions would otherwise never be tested.
- **`ROBLOX_SKILL_HOME`** — install against a different profile. `$HOME` cannot be redirected in
  PowerShell 7 on Windows, so tests need this to stay out of the real one.

---

## 2.13.0 — Sep 25, 2026

**One-line installers for every OS and every major agent, and RobloxDocs that sets itself up.**
No engine change — still 0.740.19.7400931 / Luau 0.739.

### Added — installers

| Shell | Command |
|---|---|
| macOS, Linux, WSL, Git Bash | `curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.sh \| bash` |
| Windows PowerShell | `irm https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.ps1 \| iex` |
| Windows CMD | `curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.cmd -o install.cmd && install.cmd` |

Each shows a wizard of 14 agent targets with the detected ones pre-selected, **stores the skill once**
and **links** it into every chosen agent (symlink → Windows junction → marked copy), so one update
reaches every agent. Non-interactive runs use the detected defaults; every option has a flag.

**Every agent path was verified against that agent's own documentation**, not recalled. Two
surprises: Codex documents `$HOME/.agents/skills`, not `~/.codex/skills`; and Antigravity does
**not** read `~/.agents/skills` at all — its global folder is `~/.gemini/config/skills`.

**Deduplication.** Nine agents document `~/.agents/skills` (the cross-client convention), so one
universal link covers them. Native links are added only for Claude Code, Antigravity, Antigravity
CLI and Kiro. Linking Cursor natively as well would make it list the skill twice.

**Safety rules, each covered by a test:**
- Never deletes anything it did not create. A conflicting folder is moved to a backup **outside**
  every skills folder — a backup inside one would load as a duplicate skill.
- A link pointing elsewhere (a maintainer's dev checkout) is left alone unless `--force`.
- Uninstall removes only manifest entries that still point at the store or carry the install marker.
- `--dry-run` leaves the file tree byte-identical.

**Shell-specific hazards designed around:**
- bash: all logic lives in `main()` called on the last line, so a truncated `curl` download runs
  nothing; prompts read `/dev/tty`, because under `curl | bash` stdin *is* the script; bash 3.2
  compatible for the macOS default; an `ERR` trap reports the failing line instead of dying silently.
- PowerShell: runs in a child scope so nothing leaks into the caller's session under `iex`;
  **throws instead of `exit`**, which would close the user's window; removes links as reparse points
  because `Remove-Item -Recurse` on a 5.1 junction can **delete the target's contents**; ASCII-only
  source because 5.1 reads BOM-less UTF-8 as ANSI; TLS 1.2 on; progress bar off.
- CMD: stored with CRLF bytes (`.gitattributes: install.cmd -text`), because raw.githubusercontent
  serves blob bytes and `cmd.exe` can mis-parse bare LF.

### Changed — RobloxDocs is now in the repo and cross-platform

The tooling previously existed only on the maintainer's machine, with a hardcoded `~/Desktop` path,
and needed zsh, jq and bc — none of which a Windows user has. Now `tools/robloxdocs/` ships:

- **`roblox-api-monitor.py`** — one implementation for every OS. `roblox-api-monitor.sh` is a shim
  so the path `SKILL.md` documents keeps working.
- **`split-api-dump.py`** — one pass in 0.7 s, replacing ~2,800 `jq` processes. Verified identical to
  the jq output across all 1,869 generated files.
- `diff-api-dumps.py`'s grep-back is now pure Python — it shelled out to `grep`, absent on Windows,
  and would have silently reported nothing there.
- Settings in `~/RobloxDocs/config` (`SKILL_REFS`, `AUDIT_MODE=warn|strict|off`), **parsed, never
  executed** — a config line containing `$(…)` was tested and does not run. Community installs
  default to `warn`; maintainers set `strict`.

Three portability traps handled: `python3` on Windows is often a Microsoft Store **stub** that
fails, so the tools probe for a *working* interpreter; a python.org install on macOS ships **no CA
bundle**, so downloads fall back to `curl`; and **`os.kill(pid, 0)` on Windows sends `CTRL_C_EVENT`**
rather than probing, so the lock checks liveness with `OpenProcess`/`GetExitCodeProcess` there.

### Fixed — misleading instructions

- **README told Claude Code users to clone into `~/.claude/skills/roblox-dev`.** The official
  `skills-ref` validator rejects that: *"Directory name 'roblox-dev' must match skill name
  'roblox-dev-skill'"*. The installer finds such a clone and moves it aside.
- **README told Antigravity users to clone into `~/.gemini/config/plugins/roblox-dev-suite/skills/`.**
  That is a plugin folder Antigravity loads only with a `plugin.json` manifest the repo never shipped
  — it worked on the maintainer's machine solely because of a hand-written local manifest.
- **The intro linked Antigravity to `antigravity.dev`, which serves a default nginx page.** The real
  site is `antigravity.google`.
- **`SKILL.md` measured file sizes with `stat -f %z`.** On Linux `stat -f` reports the *filesystem*
  and prints a wrong number with no error. Replaced by a portable one-liner; the documented median is
  now 2,050 B, the true median of 924 files (the old awk took the lower-middle element).
- `SKILL.md`'s export note and `metadata.json`'s `skill_name` still used the old name `roblox-dev`.

### Verification

`skills-ref validate` passes on the repo and on the installed payload. ShellCheck is clean; PSScriptAnalyzer
confirms syntax compatibility with PowerShell 5.1 and 7.0. Functional suites ran on throwaway `HOME`
directories under `/bin/bash` 3.2 and PowerShell 7.6.6, including wizards driven prompt-by-prompt
through a real pseudo-terminal and a from-scratch install with a real API dump download.

**Not verified on real Windows hardware** at the time — junction creation, PowerShell 5.1 at runtime,
and `install.cmd`. *2.13.1 added CI that verifies all three, and it found five Windows-only bugs.*

---

## 2.12.0 — Sep 25, 2026

**Worked examples, a second latent defect found, and the tooling that makes both checkable.**
No engine change — still 0.740.19.7400931 / Luau 0.739.

### Added — `references/worked-examples.md`

Every other reference answers *"what is true about Roblox?"*. This one answers *"what do I do, in
order, and how do I know it worked?"* Five end-to-end sequences:

1. **Add a server-authoritative feature** — intent vs outcome, all validation layers, and a
   verification step that fires junk at the handler rather than only proving the happy path.
2. **Debug a runtime error through MCP** — with the failure-mode table (`multi_edit` is `Edit`-only,
   `old_string` is exact-match, stale `studio_id` is silent, `script_grep` line numbers lie).
3. **Migrate a deprecated API** — confirm the deprecation in the local dump via `jq`, and check
   whether the replacement **yields** before doing a text substitution.
4. **Verify an unfamiliar API** — read `Security`, `Capabilities` *and* `Tags`, not just one.
5. **Refuse and redirect an unsafe request** — a worked example of *not* complying: name the
   concrete exploit, offer the nearest thing that works, and if the user reaffirms, it is their call.

Each carries a **Not this** list of requests that look similar and route elsewhere, because the
failure mode of examples is an agent matching one onto a task it does not fit.

### Fixed — the Input Action System example was wrong in six of twelve lines

Found by the new existence audit, not by a release. `project-structure.md` documented:

| Was | Reality in the 0.740 dump |
|---|---|
| `game:GetService("InputActionService")` | **No such class.** The container is `InputContext`, recommended under `ReplicatedStorage/Inputs` |
| `Instance.new("InputActionBinding")` | **No such class** — it is `InputBinding` |
| `action.ActionType = …` | The property is **`Type`** |
| `Enum.InputActionType.Button` | **Not an item.** Valid: `Bool`, `Direction1D`, `Direction2D`, `Direction3D`, `ViewportPosition` |
| `binding.InputType = Enum.UserInputType.Keyboard` | No such property; set `KeyCode` directly |
| `action.Activated` / `.Deactivated` | The events are **`Pressed`**, **`Released`**, **`StateChanged`** |
| `workspace.PlayerScriptsUseInputActionSystem = true` | It is an **`Enum.RolloutState`** (`Default`/`Disabled`/`Enabled`) — `= true` is a type error |

An agent following the old text would have failed on the first line. The section is rewritten with
the documented edit-time hierarchy, the real concept table (including `InputContext`, which was
missing entirely), and a note that `GetInputBindings()` is `RobloxScriptSecurity` — so rebinding UI
must use `PreferredBinding` + `InputActionLabel`.

Also corrected: the file claimed IAS "replaces the legacy per-input-event model
(`UserInputService`, `ContextActionService`)". Neither service carries a `Deprecated` tag; only a
few individual members do. IAS is the recommended approach for new input work, not a replacement.

### Added — tooling in `~/RobloxDocs/scripts/`

- **`audit-skill-examples.py`** — parses every Luau block in the references and checks it against
  the dump: elevated-security members, capability-gated writes, unknown classes, unknown enum items,
  and method calls that do not exist on the resolved service. **Exits non-zero**, so a broken
  example fails the ingest instead of shipping. Precision matters for a tool that will cry wolf, so
  it resolves a member name across *all* classes and only reports when every definition is elevated,
  skips receivers bound from `require()` and a community-library allowlist (`DataStore2:Get()` is not
  an engine call), and checks method calls only in section E because `ReplicatedStorage.Remotes` is
  ordinary Luau.
- **`diff-api-dumps.py`** — member-level diff: added/removed classes, members, `Security`,
  `Capabilities`, `Tags` and signatures, plus enum items. Triages developer-visible changes ahead of
  `RobloxScriptSecurity` churn, and **greps back into the references** so "the API changed" is
  connected to "our docs say something about it".

### Changed — `roblox-api-monitor.sh` v2

- **Member-level diff replaces the count diff.** v1 compared class and enum *counts* only, which is
  why six `Security` changes in 0.739→0.740 were invisible to it.
- **Download integrity gate.** The dump is validated as parseable JSON with a plausible shape
  *before* it becomes `latest.json`. v1 would have symlinked a truncated download as the source of
  truth. Verified against an empty dump, a truncated dump, and a wrong-typed dump.
- **Example audit wired in**, so a doc example that cannot execute on the new engine version fails
  the run.
- **`.current-version` now always writes both `updatedAt` and `checkedAt`**, fixing the cause of the
  staleness-check bug that 2.11.0 could only document around. `updatedAt` is preserved across
  check-only runs.
- **PID-aware lock that self-clears when stale.** The first version could be left locked by a run
  killed without its trap firing (a `| head` SIGPIPE did exactly that during testing), which blocked
  every later run until someone deleted the directory by hand.
- **Retention is opt-in (`--keep N`), defaulting to keeping everything.** Old dumps are forensic
  evidence: tracing `CollisionFidelity` across 0.733–0.740 is what proved how long the broken
  example had been shipping. Deleting them by default to save ~8 MB each would destroy that.
- `set -u`, pipefail, a dependency check, and version-sorted previous-dump detection instead of
  mtime.

### Verified — how long the 2.11.0 defect had been shipping

`TriangleMeshPart.CollisionFidelity` was `Write: PluginSecurity` in **every** dump from 0.733
through 0.739, and `git log -S` puts the broken example in the **initial release of 2026-06-25**. So
it was wrong for three months and across eight engine versions. 0.740 did not break it — 0.740
accidentally *fixed* it, and that is the only reason it surfaced.

### Installation — one source of truth

`~/.claude/skills/roblox-dev` and
`~/.gemini/config/plugins/roblox-dev-suite/skills/roblox-dev-skill` were **separate clones**, at
v2.9.0 and **v2.6.0** respectively, so Claude Code and Antigravity/Gemini were each serving stale
content after a merge. Both are now symlinks to the canonical checkout; the old clones are backed up
under `~/RobloxDocs/.skill-clone-backups/`. A `git pull` in one place now updates every agent.

---

## 2.11.0 — Sep 25, 2026

**Engine 0.740.19.7400931 + Luau 0.739 (released 2026-09-18).** Dump downloaded, re-split, and
diffed against 0.739 locally: **924 classes (−1) / 635 enums (−1) / 258 services / 48 deprecated** —
the first shrinking release in this window.

### Engine 0.740 — removals and deprecations

- **`SnippetService` removed** (whole class). **`Enum.Language` removed.** Nothing in this skill
  referenced either.
- **`LocalizationService:GetTranslatorForPlayer()` newly deprecated** → use
  **`GetTranslatorForPlayerAsync()`** (confirmed `Yields` in the dump). Added to the Migration
  Reference Table alongside the 0.739 `CallingService.CreateCall` → `CreateCallAsync` rename.
- `WorldRoot.PhysicsStepTime` gained the `ReadOnly` tag.

### Engine 0.740 — a security relaxation that invalidated a shipped example

`Security.Write` went **`PluginSecurity` → `None`** for `TriangleMeshPart.CollisionFidelity`,
`TriangleMeshPart.FluidFidelity`, `PartOperation.RenderFidelity`, and `PartOperation.SmoothingAngle`.

**This means `performance-optimization.md` had been shipping a plain `--!strict` runtime loop that
set `part.CollisionFidelity` — which could not have worked from an ordinary Script before 0.740.**
It would have thrown a lacking-capability error; only a plugin or the command bar could run it. The
section now states the version requirement and tells you to set it at author time on older clients.

Two guards against over-correcting:

- **`MeshPart.RenderFidelity` was NOT relaxed** — MeshPart overrides the property and it remains
  `PluginSecurity`. So on a MeshPart, `CollisionFidelity` is now scriptable and `RenderFidelity`
  still is not.
- **The gate moved rather than vanished.** Each relaxed member gained
  `Capabilities.Write: ["PluginOrOpenCloud"]`. Capabilities apply only inside an opt-in sandboxed
  container, and `PluginOrOpenCloud` is not listed on the public Script capabilities page — so that
  path is flagged as test-it-yourself rather than asserted.

`Lighting.LightingStyle` (`Realistic`/`Soft`) and `Lighting.PrioritizeLightingQuality` also moved
from `RobloxScriptSecurity` to developer-writable.

### Engine 0.740 — additions

`+TeleportOptions.ReservedServerId`, `+TeleportOptions.VipServerId`, `Enum.TeleportMethod`
+`TeleportSwitchServer`, `+AudioTextToSpeech.AutoLocalize`, `+InputAction.DisplayName` (now shown in
the IAS example in `project-structure.md`), `+WrapTextureTransfer:PrepareProjectionMeshDataAsync`.

Recorded but **not usable**: `CaptureService:StartVideoCaptureForMCPAsync` /
`StopVideoCaptureForMCP` are `RobloxScriptSecurity`. Noted only because the naming suggests Studio
MCP is growing a video-capture path; no MCP tool exposes it and you cannot call it.

### Luau 0.739

- **Generics are typechecked more strictly inside function bodies.** The one item here that can
  surface **new errors in code that previously passed** — `fn(nil)` against a `(T) -> T` parameter
  was wrongly accepted and now errors. It is a soundness fix, not a regression, and
  `luau-fundamentals.md` now says where to look when `--!strict` starts complaining after a Studio
  update.
- **`if local` *expressions*** added to the experimental prototype (statements landed in 0.737).
  Still behind `DebugLuau*` flags, described by the release notes as unstable, and **not enabled in
  Roblox Studio** — called out explicitly because it is exactly the kind of release-note item an
  agent will offer as a shipped feature.
- VM: Luau→Luau metamethod calls inlined, table get/set slow paths faster, and a **metamethod lookup
  cache on frozen metatables** — which gives `table.freeze` on a metatable a second mechanical
  benefit beyond immutability. An integer overflow after `table.move` that caused an out-of-bounds
  access was fixed.
- Still **no new standard-library function** across 0.736–0.739.

### Fixed — misleading items found while ingesting

- **`Sandboxed = true` was presented as protection without its prerequisite.** `security-hardening.md`
  advised sandboxing third-party models, but script capabilities are **experimental / client beta and
  off by default**: `Workspace.SandboxedInstanceMode` must be changed from `Default` to
  `Experimental` first, or marking a model `Sandboxed` constrains nothing. Added, with the real
  error format and capability categories, sourced to the official page.
- **`.current-version` has no `checkedAt` field after a fresh download.** The monitor script writes
  `updatedAt` when it downloads and `checkedAt` only when it finds you are already current, so
  `SKILL.md`'s "if `checkedAt` is older than 7 days" silently found nothing right after an update.
  It now reads whichever is present.
- **The documented measurement command was broken.** `stat -f %z ~/RobloxDocs/…/latest.json` reports
  the **75-byte symlink**, not the 8.3 MB dump. Now `stat -Lf %z`, with the reason inline.
- **`LOP_FASTPCALL` was still described as "~2x faster" in `luau-fundamentals.md`** even though
  `performance-optimization.md` had already been corrected to the release note's actual "around two
  times lower" (halved overhead, not free). The two files now agree.

---

## 2.10.0 — Sep 25, 2026

**Accuracy pass on the MCP layer, and a new trust boundary.** No engine ingest in this entry —
reference content reflected engine 0.739.0.7390687 / Luau 0.738 at the time; 2.11.0 above carries
the 0.740 ingest.

### Added

- **`references/agent-safety.md`** — a threat model for the **agent → Studio** boundary, which the
  skill previously covered in four bullet points of etiquette while spending ~600 lines on the
  player → server boundary. Covers: what plugin-level privilege actually reaches, why Ctrl+Z is
  not a safety net, the `studio_id` mis-targeting failure, `Server`-datamodel writes hitting
  production DataStores, confirm-first and never-do rules, a pre-flight sequence, treating place
  content (comments, instance names, console text) as data rather than instructions, and an
  explicit statement that **a skill documents and cannot enforce** — only the host's permission
  layer can.
- **`CHANGELOG.md`** (this file). The README's update table had grown to 11 rows of dense release
  notes; the README now shows three.
- `skill` and `subagent` MCP tools documented — both are official and were missing entirely.
  Roblox ships seven first-party `rbx-*` skills (`rbx-debug`, `rbx-perf-profiling`,
  `rbx-scene-analysis`, `rbx-device-simulator-lua`, `rbx-docs-search`, `rbx-unit-test`,
  `rbx-create-skill`) that are narrower and more current than this skill on their topics.
- MCP setup section: `stdio` transport, the local binary paths, quick-connect client list, JSON
  config, and the verification/troubleshooting steps — all from the official page.
- A **Corrections Log** table in `mcp-integration.md`, so an agent carrying an older copy in
  context does not reintroduce a fixed error.

### Fixed — MCP claims that were wrong

Each verified 2026-09-25 against
[the official docs page](https://create.roblox.com/docs/studio/mcp) and the live tool schemas of
the installed server.

- **`run_as_job` does not exist.** It was listed as a tool in both `SKILL.md` and
  `mcp-integration.md` — added by v2.7.0's own accuracy pass, ironically, while removing a
  different phantom tool. Async is a **per-tool `async: true` argument** that returns a `jobId`;
  `wait_job_finished` consumes that id.
- **`multi_edit` was documented with a fabricated signature.** The file claimed it edits *multiple
  scripts* via `{scriptPath, newSource}` entries. It actually applies **several edits to one
  script**: `file_path` + `edits[{old_string, new_string, replace_all}]`, sequential exact-match
  replacements, atomic per call, `className` when creating. An agent following the old text would
  have failed every call.
- **`multi_edit` accepts `datamodel_type: "Edit"` only** — it cannot edit scripts during a
  playtest. The Debug Loop workflow showed `multi_edit` *inside* the playtest loop; it now stops
  the playtest first.
- **`execute_luau` returns the result or the error.** The file asserted that "MCP tools do not
  return Luau values directly" and that `print()` was the only way to get values out. Wrong on
  both counts.
- **`upload_image` and `store_image` were misdescribed.** `upload_image` takes a **batch of
  HTTP(S) URLs** and returns an imagePath→assetId map. `store_image` is the local-file path
  (png/jpg/jpeg, ≤5 MB) and returns an `IMAGEID_<id>` URI — **not** an asset ID.
- **`http_get` is allowlisted**, not a general fetcher. Only Roblox docs domains plus
  `github.com/Roblox/libmp`, and the URL must end in `.md` or be `llms.txt` — so `llms-full.txt`
  and `openapi.json` are rejected. The file described it as "Fetch a URL from inside Studio".
- **Tool count**: "29 tools observed" → **26 documented officially, 28 in the observed build**
  (`generate_texture` and `segment_mesh` exist but are undocumented, and are now flagged as such).
- Undocumented limits added: `script_search` returns ≤10 fuzzy results, `script_grep` is capped at
  50 matches, `script_read` supports line ranges and returns `LINE→CONTENT`, `wait_job_finished`
  defaults to a 600 s timeout.
- `search_asset` searches the **Creator Store + Creator Inventory** with type/price/tag/scope
  filters, not "the marketplace / Toolbox".
- `subagent` types are **build-dependent** — the docs name `explore` and `playtest`; the observed
  build advertised `explore`, `screen_capture`, `unit_test`. Read the schema instead of hardcoding.

### Fixed — misleading claims elsewhere

- **The README described this repo as if it were an MCP server.** It is a skill: no tools, no
  transport, no execute surface. Both the README and `mcp-integration.md` now say so in the first
  paragraph, and the `mcp` GitHub topic is explained as *client integration*.
- **The README's directory tree listed only 11 of the 12 reference files** — it omitted
  `studio-plugins-and-limits.md`, which v2.7.0 had added to the routing table but not to the tree.
  Readers counting files in the README got the wrong number.
- **The tree's file counts were stale and self-contradictory**: "914 class JSONs (~10KB each)"
  against 925 actual, and a "~10KB" figure that the README's own measured note (median ~2 KB)
  refutes two paragraphs later. Same `~10KB` claim removed from `SKILL.md`.
- **`SKILL.md` told the agent to fire `roblox-api-monitor.sh &` automatically** when local data
  looked stale — contradicting its own Knowledge Freshness Check ("NEVER auto-update without user
  approval") and the README's "there is no background job". Staleness now falls through to the web
  sources and *offers* a refresh.
- **The engine stamp was made honest about the gap.** A live check on 2026-09-25 returned engine
  `0.740.19.7400931` and Luau `0.739`, and `SKILL.md` recorded that pair as **not ingested** rather
  than leaving a bare "verified" date that implies currency. *(Superseded the same day by 2.11.0,
  which ingested it.)*

---

## 2.9.0 — Sep 17, 2026

Engine 0.739.0.7390687 (Luau **unchanged** at 0.738 — engine-only bump, no language changes).
Dump re-split: 925 classes / 636 enums / 259 services / 48 deprecated.

Local 0.738→0.739 diff: +4 classes (`AdPlacement`, `ExternalIdentityService`, `QueueService`,
`StandardQueue`); `CallingService.CreateCall` → **`CreateCallAsync`** (renamed, now Yields —
breaking); +`UGCValidationService:GetLayeredClothingPostDeformationSizeAsync`;
+`StateMachineTransitionDefinition` {From, To, Priority, TransitionId}; +Terrain
`Set`/`ReplaceMaterialInTransformSubregionSlot`; +`ChatWindowConfiguration.TextChannelDisplayMode`;
+3 enums (`AnimationNodeBlendMode`, `QueueDecision`, `TextChannelDisplayMode`);
`AnimationNodeType` +OneShotNode/+StateMachineNode; `PromptCreateOutfitResult`
+UGCValidationFailed.

---

## 2.8.0 — Sep 12, 2026

Engine 0.738.0.7381393 + Luau 0.738 (2026-09-11). Dump re-split: 921 classes / 633 enums /
257 services.

Local 0.737→0.738 diff: `GuiObject:TweenPosition`/`TweenSize`/`TweenSizeAndPosition` and
`.Transparency` newly deprecated; `DataModelPatchService` removed; +`AnimatedImageService` /
`AnimatedImage` / `AnimatedImageTrack`, +`MomentsService`, +`RunService:BindToAnimation`,
+`Workspace.StreamingAdaptiveRadius`, +`TextChannel.AddPlayersOnJoin`.

Luau 0.738 = inference fixes plus two more flag-gated prototypes (`coroutine.finally`, mandatory
top-level annotations); no new stdlib functions.

---

## 2.7.0 — Sep 6, 2026

Engine 0.737.0.7371584 + Luau 0.737. Dump re-split: 916 classes / 629 enums / 256 services.

**Accuracy pass** — removed the non-existent `set_active_studio` MCP tool and the unreproducible
"845×" figure; corrected Context7's tool name (`get-library-docs`, not `query-docs`); stopped
presenting `/roblox-update` as a registered slash command; dropped the invented "2-5x"
native-codegen speedup and documented its real server-only scope and costs; softened
"self-updating" to what actually happens; added `studio-plugins-and-limits.md` to the routing
table; recorded that `script_grep`'s line numbers are unreliable.

> This pass also *introduced* the phantom `run_as_job` tool, fixed in 2.10.0.

---

## 2.6.0 — Aug 28, 2026

Engine 0.736.0.7361346. Full API dump to 914 classes (+`StateMachineDefinition`,
+`StateMachineTransitionDefinition`), 623 enums (+`AnimationNodeTransitionWhen`),
+`ServerLowMemoryWarning`, +`CreateDecalAsync`, emissive decals.

---

## 2.5.0 — Aug 27, 2026

Engine & Luau 0.735. Dump 0.735.0.7351131 (912 classes, +`BranchService`, +`IntentService`,
+`PlayerControlState`, +`ScriptScannerService`). `LOP_FASTPCALL` (pcall/xpcall overhead around two
times lower), type function enhancements, `setmetatable` inference.

---

## 2.4.0 — Aug 11, 2026

Local-first `~/RobloxDocs/` lookup: pre-split per-class JSON prioritized over live web sources.
Obsolescence check via `.current-version`. Monitor script rewritten with `uname`-based platform
detection. Deprecated lookup made local-first.

> The motivation was **token cost and offline resilience**, not security. Later framing that
> treated local-first as a security decision would be revisionist.

---

## 2.3.0 — Aug 11, 2026

Deep reference refresh: 7 files updated with `UIFlexItem`, ZSTD, Subscriptions,
`MemoryStoreService`, and the RunService frame pipeline.

---

## 2.2.0 — Aug 11, 2026

Fixed a broken deprecated-API URL; added Open Cloud `llms.txt` discovery and the OpenAPI spec.

---

## 2.1.0 — Jun 27, 2026

Added `file-formats-and-assets.md` and the official-docs lookup section.

---

## 2.0.0 — Jun 25, 2026

Mid-2026 deep refresh: monetization, `StyleQuery`, `BanAsync`, 12+ deprecated APIs.

---

## 1.0.0 — Jun 25, 2026

Initial release: 9 reference files, `SKILL.md` router, MCP integration.
