# Roblox Studio MCP Integration

> **Primary source (re-verified 2026-11-07):**
> https://create.roblox.com/docs/studio/mcp — raw markdown at
> `https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/studio/mcp.md` —
> and, since 2026-11-05, https://create.roblox.com/docs/studio/mcp-open-cloud for Open Cloud and
> MCP Permissions.
>
> Every tool description below is taken from that page or from the live tool schema of the
> installed server. Where the two disagree, both readings are given.

> How to use the `Roblox_Studio` MCP server to drive Roblox Studio from an AI agent.

**This skill is not an MCP server.** It is a knowledge base that is *read by* an agent which
may also be connected to Roblox's own Studio MCP server. This skill ships no tools, no
transport, and no `execute` surface of its own. See `references/agent-safety.md` for what that
distinction means for the trust boundary.

## Table of Contents

1. [Overview](#overview)
2. [Setup](#setup)
3. [Tool Reference](#tool-reference)
4. [Recommended Workflows](#recommended-workflows)
5. [Best Practices](#best-practices)
6. [Corrections Log](#corrections-log)

Open Cloud and permissions: [Open Cloud and MCP Permissions](#open-cloud-and-mcp-permissions).

---

## Overview

The **Roblox Studio MCP server is built into Roblox Studio** and is the supported integration
path. It implements the Model Context Protocol, letting an AI client explore the DataModel,
write scripts, run Luau, and playtest inside your open Studio session.

Mechanics that matter when things break:

- It **runs as a local process on your machine** and speaks **`stdio` transport**. It is not a
  network service you point a URL at. On macOS the binary is
  `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`; on Windows it is
  `%LOCALAPPDATA%\Roblox\mcp.bat`.
- All actions are **initiated by the client**, which sends a request down that channel into the
  running Studio session. Studio must be open, with the server enabled, or every call fails.

> **Migration note:** the previous standalone Rust server (`Roblox/studio-rust-mcp-server` on
> GitHub) is **archived** — verified 2026-09-25 via the GitHub API: `archived: true`, last push
> 2026-04-03. Do not install it, and do not follow guides that tell you to. Nothing needs to run
> as a separate process any more.

**Host-specific call convention — check yours before following either line.** In **Antigravity**,
tools are lazily loaded: read the schema from
`~/.gemini/antigravity/mcp/Roblox_Studio/<toolName>.json` first, then call via `call_mcp_tool`
with server name `Roblox_Studio`. In **Claude Code** there is no `call_mcp_tool` wrapper — tools
appear directly as `mcp__Roblox_Studio__<toolName>`, and some are deferred, in which case load
the schema with tool-search before calling.

**Two arguments are on effectively every call:**

- **`studio_id` — required, on every tool.** There is no "set active studio" tool and no session
  state; the target is an argument, not a mode. Call `list_roblox_studios` (it returns name,
  Studio instance ID, and place ID) and pass the id you want each time. A forgotten or
  copy-pasted id silently drives the wrong place. Two instances with the same name are told
  apart by place ID; local places with no place ID are listed by name only.
- **`datamodel_type` (`Edit` / `Client` / `Server`) — required on the tools that take it.**
  `Edit` is the saved place. `Client` and `Server` exist **only while a playtest is running**.
  Call `get_studio_state` to see which are currently available. Note the asymmetry:
  `execute_luau` and `search_game_tree` accept all three, but **`multi_edit` accepts `Edit` only** —
  you cannot edit scripts through MCP while a playtest is running — and `character_navigation`,
  `user_keyboard_input` and `user_mouse_input` accept `Client` only. During a playtest `Edit` is
  refused: `Edit datamodel is not available in Play mode` (tested 2026-11-07).

**Two things this file will not claim:**

- **`ScriptDebuggerService` is `PluginSecurity`, so game code cannot reach it.** It does expose
  `AddBreakpoint`, `RemoveBreakpoint`, `ClearBreakpoints`, `Pause`, `Evaluate`, `GetStackTrace`,
  `GetThreads`, `GetVariables`, `GetRootVariables`, `SetExceptionBreakMode`, `OnStopped`,
  `Resumed` — but **every one of those members is `PluginSecurity`** (verified against the API
  dump). A Script or LocalScript calling them errors; only a plugin, the command bar, or
  `execute_luau` can. Roblox ships a first-party `rbx-debug` skill for exactly this — reach it
  through the `skill` tool rather than improvising.
- **Studio Assistant "Planning Mode" is not exposed by any MCP tool**, and this file has never
  carried a source for it. Build nothing on it. For multi-step verification, drive
  `start_stop_play` + `get_console_output` yourself, or hand the steps to the user.

---

## Setup

1. Open **Assistant** in Studio.
2. Click **…** → **Manage MCP Servers**.
3. Turn on **Enable Studio as MCP server**.

Then connect the client one of three ways, in this order of preference:

- **Quick connect** (Assistant Settings → MCP Servers → *Quick connect*) — officially supports
  Antigravity, Codex CLI, Claude Code, Claude Desktop, Cursor, Gemini CLI, and Visual Studio
  Code. If your client is missing from the list, install it and restart Studio.
- **JSON config**, for any client that reads `mcp.json`:

  ```json
  {
    "mcpServers": {
      "Roblox_Studio": {
        "command": "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
      }
    }
  }
  ```

  On Windows: `"command": "cmd.exe"`, `"args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]`.
  Merge the `Roblox_Studio` entry into an existing `mcpServers` dictionary rather than replacing
  the file, and mind the commas: "Missing commas will result in invalid JSON and prevent the
  configuration from loading" (official page).
- **CLI command**, for clients that want one: run the binary path above directly.

**Verify:** Assistant → **…** → **Manage MCP Servers** → under *Enable Studio as MCP server*,
a green indicator shows the number of connected clients.

**If tools do not appear:** restart both Studio and the client, confirm the binary path exists,
and re-check the JSON syntax. Any client that supports `stdio` works.

> **Roblox's own warning, quoted:** *"MCP clients can read and modify content in your open
> Roblox places. Make sure to only connect clients you trust."* Read
> `references/agent-safety.md` before acting on a place you care about.

---

## Tool Reference

**Counts, stated precisely.** The official docs page lists **26 tools** (recounted 2026-10-17; its
only later change, on 2026-11-05, links the Open Cloud page). **On 2026-11-07 (Studio
0.746.0.7461269) the build exposes 35**: the 34 of 2026-11-05 plus `open_cloud_invoke`, the one
addition that has a docs page of its own. **On 2026-10-29 (Studio
0.745.0.7451137) the build exposed 31**: the 28 below plus three undocumented skill-authoring
tools, `list_skills`, `create_skill` and `edit_skill` (see *Documentation and skills*); the other
28 schemas were unchanged. The build observed on
2026-10-17 and again on 2026-10-21 (Studio 0.743.0.7431133) and 2026-10-22 (Studio 0.744.0.7441077,
`StudioMCP` binary of 2026-10-20) exposes **28**: those 26 plus `generate_texture` and
`segment_mesh`, which are present but undocumented. Their schemas were unchanged across the three
dates. On 2026-10-11 (Studio 0.742) it also exposed
`list_plugin_guis` and `capture_plugin_gui`; on 2026-10-17 both were gone. Tool sets move; when a call fails with an unknown-tool error, list what
your host actually exposes instead of trusting this table.

### Scripts

| Tool | What it does |
|---|---|
| `script_read` | Reads a script by dot-notation path. Output is `LINE_NUMBER→LINE_CONTENT`. Reads the whole script by default; for large scripts pass `should_read_entire_file: false` with `start_line_one_indexed` + `end_line_one_indexed_inclusive`. Never creates a script. |
| `multi_edit` | Applies **several edits to one script** in a single atomic call. Creates the script if the path does not exist. |
| `script_search` | Finds scripts **by name**, fuzzy-matched. **Returns up to 10 results.** |
| `script_grep` | Searches a string or Luau pattern across **all** script contents. **Capped at 50 matches.** |

**`multi_edit` — the shape agents most often get wrong:**

```jsonc
{
  "file_path": "game.ServerScriptService.GameManager",   // dot notation, full path
  "datamodel_type": "Edit",                              // Edit ONLY — no Client/Server
  "studio_id": "<from list_roblox_studios>",
  "edits": [
    { "old_string": "JUMP_COOLDOWN = 0.15", "new_string": "JUMP_COOLDOWN = 0.3" }
  ],
  "className": "Script"                                  // only when creating a new script
}
```

- It is **one script per call**, keyed by `file_path`. It is *not* a batch across several
  scripts, and it does **not** take whole-source replacements. Rename something across three
  scripts and that is three calls.
- Edits are **string replacements applied in sequence**, each operating on the result of the
  last. `old_string` must match the current contents **exactly**, whitespace included, and must
  differ from `new_string`. Use `replace_all: true` to rename a symbol throughout.
- **Atomic:** if any edit fails to apply, the whole call fails and nothing is written. Plan the
  sequence so edits do not invalidate each other.
- **Creating a script:** pass `className` (`Script`, `LocalScript`, `ModuleScript`) and make the
  first edit `old_string: ""` to set the initial content; later edits then behave normally.
- `script_read` first. A `multi_edit` written from a guessed `old_string` simply errors.

### Luau execution

| Tool | What it does |
|---|---|
| `execute_luau` | Runs Luau in Studio and **returns the result of the code, or the error**. Requires `datamodel_type`: `Edit`, `Client`, or `Server`. |

- Runs at **plugin / command-bar privilege**, not game privilege — it can reach
  `PluginSecurity` members that a Script cannot.
- **That privilege does not reach `NotScriptable` properties.** These are Properties-window-only
  settings such as `SandboxedInstanceMode`, `EnableSLIMAvatars` and `PlayerCharacterDestroyBehavior`
  on Workspace. No Luau can read or write them, so an agent should ask the user
  to change them in Studio rather than retry. Measured in Studio 0.741.19.7411056: reading any of
  them from `execute_luau` fails with `<Name> is not a valid member of Workspace "Workspace"`. That
  message reads like a typo, and it is not one. Check the member's `Tags` in
  `~/RobloxDocs/RobloxAPI/classes/<Class>.json`.
- **Nor does it reach `RobloxScriptSecurity`.** `PlayerScriptsUseInputActionSystem` was in the list
  above until 0.742; since 0.743 it is `RobloxScriptSecurity`, and `execute_luau` reading it fails
  with `The current thread cannot read 'PlayerScriptsUseInputActionSystem' (lacking capability
  RobloxScript)` (Studio 0.743.0.7431133; same in 0.744.0.7441077). It is still a Properties-window setting.
- In `Edit` it operates on the saved place. In `Client` / `Server` it operates on the live
  playtest DataModel, which only exists while a playtest is running.
- **It does return values.** Earlier versions of this file claimed MCP tools could not return
  Luau values and that `print()` was the only way out — that was wrong. `print()` is still
  useful for *incremental* output during long work, which surfaces via `get_console_output`.
- There is **no automatic timeout**. An infinite loop hangs Studio. The tool's schema says more:
  until the code yields, Studio is frozen and the MCP connection may drop. Split heavy work into
  chunks of about 1000 items with one `task.wait()` per chunk, build each chunk outside the
  DataModel, and parent it before that wait, because one `.Parent` write costs the whole subtree.
- **A call that yields forever ends in `Request timeout`.** Measured 2026-11-07: an `execute_luau`
  call in `Edit` that included `HeapProfilerService:ServerRequestDataAsync()` returned exactly that
  (the same call in a timed thread was still waiting after 4 s; in the `Server` datamodel during a
  playtest it returned in 0.4 s). If a call times out, check what it had already changed before you
  retry it: earlier lines did run.
- **HTTP and data stores are gated for this tool.** See
  [Open Cloud and MCP Permissions](#open-cloud-and-mcp-permissions).

### Data model exploration

| Tool | What it does |
|---|---|
| `search_game_tree` | Explores the instance hierarchy as a flat JSON array; filters by path, instance type, and keywords, with configurable depth. **`datamodel_type` is required.** |
| `inspect_instance` | Full detail on one instance: readable properties, custom attributes, and a summary of children/descendants. |
| `subagent` | Launches a specialized subagent for autonomous multi-step work. |

**`subagent` types are build-dependent — read the schema, do not hardcode.** The official docs
name `explore` and `playtest`; the build in this session advertised `explore`, `screen_capture`,
and `unit_test`. A subagent returns one final text summary and cannot be conversed with or
nested. `explore` answered a read-only question correctly during a playtest (run 2026-11-07).

### Playtesting

| Tool | What it does |
|---|---|
| `get_studio_state` | Current play state **and which datamodel types are available**. Call this before anything that takes `datamodel_type`. |
| `start_stop_play` | Starts or stops playtesting. |
| `get_console_output` | Reads the Studio output log. |
| `screen_capture` | Captures the viewport and returns image data; optionally takes a custom camera position and look-at target. **`capture_id` is required** (for example `ScreenCapture_1`). |
| `list_plugin_guis` / `capture_plugin_gui` | **Not in the 2026-10-17 build (Studio 0.743).** On 2026-10-11 they listed plugin widgets with a `pluginGuiId` (hidden ones too) and screenshotted a **visible** one by that id. Undocumented; do not plan on them |

### Player input simulation

| Tool | What it does |
|---|---|
| `character_navigation` | Moves the player character to a position **or an instance path**, with a configurable speed multiplier. |
| `user_keyboard_input` | Sends ordered keyboard actions: key down, key up, key press, text input, or wait. Can target a specific UI instance. |
| `user_mouse_input` | Sends ordered mouse actions: move, click, button down/up, scroll, or wait. Can target instances or screen coordinates. |

### Assets and content generation

| Tool | What it does |
|---|---|
| `search_asset` | Searches the **Creator Store** (public) and **Creator Inventory** (user / group / universe), filterable by asset type, price, tags, and scope. Its schema says to name the source and destination and get consent before inserting an asset whose `creatorId` differs from the place's owner. |
| `insert_asset` | Inserts an asset by numeric asset ID — models, meshes, images, audio, video, animations, packages. |
| `generate_mesh` | Generates a textured 3D mesh from a text prompt. Options: `maxTriangles` (12–20000), `size`, and `segmentation` (`auto`, `none`, or `explicit` with up to 8 `partNames`). |
| `generate_procedural_model` | Builds an object from primitive parts (blocks, spheres, cylinders, wedges) as a `ProceduralModel` with configurable attributes; accepts reference images and custom part schemas. |
| `generate_material` | Generates a material variant; returns the base material plus the variant name to apply. |
| `generate_scene` | **Undocumented; first seen 2026-11-05 (Studio 0.746).** Generates models and parts from `textPrompt` and/or `images`, in an optional `boundingBoxPosition` / `boundingBoxSize`, and **runs the generated script in the DataModel**. Schema read, not run: review what it may change first. |
| `generate_avatar` | **Undocumented; first seen 2026-11-05.** Generates a rigged R15 avatar from `textPrompt` (options `pipelineName` `npc` / `modesty`, `dynamicHead`, `r15Plus`), **uploads it as a persistent asset** and inserts it into Workspace. Usually several minutes. Its description says to prefer `async`, but the schema has no `async` property (read 2026-11-07), so expect the call to block. Schema read, not run. |
| `auto_setup_avatar` | **Undocumented; first seen 2026-11-05.** Rigs a static Workspace Model (`instance_path`, or the single selected Model) as an R15 avatar and places the result beside it; `setup_type` `Platform` (marketplace-compatible, the default) or `Development` (experience-only NPCs). Its schema says do not set Selection with `execute_luau`. Usually 3-5 minutes. Schema read, not run. |
| `wait_job_finished` | Waits for a background job to reach a terminal state (Completed / Failed / Cancelled) and returns its status. |
| `store_image` | **Local file → URI.** Loads a png/jpg/jpeg from an absolute local path (**max 5 MB**) and returns an `IMAGEID_<id>` URI for other tools, e.g. as `attachedImageUri` for `generate_procedural_model`. |
| `upload_image` | **HTTP URLs → asset IDs.** Uploads a *batch* of images **fetched from HTTP(S) URLs** and returns an imagePath→assetId map, e.g. `{"https://…/image.png": "rbxassetid://12345678"}`. |

> **`store_image` and `upload_image` are not interchangeable, and this file previously described
> `upload_image` as taking a local file.** It does not: it takes URLs and returns a map. A local
> file goes through `store_image`, which returns an `IMAGEID_` URI, **not** an asset ID.

> **`wait_job_finished` takes a `jobId`**, which you get back from a tool that was called with
> its own `async: true` argument. Its `timeout` defaults to 600 s. Async is a per-tool argument,
> **not** a separate wrapper tool — see the corrections log.

### Documentation and skills

| Tool | What it does |
|---|---|
| `http_get` | Fetches Roblox documentation **from an allowlist only**. Supports in-content keyword search via `query`, with `context_lines` (default 3) and `return_full`. |
| `skill` | Retrieves Roblox's own first-party reference material for a named skill. |
| `list_skills` | Lists every available skill with its source (`Roblox` for the first-party ones) and description. Read-only. *New 2026-10-29, undocumented* |
| `create_skill` | Creates a **user** skill from `skill_name` (lowercase, digits, `_` and `-`; may not start with `rbx-`), a one-line `skill_description` and a markdown `skill_body`, and "**publishes**" it, available immediately. *New 2026-10-29; not run here* |
| `edit_skill` | Renames or rewrites a user-created skill (`new_name`, `new_description`, `new_skill_body` replaces the whole body). Roblox's own skills cannot be edited. *New 2026-10-29; not run here* |

**`create_skill` and `edit_skill` write persistent state outside the place**, which a place
revert does not undo, and `edit_skill` replaces the body without a diff. Ask before calling
either, and read the current body with `skill` before an edit. Per the `Assistant/Skills` docs
page, a skill belongs to the **Roblox account**, so it is available in every place that account
opens, and it is deleted in **Assistant Settings → Skills**: no MCP tool deletes one. Duplicating a
Roblox-authored skill there disables the original in favour of your copy, and the copy gets no
further updates.

**`http_get` is allowlisted, not a general fetcher.** Permitted prefixes: `create.roblox.com/docs`
(including `/reference/engine`, `/cloud`, `/performance-optimization`) and
`github.com/Roblox/libmp`. **The URL must end in `.md` or be `llms.txt`** — anything else is
rejected, which notably includes `llms-full.txt` and `openapi.json`. For those, and for any
non-Roblox URL, use the host's own fetch tool or `curl`.

Using `query` is the token-efficient path: it returns only matching sections with context rather
than the whole page.

> **A `github.com/Roblox/libmp/blob/….md` URL passes the allowlist but returns HTML.** On
> 2026-10-21, `http_get` on `https://github.com/Roblox/libmp/blob/main/docs/ALL-SCOPES.md` with a
> `query` returned GitHub's page markup, about 1 MB in 7 lines, so the one "matching section" was
> a whole line of embedded JSON. For LibMP docs, fetch
> `raw.githubusercontent.com/Roblox/libmp/main/…` with the host's own fetch tool or `curl`
> (that host is not on the allowlist), or use `skill("rbx-perf-profiling")`.

**First-party skills exposed by the `skill` tool (2026-11-07, Studio 0.746.0.7461269, seventeen):**
`rbx-configs-experimentation`, `rbx-convert-to-streaming`, `rbx-create-skill`, `rbx-debug`,
`rbx-device-simulator-lua`, `rbx-docs-search`, `rbx-import-asset`, `rbx-input-action-system`,
`rbx-instrument-analytics`, `rbx-luau-heap-profiling`, `rbx-network-simulator`,
`rbx-open-cloud-usage`, `rbx-perf-profiling`, `rbx-permissions`, `rbx-process-receipt-misuse`,
`rbx-scene-analysis`, `rbx-unit-test`. The three added since 2026-11-05 are the Open Cloud set:
`rbx-open-cloud-usage`, `rbx-permissions` and `rbx-import-asset` (bring a model in from Blender or
another tool, then repair what the importer changed). The `Assistant` docs page lists
fewer, so run `list_skills` for the current set.

These are Roblox's, shipped inside Studio, and they go **deeper than this skill on their specific
topics**: use `skill("rbx-debug")` for breakpoint work, `skill("rbx-perf-profiling")` for MicroProfiler
and LibMP analysis, `skill("rbx-luau-heap-profiling")` for leaks, `skill("rbx-scene-analysis")` for
SceneAnalysisService, `skill("rbx-permissions")` before an Open Cloud call, and
`skill("rbx-input-action-system")` to migrate input. Use this repository's references for
architecture, security, and Luau standards, which they do not cover.

**Read them, then check them: first-party does not mean current.** On 2026-11-07, eleven were read
in full; for the six long ones (input, streaming, network, analytics, scene, profiling, 50–120 KB
each) the rule sections were read and every API and tool name was checked against the dump and the
live tool list. These statements failed when run:

| A Roblox skill says | What happened (Studio 0.746.0.7461269) |
|---|---|
| `rbx-device-simulator-lua`: `execute_luau` "cannot access `PlayerGui`, `LocalPlayer`, or live `AbsolutePosition`/`AbsoluteSize` during Play mode" | With `datamodel_type: "Client"` it read `LocalPlayer.PlayerGui`, a `ScreenGui`'s `AbsoluteSize` and the viewport |
| `rbx-device-simulator-lua`, `rbx-network-simulator`: call `list_roblox_studios` + `set_active_studio` | `set_active_studio` is not a tool. Pass `studio_id` on each call |
| `rbx-scene-analysis`: `SceneAnalysisService` "doesn't work in edit mode" | `GetInstanceCompositionAsync()` returned a table in `Edit`. Runtime numbers still need a playtest |
| `rbx-input-action-system`: `StarterGui` "Never registers" an `InputContext` | True of the template. The copy the engine places in `PlayerGui` fired on a real key press (`project-structure.md`) |
| `rbx-create-skill`: gather requirements with `ask_questions` | Not an MCP tool; ask the user directly |

Also check what a skill leaves out. `rbx-process-receipt-misuse` audits `ProcessReceipt` and never
mentions `BindReceiptHandler` (see `monetization.md`), and `rbx-luau-heap-profiling` does not warn
that its call hangs in `Edit`. Its "Plugin-level security" line held: a game Script gets `lacking
capability Plugin`.

`rbx-network-simulator` drives `settings().Network` from `execute_luau`. Its values **persist on the
machine across Studio restarts** (per that skill), so record and restore them. Writes clamp silently,
measured: `InboundNetworkLossPercent = 200` read back `0.5`, and `InboundNetworkMinDelayMs = 5000`
read back `500`. A game Script fails on `settings()` with `lacking capability Plugin`.

### Open Cloud and MCP Permissions

`open_cloud_invoke` (first seen 2026-11-07; docs page 2026-11-05) calls a path under
`https://apis.roblox.com`. **There is no API key:** Studio requests a short-lived token for each call,
limited to what the user enabled. Pass `method`, `endpoint` (a path), and optionally `body` (a JSON
string), `scopes` and `files`. Read `skill("rbx-permissions")` and `skill("rbx-open-cloud-usage")`
first; `http_get` on `https://create.roblox.com/docs/cloud/llms.txt` finds the endpoints.

From the docs page:

- The user sets permissions in **Assistant Settings → MCP Permissions**, or **MCP** in Studio's
  bottom-right corner. They are **per game and per person**, saved to the Roblox account, so an
  unpublished local place cannot use them. Levels: **Safe**, **Balanced** (the default),
  **Full access**, and **Custom**. The client cannot change them.
- The same settings gate `execute_luau`: `DataStoreService` and `MemoryStoreService` need the
  **Save & load data** scopes (and **Enable Studio Access to API Services** in Game Settings), and
  `HttpService` needs **Connect to the internet** plus each domain on its allow list.
- **Use `DataStoreService` and `MemoryStoreService` through `execute_luau`, not Open Cloud.**
- **Uploads create permanent assets** owned by the game's owner. Open Cloud cannot archive or delete
  them; only the Creator Dashboard can. Files must be in a folder the user approved. To bring a model
  in from Blender or another tool, follow `skill("rbx-import-asset")`: the importer changes scale,
  rotation, colours and anchoring, so it records what to expect before uploading.
- These cannot be granted to MCP at all: badge scopes, `universe-datastores.control:*`,
  `universe-datastores.objects:create`, analytics alerts, and every `legacy-*` scope.

Measured 2026-11-07 on a published test place, with read-only calls (no write was sent):

| Call | Result |
|---|---|
| `GET /cloud/v2/universes/<id>` with `scopes: ["universe:read"]`, or with no `scopes` | `200`, with the universe's settings |
| Same, `scopes: ["universe:reed"]` (a typo) | `Could not acquire an Open Cloud access token: Scope 'universe:reed' has not been granted…`. **A misspelled scope reads exactly like a disabled one** |
| Same, `scopes: ["legacy-universe.badge:read"]` | The same error: an ungrantable scope looks disabled too |
| `endpoint: "https://apis.roblox.com/…"` | `endpoint must be a path starting with /, such as /cloud/v2/universes/123` |
| `GET /cloud/v2/universes/<id>/data-stores` with `scopes: ["universe-datastores.objects:read"]` | `403 Forbidden`, `Scope not authorized`. The scope probe passes and the call still fails, while the tool's text suggests asking for a grant: this listing needs `universe-datastores.control:*`, which cannot be granted |
| A `files` path outside an approved folder | Refused before any request: `… is not inside a directory approved for uploads. Ask the creator to add the file's directory…` |
| `GET` on `/cloud/v2/universes/<id>/places/<id>`, `/cloud/v2/universes/<id>/user-restrictions`, `/developer-products/v2/universes/<id>/developer-products/creator`, `/game-passes/v1/universes/<id>/game-passes/creator`, `/cloud/v2/users/<id>`, `/assets/v1/assets/<id>` | `200` with the matching scope, so these accept the MCP token for reads |

**To check a grant,** send a harmless `GET` that names one scope, as above: per `rbx-permissions`, a
missing scope fails before anything is sent, so this is safe even for a write scope. Probe one at a
time, because it stops at the first missing one. `200` proves the scope is on, not that an endpoint
accepts the token: a `403` with the scope on means that endpoint refuses MCP, so use a Studio tool or
the Creator Dashboard instead of asking the user again.

**Your host has its own gate.** In Claude Code on 2026-11-07, the permission classifier refused probes
naming `asset:write`, `universe-datastores.objects:update`, `universe.user-restriction:write` and
`universe.place.luau-execution-session:write`, before they reached Studio, so those four were not
measured. Report a refusal like that to the user; do not route around it.

**What `execute_luau` does with the same gates** (measured 2026-11-07, `Edit`, `HttpEnabled` `true`):

| Call | Result |
|---|---|
| `HttpService:GetAsync` / `RequestAsync` to a domain not on the list | `HttpService request denied: domain example.com is not in the Assistant HTTP allowlist` |
| `DataStoreService:GetDataStore(…):GetAsync(…)`, and `MemoryStoreService:GetSortedMap(…):GetAsync(…)` | Returned `nil` (scopes granted). **`Edit` reaches the live stores; a playtest is not required** |
| `MessagingService:PublishAsync` | `MessagingService can only be executed by game server`: there is no Studio route |

The docs list the other errors: `502 … Access forbidden` (the matching **Save & load data** scope is
off), `Studio access to APIs is not allowed` (the game setting), `InternalError` from a memory store
(its scopes are off), and `lacking capability <capability>` (only `Network` can be granted).

**Do not work around a refusal.** `rbx-permissions` is explicit: do not start a playtest or run game
code to do what MCP blocked, do not try other endpoints or domains for the same effect, and do not
copy a file into an approved folder. If the user declines, accept it. Using a Studio tool after an
endpoint refuses a *granted* scope is fine, because nobody blocked it. For that reason the playtest
route was not tested here. `universe:write`, `developer-product:write`, `game-pass:write`,
`ad.campaign:write`, the ban and notification scopes, and the secret and cloud-Luau scopes are the
ones `rbx-permissions` says never to bundle into a general request: name each and get a clear yes.

### Session management

| Tool | What it does |
|---|---|
| `list_roblox_studios` | Lists connected Studio instances with name, Studio instance ID, and place ID. |

### Present in this build but undocumented officially

| Tool | What it does |
|---|---|
| `generate_texture` | **Re-textures an existing** MeshPart or Model from `textPrompt` (optional `hintImage`; `model` `Fast` or `Quality`, where `Quality` supports only a single MeshPart), and **replaces the source in place**. Targets `instance_path`, or the current Studio selection when it is omitted. Duplicate the source first if the user may want the original |
| `segment_mesh` | Splits an existing MeshPart or Model into up to **5** named `parts` and inserts the result as a **new Model next to the source** (the source stays). Same `instance_path` / selection fallback |

> Treat these two as unsupported: they are not on the docs page, so they may change or vanish
> without a release note (`list_plugin_guis` / `capture_plugin_gui` did, between 2026-10-11 and
> 2026-10-17). Descriptions are from the live schemas of 2026-10-17 (unchanged 2026-10-21 and 2026-10-22);
> neither was run. The Studio **Texture Generator** page (rewritten 2026-10-16, extended
> 2026-10-20) describes the same two modes for the Studio tool: `Fast` gives 1K diffuse
> textures and `Quality` 4K PBR textures, and Ctrl/Cmd+Z undoes a result. Whether the MCP tool
> produces the same output, or can be undone the same way, was not checked; duplicate first.

### Known tool defect

> **`script_grep` line numbers need confirming.** Measured 2026-09-06: it placed a match at line
> 171 that `script_read` showed was 15 lines lower. On 2026-10-11 (Studio 0.742) two tests, a
> generated script and a Rojo-synced one, returned the exact line, so the trigger is unknown.
> Use `script_grep` to find *which* script
> holds a string, then `script_read` to find *where*. Do not feed a `script_grep` line number
> into an edit.

---

## Recommended Workflows

### 1. Read-Before-Write

```text
1. list_roblox_studios  →  get the studio_id, once, and reuse it deliberately
2. get_studio_state     →  confirm Edit is available (multi_edit needs it)
3. search_game_tree     →  find the relevant services / folders
4. script_search        →  locate the target script (≤10 fuzzy results)
5. script_read          →  read current source, with real line numbers
6. multi_edit           →  exact-match edits, one script per call
```

**Why:** `multi_edit` matches `old_string` verbatim, so an `old_string` guessed without a read
usually fails the whole call (a read is not required: an edit whose text does match succeeds,
tested 2026-10-11). And blind whole-script rewrites break references, discard
project conventions, and destroy work done outside the agent session.

### 2. Test-After-Change

```text
1. multi_edit            →  apply changes (Edit datamodel)
2. get_console_output    →  catch syntax / load errors before playing
3. start_stop_play       →  begin playtest
4. get_console_output    →  runtime errors and print output
5. screen_capture        →  visual check (optional)
6. start_stop_play       →  stop playtest
```

### 3. Debug Loop

```text
1. get_console_output    →  read the error and stack trace
2. script_read           →  read the offending script
3. execute_luau          →  query live state (datamodel_type: Server or Client)
4. start_stop_play       →  STOP the playtest first
5. multi_edit            →  apply the fix (Edit datamodel only)
6. start_stop_play       →  restart and confirm via get_console_output
```

> **Step 4 is not optional.** `multi_edit` accepts `datamodel_type: "Edit"` and nothing else, so
> attempting to patch a script mid-playtest fails. Earlier versions of this file showed
> `multi_edit` inside the playtest loop with no such caveat. Inspecting live state with
> `execute_luau` in `Server` / `Client` *is* fine — that is the point of step 3.

### 4. Legacy Pattern Detection

```text
1. script_grep("spawn(")     →  find legacy spawn calls (≤50 matches, unreliable line numbers)
2. script_grep("wait(")      →  …and legacy wait
3. script_grep("delay(")     →  …and legacy delay
4. script_read (each hit)    →  confirm the real location and context
5. multi_edit                →  one call per script, replace_all where the symbol is unambiguous
6. start_stop_play           →  verify nothing broke
```

> `script_grep("wait(")` also matches `task.wait(`. Read before replacing, or you will "migrate"
> code that was already correct.

### 5. Read Roblox's Own Skill First

For debugging, device-form-factor UI testing, MicroProfiler performance analysis, scene
analysis, Open Cloud, or a permission error, call `skill` with the matching `rbx-*` name before
hand-rolling an approach. It ships with Studio and is cheaper than rediscovering the same API
surface. Run what it tells you before you rely on it: see the table under *Documentation and skills*.

---

## Best Practices

### General

- **One logical change per `multi_edit` call.** Easier to verify, easier to roll back.
- **Always read before writing** — with `multi_edit` this is a hard requirement, not etiquette.
- **Check `get_studio_state` before anything that takes `datamodel_type`.** It tells you both
  the play state and which datamodels currently exist.
- **Pin the `studio_id` deliberately.** Resolve it once via `list_roblox_studios`, confirm it is
  the place you mean, and reuse it. Nothing will warn you that you edited the wrong open place.

### Performance

- **Batch edits to the same script** into one `multi_edit` call; each round-trip costs latency.
  Across different scripts you have no choice but separate calls.
- **Use `http_get`'s `query`** instead of pulling whole doc pages into context.
- **Avoid large `execute_luau` loops** that create thousands of Instances at once — Studio may
  freeze. Batch with `task.wait()` yields.

### Safety

Summary only — the full threat model, including what this skill cannot enforce, is in
`references/agent-safety.md`.

- **`execute_luau` is the command bar.** Plugin-level privilege, no timeout, no undo guarantee,
  no dry-run. Treat every call as a write to the user's place.
- **Never delete services** (`Workspace`, `ReplicatedStorage`, …) and never
  `game:ClearAllChildren()`. What Studio does then has not been tested here; do not find out on a
  real place.
- **Confirm the target place before the first mutation**, especially with several Studio windows
  open.
- **Don't overwrite work you have not read.** The developer may have been editing outside your
  session.

### Debugging

- **`execute_luau` returns its result** — use the return value first; add `print()` when you
  want progressive output during long-running work, then read `get_console_output`.
- **Check `get_console_output` after every change**, even when nothing looks broken — warnings
  and deprecation notices are easy to miss.
- **Use `inspect_instance`** rather than guessing property values. Common gotcha: a Part's
  `Anchored` defaulting to `false`.

---

## Corrections Log

Errors that were in this file and are now fixed. Kept visible so an agent that remembers an old
version does not reintroduce them.

| Wrong claim | Reality | Verified |
|---|---|---|
| `run_as_job` is a tool | **No such tool**, in the docs or in the live build. Async is a per-tool `async: true` argument that returns a `jobId`; `wait_job_finished` consumes that id. v2.7.0 introduced this error while "adding real tools". | Official docs page + live tool list, 2026-09-25 |
| `multi_edit` edits multiple scripts, taking `{scriptPath, newSource}` | **One script per call.** `file_path` + `edits[{old_string, new_string, replace_all}]`, sequential exact-match replacements, atomic, `className` to create. | Live schema + official docs |
| `multi_edit` works during a playtest | `datamodel_type` enum is **`Edit` only**. | Live schema |
| "MCP tools do not return Luau values directly" | `execute_luau` **returns the result or the error**. | Live schema + official docs |
| `upload_image` uploads a local image file | It uploads a **batch from HTTP(S) URLs** and returns an imagePath→assetId map. Local files go through `store_image` → `IMAGEID_` URI, ≤5 MB, png/jpg/jpeg. | Live schemas |
| `http_get` fetches any URL from Studio | **Allowlisted** to Roblox docs domains, and the URL must end in `.md` or be `llms.txt`. `llms-full.txt` and `openapi.json` are rejected. | Live schema |
| `search_asset` searches "the marketplace / Toolbox" | **Creator Store + Creator Inventory**, with type / price / tag / scope filters. | Official docs |
| 29 tools | **26 documented**, **28 in this build** (+`generate_texture`, +`segment_mesh`, both undocumented). | Official docs + live tool list |
| 28 tools (2026-10-17 to 2026-10-22) | **31 on 2026-10-29** (Studio 0.745): +`list_skills`, +`create_skill`, +`edit_skill`. | Live tool list |
| 31 tools (2026-10-29) | **34 on 2026-11-05** (Studio 0.746): +`generate_scene`, +`generate_avatar`, +`auto_setup_avatar`. | Live tool list |
| 34 tools (2026-11-05) | **35 on 2026-11-07** (Studio 0.746.0.7461269): +`open_cloud_invoke`. | Live tool list |
| `execute_luau` has only plugin privilege to think about | HTTP goes through the Assistant allowlist and data stores through the **Save & load data** scopes, in addition to plugin privilege. | Run 2026-11-07 + docs |
| Roblox's `rbx-*` skills are "more current than this skill" | They go deeper, and some steps in them are stale. Run them. | Run 2026-11-07 |
| `skill` and `subagent` absent from this file | Both are real and officially documented. Roblox ships 7 first-party `rbx-*` skills that partly supersede hand-rolled approaches (9 on 2026-10-29, 14 on 2026-11-05, 17 on 2026-11-07). | Official docs + live schemas |
| `set_active_studio` is a tool | Does not exist. Targeting is per call via `studio_id`. (Corrected in v2.7.0, kept here as a guard.) | Official docs |
