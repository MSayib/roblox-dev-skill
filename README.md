# 🎮 Roblox Dev Skill — AI Coding Assistant for Roblox Development

An expert-level AI skill for Roblox game development with Luau. Designed for
[Antigravity IDE](https://antigravity.dev), [Claude Code](https://claude.ai),
and any AI coding assistant that supports the Skills format.

> **Skill version:** 2.11.0 | **Engine:** 0.740.19.7400931 | **Luau:** 0.739 | **Ingested:** 2026-09-25
>
> Dump downloaded, re-split, and diffed against 0.739 on that date: 924 classes / 635 enums /
> 258 services / 48 deprecated.
>
> Roblox ships roughly weekly, so treat that number as *when this was last verified*, never as
> today's version. `SKILL.md` carries the two commands that re-derive engine and Luau in one line
> each — and the skill is instructed to tell you when its local dump looks stale rather than
> pretending otherwise.

## What Is This?

A structured knowledge base that transforms your AI coding assistant into a
**Roblox development expert**. When you mention anything Roblox-related, the skill
auto-triggers and provides the AI with deep, accurate, research-verified knowledge
about the Roblox platform.

> ### This is a skill, not an MCP server
>
> The repo is tagged `mcp` because it teaches an agent to **drive Roblox's own Studio MCP server**
> — which is [built into Roblox Studio](https://create.roblox.com/docs/studio/mcp). This project
> ships **no tools, no transport, and no execute surface of its own**: it is Markdown that an agent
> reads. If you are looking for something to put in `mcpServers`, you want Studio's built-in
> server, not this. See [`references/mcp-integration.md`](references/mcp-integration.md) for how to
> connect it and [`references/agent-safety.md`](references/agent-safety.md) for what that access
> implies.

### Key Features
- 🧠 **Comprehensive knowledge base** — curated Roblox & Luau development guides across 13 reference topics
- 📂 **Local-first API lookup** — pre-split `~/RobloxDocs/` JSON files: a typical class lookup reads ~2 KB against an 8.3 MB full dump (re-measured 2026-09-25)
- 🔄 **Obsolescence detection** — the skill compares `metadata.json` against today's date and *asks* before updating. It is not self-updating and there is no background job; a human runs `roblox-api-monitor.sh`
- 🎯 **Smart routing** — automatically selects the right reference based on your intent
- 🔌 **MCP client guidance** — how to use Roblox's built-in Studio MCP server correctly, with its real tool signatures and limits
- 🛡️ **Two threat models** — player→server anti-exploit (`security-hardening.md`) *and* agent→Studio safety (`agent-safety.md`)
- 📚 **Migration-aware** — guides you through deprecated APIs and breaking changes
- ⚡ **Multi-fallback** — local JSON → web docs → Context7

## Directory Structure

```
roblox-dev-skill/
├── SKILL.md                          # Main skill file (router + standards + workflows)
├── metadata.json                     # Knowledge update tracking (timestamps, versions)
├── CHANGELOG.md                      # Full version history
├── README.md                         # This file
├── references/                       # Deep-dive reference guides (13)
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
│   ├── classes/                       # 924 class JSONs (~2 KB median — measured below)
│   ├── enums/                         # 635 enum JSONs
│   ├── services/                      # 258 service JSONs (subset)
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

**Why?** Re-measured 2026-09-25 on 0.740.19.7400931: the full dump is **8,314,613 bytes**, while the
924 split class files are **101 B min / 2,047 B median / 4,795 B mean / 104,594 B max**. A typical
class lookup therefore reads about **0.02%** of the dump. (An earlier README claimed "845× smaller"
from a "~10KB" class file; neither number is reproducible — the median class file is ~2 KB.
`SKILL.md` carries the command that re-measures both, including the `stat -L` needed to follow the
`latest.json` symlink instead of measuring the link itself.)

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

## Knowledge Coverage

Each row says when that file's content was last verified — not that it is current today.

| Topic | Status | Reference File |
|-------|--------|---------------|
| Luau language (strict mode, types, generics) | ✅ **Luau 0.739** | `luau-fundamentals.md` |
| Project architecture (services, Rojo, IAS) | ✅ Current | `project-structure.md` |
| DataStore + ProfileStore + **MemoryStoreService** | ✅ Aug 2026 | `datastore-persistence.md` |
| Client-Server networking + BindableEvent caveats | ✅ Aug 2026 | `networking.md` |
| Security — player→server (BanAsync, server authority, exploits, script capabilities) | ✅ **Sep 2026** | `security-hardening.md` |
| Safety — agent→Studio (destructive MCP ops, injection from place content) | ✅ **new in 2.10.0** | `agent-safety.md` |
| Performance (Parallel Luau, **RunService pipeline**, fidelity write rules) | ✅ **Sep 2026 (0.740)** | `performance-optimization.md` |
| MCP integration (26 documented tools / 28 observed) | ✅ **re-verified 2026-09-25** against the official docs page + live schemas | `mcp-integration.md` |
| UI (**UIFlexItem**, **StyleSheet/StyleRule**, StyleQuery) | ✅ Aug 2026 | `ui-systems.md` |
| Legacy migration (RunService events, **0.740 removals & deprecations**) | ✅ **Sep 2026 (0.740)** | `legacy-migration.md` |
| Studio plugins, `Script.Source` limits, engine limits | ✅ measured Aug 2026 | `studio-plugins-and-limits.md` |
| Monetization (Transfers, **Subscriptions**) | ✅ Aug 2026 | `monetization.md` |
| File formats (**ZSTD/LZ4**, **MeshContent**, importing) | ✅ Aug 2026 | `file-formats-and-assets.md` |

## Update History

Last three releases. **Full history: [CHANGELOG.md](CHANGELOG.md)** · machine-readable entries with
per-release verification method: [`metadata.json`](metadata.json).

| Version | Date | Highlights |
|---------|------|-----------|
| **2.11.0** | Sep 25, 2026 | **Engine 0.740.19.7400931 + Luau 0.739.** Dump re-split: 924 classes / 635 enums / 258 services (a *shrinking* release). `SnippetService` and `Enum.Language` **removed**; `LocalizationService:GetTranslatorForPlayer` **deprecated** → `GetTranslatorForPlayerAsync`. **`TriangleMeshPart.CollisionFidelity`/`FluidFidelity` and `PartOperation.RenderFidelity`/`SmoothingAngle` became script-writable** (`PluginSecurity` → `None`) — this file had been shipping a runtime `CollisionFidelity` example that **could not have worked before 0.740**, now corrected, with the caveat that `MeshPart.RenderFidelity` was *not* relaxed. `Lighting.LightingStyle`/`PrioritizeLightingQuality` opened up too. Luau 0.739 typechecks generics inside function bodies more strictly (**can surface new errors in code that used to pass**) and adds a frozen-metatable metamethod cache. Also fixed: the `Sandboxed = true` advice omitted its prerequisite (`Workspace.SandboxedInstanceMode = Experimental`) so it read as protection you did not have; `checkedAt` does not exist in `.current-version` after a fresh download; and the documented `stat -f %z latest.json` measured the 75-byte symlink instead of the dump. |
| **2.10.0** | Sep 25, 2026 | **MCP accuracy pass + new threat model.** Added `references/agent-safety.md` (agent→Studio trust boundary) and this changelog split. Fixed MCP claims against the [official docs](https://create.roblox.com/docs/studio/mcp) and live tool schemas: removed the phantom `run_as_job`; corrected `multi_edit` (one script per call, exact-match `old_string`/`new_string`, `Edit` datamodel only — the old documented signature would have failed every call); `execute_luau` **does** return values; `upload_image` takes HTTP URLs, `store_image` takes local files; `http_get` is allowlisted; 29 tools → 26 documented / 28 observed; documented the missing `skill` and `subagent` tools. Also fixed non-MCP misleading items: README described the repo as if it were an MCP server, its tree listed 11 of 12 reference files, class counts and the "~10KB" figure were stale, and `SKILL.md` told the agent to auto-run a background update against its own approval rule. |
| **2.9.0** | Sep 17, 2026 | Engine 0.739.0.7390687 (Luau **unchanged** at 0.738 — engine-only bump). Dump re-split: 925 classes / 636 enums / 259 services. `CallingService.CreateCall` → **`CreateCallAsync`** (breaking rename); +4 classes; +3 enums. |

## Roadmap

- **Worked examples for agentic consumption (next).** Every reference is currently *prose plus
  snippets*. The goal is a set of end-to-end samples — request → routing decision → tool calls →
  verification — shaped so an agent can pattern-match them without regressing on its actual task.
  Requirements: each sample carries its own trigger conditions and explicit non-goals (to avoid
  false-positive routing), shows the verification step rather than stopping at "code written", and
  is covered by `evals/evals.json` so a sample that starts mis-firing is caught.
- **Keep the weekly ingest cadence.** Each release is diffed locally dump-to-dump rather than
  trusted from release-note prose, because that is what produces checkable changelog rows.

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

## ⭐ Star History

If you find this skill helpful, don't forget to give it a ⭐ **star** on GitHub! It helps more developers discover the project and supports continued development.

[![Star History Chart](https://api.star-history.com/svg?repos=MSayib/roblox-dev-skill&type=Date)](https://star-history.com/#MSayib/roblox-dev-skill&Date)
