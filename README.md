# 🎮 Roblox Dev Skill — AI Coding Assistant for Roblox Development

An expert-level AI skill for Roblox game development with Luau. Designed for
[Antigravity IDE](https://antigravity.dev), [Claude Code](https://claude.ai),
and any AI coding assistant that supports the Skills format.

> **Version:** 2.5.0 | **Engine Version:** v735+ (0.735.0.7351131) | **Knowledge Status:** August 2026 Current

## What Is This?

A structured knowledge base that transforms your AI coding assistant into a
**Roblox development expert**. When you mention anything Roblox-related, the skill
auto-triggers and provides the AI with deep, accurate, research-verified knowledge
about the Roblox platform.

### Key Features
- 🧠 **5,800+ lines** of curated Roblox development knowledge across 11 reference files
- 📂 **Local-first API lookup** — pre-split `~/RobloxDocs/` JSON files (845× more token-efficient than full dump)
- 🔄 **Self-updating** — built-in obsolescence detection + background auto-update
- 🎯 **Smart routing** — automatically selects the right reference based on your intent
- 🔌 **MCP integration** — works with the official Roblox Studio MCP server
- 🛡️ **Security-first** — server authority, input validation, anti-exploit patterns
- 📚 **Migration-aware** — guides you through deprecated APIs and breaking changes
- ⚡ **Multi-fallback** — local JSON → web docs → context7 MCP

## Directory Structure

```
roblox-dev-skill/
├── SKILL.md                          # Main skill file (router + standards + workflows)
├── metadata.json                     # Knowledge update tracking (timestamps, versions)
├── README.md                         # This file
├── references/                       # Deep-dive reference guides
│   ├── luau-fundamentals.md          # Luau language, types, naming, style
│   ├── project-structure.md          # Architecture, Rojo, Script Sync, IAS
│   ├── datastore-persistence.md      # DataStoreService, ProfileStore, MemoryStoreService
│   ├── networking.md                 # RemoteEvents, client-server, BindableEvent caveats
│   ├── security-hardening.md         # Anti-exploit, BanAsync, Server Authority
│   ├── performance-optimization.md   # Memory, Parallel Luau, RunService frame pipeline
│   ├── mcp-integration.md            # Roblox Studio MCP tools and workflows
│   ├── ui-systems.md                 # GUI, UIShadow, StyleQuery, UIFlexItem, StyleSheet
│   ├── legacy-migration.md           # Deprecated APIs, RunService events, Scoped UserIds
│   ├── monetization.md               # Transfers API, Subscriptions, game passes
│   └── file-formats-and-assets.md    # rbxl/rbxm formats, ZSTD/LZ4, MeshContent, importing
└── evals/
    └── evals.json                    # Skill trigger accuracy test cases
```

## Companion: `~/RobloxDocs/` (Local API Reference)

The skill integrates with a **local API reference hub** for token-efficient lookups:

```
~/RobloxDocs/
├── RobloxAPI/
│   ├── dumps/                         # Full-API-Dump.json per version
│   │   └── latest.json → (symlink)
│   ├── classes/                       # 912 individual class JSONs (~10KB each)
│   ├── enums/                         # 622 enum JSONs
│   ├── services/                      # 255 service JSONs (subset)
│   ├── deprecated/                    # 48 deprecated class JSONs
│   ├── class-index.json               # Lightweight index for quick lookup
│   ├── enum-index.json
│   ├── service-index.json
│   └── deprecated-index.json
├── scripts/
│   ├── roblox-api-monitor.sh          # Smart platform detection + auto-diff + auto-split
│   └── split-api-dump.sh             # Split dump into per-class files
└── README.md
```

**Why?** Reading one class file (~10KB) is **845× smaller** than the full API dump (~8MB).
This dramatically reduces token usage for AI agents.

### Setup RobloxDocs

```bash
# 1. Create structure
mkdir -p ~/RobloxDocs/{RobloxAPI/{dumps,classes,enums,services,deprecated},scripts}

# 2. Copy scripts (from this repo or create them)
# See ~/RobloxDocs/README.md for script contents

# 3. Download and split the API dump
~/RobloxDocs/scripts/roblox-api-monitor.sh
```

### Keeping Updated

The monitor script uses **smart platform detection** (via `uname`):
- `Darwin` → checks `MacStudio` version
- `Linux` / `Windows` → checks `WindowsStudio64`
- Always downloads dump via WindowsStudio64 hash (only Windows builds have it on CDN)

```bash
# Manual check
~/RobloxDocs/scripts/roblox-api-monitor.sh

# Force re-download
~/RobloxDocs/scripts/roblox-api-monitor.sh --force
```

## Installation

### Antigravity IDE / Gemini (Primary)

```bash
# Clone into your plugins directory
mkdir -p ~/.gemini/config/plugins/roblox-dev-suite/skills
cd ~/.gemini/config/plugins/roblox-dev-suite/skills
git clone https://github.com/MSayib/roblox-dev-skill.git roblox-dev-skill
```

### Claude Code

```bash
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/MSayib/roblox-dev-skill.git roblox-dev
```

### Verify Installation

The skill is active when listed in your AI assistant's available skills.
Test by asking: *"Create a coin collection system for my Roblox game"* — the skill
should auto-trigger and generate server-authoritative Luau code with `--!strict` mode.

## Usage

### Auto-Trigger
The skill automatically activates when you mention Roblox-related topics:
- `Roblox`, `Luau`, `Roblox Studio`, `DataStoreService`, `RemoteEvent`
- `ProfileStore`, `Rojo`, `rbxl`, `rbxlx`, `rbxm`, `game pass`
- `fbx`, `obj`, `gltf`, `import/export model`, `Universal Importer`
- Any Roblox Engine API reference

### Lookup Priority
```
1. Reference files (Routing Table in SKILL.md)    ← curated knowledge
2. ~/RobloxDocs/RobloxAPI/classes/<Name>.json      ← local split JSON
3. Web docs (create.roblox.com/docs/en-us/*.md)    ← live Roblox official
4. robloxapi.github.io/ref                         ← visual API browser
5. context7 MCP                                    ← fallback
```

### With Roblox Studio MCP
If you have the official [Roblox Studio MCP server](https://create.roblox.com/docs)
connected, the skill can:
- Read/write scripts directly in Studio
- Execute Luau code for validation
- Search the game tree
- Run playtests and read console output
- Take screenshots for visual verification

## Knowledge Coverage (August 2026)

| Topic | Status | Reference File |
|-------|--------|---------------|
| Luau language (strict mode, types, generics) | ✅ Current | `luau-fundamentals.md` |
| Project architecture (services, Rojo, IAS) | ✅ Current | `project-structure.md` |
| DataStore + ProfileStore + **MemoryStoreService** | ✅ Aug 2026 | `datastore-persistence.md` |
| Client-Server networking + BindableEvent caveats | ✅ Aug 2026 | `networking.md` |
| Security (BanAsync, server authority, exploits) | ✅ Current | `security-hardening.md` |
| Performance (Parallel Luau, **RunService pipeline**) | ✅ Aug 2026 | `performance-optimization.md` |
| MCP integration (26 tools) | ✅ Current | `mcp-integration.md` |
| UI (**UIFlexItem**, **StyleSheet/StyleRule**, StyleQuery) | ✅ Aug 2026 | `ui-systems.md` |
| Legacy migration (RunService events, PlayerOwnsAsset) | ✅ Aug 2026 | `legacy-migration.md` |
| Monetization (Transfers, **Subscriptions**) | ✅ Aug 2026 | `monetization.md` |
| File formats (**ZSTD/LZ4**, **MeshContent**, importing) | ✅ Aug 2026 | `file-formats-and-assets.md` |

## Update History

| Version | Date | Highlights |
|---------|------|-----------|
| **2.5.0** | Aug 27, 2026 | Engine & Luau v0.735 upgrade: Full API Dump 0.735.0.7351131 (912 classes, +BranchService, +IntentService, +PlayerControlState, +ScriptScannerService), LOP_FASTPCALL (~2x faster pcall/xpcall), type function enhancements & setmetatable |
| **2.4.0** | Aug 11, 2026 | Local-first `~/RobloxDocs/` lookup, smart platform detection, background auto-update |
| **2.3.0** | Aug 11, 2026 | Deep reference refresh: 7 files updated with UIFlexItem, ZSTD, Subscriptions, MemoryStoreService, RunService pipeline |
| **2.2.0** | Aug 11, 2026 | Fixed broken deprecated URL, added Open Cloud llms.txt discovery + OpenAPI spec |
| **2.1.0** | Jun 27, 2026 | Added file-formats-and-assets.md, official docs lookup section |
| **2.0.0** | Jun 25, 2026 | Mid-2026 deep refresh: monetization, StyleQuery, BanAsync, 12+ deprecated APIs |
| **1.0.0** | Jun 25, 2026 | Initial creation: 9 reference files, SKILL.md router, MCP integration |

## Contributing

1. **Research-based only** — all content must be grounded in official Roblox documentation
2. **No improvisation** — if unsure, flag it as a question rather than guessing
3. **Update `metadata.json`** — bump version and add a changelog entry
4. **Run evals** — verify trigger accuracy with `evals/evals.json`
5. **Keep format consistent** — `--!strict` in all code examples, PascalCase for APIs

## License

MIT License — see [LICENSE](LICENSE) for details.

## Credits

- **Creator**: [@MSayib](https://github.com/MSayib) — built collaboratively with AI (research-driven, fact-checked)
- **Sources**: [Roblox Creator Docs](https://create.roblox.com/docs),
  [Luau Language](https://luau.org), [Roblox DevForum](https://devforum.roblox.com),
  [RobloxAPI/ref](https://robloxapi.github.io/ref)
- **Skills Format**: Pioneered by [Anthropic](https://github.com/anthropics/skills)
