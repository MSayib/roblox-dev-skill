---
name: roblox-dev-skill
description: >
  Verified, current Roblox and Luau knowledge for writing, reviewing, debugging and testing Roblox
  experiences. Use for ANY Roblox, Luau or Roblox Studio task, even a quick snippet: scripts,
  RemoteEvents, DataStores/ProfileStore, ProcessReceipt, UI, Input Action System, Parallel Luau,
  performance, security, deprecated APIs, Rojo, and Studio MCP tools (list_roblox_skills,
  get_roblox_skill for built-in rbx-* skills, execute_luau, multi_edit, script_read,
  open_cloud_invoke, generate_mesh, generate_procedural_model, generate_animation, store_image,
  start_stop_play, screen_capture, video_capture, save_place). Holds facts general knowledge gets
  wrong (Script capability gates, unenabled features, Studio betas, engine 0.748 / Luau 0.748) and
  Studio-tested workflows; consult before answering from memory. Not for non-Roblox Lua (Redis,
  OpenResty, WoW, LOVE) or other engines.
---

# Roblox Game Development Skill

Expert development companion for building Roblox experiences with Luau. Grounded in
official Roblox documentation (https://create.roblox.com/docs), the Luau language spec
(https://luau.org), and the Roblox Lua Style Guide (https://roblox.github.io/lua-style-guide/).

> **Engine**: Roblox Studio **0.748.0.7481526** with **Luau 0.748** (released 2026-11-20) — dump
> downloaded, re-split, and diffed against 0.746 on **2026-11-23**, with every developer-visible
> change run in Studio 0.748. 960 classes / 664 enums; locally, 270 class files named `*Service`
> (351 classes carry the `Service` tag) and 48 deprecated classes (579 members). The official docs
> were checked through 2026-11-23. Newly usable in 0.748: `EditableMesh:AddFace`,
> `SceneAnalysisService:GetCollisionGeometryMemoryAsync`, `AssetService:GetLatestVersionUriAsync`,
> `BoxHandleAdornment.DoubleSided`, `PhysicsActivitySensor`, and `GuiObject.SelectionGained`
> direction. Also usable: `RaycastParams.Margin` / `SizeGradient`, `Color3` contrast methods,
> `GamepadService:EnableGamepadCursor()` with no argument.
>
> Roblox ships roughly weekly, so this line is stale by design — never quote it as today's version.
> Re-derive it instead:
>
> ```bash
> curl -s "https://clientsettings.roblox.com/v2/client-version/MacStudio"   # or WindowsStudio64
> curl -s "https://api.github.com/repos/luau-lang/luau/releases?per_page=1" | grep tag_name
> ```
>
> The `WindowsStudio` (no `64`) endpoint returns a long-stale value — use `WindowsStudio64` or
> `MacStudio`. When in doubt about an API, look it up below rather than recalling it.

---

## MCP Detection

On every invocation, detect available Roblox Studio MCP tools before proceeding:

### Mandatory MCP Pre-Flight & Built-in `rbx-*` Skill Gate

**This skill is a knowledge base, not an MCP server.** It ships no tools. The tools below belong
to **Roblox's own MCP server built into Studio** (https://create.roblox.com/docs/studio/mcp). When
Studio MCP tools are available, run this gate automatically without waiting for the user to remind
you:

1. **Pin target & mode**: Call `list_roblox_studios` (pass `studio_id` on every call; no
   `set_active_studio` tool exists), then `get_studio_state` (`Edit` / `Client` / `Server`).
2. **Load Studio's built-in `rbx-*` skill first when the domain matches**: Call
   `list_roblox_skills` → `get_roblox_skill` (`list_skills` / `skill` on older Studio hosts)
   whenever a task involves debugging/breakpoints, profiling/heap/scene/network/device simulation,
   streaming conversion, analytics, Open Cloud/permissions, model import, IAS migration,
   `ConfigService`, `ProcessReceipt` audit, or unit tests. See **Built-in `rbx-*` Skill Routing**
   below — and verify known stale `rbx-*` steps against `references/mcp-integration.md`.
3. **Safety first**: Before the first mutation of any session, read `references/agent-safety.md`.
   There is no dry-run and no reliable undo; confirm which place you are targeting first.

### Official Roblox MCP (`Roblox_Studio` server)

`create.roblox.com/docs/studio/mcp` lists **30 tools**. Studio **0.748.0.7481526** exposes **39**
(those plus `open_cloud_invoke` and undocumented/newer generation, skill, save, capture, and
feedback tools; full count history in `references/mcp-integration.md`). Detect what your host
exposes rather than trusting this table.

| Tool | Purpose |
|------|---------|
| `list_roblox_studios` | Enumerate connected Studio instances (name, `studio_id`, place ID) |
| `get_studio_state` | Play state **and which `datamodel_type` values are currently available** |
| `list_roblox_skills` / `get_roblox_skill` | List & load Roblox's 17 first-party `rbx-*` guides (older hosts: `list_skills` / `skill`) |
| `create_skill` / `edit_skill` | Publish/edit a user skill (persistent on Roblox account; ask first) |
| `execute_luau` | Run Luau in Studio at plugin privilege (`Edit`/`Client`/`Server`) — **returns result or error**; HTTP & DataStores go through MCP Permissions |
| `open_cloud_invoke` | Call Open Cloud without an API key, gated by MCP Permissions; uploads create permanent assets (ask first) |
| `multi_edit` | Exact-match sequential edits to **ONE** script (`Edit` datamodel only; creates if missing) |
| `script_read` | Read script source (`LINE→CONTENT`), whole or by line range |
| `script_search` / `script_grep` | Find scripts by name (fuzzy, ≤10) or content (≤50 matches; confirm line numbers with `script_read`) |
| `search_game_tree` / `inspect_instance` | Explore DataModel (`datamodel_type` required) or inspect one instance's properties/attributes |
| `subagent` | Launch a Studio-side subagent (`explore`, `screen_capture`, `unit_test` — check schema) |
| `start_stop_play` | Start or stop playtesting |
| `save_place` | Save open place (Ctrl+S equivalent; creates Roblox version or writes local file; **never publishes**; don't call every edit) |
| `get_console_output` | Read Output/console logs (history capped at 512 lines; store test telemetry in attributes too) |
| `screen_capture` | Capture viewport (`capture_id` required; `camera_position` + `look_at_position` as `[x,y,z]` arrays together) |
| `video_capture` | Record playtest video (`Client` only; returned `Target is not reachable` in 0.748.0.7481526 — keep `screen_capture` primary) |
| `character_navigation` | Move character to a position or instance path (`Client` only; requires walkable navmesh) |
| `user_mouse_input` / `user_keyboard_input` | Simulate ordered mouse/keyboard actions (`Client` only) |
| `search_asset` / `insert_asset` | Search Creator Store + Inventory; insert by asset ID |
| `store_image` / `upload_image` | `store_image`: local png/jpg ≤5 MB → `IMAGEID_` URI. `upload_image`: HTTP(S) URLs → asset IDs |
| `generate_mesh` / `generate_procedural_model` | Generate textured 3D mesh or attribute-driven `ProceduralModel` (accepts `attachedImageUri`, default `async: true`) |
| `generate_material` | Generate a `MaterialVariant`; returns `BaseMaterial` + `Name` |
| `generate_texture` | Re-texture an existing MeshPart/Model — **replaces source in place** (duplicate first) |
| `segment_mesh` | Split a **single `MeshPart`** into ≤5 named parts (errors `SegmentRequiresSingleMeshPart` on multi-part Models) |
| `generate_scene` | Generate models/parts in an optional bounding box; **runs the generated script in the DataModel** |
| `generate_avatar` / `auto_setup_avatar` | Generate & upload persistent rigged R15 avatar, or rig static Model (3–5 min) |
| `generate_animation` | Generate R15+ animation from `textPrompt` (1–30s) or upscale R6 `inputAssetId` |
| `wait_job_finished` | Await `jobId` from `async: true`; **45 s** per-call cap for external MCP clients (loop while `status == "Running"`) |
| `http_get` | Fetch Roblox docs **from allowlist** (`.md` or `llms.txt` only) |
| `submit_feedback` | Send ≤4000-byte feedback on Studio/MCP tools (never include source code, PII, or credentials; respect user opt-out) |

> **Core MCP constraints**: `execute_luau` accepts `Edit`/`Client`/`Server`, whereas `multi_edit`
> accepts **`Edit` only** (stop playtest first) and `script_read` first so `old_string` matches
> verbatim. Confirm `script_grep` lines with `script_read`. There is **no `run_as_job` tool** —
> async is a per-tool `async: true` arg returning a `jobId`.

If MCP tools are NOT available, provide copy-paste-ready Luau scripts with clear container paths.

---

## Routing Table

Match user intent to the appropriate reference file **and** built-in Studio `rbx-*` skill. Read
the reference BEFORE generating code.

| User Intent | Reference File |
|---|---|
| **How do I sequence this?** End-to-end patterns: server-authoritative feature, MCP debug, deprecation migration, API lookup, unsafe-request refusal, developer product, save migration, IAS toggle, concept-image-to-3D + playtest, `rbx-*` skill routing | `references/worked-examples.md` |
| Luau syntax, types, naming conventions, style | `references/luau-fundamentals.md` |
| Project layout, architecture, Rojo, IAS, `ConfigService` | `references/project-structure.md` |
| Save/load player data, DataStore, ProfileStore | `references/datastore-persistence.md` |
| Client-server communication, RemoteEvents, input, text chat (`TextChatService`) | `references/networking.md` |
| Security, anti-exploit, server authority, bans | `references/security-hardening.md` |
| Agent→Studio safety, destructive MCP ops, `save_place` / `submit_feedback`, prompt injection | `references/agent-safety.md` |
| Performance, memory, Parallel Luau, live instance groups (`CreateCollection`) | `references/performance-optimization.md` |
| Studio MCP tools, generative 3D/animation pipeline, playtest automation, `rbx-*` skill audit | `references/mcp-integration.md` |
| Open Cloud from MCP (`open_cloud_invoke`), MCP Permissions, uploads | `references/mcp-integration.md` + `references/agent-safety.md` |
| UI, GUI, ScreenGui, menus, HUD, StyleQuery | `references/ui-systems.md` |
| Migrating legacy code, deprecated APIs, 0.748 engine changes | `references/legacy-migration.md` |
| Monetization, game passes, developer products, donations, transfers | `references/monetization.md` |
| File formats, import/export, asset management | `references/file-formats-and-assets.md` |
| Plugins, `Script.Source` limits, HttpService/engine limits | `references/studio-plugins-and-limits.md` |

### Built-in `rbx-*` Skill Routing (when Studio MCP is connected)

Studio's 17 `rbx-*` skills (`list_roblox_skills` / `get_roblox_skill`) own **Studio MCP execution
recipes**; this repo's `references/` own **`--!strict` Luau, security, architecture, and engine
truth** (and catch stale `rbx-*` steps). Load both when a task spans both:

| Task Domain | Call `get_roblox_skill(...)` | Pair with `roblox-dev-skill` Reference |
|---|---|---|
| Breakpoints / runtime thread inspection | `rbx-debug` | `mcp-integration.md` |
| MicroProfiler, Luau heap, SceneAnalysis | `rbx-perf-profiling`, `rbx-luau-heap-profiling`, `rbx-scene-analysis` | `performance-optimization.md` + `mcp-integration.md` |
| Network lag / Device UI sim / Streaming | `rbx-network-simulator`, `rbx-device-simulator-lua`, `rbx-convert-to-streaming` | `performance-optimization.md` + `mcp-integration.md` (stale-step fixes) |
| Input Action System / `ConfigService` | `rbx-input-action-system`, `rbx-configs-experimentation` | `project-structure.md` |
| `ProcessReceipt` audit / Analytics / Unit tests | `rbx-process-receipt-misuse`, `rbx-instrument-analytics`, `rbx-unit-test` | `monetization.md` (`BindReceiptHandler`), `luau-fundamentals.md` |
| Open Cloud / Permissions / FBX-glTF import | `rbx-permissions`, `rbx-open-cloud-usage`, `rbx-import-asset` | `mcp-integration.md` + `agent-safety.md` + `file-formats-and-assets.md` |
| Docs search / Custom Studio skill | `rbx-docs-search`, `rbx-create-skill` | `mcp-integration.md` |

**Start with `worked-examples.md` when the task is a *doing* task** (build, debug, migrate, look up,
sell, bind input, generate 3D + playtest, route `rbx-*`). Where an example and a reference file
disagree, the reference file wins.

---

## API & Documentation Lookup

### Priority 1: Local API Reference (`~/RobloxDocs/`)

**Always check local files first** — they are pre-split and require no network. Measured on
**0.748.0.7481526**: the full dump is **8,798,639 bytes**; the **960** split class files run
**101 B min, 2,065 B median, 4,887 B mean, 106,393 B max** (~0.02% of the dump per typical class).

```bash
# Portable size check (macOS/Linux/Windows; avoid `stat -f %z`, which misreports symlinks/Linux)
python3 -c "import os,glob,statistics as s; d=os.path.expanduser('~/RobloxDocs/RobloxAPI'); \
z=sorted(os.path.getsize(f) for f in glob.glob(d+'/classes/*.json')); \
print('dump', os.path.getsize(os.path.realpath(d+'/dumps/latest.json')), 'B | n', len(z), \
'min', z[0], 'median', int(s.median(z)), 'mean', int(s.mean(z)), 'max', z[-1])"

cat ~/RobloxDocs/RobloxAPI/classes/<ClassName>.json
jq '.Members[] | select(.Name == "<MemberName>")' ~/RobloxDocs/RobloxAPI/classes/<ClassName>.json
cat ~/RobloxDocs/RobloxAPI/service-index.json
cat ~/RobloxDocs/RobloxAPI/deprecated-index.json
ls ~/RobloxDocs/RobloxAPI/classes/ | grep -i <keyword>
grep -l '"<PropertyName>"' ~/RobloxDocs/RobloxAPI/classes/*.json
```

**Obsolescence check:** Read `updatedAt` OR `checkedAt` (older installs may lack `checkedAt`) from
`~/RobloxDocs/RobloxAPI/.current-version`:
```bash
cat ~/RobloxDocs/RobloxAPI/.current-version
```
If older than 7 days or missing, **fall back to Priority 2** and offer to refresh (never
background or auto-run without user approval):
```bash
~/RobloxDocs/scripts/roblox-api-monitor.sh                      # macOS, Linux, WSL, Git Bash
python "%USERPROFILE%\RobloxDocs\scripts\roblox-api-monitor.py"    # Windows without bash
```
If `~/RobloxDocs` does not exist, point the user to the installer's `--docs-only` (`-DocsOnly`) flag.

### Priority 2: Live Web Sources (Fallback)

| Resource | URL | Use For |
|----------|-----|--------|
| **LLM docs index** | `https://create.roblox.com/docs/llms.txt` | Browse all available doc pages by topic |
| **Full docs (single file)** | `https://create.roblox.com/docs/llms-full.txt` | Comprehensive single-file reference |
| **Per-page markdown** | `https://create.roblox.com/docs/en-us/{path}.md` | Read specific doc pages in clean markdown |
| **Engine API index** | `https://create.roblox.com/docs/reference/engine/llms.txt` | Luau API classes, methods, events |
| **Open Cloud API index** | `https://create.roblox.com/docs/cloud/llms.txt` | **Primary discovery** for all Cloud REST API: features, domains, guides, auth |
| **OpenAPI spec (raw)** | `https://create.roblox.com/docs/cloud/openapi.json` | Machine-readable OpenAPI spec for MCP/code-gen tools |
| **Deprecated API check** | `https://robloxapi.github.io/ref/class/<Name>.html` | Visual deprecated member check |

> **`http_get` allowlist**: only `create.roblox.com/docs` and `github.com/Roblox/libmp` ending in
> `.md` or `llms.txt` (`llms-full.txt`, `openapi.json`, `robloxapi.github.io` are rejected — use
> the host fetch tool or `curl`; read LibMP via `raw.githubusercontent.com`). Use `query` to save tokens.

### Lookup Workflow
1. Check the matching **reference file** (Routing Table) and, when MCP is connected, `get_roblox_skill`.
2. Check **`~/RobloxDocs/RobloxAPI/classes/<Name>.json`** (`Security`, `Capabilities`, `Tags`).
3. Fetch per-page markdown (`https://create.roblox.com/docs/en-us/{path}.md`) or browse `llms.txt`.
4. For **Open Cloud / REST**, check `https://create.roblox.com/docs/cloud/llms.txt` (call via `open_cloud_invoke` from MCP — no API key needed).
5. **Fallback**: Context7 (`resolve-library-id` → `query-docs`, or `npx ctx7@latest library "Roblox"` → `docs <id> "<question>"`).
6. If still unclear, ask the user before proceeding.

> **Important**: Engine APIs (`game:GetService()`) and Open Cloud REST APIs (`x-api-key` /
> `open_cloud_invoke`) are **completely separate systems**. For deprecations, check
> `deprecated-index.json` → `deprecated/<ClassName>.json` → `robloxapi.github.io/ref` → Context7 (`resolve-library-id` → `query-docs`).

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
<!-- skilltest: prelude datastore; expect call-succeeded -->
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
1. Run MCP Pre-Flight (`list_roblox_studios`, `get_studio_state`, `list_roblox_skills` / `get_roblox_skill` if domain matches — e.g. `rbx-configs-experimentation`, `rbx-input-action-system`, `rbx-instrument-analytics`)
2. Read existing project structure (`search_game_tree`) and matching `references/*.md`
3. Create `--!strict` ModuleScript(s) in the appropriate container (`multi_edit`)
4. Wire up validated server/client communication if needed
5. Test via playtest (`start_stop_play` + `get_console_output` + `execute_luau` assertions)

### Debug Issue
1. Check `list_roblox_skills` / `get_roblox_skill("rbx-debug")` when breakpoints or thread inspection are needed
2. Read console output (`get_console_output`) and the offending script (`script_read` — confirm `script_grep` line numbers first)
3. Inspect live state (`execute_luau` on `Server`/`Client`), then **stop playtest** (`start_stop_play`) before editing
4. Apply minimal exact-match fix (`multi_edit` in `Edit` datamodel) and verify via playtest (`0` errors, `0` new warnings)

### Concept-Image / 3D Generation & Automated Playtest
1. Local concept image → `store_image` (≤5 MB png/jpg → `IMAGEID_`) → `generate_procedural_model` / `generate_mesh` / `generate_material` / `generate_animation` (`async: true` → loop `wait_job_finished` while `status == "Running"`, 45s per-call cap). Duplicate before `generate_texture`; pass a single `MeshPart` to `segment_mesh`.
2. Add `--!strict` physics/gameplay scripts (`multi_edit`), then `start_stop_play` → `character_navigation` / `user_keyboard_input` / `user_mouse_input` → `execute_luau` (`Server`/`Client` attribute assertions) → `screen_capture` (keep primary; `video_capture` failed in 0.748.0.7481526) → stop playtest → `save_place` only when asked.

### Code Review
1. Read scripts in the project (`script_grep` + `script_read`)
2. Check against Core Coding Standards above and `references/security-hardening.md`
3. Flag security issues (client trust, exposed data) and performance issues (hot loops, part count)
4. Suggest improvements with before/after examples

---

## Knowledge Freshness Check

Nothing about this is automatic — there is no scheduler, hook, or background job behind it. It is an
instruction to *you*, the agent reading this file: **when this skill is invoked**, read
`metadata.json` in this skill directory and compare `last_updated` to the current date.

### Logic:
```
IF (current_date - last_updated) > update_interval_days (default: 7):
    TELL the user:
    "⏰ Roblox Dev Skill knowledge was last updated on {last_updated}, {days} days ago.
     Want me to run a knowledge update before we rely on it?"
    ...then WAIT. Do not update anything unless they say yes.
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

The user can trigger a full knowledge update at any time by asking for one in plain language —
"update roblox skill knowledge", "refresh roblox dev skill", "roblox-update".

> **`/roblox-update` is NOT a registered slash command.** Earlier versions of this file presented it
> as one; it has never been installed in `~/.claude/commands/` or shipped by a plugin, so typing it
> resolves to nothing. It is a phrase this skill listens for, and that is all it has ever been.

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

Users install it with the one-line installers in the repository (`install.sh`, `install.ps1`,
`install.cmd`), which link it into each agent's skills folder. When copying it by hand, the folder
**must be named `roblox-dev-skill`** — the Agent Skills spec requires the folder name to match the
`name` field above, and stricter agents skip a skill whose folder does not.

