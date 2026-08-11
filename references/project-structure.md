# Roblox Project Structure & Architecture

> Reference for AI coding skill — verified against official Roblox documentation.
> Sources: https://create.roblox.com/docs/projects/data-model, https://roblox.github.io/lua-style-guide/

## Table of Contents

- [Data Model Overview](#data-model-overview)
- [Container Services](#container-services)
- [Recommended Project Layout](#recommended-project-layout)
- [Service/Controller Architecture](#servicecontroller-architecture)
- [ModuleScript Best Practices](#modulescript-best-practices)
- [Script Execution Order](#script-execution-order)
- [Container Decision Tree](#container-decision-tree)
- [Rojo Integration](#rojo-integration)
- [Studio Script Sync](#studio-script-sync)
- [Input Action System (IAS)](#input-action-system-ias)
- [LEGACY Patterns](#legacy-patterns)

---

## Data Model Overview

Every Roblox place is represented by a **data model** — a hierarchy of objects
describing the 3D world, scripts, and runtime behavior. The Roblox Engine uses
the data model as the source of truth for state, simulation, and rendering.

### Script Types

| Script Type | Runs On | Container |
|---|---|---|
| `Script` | Server | `ServerScriptService` |
| `LocalScript` | Client | `StarterPlayerScripts`, `StarterGui`, `StarterCharacterScripts` |
| `ModuleScript` | Where required | `ReplicatedStorage` (shared), `ServerScriptService` (server-only) |

---

## Container Services

### Workspace

`Workspace` stores **all objects rendered in the 3D world**. Clients render
everything inside and nothing outside. Pre-populated with `Terrain` and `Camera`.

```
Workspace/
├── Terrain
├── Camera
├── Maps/          -- Map geometry (Models, Parts)
├── Interactables/ -- Doors, switches, pickups
└── Lighting/      -- In-world light sources
```

### ServerScriptService

Server-only scripts. **Never replicated to clients.** Contains `Script` objects
and `ModuleScript` objects required only by server code.

```
ServerScriptService/
├── Services/
│   ├── PlayerDataService.luau
│   ├── MatchmakingService.luau
│   └── EconomyService.luau
└── Init.server.luau
```

### ServerStorage

Server-only **assets and data**. Scripts do NOT run here, but server scripts
can `require()` ModuleScripts stored here. Use for large assets loaded on demand.

```
ServerStorage/
├── Maps/           -- Map models to swap into Workspace
├── Templates/      -- Item templates for cloning
└── Data/
    └── ItemDatabase.luau
```

> **Note:** Scripts don't execute when parented to ServerStorage. Store runnable
> server scripts in ServerScriptService instead.

### ReplicatedStorage

Available to **both server and client**. Changes made on the client persist
locally but do NOT replicate to the server. The server can overwrite client
changes to maintain consistency.

```
ReplicatedStorage/
├── Modules/
│   ├── Utilities.luau        -- Shared utility functions
│   ├── Types.luau            -- Shared type definitions
│   └── GameConfig.luau       -- Shared constants/config
├── Remotes/
│   ├── Events/               -- RemoteEvent objects
│   └── Functions/            -- RemoteFunction objects
└── Assets/
    ├── Effects/              -- ParticleEmitters, Beams
    └── UI/                   -- Shared UI prefabs
```

### StarterPlayerScripts

Client-side scripts copied to `Player.PlayerScripts` when a player joins.
The server **cannot** access this container. Scripts here persist across respawns.

```
StarterPlayer/
└── StarterPlayerScripts/
    ├── Controllers/
    │   ├── InputController.client.luau
    │   ├── CameraController.client.luau
    │   └── UiController.client.luau
    └── Init.client.luau
```

### StarterGui

UI elements and LocalScripts copied to `Player.PlayerGui` on each respawn.
Contents of PlayerGui are emptied when the player respawns, then re-copied
from StarterGui.

```
StarterGui/
├── HudGui/
│   ├── HealthBar (ScreenGui)
│   └── Minimap (ScreenGui)
└── MenuGui/
    └── PauseMenu (ScreenGui)
```

### StarterCharacterScripts

Scripts copied to `Player.Character` on each spawn. These do NOT persist
across respawns — they are destroyed and re-copied each time.

### ReplicatedFirst

Replicated to clients **first, before anything else**. Used for loading screens
and essential initialization. Content replicates only once (server → client).

```
ReplicatedFirst/
└── LoadingScreen.client.luau
```

---

## Recommended Project Layout

```
game
├── Workspace/                      -- 3D world
│   ├── Terrain
│   └── Maps/
│
├── ServerScriptService/            -- Server logic
│   ├── Services/                   -- Server service modules
│   │   ├── PlayerDataService.luau
│   │   ├── RoundService.luau
│   │   └── CombatService.luau
│   └── Init.server.luau            -- Server entry point
│
├── ServerStorage/                  -- Server-only assets
│   ├── Templates/
│   └── MapPool/
│
├── ReplicatedStorage/              -- Shared between server & client
│   ├── Modules/                    -- Shared modules
│   │   ├── Types.luau
│   │   ├── Constants.luau
│   │   └── Utilities.luau
│   ├── Remotes/                    -- RemoteEvents/RemoteFunctions
│   └── Assets/                     -- Shared assets
│
├── StarterPlayer/
│   └── StarterPlayerScripts/       -- Client logic
│       ├── Controllers/            -- Client controller modules
│       │   ├── InputController.luau
│       │   └── CameraController.luau
│       └── Init.client.luau        -- Client entry point
│
├── StarterGui/                     -- UI
│   └── HudGui/
│
└── ReplicatedFirst/                -- Loading screen
    └── LoadingScreen.client.luau
```

---

## Service/Controller Architecture

A common pattern for organizing game logic:

- **Services** = server-side singletons (in `ServerScriptService/Services/`)
- **Controllers** = client-side singletons (in `StarterPlayerScripts/Controllers/`)
- Both are ModuleScripts that return a table with an `Init` method

### Server Service Example

```luau
--!strict
-- ServerScriptService/Services/PlayerDataService.luau
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = {}

local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local sessionData: { [number]: PlayerData } = {}

export type PlayerData = {
	Coins: number,
	Level: number,
	Inventory: { string },
}

local DEFAULT_DATA: PlayerData = table.freeze({
	Coins = 0,
	Level = 1,
	Inventory = {},
})

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(function(player: Player)
		PlayerDataService.loadData(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		PlayerDataService.saveData(player)
	end)
end

function PlayerDataService.loadData(player: Player)
	local success, data = pcall(function()
		return playerDataStore:GetAsync(`Player_{player.UserId}`)
	end)

	if success and data then
		sessionData[player.UserId] = data :: PlayerData
	else
		sessionData[player.UserId] = table.clone(DEFAULT_DATA)
	end
end

function PlayerDataService.saveData(player: Player)
	local data = sessionData[player.UserId]
	if not data then
		return
	end

	pcall(function()
		playerDataStore:SetAsync(`Player_{player.UserId}`, data)
	end)

	sessionData[player.UserId] = nil
end

function PlayerDataService.getData(player: Player): PlayerData?
	return sessionData[player.UserId]
end

return PlayerDataService
```

### Client Controller Example

```luau
--!strict
-- StarterPlayerScripts/Controllers/InputController.luau
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputController = {}

function InputController.Init()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			InputController.onInteract()
		end
	end)
end

function InputController.onInteract()
	local interactEvent = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild("Interact")
	if not interactEvent then
		return
	end

	(interactEvent :: RemoteEvent):FireServer()
end

return InputController
```

### Server Entry Point

```luau
--!strict
-- ServerScriptService/Init.server.luau
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:FindFirstChild("Services")
if not Services then
	return
end

-- Require and initialize all services
for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local service = require(module)
		if service.Init then
			service.Init()
		end
	end
end
```

---

## ModuleScript Best Practices

1. **Return a single table** — every ModuleScript should return one table
2. **Use `--!strict`** at the top of every ModuleScript
3. **Export shared types** with `export type` for cross-script type sharing
4. **Require at the top** — group all `require()` calls at the top of the file
5. **Avoid circular dependencies** — if A requires B, B must not require A

### Template

```luau
--!strict
-- ReplicatedStorage/Modules/Utilities.luau

local Utilities = {}

function Utilities.formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return `{minutes}:{string.format("%02d", secs)}`
end

function Utilities.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

return Utilities
```

---

## Script Execution Order

### Key Rules

1. **ReplicatedFirst** scripts run first on the client, before anything else
2. **Server Scripts** in `ServerScriptService` begin executing when the server starts
3. **LocalScripts** in `StarterPlayerScripts` run when the player joins
4. **StarterGui** scripts run after being copied to `PlayerGui`
5. **StarterCharacterScripts** run after each character spawn
6. **ModuleScripts** run when first `require()`-d (cached after first run)

### Gotchas

- **No guaranteed order** among sibling scripts in the same container. Do NOT
  rely on one Script executing before another in `ServerScriptService`
- **ModuleScripts are cached** — `require()` returns the same table every time
  after the first call. This is what enables the singleton pattern
- Scripts in `ServerStorage` **do not run**. Only ModuleScripts there can be
  `require()`-d by server scripts
- `StarterGui` contents are **cleared on respawn** and re-copied. Use
  `ResetOnSpawn = false` on ScreenGuis to prevent this

### WaitForChild Pattern

When a client script needs objects that may not have replicated yet:

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- SAFE: waits for the object to replicate
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local interactEvent = remotes:WaitForChild("Interact")

-- UNSAFE on client: may not exist yet
-- local remotes = ReplicatedStorage.Remotes  -- Could error!
```

---

## Container Decision Tree

Use this to decide where to place objects:

```
Is it a 3D object visible in the world?
├── YES → Workspace
└── NO
    Does it need to run on the server?
    ├── YES
    │   Is it a Script or server ModuleScript?
    │   ├── YES → ServerScriptService
    │   └── NO (asset/data) → ServerStorage
    └── NO
        Does both server AND client need it?
        ├── YES → ReplicatedStorage
        └── NO (client only)
            Is it UI?
            ├── YES → StarterGui
            └── NO
                Should it run before everything else?
                ├── YES → ReplicatedFirst
                └── NO → StarterPlayerScripts
```

---

## Rojo Integration

[Rojo](https://rojo.space/) is the standard external tooling for syncing a
VS Code / filesystem project to Roblox Studio.

### Why Use Rojo

- Version control with Git
- Use external editors (VS Code, Neovim, etc.)
- File-based project structure instead of Studio-only
- Team collaboration through standard Git workflows

### File Extension Conventions

| Extension | Script Type |
|---|---|
| `.server.luau` | Server Script |
| `.client.luau` | Client LocalScript |
| `.luau` | ModuleScript |

### Example `default.project.json`

```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "$path": "src/server"
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "$path": "src/client"
      }
    },
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "$path": "src/shared"
    },
    "StarterGui": {
      "$className": "StarterGui",
      "$path": "src/gui"
    }
  }
}
```

### Corresponding Filesystem

```
MyGame/
├── default.project.json
└── src/
    ├── server/
    │   ├── Services/
    │   │   └── PlayerDataService.luau
    │   └── Init.server.luau
    ├── client/
    │   ├── Controllers/
    │   │   └── InputController.luau
    │   └── Init.client.luau
    ├── shared/
    │   ├── Modules/
    │   │   ├── Types.luau
    │   │   └── Utilities.luau
    │   └── Remotes/
    └── gui/
        └── HudGui/
```

---

## Studio Script Sync

> Released: June 2026 (GA).
> Source: https://create.roblox.com/docs/studio/script-sync

**Studio Script Sync** enables collaborative scripting between Roblox Studio and
external editors (VS Code, Neovim, etc.) via a real-time bidirectional file
sync. Changes saved in your external editor appear in Studio immediately, and
vice versa.

### How It Works

1. Studio exposes scripts as files in a local sync directory on disk.
2. An external editor opens / edits those files normally.
3. Studio watches for filesystem changes and applies them to the DataModel
   in real time (and pushes DataModel changes back to disk).

### Relationship to Rojo

| Aspect | Rojo | Studio Script Sync |
|---|---|---|
| **Sync direction** | Filesystem → Studio (primarily) | Bidirectional |
| **Requires external binary** | Yes (`rojo serve`) | No — built into Studio |
| **Project manifest** | `default.project.json` | None — uses DataModel structure |
| **Non-script files** | Syncs models, JSON, etc. | Scripts only (by design) |
| **Team collaboration** | Git-based | Git-based OR Studio collab |

**When to use which:**

- **Rojo** remains the best choice for teams that want a fully file-driven
  project, custom build pipelines, and non-script asset syncing.
- **Script Sync** is ideal for developers who prefer Studio as the primary
  editor but want the option to use an external text editor for scripts without
  installing Rojo. It also works alongside Rojo — you can use both if desired,
  though care must be taken to avoid conflicting writes to the same script.

### Quick Start

```text
1. In Studio: File → Script Sync → Enable Script Sync
2. Choose or create a local sync folder
3. Open the folder in your external editor
4. Edits in either location are reflected immediately
```

> **Tip:** Script Sync respects the same `.server.luau`, `.client.luau`, and
> `.luau` file extensions as Rojo. Files without these extensions are treated
> as ModuleScripts.

---

## Input Action System (IAS)

> Released: June 11, 2026 (GA).
> Source: https://create.roblox.com/docs/input/input-action-system

The **Input Action System (IAS)** replaces the legacy per-input-event model
(`UserInputService`, `ContextActionService`) with a declarative, data-driven
action mapping system. It is the foundation for the upcoming **Character
Controller Library** and **Server Authority** features.

### Enabling IAS

IAS is controlled by a Workspace-level property:

```luau
--!strict
-- Enable IAS for all PlayerScripts in this place
workspace.PlayerScriptsUseInputActionSystem = true
```

Set this property in Studio (Workspace → Properties → `PlayerScriptsUseInputActionSystem`)
or via script. When enabled, the default player scripts use IAS internally.

### Key Concepts

| Concept | Description |
|---|---|
| **InputAction** | A named action (e.g., `"Jump"`, `"Sprint"`) decoupled from specific keys/buttons |
| **Action binding** | Maps one or more physical inputs to an InputAction |
| **Action handler** | A callback that fires when an InputAction is activated/deactivated |
| **Composite actions** | Combine multiple inputs into a single action (e.g., WASD → `"Move"` as Vector2) |

### Example

```luau
--!strict
-- StarterPlayerScripts/Controllers/ActionController.client.luau
local InputActionService = game:GetService("InputActionService")

-- Create an action
local sprintAction = Instance.new("InputAction")
sprintAction.Name = "Sprint"
sprintAction.ActionType = Enum.InputActionType.Button
sprintAction.Parent = InputActionService

-- Bind Left Shift to the Sprint action
local shiftBinding = Instance.new("InputActionBinding")
shiftBinding.InputType = Enum.UserInputType.Keyboard
shiftBinding.KeyCode = Enum.KeyCode.LeftShift
shiftBinding.Parent = sprintAction

-- Handle the action
sprintAction.Activated:Connect(function()
	-- Begin sprinting
end)

sprintAction.Deactivated:Connect(function()
	-- Stop sprinting
end)
```

### Foundation for Future Features

IAS is a prerequisite for two major upcoming systems:

- **Character Controller Library:** A modular, customizable character movement
  system that replaces the monolithic default scripts. Built on top of IAS
  action definitions for input handling.
- **Server Authority:** Moves character state validation to the server. IAS
  provides the standardized input representation that the server can interpret
  and verify, reducing cheating surface area.

> **Migration:** When `PlayerScriptsUseInputActionSystem` is `true`, the default
> character scripts automatically use IAS internally. Custom scripts that call
> `ContextActionService:BindAction()` or `UserInputService.InputBegan` continue
> to work — IAS does not remove these APIs, but new code should prefer IAS
> for forward compatibility.

---

## LEGACY Patterns

### Scripts in Workspace (avoid)

Historically, developers placed Scripts directly inside Parts or Models in
Workspace. This made code hard to find and maintain.

```
-- LEGACY: Script inside a Part
Workspace/
└── DoorModel/
    ├── DoorPart
    └── DoorScript  ← hard to find, can't reuse

-- MODERN: Centralized in ServerScriptService
ServerScriptService/
└── Services/
    └── DoorService.luau  ← manages ALL doors from one place
```

### Scattered Scripts (avoid)

Avoid placing scripts in random locations throughout the data model. Centralize
logic into Services (server) and Controllers (client).

### Value Objects for State (avoid for new code)

Legacy pattern used IntValue, StringValue, BoolValue objects for state.
Modern code should use ModuleScripts with tables or RemoteEvents for
client-server communication.

```luau
--!strict
-- LEGACY: Value objects for configuration
-- local maxHealth = someModel:FindFirstChild("MaxHealth") -- IntValue
-- maxHealth.Value = 100

-- MODERN: Configuration module
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local maxHealth = GameConfig.MAX_HEALTH  -- 100
```

### require() by Asset ID (avoid)

Legacy code sometimes used `require(assetId)` to load ModuleScripts by their
asset ID. This is fragile and hard to maintain.

```luau
--!strict
-- LEGACY (avoid)
-- local module = require(123456789)

-- MODERN: require by reference
local module = require(ReplicatedStorage.Modules.MyModule)
```
