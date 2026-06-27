# DataStore & Persistence

> **Source:** [Roblox DataStores](https://create.roblox.com/docs/cloud-services/data-stores) ·
> [Error Codes & Limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) ·
> [Versioning & Caching](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching)

## Table of Contents
1. [DataStoreService Overview](#datastoreservice-overview)
2. [Core CRUD Operations](#core-crud-operations)
3. [SetAsync vs UpdateAsync](#setasync-vs-updateasync)
4. [Error Handling with pcall](#error-handling-with-pcall)
5. [Rate Limits & Throttling](#rate-limits--throttling)
6. [OrderedDataStore](#ordereddatastore)
7. [Versioning](#versioning)
8. [Storage & Access Limits (2026)](#storage--access-limits-2026)
9. [ProfileStore (Community Framework)](#profilestore-community-framework)
10. [Data Schema Best Practices](#data-schema-best-practices)
11. [LEGACY](#legacy)

---

## DataStoreService Overview

`DataStoreService` persists data between sessions. Data stores are consistent
per **experience** — every place/server in that experience shares the same data.

**Critical rule:** DataStoreService is **server-side only**. Attempting to access
it from a `LocalScript` throws an error. All DataStore calls must live in `Script`
objects (typically in `ServerScriptService`).

```luau
--!strict
-- ServerScriptService/DataManager.server.luau
local DataStoreService = game:GetService("DataStoreService")
local playerStore = DataStoreService:GetDataStore("PlayerData")
```

---

## Core CRUD Operations

### GetAsync — Read
```luau
--!strict
local success, value = pcall(function()
    return playerStore:GetAsync("User_1234")
end)
if success then
    print("Data:", value)
end
```

### SetAsync — Write (simple)
```luau
--!strict
local success, err = pcall(function()
    playerStore:SetAsync("User_1234", { coins = 50, level = 1 })
end)
if not success then
    warn("SetAsync failed:", err)
end
```

### UpdateAsync — Atomic Read-Modify-Write
```luau
--!strict
local success, updatedValue = pcall(function()
    return playerStore:UpdateAsync("User_1234", function(currentData)
        -- The callback must NOT yield (no task.wait, etc.)
        currentData = currentData or { coins = 0, level = 1 }
        currentData.coins += 10
        return currentData
    end)
end)
```

### RemoveAsync — Delete
```luau
--!strict
local success, oldValue = pcall(function()
    return playerStore:RemoveAsync("User_1234")
end)
```

### IncrementAsync — Atomic Integer Increment
```luau
--!strict
local success, newValue = pcall(function()
    return playerStore:IncrementAsync("User_1234_Visits", 1)
end)
```

---

## SetAsync vs UpdateAsync

| Aspect | SetAsync | UpdateAsync |
|---|---|---|
| **Atomicity** | No — can overwrite concurrent writes from other servers | Yes — reads current value before writing |
| **Speed** | Faster (write only) | Slower (read then write) |
| **Budget cost** | Write limit only | Both read AND write limits |
| **Multi-server safety** | Risk of data inconsistency | Safe against race conditions |
| **Callback** | N/A | Receives current value, must return new value (or `nil` to cancel) |

**Rule of thumb:** Always prefer `UpdateAsync` for player data. Use `SetAsync`
only for fire-and-forget writes where overwrites are acceptable (e.g., analytics
counters, initial data seeding).

---

## Error Handling with pcall

**All DataStore calls are network requests and can fail.** You MUST wrap every
call in `pcall`. This is not optional.

```luau
--!strict
local MAX_RETRIES = 3
local RETRY_DELAY = 2

local function safeGetAsync(store: DataStore, key: string): (boolean, any)
    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(function()
            return store:GetAsync(key)
        end)
        if success then
            return true, result
        end
        warn(`[DataStore] Attempt {attempt} failed: {result}`)
        if attempt < MAX_RETRIES then
            task.wait(RETRY_DELAY * attempt) -- exponential-ish backoff
        end
    end
    return false, nil
end
```

---

## Rate Limits & Throttling

### Experience-Level Limits (Standard DataStores)

| Request Type | Functions | Requests per Minute |
|---|---|---|
| **Read** | GetAsync, GetVersionAsync, UpdateAsync (read part) | 250 + players × 40 |
| **Write** | SetAsync, IncrementAsync, UpdateAsync (write part) | 250 + players × 20 |
| **List** | ListDataStoresAsync, ListKeysAsync, ListVersionsAsync | 10 + players × 2 |
| **Remove** | RemoveAsync | 100 + players × 40 |

> `UpdateAsync` counts against **both** read and write budgets.

### Server-Level Defaults (Configurable)

| Request Type | Requests per Minute |
|---|---|
| **Read** | 60 + numPlayers × 40 |
| **Write** | 60 + numPlayers × 40 |
| **List** | 5 + numPlayers × 2 |
| **Remove** | 60 + numPlayers × 40 |

Server limits are configurable via `DataStoreService:SetRateLimitForRequestType()`.

### Per-Key Throughput Limits

| Direction | Limit |
|---|---|
| Read | 25 MB per minute per key |
| Write | 4 MB per minute per key |

### Data Size Limits

| Component | Max Characters |
|---|---|
| Data store name | 50 |
| Key name | 50 |
| Scope | 50 |
| Key value (data) | 4,194,304 (4 MB) |

Queue limit: 30 requests per queue. When full, requests are dropped (error 301–306).

---

## OrderedDataStore

`OrderedDataStore` stores **integer values only** and supports sorted queries.
Ideal for leaderboards, high-score tables, and ranking systems.

```luau
--!strict
local DataStoreService = game:GetService("DataStoreService")
local leaderboardStore = DataStoreService:GetOrderedDataStore("TopScores")

-- Write a score
local success, err = pcall(function()
    leaderboardStore:SetAsync("Player_5678", 9500)
end)

-- Read top 10 (descending order)
local success, pages = pcall(function()
    return leaderboardStore:GetSortedAsync(false, 10)
end)
if success then
    local entries = pages:GetCurrentPage()
    for rank, entry in entries do
        print(`#{rank}: {entry.key} — {entry.value}`)
    end
end
```

> **Note:** OrderedDataStore does NOT support versioning or metadata.
> `DataStoreKeyInfo` is always `nil` for ordered data store keys.

---

## Versioning

SetAsync, UpdateAsync, and IncrementAsync create **versioned backups** using the
first write to each key in each UTC hour. Successive writes in the same hour
overwrite the previous data. Versioned backups expire **30 days** after a new
write overwrites them. The latest version never expires.

### Key Functions

| Function | Purpose |
|---|---|
| `ListVersionsAsync(key, sortDir, minDate?, maxDate?)` | List all versions for a key |
| `GetVersionAsync(key, version)` | Retrieve a specific version |
| `RemoveVersionAsync(key, version)` | Delete a specific version |

```luau
--!strict
-- Revert a key to state before a specific timestamp
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData")

local KEY = "User_1234"
local maxDate = DateTime.fromUniversalTime(2026, 06, 20, 12, 00)

local listOk, pages = pcall(function()
    return store:ListVersionsAsync(KEY, Enum.SortDirection.Descending, nil, maxDate.UnixTimestampMillis)
end)
if listOk then
    local items = pages:GetCurrentPage()
    if #items > 0 then
        local closest = items[1]
        local getOk, value, info = pcall(function()
            return store:GetVersionAsync(KEY, closest.Version)
        end)
        if getOk then
            local setOptions = Instance.new("DataStoreSetOptions")
            setOptions:SetMetadata(info:GetMetadata())
            store:SetAsync(KEY, value, nil, setOptions)
        end
    end
end
```

---

## Storage & Access Limits (Updated April 2026)

As of April 9, 2026, DataStore limits are calculated at **experience level** (not per-server).

### Storage Limit Formula
```
Total storage = 100 MB + 1 MB × lifetime user count
```

- A **lifetime user** is any user who has joined the experience at least once
- Deleted/replaced keys (accessible through version APIs) do NOT count
- Data stores deleted via Open Cloud `DeleteDataStore` continue counting for 30 days

### Overage Handling
If storage exceeds the limit, Roblox handles overages **without immediate write failures**:
- Overages are charged via **Robux deductions** or covered by **Extended Services** subscription
- No data loss — writes continue working during overage

### Notification Thresholds
Automated notifications are sent at:
| Threshold | Action |
|-----------|--------|
| **60%** | Info notification |
| **80%** | Warning notification |
| **90%** | Critical warning |
| **100%** | Overage begins, Robux billing starts |

### Monitoring Dashboard
Monitor storage usage via **Creator Hub → Data Stores Manager**:
- Real-time storage consumption per DataStore
- Access rate monitoring
- Overage billing visibility

> [!TIP]
> Enable the **Extended Services** free monthly tier for additional capacity
> without per-overage charges. Opt in via Creator Hub → Subscriptions.

---

## ProfileStore (Community Framework)

[ProfileStore](https://madstudioroblox.github.io/ProfileStore/) by loleris is the
**successor to ProfileService** and the recommended community framework for
player data management. It wraps `DataStoreService` with critical safeguards.

### Session Locking
- Only **one server** can "own" a player's data at a time
- Prevents data corruption and item duplication exploits
- Handles server-to-server handover gracefully during teleports

### Auto-Save
- Automatically saves data at regular intervals (default: **300 seconds**)
- Dramatically reduces DataStore API calls vs manual approaches
- Saves on `PlayerRemoving` and `game:BindToClose`

### Data Migration
- Supports schema versioning via `Profile.Data` reconciliation
- Define a template and ProfileStore fills in missing fields automatically

### Basic Usage Pattern
```luau
--!strict
-- ServerScriptService/PlayerDataManager.server.luau
local ProfileStore = require(game.ServerStorage.ProfileStore)
local Players = game:GetService("Players")

local DATA_TEMPLATE = {
    coins = 0,
    gems = 0,
    inventory = {},
    settings = { musicVolume = 0.5 },
    dataVersion = 1,
}

local playerStore = ProfileStore.New("PlayerData", DATA_TEMPLATE)
local profiles: { [Player]: typeof(playerStore:StartSessionAsync()) } = {}

local function onPlayerAdded(player: Player)
    local profile = playerStore:StartSessionAsync(`Player_{player.UserId}`, {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })
    if profile == nil then
        player:Kick("Unable to load data. Please rejoin.")
        return
    end
    profile:AddUserId(player.UserId)
    profile:Reconcile() -- fill missing template fields
    profile.OnSessionEnd:Connect(function()
        profiles[player] = nil
        player:Kick("Session ended.")
    end)
    if player.Parent == Players then
        profiles[player] = profile
    else
        profile:EndSession()
    end
end

local function onPlayerRemoving(player: Player)
    local profile = profiles[player]
    if profile then
        profile:EndSession()
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
```

---

## Data Schema Best Practices

1. **Single key per player** — store all data in one table keyed by `Player_{UserId}`
2. **Use a template** — define defaults so new fields auto-populate
3. **Include a version number** — `dataVersion = 1` enables future migrations
4. **Flatten when possible** — deeply nested tables are harder to migrate
5. **Never store Instances** — only serializable Luau types (string, number, boolean, table, buffer)
6. **Use `UpdateAsync` for player data** — atomic, prevents overwrites
7. **Bind to close** — always save on `game:BindToClose` with a timeout

```luau
--!strict
game:BindToClose(function()
    -- Give DataStore calls time to complete (max 30s in production)
    for _, player in Players:GetPlayers() do
        task.spawn(function()
            onPlayerRemoving(player)
        end)
    end
    task.wait(5) -- wait for saves to flush
end)
```

---

## LEGACY

### DataStore2 (Berezaa)
**Status:** Outdated. Not recommended for new projects.

DataStore2 was an early community wrapper that introduced:
- Ordered backups across multiple DataStore keys
- Automatic retry logic
- Caching layer

**Why it's deprecated:**
- Uses a backup strategy that creates many DataStore keys (wasteful)
- No session locking — vulnerable to data duplication
- Not maintained; incompatible with newer DataStore features (versioning, metadata)
- Roblox's native versioning now covers the backup use case

### Migration: DataStore2 → ProfileStore

1. Read existing data via DataStore2's `Get()` one last time
2. Write it into ProfileStore's format under the same key convention
3. On subsequent loads, check if ProfileStore data exists; if not, fall back to DataStore2
4. Once all active players have been migrated, remove DataStore2 code

```luau
--!strict
-- Simplified migration check (server-side)
local function migrateFromDataStore2(player: Player, profile: any)
    if profile.Data.migrated then return end

    -- Attempt to read from old DataStore2
    local DataStore2 = require(game.ServerStorage.DataStore2) -- legacy module
    local oldStore = DataStore2("PlayerSave", player)
    local oldData = oldStore:Get(nil)

    if oldData then
        -- Merge old data into ProfileStore format
        profile.Data.coins = oldData.coins or profile.Data.coins
        profile.Data.inventory = oldData.inventory or profile.Data.inventory
        profile.Data.migrated = true
    end
end
```

### ProfileService → ProfileStore Changes

ProfileStore is the direct successor by the same author (loleris). Key changes:

| Aspect | ProfileService (Old) | ProfileStore (New) |
|---|---|---|
| **Load method** | `ProfileStore:LoadProfileAsync()` | `ProfileStore:StartSessionAsync()` |
| **Release method** | `Profile:Release()` | `Profile:EndSession()` |
| **Auto-save interval** | 30 seconds | 300 seconds (configurable) |
| **API style** | Callback-heavy | Promise/session-based |
| **Reconcile** | `Profile:Reconcile()` | `Profile:Reconcile()` (same) |
| **Module name** | `ProfileService` | `ProfileStore` |

Migration is straightforward: ProfileStore reads the same underlying DataStore
keys. Update method names and adjust auto-save expectations.
