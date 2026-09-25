# 🎮 Roblox Dev Skill — AI Coding Assistant for Roblox Development

An expert-level AI skill for Roblox game development with Luau. Works with
[Claude Code](https://code.claude.com), [Antigravity](https://antigravity.google), Codex, Cursor,
Gemini CLI, GitHub Copilot and every other agent that reads the open
[Agent Skills](https://agentskills.io) format.

> **Skill version:** 2.13.0 | **Engine:** 0.740.19.7400931 | **Luau:** 0.739 | **Ingested:** 2026-09-25
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
- 🧠 **Comprehensive knowledge base** — curated Roblox & Luau development guides across 14 reference topics
- 🧩 **Worked examples for agents** — end-to-end sequences (request → routing → tool calls → verification), each with explicit *non-goals* so a near-miss request does not get pattern-matched to the wrong pattern
- 📂 **Local-first API lookup** — pre-split `~/RobloxDocs/` JSON files: a typical class lookup reads ~2 KB against an 8.3 MB full dump (re-measured 2026-09-25)
- 🔄 **Obsolescence detection** — the skill compares `metadata.json` against today's date and *asks* before updating. It is not self-updating and there is no background job; a human runs `roblox-api-monitor.sh`
- 🎯 **Smart routing** — automatically selects the right reference based on your intent
- 🔌 **MCP client guidance** — how to use Roblox's built-in Studio MCP server correctly, with its real tool signatures and limits
- 🛡️ **Two threat models** — player→server anti-exploit (`security-hardening.md`) *and* agent→Studio safety (`agent-safety.md`)
- 📚 **Migration-aware** — guides you through deprecated APIs and breaking changes
- ⚡ **Multi-fallback** — local JSON → web docs → Context7
- 🔬 **Self-auditing** — `audit-skill-examples.py` checks every code example against the API dump, so an example that cannot execute under the current security model fails the ingest instead of shipping

## Installation

### Step 1: Install the skill

One command installs the skill once and links it into every agent you choose. No git clone.

**macOS, Linux, WSL, Git Bash:**

```bash
curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.sh | bash
```

**Windows PowerShell:**

```powershell
irm https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.ps1 | iex
```

**Windows CMD:**

```bat
curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.cmd -o install.cmd && install.cmd
```

The installer then:

1. **Asks which agents to set up**, with the ones it finds on your machine pre-selected. Toggle by
   number and press Enter. Without a terminal (CI, scripts) it uses the detected defaults.
2. **Stores the skill once** — `~/.local/share/roblox-dev-skill/` on macOS/Linux,
   `%LOCALAPPDATA%\roblox-dev-skill\` on Windows — and **links** it into each agent's skills
   folder. One copy on disk means one update reaches every agent. On Windows it uses a symlink, or
   a directory junction when symlinks need admin rights, or a copy as a last resort.
3. **Offers to set up `~/RobloxDocs/`** — it downloads the current Roblox API dump and splits it
   into ~2 KB per-class files, so the agent answers API questions from local data. Needs Python 3.6+;
   the skill works without it, using web docs.

Nothing it did not create is ever deleted. An existing folder in the way is moved to a backup
outside every skills folder (a backup inside one would load as a duplicate skill), and a link that
points somewhere else is left alone unless you pass `--force`.

### Step 2: Restart your agent

Agents scan their skills folders at startup. Then ask something like *"Create a coin collection
system for my Roblox game"* — the skill should trigger and produce server-authoritative `--!strict`
Luau.

### Supported agents

One link in **`~/.agents/skills`** — the cross-agent convention — already covers most agents. The
installer adds native links only where an agent does not read that folder, so nothing shows up
twice. Every path below was checked against the agent's own documentation (2026-09-25).

| Agent | User skills folder | Covered by `~/.agents/skills` |
|---|---|---|
| Claude Code | `~/.claude/skills/` | — needs its own link |
| Antigravity (2.0 / IDE) | `~/.gemini/config/skills/` | — needs its own link |
| Antigravity CLI | `~/.gemini/antigravity-cli/skills/` | — needs its own link |
| Kiro | `~/.kiro/skills/` | — needs its own link |
| Codex (OpenAI) | `~/.agents/skills/` | ✓ (its native folder) |
| Goose | `~/.agents/skills/` | ✓ (its native folder) |
| Gemini CLI | `~/.gemini/skills/` | ✓ |
| Cursor | `~/.cursor/skills/` | ✓ |
| GitHub Copilot (CLI / VS Code) | `~/.copilot/skills/` | ✓ |
| OpenCode | `~/.config/opencode/skills/` | ✓ |
| Roo Code | `~/.roo/skills/` | ✓ |
| Junie (JetBrains) | `~/.junie/skills/` | ✓ |
| Amp | `~/.config/amp/skills/` | ✓ |
| Anything else | `--path DIR` / `-Path DIR` | — |

`install.sh --list` (or `-List` in PowerShell) prints the same table with what it detected on your
machine and the documentation URL behind each path.

### Options

Pass options after `bash -s --` in the one-liner, or use the script-block form in PowerShell:

```bash
# non-interactive: exactly these agents, no RobloxDocs
curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.sh | bash -s -- --agents claude,universal --no-docs --yes

# see what would happen, change nothing
curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.sh | bash -s -- --dry-run
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.ps1))) -Agents claude,universal -NoDocs -Yes
```

| bash | PowerShell | |
|---|---|---|
| `--agents a,b` | `-Agents a,b` | agent ids, `detected`, or `all` |
| `--path DIR` | `-Path DIR` | also install into a custom skills folder |
| `--yes` | `-Yes` | no questions |
| `--dry-run` | `-DryRun` | show the plan, change nothing |
| `--copy` | `-Copy` | copy instead of linking |
| `--force` | `-Force` | replace a link that points elsewhere (it is backed up) |
| `--docs` / `--no-docs` | `-Docs` / `-NoDocs` | set up RobloxDocs, or skip it |
| `--docs-only` | `-DocsOnly` | only (re)install RobloxDocs |
| `--ref TAG` | `-Ref TAG` | install a specific branch or tag |
| `--update` | `-Update` | fetch the latest skill; links follow automatically |
| `--uninstall` | `-Uninstall` | remove exactly what the installer made |
| `--list` | `-List` | show supported agents and their folders |

### Update and uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.sh | bash -s -- --update     # links pick up the new version at once
bash ~/.local/share/roblox-dev-skill/install.sh --uninstall
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.ps1))) -Update
& "$env:LOCALAPPDATA\roblox-dev-skill\install.ps1" -Uninstall
```

Uninstall removes only the links and copies listed in the installer's manifest, and only while they
still point at the installed skill. `~/RobloxDocs` is kept unless you add `--purge-docs`, which
asks first — old API dumps are the evidence you diff new releases against.

### Manual install

Copy or clone the repository into any agent's skills folder from the table above. **The folder must
be named `roblox-dev-skill`**: the [Agent Skills spec](https://agentskills.io/specification)
requires the folder name to match the skill's `name`, and stricter agents skip a skill whose folder
does not.

```bash
git clone https://github.com/MSayib/roblox-dev-skill.git ~/.agents/skills/roblox-dev-skill
```

> **If you followed an older version of this README:** it told Claude Code users to clone into
> `~/.claude/skills/roblox-dev`, which breaks that rule, and told Antigravity users to clone into
> `~/.gemini/config/plugins/roblox-dev-suite/skills/` — a plugin folder that Antigravity only loads
> when a `plugin.json` manifest is present, which the repo never shipped. The installer detects an
> old `roblox-dev` clone and moves it aside for you.

## Directory Structure

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
│   └── evals.json                    # Skill trigger accuracy test cases
└── tools/robloxdocs/                 # RobloxDocs scripts the installer copies to ~/RobloxDocs/scripts
```

The installed skill contains only `SKILL.md`, `metadata.json`, `references/` and the license/docs —
`evals/`, `tools/` and the installers stay in the repository.

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
│   ├── deprecated-index.json
│   └── diffs/                         # member-level diffs between consecutive dumps
├── scripts/
│   ├── roblox-api-monitor.py          # check → download → validate → diff → split → audit
│   ├── roblox-api-monitor.sh          # shim for the above (keeps the documented path working)
│   ├── split-api-dump.py              # one-pass splitter (no jq)
│   ├── diff-api-dumps.py              # member-level diff + grep-back into the skill's docs
│   └── audit-skill-examples.py        # validates the skill's code examples against the dump
├── config                             # SKILL_REFS=…, AUDIT_MODE=warn|strict|off
└── README.md
```

**Why?** Re-measured 2026-09-25 on 0.740.19.7400931: the full dump is **8,314,613 bytes**, while the
924 split class files are **101 B min / 2,050 B median / 4,795 B mean / 104,594 B max**. A typical
class lookup therefore reads about **0.02%** of the dump. (An earlier README claimed "845× smaller"
from a "~10KB" class file; neither number is reproducible — the median class file is ~2 KB.
`SKILL.md` carries the command that re-measures both, including the `stat -L` needed to follow the
`latest.json` symlink instead of measuring the link itself.)

### Setting up and refreshing RobloxDocs

The installer sets it up (`--docs-only` / `-DocsOnly` to do only that). To refresh it to a new
engine version later:

```bash
~/RobloxDocs/scripts/roblox-api-monitor.sh                      # macOS, Linux, WSL, Git Bash
python "%USERPROFILE%\RobloxDocs\scripts\roblox-api-monitor.py"    # Windows without bash
```

It checks the current Studio version, downloads the dump only when it changed, validates it before
it replaces anything, diffs it member-by-member against the previous one, re-splits it, and audits
the skill's code examples against it. It needs **Python 3.6+** and nothing else — no `jq`, no zsh.
Roblox ships roughly weekly; the skill tells you when the local dump looks stale and never refreshes
on its own.

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
| Safety — agent→Studio (destructive MCP ops, injection from place content) | ✅ Sep 2026 | `agent-safety.md` |
| Worked examples (build / debug / migrate / verify / refuse) | ✅ **new in 2.12.0** | `worked-examples.md` |
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
| **2.13.0** | Sep 25, 2026 | **One-line installers** — `install.sh` (macOS/Linux/WSL/Git Bash), `install.ps1` and `install.cmd` (Windows) — with a wizard over 14 agents whose skills folders were each verified against that agent's documentation. The skill is stored once and linked everywhere; one `~/.agents/skills` link covers nine agents, so nothing is listed twice. RobloxDocs tooling moved into the repo and became cross-platform (Python monitor and one-pass splitter; no zsh/jq/bc), and the installer sets it up with a real API dump. Fixed: the README's Claude Code folder name (`roblox-dev`) fails the official spec validator; its Antigravity path only worked with a hand-written `plugin.json`; the Antigravity link pointed at an nginx placeholder; `stat -f %z` silently prints filesystem data on Linux. |
| **2.12.0** | Sep 25, 2026 | **Worked examples, and the tooling that proves the docs are executable.** New `references/worked-examples.md`: five end-to-end sequences (build a server-authoritative feature, debug via MCP, migrate a deprecation, verify an unfamiliar API, refuse an unsafe request), each with a **Not this** list so a near-miss request is not pattern-matched to the wrong sample, and each ending in a verification step rather than "code written". **Found and fixed a second latent defect**: the Input Action System example used `InputActionService` and `InputActionBinding` (neither class exists), `ActionType` (the property is `Type`), `Enum.InputActionType.Button` (not an item — it is `Bool`), `Activated`/`Deactivated` (the events are `Pressed`/`Released`/`StateChanged`), and `PlayerScriptsUseInputActionSystem = true` (it is an `Enum.RolloutState`) — six wrong lines in twelve. Also softened the false claim that IAS deprecates `UserInputService`/`ContextActionService` (neither carries a `Deprecated` tag). New tooling in `~/RobloxDocs/scripts/`: `audit-skill-examples.py` (validates every example against the dump; **exits non-zero so a broken example fails the ingest**) and `diff-api-dumps.py` (member-level diff with grep-back into the docs). `roblox-api-monitor.sh` v2 adds a download integrity gate, a PID-aware self-clearing lock, both `.current-version` timestamps, and opt-in retention. |
| **2.10.0** | Sep 25, 2026 | **MCP accuracy pass + new threat model.** Added `references/agent-safety.md` (agent→Studio trust boundary) and this changelog split. Fixed MCP claims against the [official docs](https://create.roblox.com/docs/studio/mcp) and live tool schemas: removed the phantom `run_as_job`; corrected `multi_edit` (one script per call, exact-match `old_string`/`new_string`, `Edit` datamodel only — the old documented signature would have failed every call); `execute_luau` **does** return values; `upload_image` takes HTTP URLs, `store_image` takes local files; `http_get` is allowlisted; 29 tools → 26 documented / 28 observed; documented the missing `skill` and `subagent` tools. Also fixed non-MCP misleading items: README described the repo as if it were an MCP server, its tree listed 11 of 12 reference files, class counts and the "~10KB" figure were stale, and `SKILL.md` told the agent to auto-run a background update against its own approval rule. |

## Roadmap

- **Verify the Windows installers on real hardware** — junction creation, Windows PowerShell 5.1 at
  runtime, and `install.cmd` were tested only indirectly (see CHANGELOG 2.13.0). Reports welcome.
- **Widen the worked examples** (shipped in 2.12.0) to DataStore migrations, monetization receipts,
  and UI/IAS flows, each with its own *Not this* list and eval coverage.
- **Parse Luau properly in the example audit.** It matches simple assignments and method calls with
  regular expressions; dynamic forms such as `obj[name] = value` pass unchecked.
- **Keep the weekly ingest cadence.** Each release is diffed dump-to-dump rather than trusted from
  release-note prose, because that is what produces checkable changelog rows.

## Contributing

1. **Research-based only** — all content must be grounded in official Roblox documentation
2. **No improvisation** — if unsure, flag it as a question rather than guessing
3. **Update `metadata.json`** — bump version and add a changelog entry
4. **Run evals** — verify trigger accuracy with `evals/evals.json`
5. **Keep format consistent** — `--!strict` in all code examples, PascalCase for APIs
6. **Audit your examples** — `python3 tools/robloxdocs/audit-skill-examples.py references` must
   report 0 defects; it checks every Luau example against the current API dump
7. **Validate against the spec** —
   `uvx --from "git+https://github.com/agentskills/agentskills#subdirectory=skills-ref" skills-ref validate "$PWD"`
8. **Test installer changes locally** — `bash install.sh --source . --dry-run` (or
   `& ./install.ps1 -Source . -DryRun`) installs from your checkout instead of GitHub

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
