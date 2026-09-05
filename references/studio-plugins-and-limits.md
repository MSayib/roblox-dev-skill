# Studio Plugins & Engine Limits

> **Source:**
> https://create.roblox.com/docs/reference/engine/classes/HttpService ·
> https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService ·
> https://create.roblox.com/docs/studio/plugins ·
> plus direct empirical measurement in Roblox Studio (2026-08-06)
>
> Every number below marked **measured** was produced by running code in a live
> Studio session, not read from documentation. Where docs and measurement
> disagree, the measurement is noted as such.

---

## 1. Script source size — there are TWO limits

**Measured 2026-08-06.** These differ by an enormous margin, and confusing them
leads to either data loss or needlessly conservative caps.

| Path | Limit |
|---|---|
| `Script.Source = x` (direct assignment) | **199,999 bytes.** 200,000 is rejected |
| `ScriptEditorService:UpdateSourceAsync` | **No limit found up to 64 MiB** |

Exact boundary on direct assignment: 199,998 ✓ · 199,999 ✓ · 200,000 ✗ · 200,001 ✗

Rejection message:

```
Unable to assign property Source. Provided string length (200000)
is greater than or equal to max length (200000)
```

`UpdateSourceAsync` stored 8 / 16 / 32 / 64 MiB intact (verified by checking
first and last characters); 64 MiB completed in 0.48 s.

### Which to use

Prefer `UpdateSourceAsync` for programmatic edits regardless of size — it also
avoids clobbering a script the user currently has open in the editor:

```lua
local ScriptEditorService = game:GetService("ScriptEditorService")

ScriptEditorService:UpdateSourceAsync(target, function(oldSource)
    return transform(oldSource)
end)
```

> [!WARNING]
> **Unverified:** whether source above 199,999 bytes survives place
> *serialization* (save → reload). The measurement above covers only the
> in-memory DataModel. Treat large generated sources as a data-loss risk until
> a save/reload round-trip is tested.

---

## 2. Plugins are exempt from "Allow HTTP Requests"

**Measured 2026-08-06.** A plugin made successful `HttpService:GetAsync` calls
while `HttpService.HttpEnabled == false` on an unpublished place (`PlaceId == 0`).

This matters because **Experience Settings requires the place to be published**,
so a plugin that needed the setting would be unusable on local files. It doesn't.

### The misleading error

When the request budget is exhausted, Studio raises:

```
Number of requests exceeded limit
```

and may append the generic hint *"Go to Experience Settings and turn on Allow
HTTP requests."* That hint is **wrong for plugins** — the real cause is the rate
limit in §3. Do not send users to a settings page they may not even have.

---

## 3. HttpService rate limit is shared across the Studio session

Documented: **500 requests/minute** for external HTTP, and a separate
**2,500/minute** for Open Cloud requests.

**Measured consequence:** this budget is shared by *everything* in the session —
every plugin plus the game context. A burst of test requests from the command
bar starved a running plugin (Rojo, or any connector plugin) and knocked it
offline with `Number of requests exceeded limit`.

This is the usual explanation for "my plugin randomly disconnects":

| Client | Requests/minute |
|---|---|
| A plugin polling every 2 s | 30 |
| Rojo (sync + long-poll) | varies; spikes on large syncs |
| A plugin long-polling at ~20 s | **3** |

### Design rules for connector plugins

1. **Long-poll instead of fixed-interval polling.** A ~20 s held request cuts
   request rate by an order of magnitude.
2. **Retry with exponential backoff — never disconnect on the first failure.**
   The budget is shared, so transient exhaustion is normal, not fatal. A plugin
   that tears down its connection on any failed poll will drop out permanently
   until the user reconnects by hand.
3. **Distinguish "retrying" from "disconnected" in the UI.**

---

## 4. HttpService response handling

**Measured 2026-08-06, from plugin context:**

| Test | Result |
|---|---|
| 1 / 4 / 16 MB raw JSON | received intact (16 MB in 0.09 s) |
| 32 MB raw JSON | **33,554,423 bytes intact**, 0.16 s — no truncation |
| 16 MB sent with `Content-Encoding: gzip` | **16,777,207 bytes returned already decompressed** |

Two consequences:

- **No practical response size ceiling** up to at least 32 MB.
- **Studio transparently decompresses `Content-Encoding: gzip`.** A pure-Lua
  inflate library (zzlib and friends) is unnecessary for data you control the
  server for. Compress at the *transport* layer and the runtime handles it.

Application-layer gzip forces base64 to survive JSON, costing 33% overhead plus
pure-Lua inflate CPU — all avoidable.

---

## 5. Local plugin installation

Studio loads plugins from the local plugins directory:

| OS | Path |
|---|---|
| macOS | `~/Documents/Roblox/Plugins` |
| Windows | `%LOCALAPPDATA%\Roblox\Plugins` |

**Measured:** a plain `.lua` file placed there loads and runs as a plugin.
A `.luau` file placed there did **not** load in the same session — prefer
`.lua`, `.rbxm`, or `.rbxmx`.

Resolve the path programmatically rather than hardcoding it. Lune exposes
`studioPluginPath` (along with `studioApplicationPath` and `studioContentPath`)
via `@lune/roblox`.

Studio must be restarted to pick up a newly added plugin file.

---

## 6. Editing a place safely from a plugin

Patterns worth copying for any plugin that mutates a user's place:

```lua
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local recording = ChangeHistoryService:TryBeginRecording("Replace asset IDs")
local ok, err = pcall(applyChanges)
if ok then
    ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
else
    ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
    warn("[Plugin] change aborted:", err)
end
```

- **Wrap every mutation in a recording** so the whole operation is one Ctrl+Z.
- **Cancel, don't commit, on error** — a half-applied change is worse than none.
- **Swap MeshParts properly.** `MeshId` is not assignable at runtime; build a
  replacement with `AssetService:CreateMeshPartAsync`, transfer properties,
  attributes, children, tags and joints, then reparent and destroy the original.
- **Gate on `RunService:IsEdit()`** if the plugin has no business running during
  playtest.
- **Persist place identity** with an attribute on `game` (e.g. a GUID from
  `HttpService:GenerateGUID(false)`), set inside a recording. It survives in the
  saved file and survives `PlaceId == 0` on unpublished places.

### Scanning a place

`game:QueryDescendants` takes a class filter string and is markedly faster than
walking `GetDescendants()` with `IsA` checks:

```lua
local found = game:QueryDescendants(
    "Sound, Animation, MeshPart, Script, LocalScript, ModuleScript, IntValue, StringValue, NumberValue"
)
```

Skip anything under `PluginGuiService` — that is other plugins' UI, not the
user's place.

---

## 7. Reading and writing place files outside Studio

The whole ecosystem sits on **`rbx-dom`** (Rust): `rbx_binary`, `rbx_dom_weak`,
`rbx_xml`, `rbx_reflection`, `rbx_reflection_database`. Rojo and Lune both build
on it.

| Tool | Use for |
|---|---|
| **Lune** (`@lune/roblox`) | Scripted read/write in Luau: `deserializePlace`, `deserializeModel`, `serializePlace`, `serializeModel`, `getReflectionDatabase`, `getAuthCookie`, `studioPluginPath` |
| **rbx-dom** crates | Native Rust integration |
| **Rojo** | Project sync and `.rbxm`/`.rbxl` builds |
| ~~remodel~~ | **Archived** — superseded by Lune |
| `robloxapi/rbxfile` (Go) | Works, but unmaintained since 2023 — see fidelity note below |

### Fidelity depends on the reflection database

Per the `rbx_binary` README: it embeds a reflection database, and **when that
database is outdated** you can get properties serialized under the wrong name,
properties with incorrect defaults, and data types newer than the crate release
that cannot be (de)serialized at all. The fix is always to update the crate.

So parser freshness is a correctness requirement, not a preference. A parser
frozen years ago structurally cannot know property types Roblox added since.
