# 🎮 Roblox Dev Skill — AI Coding Assistant for Roblox Development

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Roblox-blue?style=for-the-badge&logo=roblox" alt="Roblox"/>
  <img src="https://img.shields.io/badge/Language-Luau-purple?style=for-the-badge" alt="Luau"/>
  <img src="https://img.shields.io/badge/Engine-v727+-green?style=for-the-badge" alt="Engine"/>
  <img src="https://img.shields.io/badge/Knowledge-June_2026-orange?style=for-the-badge" alt="Updated"/>
  <img src="https://img.shields.io/badge/Lines-5100+-red?style=for-the-badge" alt="Lines"/>
</p>

<p align="center">
  <strong>An expert-level AI skill that transforms your coding assistant into a Roblox development expert.</strong>
</p>

<p align="center">
  Works with <a href="https://claude.ai">Claude Code</a> · <a href="https://antigravity.dev">Antigravity IDE</a> · Any AI assistant supporting the Skills format
</p>

---

> 🇮🇩 **Dokumentasi Bahasa Indonesia tersedia di bawah.** [Klik di sini untuk langsung ke Bahasa Indonesia](#-dokumentasi-bahasa-indonesia)

---

## 📖 Table of Contents

- [What Is This?](#what-is-this)
- [Features](#-features)
- [Directory Structure](#-directory-structure)
- [Installation](#-installation)
- [Usage](#-usage)
- [MCP Integration (Roblox Studio)](#-mcp-integration-roblox-studio)
- [Knowledge Update System](#-knowledge-update-system)
- [What's Covered](#-whats-covered-mid-2026)
- [Contributing](#-contributing)
- [Credits & Sources](#-credits--sources)
- [License](#-license)
- [Bahasa Indonesia Documentation](#-dokumentasi-bahasa-indonesia)

---

## What Is This?

A structured knowledge base of **5,100+ lines** that transforms your AI coding assistant into a **Roblox development expert**. When you mention anything Roblox-related in your conversation, the skill auto-triggers and provides the AI with deep, accurate, research-verified knowledge about the Roblox platform.

Built through collaborative **human + AI deep research** — every line is grounded in official Roblox documentation, verified against the live engine (v727), and fact-checked through a rigorous audit process.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🧠 **5,100+ lines** | Curated Roblox development knowledge across 10 reference files |
| 🔄 **Self-updating** | Built-in weekly freshness check with `/roblox-update` command |
| 🎯 **Smart routing** | Automatically selects the right reference based on your intent |
| 🔌 **MCP integration** | Full integration with the official Roblox Studio MCP server |
| 🛡️ **Security-first** | Server authority, input validation, anti-exploit patterns |
| 📚 **Migration-aware** | Guides you through deprecated APIs and breaking changes |
| ⚡ **Context7 fallback** | Looks up latest API docs when local knowledge isn't enough |
| 🚫 **Negative triggers** | Won't activate for Unity, Unreal, Godot, or web development |
| 📊 **Eval test suite** | 10 test cases to verify trigger accuracy |
| 🌏 **Dual-language docs** | English + Bahasa Indonesia 🇮🇩 |

---

## 📁 Directory Structure

```
roblox-dev-skill/
├── SKILL.md                          # Main skill file (router + standards + workflows)
├── metadata.json                     # Knowledge update tracking (timestamps, versions)
├── README.md                         # This file
├── LICENSE                           # MIT License
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

---

## 🚀 Installation

### Claude Code (Recommended)

```bash
# Clone into your global skills directory
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/MSayib/roblox-dev-skill.git roblox-dev
```

### Antigravity IDE / Gemini Code Assist

```bash
# Option A: Symlink from Claude's directory (single source of truth)
mkdir -p ~/.gemini/config/skills
ln -s ~/.claude/skills/roblox-dev ~/.gemini/config/skills/roblox-dev

# Option B: Direct install
mkdir -p ~/.gemini/config/skills
cd ~/.gemini/config/skills
git clone https://github.com/MSayib/roblox-dev-skill.git roblox-dev
```

### Verify Installation

The skill is active when you see it listed in your AI assistant's available skills.
Test by asking:

> *"Create a coin collection system for my Roblox game"*

The skill should auto-trigger and generate server-authoritative Luau code with `--!strict` mode.

---

## 💡 Usage

### Auto-Trigger Keywords

The skill automatically activates when you mention these Roblox-related topics:

```
Roblox · Luau · Roblox Studio · DataStoreService · RemoteEvent · RemoteFunction
ServerScriptService · ReplicatedStorage · StarterGui · MeshPart · ProfileStore
Rojo · rbxl · rbxlx · game pass · developer product · obby · tycoon · simulator
```

It will **NOT** trigger for: Unity, Unreal Engine, Godot, web/mobile development, or non-Luau languages.

### Smart Routing

The skill automatically selects the right reference file based on your intent:

| Your Intent | Reference Used |
|-------------|----------------|
| Luau syntax, types, naming | `luau-fundamentals.md` |
| Project architecture, patterns | `project-structure.md` |
| Save/load data, DataStore | `datastore-persistence.md` |
| Client-server communication | `networking.md` |
| Security, anti-exploit | `security-hardening.md` |
| Performance, optimization | `performance-optimization.md` |
| Roblox Studio MCP tools | `mcp-integration.md` |
| UI, GUI, menus, HUD | `ui-systems.md` |
| Migrating deprecated APIs | `legacy-migration.md` |
| Monetization, donations | `monetization.md` |

---

## 🔌 MCP Integration (Roblox Studio)

This skill is designed to work seamlessly with the **official Roblox Studio MCP server** — the built-in native MCP that ships with Roblox Studio (mid-2026+).

### Setup

1. Open **Roblox Studio**
2. Open the **Assistant widget**
3. Click **"Manage MCP Servers"**
4. **Enable** the built-in MCP server
5. Connect your AI assistant (Claude Code, Antigravity IDE, etc.)

### Available MCP Tools

The skill provides guidance for **26 MCP tools** including:

| Tool | Description |
|------|-------------|
| `execute_luau` | Run Luau code directly in Studio |
| `search_game_tree` | Explore the game hierarchy |
| `script_read` / `script_search` | Read and search scripts |
| `multi_edit` | Batch-edit multiple scripts |
| `start_stop_play` | Start/stop playtesting |
| `get_console_output` | Read console for errors |
| `screen_capture` | Take screenshots for visual verification |
| `inspect_instance` | Inspect properties of instances |
| `generate_mesh` / `generate_material` | AI-powered asset generation |
| `insert_asset` / `search_asset` | Insert assets from library |

### Recommended Workflow with MCP

```
1. get_studio_state        → Check what's currently open
2. search_game_tree        → Understand the project structure
3. script_read             → Read existing scripts before modifying
4. multi_edit              → Apply changes
5. execute_luau            → Validate code
6. start_stop_play         → Run playtest
7. get_console_output      → Check for errors
```

### Workspace Configuration

For optimal MCP integration, create an `AGENTS.md` in your Roblox workspace root:

```markdown
# Roblox Development Workspace

## First Steps (Every Session)
1. Run `get_studio_state` via Roblox_Studio MCP
2. Run `search_game_tree` to understand the project structure
3. Read existing scripts before modifying

## Development Environment
- Engine: Roblox Studio (latest version)
- Language: Luau (--!strict mode)
- MCP: Roblox_Studio server (built-in native MCP)
```

---

## 🔄 Knowledge Update System

The skill includes a **self-monitoring freshness system**:

### How It Works

1. On each skill trigger, the AI reads `metadata.json` for the `last_updated` timestamp
2. If more than **7 days** have passed, it reminds you to update
3. You decide — the AI **never auto-updates** without your approval

### Manual Update Command

```
/roblox-update
```

Or say naturally: *"update roblox skill knowledge"*, *"refresh roblox dev skill"*

### Update Protocol

```
Research → Fact-check → QnA with user → Apply changes → Full audit → Update timestamp
```

Every update follows the same rigorous process:
- Deep research from official Roblox sources
- Cross-check against existing reference files
- Discussion with user for all decisions
- Full fact-check audit after changes
- Timestamp update in `metadata.json`

---

## 📋 What's Covered (Mid-2026)

| Topic | Status | Details |
|-------|--------|---------|
| **Luau Language** | ✅ Current | Strict mode, types, generics, `task` library |
| **Architecture** | ✅ Current | Services, MVC, module patterns, Rojo |
| **DataStore** | ✅ April 2026 | ProfileStore, session locking, storage limits, overage handling |
| **Networking** | ✅ Current | RemoteEvents, replication, Input Action System |
| **Security** | ✅ June 2026 | Server Authority Client Beta, BanAsync, device blocking |
| **Performance** | ✅ Current | Parallel Luau, Microprofiler, memory management |
| **MCP** | ✅ June 2026 | Built-in native server, 26 tools, ScriptDebuggerService |
| **UI Systems** | ✅ June 2026 | UIShadow, StyleQuery, per-corner UICorner |
| **Migration** | ✅ June 2026 | 12+ deprecated APIs, Scoped UserIds (Oct 2026) |
| **Monetization** | ✅ May 2026 | Transfers API, Roblox Plus, publishing fee |

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Research-based only** — all content must be grounded in official Roblox documentation
2. **No improvisation** — if you're unsure, flag it as a question rather than guessing
3. **Update `metadata.json`** — bump version and add a changelog entry
4. **Run evals** — verify trigger accuracy with `evals/evals.json`
5. **Keep format consistent** — `--!strict` in all code examples, PascalCase for APIs
6. **Credit sources** — cite official docs for any new information

### How to Contribute

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/new-reference`)
3. Make your changes following the guidelines above
4. Update `metadata.json` with your changes
5. Submit a Pull Request with a clear description

---

## 🙏 Credits & Sources

### Creator

Created by **[@msayib](https://github.com/MSayib)** through collaborative human + AI deep research.

> **Attribution Required**: If you fork, reproduce, or improve this skill, you
> **MUST** credit the original creator by including a link to this repository and
> the GitHub username [@msayib](https://github.com/MSayib) in your README or documentation.
> See [License](#-license) for details.

### Process

This skill was built through a rigorous, research-driven process:

1. **Deep Research** — Extensive web research across official Roblox documentation, DevForum announcements, and API changelogs
2. **Live Engine Verification** — All content verified against live Roblox Studio Engine v0.727.0 via MCP
3. **Fact-Checking** — 14-point audit covering every major claim in the knowledge base
4. **Dual-Platform Testing** — Verified on both Claude Code and Antigravity IDE
5. **Iterative Review** — Multiple rounds of human review and QnA decision-making
6. **Mid-2026 Freshness** — Includes all breaking changes, deprecations, and new features through June 2026

### Official Sources Used

| Source | URL | Usage |
|--------|-----|-------|
| **Roblox Creator Documentation** | https://create.roblox.com/docs | Primary API reference, tutorials, best practices |
| **Luau Language** | https://luau.org | Language specification, type system, standard library |
| **Roblox Lua Style Guide** | https://roblox.github.io/lua-style-guide/ | Naming conventions, formatting standards |
| **Roblox DevForum** | https://devforum.roblox.com | Release notes, announcements, community guidance |
| **Roblox Studio MCP** | Built-in to Roblox Studio | Live engine verification, tool reference |
| **ProfileStore** | https://madstudioroblox.github.io/ProfileStore/ | Community data framework documentation |

### Skills Format

The AI Skills format was pioneered by **[Anthropic](https://github.com/anthropics/skills)**.
This skill follows the Anthropic SKILL.md specification with YAML frontmatter and
progressive disclosure via reference files.

### Built with 🇮🇩

Made with ❤️ from Indonesia.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

### Attribution Requirement

While the MIT License is permissive, **we kindly require** that any fork, reproduction,
or derivative work includes:

1. A credit to **[@msayib](https://github.com/MSayib)** as the original creator
2. A link back to this repository: `https://github.com/MSayib/roblox-dev-skill`
3. The original LICENSE file

Example attribution:
```markdown
Based on [roblox-dev-skill](https://github.com/MSayib/roblox-dev-skill) by [@msayib](https://github.com/MSayib)
```

---

---

# 🇮🇩 Dokumentasi Bahasa Indonesia

## Apa Ini?

Sebuah knowledge base terstruktur sebanyak **5.100+ baris** yang mengubah AI coding assistant Anda menjadi **ahli pengembangan Roblox**. Saat Anda menyebut topik apa pun yang berkaitan dengan Roblox, skill ini otomatis aktif dan memberikan AI pengetahuan yang mendalam, akurat, dan telah diverifikasi melalui riset.

Dibangun melalui **riset mendalam kolaboratif manusia + AI** — setiap baris didasarkan pada dokumentasi resmi Roblox, diverifikasi terhadap engine live (v727), dan di-fact-check melalui proses audit yang ketat.

---

## 🚀 Instalasi

### Claude Code (Direkomendasikan)

```bash
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/MSayib/roblox-dev-skill.git roblox-dev
```

### Antigravity IDE / Gemini

```bash
# Opsi A: Symlink (sumber tunggal)
mkdir -p ~/.gemini/config/skills
ln -s ~/.claude/skills/roblox-dev ~/.gemini/config/skills/roblox-dev

# Opsi B: Install langsung
mkdir -p ~/.gemini/config/skills
cd ~/.gemini/config/skills
git clone https://github.com/MSayib/roblox-dev-skill.git roblox-dev
```

### Verifikasi

Skill aktif jika terlihat di daftar skills AI assistant Anda. Uji dengan bertanya:

> *"Buatkan sistem koleksi koin untuk game Roblox saya"*

Skill harus otomatis aktif dan menghasilkan kode Luau server-authoritative dengan `--!strict` mode.

---

## 💡 Penggunaan

### Auto-Trigger

Skill otomatis aktif saat Anda menyebut topik Roblox:

```
Roblox · Luau · Roblox Studio · DataStoreService · RemoteEvent
ServerScriptService · ReplicatedStorage · ProfileStore · obby · tycoon
```

**TIDAK** akan trigger untuk: Unity, Unreal Engine, Godot, pengembangan web/mobile.

### Routing Otomatis

| Maksud Anda | File Referensi |
|-------------|----------------|
| Sintaks Luau, tipe, penamaan | `luau-fundamentals.md` |
| Arsitektur proyek, pola | `project-structure.md` |
| Simpan/muat data, DataStore | `datastore-persistence.md` |
| Komunikasi client-server | `networking.md` |
| Keamanan, anti-exploit | `security-hardening.md` |
| Performa, optimisasi | `performance-optimization.md` |
| MCP tools Roblox Studio | `mcp-integration.md` |
| UI, GUI, menu, HUD | `ui-systems.md` |
| Migrasi API deprecated | `legacy-migration.md` |
| Monetisasi, donasi | `monetization.md` |

---

## 🔌 Integrasi MCP (Roblox Studio)

Skill ini dirancang untuk bekerja dengan **Roblox Studio MCP server** bawaan (native, mid-2026+).

### Setup

1. Buka **Roblox Studio**
2. Buka widget **Assistant**
3. Klik **"Manage MCP Servers"**
4. **Aktifkan** MCP server bawaan
5. Hubungkan AI assistant Anda (Claude Code, Antigravity IDE, dll.)

### Alur Kerja yang Direkomendasikan

```
1. get_studio_state        → Cek project yang terbuka
2. search_game_tree        → Pahami struktur proyek
3. script_read             → Baca script sebelum modifikasi
4. multi_edit              → Terapkan perubahan
5. execute_luau            → Validasi kode
6. start_stop_play         → Jalankan playtest
7. get_console_output      → Periksa error
```

---

## 🔄 Sistem Update Knowledge

Skill memiliki **sistem pemantauan freshness otomatis**:

1. Setiap trigger, AI cek timestamp `last_updated` di `metadata.json`
2. Jika sudah >**7 hari**, AI akan mengingatkan untuk update
3. **AI tidak pernah auto-update** — selalu minta persetujuan Anda

### Perintah Update Manual

```
/roblox-update
```

Atau ucapkan: *"update knowledge roblox dev skill"*

### Protokol Update

```
Riset → Fact-check → Diskusi QnA dengan user → Terapkan → Audit → Update timestamp
```

---

## 🙏 Kredit & Sumber

### Pembuat

Dibuat oleh **[@msayib](https://github.com/MSayib)** 🇮🇩 melalui riset mendalam kolaboratif manusia + AI.

> **Atribusi Wajib**: Jika Anda fork, reproduce, atau improve skill ini, Anda
> **WAJIB** mencantumkan kredit ke pembuat asli dengan menyertakan link ke
> repositori ini dan username GitHub [@msayib](https://github.com/MSayib).

### Sumber Resmi

| Sumber | URL |
|--------|-----|
| Roblox Creator Documentation | https://create.roblox.com/docs |
| Luau Language | https://luau.org |
| Roblox Lua Style Guide | https://roblox.github.io/lua-style-guide/ |
| Roblox DevForum | https://devforum.roblox.com |
| ProfileStore | https://madstudioroblox.github.io/ProfileStore/ |

### Format Skills

Format AI Skills dipelopori oleh **[Anthropic](https://github.com/anthropics/skills)**.

---

<p align="center">
  Made with ❤️ from Indonesia 🇮🇩
  <br/>
  <a href="https://github.com/MSayib/roblox-dev-skill">⭐ Star this repo if it helps!</a>
</p>
