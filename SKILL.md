---
name: roblox-dev
description: >
  Expert Roblox game development companion for Luau scripting, Roblox Studio, and MCP integration.
  Covers full-lifecycle development: architecture, scripting, debugging, security hardening,
  performance optimization, data persistence, networking, UI systems, and publishing.
  MUST use this skill whenever the user mentions: 'Roblox', 'Luau', 'Roblox Studio',
  'game development' (in Roblox context), 'DataStoreService', 'RemoteEvent', 'RemoteFunction',
  'ServerScriptService', 'ReplicatedStorage', 'StarterGui', 'MeshPart', 'obby', 'tycoon',
  'simulator' (Roblox game genre), 'ProfileStore', 'Rojo', 'rbxl', 'rbxlx', 'rbxm', 'rbxmx',
  'import model', 'export model', 'fbx', 'obj', 'gltf', 'asset manager', 'Universal Importer',
  'publish game', 'game pass', 'developer product', or any Roblox Engine API reference. Also trigger when
  working with Roblox Studio MCP tools like execute_luau, search_game_tree, script_search,
  inspect_instance, or start_stop_play.
  Do NOT trigger for: Unity, Unreal Engine, Godot, general game design theory without
  Roblox context, web/mobile app development, or non-Luau scripting languages.
---

# Roblox Game Development Skill

Expert development companion for building Roblox experiences with Luau. Grounded in
official Roblox documentation (https://create.roblox.com/docs), the Luau language spec
(https://luau.org), and the Roblox Lua Style Guide (https://roblox.github.io/lua-style-guide/).

> **Engine**: Roblox Studio v727+ (mid-2026). APIs update weekly — when in doubt,
> use **context7 MCP** (`resolve-library-id` + `query-docs`) to look up the latest
> Roblox API documentation, or refer directly to https://create.roblox.com/docs.
> If information is still unclear, ask the user before proceeding.

---

## MCP Detection

On every invocation, detect available Roblox Studio MCP tools before proceeding:

### Official Roblox MCP (Roblox_Studio server)

Check for these tools from the `Roblox_Studio` MCP server:

| Tool | Purpose |
|------|---------|
| `execute_luau` | Run Luau code directly in Studio |
| `search_game_tree` | Search the Explorer/DataModel hierarchy |
| `script_search` / `script_grep` | Find scripts by name or content |
| `script_read` | Read script source code |
| `multi_edit` | Edit multiple scripts at once |
| `inspect_instance` | Inspect Instance properties |
| `insert_asset` / `search_asset` | Insert and search Roblox assets |
| `start_stop_play` | Start/stop playtesting |
| `get_console_output` | Read Output/console logs |
| `get_studio_state` | Get current Studio state |
| `screen_capture` / `store_image` | Capture and store screenshots |
| `generate_mesh` / `generate_procedural_model` | Generate 3D content |
| `generate_material` | Generate materials |
| `upload_image` | Upload images to Roblox |
| `character_navigation` | Navigate character in playtest |
| `user_mouse_input` / `user_keyboard_input` | Simulate user input |
| `list_roblox_studios` / `set_active_studio` | Manage Studio instances |

If MCP tools are available, prefer using them for:
- Reading existing scripts before writing new ones (`script_read`, `script_search`)
- Validating changes by running code (`execute_luau`)
- Inspecting game tree to understand project structure (`search_game_tree`)
- Testing changes with playtest (`start_stop_play`, `get_console_output`)

If MCP tools are NOT available, provide copy-paste-ready Luau scripts with clear
placement instructions (which service container to put them in).

---

## Routing Table

Match user intent to the appropriate reference file. Read the file BEFORE generating code.

| User Intent | Reference File |
|---|---|
| Luau syntax, types, naming conventions, style | `references/luau-fundamentals.md` |
| Project layout, architecture, patterns | `references/project-structure.md` |
| Save/load player data, DataStore, ProfileStore | `references/datastore-persistence.md` |
| Client-server communication, RemoteEvents, input | `references/networking.md` |
| Security, anti-exploit, server authority, bans | `references/security-hardening.md` |
| Performance, memory, optimization, Parallel Luau | `references/performance-optimization.md` |
| Using Roblox Studio MCP tools effectively | `references/mcp-integration.md` |
| UI, GUI, ScreenGui, menus, HUD, StyleQuery | `references/ui-systems.md` |
| Migrating legacy code, deprecated APIs | `references/legacy-migration.md` |
| Monetization, game passes, donations, transfers | `references/monetization.md` |
| File formats, import/export, asset management | `references/file-formats-and-assets.md` |

If the intent spans multiple domains, read all relevant files.
If a reference file doesn't cover a topic sufficiently, use the Official
Documentation Lookup workflow below.

---

## Official Documentation Lookup

Roblox provides AI-optimized documentation endpoints. Use these when reference
files don't cover a topic or you need the latest API details:

| Resource | URL | Use For |
|----------|-----|--------|
| **LLM docs index** | `https://create.roblox.com/docs/llms.txt` | Browse all available doc pages by topic |
| **Full docs (single file)** | `https://create.roblox.com/docs/llms-full.txt` | Comprehensive single-file reference |
| **Per-page markdown** | `https://create.roblox.com/docs/en-us/{path}.md` | Read specific doc pages in clean markdown |
| **Engine API index** | `https://create.roblox.com/docs/reference/engine/llms.txt` | Luau API classes, methods, events |
| **Open Cloud API index** | `https://create.roblox.com/docs/cloud/llms.txt` | REST API endpoints for external tools |
| **Deprecated API inventory** | `https://create.roblox.com/docs/reference/engine/deprecated.md` | Check if an API is deprecated |

### Lookup Workflow
1. Check if a reference file covers the topic (Routing Table above)
2. If not, use `read_url_content` on the per-page markdown URL
   - Example: `https://create.roblox.com/docs/en-us/studio/importer.md`
3. If unsure which page to read, browse `llms.txt` for the right URL
4. **Fallback**: Use **context7 MCP** (`resolve-library-id` + `query-docs`)
5. If still unclear, ask the user before proceeding

> **Important**: Engine APIs (Luau via `game:GetService()`) and Open Cloud APIs
> (HTTP REST via `x-api-key`) are **completely separate systems**. Using the
> wrong index will produce non-functional code.

---

## Core Coding Standards

These rules apply to ALL generated Roblox/Luau code. They are non-negotiable.

### 1. Type Safety
- Use `--!strict` at the top of every new script
- Annotate function parameters and return types
- Define custom types with `type` keyword for complex data structures

### 2. Naming Conventions (Official Roblox Style)
- **PascalCase**: Classes, ModuleScripts, Constructors, Services — `CombatService`, `PlayerData`
- **camelCase**: Variables, functions, parameters — `playerHealth`, `calculateDamage()`
- **UPPER_SNAKE_CASE**: Constants — `MAX_HEALTH`, `DEFAULT_SPEED`
- Spell out words fully — avoid abbreviations
- Don't fully capitalize acronyms: `JsonTable` not `JSONTable`

### 3. Modern API Usage
- Use `task.spawn()`, `task.delay()`, `task.wait()` — NOT legacy `spawn()`, `delay()`, `wait()`
- Use `task.cancel()` to clean up deferred tasks
- Always disconnect event connections in cleanup: `connection:Disconnect()`
- Wrap fallible operations in `pcall()` or `xpcall()`

### 4. Architecture Rules
- **Server authority**: All game state mutations happen on the server
- **ModuleScripts** for shared logic — avoid monolithic scripts
- **Service/Controller pattern**: Services (server), Controllers (client)
- Scripts go in the correct container:
  - Server logic → `ServerScriptService`
  - Client logic → `StarterPlayerScripts` or `StarterCharacterScripts`
  - Shared modules → `ReplicatedStorage`
  - Server-only data → `ServerStorage`
  - UI → `StarterGui`

### 5. Error Handling
```lua
local success, result = pcall(function()
    return DataStoreService:GetDataStore("PlayerData"):GetAsync(key)
end)
if not success then
    warn("[DataService] Failed to load data:", result)
    -- Handle gracefully: use defaults, retry, etc.
end
```

### 6. Security (Always Apply)
- NEVER trust client-sent data — validate types, ranges, and permissions on server
- Keep sensitive logic in `ServerScriptService` (not visible to clients)
- Validate RemoteEvent arguments: check `typeof()`, ranges, and player state
- Rate-limit RemoteEvent calls from clients
- Never expose admin commands or server keys to ReplicatedStorage

---

## Script Template

When creating new scripts, use this template as a starting point:

```lua
--!strict
-- [ScriptName]
-- [Brief description of what this script does]
-- Container: [ServerScriptService/StarterPlayerScripts/ReplicatedStorage]

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Dependencies -----
-- local SomeModule = require(ReplicatedStorage.Modules.SomeModule)

----- Constants -----
local MAX_VALUE = 100

----- Types -----
type PlayerData = {
    coins: number,
    level: number,
    inventory: { string },
}

----- Variables -----
local activeConnections: { [Player]: { RBXScriptConnection } } = {}

----- Private Functions -----
local function cleanup(player: Player)
    local connections = activeConnections[player]
    if connections then
        for _, conn in connections do
            conn:Disconnect()
        end
        activeConnections[player] = nil
    end
end

----- Public / Event Handlers -----
local function onPlayerAdded(player: Player)
    activeConnections[player] = {}
    -- Setup logic here
end

----- Initialization -----
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(cleanup)

-- Handle players already in game (Studio hot-reload)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end
```

---

## Response Guidelines

1. **Ask before building**: If the request is vague, ask clarifying questions about genre, scale, and target audience
2. **Read before writing**: If MCP is available, read existing scripts and game tree before modifying
3. **Small slices**: Generate 50-100 lines at a time for complex systems — easier to debug
4. **Explain the why**: Comment non-obvious code and explain architectural decisions
5. **Test path**: Suggest how to test the code (playtest steps, console checks)
6. **Migration-aware**: When touching existing code, check for legacy patterns and suggest migration if appropriate — but never force it. Incremental migration is acceptable.

---

## Common Workflows

### New Feature
1. Read existing project structure (MCP: `search_game_tree`)
2. Identify where the feature fits in the architecture
3. Create ModuleScript(s) in the appropriate container
4. Wire up server/client communication if needed
5. Test via playtest (MCP: `start_stop_play` + `get_console_output`)

### Debug Issue
1. Read the relevant script (MCP: `script_read`)
2. Check console output (MCP: `get_console_output`)
3. Identify the root cause — look for:
   - Missing `pcall` around DataStore/HTTP calls
   - Client-server boundary issues
   - Connection leaks (missing Disconnect)
   - Race conditions (script execution order)
4. Apply minimal fix
5. Verify fix via playtest

### Code Review
1. Read scripts in the project (MCP: `script_grep`)
2. Check against Core Coding Standards above
3. Flag security issues (client trust, exposed data)
4. Flag performance issues (expensive loops, part count)
5. Suggest improvements with before/after examples

---

## Knowledge Freshness Check (Auto-Reminder)

**On every skill trigger**, read `metadata.json` in this skill directory and check
the `last_updated` timestamp against the current date.

### Logic:
```
IF (current_date - last_updated) > update_interval_days (default: 7):
    REMIND the user:
    "⏰ Roblox Dev Skill knowledge was last updated on {last_updated}.
     It's been more than {days} days. Consider running a knowledge update
     via `/roblox-update` to ensure accuracy with the latest Roblox changes."
ELSE:
    Proceed normally — knowledge is fresh.
```

### Decision Rules:
- **NEVER auto-update** without user approval — always ask first
- **Source of truth**: https://create.roblox.com/docs, https://devforum.roblox.com
- **Decision maker**: Always the user (never the AI alone)
- **Update process**: Deep research → fact-check → QnA with user → apply → audit
- **After update**: Update `metadata.json` with new timestamp, version, and changes

---

## Manual Knowledge Update

The user can trigger a full knowledge update at any time by saying:

```
/roblox-update
```

Or any natural variation like "update roblox skill knowledge", "refresh roblox dev skill".

### Update Protocol:
1. **Research** — Search for latest Roblox changes since `last_updated` timestamp
   - DevForum release notes, API changelog, deprecation notices
   - Use web search for "Roblox developer updates {year}" and "Roblox API changes {month} {year}"
   - Visit https://devforum.roblox.com/c/updates/release-notes/58
2. **Compare** — Cross-check findings against existing reference files
3. **Report** — Present findings to user with clear "what changed" summary
4. **Discuss** — QnA with user on any decisions (add/remove/modify content)
5. **Apply** — Update reference files (keep what's correct, update what changed)
6. **Audit** — Full fact-check (same pattern as initial audit: file integrity + content verification)
7. **Stamp** — Update `metadata.json` with new timestamp and changelog entry

> [!IMPORTANT]
> All updates must be research-based. No improvisation. When in doubt, ask the user.
> Fallback: consult official docs via context7 MCP or direct web search.

---

## Export / Publish

This skill is designed to be export-ready for GitHub publishing. See `README.md`
in the skill root directory for the complete structure and usage guide.

To export: zip the entire `roblox-dev/` directory. The structure is self-contained
and platform-agnostic (works with Claude Code, Antigravity IDE, and any
compatible AI coding assistant).

