# `~/RobloxDocs/`: the local API reference

[← README](../README.md)

The skill integrates with a **local API reference hub** for token-efficient lookups:

```
~/RobloxDocs/
├── RobloxAPI/
│   ├── dumps/                         # Full-API-Dump.json per version
│   │   └── latest.json → (symlink)
│   ├── classes/                       # one JSON per class (940 on 0.742, ~2 KB median)
│   ├── enums/                         # one JSON per enum (648 on 0.742)
│   ├── services/                      # service classes (263 on 0.742)
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

**Why?** Re-measured 2026-10-01 on 0.741.19.7411056: the full dump is **8,356,896 bytes**, while the
931 split class files are **101 B min / 2,054 B median / 4,782 B mean / 104,956 B max**. A typical
class lookup therefore reads about **0.02%** of the dump. (An earlier README claimed "845× smaller"
from a "~10KB" class file; neither number is reproducible — the median class file is ~2 KB.
`SKILL.md` carries the command that re-measures both, including the `stat -L` needed to follow the
`latest.json` symlink instead of measuring the link itself.)

## Setting up and refreshing RobloxDocs

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
