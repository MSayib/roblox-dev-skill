#!/usr/bin/env bash
# End-to-end: install the skill the way a user does, then prove an agent actually loads it.
#
#   bash tests/e2e/test_install_e2e.sh            # install from this checkout (--source)
#   bash tests/e2e/test_install_e2e.sh --github   # the README one-liner, downloading ROBLOX_SKILL_REF
#                                                 # (default master) from GitHub
#
# Everything happens in a throwaway $HOME: your real agent folders are never touched. Steps:
#   1. install for Claude Code + the universal ~/.agents/skills link, no RobloxDocs
#   2. the payload is complete (SKILL.md, references/, docs/) and passes the official skills-ref
#      validator (skipped if uvx is missing)
#   3. Claude Code, pointed at the throwaway config with CLAUDE_CONFIG_DIR, lists roblox-dev-skill at
#      startup; an empty config dir does not (negative control). Discovery needs no login. Skipped
#      if the claude CLI is missing.
#   4. uninstall leaves no link, no payload, no manifest
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
MODE=source
[ "${1:-}" = --github ] && MODE=github
SKILL=roblox-dev-skill
pass=0 fail=0 skip=0
H="$(mktemp -d "${TMPDIR:-/tmp}/rds-e2e.XXXXXX")"
trap 'rm -rf "$H" "$H.empty"' EXIT

check() { if eval "$2" >/dev/null 2>&1; then echo "  ok    $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
skipped() { echo "  skip  $1"; skip=$((skip+1)); }

install() {
    if [ "$MODE" = github ]; then
        local ref="${ROBLOX_SKILL_REF:-master}"
        curl -fsSL "https://raw.githubusercontent.com/MSayib/roblox-dev-skill/$ref/install.sh" |
            HOME="$H" XDG_DATA_HOME="" NO_COLOR=1 ROBLOX_SKILL_REF="$ref" bash -s -- "$@"
    else
        HOME="$H" XDG_DATA_HOME="" NO_COLOR=1 bash "$REPO/install.sh" --source "$REPO" "$@"
    fi
}

skills_at_startup() { # $1 = config dir; prints the roblox skills Claude Code lists in its init event
    (cd "$1/.." && CLAUDE_CONFIG_DIR="$1" claude -p "ok" --output-format stream-json --verbose --strict-mcp-config 2>/dev/null) |
        python3 -c 'import sys,json
for l in sys.stdin:
    try: e=json.loads(l)
    except ValueError: continue
    if e.get("type")=="system" and e.get("subtype")=="init":
        print(" ".join(s for s in e.get("skills",[]) if "roblox" in str(s)))'
}

echo "== install ($MODE)"
install --agents claude,universal --no-docs --yes > "$H.log" 2>&1
rc=$?
check "installer exits 0"                         "[ $rc -eq 0 ]"
PAYLOAD="$H/.local/share/$SKILL/$SKILL"
check "Claude Code link resolves to SKILL.md"     "[ -f '$H/.claude/skills/$SKILL/SKILL.md' ]"
check "universal link resolves to SKILL.md"       "[ -f '$H/.agents/skills/$SKILL/SKILL.md' ]"
check "payload has references/ (14 files)"        "[ \$(ls '$PAYLOAD/references' | wc -l) -eq 14 ]"
check "payload has docs/ the README links to"     "[ -f '$PAYLOAD/docs/installation.md' ]"
check "payload excludes tools/ and evals/"        "[ ! -e '$PAYLOAD/tools' ] && [ ! -e '$PAYLOAD/evals' ]"

if command -v uvx >/dev/null 2>&1; then
    check "official skills-ref validator passes"  "uvx -q --from 'git+https://github.com/agentskills/agentskills#subdirectory=skills-ref' skills-ref validate '$PAYLOAD'"
else
    skipped "skills-ref validator (uvx not installed)"
fi

if command -v claude >/dev/null 2>&1; then
    found="$(skills_at_startup "$H/.claude")"
    check "Claude Code lists $SKILL at startup"   "[ '$found' = '$SKILL' ]"
    mkdir -p "$H.empty/.claude"
    control="$(skills_at_startup "$H.empty/.claude")"
    check "negative control: empty config lists none" "[ -z '$control' ]"
else
    skipped "Claude Code discovery (claude CLI not installed)"
fi

echo "== uninstall"
HOME="$H" XDG_DATA_HOME="" NO_COLOR=1 bash "$H/.local/share/$SKILL/install.sh" --uninstall --yes > "$H.log" 2>&1
rc=$?
check "uninstall exits 0"                         "[ $rc -eq 0 ]"
check "Claude Code link removed"                  "[ ! -e '$H/.claude/skills/$SKILL' ] && [ ! -L '$H/.claude/skills/$SKILL' ]"
check "universal link removed"                    "[ ! -e '$H/.agents/skills/$SKILL' ] && [ ! -L '$H/.agents/skills/$SKILL' ]"
check "payload removed"                           "[ ! -e '$PAYLOAD' ]"

echo
echo "$pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
