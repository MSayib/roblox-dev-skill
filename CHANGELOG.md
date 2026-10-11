# Changelog

All notable changes to `roblox-dev-skill`. Newest first.

The README carries only the **three most recent** versions; this file is the full history.
Machine-readable entries, with the verification method used for each, live in
[`metadata.json`](metadata.json) under `update_history`.

**Version numbers track this skill, not Roblox.** An entry's engine/Luau version records what the
reference content was verified against at that time.

---

## 2.17.0 — Oct 11, 2026

**Every claim checked, the fragments run, and the important examples assert what they do.** No
engine change (0.742.0.7421053 / Luau 0.742). Three new test layers: preludes that let the 48
fragment blocks run, behavioural expectations on 27 blocks, and a claims register covering every
high-risk prose line (652 claims: 187 run in Studio, 165 official docs, 64 API dump, 74 source,
104 advice, **0 unverified**). Verifying them found **58 wrong statements**, each fixed and kept as
a regression guard. Every result below is from Studio 0.742 in the owner's test place through Rojo
on port 34871 (place 118652544255235), with all layers re-run after the last edit: server 97/97
cases and 20/20 expectations, client 27/27 and 5/5, plugin 3/3 and 2/2, static 0 unexplained
findings, API audit 0 defects.

### Fixed — found by running the 48 fragments for the first time

- **`monetization.md` subscription handler used an event that does not exist.**
  `MarketplaceService.SubscriptionStatusChanged` is not a member (API dump 0.742; the
  `MarketplaceService.UserSubscriptionStatusChanged` that does exist is RobloxScriptSecurity). The
  event a game Script receives is `Players.UserSubscriptionStatusChanged(user, subscriptionId)`,
  which carries no status, so the example now re-reads it with `GetUserSubscriptionStatusAsync`
  and changes nothing when that check fails. Added when it fires (official `Players` reference).
  The API audit did not flag this; the strict type check of the fragment with its prelude did.
- **`security-hardening.md` rate limiting measured time with `time()`.** `time()` is game time,
  which falls behind real time while the server is busy: twice, a `task.wait(0.7)` early in a busy
  server took 3.0–3.2 s by `os.clock()` while `time()` advanced 0.36–0.44 s, so the token bucket
  (the official *Client-server boundary* sample uses `time()` too) refused a player sending at the
  allowed rate. The token bucket and the cooldown example now use `os.clock()` (official reference:
  real elapsed time, unaffected by system clock changes). The note says where this departs from
  the official sample.
- **`legacy-migration.md` used the deprecated `PlayerOwnsAsset`.** Now `PlayerOwnsAssetAsync`.
- **`ui-systems.md` ScreenGui example failed `--!strict`.** `player.PlayerGui` is a child, not a
  property; now `player:WaitForChild("PlayerGui")`.

### Fixed — found by verifying SKILL.md claim by claim

- **Context7's tools were named backwards.** SKILL.md said the second tool is `get-library-docs`
  and that `query-docs` does not exist; the upstash/context7 README (2026-10-11) lists
  `resolve-library-id` and `query-docs`. Same fix in `worked-examples.md`.
- **"`script_read` first or `multi_edit` simply fails" was false.** A `multi_edit` on a script
  never read succeeded (Studio 0.742). Atomicity was confirmed: a call with one non-matching edit
  failed and left the script unchanged.
- **"263 services" counted names, not services.** It is the number of classes named `*Service`
  (the local `services/` folder); 343 classes carry the `Service` tag. "48 deprecated" is
  classes; 477 members are deprecated. Reworded in SKILL.md and `legacy-migration.md`.
- **MCP tool count**: the docs page still lists 26 tools; the connected build now exposes 30
  (`list_plugin_guis` and `capture_plugin_gui` added to the table).
- **`script_grep` line numbers**: the 15-line offset seen on 2026-09-06 did not reproduce in two
  tests on 0.742; the text now says so and still says to confirm with `script_read`.
- Dump size figures re-measured on 0.742 (8,438,918 B; 940 class files).

### Fixed — found by verifying `legacy-migration.md` claim by claim

Every dump claim was re-derived from the local dumps 0.733–0.742 (81 assertions; older releases
from the Roblox-Client-Tracker mirror of the official dump), every *(Studio)* row of the 0.742
table re-run from playtest Scripts, and every dated platform change traced to a Roblox staff post.

- **Scoped User IDs are not rolling out in October 2026.** A staff update on 2026-09-01 delayed
  the rollout and promised a new timeline in October; none had been posted by 2026-10-11. Fixed in
  `legacy-migration.md` and `security-hardening.md` (both said October 2026), and the "August
  2026" Account Linking date. The non-collision of scoped and global IDs, marked unverified, is now
  quoted from the official *Users* page.
- **`player.User.Id` is not `player.UserId`.** Measured in a playtest: the same returning player
  had 8935399566 and 1237928291809. The advice to adopt `player.User` now warns not to re-key
  existing saves.
- **The New Type Solver is not on for `--!strict` by default.** The general-release post
  (2025-11-20) turned it on for nonstrict/nocheck only; Studio 0.742 still publishes
  `DFFlagStudioLuauNewSolverOptOutPlacesWithStrictScripts = True`. The opt-in is
  `Workspace.UseNewLuauTypeSolver` (Properties window). `luau-fundamentals.md` says so too. The
  section's example claimed an error the code does not produce (and that the old solver reports
  as well); replaced by one that only the new solver reports, checked with both.
- **The April 2026 migration actions were swapped.** The removed `economy.roblox.com` endpoint is a
  purchase flow (migrate to in-experience `MarketplaceService`), and the April 23 deprecation is of
  game pass / developer product *management* endpoints (migrate to Open Cloud). The publishing fee
  row now says it is refundable and an alternative to Plus/Premium for all-ages publishing.
- **Mid-June removals had nothing to migrate**: the `Accoutrement` and `AdService`/`AdGui` members
  removed in 0.725–0.726 were all `RobloxSecurity`/`Hidden` or `NotScriptable`.
- `DataModelPatchService` was not `NotBrowsable` and lived from at least 0.733 to 0.737, not one
  release; `TestService.RegisterTest` predates 0.742 (the new members are `RegisterSuite`,
  `ListTests`, `RunTestsAsync`, `ResetTestRegistry`, `TestRegistryChanged`); 0.741 did remove 15
  `StarterPlayer.GameSettings*` properties; "2024" for the RunService renames had no source;
  `LuauTypeCheckMode` and `HumanoidRigDescription.OriginOffset` cannot even be read by a Script.

### Fixed — found by verifying `performance-optimization.md` claim by claim

- **`RunService.PreAnimation` is not client-only.** A server Script counted 104 firings in 2 s
  (Studio 0.742), the same as `PreSimulation`. `PreRender` connects on the server but never fires,
  and `RenderStepped` errors there; the table now says so.
- **`RocketPropulsion`'s replacement is `LineForce`** (the dump's `PreferredDescriptorName`), not
  `LinearVelocity` + `AlignOrientation`.
- **`Workspace.PhysicsSteppingMethod = Adaptive` looked like code**; it is `NotScriptable` (a Script
  reading it gets "not a valid member"). Now: set it in the Properties window; up to 2.5× per the
  official page.
- Two statements had no source and were replaced by what the official *Improve performance* page
  says: "unions can't benefit from instancing" (the page documents instancing for MeshParts only)
  and "the engine auto-scales textures based on device memory and distance".
- The `Local Safe` thread-safety row now matches the official table (other Actors may read);
  "a `--!native` client script gains nothing" now says only what the docs say (server-side).

### Fixed — found by verifying `luau-fundamentals.md` claim by claim

Every release-note row (0.736–0.742) was matched against the GitHub release text, every gate
against the 0.737–0.742 source tarballs, and the beta claims against the staff posts.

- **"Runtime heap limits" for type functions do not apply in Roblox.** The limit is
  `DebugLuauTypeFunctionRuntimeHeapLimit`, default 0 and unset in Studio's flags. The
  `pcall`/`xpcall` part is right for Luau 0.742 (`TypeFunctionRuntime.cpp` registers the base
  library and removes only `gcinfo`, `getfenv`, `newproxy`, `setfenv`), but luau-lsp 1.69 still
  rejects it; the text now says both.
- **`DebugLuauUserDefinedClassesRuntime` is not new in 0.742**; it is in the 0.737 source and the
  0.737 release notes.
- "Team members without the beta cannot compile `if local`" is now tested: in a Studio 0.742
  without the beta, a game Script and a plugin `loadstring` both fail to parse it.

### Fixed — found by verifying `mcp-integration.md` claim by claim

- **"Without a read, `multi_edit` fails outright" was false** (same defect as in SKILL.md, a second
  copy): a matching edit on a never-read script succeeds. A guessed `old_string` does fail.
- **Tool count 28 → 30**: `list_plugin_guis` and `capture_plugin_gui` added to the table.
- **"Destroying core services crashes Studio"** was never tested; removed (the advice stays).
  **"Invalid JSON fails silently"** became the official wording ("prevent the configuration from
  loading").
- Re-verified 2026-10-11: the archived Rust server repo, the `http_get` allowlist
  (`openapi.json` rejected too), `NotScriptable` reads failing even through `execute_luau` on 0.742,
  `ScriptDebuggerService` all `PluginSecurity`, the `subagent` types, the seven `rbx-*` skills.

### Fixed — found by verifying `security-hardening.md` claim by claim

- **Server Authority is fully released** (2026-07-09, Roblox staff); the section still called it a
  client beta and quoted a sentence the official pages no longer contain. Rewritten from the
  release posts and the official setup list, with which settings a script cannot change
  (`AuthorityMode` is `RobloxScriptSecurity`, the rest `NotScriptable` or plugin-only).
- The UTF-8 rule is now measured: an invalid value fails `SetAsync` with error 104; an invalid
  key was accepted.
- Re-verified: NaN behaviour (playtest), device blocking (desktop only, 24 h; staff post
  2026-06-04 and the `BanAsync` reference), Script Capabilities (client beta, `Unassigned`,
  the quoted error), decompilation of replicated modules, server-only data stores.

### Added — found by verifying `worked-examples.md`

- **`MarketplaceService:BindReceiptHandler` for developer products.** The official reference now
  calls `ProcessReceipt` "legacy" and documents per-product (or catch-all) handlers returning
  `Enum.ReceiptDecision`; bound handlers take precedence and unmatched receipts fall through. It
  has been in the dump since at least 0.733, and a game Script registered both forms in Studio
  0.742. `monetization.md` and `worked-examples.md` §6 now say so (the tested `ProcessReceipt`
  example stays; a full purchase through `BindReceiptHandler` was not run).
- Every other claim in the file held: its verification sections were run in 2.16.0 and the
  receipt and migration ones again today as harness expectations.

### Fixed — found by verifying `datastore-persistence.md` claim by claim

- **The MemoryStore limits table was wrong in five places.** Sorted map values and queue items are
  32 KB, not 1 KB (measured: 32 KB accepted, 33 KB `ItemValueSizeTooLarge`); the request quota is
  `1000 + 120 × concurrent users` request units shared by all calls, not `1000 + 100 × players`
  each for read and write; memory is `64 KB + 1.2 KB × users` per game, not "64 MB per
  partition" (a playtest reported a 65,536-byte quota); expiration is 0–3,888,000 s, there is no
  10-second minimum (`InvalidExpirationTime` quotes the range). Rewritten from the official pages
  and the measurements.
- **DataStore2 is Kampfkarren's module**, not berezaa's (berezaa conceived its default saving
  method). Its "deprecated" reasons now say what its source shows and that the label is this
  skill's advice, not a Roblox status.
- Measured: an `OrderedDataStore` rejects `1.5` and `"7"` with error 103 and accepts negative
  integers. ProfileStore's 300 s auto-save is settable with `ProfileStore.SetConstant`.

### Fixed — found by verifying `agent-safety.md`

- **Undo was described from history, not measured.** In Studio 0.742 every `execute_luau` call
  leaves an undo waypoint (`Assistant N`; `ChangeHistoryService:Undo()` removed a Part the previous
  call created), while a `multi_edit` did not leave its own: one Undo after it removed the script an
  earlier call had created. The advice ("do not rely on Ctrl+Z") stays, now on that evidence.
- "Destroying services crashes Studio" was untested here too; removed (the rule stays).

### Fixed — found by verifying `project-structure.md`

- **The server can read `StarterPlayerScripts`**; it is the per-player `PlayerScripts` copy it
  cannot see (nil on the server in a playtest, as the official reference says).
- **Server Authority is no longer "upcoming"** (full release 2026-07-09); the Character Controller
  Library is still a Studio beta. Studio Script Sync's full release is dated (2026-06-17).
- Measured: an object the server adds to `ReplicatedFirst` after a player joins never reaches that
  client, which backs "replicates only once".

### Fixed — found by verifying `networking.md`

- `UnreliableRemoteEvent` payloads over 1000 bytes are dropped but **not silently** (Studio logs the
  overflow), and its ~500/s throttle is counted separately from `RemoteEvent`'s; excess unreliable
  events are dropped while excess `RemoteEvent`s are processed later, in order.
- Measured: `BindableEvent:Fire` with a cyclic table errors ("tables cannot be cyclic") and strips
  metatables. The MessagingService limits table matches the official reference.

### Fixed — found by verifying `monetization.md` claim by claim

Every dated statement traced to its Roblox staff post or official page.

- **Robux transfer limits for 2-step verification (5,000/day, 10,000/month) and an "under 16" rule
  had no source.** Roblox's FAQ gives 500 per day and 1,000 per month and says it is "intentionally
  starting with this limit"; the unsourced rows are gone. The age rule is now the official one:
  18+ must be age checked; under 18 needs a linked parent and approval for every transfer, sender
  and recipient alike.
- **Roblox Plus does not replace Premium** (the announcement says Premium still grants marketplace
  access); the rollout date is 2026-04-30.
- **The publishing fee is refunded 90 days after the game becomes eligible** (or 90 days after
  payment), not "after 60+ days of maintained engagement"; it is forfeited only on permanent
  removal for severe violations; Plus or Premium waives it.
- The quoted reason for ending cross-game sales now quotes Roblox exactly ("were never designed
  for"; the old text added "originally" inside the quote). Managed Pricing is dated (2026-06-15)
  and its 60,000-transaction and 90-day figures match the official pages.

### Fixed — found by verifying `ui-systems.md`

- **Per-corner `UICorner` rounding does not need a beta.** It and `UIShadow` were fully released and
  made publishable on 2026-06-23, and the "New UI Capabilities" flag was removed. The official
  `UICorner` reference still says "currently in beta"; the text now says which source is newer.
- StyleQuery's full release is dated (2026-05-11). UIShadow's `ZIndex`, text and gradient limits
  match the official reference.

### Fixed — found by verifying `file-formats-and-assets.md`

- **"Code that only checks legacy property names will miss assets saved by modern Studio" was not
  borne out**: a place Studio saved in August 2026 stores `MeshId`, `TextureID`, `SoundId`,
  `AnimationId` and `Image` (legacy names) and only `EmissiveMaskContent` among `*Content` names.
  The advice to check both names stays, with the measurement.
- "Studio writes ZSTD since ~2025" had no source for the year; "all 2,984 chunks used ZSTD" was
  2,983 plus the uncompressed `END` chunk; "animated GIFs are static" is undocumented and untested,
  now said as such. Place size, audio limits, Importer defaults and auto-recovery match the
  official pages; `rbxfile` depends on an LZ4 codec only.

### Added — claims register

- `tools/skill-test/claims.json` + `check_claims.py` + generated `docs/claims.md`: every
  high-risk prose line (numbers, versions, "cannot / only / not enabled / deprecated") is
  registered; stale quotes fail; text verified wrong is guarded against coming back; prose API
  mentions are checked against the dump. First pass: SKILL.md fully classified (20 studio,
  3 docs, 2 dump, 11 source, 17 advice, 0 unverified); 8 regression guards across the files; the reference files
  are seeded as unverified (490) and are verified next, highest risk first.

### Added — tests

- **Preludes** (`tools/skill-test/preludes/`, 26) supply the reader's names, declared with an HTML
  comment above the fence that the rendered page does not show. Fragments with unresolved names:
  48 → 1 (the `if local` beta-syntax block, which cannot run in a game). Skipped cases 54 → 9
  (beta syntax, legacy, anti-pattern, placeholder, and four that ban, teleport or prompt a purchase).
- **Expectations** (`tools/skill-test/expect/`, 22 files on 27 blocks) assert behaviour, not just "no error": the pool
  is back to 10 and a double release is ignored; two new players do not share an Inventory; a
  receipt is granted once and stays retryable when not ready; v1 and v2 saves migrate to v3 and a
  v4 save is refused; the token bucket allows 10, refuses the 11th and refills; table library
  results; the DataStore2 migration merges once; UI properties (UIShadow, per-corner UICorner,
  tween end state, disconnected connections); plugin-level `UpdateSourceAsync` and the
  CollisionFidelity loop.
- **Harness**: a client reporter next to the server one, expectation results, `Infinite yield`
  detection that tells a child that never arrived from one that arrived late, and a plugin-level
  runner (`run_plugin_cases.luau`) for blocks a game Script cannot run.
- Results, Studio 0.742: server 97/97 cases, 20/20 expectations; client 27/27, 5/5; plugin 3/3,
  2/2; 0 runtime errors, 0 infinite yields. Static: 136 blocks, 0 unexplained findings. API audit:
  0 defects.

### Fixed — test tooling

- The directive parser let `\s+` cross a line end, so a value-less directive (`client`) swallowed
  the next line. A prelude's dependency was lost this way; in-block `plugin`/`client` directives
  had carried the following comment as their value.
- Expectation results no longer live in attributes on the case script: in a playtest they were
  written, then found cleared on the original scripts after the run (a clone of the same script
  kept them; cause not established). They go to `shared.SkillTestResults`.

---

## 2.16.0 — Oct 11, 2026

**Every code example tested: type-checked under `--!strict`, then run in a real Studio place.** No
engine change (still 0.742.0.7421053 / Luau 0.742). The skill's 130 Luau blocks were checked by
two new layers, and the worked examples' own verification steps were executed as written. Eleven
defects were found and fixed; several had shipped since the initial release. Every item below was
reproduced before it was fixed and re-run after.

### Fixed — examples that could not run or did the wrong thing

- **`ui-systems.md` shop controller could not compile.** A line starting with `(` after
  `entry.Visible = true` is "Ambiguous syntax" in Luau; the Roblox compiler rejected the whole
  LocalScript (seen in Studio). Rewritten with locals.
- **`project-structure.md` PlayerDataService leaked data between players and could wipe saves.**
  `table.clone(DEFAULT_DATA)` is shallow, so every new player shared one `Inventory` table
  (reproduced: an item given to player A appeared for player B and in the default). Worse, a
  *failed* `GetAsync` fell back to defaults, which the next save wrote over the player's real data.
  Now a fresh default per player, a kick instead of defaults on a failed read, a warning on a failed
  save, and `BindToClose`.
- **`performance-optimization.md` object pool leaked every object.** `npcPool:acquire(npcPool)` and
  `npcPool:release(npcPool, npc)` passed `self` twice, so `release` received the pool as the item
  (reproduced: `available` fell from 10 to 4 in six cycles). Rewritten with correct calls and
  New-Solver types (`setmetatable<...>`).
- **`monetization.md` charged players for items it did not give.** `local success = pcall(handler,
  player)` ignored the handler's `false`, so a failed grant returned `PurchaseGranted`. Now
  `ok and granted == true`, with an idempotency note. Roblox's own sample has the same `if success`
  check.
- **`legacy-migration.md` passed a signal where ProfileStore expects a function**
  (`Cancel = player.AncestryChanged`; the official signature is `Cancel: fn() -> (boolean)?`).
- **`luau-fundamentals.md` taught a directive form that switches strict mode off.**
  `--!strict    -- comment` is ignored with "Comment directive ... has extra symbols at the end of
  the line" (verified with luau-analyze 0.742: a type error in such a file goes unreported). Now a
  table, and an explicit warning.
- **`luau-fundamentals.md` generalized-iteration example errored under `--!strict`** ("Cannot iterate
  over a table without indexer"). The table is now annotated as a map.
- **`performance-optimization.md` Parallel Luau example failed outside an Actor**
  ("Scripts that connect in parallel must be rooted under an Actor", seen in Studio), showed
  `ConnectParallel` under a `task.desynchronize` heading, and said an `Actor` inherits from
  `DataModel` (it is `Actor` → `Model` → `PVInstance` → `Instance`).
- **`studio-plugins-and-limits.md` ignored `TryBeginRecording` returning `nil`.** It does return
  `nil` inside MCP `execute_luau` (tested), and `FinishRecording(nil)` then errors.
- **`worked-examples.md` §1 verification could not work.** It said to fire the remote from a
  *Server* `execute_luau`; a server cannot raise its own `OnServerEvent`. Now fired from the Client
  datamodel, asserting on what the server can observe. Run as written: all junk rejected, the valid
  claim accepted, a repeat claim rejected.
- **Strict type errors** in `security-hardening.md` (`Position` on an `Instance`),
  `project-structure.md` (calling into an untyped `require`, `ReplicatedStorage.Remotes`), and
  `game.ServerStorage` / `game.ServerScriptService` instead of `GetService` in four places.

### Added

- **Runtime fidelity path.** A game Script cannot write `CollisionFidelity`, but
  `AssetService:CreateMeshPartAsync(meshContent, { CollisionFidelity = ..., RenderFidelity = ... })`
  + `MeshPart:ApplyMesh` changes it at runtime (tested from a plain Script; large meshes are
  rejected).
- **Worked examples 6–8**, each run in Studio: granting a developer product idempotently
  (`ReceiptHandler`, five receipt cases against a real DataStore), migrating saved data by version
  (`PlayerDataSchema`, v1→v3, future versions refused, a DataStore round trip), and opening a menu
  from an Input Action (a real `B` key press via MCP `user_keyboard_input`).
- **`tools/skill-test/`**: `extract_blocks.py`, `run_static.py` (luau-lsp, New Type Solver, every
  block in strict mode, game-Script definitions, plugin definitions for plugin blocks) and a Studio
  runtime harness synced by Rojo on port 34871 (each block as its own `Script`, `LocalScript`, or
  inside an `Actor`; fixtures for the remotes, GUIs and modules the examples need; the official
  ProfileStore fetched at build time). Result: 136 blocks, 0 unexplained static findings; 73 server
  and 9 client cases, 0 runtime errors, 0 infinite yields. See `docs/testing.md`.
- **Audit:** bare member names in prose (`` `Class` (`MemberA`, `MemberB`) ``) are now resolved
  against their class; security-level labels in that position are not mistaken for members.
- **`tests/e2e/`**: `test_install_e2e.sh` installs into a throwaway home, validates the payload,
  proves Claude Code lists the skill at startup (with a negative control) and uninstalls cleanly;
  `run_evals.py` runs evals headless through `claude -p` with no MCP servers and read-only tools.
  CI runs the static layer and the install E2E.
- **Evals 52 → 58** for the defects above.

### Changed

- **Skill description rewritten, and measured.** It told agents to route monetization, UI, audio
  and VFX to "their respective skills in the suite", which this repository does not ship, and gave
  no reason to open the skill for a question the model thinks it knows. Measured with
  `tests/e2e/run_evals.py` on 13 evals through Claude Code (Opus 5.5, no MCP, read-only tools):
  the old description triggered the skill on **2 of 11** Roblox prompts, the new one on **10 of
  11**; both negative prompts (Redis Lua, a WoW addon) stayed untriggered. Without the skill, two
  answers quoted a wrong error message ("lacking capability Plugin") and one presented an untested
  workaround as working; with it, every triggered answer met its eval's notes. The one prompt still
  answered without the skill (#56, the `--!strict -- comment` directive) was answered correctly.
  Adding "Luau type errors and --!strict" to the description did not change that, so it was not
  kept.
- **README cut to an overview** (what it is, quick install, what's inside, how it stays correct);
  the details moved to `docs/installation.md`, `docs/robloxdocs.md`, `docs/how-it-works.md` and
  `docs/testing.md`, which the installer now ships with the skill.
- The maintainer's Claude Code link was named `roblox-dev`, which the spec rejects; renamed to
  `roblox-dev-skill`.

### Roadmap closed

All three open items shipped: wider worked examples (§6–8), a real parser for the examples (the
luau-lsp layer, which type-checks every block instead of matching it with regular expressions), and
bare member names in prose. The weekly ingest stays a routine, not a roadmap item. The README no
longer carries a roadmap.

---

## 2.15.0 — Oct 11, 2026

**Engine 0.742.0.7421053 / Luau 0.742, with every developer-visible change run in Studio, and a
correction to a claim this skill had made since 2.11.0.** Engine 0.742 went live on all four
platforms (Windows and Mac, Studio and Player). Every row below marked *tested* was run in Studio
0.742.0.7421053 on an empty baseplate. The probes ran from an ordinary server `Script`
(`Sandboxed = false`) or a `LocalScript` during a playtest, and from MCP `execute_luau` for the
plugin / command-bar level. The probe scripts were removed afterwards.

### Corrected — `PluginOrOpenCloud` blocks ordinary game Scripts

2.11.0 read the 0.740 dump, saw `CollisionFidelity`, `FluidFidelity`, `PartOperation.RenderFidelity`,
`SmoothingAngle`, `Lighting.LightingStyle` and `PrioritizeLightingQuality` go to `Security: None`
with a new `PluginOrOpenCloud` capability, and called them "script-writable at runtime". It also
said the capability "only applies inside a sandboxed container". Neither claim was ever run.

Tested in 0.742, a plain server Script fails on every one of those writes with
`The current thread cannot write '<Property>' (lacking capability PluginOrOpenCloud)`. The same
Script writes `Part.Color`, `Part.CanCollide` and `Humanoid.Health` (`AvatarBehavior`) without
error, and `execute_luau` (plugin level) writes all of them. So `Security: None` +
`PluginOrOpenCloud` is **plugin-only**. The capability metadata on these members did not change
from 0.740 to 0.742, so the old text was most likely wrong from the start. 0.740 and 0.741 can no
longer be run to prove it.

- `performance-optimization.md` §3 is rewritten around the measured result. Its runtime
  `CollectionService` loop is now labelled command bar / plugin only.
  `legacy-migration.md`'s 0.740 rows, `security-hardening.md`'s capability table and
  `worked-examples.md`'s "read three fields" step are corrected the same way.
- `audit-skill-examples.py` treats a `PluginOrOpenCloud` read/write capability as plugin-only in
  section A, instead of section B's "only bites inside a sandboxed container". That alone was not
  enough: the 2.14.0 loop still passed as "plugin context", because its comment said "on older
  clients do this in Studio or a plugin". A comment now counts as plugin context only when it
  declares the block plugin-only ("command bar or plugin ONLY"). Code that uses plugin APIs still
  counts as before. Run against the 2.14.0 references, the audit now reports the loop as a DEFECT
  and exits 1. The current references pass with 0 defects.
- Evals #33 and #47 had encoded the wrong answer (the runtime loop as correct). Both now expect the
  loop to be refused for a game Script and offered for the command bar or a plugin.

### Engine 0.742 (940 classes +10 −1, 648 enums +8 −1, 263 services, 48 deprecated)

- **Seven more `PluginOrOpenCloud` relaxations, all still plugin-only (*tested*):**
  `Workspace.StreamingEnabled`, `FallenPartsDestroyHeight`, `FallHeightEnabled`,
  `LuauTypeCheckMode`, `Model.LevelOfDetail` (even reading fails), `MeshPart.RenderFidelity`, and
  `HumanoidRigDescription.OriginOffset`. `performance-optimization.md` had said
  "Enable via `Workspace.StreamingEnabled = true`". It now says Properties window: the official page
  calls the property not scriptable, and the write fails.
- **Present but not enabled (*tested*):** `Camera.ProjectionType` / `OrthographicSize` (writes are
  silently ignored), `MeshPart:GetSurfaceSlotsAsync()`, the `TestService` test registry,
  `MarketplaceService:CanUsersTransferRobuxAsync()` and `ModerationService:BindViolationProcessor()`,
  each with its own "not enabled" error. `Workspace.ReplicationFrequency` / `ReplicationThroughput`
  cannot even be read by a Script.
- **Usable (*tested*):** `Decal.ResampleMode` (read/write) and `SurfaceAppearance.SurfaceSlot`
  (read). `UIBlur` can be created and parented in `PlayerGui`, but whether it renders a blur was
  **not** verified.
- **Removed:** `AnimatedImage` and `Enum.AnimatedImagePlaybackState`. They were never usable: every
  member was `RobloxScriptSecurity`.
- No new page for any of these on create.roblox.com yet (checked in Roblox/creator-docs).

### Luau 0.742

- `coroutine.finally` is "no longer gated behind a debug flag". In the 0.742 source the flag was only
  renamed (`DebugLuauCoroutineFinally` → `LuauCoroutineFinally`, plus
  `LuauCoroutineFinallyAnalysis`) and still defaults to off. No Studio client setting enables it, and
  **`coroutine.finally` is `nil` in Studio 0.742** (*tested*, Script and command bar). New prototype
  flag: `DebugLuauUserDefinedClassesRuntime`.
- Analysis fixes (strict-mode scope handling, unifier rewrite rules, `~nil` refinement of blocked
  types, grouped `error` calls), a faster `string.gsub` for plain patterns, and compiler / NCG fixes.
  No new standard-library function is usable in Roblox.
- `if local` gates are unchanged, and the Studio beta flags are unchanged
  (`FFlagLuauIfLocalBetaFeature = True`, rollout 0%).

### Changed — `if local` / `if const` became a Studio beta on 2026-10-06

Roblox staff announced "If Local/Const Bindings" as a **Studio Beta Feature** (DevForum topic
4918297). The skill said the syntax was "not enabled in Roblox Studio", which stopped being true
the day after 2.14.0. Studio's published flags now set `FFlagLuauIfLocalBetaFeature = True` with a
rollout of 0%, so it is opt-in.

It is still **not usable in a game**: "Studio Betas are not enabled in published experiences … you
won't be able to use this in a published game until it's fully released" (Roblox staff, post #41).
`luau-fundamentals.md` gives it a section of its own: what the syntax does, why it fails for players
and for collaborators without the beta, the beta's limits (one name and one value, no multi-return
`pcall`, no compound conditions, no `while local` yet), and the rule. Game code keeps the plain
`local` + `if` form. `if local` is shown only to a user who is experimenting in Studio, with a note
that it must be rewritten before publishing.

### Luau 0.741 (checked Oct 7, 2026)

- Analysis: jump-to-definition works on function return annotations. A crash on a type assertion
  inside `typeof(...)` inside a type alias is fixed.
- Compiler register reuse after a local's last use, a GC allocation-rate underflow fix, and an NCG
  buffer range-check fix (only `--!native` code that uses `buffer`).
- `lua_setbuffercage` was renamed to `lua_setmemorycage`. This is C API only and no Roblox script can
  reach it, so the skill does not mention it.
- The feature gates are the same as in 0.740 (checked in the 0.741 source tarball). Exact tables,
  classes, `coroutine.finally` and the `integer` library are still off in Studio.

### Evals 47 → 52

- **#50**: `coroutine.finally` after the 0.742 release note. It is `nil` in Studio.
- **#51**: toggling `StreamingEnabled` from a server Script. It cannot be done. The answer offers
  `ModelStreamingMode` and `RequestStreamAroundAsync`, both run from a Script in Studio 0.742.
- **#52**: an over-correction guard. `Humanoid.Health` writes and `CollisionFidelity` reads work
  from a plain Script, so they must not be sent to a plugin.
- **#48**: "it works in playtest, can I publish?" The correct answer is no: rewrite every `if local`
  before publishing.
- **#49**: an over-correction guard. A user who has opted into the beta and wants to experiment in
  Studio gets `if local` code with the publish caveat, not a refusal.
- The notes for #35 and #45 now describe the beta status instead of "flag-gated, off".

---

## 2.14.0 — Oct 1, 2026

**Engine 0.741.19.7411056 / Luau 0.740 — and an audit that now reads prose, which found three more
latent defects.** None of the three was caused by 0.741; all were wrong on the day they were written.

### Engine 0.741 — additions (931 classes +7, 641 enums +6, 260 services, 48 deprecated)

Diffed 0.740 → 0.741 with `diff-api-dumps.py` and a second, independent all-fields diff; both agree.
No removals, no new deprecations, no `Capabilities` changes.

- **`Player:GetFriendsInServerAsync()`** — `Security: None`, Yields, no parameters, returns an
  `Array`, capabilities `Players` + `Social`. Not yet on the official `Player` page (checked
  2026-10-01), so the skill says to inspect a result rather than guess its fields.
- **`Enum.GradientType.Elliptical`** (Value 3) — present at runtime in Studio 0.741; the official
  enum page still lists only `Linear` and `Radial`.
- `TestService.Enabled` (read-only); `BackendReplicatedStorage` / `BackendServerScriptService` /
  `BackendServerStorage` — services with no members and no docs.
- Roblox-internal only: `FriendsCalling*` classes and enums, `ProjectService`, `AssetService` text
  content, `NotificationService` topics; 15 `StarterPlayer.GameSettings*` properties removed (all were
  `RobloxScriptSecurity`). `LocalizedTextureContent` / `LocalizedImageContent` write security changed;
  still unreadable by game code.

### Luau 0.740

- A soundness fix in function normalization can surface **new type errors** in code using
  intersections of function types.
- `if local` flags were **renamed** from `DebugLuauIfLocal*` to `LuauExperimentalIfLocal*`. The skill
  had said "only behind `DebugLuau*` flags", which became untrue. Still **off**: neither flag is set
  in Studio's published client settings (PCStudioApp / MacStudioApp, checked 2026-10-01).
- Exact-by-default tables (RFC #11) are `DebugLuau*`-gated; an `integer` library exists behind
  `LuauIntegerLibrary`, also not enabled in Studio. Recorded in a table of prototypes with their gates.

### Fixed — `legacy-migration.md` listed Roblox-internal APIs as usable since 0.737

The 0.737–0.739 rows called `CallingService`, `AnimatedImageService` / `AnimatedImage`,
`MomentsService`, `PinShortcutService`, `Decal.LocalizedTextureContent`, `ExternalIdentityService`,
`UGCValidationService` post-deformation sizing and `Terrain` transform-subregion slots "new public
surface" or "new methods". In the dump each row was derived from, every one of them is
`RobloxScriptSecurity`. The 0.739 `CreateCall` → `CreateCallAsync` row told readers to "update
callers" of a method no game script could ever call. Each row is corrected in place, and a
corrections note heads the 0.741 section. `AvatarEditorService:GetItemDetails()` (deprecated) was
recommended as an ownership check; its `Async` form's `Owned` field describes only the current user,
so the row now points at the Open Cloud Inventory API for server-side checks.

### Fixed — the IAS example still could not run after 2.12.0 fixed it

2.12.0 changed `workspace.PlayerScriptsUseInputActionSystem = true` to `= Enum.RolloutState.Enabled`.
The type was right, but the property is **`NotScriptable`**: no script can read or set it, MCP
`execute_luau` included. Confirmed in Studio 0.741.19.7411056 — `PlayerScriptsUseInputActionSystem
is not a valid member of Workspace "Workspace"`. The example is now a Properties-window instruction.
`EnableSLIMAvatars`, `SandboxedInstanceMode`, `PlayerCharacterDestroyBehavior` and `UseInputSink`
are the same kind of setting and are now labelled so; `Model.LevelOfDetail` is labelled `PluginSecurity`.
`mcp-integration.md` now states that `execute_luau`'s plugin privilege does **not** reach
`NotScriptable` properties, and that the resulting "is not a valid member" error is not a typo.

### Changed — tooling

- **`audit-skill-examples.py` section F** checks `` `Class.Member` `` and `` `Class:Method()` `` in
  prose and tables against the dump: missing, deprecated, `RobloxScriptSecurity`, or `NotScriptable`,
  each reported only when its own context does not already say so. A table row must say it on the same
  row, so a qualifier in another row cannot excuse it. Section A now also flags code that **writes** a
  `NotScriptable` property, ignoring `--` comments.
- **`diff-api-dumps.py` grep-back** matched a member's bare name as a substring, so
  `TestService.Enabled` was reported "mentioned in" six files that never name `TestService`. It now
  matches whole words, and when a member name is ambiguous it requires the owning class or a relative of
  it in the same file. Back-tested over all eight dump pairs 0.733 → 0.741: no event lost, and every
  dropped mention was checked by hand and was false. `part.CollisionFidelity`, the 2.11.0 find, still
  matches.
- The diff now also reports **class-level** tag and superclass changes, enum tags, and enum item tag and
  value changes. Before this, a whole class turning `Deprecated` would have produced no event. The
  back-test surfaced seven historical events nobody had seen, such as `TriangleMeshPart` becoming
  `NotBrowsable` (0.736) and three `Enum.AdEventType` items deprecated (0.734).
- `SKILL.md`: `.current-version` has carried both `updatedAt` and `checkedAt` since 2.12.0, so the
  note that a fresh download "has no `checkedAt`" now applies only to installs that never updated their tools.

### Evals 41 → 47

- Fixed **#38**, which marked the unrunnable `= Enum.RolloutState.Enabled` as the correct answer.
- Added guards for `GetFriendsInServerAsync` (do not invent fields), the `CreateCall` non-migration,
  `AnimatedImageService`, `if local` and exact tables in 0.740.
- Added an **over-correction** guard: a server Script setting `CollisionFidelity` must not be sent to
  the Properties window.

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
