# Installing roblox-dev-skill

[← README](../README.md)

## Step 1: Install the skill

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

## Step 2: Restart your agent

Agents scan their skills folders at startup. Then ask something like *"Create a coin collection
system for my Roblox game"* — the skill should trigger and produce server-authoritative `--!strict`
Luau.

## Supported agents

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

## Options

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

## Update and uninstall

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

## Manual install

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
