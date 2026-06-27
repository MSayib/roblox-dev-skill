# Performance Optimization Reference

> **Source**: Roblox official performance documentation  
> https://create.roblox.com/docs/en-us/performance-optimization  
> https://create.roblox.com/docs/en-us/performance-optimization/improve  
> https://create.roblox.com/docs/en-us/scripting/multithreading  
> https://create.roblox.com/docs/en-us/workspace/streaming

## Table of Contents

1. [Part Count Optimization](#1-part-count-optimization)
2. [MeshParts Over UnionOperations](#2-meshparts-over-unionoperations)
3. [CollisionFidelity Settings](#3-collisionfidelity-settings)
4. [Rendering Optimization](#4-rendering-optimization)
5. [Script Optimization](#5-script-optimization)
6. [Connection Cleanup](#6-connection-cleanup)
7. [Parallel Luau with Actors](#7-parallel-luau-with-actors)
8. [Object Pooling Pattern](#8-object-pooling-pattern)
9. [Content Streaming](#9-content-streaming-streamingenabled)
10. [MicroProfiler Usage](#10-microprofiler-usage)
11. [Device Testing](#11-device-testing)
12. [LEGACY Section](#12-legacy-section)

---

## 1. Part Count Optimization

Per Roblox docs, the number of objects in a scene directly impacts draw calls and physics
computation. More objects = more draw calls = lower frame rate.

**Best practices:**
- **Anchor all static parts** — unanchored parts incur physics simulation cost every frame
- **Merge decorative geometry** — combine small decorative parts into single MeshParts
- **Reduce mechanism complexity** — minimize constraints/joints in assemblies
- **Set `Model.LevelOfDetail`** to `Enum.ModelLevelOfDetail.SLIM` for distant models
- **Cull distant objects** — only spawn NPCs when users are nearby; despawn when out of range

**Draw call instancing**: Roblox collapses identical meshes into a single draw call when
`MeshContent` and `SurfaceAppearance` (or `TextureContent`) are identical. Ensure
duplicate meshes share the same asset IDs — import once, duplicate in Studio.

```luau
--!strict
-- Script to audit mesh duplication (find meshes with same name but different IDs)
for _, descendant in workspace:GetDescendants() do
    if descendant:IsA("MeshPart") then
        print(descendant.Name .. ", " .. descendant.MeshId)
    end
end
```

---

## 2. MeshParts Over UnionOperations

`UnionOperation` (CSG unions via Negate/Union) have higher runtime cost than `MeshPart`:
- Unions store complex geometry data and can't benefit from instancing
- MeshParts with identical `MeshContent` are collapsed into single draw calls
- MeshParts support `SurfaceAppearance` for PBR materials
- MeshParts have configurable `CollisionFidelity` and `RenderFidelity`

**Rule**: Use MeshParts created in external 3D tools (Blender, Maya) instead of building
complex shapes from CSG unions in Studio.

---

## 3. CollisionFidelity Settings

`MeshPart.CollisionFidelity` controls how precisely collision bounds match the visual mesh.
Higher fidelity = more memory and computation.

| CollisionFidelity   | Cost     | Use Case                                       |
|---------------------|----------|-------------------------------------------------|
| `Box`               | Lowest   | Small parts, non-interactable, non-collidable   |
| `Hull`              | Low      | Small-medium convex shapes                      |
| `Default`           | Medium   | General purpose (decomposition)                 |
| `Precise`           | Highest  | Only when pixel-perfect collision is required    |

**From docs:**
- For **non-collidable objects**, use `Box` fidelity — collision geometry is still stored
  in memory even when `CanCollide = false`
- For small anchored parts, `Box` fidelity is always safe
- For large complex meshes, build custom collision from invisible `Box`-fidelity parts
- Disable all collision channels (`CanCollide`, `CanTouch`, `CanQuery` = false) on
  purely decorative parts to save memory

```luau
--!strict
-- Batch-set non-collidable decorative parts to Box fidelity
local CollectionService = game:GetService("CollectionService")

for _, part in CollectionService:GetTagged("Decorative") do
    if part:IsA("MeshPart") then
        part.CollisionFidelity = Enum.CollisionFidelity.Box
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
    end
end
```

---

## 4. Rendering Optimization

### Shadows

Per docs: *"Handling shadows is an expensive process."*
- Use `BasePart.CastShadow = false` on small parts where shadows are invisible
- Disable `Light.Shadows` on light instances that don't need shadow casting
- Limit range and angle of light instances
- Disable shadows on moving objects when possible
- Consider per-room lighting for indoor environments

### Level of Detail (LOD)

- Set `MeshPart.RenderFidelity` to `Automatic` or `Performance` — allows engine to use
  lower-poly alternatives at distance
- Set `Model.LevelOfDetail` to `SLIM` for distant model representations
- Enable `Workspace.EnableSLIMAvatars` for optimized distant avatar rendering

### Transparency Overdraw

Overlapping semi-transparent objects force multiple pixel renders. Remove or reduce
layered transparent parts.

### Texture Memory

Texture memory is based on pixel count, not file size. A 1024×1024 texture uses 4× the
graphics memory of 512×512. The engine auto-scales textures based on device memory and
distance, but strategically sizing textures improves baseline memory usage.

---

## 5. Script Optimization

### Cache References

Avoid repeated `FindFirstChild` or `WaitForChild` lookups in hot loops:

```luau
--!strict
-- BAD: repeated lookups every frame
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
    local character = workspace:FindFirstChild("PlayerCharacter") -- ❌ every frame
    if character then
        local humanoid = character:FindFirstChild("Humanoid") -- ❌ every frame
        if humanoid then
            -- do work
        end
    end
end)

-- GOOD: cache references, update on change
local character: Model? = nil
local humanoid: Humanoid? = nil

local function onCharacterAdded(newCharacter: Model)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
end

local player = game:GetService("Players").LocalPlayer
if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

RunService.Heartbeat:Connect(function()
    if humanoid and humanoid.Health > 0 then
        -- do work with cached reference ✅
    end
end)
```

### Use Local Variables for Faster Access

Luau resolves local variables faster than globals or table lookups:

```luau
--!strict
-- BAD: repeated global/table access in a tight loop
local function processItems(items: { Vector3 })
    for i = 1, #items do
        local dist = (items[i] - workspace.CurrentCamera.CFrame.Position).Magnitude -- ❌
    end
end

-- GOOD: hoist lookups outside the loop
local function processItemsFast(items: { Vector3 })
    local cameraPos = workspace.CurrentCamera.CFrame.Position -- ✅ cached
    for i = 1, #items do
        local dist = (items[i] - cameraPos).Magnitude
    end
end
```

### Minimize Table Allocations in Loops

```luau
--!strict
-- BAD: new table every frame
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
    local results = {} -- ❌ allocates every frame, pressure on GC
    -- populate results...
end)

-- GOOD: reuse table via table.clear()
local results: { BasePart } = {}
RunService.Heartbeat:Connect(function()
    table.clear(results) -- ✅ reuse allocation
    -- populate results...
end)
```

### Avoid Expensive Operations on RunService Events

Per docs: *"Invoke code on RunService events sparingly, limiting usage to cases where
high frequency invocation is essential (for example, updating the camera)."* Most code
can run on other events or less frequently with `task.wait()`.

---

## 6. Connection Cleanup

Per docs: *"The engine never garbage collects events connected to an instance and any
values referenced inside the connected callback."* Active connections keep everything
in scope alive — this is the #1 source of memory leaks in Roblox.

```luau
--!strict
-- Pattern: clean up connections when the instance is no longer needed
local Players = game:GetService("Players")

local playerConnections: { [Player]: { RBXScriptConnection } } = {}

Players.PlayerAdded:Connect(function(player: Player)
    local connections: { RBXScriptConnection } = {}

    table.insert(connections, player.CharacterAdded:Connect(function(character)
        -- handle character
    end))

    playerConnections[player] = connections
end)

Players.PlayerRemoving:Connect(function(player: Player)
    -- Disconnect all connections for this player
    local connections = playerConnections[player]
    if connections then
        for _, conn in connections do
            conn:Disconnect()
        end
    end
    playerConnections[player] = nil
end)
```

**Three ways to disconnect** (from docs):
1. Call `connection:Disconnect()` manually
2. Call `instance:Destroy()` — disconnects all events on that instance
3. Destroy the script object the connection traces back to

---

## 7. Parallel Luau with Actors

### Actors as Unit of Parallel Execution

`Actor` instances (inheriting from `DataModel`) are the unit of execution isolation.
Scripts under different Actors can run on multiple CPU cores simultaneously.

- Scripts under the **same Actor** always execute sequentially with respect to each other
- Scripts under **different Actors** can run in true parallel
- Actors should be placed in appropriate containers or replace top-level entities (NPCs)

### task.desynchronize() / task.synchronize()

By default, code under Actors still runs serially. You must explicitly switch to parallel:

```luau
--!strict
local RunService = game:GetService("RunService")

RunService.Heartbeat:ConnectParallel(function()
    -- This runs in PARALLEL (can read DataModel, limited writes)
    -- ... expensive computation ...

    task.synchronize()

    -- This runs SERIALLY (can modify instances freely)
    -- ... apply results to DataModel ...
end)
```

**Alternative**: Use `signal:ConnectParallel()` to immediately run callbacks in parallel
without calling `task.desynchronize()`.

> **Warning**: You cannot use `require()` in a desynchronized parallel phase.
> Require modules first in a serial context.

### Thread Safety Levels

| Safety Level    | Properties                        | Functions                         |
|-----------------|-----------------------------------|-----------------------------------|
| **Unsafe**      | Cannot read or write in parallel  | Cannot call in parallel           |
| **Read Parallel** | Read only in parallel          | N/A                               |
| **Local Safe**  | Read/write within same Actor      | Call within same Actor only       |
| **Safe**        | Read and write freely             | Call freely                       |

Check thread safety tags on the API reference for each member.

### Master-Worker Pattern

From the official Parallel Luau docs — a master script creates worker Actors and
distributes tasks via `Actor:SendMessage()`:

```luau
--!strict
-- Master script: creates workers and dispatches tasks
local Workspace = game:GetService("Workspace")

local WORKER_COUNT = 32
local actor = script:GetActor()
if actor == nil then
    -- This is the master: create workers
    local workers: { Actor } = {}
    for i = 1, WORKER_COUNT do
        local workerActor = Instance.new("Actor")
        script:Clone().Parent = workerActor
        table.insert(workers, workerActor)
    end

    for _, worker in workers do
        worker.Parent = script
    end

    -- Distribute work across workers
    task.defer(function()
        local rand = Random.new()
        for taskIndex = 1, 100 do
            local workerIndex = rand:NextInteger(1, #workers)
            workers[workerIndex]:SendMessage("DoWork", taskIndex)
        end
    end)
    return -- Master exits; workers handle the rest
end

-- Worker script: receives and processes tasks
actor:BindToMessageParallel("DoWork", function(taskIndex: number)
    -- Parallel computation here
    local result = taskIndex * taskIndex -- example work

    task.synchronize()
    -- Apply results to DataModel (serial)
    print("Task", taskIndex, "result:", result)
end)
```

**Best practice from docs**: Use more Actors than CPU cores. Even on 4-core devices,
64 Actors enables better load balancing. But don't use so many that they become
unmaintainable.

---

## 8. Object Pooling Pattern

Per docs: *"Instead of destroying an NPC completely, send the NPC to a pool of inactive
NPCs. This minimizes the amount of times characters need to be instantiated."*

Instantiating and destroying models (especially with Humanoids or layered clothing) is
expensive. Pool and reuse instead.

```luau
--!strict
-- ModuleScript in ServerScriptService

type Pool<T> = {
    available: { T },
    inUse: { [T]: boolean },
    factory: () -> T,
    reset: (item: T) -> (),
}

local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new<T>(factory: () -> T, reset: (item: T) -> (), preWarm: number?): Pool<T>
    local pool: Pool<T> = {
        available = {},
        inUse = {},
        factory = factory,
        reset = reset,
    }
    setmetatable(pool, ObjectPool)

    for i = 1, preWarm or 0 do
        table.insert(pool.available, factory())
    end

    return pool
end

function ObjectPool.acquire<T>(self: Pool<T>): T
    local item: T
    if #self.available > 0 then
        item = table.remove(self.available, #self.available) :: T
    else
        item = self.factory()
    end
    self.inUse[item] = true
    return item
end

function ObjectPool.release<T>(self: Pool<T>, item: T)
    if not self.inUse[item] then return end
    self.inUse[item] = nil
    self.reset(item)
    table.insert(self.available, item)
end

return ObjectPool
```

Usage for NPC pooling:

```luau
--!strict
local ServerStorage = game:GetService("ServerStorage")
local ObjectPool = require(script.Parent.ObjectPool)

local npcTemplate = ServerStorage:WaitForChild("NPCTemplate") :: Model

local npcPool = ObjectPool.new(
    function(): Model
        return npcTemplate:Clone()
    end,
    function(npc: Model)
        -- Reset NPC state and move to storage
        npc.Parent = ServerStorage
        local humanoid = npc:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = humanoid.MaxHealth
        end
    end,
    10 -- pre-warm with 10 NPCs
)

-- Spawn an NPC
local npc = npcPool:acquire(npcPool)
npc:PivotTo(CFrame.new(0, 5, 0))
npc.Parent = workspace

-- Return NPC to pool instead of destroying
npcPool:release(npcPool, npc)
```

---

## 9. Content Streaming (StreamingEnabled)

Per docs: *"Instance streaming selectively loads out parts of the data model that are not
required, which can lead to considerably reduced load times and increase the client's
ability to prevent crashes when it comes under memory pressure."*

Enable via `Workspace.StreamingEnabled = true`.

**Key properties:**
- `StreamingMinRadius` — minimum distance (studs) that content always streams in
- `StreamingTargetRadius` — target distance the engine tries to maintain
- `StreamingIntegrityMode` — behavior when required content isn't loaded yet

**Per-model streaming modes** (`Model.ModelStreamingMode`):
- `Default` — standard distance-based streaming
- `Atomic` — entire model streams in/out as a unit
- `Persistent` — always loaded (use sparingly — defeats streaming purpose)
- `PersistentPerPlayer` — always loaded for specific players

**Script considerations**: With streaming enabled, instances may not exist when scripts
run. Use `WaitForChild()` or `ModelStreamingMode.Atomic` for critical models.

---

## 10. MicroProfiler Usage

The MicroProfiler (`Ctrl+F6` / `⌘+F6`) is the primary tool for identifying performance
bottlenecks. It shows per-frame timing of engine subsystems.

**Key scopes to watch:**

| Scope                          | What it means                          |
|--------------------------------|----------------------------------------|
| `RunService.PreRender`         | Code on PreRender event                |
| `RunService.PreSimulation`     | Code on Stepped event                  |
| `RunService.PostSimulation`    | Code on Heartbeat event                |
| `physicsStepped`               | Overall physics computation            |
| `worldStep`                    | Discrete physics steps per frame       |
| `Prepare and Perform`          | Overall rendering                      |
| `ShadowMapSystem`             | Shadow mapping cost                    |
| `updateInvalidatedFastClusters`| Avatar instantiation/modification      |
| `ProcessPackets`               | Incoming network packet processing     |

**Custom profiling in scripts:**

```luau
--!strict
local function expensiveOperation()
    debug.profilebegin("MyExpensiveOperation") -- custom MicroProfiler label
    -- ... work ...
    debug.profileend()
end
```

---

## 11. Device Testing

Always test on target devices, especially mobile and low-end hardware:

- **Mobile devices** have significantly less memory and CPU — test with Device Emulator
  in Studio and on physical devices
- **Roblox targets 60 FPS** (one frame every 16.67ms) — monitor frame budget
- Use **Developer Console** (`F9`) to monitor:
  - `LuaHeap` — high/growing suggests memory leak
  - `InstanceCount` — growing count suggests leaked references
  - `PlaceScriptMemory` — per-script memory breakdown
- Enable **Render Stats** (`Shift+F2`) to see draw calls and frame timing in-client
- Test with lower graphics quality settings to match low-end device experience

---

## 12. LEGACY Section

These patterns are outdated but may appear in older codebases. Migrate to modern
alternatives.

### spawn() and wait() → task library

```luau
--!strict
-- LEGACY (deprecated, imprecise timing, throttled)
spawn(function()
    wait(1)
    print("delayed")
end)

-- MODERN (precise, not throttled)
task.delay(1, function()
    print("delayed")
end)

-- Or:
task.spawn(function()
    task.wait(1)
    print("delayed")
end)
```

### BodyVelocity / BodyPosition / BodyGyro → Constraints

Legacy `BodyMover` classes are deprecated. Use modern constraint-based equivalents:

| Legacy              | Modern Replacement        |
|---------------------|---------------------------|
| `BodyVelocity`      | `LinearVelocity`          |
| `BodyPosition`      | `AlignPosition`           |
| `BodyGyro`          | `AlignOrientation`        |
| `BodyForce`         | `VectorForce`             |
| `BodyAngularVelocity` | `AngularVelocity`       |
| `BodyThrust`        | `VectorForce`             |
| `RocketPropulsion`  | `LinearVelocity` + `AlignOrientation` |

### Manually Destroying Player Characters → Automatic

```luau
--!strict
-- LEGACY: manual cleanup
local Players = game:GetService("Players")
Players.PlayerRemoving:Connect(function(player)
    if player.Character then
        player.Character:Destroy()
    end
end)

-- MODERN: set Workspace.PlayerCharacterDestroyBehavior = Enabled
-- The engine automatically destroys player characters on leave
```

### RunService.Heartbeat for Game Loops → Selective Use

Old pattern: putting all game logic in a single Heartbeat connection. Modern approach:
use appropriate events for each task and break heavy work across frames with `task.wait()`.

### Old Physics Stepping → Adaptive

Legacy: Fixed physics stepping at 240 Hz for all assemblies.
Modern: `Workspace.PhysicsSteppingMethod = Adaptive` — physics steps at 60/120/240 Hz
based on mechanism complexity, saving computation.
