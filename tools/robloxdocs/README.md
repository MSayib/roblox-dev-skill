# RobloxDocs — local Roblox API reference hub

Installed by [roblox-dev-skill](https://github.com/MSayib/roblox-dev-skill)'s `install.sh`.
The skill reads these files to answer API questions from ~2 KB of local JSON instead of an
8 MB dump or a web request.

```
~/RobloxDocs/
├── config                      # SKILL_REFS=…  AUDIT_MODE=warn|strict|off
├── RobloxAPI/
│   ├── .current-version        # {"version", "updatedAt", "checkedAt", …}
│   ├── dumps/                  # Full-API-Dump.json per engine version; latest.json → newest
│   ├── diffs/                  # member-level diffs between consecutive dumps
│   ├── classes/<Name>.json     # one file per class
│   ├── enums/<Name>.json       # one file per enum
│   ├── services/<Name>.json    # classes whose name ends in "Service"
│   ├── deprecated/<Name>.json  # classes tagged Deprecated
│   └── *-index.json            # class / enum / service / deprecated indexes
└── scripts/
    ├── roblox-api-monitor.sh   # check → download → validate → diff → split → audit
    ├── split-api-dump.py       # the splitter (split-api-dump.sh is a compatibility shim)
    ├── diff-api-dumps.py       # member-level diff with grep-back into the skill's docs
    └── audit-skill-examples.py # checks the skill's code examples against the dump
```

Requires **bash 3.2+, curl or wget, and python3**. No jq, zsh or bc.

## Refresh to the newest engine version

```bash
~/RobloxDocs/scripts/roblox-api-monitor.sh
```

Roblox ships roughly weekly. The skill will tell you when the local dump looks stale; it never
refreshes on its own.

## Look things up

```bash
cat ~/RobloxDocs/RobloxAPI/classes/MeshPart.json
python3 -c "import json; print([m for m in json.load(open('$HOME/RobloxDocs/RobloxAPI/classes/MeshPart.json'))['Members'] if m['Name']=='CollisionFidelity'])"
jq '.Members[] | select(.Name == "CollisionFidelity")' ~/RobloxDocs/RobloxAPI/classes/MeshPart.json   # if you have jq
```

Read **`Security`, `Capabilities` and `Tags`** together — a member with
`{"Read": "None", "Write": "PluginSecurity"}` can be read by a Script but not written.
