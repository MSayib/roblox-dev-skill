# Roblox Studio MCP Integration

> **Primary source (re-verified 2026-09-25):**
> https://create.roblox.com/docs/studio/mcp — raw markdown at
> `https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/studio/mcp.md`
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
  `execute_luau` accepts all three, but **`multi_edit` accepts `Edit` only** — you cannot edit
  scripts through MCP while a playtest is running.

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
  the file, and mind the commas — invalid JSON fails silently at load.
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

**Counts, stated precisely.** The official docs page lists **26 tools**. The build observed in
this session (2026-09-25) exposes **28** — those 26 plus `generate_texture` and `segment_mesh`,
which are present but undocumented. Tool sets move; when a call fails with an unknown-tool
error, list what your host actually exposes instead of trusting this table.

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
- In `Edit` it operates on the saved place. In `Client` / `Server` it operates on the live
  playtest DataModel, which only exists while a playtest is running.
- **It does return values.** Earlier versions of this file claimed MCP tools could not return
  Luau values and that `print()` was the only way out — that was wrong. `print()` is still
  useful for *incremental* output during long work, which surfaces via `get_console_output`.
- There is **no automatic timeout**. An infinite loop hangs Studio.

### Data model exploration

| Tool | What it does |
|---|---|
| `search_game_tree` | Explores the instance hierarchy as a flat JSON array; filters by path, instance type, and keywords, with configurable depth. |
| `inspect_instance` | Full detail on one instance: readable properties, custom attributes, and a summary of children/descendants. |
| `subagent` | Launches a specialized subagent for autonomous multi-step work. |

**`subagent` types are build-dependent — read the schema, do not hardcode.** The official docs
name `explore` and `playtest`; the build in this session advertised `explore`, `screen_capture`,
and `unit_test`. A subagent returns one final text summary and cannot be conversed with or
nested.

### Playtesting

| Tool | What it does |
|---|---|
| `get_studio_state` | Current play state **and which datamodel types are available**. Call this before anything that takes `datamodel_type`. |
| `start_stop_play` | Starts or stops playtesting. |
| `get_console_output` | Reads the Studio output log. |
| `screen_capture` | Captures the viewport and returns image data; optionally takes a custom camera position and look-at target. |

### Player input simulation

| Tool | What it does |
|---|---|
| `character_navigation` | Moves the player character to a position **or an instance path**, with a configurable speed multiplier. |
| `user_keyboard_input` | Sends ordered keyboard actions: key down, key up, key press, text input, or wait. Can target a specific UI instance. |
| `user_mouse_input` | Sends ordered mouse actions: move, click, button down/up, scroll, or wait. Can target instances or screen coordinates. |

### Assets and content generation

| Tool | What it does |
|---|---|
| `search_asset` | Searches the **Creator Store** (public) and **Creator Inventory** (user / group / universe), filterable by asset type, price, tags, and scope. |
| `insert_asset` | Inserts an asset by numeric asset ID — models, meshes, images, audio, video, animations, packages. |
| `generate_mesh` | Generates a textured 3D mesh from a text prompt. |
| `generate_procedural_model` | Builds an object from primitive parts (blocks, spheres, cylinders, wedges) as a `ProceduralModel` with configurable attributes; accepts reference images and custom part schemas. |
| `generate_material` | Generates a material variant; returns the base material plus the variant name to apply. |
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

**`http_get` is allowlisted, not a general fetcher.** Permitted prefixes: `create.roblox.com/docs`
(including `/reference/engine`, `/cloud`, `/performance-optimization`) and
`github.com/Roblox/libmp`. **The URL must end in `.md` or be `llms.txt`** — anything else is
rejected, which notably includes `llms-full.txt` and `openapi.json`. For those, and for any
non-Roblox URL, use the host's own fetch tool or `curl`.

Using `query` is the token-efficient path: it returns only matching sections with context rather
than the whole page.

**First-party skills exposed by the `skill` tool in this build (2026-09-25):**
`rbx-create-skill`, `rbx-debug`, `rbx-device-simulator-lua`, `rbx-docs-search`,
`rbx-perf-profiling`, `rbx-scene-analysis`, `rbx-unit-test`. These are Roblox's, shipped inside
Studio, and they are **narrower and more current than this skill on their specific topics** —
prefer `skill("rbx-debug")` for breakpoint work, `skill("rbx-perf-profiling")` for MicroProfiler
and LibMP analysis, and `skill("rbx-scene-analysis")` for SceneAnalysisService. Use this
repository's references for architecture, security, and Luau standards, which they do not cover.

### Session management

| Tool | What it does |
|---|---|
| `list_roblox_studios` | Lists connected Studio instances with name, Studio instance ID, and place ID. |

### Present in this build but undocumented officially

| Tool | What it does |
|---|---|
| `generate_texture` | Generates a texture (companion to `generate_material` / `generate_mesh`). |
| `segment_mesh` | Segments a mesh into parts. |

> Treat these two as unsupported: they are not on the docs page, so they may change or vanish
> without a release note.

### Known tool defect

> **`script_grep` line numbers are unreliable.** Measured 2026-09-06: it placed a match at line
> 171 that `script_read` showed was 15 lines lower. Use `script_grep` to find *which* script
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

**Why:** `multi_edit` matches `old_string` verbatim. Without a read, the call does not merely
risk a bad edit — it fails outright. And blind whole-script rewrites break references, discard
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

### 5. Prefer Roblox's Own Skill First

For debugging, device-form-factor UI testing, MicroProfiler performance analysis, or scene
analysis, call `skill` with the matching `rbx-*` name before hand-rolling an approach. It is
first-party, versioned with Studio, and cheaper than rediscovering the same API surface.

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
- **Never delete services** (`Workspace`, `ReplicatedStorage`, …). Destroying core services
  crashes Studio. Never `game:ClearAllChildren()`.
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
| `skill` and `subagent` absent from this file | Both are real and officially documented. Roblox ships 7 first-party `rbx-*` skills that partly supersede hand-rolled approaches. | Official docs + live schemas |
| `set_active_studio` is a tool | Does not exist. Targeting is per call via `studio_id`. (Corrected in v2.7.0, kept here as a guard.) | Official docs |
