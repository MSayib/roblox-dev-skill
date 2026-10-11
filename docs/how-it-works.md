# How the skill works

[← README](../README.md)

## Repository layout

```
roblox-dev-skill/
├── SKILL.md                          # Main skill file (router + standards + workflows)
├── metadata.json                     # Knowledge update tracking (timestamps, versions)
├── CHANGELOG.md                      # Full version history
├── README.md                         # This file
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

The installed skill contains only `SKILL.md`, `metadata.json`, `references/` and the license/docs —
`evals/`, `tools/` and the installers stay in the repository.


## Auto-Trigger
The skill automatically activates when you mention Roblox-related topics:
- `Roblox`, `Luau`, `Roblox Studio`, `DataStoreService`, `RemoteEvent`
- `ProfileStore`, `Rojo`, `rbxl`, `rbxlx`, `rbxm`, `game pass`
- `fbx`, `obj`, `gltf`, `import/export model`, `Universal Importer`
- Any Roblox Engine API reference

## Lookup Priority
```
1. Reference files (Routing Table in SKILL.md)    ← curated knowledge
2. ~/RobloxDocs/RobloxAPI/classes/<Name>.json      ← local split JSON
3. Web docs (create.roblox.com/docs/en-us/*.md)    ← live Roblox official
4. robloxapi.github.io/ref                         ← visual API browser
5. context7 MCP                                    ← fallback
```

## With Roblox Studio MCP

The [Studio MCP server is built into Roblox Studio](https://create.roblox.com/docs/studio/mcp) —
enable it via **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**, then connect
your client with quick connect. (The old standalone `studio-rust-mcp-server` binary is
**archived**; you do not need it.)

With it connected, the agent can read and write scripts in Studio, run Luau, explore the game
tree, drive playtests, read console output, and capture screenshots. This skill supplies the
part that is easy to get wrong: the **real** tool signatures and their limits —
`multi_edit` edits *one* script per call with exact-string matching and works in the `Edit`
datamodel only, `execute_luau` returns its result, `http_get` is allowlisted to Roblox docs URLs
ending in `.md`, and every call takes a `studio_id` that nothing will double-check for you.

> ⚠️ Roblox's own warning: *"MCP clients can read and modify content in your open Roblox places.
> Make sure to only connect clients you trust."* There is no dry-run and no reliable undo — read
> [`references/agent-safety.md`](references/agent-safety.md) before pointing an agent at a place
> you care about.

## Knowledge coverage

Each row says when that file's content was last verified — not that it is current today. Since
2.16.0 every code example in every file is also type-checked and run in Studio on each release
([testing.md](testing.md)).

| Topic | Status | Reference File |
|-------|--------|---------------|
| Luau language (strict mode, types, generics, `if local` beta) | ✅ **Luau 0.742** | `luau-fundamentals.md` |
| Project architecture (services, Rojo, IAS) | ✅ **Oct 2026 (0.741)** | `project-structure.md` |
| DataStore + ProfileStore + **MemoryStoreService** | ✅ Aug 2026 | `datastore-persistence.md` |
| Client-Server networking + BindableEvent caveats | ✅ Aug 2026 | `networking.md` |
| Security — player→server (BanAsync, server authority, exploits, script capabilities) | ✅ **Oct 2026** | `security-hardening.md` |
| Safety — agent→Studio (destructive MCP ops, injection from place content) | ✅ Sep 2026 | `agent-safety.md` |
| Worked examples (build / debug / migrate / verify / refuse / sell / migrate data / bind input) | ✅ **Oct 2026: every Verification section run in Studio 0.742** | `worked-examples.md` |
| Performance (Parallel Luau, **RunService pipeline**, plugin-only fidelity/LOD/streaming settings) | ✅ **Oct 2026 (0.742, tested in Studio)** | `performance-optimization.md` |
| MCP integration (26 documented tools / 28 observed) | ✅ **re-verified 2026-09-25** against the official docs page + live schemas | `mcp-integration.md` |
| UI (**UIFlexItem**, **StyleSheet/StyleRule**, StyleQuery) | ✅ Aug 2026 | `ui-systems.md` |
| Legacy migration (RunService events, **0.742 additions**, per-release API tables) | ✅ **Oct 2026 (0.742)** | `legacy-migration.md` |
| Studio plugins, `Script.Source` limits, engine limits | ✅ measured Aug 2026 | `studio-plugins-and-limits.md` |
| Monetization (Transfers, **Subscriptions**) | ✅ Aug 2026 | `monetization.md` |
| File formats (**ZSTD/LZ4**, **MeshContent**, importing) | ✅ Aug 2026 | `file-formats-and-assets.md` |
