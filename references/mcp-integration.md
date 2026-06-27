# Roblox Studio MCP Integration

> **Source:**
> https://create.roblox.com/docs/ai/build ·
> https://create.roblox.com/docs/studio

> How to use the Roblox_Studio MCP server to interact with Roblox Studio from an AI agent.

## Table of Contents

1. [Overview](#overview)
2. [Tool Reference](#tool-reference)
3. [Recommended Workflows](#recommended-workflows)
4. [Best Practices](#best-practices)

---

## Overview

The **Roblox_Studio MCP server** is **built-in natively** to Roblox Studio as of
mid-2026. It exposes Studio functionality through the Model Context Protocol,
letting AI agents read, write, and test game code without the developer manually
copy-pasting between the agent and Studio.

> **Migration note:** The previous external Rust binary (`studio-rust-mcp-server`
> on GitHub) has been **archived**. You no longer need to install or run a
> separate process. All MCP functionality is now handled by the native server
> inside Studio.

**Setup:**

1. Open the **Assistant** widget in Roblox Studio.
2. Navigate to **"Manage MCP Servers"**.
3. Enable the **built-in MCP server**.

Tool names and functionality are **unchanged** from the external-server era —
existing agent code and workflows continue to work without modification.

**Key concepts:**

- Tools are **lazily loaded** — read the schema from
  `/Users/sayib/.gemini/antigravity/mcp/Roblox_Studio/<toolName>.json` before
  first use.
- Call tools via `call_mcp_tool` with server name `Roblox_Studio`.
- Studio must be open and the built-in MCP server enabled for calls to succeed.
- If multiple Studio windows are open, use `list_roblox_studios` /
  `set_active_studio` to target the correct one.
- **ScriptDebuggerService (beta):** Provides programmatic access to Studio's
  script debugger — set breakpoints, step through code, and inspect variables
  via MCP. Currently in beta; use `game:GetService("ScriptDebuggerService")` to
  access. Expect API changes before full release.
- **Studio Assistant Planning Mode:** Enables the Studio Assistant to generate
  and execute multi-step test plans automatically. Agents can leverage this for
  automated testing by triggering Planning Mode workflows through the Assistant
  widget. Useful for verifying complex game flows without manual playtesting.

---

## Tool Reference

### Reading & Inspecting

| Tool | Purpose | When to Use |
|---|---|---|
| `search_game_tree` | Search the Explorer / DataModel hierarchy by name or class | Understanding project structure, finding instances |
| `script_search` | Find scripts by name | Locating a script before reading it |
| `script_grep` | Search inside script source code for a pattern | Finding usages of a function, detecting legacy patterns |
| `script_read` | Read the full source of a script | Understanding existing code before modifying it |
| `inspect_instance` | Get all properties of an Instance | Debugging property values, checking configuration |
| `get_studio_state` | Get current Studio state (Editing, Playing, etc.) | Deciding whether to start/stop a playtest |
| `get_console_output` | Read the Output window | Checking for errors after a change or during playtest |

### Writing & Editing

| Tool | Purpose | When to Use |
|---|---|---|
| `execute_luau` | Run arbitrary Luau in the Studio command bar context | Testing snippets, querying game state, creating/modifying instances |
| `multi_edit` | Edit multiple scripts in a single call | Refactoring, renaming across files, batch updates |

**`execute_luau` notes:**

- Runs in the **Plugin** security context (server-side, edit mode).
- During a playtest (`start_stop_play`), code runs in the live DataModel.
- Use `print()` to return diagnostic values — output appears in `get_console_output`.
- Avoid infinite loops; there is no automatic timeout.

**`multi_edit` notes:**

- Accepts a list of `{ scriptPath, newSource }` entries.
- Always `script_read` first to understand current content before overwriting.
- Targets scripts by their full DataModel path
  (e.g., `ServerScriptService.GameManager`).

### Asset Management

| Tool | Purpose |
|---|---|
| `search_asset` | Search the Roblox marketplace / Toolbox for models, decals, audio, etc. |
| `insert_asset` | Insert a marketplace asset into the DataModel by asset ID |
| `upload_image` | Upload a local image file to Roblox (returns an asset ID) |

### AI Content Generation

| Tool | Purpose |
|---|---|
| `generate_mesh` | Generate a 3D mesh from a text prompt |
| `generate_procedural_model` | Generate a procedural model (trees, rocks, etc.) |
| `generate_material` | Generate a PBR material from a text prompt |

These tools return asynchronous jobs. Use `wait_job_finished` to poll completion.

### Playtesting & Input Simulation

| Tool | Purpose |
|---|---|
| `start_stop_play` | Start or stop a playtest session |
| `character_navigation` | Move the player character to a world position during playtest |
| `user_mouse_input` | Simulate mouse clicks / movement |
| `user_keyboard_input` | Simulate key presses |
| `screen_capture` | Capture a screenshot of the current viewport |
| `store_image` | Persist a captured image for later reference |

### Multi-Instance Management

| Tool | Purpose |
|---|---|
| `list_roblox_studios` | List all open Roblox Studio windows |
| `set_active_studio` | Switch the active Studio instance for subsequent calls |

---

## Recommended Workflows

### 1. Read-Before-Write

Always understand the existing code and structure before making changes.

```text
1. search_game_tree  →  find relevant services / folders
2. script_search     →  locate the target script(s)
3. script_read       →  read current source
4. multi_edit        →  apply changes with full context
```

**Why:** Blind overwrites break references to other scripts, miss existing
patterns the project relies on, and create merge conflicts.

### 2. Test-After-Change

Verify every change by running the game.

```text
1. multi_edit            →  apply code changes
2. get_console_output    →  check for immediate syntax/load errors
3. start_stop_play       →  begin playtest
4. get_console_output    →  check runtime errors / print output
5. screen_capture        →  visually verify (optional)
6. start_stop_play       →  stop playtest
```

### 3. Debug Loop

When a runtime error is reported or behavior is wrong:

```text
1. get_console_output        →  read the error message and stack trace
2. script_read               →  read the offending script
3. execute_luau              →  query live state (inspect variables, instances)
4. multi_edit                →  fix the issue
5. start_stop_play           →  restart playtest
6. get_console_output        →  confirm the fix
```

### 4. Legacy Pattern Detection

Use `script_grep` to scan for deprecated APIs before migrating:

```text
1. script_grep("spawn(")         →  find legacy spawn calls
2. script_grep("wait(")          →  find legacy wait calls
3. script_grep("delay(")         →  find legacy delay calls
4. script_read  (each result)    →  review context
5. multi_edit                    →  batch-replace with task.* equivalents
6. start_stop_play               →  verify nothing broke
```

---

## Best Practices

### General

- **One logical change per `multi_edit` call.** Smaller edits are easier to
  verify and roll back.
- **Always read before writing.** Use `script_read` so you can produce a
  correct, complete replacement — not a guess.
- **Check `get_studio_state` before playtesting.** If Studio is already playing,
  stop first or your `start_stop_play` call may toggle incorrectly.

### Performance

- **Batch related edits** into a single `multi_edit` call instead of making
  many sequential calls — each MCP round-trip has latency.
- **Avoid large `execute_luau` loops** that create thousands of Instances at
  once; Studio may freeze. Batch creation with `task.wait()` yields.

### Safety

- **Never delete services** (`Workspace`, `ReplicatedStorage`, etc.) via
  `execute_luau`. Destroying core services crashes Studio.
- **Don't overwrite scripts you haven't read.** You may destroy code the
  developer has been working on outside the agent session.
- **Treat `execute_luau` as a command bar** — it has full plugin-level access.
  Avoid destructive operations like `game:ClearAllChildren()`.

### Debugging

- **Print liberally** in `execute_luau` — it is the primary way to get values
  back from Studio since MCP tools do not return Luau values directly.
- **Check `get_console_output` after every change**, even if there is no
  visible error — warnings and deprecation notices are easy to miss.
- **Use `inspect_instance`** to verify property values rather than guessing.
  Common gotcha: a Part's `Anchored` property defaulting to `false`.
