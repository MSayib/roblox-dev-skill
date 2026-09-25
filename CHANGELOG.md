# Changelog

All notable changes to `roblox-dev-skill`. Newest first.

The README carries only the **three most recent** versions; this file is the full history.
Machine-readable entries, with the verification method used for each, live in
[`metadata.json`](metadata.json) under `update_history`.

**Version numbers track this skill, not Roblox.** An entry's engine/Luau version records what the
reference content was verified against at that time.

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
