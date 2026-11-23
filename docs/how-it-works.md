# How the skill works

[← README](../README.md)

## Repository layout

```
roblox-dev-skill/
├── SKILL.md                          # Main skill file (router + standards + workflows)
├── metadata.json                     # Knowledge update tracking (timestamps, versions)
├── CHANGELOG.md                      # Full version history
├── README.md                         # Overview; links to docs/
├── install.sh                        # Installer: macOS, Linux, WSL, Git Bash (bash 3.2+)
├── install.ps1                       # Installer: Windows PowerShell 5.1+ / PowerShell 7
├── install.cmd                       # Installer: Windows CMD (launches install.ps1)
├── references/                       # Deep-dive reference guides (14)
│   ├── worked-examples.md            # End-to-end agent sequences + verification + non-goals
│   ├── luau-fundamentals.md          # Luau language, types, naming, style
│   ├── project-structure.md          # Architecture, Rojo, Script Sync, IAS
│   ├── datastore-persistence.md      # DataStoreService, ProfileStore, MemoryStoreService
│   ├── networking.md                 # RemoteEvents, client-server, BindableEvent caveats
│   ├── security-hardening.md         # Anti-exploit, BanAsync, Server Authority (player→server)
│   ├── agent-safety.md               # Agent→Studio trust boundary, destructive MCP ops
│   ├── performance-optimization.md   # Memory, Parallel Luau, RunService frame pipeline
│   ├── mcp-integration.md            # Roblox Studio MCP tools, real signatures and limits
│   ├── ui-systems.md                 # GUI, UIShadow, StyleQuery, UIFlexItem, StyleSheet
│   ├── legacy-migration.md           # Deprecated APIs, RunService events, Scoped UserIds
│   ├── monetization.md               # Transfers API, Subscriptions, game passes
│   ├── file-formats-and-assets.md    # rbxl/rbxm formats, ZSTD/LZ4, MeshContent, importing
│   └── studio-plugins-and-limits.md  # Plugins, Script.Source limits, engine/HttpService limits
├── evals/
│   └── evals.json                    # Prompts + what a correct answer must do
├── docs/                             # Installation, RobloxDocs, testing, this file
└── tools/
    ├── robloxdocs/                   # RobloxDocs scripts the installer copies to ~/RobloxDocs/scripts
    └── skill-test/                   # Static + Studio runtime tests for every example (docs/testing.md)
```

The installer copies `SKILL.md`, `metadata.json`, `LICENSE`, `README.md`, `CHANGELOG.md`,
`references/` and `docs/` (and keeps its own `install.sh` next to the payload); `evals/` and `tools/`
stay in the repository. A manual `git clone` or a link to a checkout gives the agent the whole
repository instead, which works the same but is larger.


## Auto-Trigger
The skill automatically activates when you mention Roblox-related topics:
- `Roblox`, `Luau`, `Roblox Studio`, `DataStoreService`, `RemoteEvent`
- `ProfileStore`, `Rojo`, `rbxl`, `rbxlx`, `rbxm`, `game pass`
- `fbx`, `obj`, `gltf`, `import/export model`, `Universal Importer`
- Studio MCP tools & skills: `list_roblox_skills`, `get_roblox_skill`, `rbx-*`, `execute_luau`,
  `multi_edit`, `open_cloud_invoke`, `generate_mesh`, `generate_procedural_model`,
  `generate_animation`, `store_image`, `start_stop_play`, `save_place`
- Any Roblox Engine API reference

## Lookup Priority
```
1. Reference files (Routing Table in SKILL.md)    ← curated knowledge
2. Studio `list_roblox_skills`/`get_roblox_skill`  ← Studio's 17 built-in rbx-* recipes (when MCP connected)
3. ~/RobloxDocs/RobloxAPI/classes/<Name>.json      ← local split JSON
4. Web docs (create.roblox.com/docs/en-us/*.md)    ← live Roblox official
5. robloxapi.github.io/ref                         ← visual API browser
6. context7 MCP                                    ← fallback
```

## With Roblox Studio MCP

The [Studio MCP server is built into Roblox Studio](https://create.roblox.com/docs/studio/mcp) —
enable it via **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**, then connect
your client with quick connect. (The old standalone `studio-rust-mcp-server` binary is
**archived**; you do not need it.)

Studio **0.748.0.7481526** exposes **39 tools** (**30** documented on `studio/mcp.md`), letting
the agent read/edit scripts, run Luau, explore the game tree, generate 3D meshes, procedural models,
materials, textures, and animations (`store_image` + `generate_*` + `wait_job_finished`), drive
playtests with simulated input and captures (`start_stop_play`, `character_navigation`,
`user_keyboard_input`, `screen_capture`), call Open Cloud (`open_cloud_invoke`), and save the place
(`save_place`).

**Two-layer skill model:** Studio also ships 17 first-party `rbx-*` skills accessed via
`list_roblox_skills` and `get_roblox_skill` (older builds: `list_skills` / `skill`). Those `rbx-*`
skills own Studio-tool procedures (debugger breakpoints, MicroProfiler, heap snapshots, network/device
simulators, streaming conversion, asset import); `roblox-dev-skill` owns `--!strict` Luau,
server-authoritative security, architecture, engine capability truth (`NotScriptable` /
`PluginOrOpenCloud`), real tool constraints (`multi_edit` in `Edit` only, `execute_luau` returns
values, `http_get` allowlist, per-call `studio_id`, `wait_job_finished` 45s cap), and a cross-check
table of stale steps inside Roblox's own `rbx-*` skills.

> ⚠️ Roblox's own warning: *"MCP clients can read and modify content in your open Roblox places.
> Make sure to only connect clients you trust."* There is no dry-run and no reliable undo — read
> [`references/agent-safety.md`](../references/agent-safety.md) before pointing an agent at a place
> you care about.

## Knowledge coverage

Each row says when that file's content was last verified — not that it is current today. Since
2.16.0 every code example in every file is also type-checked and run in Studio on each release,
and since 2.17.0 every high-risk statement in the prose of `SKILL.md` and `references/` is in a
claims register with how it was verified ([testing.md](testing.md), [claims.md](claims.md)). The
pages in `docs/` and the README are not in the register; they were checked by hand on 2026-10-17,
2026-10-21, 2026-10-22, 2026-10-29, 2026-11-05, and 2026-11-23.

| Topic | Status | Reference File |
|-------|--------|---------------|
| Luau language (strict mode, types, generics, `if local` / `LuauModularity` betas) | ✅ **Luau 0.748**, claims checked 2026-11-23 in Studio 0.748 (`LuauCodegenRuntimeFeedback`/`LuauPromoteProto` active, `integer` removed, `buffer.readvector*` nil in Studio) | `luau-fundamentals.md` |
| Project architecture (services, Rojo, IAS, Script Sync, `ConfigService`) | ✅ claims checked 2026-11-23 (`get_roblox_skill` refs updated; IAS / `ConfigService` verified) | `project-structure.md` |
| DataStore + ProfileStore + **MemoryStoreService** | ✅ claims checked 2026-10-11 (limits measured) | `datastore-persistence.md` |
| Client-Server networking + BindableEvent caveats + **text chat / platform-integrated chat** + **teleports** (`ForcePublicServer`, Studio teleport test) | ✅ claims checked 2026-11-23 (`0.748` teleport fields & docs checked) | `networking.md` |
| Security — player→server (BanAsync, server authority, **device trust**, exploits, script capabilities) | ✅ claims checked 2026-11-23 (`0.748` anchor fix + capability checks) | `security-hardening.md` |
| Safety — agent→Studio (destructive MCP ops, `save_place`, `submit_feedback`, `generate_*`, prompt injection) | ✅ claims checked 2026-11-23 | `agent-safety.md` |
| Worked examples (build / debug / migrate / verify / refuse / sell / migrate data / bind input / concept-image-to-3D + playtest / `rbx-*` skill routing) | ✅ **updated 2026-11-23** with Studio 0.748 workflows & TOC | `worked-examples.md` |
| Performance (Parallel Luau, **RunService pipeline**, **thick casts**, `SceneAnalysisService` all-7 methods, `EditableMesh:AddFace`, plugin-only fidelity/streaming) | ✅ claims checked 2026-11-23 in Studio 0.748 | `performance-optimization.md` |
| MCP integration (30 documented tools / 39 observed in 0.748; 17 first-party `rbx-*` skills audited, generative & playtest workflows) | ✅ **re-verified 2026-11-23** against `studio/mcp.md` + live Studio 0.748.0.7481526 | `mcp-integration.md` |
| UI (**UIFlexItem**, **StyleSheet/StyleRule**, StyleQuery, UIShadow, UIGradient modes, `SelectionGained` direction, `ParticleEmitter2D`, **`Color3` contrast**) | ✅ claims checked 2026-11-23 in Studio 0.748 | `ui-systems.md` |
| Legacy migration (RunService events, **0.746–0.748 additions/removals**, per-release API tables) | ✅ claims checked 2026-11-23 against dumps 0.723–0.748 and Studio 0.748 | `legacy-migration.md` |
| Studio plugins, `Script.Source` limits, engine limits | ✅ measured Aug 2026, source limits re-measured 2026-10-11 | `studio-plugins-and-limits.md` |
| Monetization (Transfers, **Subscriptions**, `GetPassOwnershipAsync`) | ✅ claims checked 2026-11-23 (`get_roblox_skill` + TOC anchor fixes) | `monetization.md` |
| File formats (**ZSTD/LZ4**, **MeshContent**, importing, MCP generation pointer) | ✅ claims checked 2026-11-23 (TOC + `rbx-import-asset` pointer) | `file-formats-and-assets.md` |
