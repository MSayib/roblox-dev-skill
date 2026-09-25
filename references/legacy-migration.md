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
| Legacy GamePass APIs | `MarketplaceService` methods | ⚠️ Mostly | Check April 2026 deprecation notes |
| Old Type Solver | New Type Solver (GA Nov 2025) | Auto | Auto-enabled; `--!strict` behavior improved |
| `Instance.new` + parent first | Set `Parent` **last** | ✅ Yes | Avoids redundant replication/events |
| `RunService.Stepped` | `RunService.PreSimulation` | Same behavior, clearer name | 2024 |
| `RunService.Heartbeat` | `RunService.PostSimulation` | Same behavior, clearer name | 2024 |
| `RunService.RenderStepped` | `RunService.PreRender` | Same behavior, clearer name | 2024 |
| `LocalizationService:GetTranslatorForPlayer()` | `:GetTranslatorForPlayerAsync()` | ⚠️ Mostly | Deprecated in engine **0.740**. The async form **yields** — wrap it or call it off the critical path |
| `CallingService:CreateCall()` | `:CreateCallAsync()` | ❌ No | Renamed in 0.739 and now yields. Note the Roblox Connect calling APIs were sunset July 15, 2026 |

---

## Detailed Migration Guides

### 1. Task Library (`spawn` / `delay` / `wait`)

The globals use a legacy scheduler with throttling. The `task` library is the
standard replacement (available since 2021).

```luau
-- ❌ Legacy                        -- ✅ Modern
spawn(function()                    task.spawn(function()
    wait(2)                             task.wait(2)
    print("Hello")                      print("Hello")
end)                                end)

delay(5, function()                 task.delay(5, function()
    print("Delayed")                    print("Delayed")
end)                                end)
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
-- ❌ Legacy (parent first)         -- ✅ Modern (parent last)
local part = Instance.new("Part")   local part = Instance.new("Part")
part.Parent = workspace             part.Size = Vector3.new(4, 1, 4)
part.Size = Vector3.new(4, 1, 4)   part.Anchored = true
part.Anchored = true                part.Parent = workspace
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
-- Conceptual migration loader (server-side)
local ProfileStore = require(game.ServerScriptService.ProfileStore)
local DataStoreService = game:GetService("DataStoreService")
local legacyStore = DataStoreService:GetDataStore("PlayerData")

type PlayerData = { Coins: number, Inventory: { string }, Migrated: boolean }
local DEFAULT_DATA: PlayerData = { Coins = 0, Inventory = {}, Migrated = false }
local playerStore = ProfileStore.New("PlayerProfiles", DEFAULT_DATA)

local function loadPlayer(player: Player)
    local profile = playerStore:StartSessionAsync(
        `Player_{player.UserId}`, { Cancel = player.AncestryChanged }
    )
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

Auto-enabled for all experiences. Provides better type inference and stricter
`--!strict` checking. Some previously-passing code may now error:

```luau
-- Error: Type 'Instance?' could not be converted to 'Part'
local part = workspace:FindFirstChild("MyPart") -- returns Instance?

-- ✅ Fix: guard with IsA
local maybePart = workspace:FindFirstChild("MyPart")
if maybePart and maybePart:IsA("Part") then
    local part: Part = maybePart
    part.Anchored = true
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
| `economy.roblox.com/v1/purchases/products/{productId}` **REMOVED** | April 10 | Migrate to Open Cloud APIs |
| Legacy GamePass/DevProduct purchase APIs deprecated | April 23 | Use `MarketplaceService` methods |

### May 2026

| Change | Date | Action Required |
|--------|------|-----------------|
| Publishing fee: 1,000 Robux per game (or Roblox Plus) | May 19 | Budget for new game launches |
| **Cross-game sales DISABLED** | May 29 | Use Transfers API for donations. See `references/monetization.md` |

### June 2026

| Change | Date | Action Required |
|--------|------|-----------------|
| `Accoutrement` state props/methods removed | Mid-June | Remove usage if any |
| `AdService` / `AdGui` signals removed | Mid-June | Migrate to current ad APIs |
| Input Action System (IAS) full release | June 11 | `Workspace.PlayerScriptsUseInputActionSystem`. See `references/project-structure.md` |
| Roblox Connect calling APIs **SUNSET** | **July 15** | Remove usage before deadline |

### September 2026 — engine 0.740.19.7400931 (ingested 2026-09-25)

Derived by diffing the **0.739 and 0.740 Full API Dumps locally** (`python3` over
`~/RobloxDocs/RobloxAPI/dumps/`), 2026-09-25. **924 classes (−1), 635 enums (−1), 258 services,
48 deprecated.** Luau 0.739 (2026-09-18). Note this is a *shrinking* release — the first in this
window where the dump got smaller.

| Change | Action Required |
|--------|-----------------|
| `LocalizationService:GetTranslatorForPlayer()` **newly Deprecated** | Migrate to **`GetTranslatorForPlayerAsync()`** (the dump names it as the preferred descriptor). The old call still exists but now emits a deprecation lint |
| **`SnippetService` REMOVED** (whole class) | If anything referenced it, it is gone. Nothing in this skill did |
| **`Enum.Language` REMOVED** | Remove any `Enum.Language` usage |
| `TriangleMeshPart.CollisionFidelity` / `.FluidFidelity` and `PartOperation.RenderFidelity` / `.SmoothingAngle`: `Security.Write` **`PluginSecurity` → `None`** | **Newly script-writable at runtime.** Before 0.740 an ordinary Script could not set these. **`MeshPart.RenderFidelity` was NOT relaxed** and stays `PluginSecurity`. Each relaxed member gains `Capabilities.Write: ["PluginOrOpenCloud"]`, which only applies inside an opt-in sandboxed container. See `performance-optimization.md` §3 |
| `Lighting.LightingStyle` (enum `Realistic`/`Soft`) and `Lighting.PrioritizeLightingQuality` (bool): `Security.Write` **`RobloxScriptSecurity` → `None`** | Both are now developer-settable from a script, having been Roblox-internal. Same `Capabilities.Write: ["PluginOrOpenCloud"]` caveat |
| `+TeleportOptions.ReservedServerId`, `+TeleportOptions.VipServerId`; `Enum.TeleportMethod` +`TeleportSwitchServer` | New public teleport targeting fields. The matching `TeleportService:TeleportSwitchServer()` is **`RobloxScriptSecurity`** — you cannot call it, so do not build on it |
| `WorldRoot.PhysicsStepTime` gained the **`ReadOnly`** tag | Any code assigning to it was already wrong and is now explicitly rejected |
| `+AudioTextToSpeech.AutoLocalize`, `+InputAction.DisplayName` | New public properties; `DisplayName` is useful for IAS rebinding UI (see `project-structure.md`) |
| `+WrapTextureTransfer:PrepareProjectionMeshDataAsync()` (Yields, no security) | New public LC/UGC mesh-projection helper |
| `+CaptureService:StartVideoCaptureForMCPAsync()` / `:StopVideoCaptureForMCP()` | **`RobloxScriptSecurity` — not callable by you.** Listed only because the name suggests Studio MCP is growing a video-capture path; it is not an API you can use, and no MCP tool exposes it today |
| Other additions are `RobloxScriptSecurity`: `MarketplaceService` bulk-purchase refresh signals, `MomentsService:FetchPostAsync`, `PerformanceControlService:SetUserActivity`, `AssetQualityService:…V2Async`, `Plugin:GetPreinitPayload` | Ignore for game code; none are callable from a Script |

### September 2026 — engine 0.739 (2026-09-17)

Derived by diffing the **0.738 and 0.739 Full API Dumps locally** (`python3` over
`~/RobloxDocs/RobloxAPI/dumps/`), 2026-09-17. 925 classes (+4, 0 removed), 636 enums (+3), 259 services, 48 deprecated. Luau unchanged at 0.738.

| Change | Action Required |
|--------|-----------------|
| `CallingService.CreateCall` **RENAMED** to `CreateCallAsync` (now **Yields**) | Breaking change for any code invoking `CreateCall`. Update callers to `CreateCallAsync` and handle yielding |
| `+UGCValidationService:GetLayeredClothingPostDeformationSizeAsync()` (Yields) | New LC/UGC validation method for post-deformation bounding checks |
| `+StateMachineTransitionDefinition` (`From`, `To`, `Priority`, `TransitionId`) | New class for state machine animation graphs |
| `+Terrain:SetMaterialInTransformSubregionSlot()`, `:ReplaceMaterialInTransformSubregionSlot()` | New voxel terrain transformation methods |
| `+ChatWindowConfiguration.TextChannelDisplayMode`, `+TextChannel.IsDefaultTextChannel` (Hidden) | New chat window display configuration knobs |
| New classes: `+AdPlacement`, `+ExternalIdentityService`, `+QueueService`, `+StandardQueue` | Engine additions; check documentation before building on new queue or ad services |
| Enums: `+AnimationNodeBlendMode`, `+QueueDecision`, `+TextChannelDisplayMode`; `AnimationNodeType` +`OneShotNode`, +`StateMachineNode`; `PromptCreateOutfitResult` +`UGCValidationFailed` | New enum members and categories |

### September 2026 — engine 0.738 (2026-09-11)

Derived by diffing the **0.737 and 0.738 Full API Dumps locally** (`python3` over
`~/RobloxDocs/RobloxAPI/dumps/`), 2026-09-12. 921 classes (+6 −1), 633 enums (+4).

| Change | Action Required |
|--------|-----------------|
| `GuiObject:TweenPosition()`, `:TweenSize()`, `:TweenSizeAndPosition()` and `GuiObject.Transparency` newly **Deprecated** | Use `TweenService:Create()` on `Position`/`Size`, and `BackgroundTransparency`/`TextTransparency` etc. Grep for `:TweenPosition(` / `:TweenSize(` — Starship had 0 call sites on 2026-09-12 |
| `DataModelPatchService` **REMOVED** (`GetLuaVersion`, `GetPatch`, `RegisterPatch`, `UpdatePatch`) | Nothing to do unless you called it; it was `NotBrowsable` and lived one release |
| `+AnimatedImageService` (`GetTrack`, `Prewarm`, `UnloadTracks`, `GetFrameNames`, `GetTracksChanged`), `+AnimatedImage` GuiBase (`Content`, `PlaybackSpeed`, `Pause`, `Resume`), `+AnimatedImageTrack`, enums `AnimatedImagePlaybackState` / `AnimatedImageScaleType` | New: engine-native animated images. `AnimatedImage` is `NotCreatable` in this dump — read the docs before designing on it |
| `+RunService:BindToAnimation()` | New, no docs page yet — treat as unstable |
| `+Workspace.StreamingAdaptiveRadius` | New streaming knob; check the property page before touching streaming tuning |
| `+TextChannel.AddPlayersOnJoin` | New; relevant to any custom `TextChatService` channel setup |
| `+MomentsService` (`CreatePostAsync`, `GenerateMomentTextAsync`, `CheckMomentTextStatusAsync`), `+PinShortcutService` members, `+Folder.IconTint`, `+Decal.LocalizedTextureContent` (read-only), `+AnimationImportData.VersionedAssetId` / `.ForceNewVersion`, `+ScriptService:ResolveModulePath()` | New public surface, none required for existing code |

### September 2026 — engine 0.737

Derived by diffing the **0.736 and 0.737 Full API Dumps locally**, not from release-note prose, so
each row is checkable with `jq` against `~/RobloxDocs/RobloxAPI/dumps/`.

| Change | Action Required |
|--------|-----------------|
| `GeometryService:CreateSolidPrimitive()` **REMOVED**, replaced by `GeometryService:CreateBasicMeshPart()` | Rewrite call sites. The enum went with it: `SolidPrimitiveType` was removed and `BasicMeshPartShape` added |
| `PlayerControlState` **RENAMED** to `ControlState` | Rename references. Verified a pure rename — the member lists are identical, and both are `NotBrowsable` |
| `DataModel.IsPioneerBuild` / `DataModel.PioneerSource` newly **deprecated** | Stop reading them |
| `+CallingService` (`CreateCall`, `AnswerIncomingCall`, `EndCall`, `GetCallingState`, `OnCallingStateChange`, `OnCallingRemoved`) | New; note the July 15 Roblox Connect sunset above is a *different*, older API |
| `+WrapContentProvider` | Service exists but exposes **no members yet** — nothing to call |
| `+AssetService:PromptCreatePlatformContentAsync()`, `+WrapTarget:CreateTextureInCageSpaceAsync()` / `:CreateTextureInTargetSpaceAsync()`, `+TextChannelWindow.FontFace` / `.UseDefaultFont`, `+Workspace.UseInputSink` | New public surface |

> **`PlayerControlState` is a cautionary tale about writing against brand-new APIs.** It first
> appeared in 0.735 and was gone by 0.737 — two weeks. An API that is `NotBrowsable` and days old is
> not a stable contract.

### `PlayerOwnsAsset` Breaking Change (Early 2026)

Inventory privacy enforcement changed the behavior of `PlayerOwnsAsset` and
inventory web APIs. Player inventory is now private by default.

```lua
-- ⚠️ This may now return false even if the player owns the asset
-- due to privacy settings
local success, owns = pcall(function()
    return MarketplaceService:PlayerOwnsAsset(player, assetId)
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
| Avatar items | `AvatarEditorService:GetItemDetails()` or Open Cloud Inventory API |
| Generic assets | Open Cloud `GET /cloud/v2/users/{userId}/inventory-items` |

**Migration**: Use the new Economy API endpoints for asset ownership checks.
Consult https://create.roblox.com/docs for the latest API reference.

### `UserHasBadgeAsync` / `CheckUserBadgesAsync` (March 2026)

Modified return behavior. Check current documentation for updated return values.

---

## Scoped User Identifiers (October 2026)

> [!WARNING]
> **Rollout: October 2026** — Players will receive domain-scoped user IDs per
> experience instead of global UserIds. This is a major platform change.

### What Does NOT Change
- **Single-game DataStores**: `Player_{UserId}` pattern **still works**. No migration needed.
- `player.UserId` continues to return a numeric value (Global for existing players, Scoped for new)
- Scoped and Global IDs are described as non-colliding — but this line is **not verified against a
  current primary source**; confirm on the Scoped User IDs doc before designing a key scheme that
  depends on it
- Friends, chat, avatar services continue working

### What BREAKS
- **Cross-game progression** — Same player has different IDs in different games
- **Cross-game ban lists** — Custom bans using shared Global UserIds won't match new players
- **Cross-game gifting** — Offline player lookup by UserId across universes fails
- **Hub → Sub-game architectures** — Teleported players may have different IDs

### New Engine Primitives
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
| **User Account Linking API** | August 2026 | Consent-based cross-game identity linking |
| **Ban API improvements** | Before October 2026 | Cross-experience ban lists |

### What to Do NOW
1. **Audit** cross-game systems (bans, progression, gifting)
2. **Single-game DataStores**: Do nothing — pattern still works
3. **Start using `player.User` object** in new code instead of raw `player.UserId`
4. **Monitor** for Account Linking API (August 2026)
5. **Do NOT bypass** scoped IDs — may violate platform policies

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

