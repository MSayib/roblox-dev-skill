# 🎮 Roblox Dev Skill — AI Coding Assistant for Roblox Development

An expert-level AI skill for Roblox game development with Luau. Designed for 
[Claude Code](https://claude.ai), [Antigravity IDE](https://antigravity.dev), 
and any AI coding assistant that supports the Skills format.

> **Last Updated:** June 25, 2026 | **Engine Version:** v727+ | **Knowledge Status:** Mid-2026 Current

## What Is This?

A structured knowledge base that transforms your AI coding assistant into a 
**Roblox development expert**. When you mention anything Roblox-related, the skill 
auto-triggers and provides the AI with deep, accurate, research-verified knowledge 
about the Roblox platform.

### Key Features
- 🧠 **4,900+ lines** of curated Roblox development knowledge
- 🔄 **Self-updating** — built-in weekly freshness check with `/roblox-update` command
- 🎯 **Smart routing** — automatically selects the right reference based on your intent
- 🔌 **MCP integration** — works with the official Roblox Studio MCP server
- 🛡️ **Security-first** — server authority, input validation, anti-exploit patterns
- 📚 **Migration-aware** — guides you through deprecated APIs and breaking changes
- ⚡ **Context7 fallback** — looks up latest API docs when local knowledge isn't enough

## Directory Structure

```
roblox-dev/
├── SKILL.md                          # Main skill file (router + standards + workflows)
├── metadata.json                     # Knowledge update tracking (timestamps, versions)
├── README.md                         # This file
├── references/                       # Deep-dive reference guides
│   ├── luau-fundamentals.md          # Luau language, types, naming, style
│   ├── project-structure.md          # Architecture, Rojo, Script Sync, IAS
│   ├── datastore-persistence.md      # DataStoreService, ProfileStore, storage limits
│   ├── networking.md                 # RemoteEvents, client-server, replication
│   ├── security-hardening.md         # Anti-exploit, BanAsync, Server Authority
│   ├── performance-optimization.md   # Memory, Parallel Luau, profiling
│   ├── mcp-integration.md            # Roblox Studio MCP tools and workflows
│   ├── ui-systems.md                 # GUI, UIShadow, StyleQuery, UICorner
│   ├── legacy-migration.md           # Deprecated APIs, Scoped UserIds, migration
│   └── monetization.md              # Transfers API, game passes, publishing
└── evals/
    └── evals.json                    # Skill trigger accuracy test cases
```

## Installation

### Claude Code (Primary)

```bash
# Clone into your global skills directory
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/YOUR_USERNAME/roblox-dev-skill.git roblox-dev
```

### Antigravity IDE / Gemini

```bash
# Symlink from Claude's directory (single source of truth)
mkdir -p ~/.gemini/config/skills
ln -s ~/.claude/skills/roblox-dev ~/.gemini/config/skills/roblox-dev
```

Or install directly:
```bash
mkdir -p ~/.gemini/config/skills
cd ~/.gemini/config/skills
git clone https://github.com/YOUR_USERNAME/roblox-dev-skill.git roblox-dev
```

### Verify Installation

The skill is active when you see it listed in your AI assistant's available skills.
Test by asking: *"Create a coin collection system for my Roblox game"* — the skill 
should auto-trigger and generate server-authoritative Luau code with `--!strict` mode.

## Usage

### Auto-Trigger
The skill automatically activates when you mention Roblox-related topics:
- `Roblox`, `Luau`, `Roblox Studio`, `DataStoreService`, `RemoteEvent`
- `ProfileStore`, `Rojo`, `rbxl`, `rbxlx`, `game pass`, `obby`, `tycoon`
- Any Roblox Engine API reference

### Manual Commands
| Command | Description |
|---------|-------------|
| `/roblox-update` | Trigger a full knowledge refresh from latest Roblox docs |
| *"update roblox skill"* | Natural language alternative for knowledge update |

### With Roblox Studio MCP
If you have the official [Roblox Studio MCP server](https://create.roblox.com/docs) 
connected, the skill can:
- Read/write scripts directly in Studio
- Execute Luau code for validation
- Search the game tree
- Run playtests and read console output
- Take screenshots for visual verification

## Knowledge Update System

The skill includes a **self-monitoring freshness system**:

1. On each trigger, it checks `metadata.json` for the `last_updated` timestamp
2. If more than 7 days have passed, it reminds you to run an update
3. Updates follow a strict protocol: **Research → Fact-check → QnA → Apply → Audit**
4. All decisions require user approval — the AI never auto-updates

### Manual Update
Say `/roblox-update` to trigger an immediate knowledge refresh.

## What's Covered (Mid-2026)

| Topic | Status |
|-------|--------|
| Luau language (strict mode, types, generics, `task` library) | ✅ Current |
| Project architecture (services, MVC, module patterns) | ✅ Current |
| DataStore + ProfileStore (session locking, limits, overage) | ✅ April 2026 |
| Client-Server networking (RemoteEvents, replication) | ✅ Current |
| Security (server authority Client Beta, BanAsync, exploits) | ✅ June 2026 |
| Performance (Parallel Luau, memory, Microprofiler) | ✅ Current |
| MCP integration (built-in native server, 26 tools) | ✅ June 2026 |
| UI systems (UIShadow, StyleQuery, per-corner UICorner) | ✅ June 2026 |
| Legacy migration (12+ deprecated APIs, Scoped UserIds Oct 2026) | ✅ June 2026 |
| Monetization (Transfers API, Roblox Plus, publishing fee) | ✅ May 2026 |

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Research-based only** — all content must be grounded in official Roblox documentation
2. **No improvisation** — if you're unsure, flag it as a question rather than guessing
3. **Update `metadata.json`** — bump version and add a changelog entry
4. **Run evals** — verify trigger accuracy with `evals/evals.json`
5. **Keep format consistent** — `--!strict` in all code examples, PascalCase for APIs

## License

MIT License — see [LICENSE](LICENSE) for details.

## Credits

- **Creator**: Built collaboratively by human + AI (research-driven, fact-checked)
- **Sources**: [Roblox Creator Docs](https://create.roblox.com/docs), 
  [Luau Language](https://luau.org), [Roblox DevForum](https://devforum.roblox.com),
  [Roblox Lua Style Guide](https://roblox.github.io/lua-style-guide/)
- **Skills Format**: Pioneered by [Anthropic](https://github.com/anthropics/skills)
