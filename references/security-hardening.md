# Security Hardening Reference

> **Source**: Roblox official security documentation  
> https://create.roblox.com/docs/en-us/scripting/security/security-tactics  
> https://create.roblox.com/docs/en-us/scripting/security/client-server-boundary  
> https://create.roblox.com/docs/en-us/scripting/security/access-control  
> https://create.roblox.com/docs/en-us/scripting/security/network-ownership  
> https://create.roblox.com/docs/en-us/scripting/security/defensive-design  
> https://create.roblox.com/docs/en-us/scripting/security/third-party-vulnerabilities

## Table of Contents

1. [Core Principle: Never Trust the Client](#1-core-principle-never-trust-the-client)
2. [Server-Side Validation Patterns](#2-server-side-validation-patterns)
3. [Input Sanitization for RemoteEvents](#3-input-sanitization-for-remoteevents)
4. [Architecture Security](#4-architecture-security)
5. [Anti-Cheat Design Philosophy](#5-anti-cheat-design-philosophy)
6. [Rate Limiting](#6-rate-limiting)
7. [Data Protection](#7-data-protection)
8. [Script Security](#8-script-security)
9. [Complete Example: Secure RemoteEvent Handler](#9-complete-example-secure-remoteevent-handler)
10. [BanAsync API + Device Blocking (June 2026)](#10-banasync-api--device-blocking-june-2026)
11. [Scoped User Identifiers Warning (October 2026)](#11-scoped-user-identifiers-warning-october-2026)
12. [Mid-2026 Changelog](#12-mid-2026-changelog)

---

## 1. Core Principle: Never Trust the Client

This is the foundational principle of Roblox security. A determined exploiter has **complete
control** over their local state and network traffic. Per Roblox docs, exploiters can:

- **Decompile** any replicated `LocalScript` or `ModuleScript`, even if never run on client
- **Take network ownership** of their character and any unanchored parts
- **Trigger events** (`Touched`, `ProximityPrompt`) at any range or frequency
- **Modify** position, physics, or interactions with the world
- **Fire RemoteEvents/RemoteFunctions** at any frequency with arbitrary arguments
- **Change anything** in their local DataModel without firing expected events
- **Alter behavior** of any locally running code

**All critical logic must be validated server-side or run exclusively on the server.**

---

## 2. Server-Side Validation Patterns

Every piece of data from a client must pass multiple validation layers.

### Type Checking with typeof()

```luau
--!strict
local function validateType(value: unknown, expectedType: string): boolean
    return typeof(value) == expectedType
end

-- Usage in a remote handler:
remoteEvent.OnServerEvent:Connect(function(player: Player, itemName: unknown)
    if typeof(itemName) ~= "string" then
        return -- Reject: wrong type
    end
    -- Also guard against tables spoofing instances:
    -- typeof(item) ~= "Instance" catches table payloads
end)
```

### Range Validation

```luau
--!strict
local function isFiniteNumber(n: number): boolean
    -- Rejects NaN (n ~= n) and Inf (math.abs(n) == math.huge)
    return n == n and math.abs(n) ~= math.huge
end

local function isInRange(value: number, min: number, max: number): boolean
    return isFiniteNumber(value) and value >= min and value <= max
end
```

> **Warning**: NaN passes `typeof() == "number"` and silently fails **all** comparison
> operators. `NaN < 0` is false, `NaN > 1000000` is also false. Always check explicitly.

### State Validation

```luau
--!strict
local function isPlayerAlive(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

local function isInRange(player: Player, targetPos: Vector3, maxDist: number): boolean
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    return (rootPart.Position - targetPos).Magnitude <= maxDist
end
```

### Cooldown Enforcement

```luau
--!strict
local COOLDOWN_SECONDS = 1.5
local lastActionTime: { [Player]: number } = {}

local function isOnCooldown(player: Player): boolean
    local last = lastActionTime[player]
    if last and (time() - last) < COOLDOWN_SECONDS then
        return true
    end
    lastActionTime[player] = time()
    return false
end
```

---

## 3. Input Sanitization for RemoteEvents

### The Danger of NaN

NaN is uniquely dangerous: it is of type `"number"` but fails all standard comparisons.
An exploiter can send NaN to bypass range checks, inventory checks, and corrupt DataStores.

```luau
--!strict
local function isNaN(n: number): boolean
    return n ~= n -- NaN is never equal to itself
end

local function isInf(n: number): boolean
    return math.abs(n) == math.huge
end

local function sanitizeNumber(n: unknown): number?
    if typeof(n) ~= "number" then return nil end
    local num = n :: number
    if isNaN(num) or isInf(num) then return nil end
    return num
end
```

### Validate Instance Arguments

Exploiters can send tables that mimic Instance structure. Always use `typeof()` and
verify ancestry:

```luau
--!strict
local itemDataFolder = game:GetService("ReplicatedStorage"):WaitForChild("ItemData")

local function validateItemInstance(item: unknown): boolean
    if typeof(item) ~= "Instance" then return false end
    -- Verify it's actually in the expected folder
    return (item :: Instance):IsDescendantOf(itemDataFolder)
end
```

### Sanitize Strings for DataStore

DataStores only accept valid UTF-8. Validate strings before storing:

```luau
--!strict
local MAX_STRING_LENGTH = 200

local function sanitizeString(s: unknown): string?
    if typeof(s) ~= "string" then return nil end
    local str = s :: string
    if #str > MAX_STRING_LENGTH then return nil end
    if not utf8.len(str) then return nil end -- invalid UTF-8
    return str
end
```

---

## 4. Architecture Security

### Container Visibility Rules

| Container              | Server Access | Client Access | Notes                                         |
|------------------------|:------------:|:-------------:|-----------------------------------------------|
| `ServerScriptService`  | ✅           | ❌            | Never replicated. Store all server logic here  |
| `ServerStorage`        | ✅           | ❌            | Never replicated. Store sensitive assets here  |
| `ReplicatedStorage`    | ✅           | ✅            | **Visible to clients.** No secrets here        |
| `Workspace`            | ✅           | ✅            | **Visible to clients.** Geometry, models       |
| `StarterPlayerScripts` | ✅           | ✅            | Client scripts. Can be decompiled              |

**Key rules from docs:**
- Keep logic and data in `ServerScriptService` from day one
- Never place server logic in replicated containers (`ReplicatedStorage`, `Workspace`)
- All `DataStoreService` operations must be server-side only
- `ModuleScripts` in `ReplicatedStorage` can be decompiled even if never `require()`d
- Avoid `RunService:IsServer()` branching in shared ModuleScripts — the server branch
  is still visible in decompilation

### Script Decompilation Warning

Any `LocalScript`, client-context `Script`, or `ModuleScript` replicated to the client
**can be decompiled** — even if disabled or never required. Never put secrets, passwords,
or server-side business logic in shared modules.

---

## 5. Anti-Cheat Design Philosophy

### "Design Over Detection" (Defensive Design)

Per Roblox docs: *"Design systems where cheating is either impossible or provides no
meaningful advantage, rather than trying to detect and prevent cheating after the fact."*

| Exploit Scenario                | Reactive (Less Effective)              | Defensive (More Effective)                        |
|---------------------------------|----------------------------------------|---------------------------------------------------|
| Obby: teleport to end           | Detect impossible completion times     | Mandatory sequential server-validated checkpoints  |
| Combat: impossible damage       | Filter out impossible damage values    | Server calculates all damage from server-side stats|
| Economy: rapid-fire duplication  | Detect duplicate request patterns      | Server-side cooldowns + validate inventory state   |
| Shooter: bot farming kills      | Write complex bot detection code       | Remove point gains for kills on newly spawned      |

### Server-Side Heuristics

For movement validation, the server can employ heuristics to detect impossible behavior:
- Track distance-over-time for speed checks (project onto XZ plane for ground movement)
- Use leaky-bucket accumulators for burst tolerance with sustained violation detection
- Account for network latency by averaging position updates over time
- Build exemption systems for legitimate teleport mechanics

### Server Authority (Client Beta — Updated April 2026)

Per Roblox docs: *"The most reliable solution for preventing physics and movement exploits
is server authority, which moves physics simulation and movement validation entirely to
the server."* See: https://create.roblox.com/docs/en-us/projects/server-authority

> **Mid-2026 Update**: Server Authority has graduated from "Beta" to **"Client Beta"** as
> of late April 2026. Key changes:
>
> - **Live server testing**: You can now **publish** and test Server Authority on live
>   production servers, not just Studio playtests.
> - **APIs are locked**: The API surface is considered **stable** — safe to build upon
>   without expecting breaking changes.
> - **Includes**: Server-side validation, client-side prediction, and rollback netcode.
>
> Server Authority is the recommended long-term solution for movement/physics exploit
> prevention. While heuristic-based anti-cheat (rubber-banding, speed checks) remains
> valid, Server Authority eliminates entire classes of exploits at the engine level.

### Rubber-Banding for Invalid Positions

When the server detects invalid player positions, the standard approach is to teleport
the player's character back to their last known valid server-side position.

```luau
--!strict
-- Server Script in ServerScriptService
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAX_SPEED = 50 -- studs per second (generous for latency)
local lastValidPositions: { [Player]: Vector3 } = {}

RunService.Heartbeat:Connect(function(dt: number)
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then continue end

        local currentPos = (rootPart :: BasePart).Position
        local lastPos = lastValidPositions[player]

        if lastPos then
            local distance = (currentPos - lastPos).Magnitude
            if distance > MAX_SPEED * dt * 2 then -- 2x tolerance for latency
                -- Rubber-band: teleport back to last valid position
                (rootPart :: BasePart).CFrame = CFrame.new(lastPos)
                continue
            end
        end

        lastValidPositions[player] = currentPos
    end
end)

Players.PlayerRemoving:Connect(function(player: Player)
    lastValidPositions[player] = nil
end)
```

---

## 6. Rate Limiting

### Token Bucket Pattern

From the official docs — a token bucket allows short bursts but prevents sustained spam:

```luau
--!strict
-- ModuleScript in ServerScriptService
export type TokenBucket = {
    capacity: number,
    refillPerSecond: number,
    buckets: { [number]: { tokens: number, last: number } },
    allow: (self: TokenBucket, userId: number) -> boolean,
}

local TokenBucketModule = {}
TokenBucketModule.__index = TokenBucketModule

function TokenBucketModule.new(capacity: number, windowSeconds: number): TokenBucket
    assert(capacity >= 1, "capacity must be >= 1")
    assert(windowSeconds > 0, "windowSeconds must be > 0")
    return setmetatable({
        capacity = capacity,
        refillPerSecond = capacity / windowSeconds,
        buckets = {},
    }, TokenBucketModule) :: any
end

function TokenBucketModule.allow(self: TokenBucket, userId: number): boolean
    local now = time()
    local b = self.buckets[userId]
    if not b then
        b = { tokens = self.capacity, last = now }
        self.buckets[userId] = b
    else
        local elapsed = now - b.last
        if elapsed > 0 then
            b.tokens = math.min(self.capacity, b.tokens + elapsed * self.refillPerSecond)
            b.last = now
        end
    end
    if b.tokens >= 1 then
        b.tokens -= 1
        return true
    end
    return false
end

return TokenBucketModule
```

Always clean up on `PlayerRemoving` to prevent memory leaks:

```luau
--!strict
Players.PlayerRemoving:Connect(function(player: Player)
    rateLimiter.buckets[player.UserId] = nil
end)
```

---

## 7. Data Protection

### Atomic Operations with UpdateAsync

Use `GlobalDataStore:UpdateAsync()` for atomic read-modify-write operations. Never use
`GetAsync` followed by `SetAsync` — this creates race conditions.

```luau
--!strict
local DataStoreService = game:GetService("DataStoreService")
local playerStore = DataStoreService:GetDataStore("PlayerData")

local function addCurrency(userId: number, amount: number): boolean
    local success, _ = pcall(function()
        playerStore:UpdateAsync("Player_" .. userId, function(oldData)
            local data = oldData or { currency = 0 }
            data.currency = (data.currency or 0) + amount
            return data
        end)
    end)
    return success
end
```

### Race Condition Handling (Player Leaving During Trades)

Per Roblox docs: *"A player initiates a trade, sends their item to another player, then
immediately leaves the game. If the trade completes but their DataStore save fails, they
rejoin with their original items — resulting in duplication."*

Prevention strategies:
- Validate all data **before** any trade operations begin
- Use transaction-like patterns where **all** players' data is validated before committing
- Implement error handling that **reverts all changes** if any part fails
- Lock player data during critical operations (session locking)

### Session Locking (ProfileStore / ProfileService Pattern)

Session locking ensures only one server can write to a player's data at a time.
The community-standard approach (ProfileService/ProfileStore) uses `UpdateAsync` to
write a lock key with the current server's `game.JobId`. Other servers check this lock
before loading, preventing data corruption from dual-sessions.

---

## 8. Script Security

### Third-Party Asset Risks

Per Roblox docs: *"Third-party assets from the Creator Store are a common source of
security risks, as they can contain malicious scripts called backdoors."*

**Best practices:**
- **Sandbox third-party models**: Set `Sandboxed = true` on inserted models and configure
  minimal `Capabilities` (avoid granting `Network`, `DataStore`, `AssetRequire`)
- **Inspect all scripts** in third-party assets before use
- **Watch for obfuscated code** or whitespace that hides malicious code off-screen
- **Favor highly-rated** community assets, but remember popularity doesn't guarantee safety

---

## 9. Complete Example: Secure RemoteEvent Handler

This example demonstrates a fully validated weapon-fire handler combining all patterns:

```luau
--!strict
-- Server Script in ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local TokenBucket = require(ServerScriptService:WaitForChild("TokenBucket"))
local fireWeaponEvent = ReplicatedStorage:WaitForChild("FireWeapon") :: RemoteEvent

-- Rate limiter: 10 shots per 5 seconds
local fireLimiter = TokenBucket.new(10, 5)

local MAX_FIRE_RANGE = 300 -- studs

local function isNaN(n: number): boolean
    return n ~= n
end

local function isValidVector3(v: unknown): boolean
    if typeof(v) ~= "Vector3" then return false end
    local vec = v :: Vector3
    return not (isNaN(vec.X) or isNaN(vec.Y) or isNaN(vec.Z))
end

fireWeaponEvent.OnServerEvent:Connect(function(player: Player, origin: unknown, target: unknown)
    -- 1. Rate limit
    if not fireLimiter:allow(player.UserId) then return end

    -- 2. Type validation
    if not isValidVector3(origin) or not isValidVector3(target) then return end
    local originVec = origin :: Vector3
    local targetVec = target :: Vector3

    -- 3. State validation: is player alive?
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- 4. Position validation: is claimed origin near actual position?
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    if (originVec - (rootPart :: BasePart).Position).Magnitude > 10 then return end

    -- 5. Range validation
    local direction = targetVec - originVec
    if direction.Magnitude > MAX_FIRE_RANGE then return end

    -- 6. Server-side raycast (authoritative hit detection)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character :: Model }

    local result = Workspace:Raycast(originVec, direction, params)
    if not result then return end

    -- 7. Process hit (server-authoritative damage)
    local hitPart = result.Instance
    local hitCharacter = hitPart:FindFirstAncestorOfClass("Model")
    if not hitCharacter then return end
    local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
    if not hitHumanoid or hitHumanoid.Health <= 0 then return end

    -- Apply damage from server-side weapon stats (never trust client damage values)
    local WEAPON_DAMAGE = 25
    hitHumanoid:TakeDamage(WEAPON_DAMAGE)
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player: Player)
    fireLimiter.buckets[player.UserId] = nil
end)
```

---

## 10. BanAsync API + Device Blocking (June 2026)

> **Added**: June 2026 — `ApplyDeviceBlock` parameter for `Players:BanAsync()`

The `Players:BanAsync()` API now supports an `ApplyDeviceBlock` parameter that applies
a **24-hour device-level block** in addition to the standard account ban. This makes it
significantly harder for banned exploiters to rejoin on alt accounts from the same machine.

**Current limitations:**
- Device blocking is **desktop only** (Windows and macOS) as of June 2026
- The device block lasts **24 hours** regardless of the ban `Duration`
- Mobile and console device blocking is not yet supported

### Usage Example

```luau
--!strict
-- Server Script in ServerScriptService
local Players = game:GetService("Players")

local function banPlayerWithDeviceBlock(player: Player, reason: string, privateReason: string)
    local success, err = pcall(function()
        Players:BanAsync({
            UserIds = {player.UserId},
            ApplyToUniverse = true,
            Duration = -1, -- permanent ban
            DisplayReason = reason,
            PrivateReason = privateReason,
            ApplyDeviceBlock = true, -- NEW: 24hr device block
        })
    end)

    if not success then
        warn("BanAsync failed for", player.UserId, ":", err)
    end
end

-- Example: called from an anti-cheat detection system
local function onSpeedHackDetected(player: Player)
    banPlayerWithDeviceBlock(
        player,
        "Exploiting",
        "Speed hack detected by server-side heuristic"
    )
end
```

> **Note**: Always wrap `BanAsync` in `pcall()` — it is a yielding function that can fail
> due to network issues or rate limits. Log failures for manual review.

### Integration with Anti-Cheat

Combine device blocking with the heuristic detection patterns from
[Section 5](#5-anti-cheat-design-philosophy) for a layered approach:

1. **Detect** via server-side heuristics (speed checks, position validation)
2. **Confirm** with multiple violation thresholds (avoid false positives)
3. **Ban + Device Block** using `BanAsync` with `ApplyDeviceBlock = true`
4. **Log** the ban reason and detection metadata for review

---

## 11. Scoped User Identifiers Warning (October 2026)

> **Upcoming**: October 2026 rollout — domain-scoped user IDs

> [!WARNING]
> Starting October 2026, Roblox will begin rolling out **scoped user identifiers**.
> Players will receive **domain-scoped user IDs** that differ per game/experience.
> This is a significant change that affects cross-game systems.

### What Changes

- Each player will have a **different user ID per experience** (domain-scoped)
- The scoped ID is stable within a single experience (same player always gets the same
  scoped ID in your game)
- Standard `DataStoreService` patterns **still work** — `player.UserId` within your
  experience will be consistent

### What Needs Adaptation

- **Cross-game ban systems**: If you maintain a shared ban list across multiple experiences
  using raw `UserId` values, those IDs will no longer match across games
- **Cross-experience analytics**: Any system that correlates players across different
  experiences by `UserId` will need to use the new scoped identifier APIs
- **Universe-wide bans via `BanAsync`**: The `ApplyToUniverse = true` flag should continue
  to work as Roblox handles the mapping internally, but verify with latest docs

### Recommended Actions

1. **Audit** any code that stores or compares `UserId` values across different experiences
2. **Avoid** hardcoding `UserId` values in cross-game configurations
3. **Consult** the latest official documentation for migration guidance:
   https://create.roblox.com/docs
4. **Test** your DataStore key patterns — keys like `"Player_" .. userId` within a single
   experience will continue to work as expected

```luau
--!strict
-- Standard single-experience DataStore pattern — still works with scoped IDs
local DataStoreService = game:GetService("DataStoreService")
local playerStore = DataStoreService:GetDataStore("PlayerData")

local function getPlayerKey(player: Player): string
    -- player.UserId is scoped but stable within this experience
    return "Player_" .. tostring(player.UserId)
end
```

---

## 12. Mid-2026 Changelog

| Date | Change | Section |
|------|--------|---------|
| June 2026 | `BanAsync` gains `ApplyDeviceBlock` param (24hr, desktop only) | [§10](#10-banasync-api--device-blocking-june-2026) |
| April 2026 | Server Authority promoted to "Client Beta"; live server testing enabled, APIs locked | [§5](#5-anti-cheat-design-philosophy) |
| October 2026 (upcoming) | Scoped user identifiers rollout — domain-scoped IDs per game | [§11](#11-scoped-user-identifiers-warning-october-2026) |
