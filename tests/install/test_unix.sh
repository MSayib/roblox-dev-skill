#!/usr/bin/env bash
# Functional tests for install.sh. Every scenario runs against a throwaway $HOME, so this is safe
# to run on your own machine:
#
#   bash tests/install/test_unix.sh            # from the repository root
#
# Runs on macOS (use /bin/bash to test 3.2), Linux, and Git Bash on Windows — where `ln -s` makes
# copies, so assertions accept either a link or a marked copy and link-only scenarios are skipped.
# Network is only needed for the RobloxDocs scenario; set SKIP_NETWORK=1 to skip it.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$REPO/install.sh"
SKILL=roblox-dev-skill
MARKER=.roblox-dev-skill-install
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rds-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0; SKIP=0

ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; return 0; }
skip() { SKIP=$((SKIP + 1)); printf '  skip  %s\n' "$1"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1" "$2"; fi; }
section() { printf '\n## %s\n' "$1"; }

# Fresh throwaway home per scenario.
fresh() { H="$WORK/$1"; rm -rf "$H"; mkdir -p "$H"; STORE="$H/.local/share/$SKILL"; PAYLOAD="$STORE/$SKILL"; }
run()   { HOME="$H" XDG_DATA_HOME="" NO_COLOR=1 bash "$INSTALLER" --source "$REPO" "$@" > "$H.log" 2>&1; }

# Installed = a symlink to the store, or a copy carrying the install marker.
installed() {
    local p="$1/$SKILL"
    if [ -L "$p" ]; then [ "$(readlink "$p")" = "$PAYLOAD" ]; else [ -f "$p/$MARKER" ] && [ -f "$p/SKILL.md" ]; fi
}
# every path plus every entry's attributes — but not "..", which changes when this suite writes its log
tree_hash() { (cd "$H" && find . -print | LC_ALL=C sort; ls -lAR "$H" 2>/dev/null) | cksum; }

# Can this platform make real symlinks? (Git Bash without winsymlinks cannot.)
probe="$WORK/probe"; mkdir -p "$probe/t"; ln -s "$probe/t" "$probe/l" 2>/dev/null || true
if [ -L "$probe/l" ]; then SYMLINKS=true; else SYMLINKS=false; fi
echo "install.sh tests — bash $BASH_VERSION on $(uname -s); symlinks: $SYMLINKS"

# ────────────────────────────────────────────────────────────────────────
section "fresh install, explicit agents"
fresh a; mkdir -p "$H/.claude"
run --agents universal,claude,antigravity --no-docs -y; rc=$?
check "exits 0"                               "[ $rc -eq 0 ]"
check "universal installed"                   "installed '$H/.agents/skills'"
check "claude installed"                      "installed '$H/.claude/skills'"
check "antigravity installed"                 "installed '$H/.gemini/config/skills'"
check "payload has SKILL.md + references"     "[ -f '$PAYLOAD/SKILL.md' ] && [ -d '$PAYLOAD/references' ]"
check "payload excludes evals/ tools/ install.*" "[ ! -e '$PAYLOAD/evals' ] && [ ! -e '$PAYLOAD/tools' ] && [ ! -e '$PAYLOAD/install.sh' ]"
check "SKILL.md name matches folder (spec)"   "grep -q '^name: $SKILL\$' '$PAYLOAD/SKILL.md'"
check "manifest has 3 entries"                "[ \$(wc -l < '$STORE/manifest.tsv') -eq 3 ]"
check "installer kept for uninstall"          "[ -x '$STORE/install.sh' ]"

section "idempotent re-run"
run --agents universal,claude,antigravity --no-docs -y; rc=$?
check "exits 0"                               "[ $rc -eq 0 ]"
check "manifest still 3 entries"              "[ \$(wc -l < '$STORE/manifest.tsv') -eq 3 ]"

section "dedupe: agents that read ~/.agents/skills get no second link"
fresh b
run --agents universal,cursor,copilot,gemini --no-docs -y
check "universal installed"                   "installed '$H/.agents/skills'"
check "cursor NOT linked natively"            "[ ! -e '$H/.cursor/skills/$SKILL' ]"
check "copilot NOT linked natively"           "[ ! -e '$H/.copilot/skills/$SKILL' ]"
check "gemini NOT linked natively"            "[ ! -e '$H/.gemini/skills/$SKILL' ]"
fresh b2
run --agents universal,cursor --no-dedupe --no-docs -y
check "--no-dedupe links cursor too"          "installed '$H/.cursor/skills'"

section "detection defaults when non-interactive"
fresh c; mkdir -p "$H/.kiro"
run --no-docs < /dev/null
check "universal by default"                  "installed '$H/.agents/skills'"
check "detected kiro linked"                  "installed '$H/.kiro/skills'"

section "piped like curl | bash"
fresh d
HOME="$H" XDG_DATA_HOME="" NO_COLOR=1 bash -s -- --source "$REPO" --agents universal --no-docs < "$INSTALLER" > "$H.log" 2>&1; rc=$?
check "exits 0 when read from stdin"          "[ $rc -eq 0 ] && installed '$H/.agents/skills'"

section "conflicts are backed up, never deleted"
fresh e
mkdir -p "$H/.gemini/config/skills" "$H/.claude/skills"
cp -R "$REPO" "$H/.gemini/config/skills/$SKILL"                     # a manual clone
cp -R "$REPO" "$H/.claude/skills/roblox-dev"                        # legacy, non-spec folder name
run --agents universal,claude,antigravity --no-docs -y
check "manual clone replaced by install"      "installed '$H/.gemini/config/skills'"
check "legacy roblox-dev moved out"           "[ ! -e '$H/.claude/skills/roblox-dev' ]"
check "both backed up in the store"           "[ \$(find '$STORE/backups' -name 'roblox-dev*' -maxdepth 30 | wc -l) -ge 2 ]"
check "no duplicate SKILL.md in skills dirs"  "[ \$(find -L '$H/.claude' '$H/.gemini' '$H/.agents' -name SKILL.md -not -path '*/references/*' | wc -l) -eq 3 ]"

section "foreign links are left alone"
if [ "$SYMLINKS" = true ]; then
    fresh f; mkdir -p "$H/.claude/skills" "$WORK/precious"; echo keep > "$WORK/precious/keep.txt"
    ln -s "$WORK/precious" "$H/.claude/skills/$SKILL"
    run --agents claude --no-docs -y
    check "foreign link untouched without --force" "[ \"\$(readlink '$H/.claude/skills/$SKILL')\" = '$WORK/precious' ]"
    run --agents claude --no-docs -y --force
    check "--force replaces it"                "installed '$H/.claude/skills'"
    check "and the foreign target survives"    "[ -f '$WORK/precious/keep.txt' ]"
else
    skip "foreign-link scenarios (no real symlinks on this platform)"
fi

section "--dry-run changes nothing"
fresh g; mkdir -p "$H/.claude"
before=$(tree_hash); run --agents all --docs -y --dry-run; rc=$?; after=$(tree_hash)
check "exits 0"                               "[ $rc -eq 0 ]"
check "file tree unchanged"                   "[ '$before' = '$after' ]"

section "--copy, then --update refreshes copies"
fresh h
run --agents kiro --copy --no-docs -y
check "copy with marker"                      "[ ! -L '$H/.kiro/skills/$SKILL' ] && [ -f '$H/.kiro/skills/$SKILL/$MARKER' ]"
echo STALE > "$H/.kiro/skills/$SKILL/references/luau-fundamentals.md"
run --update; rc=$?
check "--update exits 0"                      "[ $rc -eq 0 ]"
check "stale copy refreshed"                  "! grep -q '^STALE' '$H/.kiro/skills/$SKILL/references/luau-fundamentals.md'"
check "update did not opt into RobloxDocs"    "[ ! -e '$H/RobloxDocs' ]"

section "custom --path, with a space"
fresh i
run --agents universal --path "$H/my skills" --no-docs -y
check "installed into custom path"            "installed '$H/my skills'"

section "uninstall removes only what it made"
fresh j; mkdir -p "$H/.roo/skills" "$WORK/precious2"; echo keep > "$WORK/precious2/keep.txt"
run --agents universal,claude --no-docs -y
[ "$SYMLINKS" = true ] && ln -s "$WORK/precious2" "$H/.roo/skills/$SKILL"
run --uninstall; rc=$?
check "exits 0"                               "[ $rc -eq 0 ]"
check "our installs removed"                  "[ ! -e '$H/.agents/skills/$SKILL' ] && [ ! -e '$H/.claude/skills/$SKILL' ]"
check "stored skill removed"                  "[ ! -e '$PAYLOAD' ]"
if [ "$SYMLINKS" = true ]; then
    check "foreign link survives"             "[ -L '$H/.roo/skills/$SKILL' ] && [ -f '$WORK/precious2/keep.txt' ]"
fi

section "argument validation"
fresh k
run --agents claude,nope -y; rc=$?
check "unknown agent rejected"                "[ $rc -ne 0 ] && grep -q \"unknown agent 'nope'\" '$H.log'"
run --bogus; rc=$?
check "unknown option rejected"               "[ $rc -ne 0 ]"
HOME="$H" bash "$INSTALLER" --list > "$H.log" 2>&1
check "--list prints every agent"             "[ \$(grep -cE '^(universal|claude|antigravity|kiro|codex|gemini|cursor|copilot|opencode|roo|goose|junie|amp)' '$H.log') -ge 13 ]"

section "failures are reported, never silent"
fresh l; mkdir -p "$H/.local/share"; touch "$H/.local/share/$SKILL"    # a FILE where the store must go
run --agents universal --no-docs -y; rc=$?
check "non-zero exit"                         "[ $rc -ne 0 ]"
check "names the failure"                     "grep -q 'unexpected failure at line' '$H.log'"

section "RobloxDocs (network)"
if [ "${SKIP_NETWORK:-0}" = 1 ]; then
    skip "RobloxDocs download (SKIP_NETWORK=1)"
elif ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
    skip "RobloxDocs (no Python)"
else
    fresh m
    run --agents universal --docs -y; rc=$?
    check "exits 0"                           "[ $rc -eq 0 ]"
    check "config points at installed skill"  "grep -q 'SKILL_REFS=.*$SKILL/references' '$H/RobloxDocs/config'"
    check "dump split into >900 classes"      "[ \$(ls '$H/RobloxDocs/RobloxAPI/classes' | wc -l) -gt 900 ]"
    check "example audit reports 0 defects"   "grep -q 'DEFECTS: 0' '$H.log'"
    check "documented command works"          "HOME='$H' bash '$H/RobloxDocs/scripts/roblox-api-monitor.sh' 2>&1 | grep -q 'Already up-to-date'"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
