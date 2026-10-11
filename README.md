# 🎮 Roblox Dev Skill

[![CI](https://github.com/MSayib/roblox-dev-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/MSayib/roblox-dev-skill/actions/workflows/ci.yml)

**An [Agent Skill](https://agentskills.io) that makes an AI coding agent write correct, current Roblox
code.** When you mention Roblox, Luau or Roblox Studio, the agent loads this skill: a routing file
([`SKILL.md`](SKILL.md)) plus 14 reference guides on Luau, client-server architecture, security,
DataStores, UI, performance, monetization, migration, and driving Roblox Studio through its MCP
server. Works with Claude Code, Codex, Cursor, Gemini CLI, Antigravity, GitHub Copilot, and any
agent that reads the Agent Skills format.

> **Skill 2.17.0** · verified against Roblox Studio **0.742.0.7421053** and **Luau 0.742** on
> 2026-10-11. Every code example was type-checked under `--!strict` and run in a real Studio place,
> and every factual statement checked against an official source or a test.
> Roblox ships weekly, so this is *when it was last verified*, not today's version.

It is Markdown an agent reads. It is **not** an MCP server and ships no tools: for Studio access,
enable [Studio's built-in MCP server](https://create.roblox.com/docs/studio/mcp).

## Quick install

**macOS, Linux, WSL, Git Bash**

```bash
curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.sh | bash
```

**Windows PowerShell**

```powershell
irm https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.ps1 | iex
```

**Windows CMD**

```bat
curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.cmd -o install.cmd && install.cmd
```

The installer asks which agents to set up (the ones it finds are pre-selected), stores the skill
once, and links it into each agent, so one update reaches all of them. It can also set up
[`~/RobloxDocs`](docs/robloxdocs.md), a local copy of the Roblox API for fast, offline lookups.
It never deletes anything it did not create.

**Then restart your agent** and try:

> *Create a coin collection system for my Roblox game*

You should get server-authoritative `--!strict` Luau that validates what the client sends. Options,
updating, uninstalling and manual install: **[docs/installation.md](docs/installation.md)**.

## What's inside

| Reference | Covers |
|---|---|
| [worked-examples](references/worked-examples.md) | Eight end-to-end tasks for an agent (build, debug, migrate, look up, refuse, sell a product, migrate saved data, bind input), each ending in a tested verification |
| [luau-fundamentals](references/luau-fundamentals.md) | Luau syntax, types and the New Type Solver, what each Luau release changed, beta and experimental features you cannot ship |
| [project-structure](references/project-structure.md) | Services, Rojo, client/server layout, the Input Action System |
| [networking](references/networking.md) | RemoteEvents, RemoteFunctions, unreliable remotes, bindables |
| [security-hardening](references/security-hardening.md) | Server authority, validating remote input, anti-exploit, bans, script capabilities |
| [datastore-persistence](references/datastore-persistence.md) | DataStoreService, ProfileStore, MemoryStoreService |
| [performance-optimization](references/performance-optimization.md) | Memory, Parallel Luau and Actors, streaming, the frame pipeline |
| [ui-systems](references/ui-systems.md) | GUI layout, StyleSheets, BillboardGui / SurfaceGui, ProximityPrompt |
| [monetization](references/monetization.md) | Game passes, developer products, subscriptions, Robux transfers |
| [legacy-migration](references/legacy-migration.md) | Deprecated APIs and replacements, what each engine release changed |
| [mcp-integration](references/mcp-integration.md) | Studio MCP tools with their real signatures and limits |
| [agent-safety](references/agent-safety.md) | What an agent with Studio access can break, and the rules that prevent it |
| [studio-plugins-and-limits](references/studio-plugins-and-limits.md) | Plugins, `Script.Source` limits, engine limits |
| [file-formats-and-assets](references/file-formats-and-assets.md) | `.rbxl`/`.rbxm`, meshes, importing |

How routing, lookup and the coverage dates work: **[docs/how-it-works.md](docs/how-it-works.md)**.

## How it stays correct

- **Every example is tested.** Each Luau block is type-checked with luau-lsp under `--!strict`, then
  run in a real Studio place through Rojo, as a game Script (so security gates apply), a
  LocalScript, or inside an Actor. The 2.16.0 pass found and fixed a script that could not compile,
  a pool that leaked objects, player data shared between players, and a purchase handler that
  charged for items it did not give. Since 2.17.0 the fragments run too, with the names a reader's
  project would supply, and the important examples assert what they do (a pool returns to 10, a
  receipt is granted once). **[docs/testing.md](docs/testing.md)**
- **Every claim is checked.** Each high-risk statement (limits, versions, "cannot", "not enabled")
  is in a register with its source or test; the 2.17.0 pass corrected 58, among them a
  delayed rollout the text dated, limits off by up to 1000×, and an event that does not exist.
  **[docs/claims.md](docs/claims.md)**
- **Every engine release is diffed** member by member against the previous API dump, and the
  developer-visible changes are run in Studio before the skill describes them.
- **It says what it does not know.** Features that exist but are not enabled, betas you cannot
  publish, and anything not yet tested are labelled as such.

History: **[CHANGELOG.md](CHANGELOG.md)** (machine-readable: [`metadata.json`](metadata.json)).

## For AI agents reading this

Start at [`SKILL.md`](SKILL.md): it holds the standards (always `--!strict`, server authority,
validate every remote argument) and a routing table that says which reference to open for which
task. Where a reference and a worked example disagree, the reference wins. Treat the version line
above as a date, and re-check the live engine version with the commands in `SKILL.md`.

## Contributing

Ground every claim in official documentation, the API dump, or a test you ran, and pass the four
test layers in [docs/testing.md](docs/testing.md) before opening a pull request.

## License and credits

MIT, see [LICENSE](LICENSE). Created by [@MSayib](https://github.com/MSayib), built with AI and
fact-checked against [Roblox Creator Docs](https://create.roblox.com/docs), [Luau](https://luau.org),
the Roblox API dump, and Roblox Studio itself.

If the skill helps you, a ⭐ helps other developers find it.

[![Star History Chart](https://api.star-history.com/svg?repos=MSayib/roblox-dev-skill&type=Date)](https://star-history.com/#MSayib/roblox-dev-skill&Date)
