# Legacy Pattern Migration Guide

> Identify and migrate deprecated Roblox patterns to modern replacements.
> Includes detection strategies, migration checklists, and when NOT to migrate.

## Table of Contents
1. [Migration Reference Table](#migration-reference-table)
2. [Detailed Migration Guides](#detailed-migration-guides)
3. [Detecting Legacy Patterns](#detecting-legacy-patterns)
4. [Incremental Migration Strategy](#incremental-migration-strategy)
5. [Migration Checklist](#migration-checklist)
6. [When NOT to Migrate](#when-not-to-migrate)

---

## Migration Reference Table

| Legacy Pattern | Modern Replacement | Drop-in? | Notes |
|---|---|---|---|
| `spawn(func)` | `task.spawn(func)` | ✅ Yes | Runs immediately, no throttling |
| `delay(n, func)` | `task.delay(n, func)` | ✅ Yes | More accurate timing |
| `wait(n)` | `task.wait(n)` | ✅ Yes | Returns actual elapsed time |
| `DataStore2` (community) | `ProfileStore` (community) | ❌ No | Requires data migration strategy |
| `DataStoreService` (raw) | `ProfileStore` wrapper | ❌ No | Adds session locking, auto-save |
| camelCase API aliases | PascalCase methods | ✅ Yes | `.findFirstChild()` → `.FindFirstChild()` |
| Legacy game pass / developer product web endpoints | Open Cloud (management), `MarketplaceService` (in-game purchases) | ⚠️ Mostly | See *2026 API Deprecations* below |
| Old Type Solver | New Type Solver (GA 2025-11-20) | Auto for nonstrict / nocheck; **opt-in for strict** | A place with `--!strict` scripts stays on the old solver until **`Workspace.UseNewLuauTypeSolver`** is set in the Properties window (`NotScriptable`); see `luau-fundamentals.md` |
| `Instance.new` + parent first | Set `Parent` **last** | ✅ Yes | Avoids redundant replication/events |
| `RunService.Stepped` | `RunService.PreSimulation` | Same behavior, clearer name | `Stepped` is not deprecated (official reference); either works |
| `RunService.Heartbeat` | `RunService.PostSimulation` | Same behavior, clearer name | `Heartbeat` is not deprecated (official reference); either works |
| `RunService.RenderStepped` | `RunService.PreRender` | Same behavior, clearer name | `RenderStepped` is not deprecated (official reference); either works |
| `LocalizationService:GetTranslatorForPlayer()` | `:GetTranslatorForPlayerAsync()` | ⚠️ Mostly | Deprecated in engine **0.740**. The async form **yields** — wrap it or call it off the critical path |
| `CallingService:CreateCall()` | `:CreateCallAsync()` | — | Renamed in 0.739 and now yields — but **both are `RobloxScriptSecurity`**, as is every `CallingService` member since the class appeared in 0.737, so no game script could ever call either and there is nothing to migrate. The Roblox Connect calling APIs were sunset July 15, 2026 |

---

## Detailed Migration Guides

### 1. Task Library (`spawn` / `delay` / `wait`)

The globals use a legacy scheduler with throttling. The `task` library is the
standard replacement (available since 2021).

```luau
--@skilltest: legacy
-- ❌ Legacy: throttled scheduler, deprecated globals
spawn(function()
    wait(2)
    print("Hello")
end)

delay(5, function()
    print("Delayed")
end)
```

```luau
--!strict
-- ✅ Modern: the task library
task.spawn(function()
    task.wait(2)
    print("Hello")
end)

task.delay(5, function()
    print("Delayed")
end)
```

**Full `task` API:** `task.spawn`, `task.defer`, `task.delay`, `task.wait`,
`task.cancel`, `task.synchronize`, `task.desynchronize`.

Key improvement — `task.wait()` returns actual elapsed time:
```luau
local elapsed = task.wait(1) -- e.g. 1.0003
```

### 2. Instance Parenting Order

Setting `Parent` triggers replication and `ChildAdded`. Set it **last**.

```luau
-- ❌ Legacy (parent first): every property set after this replicates separately
local part = Instance.new("Part")
part.Parent = workspace
part.Size = Vector3.new(4, 1, 4)
part.Anchored = true
```

```luau
--!strict
-- ✅ Modern (parent last): configure, then parent once
local part = Instance.new("Part")
part.Size = Vector3.new(4, 1, 4)
part.Anchored = true
part.Parent = workspace
```

### 3. camelCase → PascalCase API Methods

Both casings work, but PascalCase is the documented standard.

| Legacy (camelCase) | Modern (PascalCase) |
|---|---|
| `findFirstChild` | `FindFirstChild` |
| `getChildren` | `GetChildren` |
| `isA` | `IsA` |
| `clone` | `Clone` |
| `destroy` | `Destroy` |
| `getDescendants` | `GetDescendants` |
| `waitForChild` | `WaitForChild` |

### 4. DataStore2 → ProfileStore

`ProfileStore` (by loleris) provides session locking and better data safety.
**Migration requires a data conversion strategy:**

```luau
--!strict
--@skilltest: requires ProfileStore
-- Conceptual migration loader (server-side)
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ProfileStore = require(ServerStorage:WaitForChild("ProfileStore") :: ModuleScript)
local DataStoreService = game:GetService("DataStoreService")
local legacyStore = DataStoreService:GetDataStore("PlayerData")

type PlayerData = { Coins: number, Inventory: { string }, Migrated: boolean }
local DEFAULT_DATA: PlayerData = { Coins = 0, Inventory = {}, Migrated = false }
local playerStore = ProfileStore.New("PlayerProfiles", DEFAULT_DATA)

local function loadPlayer(player: Player)
    local profile = playerStore:StartSessionAsync(`Player_{player.UserId}`, {
        -- Cancel is a FUNCTION ProfileStore polls, returning true once the session is no longer
        -- needed (official signature: Cancel: fn() -> (boolean)?). Passing a signal such as
        -- player.AncestryChanged is wrong.
        Cancel = function()
            return player:IsDescendantOf(Players) == false
        end,
    })
    if not profile then
        player:Kick("Data failed to load. Please rejoin.")
        return
    end
    -- Migrate legacy data if not yet migrated
    if not profile.Data.Migrated then
        local success, legacyData = pcall(function()
            return legacyStore:GetAsync(`Player_{player.UserId}`)
        end)
        if success and legacyData then
            profile.Data.Coins = legacyData.Coins or 0
            profile.Data.Inventory = legacyData.Inventory or {}
        end
        profile.Data.Migrated = true
    end
end
```

### 5. Legacy GamePass APIs

Use `MarketplaceService` for all GamePass operations:

```luau
local MarketplaceService = game:GetService("MarketplaceService")
local GAME_PASS_ID = 12345678

local function playerOwnsPass(player: Player): boolean
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAME_PASS_ID)
    end)
    return success and owns
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(
    function(player: Player, passId: number, wasPurchased: boolean)
        if wasPurchased and passId == GAME_PASS_ID then
            -- Grant benefit
        end
    end
)
```

### 6. New Type Solver (GA November 2025)

On by default for nonstrict and nocheck scripts since general release (2025-11-20); a place with
`--!strict` scripts stays on the old solver until you set `Workspace.UseNewLuauTypeSolver` in the
Properties window (`NotScriptable`; details in `luau-fundamentals.md`). Once on, it infers more and checks
`--!strict` harder, so some previously-passing code may now error:

```luau
--!strict
-- Passes the old solver; the new one reports "Cannot iterate over a table without indexer"
-- (both checked with luau-lsp 1.69):
--   local prices = { Sword = 100, Shield = 50 }
--   for name, price in prices do ... end

-- ✅ Fix: give the table an indexer type
local prices: { [string]: number } = { Sword = 100, Shield = 50 }
for name, price in prices do
    print(name, price)
end
```

---

## Detecting Legacy Patterns

Use `script_grep` (Roblox Studio MCP) to scan your codebase:

```text
script_grep("spawn(")           -- legacy spawn
script_grep("wait(")            -- legacy wait (watch for task.wait false positives)
script_grep("delay(")           -- legacy delay
script_grep("findFirstChild")   -- camelCase API
script_grep("DataStore2")       -- legacy data module
```

**Note:** `wait(` also matches `task.wait(`. Use `script_read` to confirm each
result is the global `wait`. For local scripts, regex: `\bwait\s*\((?!.*task\.)`

---

## Incremental Migration Strategy

### Phase 1 — Audit
Run `script_grep` for each pattern. Categorize by risk: **low** (task swaps),
**medium** (API renames), **high** (data store migration).

### Phase 2 — Low-Risk (drop-in replacements)
`spawn` → `task.spawn`, `delay` → `task.delay`, `wait` → `task.wait`,
camelCase → PascalCase. Use `multi_edit` to batch-replace. Playtest after.

### Phase 3 — Medium-Risk
Reorder `Instance.new` to parent last. Update GamePass APIs. Requires reading
surrounding code.

### Phase 4 — High-Risk
DataStore2 → ProfileStore. **Test in a staging place first.** Deploy with a
feature flag. Keep legacy read path for at least two weeks.

---

## Migration Checklist

- [ ] Scan for `spawn(` → replace with `task.spawn(`
- [ ] Scan for `delay(` → replace with `task.delay(`
- [ ] Scan for bare `wait(` → replace with `task.wait(`
- [ ] Scan for camelCase API calls → replace with PascalCase
- [ ] Verify `Instance.new` calls set `Parent` last
- [ ] Confirm `--!strict` passes under new type solver
- [ ] Check GamePass APIs against current `MarketplaceService` docs
- [ ] If using DataStore2: plan and test data migration separately
- [ ] Playtest affected features end-to-end
- [ ] Review `get_console_output` for deprecation warnings

---

## When NOT to Migrate

**Stable production code** — If it's been running without issues for months, the
regression risk may outweigh modernization benefits. Legacy `spawn`/`wait`/`delay`
are deprecated, not removed.

**Pre-release crunch** — Don't refactor during a launch window.

**Community modules you don't own** — Don't fork to modernize. Wait for upstream.

**Data store migration without a rollback plan** — Never migrate player data
without: (1) a tested rollback path, (2) a staging environment, (3) partial
failure recovery. Data loss is irreversible.

### Risk Assessment Matrix

| Factor | Low Risk (migrate now) | High Risk (defer) |
|---|---|---|
| Change type | Drop-in replacement | Behavioral change |
| Test coverage | Automated tests exist | Manual testing only |
| Data involved | No persistent data | Player save data |
| User impact | Internal tooling | Live game with players |
| Rollback ease | Git revert | Data migration rollback |

---

## 2026 API Deprecations & Breaking Changes

### April 2026

| Change | Date | Action Required |
|--------|------|-----------------|
| DataStore limits changed to experience-level | April 9 | Monitor via Creator Hub dashboard |
| `economy.roblox.com/v1/purchases/products/{productId}` **REMOVED** (legacy purchase flow) | April 10 | Sell in-experience with `MarketplaceService` purchase prompts (staff post, *Official List of Deprecated Web Endpoints* #118) |
| Legacy game pass / developer product **management** web endpoints deprecated | April 23 | Use the Open Cloud game pass and developer product APIs (same list, #119). Read the path, not the prefix: the Open Cloud API itself lives at `/game-passes/v1/universes/{universeId}/game-passes` and `/developer-products/v2/universes/{universeId}/developer-products` (`openapi.json`, marked BETA; their `GET …/creator` answered `200` through `open_cloud_invoke`, 2026-11-07) |

### May 2026

| Change | Date | Action Required |
|--------|------|-----------------|
| Publishing requirement: a one-time, **refundable** 1,000 Robux fee per game, as an alternative to a Plus/Premium subscription, to publish to all ages (rollout began May 19) | May 19 | Budget for new game launches |
| **Cross-game sales DISABLED** | May 29 | Use Transfers API for donations. See `references/monetization.md` |

### June 2026

| Change | Date | Action Required |
|--------|------|-----------------|
| `Accoutrement` members removed: `ServerEquipAccoutrement` (0.725), `ServerUnequipAccoutrement` and `BackendAccoutrementState` (0.726; the property is back in 0.729) | Mid-June (0.725–0.726) | Nothing to migrate: they were `RobloxSecurity` + `Hidden` or `NotScriptable`, never usable from game code |
| `AdService` / `AdGui` internal signals removed (`ServeAdSignal`, `ReportImpressionSignal`, `rewardedVideoAd*`, `AdGui.AdEvent`, …) | Mid-June (0.726) | Nothing to migrate: every one was `RobloxSecurity` + `Hidden` |
| Input Action System (IAS) full release | June 11 | `Workspace.PlayerScriptsUseInputActionSystem` — a Studio Properties-window setting. No script (MCP `execute_luau` included) can read or set it: it was `NotScriptable` until 0.742, and since 0.743 it is `RobloxScriptSecurity` ("lacking capability RobloxScript", Studio 0.743). See `references/project-structure.md` |
| Roblox Connect calling APIs **SUNSET** | **July 15** | Remove usage before deadline |

### November 2026 — re-run of 2026-11-07 on 0.746.0.7461269 (an empty dump diff, and changed behaviour)

**The dump diff from 0.746.0.7461264 to 0.746.0.7461269 has zero events, yet these results changed
from two days earlier.** An empty diff does not mean nothing changed: re-run what you rely on. Each
row ran in Studio 0.746.0.7461269 from a server `Script`, a `LocalScript`, a Script under an `Actor`,
or MCP `execute_luau`, and the probes were removed afterwards.

| Change | Result *(Studio)* |
|---|---|
| **`MarketplaceService:GetPassOwnershipAsync(player, passId)`** | **Answers:** `{ Owned = false, Active = false }` for a pass not owned, `{ Owned = true, Active = true }` for an owned one. Undocumented, so what `Active` means is unknown. Not run in a published game. See `monetization.md` |
| **`AssetService:GetLatestVersionUriAsync(content)`** | **Works** from a Script and a LocalScript for the place's own asset, returning a `Content` whose `Uri` is `rbxassetid://<id>&version=<n>`. Asset `1818`, owned by someone else, fails `request failed: HTTP 403` |
| **`RunService:BindToSimulationParallel` / `BindToAnimationParallel`** | **Work** from a Script under an `Actor`. From a plain Script: `The calling script must be rooted under an Actor.` See `performance-optimization.md` |
| **`SceneAnalysisService`: a correction.** Earlier versions of this file listed the whole service as refused | Only `GetCollisionGeometryMemoryAsync` refuses. The other six methods work, also from a game Script. See `performance-optimization.md` |
| `TestService:RegisterTest`, `ModerationService:BindViolationProcessor(int, fn)` | Still refused, the first with a new message: `TestService test registration isn't enabled in this session yet.` |
| **Unchanged:** `BakeToMeshAsync`, `CanUsersTransferRobuxAsync`, `EditableMesh:AddFace`, `GetSurfaceSlotsAsync`, `SplitApartAsync`, `GetWaveformKeys`, `SerializationService`, `PlaceSettings`, `TweenInfo` with `Spring`, orthographic `Camera` writes, `AnimationPlayer` and `PhysicsActivitySensor` creation, `integer` (`nil`), `DeviceTrustLevel` (`Pending`), `Enum.GuiNavigationDirection`, `UseHitbox`, `Decal` map writes, and the plugin-only gates on `StreamingEnabled`, `CollisionFidelity`, `RunContext`, `IsEdit` and `RunState` | Same results as 2026-11-05 |

### November 2026 — documentation changes 2026-11-05 to 2026-11-06 (engine 0.746)

`Roblox/creator-docs` a47045f..031a0e3.

| Docs change | What it means for your code |
|---|---|
| **New page `studio/mcp-open-cloud`:** Open Cloud from an MCP client, with no API key | See `mcp-integration.md`. Run in Studio: `open_cloud_invoke`, the permission errors, and the HTTP gate on `execute_luau` |
| **`Instance:QueryDescendants` gains `:in-radius(studs, selector)`**, and the `Collection` datatype page is rewritten | Both work *(Studio)*. See `performance-optimization.md`, which also covers `CollectionService:CreateCollection` |
| **`buffer.readvectorf32x2`, `readvectorf32x3`, `writevectorf32x2`, `writevectorf32x3`** documented | **Not in the engine:** all four are `nil` from a Script and a LocalScript *(Studio 0.746.0.7461269)* |
| `GeometryService:SplitApartAsync`, `HapticEffect:GetWaveformKeys` documented | **Still refused:** `This API is not yet released!` and `GetWaveformKeys() is not yet enabled!` *(Studio)* |
| `Player.DeviceTrustLevel` loses `Hidden` on its page; `UIGradient.Type` / `Scale` / `TileMode` and the `Workspace` streaming properties lose tags | These match the 0.746 dump. Nothing to migrate |
| Place publishing (`cloud/guides/usage-place-publishing`) now uses the **Assets API** `Update Asset`: an API key with **assets** Read and Write, the Place ID as the asset ID, and an **Operation ID** to poll instead of an immediate version number | *Docs only.* Update a CI script that calls the old place publishing endpoint |
| New guide `cloud/guides/experience-icons-and-thumbnails` | *Docs only.* Place icons and thumbnails through Open Cloud |
| `ui/styling/compatibility` corrects the `StyleQuery` condition names to `PreferredInput` and `ReducedMotionEnabled`, and adds `PreferredTextSize`; `ui/ui-drag-detectors` fixes its example to `DragRelativity` | `ui-systems.md` already used these names |

### November 2026 — engine 0.746.0.7461264 (ingested 2026-11-05)

Derived by diffing the **0.745 and 0.746 Full API Dumps locally** with
`tools/robloxdocs/diff-api-dumps.py`, 2026-11-05. **950 classes (+2, −1), 656 enums (+3, −1), 267
classes named `*Service` (347 tagged `Service`), 48 deprecated classes (577 members).** 111
changes, 85 developer-visible. Luau 0.745 (2026-10-30), see `luau-fundamentals.md`. Every row
marked *(Studio)* was run in Studio 0.746.0.7461264 from an ordinary server `Script`, a
`LocalScript` during a playtest, or MCP `execute_luau` for the plugin level; the probe scripts
were removed. On 2026-11-05 `WindowsPlayer` still served 0.745.0.7451137 while `WindowsStudio64`,
`MacStudio` and `MacPlayer` served 0.746.0.7461264.

**The headline is `RaycastParams.Margin`, which works** (see `performance-optimization.md`). Most of
the other new methods refuse, and most properties that lost `NotScriptable` are plugin-only.

| Change | Action Required |
|--------|-----------------|
| **`RaycastParams.Margin` / `SizeGradient`** (the `WorldRoot` cast signatures show both in 0.746; `FFlagRaycastParamsMarginAndSizeGradient` is `True` in Studio's and every player client's flags) | **Usable.** A ray passing 2 studs from a part missed with `Margin = 1.9` and hit with `2.1`. A negative `Margin` or a `SizeGradient` below `-1` throws; a ray with `Margin = 1000` fails at the cast (`The maximum radius is 256.000000`). `SizeGradient` changes nothing on a plain ray but widens `Spherecast` and `Blockcast` *(Studio)*. See `performance-optimization.md` |
| `GamepadService:EnableGamepadCursor(guiObject)` is now `(guiObject: GuiObject = nil)` | **Now optional.** A call with no argument succeeds from a LocalScript *(Studio)*; it failed in 0.745 |
| `Workspace.AuthorityMode`: `RobloxScriptSecurity` → **`None`**, read `Basic`, write `PluginOrOpenCloud` | A Script and a LocalScript now **read** it (`Automatic`); writing still fails `lacking capability PluginOrOpenCloud` *(Studio)*. Set it in the Properties window |
| `Workspace.PredictiveStreamingMode`, `StreamOutBehavior`, `StreamingIntegrityMode`, `StreamingMinRadius`, `StreamingTargetRadius`: `NotScriptable` dropped, + `PluginOrOpenCloud` | **Plugin-only.** A Script fails to read and write all five (`lacking capability PluginOrOpenCloud`); `execute_luau` reads `Default`, `Opportunistic`, `PauseOutsideLoadedArea`, `64`, `1024` *(Studio)* |
| `TextChatService.ChatTranslationEnabled`, `CreateDefaultCommands`, `CreateDefaultTextChannels` (write → `None` + `PluginOrOpenCloud`); `Terrain.Decoration`, `GrassLength` (`NotScriptable` dropped; write `PluginOrOpenCloud`); `SoundService.DefaultListenerLocation` (`PluginSecurity` → `None` + `PluginOrOpenCloud`) | A Script reads the `TextChatService` and `Terrain` properties (`false`, `true`, `true`, `true`, `0.1`) and fails to write them, `lacking capability PluginOrOpenCloud`. `DefaultListenerLocation` fails both ways *(Studio)*. Plugin-only writes |
| **`Workspace.UseInputSink` removed.** `+Workspace.InputSinkEnabled` (`RobloxScriptSecurity`), `+LayerCollector.InputSinkEnabled` (`Enum.RolloutState`, `PluginOrOpenCloud`) | A Script gets `UseInputSink is not a valid member of Workspace`. On a `ScreenGui`, `InputSinkEnabled` fails from a Script and a LocalScript (`lacking capability PluginOrOpenCloud`); `execute_luau` reads `Default` *(Studio)*. No docs page yet |
| **`Workspace.PrimalPhysicsSolver` and `Enum.PrimalPhysicsSolver` removed**; `+Workspace.NextGenerationPhysicsSolver` (`Enum.RolloutState`, `PluginOrOpenCloud`); `+Workspace.ParticlesUseDynamicWind` (`NotScriptable`) | Both removed names error. `NextGenerationPhysicsSolver` fails from a Script and reads `Default` from `execute_luau`; a Script gets `ParticlesUseDynamicWind is not a valid member of Workspace` *(Studio)*. The `Workspace` page (2026-11-05) describes `NextGenerationPhysicsSolver` as an "experimental next generation physics solver"; `ParticlesUseDynamicWind` is not on it |
| `TeleportService:ReserveServerAsync`, `TeleportOptions.ReservedServerAccessCode`, `ShouldReserveServer` now tagged **`Deprecated`** in the dump | Matches the 2026-10-27 docs. Move new code to `ReservedServerId`, and test it in a published game: see `networking.md` |
| `+GeometryService:SplitApartAsync(parts, options?)`, `+HapticEffect:GetWaveformKeys()`, `+SerializationService:SerializeValue` / `DeserializeValue` (`Enum.SerializationFormat` `Binary` / `Json` / `Luau`), `+PlaceSettings` (`GetActiveRollouts`, `GetRolloutState`, `SetRolloutState`) | **Not usable:** `This API is not yet released!`, `GetWaveformKeys() is not yet enabled!`, and at plugin level `SerializeValue is not yet enabled` and `PlaceSettings is not enabled`. From a Script `GetService` returns `nil` for `SerializationService` and `PlaceSettings` *(Studio)* |
| `EditableImage:DrawCircle` / `DrawImage` / `DrawLine` / `DrawRectangle` gain `alphaBlendType` (default `Default`) | Only `Default` works: any other value fails `Enum.ImageAlphaType other than Default is not yet supported` *(Studio, `DrawCircle`)*. The page (2026-11-03) says the same. Omit the argument |
| `UIGradient.Type`, `Scale`, `TileMode`: `NotBrowsable` dropped | A Script reads `Linear`, `1`, `Clamp` on a new gradient *(Studio)*. Rendering not checked; see `ui-systems.md` |
| `AnimationNodeDefinition.NodeId`, `AnimationValueNodeDefinition.NodeId`, `StateMachineTransitionDefinition.TransitionId`: `RobloxScriptSecurity` → `None` + `Animation` | A Script reads `NodeId` (empty on a new instance) *(Studio)*; `TransitionId` is *dump only*. No docs page describes them |
| Roblox-internal: `SoundService:GetInputDevice` now needs `InternalTest` (`execute_luau` also fails *(Studio)*); `+FeatureSearchParams`, `+FeatureMatchingSession:Search` / `SearchBatch`, `+FeatureMatchingService:CreateSearchParams` (`InternalTest`; a Script fails *(Studio)*); `FriendsCalling*` members `RobloxSecurity` → `RobloxScriptSecurity`; new `RobloxScriptSecurity` members on `ScriptEditorService`, `AssetImportService`, `AnimationPlayer`, `GuiService`, `AchievementService` (*dump only*) | Nothing to do |
| **Removed:** `WrapDeformMeshProvider`, `BasePart.siz` (a stray, typo'd property; a Script gets `siz is not a valid member`), `TestFailure.GetContext`, `AnimationRigData.LoadFromHumanoid`, `ScriptEditorService.OpenTextDocumentDocumentAsync` (`OpenTextDocumentAsync` was added), `AnimatedImageService.UserCreatedTracks` | Nothing to migrate (*dump only* except `siz`) |

**Re-run in 0.746, unchanged (*Studio*):** `PartType.Capsule` (still warns, behaves as Block),
`BakeToMeshAsync`, `SceneAnalysisService:GetCollisionGeometryMemoryAsync`, `EditableMesh:AddFace`
(`AddTriangle` works), `TestService:RegisterTest`, `MeshPart:GetSurfaceSlotsAsync`,
`CanUsersTransferRobuxAsync`, `AnimationPlayer` and `PhysicsActivitySensor`
creation, `EasingStyle.Spring` / `Bezier`, the `integer` library (`nil`), `Player.DeviceTrustLevel`
(`Pending`), `User.Id ~= UserId`, and the plugin-only gates on `Lighting`, `StreamingEnabled`,
`CollisionFidelity`, `RunContext`, `IsEdit`, `RunState` and `CreateDefaultPlayerModule`. Still working:
`coroutine.finally`, `Shapecast` overrides, and 210 sequential single-use locals.

### November 2026 — documentation changes 2026-10-30 to 2026-11-04 (engine 0.746)

`Roblox/creator-docs` c8f5276..a47045f. **Several pages describe more than the engine does:** each
row below says which were run.

| Docs change | What it means for your code |
|---|---|
| **`--!native` now covers Android clients:** "server-side scripts and client-side scripts on Android devices" | See `luau-fundamentals.md`. Published flags agree: `FFlagLuauCodegen` is `True` for Android and Studio, `False` for the Windows, Mac and iOS clients. Not measured on a device |
| **`AnalyticsService:LogJourneyEvent` is back**, with a new *Journey events* guide (`production/analytics/journey-events.md`) for branching paths: `LogJourneyEvent(player, journeyName, nodeName, journeySessionId?, customFields?)` | Log from the server. Names must match the journey published in Creator Hub (2–10 stages, 1–10 nodes per stage, per the page). A valid call logs `LogJourneyEvent event fired`; a name with a comma does **not** throw, it logs `Event field journeyName is invalid` *(Studio)*, so `pcall` will not catch a bad name |
| **`Camera.ProjectionType`, `OrthographicMode`, `OrthographicSize`, `ViewStretch`** and `Enum.ProjectionType` / `OrthographicMode` documented | **Still not enabled.** From a LocalScript each write is silently ignored: `Perspective`, `Vertical`, `35`, `1` read back *(Studio 0.746)*. `FFlagOrthographicCameraBetaFeature` is `True` for Studio and absent from player clients, so expect a Studio beta first. Do not build on it |
| **`Color3:GetLuminance()`, `GetContrastRatio(other)`, `GetContrastingColor(...)`** documented | **Work** from a Script and a LocalScript *(Studio)*; see `ui-systems.md` |
| `GuiObject.SelectionGained` / `SelectionLost` gain `inputDirection` (`Enum.GuiNavigationDirection`) | **Not in the engine:** the enum errors, and the handlers receive no arguments *(Studio 0.746)*. Do not read the parameter yet |
| `Enum.AvatarSettingsHitAndTouchDetectionMode.UseHitbox`, a `HitboxSize` property on `AvatarCollisionRules`, new `Enum.AvatarSettingsTouchAndQueryDetectionMode` | **Not in the engine:** all three error *(Studio 0.746)*, and none is in the 0.746 dump |
| `Decal.MetalnessMapContent`, `NormalMapContent`, `RoughnessMapContent` (write → `None`), `VoiceChatService` properties (`None` + `PluginOrOpenCloud`) | **The pages are ahead of the engine.** The 0.746 dump still has `PluginSecurity`; a Script fails with `lacking capability Plugin` on all of them, `ColorMapContent` is writable, and `execute_luau` reads `EnableDefaultVoice` *(Studio)* |
| `UserInputService:CreateVirtualInput(target?)`: "passing a non-`nil` `target` currently throws" | The 0.746 dump has no parameter, and a LocalScript passing a `ScreenGui` got a `VirtualInput` with no error *(Studio)*: the argument is ignored. Do not assume it targets the window |
| `DataModel.ServerLowMemoryWarning` page: can fire more than once, no guarantee of shutdown or survival | See `performance-optimization.md`. The signal exists *(Studio)*; it cannot be triggered on demand, so a handler is untested here |
| **VIP server access checks** (`projects/teleport-private-servers.md`) | See `networking.md`: each player is checked at connect time, and `TeleportInitFailed` must be handled (*docs*) |
| **Chat guidelines rewritten** (`chat/guidelines.md`): any player conversation in under 60 seconds must use `TextChatService`, and player-editable text needs filtering **and** a one-minute rate limit | See `networking.md` (*docs*) |
| Character Controller Library pages now carry a beta notice; `Workspace.ImprovedAnimationConstraint` and `PrimalPhysicsSolver` left the `Workspace` page (the first is still `NotScriptable` in the 0.746 dump); Experiments gain metric sets (Default, Rewarded Video Earnings, up to three custom metrics); Marketplace share links (up to 20 active per item); promotional text beta; stricter error-report rule validation | No code change (*docs*) |

### October 2026 — engine 0.745.0.7451137 (ingested 2026-10-29)

Derived by diffing the **0.744 and 0.745 Full API Dumps locally** with
`tools/robloxdocs/diff-api-dumps.py`, 2026-10-29. **949 classes (+3, −1), 654 enums (+2), 267
classes named `*Service` (347 tagged `Service`), 48 deprecated classes (574 members).** 83
changes, 47 developer-visible. Luau 0.744 (2026-10-23), see `luau-fundamentals.md`. Every row
marked *(Studio)* was run in Studio 0.745.0.7451137 from an ordinary server `Script`, a
`LocalScript` during a playtest, or MCP `execute_luau` for the plugin level; the probe scripts
were removed. The engine reference on create.roblox.com reads 0.745 (`STUDIO_VERSION`) since
2026-10-22.

**The headline is `coroutine.finally`, which now works** (see `luau-fundamentals.md`). Most of
what is new in the dump does not: `PartType.Capsule`, the parallel `BindTo*` methods,
`GeometryService:BakeToMeshAsync`, `EditableMesh:AddFace` and the reserved-server teleport fields
all refuse in Studio.

| Change | Action Required |
|--------|-----------------|
| **`Enum.PartType` +`Capsule` (5)** | **Not usable yet.** Setting `Part.Shape = Enum.PartType.Capsule` is accepted and reads back `Capsule`, but Studio warns `PartType.Capsule is not available yet. Parts with this Shape behave as Block.` and a 4×10×2 capsule had the mass of a block (56) and landed flat *(Studio)*. Keep `Ball` / `Cylinder` or a capsule `MeshPart` |
| **`Player.DeviceTrustLevel`** (`Enum.PlayerDeviceTrustLevel`), `+IntegrityService` (`EvaluatePlayerDeviceTrust` callback), `+Enum.PlayerDeviceTrustDecision` | **Now in the engine** (they were documented on 2026-10-21 before they shipped). In a playtest the level stays `Pending` on the server and on the player's own client and the callback is never called, as the docs say; assigning the callback from a LocalScript fails `EvaluatePlayerDeviceTrust can only be assigned on the server` *(Studio)*. See `security-hardening.md` → *Device trust* |
| `TeleportOptions.ReservedServerId` / `VipServerId` (in the dump since 0.740); the docs deprecate `TeleportService:ReserveServerAsync` and `TeleportOptions.ReservedServerAccessCode` / `ShouldReserveServer` (2026-10-27) | **The replacement refuses in Studio.** `TeleportAsync` with `ReservedServerId` fails in Studio 0.745 with an Access Code V2 error *(Studio)*. A live server was not tested. **Update (0.746):** that error is gone and the fields reach the teleport backend, then fail `HTTP 403` / `Request Context Failure`, as every Studio teleport does; the dump tags `ReserveServerAsync` as deprecated; the docs say it keeps working. See `networking.md` → *Teleporting to reserved and VIP servers* |
| `+RunService:BindToSimulationParallel()` / `BindToAnimationParallel()` (`Basic`) | **Work since 2026-11-07** from a script under an `Actor`; see the re-run of that date. The `RunService` page documents both |
| `StarterPlayer.CreateDefaultPlayerModule` (`RobloxScriptSecurity` → **`None` + `PluginOrOpenCloud`**), `Players.BanningEnabled` and `UseStrafingAnimations` (`NotScriptable` dropped, + `PluginOrOpenCloud`) | **Plugin-only.** A Script and a LocalScript fail to read and write all three (`lacking capability PluginOrOpenCloud`); `execute_luau` reads them (`true`) *(Studio)*. Set them in the Properties window |
| `Workspace.AuthorityMode` | The `Workspace` page (2026-10-22) lists it as `Security: None`, but the 0.745 dump still has `RobloxScriptSecurity`, and a Script, a LocalScript and `execute_luau` all fail `lacking capability RobloxScript` *(Studio)*. The page is ahead of the engine; set it in the Properties window. **Update (0.746):** the engine caught up on reading; see the 0.746 row |
| `AvatarClothingRules`: `ClassicShirtsAccessoryOverride` → `ClassicShirtOverride`, `ClassicPantsAccessoryOverride` → `ClassicPantsOverride`, `ClassicTShirtsAccessoryOverride` → `ClassicTShirtOverride`, `LeftShoesAccessoryOverride` → `LeftShoeAccessoryOverride`, `RightShoesAccessoryOverride` → `RightShoeAccessoryOverride`; `+AvatarCollisionRules.BodyPartsCollidableOnDeath` | **Renamed without an alias:** the old names fail `is not a valid member`, the new ones read `0` *(Studio)*. Rename them in any 0.744 code. `BodyPartsCollidableOnDeath` defaults to `true` and is writable *(Studio)*; like the other rules (0.744 row) no effect was checked |
| `EditableMesh:AddFace(vertexIds)` → `AddFace(...)` (a tuple, `CustomLuaState`); the page now shows `AddFace(v0, v1, v2)` | **Not available:** `AddFace` fails `EditableMesh API function not available` with a tuple, a table, or 2 IDs, in a playtest and in Edit. `AddTriangle(v0, v1, v2)` works *(Studio)*. Keep `AddTriangle` |
| `+GeometryService:BakeToMeshAsync(input, options?)` → `MeshPart`, `+AssetService:GetLatestVersionUriAsync(asset)` → `Content`, `+SceneAnalysisService:GetCollisionGeometryMemoryAsync()` | **Not available:** `BakeToMeshAsync: This API is not available yet` and, on that one method, `SceneAnalysisService is not enabled` *(Studio)*. The other `SceneAnalysisService` methods work, and so does `GetLatestVersionUriAsync` since 2026-11-07; see the re-run of that date. No docs page for any of the three |
| `+FluidForceSensor.BuoyancyForce` / `BuoyancyTorque` (`Vector3`, `ReadOnly`) | Readable from a Script (`0, 0, 0` on a new, unparented sensor) *(Studio)*. Whether they report buoyancy in water was not measured |
| `+TestExecutionContext:Skip(reason)`, `+TestResult.SkipReason`; `TestService` / `TestSuite:RegisterTest` gain an `options` dictionary | **Still not enabled.** `RegisterTest` now fails `TestService test registration isn't enabled in this session yet.` (the 0.742 message was "Feature flag is disabled.") *(Studio)* |
| `TextDocument.TextContent` (`PluginSecurity` → `None` + `PluginOrOpenCloud`); `ScriptEditorService:OpenTemporaryDocumentAsync` gains `options`; `+OpenTextDocumentDocumentAsync` (`RobloxScriptSecurity`) | Plugin APIs (*dump only*) |
| `PhysicsActivitySensor.Position` / `Size` now `NotReplicated`; `TextChannelWindow` no longer `NotBrowsable` (shown in the Explorer's insert menu) | No action. `PhysicsActivitySensor` still needs `InternalTest` to create *(Studio)* |
| `Enum.AvatarUnificationMode`: every item now tagged `Deprecated` | Matches the 2026-10-20 docs. The property is still `NotScriptable` (a Script gets "is not a valid member of Workspace") *(Studio)* |
| **Removed:** `BulkImportService` (every member was `RobloxScriptSecurity`), `Part.shap` (a stray, typo'd property), `Player.StepIdOffset` (`RobloxSecurity`) | Nothing to migrate |
| Roblox-internal (*dump only*): `FeatureMatchingService` / `FeatureMatchingSession` (both need the `InternalTest` capability), `CloudClientService` reservations, `CollectionService:GetAllCollections` (a Script fails `lacking capability RobloxScript` *(Studio)*), `MarketplaceService:PromptNativePurchaseWithContext`, `AnimatedImageService` / `AnimationClipProvider` / `AnimationPlayer.Ended` / `Stopped`, `Audio*.Streaming`, `LinkingService:RegisterLuaUrlWithPolicy`, `Humanoid.BodyPartsCollidableOnDeath` (`NotScriptable`) | Ignore for game code |

### October 2026 — documentation changes 2026-10-22 to 2026-10-29 (engine 0.745)

From the Roblox/creator-docs commits of 2026-10-22 to 2026-10-29 (`65621e8..c8f5276`), checked
against the 0.745 dump and, where marked *(Studio)*, run in Studio 0.745.0.7451137 on 2026-10-29.

| Change | Action Required |
|--------|-----------------|
| **Device trust guide** (`scripting/security/device-trust.md`, new) and `IntegrityService` / `Player.DeviceTrustLevel` pages | See `security-hardening.md` → *Device trust* and the 0.745 row above |
| **Teleport to private servers** (`projects/teleport-private-servers.md`, new); `TeleportService:ReserveServerAsync`, `TeleportToPrivateServer`, `TeleportOptions.ReservedServerAccessCode` / `ShouldReserveServer` described as deprecated; `DataModel.PrivateServerId` now says "VIP server or reserved server" | See `networking.md` → *Teleporting to reserved and VIP servers*. Studio cannot complete a teleport with the replacement fields (0.745 and 0.746 rows) |
| `ContextActionService:BindAction()` and the related binding methods are "not recommended for new work and planned for deprecation" in favour of the Input Action System | **Not deprecated yet**: `BindAction` has no `Deprecated` tag in the 0.745 dump. Write new input code with IAS (`project-structure.md`); existing CAS code keeps working |
| `CollectionService:GetCollections(instance)` documented: the `Collection` equivalent of `GetTags`, empty "if the instance matches no active query" | `{}` for a tagged part with no matching collection, and one entry for a member of an active one *(Studio)*. It is about `Collection` queries, not tags: keep `GetTags` / `GetTagged` |
| *Users and scoped user IDs* page rewritten (2026-10-23): one **effective user ID** per game, group or app; "`Player.User.Id` equals `Player.UserId`"; scoped IDs "have not rolled out broadly yet" | **Not what Studio shows.** For the same account in Studio 0.745, `player.UserId` is `8935399566` and `player.User.Id` is `1237928291809` *(Studio)*, as in 0.742. No staff post in DevForum topic 4677155 since 2026-09-01 (checked 2026-10-29). See *Scoped User Identifiers* below |
| `BasePart:GetJoints()` returns only joints and constraints that are **active**: both parts must be in the same simulated container (`Workspace` or one `WorldModel`) | A weld to a part in `ServerStorage` is not returned on either part (*docs*) |
| `GamepadService:EnableGamepadCursor(guiObject?)`: the page says the argument may be omitted | **Not in 0.745:** calling it with no argument fails `Argument 1 missing or nil` from a LocalScript *(Studio)*. Pass `nil` explicitly. **Update (0.746):** the call with no argument works *(Studio)* |
| `MarketplaceService:PromptGamePassPurchase` / `PromptProductPurchase`: a pass or developer product from **another** game fails, even if you own both; Studio's mocked purchase does not check this | Verify every ID belongs to the current game before you publish; a Studio test does not catch it (*docs*) |
| `AssetService:PromptCreatePlatformContentAsync(player, object, assetType)` replaces `PromptCreateAssetAsync` (which left the dump in 0.737): players can publish an `EditableImage` as an `Enum.AssetType.Image`; packages from an `Instance` are not supported now | Needs a server Script, a published place and **Allow Mesh/Image APIs** (*docs*; not run, it opens a publish dialog). `PromptCreateAssetAsync` is "not a valid member of AssetService" *(Studio)* |
| `Decal.EmissiveMaskContent` (`Content`; write `PluginSecurity`), `EmissiveStrength` (default `1`), `EmissiveTint` (default white) documented (in the dump since 0.740) | A Script sets `EmissiveStrength` and `EmissiveTint`; writing `EmissiveMaskContent` fails `lacking capability Plugin` *(Studio)*. Set the mask in the Properties window. **Update (0.746):** still fails, though the page now says `None` for the other map properties |
| **Expanded Terrain** / custom terrain materials (`parts/custom-terrain-materials.md`, new): up to 62 paintable materials, enabled per place by `Workspace` **Expanded Terrain** = Enabled, which restarts the place | A Properties-window setting: `workspace.ExpandedTerrain` is `NotScriptable` ("is not a valid member" from a Script) *(Studio)*. Known limits in the guide: a `MaterialVariant`'s custom physical properties are ignored, and thin terrain (<16 voxels) can vanish with a small streaming radius |
| Server authority guide: prediction covers whole assemblies; inside `BindToSimulation` callbacks `Instance.new` / `Clone` work but `Destroy()` and re-parenting error (destroy from `PostSimulation` instead); `Humanoid:EquipTool()` / `UnequipTools()` cannot be called there and Tools are "not fully supported" yet; `RunService:GetPredictionStatus()` | *Docs*; not run (it needs `AuthorityMode = Server`, a Properties-window setting). See `security-hardening.md` |
| `PhysicsSettings.DrawShapecast` (`PluginSecurity`): draws every `Shapecast` / `Blockcast` / `Spherecast` (green hit, red miss) | A Studio debugging toggle (*docs*) |
| Memory stores: on `TotalMemoryOverLimit`, delete or expire items, flush with Open Cloud (`POST /cloud/v2/universes/{id}/memory-store:flush`, scope `LIVE` or `TEST`, clears **every** queue, sorted map and hash map in that scope), or buy capacity through Extended Services | *Docs*. A flush also wipes data that live matchmaking or trading may still need |
| `GuiObject:TweenPosition` / `TweenSize` / `TweenSizeAndPosition` (all deprecated since 0.738) error on `EasingStyle.Bezier` or `Spring` | Same as `TweenInfo.new` (0.744 row); use `TweenService` anyway |
| Also: `Studio.Theme` is typed `StudioTheme`; MicroProfiler search (<kbd>Ctrl</kbd>+<kbd>F</kbd> in Detailed mode); `Path2D` spline formula; `AnimationValueNodeDefinition` / `AnimationValueOutputDefinition` / `Enum.AnimationValueNodeType` (Graph Editor expression nodes, `NodeId` is `RobloxScriptSecurity`); rewarded-video playbooks moved from PDFs to pages; the Studio CLI page moved to `studio/cli.md` | No action |

### October 2026 — engine 0.744.0.7441077 (ingested 2026-10-22)

Derived by diffing the **0.743 and 0.744 Full API Dumps locally** with
`tools/robloxdocs/diff-api-dumps.py`, 2026-10-22. **947 classes (+4), 652 enums (+1), 266
classes named `*Service` (346 tagged `Service`), 48 deprecated classes (574 members).** Luau has
no 0.744 release yet (latest 0.743). Every row marked *(Studio)* was run in Studio 0.744.0.7441077
from an ordinary server `Script`, a `LocalScript` during a playtest, or MCP `execute_luau` for the
plugin level; the probe scripts were removed. The engine reference on create.roblox.com still
reads 0.743 (`STUDIO_VERSION`), so **none of the new members below has a docs page yet**.

**The headline:** of the 147 developer-visible changes, the ones that look most usable are not.
The two new easing styles are rejected by everything that takes an easing style, and the
avatar-rules APIs a Script can now call ran without error and changed nothing visible.

| Change | Action Required |
|--------|-----------------|
| `Enum.EasingStyle` +`Bezier` (11), +`Spring` (12) | **Not usable.** `TweenInfo.new(0.5, Enum.EasingStyle.Spring)` and `TweenService:GetValue(0.5, Enum.EasingStyle.Spring, …)` both error `… does not support Enum.EasingStyle.Spring or Enum.EasingStyle.Bezier`, from a Script and a LocalScript. Setting `UIPageLayout.EasingStyle = Enum.EasingStyle.Spring` raises no error but reads back `Back`, the default *(Studio)*. Keep the existing styles |
| ~60 `Avatar*Rules` properties (`AvatarBodyRules.AvatarType` / `HeadOverride` / `ScaleMode`, `AvatarAccessoryRules.LimitBounds`, `AvatarAnimationRules.*Override`, `AvatarClothingRules.*`, `AvatarCollisionRules.*`), `StarterPlayer.PlaceAvatarRules`, `Humanoid:ApplyAvatarRulesAsync(avatarRules)`, `Player:LoadCharacterWithAvatarRulesAsync(avatarRules)`: `RobloxScriptSecurity` → **`None`** with the new `AvatarAppearance` capability; the two methods now take a `Variant` | **Callable, but no effect observed.** A server Script creates `AvatarRules` and `AvatarBodyRules`, writes `AvatarType = R6`, `HeadOverride = 123` and `LimitBounds`, and sets `StarterPlayer.PlaceAvatarRules` (it reads `nil` by default). `ApplyAvatarRulesAsync` and `LoadCharacterWithAvatarRulesAsync` with an R6 rule both returned without error, and the character **stayed R15** (no `Torso`). Passing a table instead of an instance fails `Unable to cast value to Object` *(Studio)*. There is no docs page, so what a rule is meant to do is unknown. Keep avatar settings in the **Avatar Settings** window. `AvatarRules.AvatarType` is deprecated (→ `AvatarBodyRules.AvatarType`) and still `RobloxScriptSecurity`, and `AvatarAbilityRules` is too: `Instance.new` fails `lacking capability RobloxScript` *(Studio)* |
| `RunService:IsEdit()` (`PluginSecurity` → `None`) and `RunService.RunState` read (`PluginSecurity` → `None`), both + `PluginOrOpenCloud` | **Still plugin-only.** A Script and a LocalScript each fail `lacking capability PluginOrOpenCloud`; `execute_luau` gets `true` and `Enum.RunState.Stopped` *(Studio)*. In game code use `RunService:IsStudio()` |
| **`Lighting.Technology` deprecated** → `LightingStyle` | Nothing to migrate in game code: `Technology` is `RobloxScriptSecurity` (a Script and `execute_luau` both fail to read it, `lacking capability RobloxScript`), and `LightingStyle` reads `Realistic` *(Studio)*. Set lighting in the Properties window; `LightingStyle` is plugin-only to write (see the 0.740 row) |
| `+CollectionService:GetCollections(instance)` → `Array` | **Returns `{}`** for a part with two tags, for a character and for `workspace`, from a Script and a LocalScript, when no collection matches them *(Studio)*. It is not a tag lookup: keep `GetTags` / `GetTagged` |
| `AnimationPlayer`: `NotCreatable` removed, `Hidden` dropped from `AnimationContent` / `Enabled` | **Still not usable:** every member is `RobloxScriptSecurity`, and `Instance.new("AnimationPlayer")` now fails `lacking capability RobloxScript` from a Script and from `execute_luau` *(Studio)* |
| `+AudioSearchParams.SortType` (`+Enum.AudioSortType`: `Relevance`, `MostUsed`, `Trending`, `RecentlyCreated`, `ShortestToLongest`, `LongestToShortest`), `+AudioSearchParams.MaxPageSize` | A Script sets and reads both *(Studio)*. Whether `AssetService:SearchAudioAsync` (the deprecated `SearchAudio`'s replacement) honours them was not run |
| `Sound.AudioContent`, `AudioPlayer.AudioContent`: `Hidden` removed | Now shown in the Properties window; scripts could already use them (`file-formats-and-assets.md`) |
| `Studio.PluginDebuggingEnabled`: `PluginSecurity` → `RobloxScriptSecurity` | A plugin can no longer read it: `execute_luau` fails `lacking capability RobloxScript` *(Studio)* |
| `+ScriptDocument:IsReadOnly()` / `GetReadOnlyReasons()` / `AddReadOnlyReasonsAsync()` / `RemoveReadOnlyReasonsAsync()` (`PluginSecurity`); `+WrapLayer.RotateScaleDeformationMap` / `ScaleOnlyDeformationMap` / `TargetShaping` (read `None`, write `PluginSecurity`) | Plugin APIs (*dump only*): a `ScriptDocument` exists only for a script open in the editor, so they were not run |
| New `TestCoordinatorService`, `CloudClientService`, `AppHandle`, `ParticipantHandle`; `+RealtimeMedia.Disconnected` / `IsConnectionWeak`, `+VideoCaptureService:SetMockInputAsync` / `ClearMockInput` (`InternalTest`); `+ControlState:HasField` (`NotBrowsable`) | Not usable: `GetService("TestCoordinatorService")` and `GetService("CloudClientService")` return `nil` *(Studio)*; the rest need `InternalTest` (*dump only*) |
| Roblox-internal (*dump only*): `TextChatService.CoreMessageReceived` / `ChatIsLoaded`, `*HandleAdornment.DoubleSided` (`Hidden`), `InputAction` / `InputBinding` / `InputContext.Editor` (`NotScriptable`), `SoundService` detached-playback members, `ExperienceService:IsInExperience`, `LinkingService` / `NotificationService` / `ProjectService` / `CallingService` additions, `Enum.FriendsCallingEndReason` +`NoReason` | Ignore for game code: all `RobloxScriptSecurity` or higher |

### October 2026 — documentation changes 2026-10-16 to 2026-10-21 (engine still 0.743)

From the Roblox/creator-docs commits of 2026-10-16 to 2026-10-21, re-checked against the 0.743
dump and, where marked *(Studio)*, run in Studio 0.743.0.7431133 on 2026-10-21.

| Change | Action Required |
|--------|-----------------|
| **Platform-integrated chat** (new page, 2026-10-20): an opt-in `TextChatService.PlatformIntegratedChat` mode (`RobloxScriptSecurity`: a Properties-window setting no script can read), **required for all games from May 2027**, in which code cannot read chat text | With it enabled, `TextChatMessage.Text` / `PrefixText` read `""`, `Player.Chatted` did not fire, `TextChannel:SendAsync()` returned `nil`, and `TextChatCommand.Triggered` still got the full line *(Studio)*. Move chat commands to `TextChatCommand` and custom chat UI to `TextChannelWindow`; see `networking.md` |
| **`Workspace.AvatarUnificationMode` no longer has an effect**: every `Enum.AvatarUnificationMode` item is deprecated with "R6 avatars always load as R6 rigs" (2026-10-20), and the *R6 to R15 Adapter* page was deleted (2026-10-16) | Nothing to set, and no adapter parts to code around: drop handling for the adapter's invisible R6 proxy parts and its `CollisionHead`. In the 0.743 and 0.744 dumps the property is still there, `NotScriptable` and without a `Deprecated` tag; a Script reading it gets "is not a valid member of Workspace" *(Studio)* |
| `coroutine.finally` is documented on the `coroutine` page (2026-10-20) | **Still `nil`** in Studio 0.743 from a Script and a LocalScript *(Studio)*. See `luau-fundamentals.md`. **Update (0.745): now a function** from a Script, a LocalScript and `execute_luau` in Studio 0.745, and `FFlagLuauCoroutineFinally` is `True` in Studio's and every player client's published flags *(Studio)*; see `luau-fundamentals.md` |
| `Enum.PlayerDeviceTrustLevel` / `PlayerDeviceTrustDecision` documented (2026-10-21), for a `Player.DeviceTrustLevel` property | **Does not exist in the engine yet:** neither enum nor the property is in the 0.743 or 0.744 dump, and `Enum.PlayerDeviceTrustLevel` errors *(Studio)*. See `security-hardening.md`. **Update (0.745): shipped.** `Player.DeviceTrustLevel`, both enums and `IntegrityService` are in the 0.745 dump; see the 0.745 row |
| `AnalyticsService:LogJourneyEvent` **removed from the docs** (2026-10-21) | Still in the 0.743 and 0.744 dumps (`Security: None`), and a Script can still index it *(Studio)*. **Update (2026-11-03):** the page is back, with a guide; see the 2026-11-04 docs rows |
| `BasePart.CenterOfMass` summary corrected: it is the **local** position relative to the part's `CFrame`, not a world position | A part at `(100, 50, -30)` reads `CenterOfMass = 0, 0, 0` and `AssemblyCenterOfMass = 100, 50, -30` *(Studio)*. Use `AssemblyCenterOfMass` for a world position |
| `Player:Kick()` from the server: a custom message over **500 bytes** is discarded and the default notice shown | Keep kick reasons short (*docs*; see `security-hardening.md`) |
| `KeyCode.MouseWheel` / `TrackpadPinch` / `TouchPinch` (`Direction1D`) and `MouseDelta` / `TouchDelta` / `TrackpadPan` (`Direction2D`) report **velocities per second** under the Input Action System | One simulated wheel notch read about `15` for about 0.066 s *(Studio)*. See `project-structure.md` |
| `AssetService:CreateAssetAsync` accepts `Enum.AssetType.Audio` with an `AudioTextToSpeech` root, for reusable text-to-speech assets; `BadgeService:GetBadgeInfoAsync` documents `AwardCount`, `PastDayAwardCount` and `Rarity`; `AudioFader.Volume` range is 0–10 (was documented 0–3); `TextChannelWindow.FontFace` / `UseDefaultFont` documented | *Docs only*, not run here (the first uploads an asset). `FontFace` and `UseDefaultFont` were set from a LocalScript *(Studio)* |

### October 2026 — engine 0.743.0.7431133 (ingested 2026-10-17)

Derived by diffing the **0.742 and 0.743 Full API Dumps locally** with
`tools/robloxdocs/diff-api-dumps.py`, 2026-10-17. **943 classes (+4, −1), 651 enums (+4, −1),
264 classes named `*Service` (344 tagged `Service`), 48 deprecated classes (573 members).** Luau
0.743 (2026-10-16) — see `luau-fundamentals.md`. Every row marked *(Studio)* was run in Studio
0.743.0.7431133 from an ordinary server `Script` (`Sandboxed = false`) or a `LocalScript` during a
playtest, and from MCP `execute_luau` for the plugin level; the probe scripts were removed. Docs
were checked in Roblox/creator-docs up to 2026-10-16.

**The headline is the same security-model fact as 0.742.** Seven more members went from
`PluginSecurity` or `RobloxScriptSecurity` to `Security: None` with the `PluginOrOpenCloud`
capability, and a game Script still cannot use any of them.

| Change | Action Required |
|--------|-----------------|
| `BaseScript.RunContext` write (`PluginSecurity` → `None`), `Animator:StepAnimations()` (`PluginSecurity` → `None`), `HumanoidRigDescription:GetJoint` / `SetJoint` / `GetR15JointLabels` / `SetTposeAdjustment`, `DigitsRigDescription:SetJoint`, `AnimationRigData:LoadFromModel` (`RobloxScriptSecurity` → `None`); all gained `PluginOrOpenCloud` | **Still plugin-only.** From a server Script each fails with `lacking capability PluginOrOpenCloud` *(Studio)*. Reading `RunContext` works. From `execute_luau` (plugin level) setting `RunContext`, calling `StepAnimations(0.1)` and `GetR15JointLabels()` (15 labels) all work *(Studio)*. Set `RunContext` in the Properties window |
| `Workspace.PlayerScriptsUseInputActionSystem`, `StarterPlayer.CreateDefaultPlayerModule`: `NotScriptable` dropped, Security → **`RobloxScriptSecurity`** (read and write) | **Still not scriptable, but the error changed.** A Script, a LocalScript and `execute_luau` each get `The current thread cannot read 'PlayerScriptsUseInputActionSystem' (lacking capability RobloxScript)` *(Studio)*; it used to be "is not a valid member of Workspace". Set both in the Properties window. The official pages show the same change (2026-10-16) **Update (0.745):** `CreateDefaultPlayerModule` went on to `None` + `PluginOrOpenCloud`: a Script now fails `lacking capability PluginOrOpenCloud` and `execute_luau` can read it. `PlayerScriptsUseInputActionSystem` is unchanged |
| `+MarketplaceService:GetPassOwnershipAsync(user: Player, gamePassId: int64)` → `Dictionary`, Yields, `AssetRead` capability | **Answers since 2026-11-07,** with `{ Owned, Active }` *(Studio)*; see the re-run of that date. Passing a UserId instead of the `Player` fails with "Unable to cast value to Object". There is no docs page. Keep `UserOwnsGamePassAsync(player.UserId, passId)` for now (`monetization.md`) |
| `WorldRoot:Shapecast(part, direction, params, cframeOverride?, sizeOverride?)`: two new optional parameters, documented on the `WorldRoot` page | **Not enabled:** passing either one errors `Shapecast cframeOverride and sizeOverride are not enabled yet!` *(Studio)*. Cast from a part that is already where you want it, or use `Blockcast` / `Spherecast` with an explicit `CFrame` and size. **Update (0.745): both overrides now work.** With `cframeOverride` a cast from a part 1,000 studs away hit a target under the override (distance 8.5); a 20-wide `sizeOverride` hit a target 8 studs off-centre that the 2-wide part missed; the part itself did not move *(Studio)*. They are documented on the `WorldRoot` page |
| `LayerCollector:GetGuiObjectsAtPosition(x, y)`: `RobloxScriptSecurity` → `None` (`UI` capability) | **Usable from a LocalScript.** `screenGui:GetGuiObjectsAtPosition(x, y)` returned only that ScreenGui's frame, while the older `PlayerGui:GetGuiObjectsAtPosition` returned objects from every ScreenGui *(Studio)*. Called 0.5 s after parenting, before layout, both returned an empty list, so take the coordinates from `AbsolutePosition` once the GUI has rendered. Not on the `LayerCollector` page yet |
| `+InputBinding.Deadzone` (`NumberRange`, default `0.1`–`1`, `Input` capability) | A LocalScript reads the default and writes `NumberRange.new(0.25, 0.9)` *(Studio)*. Whether it changes analog input was **not** verified, and there is no docs page. Leave it at the default until it is documented |
| `+UIDragDetector.Selectable` (bool, default `true`), `+Player.EmotesLoaded` (event), `+StarterGear.Loaded` (bool, `ReadOnly`) | Usable: a LocalScript reads and writes `Selectable`. A server Script connects to `EmotesLoaded` (it did not fire within 8 s of a Studio join) and reads `StarterGear.Loaded` (`false` right after join) *(Studio)*. None is documented yet, so do not build on what `Loaded` means |
| `+ParticleEmitter2D` (`NotBrowsable`, 36 members: `Rate`, `Lifetime`, `Emit`, `Clear`, flipbooks, `EmissionMode` via `Enum.ParticleEmitter2DEmissionMode`) | Creatable; parenting it under a `Frame` in `PlayerGui` and calling `Emit(5)` raised no error *(Studio)*. **Whether it renders was not checked**, and there is no docs page |
| `+PhysicsActivitySensor` (`SensorBase`), `+FeatureMatchingTable`, `+InputReplayService` (no members) | Not usable: `Instance.new("PhysicsActivitySensor")` fails with `lacking capability InternalTest`; `GetService("InputReplayService")` returns `nil` *(Studio)*. `FeatureMatchingTable` is creatable but its `Data` is `NotScriptable` and it has no docs page |
| **`AnimatedImageTrack` class REMOVED**; `AnimatedImageService` reworked (its seven track methods, from `GetTrack` to `UnloadTracks`, replaced by `AddAnimatedImageClipAsync`, `GetAnimatedImageClipFramesAsync` and `GetAnimatedImageClipsChangedSignal`); `Enum.ProjectServiceOperationResult` removed | Nothing to migrate: every removed and every new member is `RobloxScriptSecurity` (*dump*). `Instance.new("AnimatedImageTrack")` now fails *(Studio)* |
| 95 `Avatar*Rules` properties (`AvatarBodyRules.CustomHeadId`, `AvatarAnimationRules.CustomRunAnimationId`, …) and `Humanoid:ApplyAvatarRules` **deprecated** (→ the new `*Override` properties and `ApplyAvatarRulesAsync`); `Enum.AvatarSettings*` items deprecated | Nothing to migrate: in 0.743 all of them, old and new, are `RobloxScriptSecurity` (*dump only*). **0.744 opened the new `*Override` properties and `ApplyAvatarRulesAsync` to scripts**, with no effect observed; see the 0.744 section. Avatar settings stay in the Studio **Avatar Settings** window |
| Docs only: `LogService:GetLogger(name)` and the `Logger` class are documented since 2026-10-15 (both were already in the 0.742 dump) | Usable from a server Script: `GetLogger("Combat")` returns the same `Logger` each time, `:Info("…{count}…", {count = 8})` logs, and a child's `FullPath` is `Combat.Hits`; a name containing `.` errors `Logger name cannot contain '.'` *(Studio)* |
| Docs only: `Enum.GradientType.Elliptical` and `Conical` are documented now (2026-10-15), behind the **Upgraded UIGradients** Studio beta (`FFlagUpgradedUIGradientsBetaFeature = True` in Studio's published flags) | A LocalScript can set `UIGradient.Type = Enum.GradientType.Elliptical` *(Studio)*. Rendering was not checked. Treat it like any Studio beta: not for a published game until it is released |
| Roblox-internal, not callable by you (*dump only*): `Humanoid.InternalAvatarRulesRootPartSize*` (`Hidden`, `NotScriptable`), `TestCase.Check` / `Require` (`CustomLuaState`), `AdPlacement` now `NotBrowsable`, `Enum.FeatureChannelEncoding` / `FeatureNormalization` / `MetadataFieldType`, `Enum.AssetType.AnimatedImage`, 85 `RobloxScriptSecurity`-only changes | Ignore for game code |

### October 2026 — engine 0.742.0.7421053 (ingested 2026-10-11)

Derived by diffing the **0.741 and 0.742 Full API Dumps locally** with
`tools/robloxdocs/diff-api-dumps.py`, 2026-10-11. **940 classes (+10, −1), 648 enums (+8, −1),
263 classes named `*Service` (343 tagged `Service`), 48 deprecated classes (477 members).** Luau 0.742 (2026-10-10) — see `luau-fundamentals.md`.
Every developer-visible row was **run in Studio 0.742.0.7421053** on an empty baseplate, from an
ordinary server `Script` (`Sandboxed = false`) or a `LocalScript` during a playtest, unless it says
*dump only*. None of the new members below has a page on create.roblox.com yet (checked 2026-10-11
in Roblox/creator-docs), and the 742 release notes were still marked Pending.

**The headline is a security model fact, not a new API.** Seven members went from `PluginSecurity`
or `RobloxScriptSecurity` to `Security: None` and gained the `PluginOrOpenCloud` capability. That
does **not** make them scriptable: an unsandboxed game Script does not hold `PluginOrOpenCloud`, and
every one of these writes failed with `lacking capability PluginOrOpenCloud`. The same is true of
the 0.740 fidelity and `Lighting` relaxations, which this file and `performance-optimization.md`
had called script-writable since 2.11.0; both are corrected.

| Change | Action Required |
|--------|-----------------|
| `Workspace.StreamingEnabled`, `.FallenPartsDestroyHeight`, `.FallHeightEnabled`, `.LuauTypeCheckMode`, `Model.LevelOfDetail`, `MeshPart.RenderFidelity`, `HumanoidRigDescription.OriginOffset`: Security → `None` + `PluginOrOpenCloud` | **Still plugin-only.** A game Script writing any of them fails *(Studio)*; `Model.LevelOfDetail`, `Workspace.LuauTypeCheckMode`, `HumanoidRigDescription.OriginOffset` and `Workspace.ReplicationFrequency` cannot even be **read** from a Script (re-run 2026-10-11). Reading `StreamingEnabled` works. The command bar / a plugin (MCP `execute_luau` too) can write them *(Studio)*. Set them in the Properties window |
| `+Camera.ProjectionType` (`Enum.ProjectionType` `Perspective`/`Orthographic`), `+OrthographicSize`, `+OrthographicMode`, `+ViewStretch` | **Present but not enabled.** From a `LocalScript`, setting `ProjectionType = Orthographic` raises no error, yet reading it back still gives `Perspective`, and `OrthographicSize = 50` reads back `300` *(Studio)*. Do not build an orthographic camera on it yet. **Update (0.746):** documented now, still ignored; the default reads `35` *(Studio)* |
| `+UIBlur` (`UIComponent`: `Color`, `Enabled`, `Strength` (`Enum.UIBlurStrength` `Light`/`Medium`/`Heavy`), `Transparency`) | Creatable, and can be parented under a `Frame` in `PlayerGui` from a `LocalScript` without error *(Studio)*. **Whether it renders a blur was not verified**, and there is no docs page. Check visually before relying on it |
| `+MarketplaceService:CanUsersTransferRobuxAsync(sender: Player, receiverUser)` → `Enum.RobuxTransferEligibility`, Yields; `+MarketplaceService:PromptVIPServerPurchase(player)` | `CanUsersTransferRobuxAsync` errors **"CanUsersTransferRobuxAsync is not enabled"** from a Script *(Studio)*. `PromptVIPServerPurchase` was not called (it opens a purchase prompt), *dump only*. Keep using `PromptRobuxTransferAsync` from `monetization.md` |
| `+MeshPart:GetSurfaceSlotsAsync()`, `+TestService` test registry (`RegisterSuite`, `ListTests`, `RunTestsAsync`, `ResetTestRegistry`, `TestRegistryChanged`, next to the older `RegisterTest`, plus `TestSuite` / `TestResult` / `TestRunResult` / `TestFailure`), `+ModerationService:BindViolationProcessor()` | **Not enabled:** they error with "MeshPart:GetSurfaceSlotsAsync is not yet enabled", "TestService test registration isn't enabled in this session yet." and "Safety callback API is not enabled" *(Studio)*. `TestService.RegisterTestLegacy` is now **deprecated** in favour of `RegisterTest` (*dump only*); nothing to migrate while the new one is off. **Update (0.745):** `RegisterTest` now fails `TestService test registration isn't enabled in this session yet.`; `GetSurfaceSlotsAsync` and `BindViolationProcessor(1, fn)` ("Safety callback API is not enabled") are unchanged *(Studio)* |
| `+Workspace.ReplicationFrequency` / `+ReplicationThroughput` (`Enum.ReplicationMode`) | `PluginOrOpenCloud` for read **and** write: a Script cannot read them *(Studio)*. Properties-window settings |
| `+Decal.ResampleMode` (`Enum.ResamplerMode`), `+SurfaceAppearance.SurfaceSlot` (int) | Usable: a Script reads and writes `ResampleMode` and reads `SurfaceSlot` (`-1` on a new instance) *(Studio)* |
| `Stats:GetMemoryUsageMbFiltered()` / `GetMemoryUsageMbAllCategoriesFiltered()` | Need the `InternalTest` capability; a Script gets "lacking capability InternalTest" *(Studio)*. Not for game code |
| **`AnimatedImage` class and `Enum.AnimatedImagePlaybackState` REMOVED** | Nothing to migrate: every `AnimatedImage` member was `RobloxScriptSecurity` (see the 0.738 row) and `Instance.new("AnimatedImage")` now fails *(Studio)* |
| `+AnimationPlayer` | `NotCreatable` (`Instance.new` fails *(Studio)*); every member `RobloxScriptSecurity`. Not usable. 0.744 dropped `NotCreatable`, and `Instance.new` still fails (`lacking capability RobloxScript`) |
| Roblox-internal, not callable by you (*dump only*): `FriendsCallingService`, `InstanceRegistryService` (`RobloxScriptSecurity`), `HiddenPlayerService` (`RobloxSecurity`), new `AnimatedImageService` / `PackageService` / `PopLatencyService` / `Sound` / `Audio*` members, `TeleportService:TeleportSwitchServer` signature change, `Enum.PioneerSource` +`RobloxPioneerTest`, `TestCase` superclass `Instance` → `Object` | Ignore for game code |

### October 2026 — engine 0.741.19.7411056 (ingested 2026-10-01)

Derived by diffing the **0.740 and 0.741 Full API Dumps locally** with
`tools/robloxdocs/diff-api-dumps.py`, cross-checked by a second, independent all-fields diff, on
2026-10-01. **931 classes (+7, 0 removed), 641 enums (+6), 260 classes named `*Service`, 48
deprecated classes.** No class or enum removals (15 `RobloxScriptSecurity`
`StarterPlayer.GameSettings*` properties went), no new deprecations, no `Capabilities` changes. Luau 0.740 (2026-09-25) — see
`luau-fundamentals.md`. Runtime facts marked *(Studio)* were read in Studio 0.741.19.7411056.

| Change | Action Required |
|--------|-----------------|
| `+Player:GetFriendsInServerAsync()` — `Security: None`, **Yields**, no parameters, returns an `Array`; `Capabilities: Players, Social` | New and usable. **Not yet on the official `Player` page** (checked 2026-10-01), so the shape of each array element is undocumented — print one result in Studio before writing code that indexes its fields, and do not guess them. It yields, so keep it off a hot path |
| `Enum.GradientType` +`Elliptical` (Value 3) — exists at runtime *(Studio)* | New `UIGradient.Type` option. **Update (2026-10-15):** the enum page and the UI guide now document `Elliptical` (radii are half the element's width and height; `Offset` shifts it, `Rotation` rotates its axes), behind the **Upgraded UIGradients** Studio beta; see the 0.743 section |
| `+TestService.Enabled` (bool, `ReadOnly`) — reads `false` in an edit session *(Studio)* | Read-only; nothing to migrate |
| `+BackendReplicatedStorage`, `+BackendServerScriptService`, `+BackendServerStorage` — services with **zero members**, `NotCreatable`, no docs page | Nothing to call and nothing documented. Do not put scripts or assets in them on the strength of their names |
| `Decal.LocalizedTextureContent`, `ImageLabel.LocalizedImageContent`, `ImageButton.LocalizedImageContent`: `Write` → `NotAccessibleSecurity`, `ReadOnly` tag dropped | No action. `Read` is still `RobloxScriptSecurity`, so game code could not read these before 0.741 and still cannot |
| Roblox-internal additions — `RobloxScriptSecurity` / `RobloxSecurity`, not callable by you: `FriendsCallingInstance` / `FriendsCallingParticipant` (+5 `FriendsCalling*` enums), `ProjectService`, `AssetService` `CreateTextContentAsync` / `ReadTextContentAsync`, `NotificationService` topic subscription, `ScriptEditorService` `OpenStringValueDocumentAsync`; 15 `StarterPlayer.GameSettings*` properties **removed** (all were `RobloxScriptSecurity`) | Ignore for game code. `TextDocument` is new too: `NotBrowsable`, its one property `PluginSecurity` |

> **Corrections to the older rows below, found by the 0.741 prose audit.** Until 0.741 the audit
> checked code blocks only, never prose or tables, and several rows here listed members as usable
> that the very dump each row was derived from marked `RobloxScriptSecurity` (or `NotScriptable`).
> All were wrong on the day they were written; none is a 0.741 change. Each row is now corrected in
> place: `CallingService` (every member, so the 0.739 `CreateCall` → `CreateCallAsync` "rename" is not
> a migration any game has to do), `AnimatedImageService` / `AnimatedImage`, `MomentsService`,
> `PinShortcutService`, `Decal.LocalizedTextureContent`, `ExternalIdentityService`,
> `UGCValidationService` post-deformation sizing, `Terrain` transform-subregion slots,
> `TextChannel.IsDefaultTextChannel`, `StateMachineTransitionDefinition.TransitionId`,
> `WorldRoot.PhysicsStepTime`, the deprecated `DataModel.IsPioneerBuild` / `PioneerSource`, and the
> `NotScriptable` `Workspace.UseInputSink`. If an older copy of this file is in your context, the
> rows here win.

### September 2026 — engine 0.740.19.7400931 (ingested 2026-09-25)

Derived by diffing the **0.739 and 0.740 Full API Dumps locally** (`python3` over
`~/RobloxDocs/RobloxAPI/dumps/`), 2026-09-25. **924 classes (−1), 635 enums (−1), 258 classes named
`*Service`, 48 deprecated classes.** Luau 0.739 (2026-09-18). Note this is a *shrinking* release — the first in this
window where the dump got smaller.

| Change | Action Required |
|--------|-----------------|
| `LocalizationService:GetTranslatorForPlayer()` **newly Deprecated** | Migrate to **`GetTranslatorForPlayerAsync()`** (the dump names it as the preferred descriptor). The old call still exists but now emits a deprecation lint |
| **`SnippetService` REMOVED** (whole class) | If anything referenced it, it is gone. Nothing in this skill did |
| **`Enum.Language` REMOVED** | Remove any `Enum.Language` usage |
| `TriangleMeshPart.CollisionFidelity` / `.FluidFidelity` and `PartOperation.RenderFidelity` / `.SmoothingAngle`: `Security.Write` **`PluginSecurity` → `None`** | **Still not writable from a game Script** (corrected in 2.15.0, measured in Studio 0.742). Each member gained `Capabilities.Write: ["PluginOrOpenCloud"]`, and an ordinary unsandboxed Script does not hold that capability: the write fails with "lacking capability PluginOrOpenCloud". This row used to say "newly script-writable at runtime". Set them at author time. `MeshPart.RenderFidelity` followed in 0.742, the same way. See `performance-optimization.md` §3 |
| `Lighting.LightingStyle` (enum `Realistic`/`Soft`) and `Lighting.PrioritizeLightingQuality` (bool): `Security.Write` **`RobloxScriptSecurity` → `None`** | **Plugin-only, not settable from a game Script** (corrected in 2.15.0): the `Capabilities.Write: ["PluginOrOpenCloud"]` they gained blocks an ordinary Script (measured in Studio 0.742 for both). Set them in the Properties window. This row used to call them "developer-settable from a script" |
| `+TeleportOptions.ReservedServerId`, `+TeleportOptions.VipServerId`; `Enum.TeleportMethod` +`TeleportSwitchServer` | New public teleport targeting fields. **Update (0.745):** the docs now prefer them to `ReserveServerAsync`, but `TeleportAsync` with either one failed in Studio 0.745; see the 0.745 and 0.746 rows. The matching `TeleportService:TeleportSwitchServer()` is **`RobloxScriptSecurity`** — you cannot call it, so do not build on it |
| `WorldRoot.PhysicsStepTime` gained the **`ReadOnly`** tag | No action. It is `RobloxScriptSecurity` for both read and write, so game code could never touch it in the first place |
| `+AudioTextToSpeech.AutoLocalize`, `+InputAction.DisplayName` | New public properties; `DisplayName` is useful for IAS rebinding UI (see `project-structure.md`) |
| `+WrapTextureTransfer:PrepareProjectionMeshDataAsync()` (Yields, no security) | New public LC/UGC mesh-projection helper |
| `+CaptureService:StartVideoCaptureForMCPAsync()` / `:StopVideoCaptureForMCP()` | **`RobloxScriptSecurity` — not callable by you.** Listed only because the name suggests Studio MCP is growing a video-capture path; it is not an API you can use, and no MCP tool exposes it today |
| Other additions are `RobloxScriptSecurity`: `MarketplaceService` bulk-purchase refresh signals, `MomentsService:FetchPostAsync`, `PerformanceControlService:SetUserActivity`, `AssetQualityService:…V2Async`, `Plugin:GetPreinitPayload` | Ignore for game code; none are callable from a Script |

### September 2026 — engine 0.739 (2026-09-17)

Derived by diffing the **0.738 and 0.739 Full API Dumps locally** (`python3` over
`~/RobloxDocs/RobloxAPI/dumps/`), 2026-09-17. 925 classes (+4, 0 removed), 636 enums (+3), 259 classes named `*Service`, 48 deprecated classes. Luau unchanged at 0.738.

| Change | Action Required |
|--------|-----------------|
| `CallingService.CreateCall` **RENAMED** to `CreateCallAsync` (now **Yields**) | No action for game code: both names are **`RobloxScriptSecurity`**, so no Script could ever call either. Recorded for completeness only |
| `+UGCValidationService:GetLayeredClothingPostDeformationSizeAsync()` (Yields) | **`RobloxScriptSecurity` — not callable by you.** Roblox-internal UGC validation |
| `+StateMachineTransitionDefinition` (`From`, `To`, `Priority`, `TransitionId`) | New class for state machine animation graphs. `From` / `To` / `Priority` are public; `TransitionId` is `RobloxScriptSecurity` (not readable by game code) |
| `+Terrain:SetMaterialInTransformSubregionSlot()`, `:ReplaceMaterialInTransformSubregionSlot()` | **`RobloxScriptSecurity` — not callable by you.** Roblox-internal terrain tooling |
| `+ChatWindowConfiguration.TextChannelDisplayMode`, `+TextChannel.IsDefaultTextChannel` (Hidden) | `TextChannelDisplayMode` is a public chat-window knob. `IsDefaultTextChannel` is `RobloxScriptSecurity` — not readable by game code |
| New classes: `+AdPlacement`, `+ExternalIdentityService`, `+QueueService`, `+StandardQueue` | `AdPlacement`, `QueueService:GetStandardQueue()` and `StandardQueue` (`PublishAsync`, `SubscribeAsync`, `BatchCommitAsync`) are public — check their documentation before building on them. Every `ExternalIdentityService` member is `RobloxScriptSecurity` — not callable by you |
| Enums: `+AnimationNodeBlendMode`, `+QueueDecision`, `+TextChannelDisplayMode`; `AnimationNodeType` +`OneShotNode`, +`StateMachineNode`; `PromptCreateOutfitResult` +`UGCValidationFailed` | New enum members and categories |

### September 2026 — engine 0.738 (2026-09-11)

Derived by diffing the **0.737 and 0.738 Full API Dumps locally** (`python3` over
`~/RobloxDocs/RobloxAPI/dumps/`), 2026-09-12. 921 classes (+6 −1), 633 enums (+4).

| Change | Action Required |
|--------|-----------------|
| `GuiObject:TweenPosition()`, `:TweenSize()`, `:TweenSizeAndPosition()` and `GuiObject.Transparency` newly **Deprecated** | Use `TweenService:Create()` on `Position`/`Size`, and `BackgroundTransparency`/`TextTransparency` etc. Grep for `:TweenPosition(` / `:TweenSize(` — Starship had 0 call sites on 2026-09-12 |
| `DataModelPatchService` **REMOVED** (`GetLuaVersion`, `GetPatch`, `RegisterPatch`, `UpdatePatch`) | Nothing to do: every member was `RobloxScriptSecurity`, so no game script could call it (it was in every dump from 0.733 to 0.737) |
| `+AnimatedImageService` (five track methods at the time, all removed again in 0.743), `+AnimatedImage` GuiBase (`Content`, `PlaybackSpeed`, `Pause`, `Resume`), `+AnimatedImageTrack`, enums `AnimatedImagePlaybackState` / `AnimatedImageScaleType` | **Not usable from game code.** Every listed `AnimatedImageService` and `AnimatedImage` member is `RobloxScriptSecurity` (and `AnimatedImage` is `NotCreatable`), so there is nothing a Script can call yet. An earlier version of this row called it "new" without saying so |
| `+RunService:BindToAnimation()` | New, no docs page yet — treat as unstable |
| `+Workspace.StreamingAdaptiveRadius` | New streaming knob; check the property page before touching streaming tuning |
| `+TextChannel.AddPlayersOnJoin` | New; relevant to any custom `TextChatService` channel setup |
| `+Folder.IconTint`, `+AnimationImportData.VersionedAssetId` / `.ForceNewVersion`, `+ScriptService:ResolveModulePath()` | New public surface, none required for existing code |
| `+MomentsService` (`CreatePostAsync`, `GenerateMomentTextAsync`, `CheckMomentTextStatusAsync`), `+PinShortcutService` (all six members), `+Decal.LocalizedTextureContent` | **`RobloxScriptSecurity` — not callable or readable by you.** An earlier version of this row listed them as "new public surface" |

### September 2026 — engine 0.737

Derived by diffing the **0.736 and 0.737 Full API Dumps locally**, not from release-note prose, so
each row is checkable with `jq` against `~/RobloxDocs/RobloxAPI/dumps/`.

| Change | Action Required |
|--------|-----------------|
| `GeometryService:CreateSolidPrimitive()` **REMOVED**, replaced by `GeometryService:CreateBasicMeshPart()` | Rewrite call sites. The enum went with it: `SolidPrimitiveType` was removed and `BasicMeshPartShape` added |
| `PlayerControlState` **RENAMED** to `ControlState` | Rename references. Verified a pure rename — the member lists are identical, and both are `NotBrowsable` |
| `DataModel.IsPioneerBuild` / `DataModel.PioneerSource` newly **deprecated** | No action: both are `RobloxScriptSecurity`, so game code could never read them |
| `+CallingService` (`CreateCall`, `AnswerIncomingCall`, `EndCall`, `GetCallingState`, `OnCallingStateChange`, `OnCallingRemoved`) | **Every member is `RobloxScriptSecurity` — not callable by you.** The July 15 Roblox Connect sunset above is a *different*, older API |
| `+WrapContentProvider` | Service exists but exposes **no members yet** — nothing to call |
| `+AssetService:PromptCreatePlatformContentAsync()`, `+WrapTarget:CreateTextureInCageSpaceAsync()` / `:CreateTextureInTargetSpaceAsync()`, `+TextChannelWindow.FontFace` / `.UseDefaultFont` | New public surface |
| `+Workspace.UseInputSink` (`Enum.RolloutState`) | A Studio Properties-window setting: it is `NotScriptable`, so no script — MCP `execute_luau` included — can read or set it. **Update (0.746):** removed; see the 0.746 row |

> **`PlayerControlState` is a cautionary tale about writing against brand-new APIs.** It first
> appeared in 0.735 and was gone by 0.737 — two weeks. An API that is `NotBrowsable` and days old is
> not a stable contract.

### `PlayerOwnsAsset` Breaking Change (Early 2026)

Inventory privacy enforcement changed the behavior of `PlayerOwnsAsset` and
inventory web APIs. Player inventory is now private by default.

<!-- skilltest: prelude ownership-ids -->
```lua
-- ⚠️ This may now return false even if the player owns the asset
-- due to privacy settings. (PlayerOwnsAsset, without Async, is deprecated.)
local success, owns = pcall(function()
    return MarketplaceService:PlayerOwnsAssetAsync(player, assetId)
end)

-- ✅ For GamePass checks, use this instead (unaffected):
local success, owns = pcall(function()
    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
end)
```

**Alternative approaches for asset ownership:**

| Asset Type | Recommended Check |
|-----------|------------------|
| Game Passes | `MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)` |
| Badges | `BadgeService:UserHasBadgeAsync(player.UserId, badgeId)` |
| Avatar items | Open Cloud Inventory API for a server-side check. `AvatarEditorService:GetItemDetailsAsync()` returns an `Owned` field, but per the official page it describes the **current user** only — a client-side answer about the local player, so never trust it to grant anything. (Its non-Async form `GetItemDetails()` is deprecated) |
| Generic assets | Open Cloud `GET /cloud/v2/users/{userId}/inventory-items` |

**Migration**: Use the new Economy API endpoints for asset ownership checks.
Consult https://create.roblox.com/docs for the latest API reference.

### `UserHasBadgeAsync` / `CheckUserBadgesAsync` (March 2026)

Modified return behavior. Check current documentation for updated return values.

---

## Scoped User Identifiers (opt-in testing; rollout delayed)

> [!WARNING]
> **Status (checked 2026-10-11): opt-in early testing; the broad rollout is delayed, with no new
> date.** Roblox announced Scoped User IDs on 2026-06-10 with a roadmap ending in a rollout to all
> games in October 2026. A staff update on 2026-09-01 says the change "is coming later than we said
> it would" and that the updated solution and timeline will be shared in October; none had been
> posted by 2026-10-11 (DevForum topic 4677155). Players would receive a user ID per experience
> instead of the global UserId, but only for players whose first visit to a game comes after the
> rollout. Re-check the announcement before planning around a date.
>
> **Re-checked 2026-10-29:** still no staff post after 2026-09-01. The official page was rewritten
> on 2026-10-23 as *Users and scoped user IDs*: each user has one **effective user ID** per game,
> **group** or app (global for pre-rollout users, scoped for post-rollout users), scoped IDs "have
> not rolled out broadly yet", and it says `Player.User.Id` always equals `Player.UserId`. **Studio
> 0.745 does not match that last point** for the account tested here (see step 3 below). In-game
> group checks (`IsInGroupAsync`, `GetRankInGroupAsync`) do not change; Open Cloud group APIs use
> the group's domain. When another domain reads a stored identity, store `user:ToString()`.

### What Does NOT Change
- **Single-game DataStores**: `Player_{UserId}` pattern **still works**. No migration needed.
- `player.UserId` continues to return a numeric value (Global for existing players, Scoped for new)
- Scoped and global IDs do not collide: "A domain-scoped user ID does not collide with any existing
  global user ID" (official *Users and domain-scoped user IDs* page, checked 2026-10-11)
- Friends, chat, avatar services continue working

### What BREAKS
- **Cross-game progression** — Same player has different IDs in different games
- **Cross-game ban lists** — Custom bans using shared Global UserIds won't match new players
- **Cross-game gifting** — Offline player lookup by UserId across universes fails
- **Hub → Sub-game architectures** — Teleported players may have different IDs

### New Engine Primitives
<!-- skilltest: prelude user-ids -->
```lua
--!strict
-- NEW: User data type (available now for early testing)
local player: Player = ... -- from PlayerAdded
local user = player.User
print(user.DomainType)  -- Enum.DomainType.EXPERIENCE
print(user.DomainId)    -- Current Universe ID

-- Convert legacy Global ID → User object
local UserService = game:GetService("UserService")
local user = UserService:GetUserFromGlobalUserIdAsync(oldGlobalUserId)

-- Convert numeric ID → User object
local user = User.fromId(numericId)
```

### Solutions Being Developed by Roblox

| Solution | Expected | Purpose |
|----------|----------|---------|
| **User Account Linking API** | Promised before the broad rollout (the June roadmap said August 2026; timeline under revision since 2026-09-01) | Consent-based cross-game identity linking |
| **Ban API improvements** | Promised before the broad rollout (timeline under revision) | Cross-experience ban lists |

### What to Do NOW
1. **Audit** cross-game systems (bans, progression, gifting)
2. **Single-game DataStores**: Do nothing — pattern still works
3. **Start using `player.User` object** in new code instead of raw `player.UserId` (the official
   *Users* page recommends it), but **do not re-key existing saves**: in a Studio 0.742 playtest
   (2026-10-11) the same returning player had `player.UserId` 8935399566 and `player.User.Id`
   1237928291809. Data saved under `Player_{UserId}` is not found under `User.Id`. Keep the key
   scheme your saves use, or migrate them explicitly. Re-run in Studio 0.745 (2026-10-29): the
   same two values, while `User.fromId(player.UserId).Id` returns `8935399566`. The page now says
   the two always match; a staff reply in the announcement (post #361) called the playtest
   mismatch a bug to fix. Until Studio agrees, do not assume they are interchangeable
4. **Monitor** the announcement for the Account Linking API and the revised timeline
5. **Do NOT bypass** scoped IDs: the announcement's FAQ says tracking players across games without
   their consent, by fingerprinting, device signals or any other method, is a violation

> [!IMPORTANT]
> For full migration details and the latest guidance, consult:
> https://create.roblox.com/docs
> If information is unclear or incomplete, ask the user before proceeding
> with any migration approach.

---

## Detection Commands (Updated 2026)

Add these to your `script_grep` scans:

```text
script_grep("PlayerOwnsAsset")       -- breaking change (early 2026)
script_grep("CrossGameSale")         -- discontinued (May 2026)
script_grep("AdService")             -- removed signals (June 2026)
script_grep("Accoutrement")          -- removed props (June 2026)
script_grep("UserHasBadge")          -- modified behavior (March 2026)
```

