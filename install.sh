#!/usr/bin/env bash
# roblox-dev-skill installer — https://github.com/MSayib/roblox-dev-skill
#
#   curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.sh | bash
#
# Installs the skill once and links it into every agent you pick, then (optionally) sets up
# ~/RobloxDocs with a freshly downloaded and split Roblox API dump. No git clone needed.
#
# Works with bash 3.2+ (macOS default), on macOS, Linux, WSL and Git Bash for Windows.
# Needs: curl or wget, tar. RobloxDocs additionally needs python3.
#
# Run with --help for every option.

# Everything lives inside main(), which is only called on the very last line. If the download is
# cut off halfway, bash sees an unterminated function and runs nothing.

REPO_OWNER="MSayib"
REPO_NAME="roblox-dev-skill"
SKILL_NAME="roblox-dev-skill"       # must equal the SKILL.md `name` and the folder name (agentskills.io spec)
DEFAULT_REF="master"
MARKER=".roblox-dev-skill-install"  # present in every copy this installer makes; nothing else is ever removed
TAB="$(printf '\t')"

main() {
set -Eeuo pipefail
# Never die silently: any unexpected failure names the line and the command.
trap 'die "unexpected failure at line $LINENO: $BASH_COMMAND"' ERR

# ─── Options ────────────────────────────────────────────────────────────
local REF="${ROBLOX_SKILL_REF:-$DEFAULT_REF}" SOURCE_DIR="" AGENTS_ARG="" CUSTOM_PATHS="" YES=false DRY=false
local FORCE=false FORCE_COPY=false DOCS_MODE=ask ACTION=install PURGE_DOCS=false NO_DEDUPE=false
if [ "${ROBLOX_SKILL_LINK:-}" = copy ]; then FORCE_COPY=true; fi

while [ $# -gt 0 ]; do
    case "$1" in
        --agents)      AGENTS_ARG="$2"; shift 2 ;;
        --agents=*)    AGENTS_ARG="${1#*=}"; shift ;;
        --path)        CUSTOM_PATHS="$CUSTOM_PATHS$2"$'\n'; shift 2 ;;
        --path=*)      CUSTOM_PATHS="$CUSTOM_PATHS${1#*=}"$'\n'; shift ;;
        -y|--yes)      YES=true; shift ;;
        --dry-run)     DRY=true; shift ;;
        --force)       FORCE=true; shift ;;
        --copy)        FORCE_COPY=true; shift ;;
        --docs)        DOCS_MODE=yes; shift ;;
        --no-docs)     DOCS_MODE=no; shift ;;
        --docs-only)   ACTION=docs-only; DOCS_MODE=yes; shift ;;
        --ref)         REF="$2"; shift 2 ;;
        --ref=*)       REF="${1#*=}"; shift ;;
        --source)      SOURCE_DIR="$2"; shift 2 ;;
        --source=*)    SOURCE_DIR="${1#*=}"; shift ;;
        --no-dedupe)   NO_DEDUPE=true; shift ;;
        --update)      ACTION=update; shift ;;
        --uninstall)   ACTION=uninstall; shift ;;
        --purge-docs)  PURGE_DOCS=true; shift ;;
        --list)        ACTION=list; shift ;;
        -h|--help)     usage; return 0 ;;
        *) die "unknown option: $1  (try --help)" ;;
    esac
done

# ─── Paths ──────────────────────────────────────────────────────────────
STORE="${ROBLOX_SKILL_STORE:-${XDG_DATA_HOME:-$HOME/.local/share}/$REPO_NAME}"
PAYLOAD="$STORE/$SKILL_NAME"
MANIFEST="$STORE/manifest.tsv"
DOCS_HOME="${ROBLOX_DOCS_HOME:-$HOME/RobloxDocs}"
STAMP="$(date +%Y%m%d-%H%M%S)"
TTY_OK=false
if [ "$YES" = false ] && { : </dev/tty; } 2>/dev/null; then TTY_OK=true; fi
setup_colors

case "$ACTION" in
    list)      list_agents; return 0 ;;
    uninstall) do_uninstall; return 0 ;;
esac

banner
preflight

local SRC
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rds-install.XXXXXX")"
trap 'rm -rf "${WORK:-}"' EXIT
SRC="$(obtain_source "$WORK")"
validate_source "$SRC"
local VERSION; VERSION="$(skill_version "$SRC")"
ok "Skill $SKILL_NAME v$VERSION ($( [ -n "$SOURCE_DIR" ] && echo "local source" || echo "ref $REF"))"

if [ "$ACTION" = docs-only ]; then
    install_docs "$SRC"
    return 0
fi

# ─── Choose targets ─────────────────────────────────────────────────────
local SELECTED
if [ "$ACTION" = update ]; then
    SELECTED=""   # update re-uses the manifest; no agent selection
elif [ -n "$AGENTS_ARG" ]; then
    SELECTED="$(parse_agents_arg "$AGENTS_ARG")"
elif [ "$TTY_OK" = true ]; then
    SELECTED="$(wizard)"
    case "$SELECTED" in *"@custom:"*)
        CUSTOM_PATHS="$CUSTOM_PATHS${SELECTED#*@custom:}"$'\n'
        SELECTED="${SELECTED%%@custom:*}" ;;
    esac
else
    SELECTED="$(default_selection)"
    if [ -n "$SELECTED" ]; then
        info "Non-interactive run: using detected defaults ($(echo $SELECTED | tr ' ' ','))."
    fi
fi

if [ "$DOCS_MODE" = ask ] && [ "$ACTION" = update ]; then
    # an update refreshes RobloxDocs only if it was set up before
    if [ -f "$DOCS_HOME/scripts/roblox-api-monitor.sh" ]; then DOCS_MODE=yes; else DOCS_MODE=no; fi
fi
if [ "$DOCS_MODE" = ask ]; then
    if [ "$TTY_OK" = true ]; then
        if confirm "Also set up ~/RobloxDocs (downloads the ~8 MB Roblox API dump; needs python3)?" y; then
            DOCS_MODE=yes; else DOCS_MODE=no; fi
    else
        DOCS_MODE=yes
    fi
fi

local TARGETS
if [ "$ACTION" = update ]; then
    TARGETS="$(manifest_targets)"
    [ -n "$TARGETS" ] || die "nothing to update: no previous install found in $MANIFEST"
else
    TARGETS="$(resolve_targets "$SELECTED" "$CUSTOM_PATHS")"
    [ -n "$TARGETS" ] || die "no agents selected — nothing to install"
fi

plan_summary "$TARGETS"
if [ "$TTY_OK" = true ] && [ "$ACTION" != update ]; then
    confirm "Proceed?" y || { info "Cancelled — nothing was changed."; return 0; }
fi

# ─── Install ────────────────────────────────────────────────────────────
install_payload "$SRC" "$VERSION"
local line dir
while IFS= read -r line; do
    [ -n "$line" ] || continue
    dir="${line#*$TAB}"
    link_into "$dir"
done <<EOF
$TARGETS
EOF
warn_legacy_installs "$TARGETS"

if [ "$DOCS_MODE" = yes ]; then install_docs "$SRC"; fi
finish "$TARGETS" "$VERSION"
}

# ════════════════════════════════════════════════════════════════════════
# Agent registry. Every path below was checked against that agent's own documentation on
# 2026-09-25 — see the URL in agent_docs. "Reads ~/.agents/skills" is what lets one install cover
# many agents; agents that do NOT read it need their own link.
# ════════════════════════════════════════════════════════════════════════
AGENT_IDS="universal claude antigravity antigravity-cli kiro codex gemini cursor copilot opencode roo goose junie amp"

agent_label() {
    case "$1" in
        universal)       echo "Universal ~/.agents/skills" ;;
        claude)          echo "Claude Code" ;;
        antigravity)     echo "Antigravity (2.0 / IDE)" ;;
        antigravity-cli) echo "Antigravity CLI" ;;
        kiro)            echo "Kiro" ;;
        codex)           echo "Codex (OpenAI)" ;;
        gemini)          echo "Gemini CLI" ;;
        cursor)          echo "Cursor" ;;
        copilot)         echo "GitHub Copilot (CLI / VS Code)" ;;
        opencode)        echo "OpenCode" ;;
        roo)             echo "Roo Code" ;;
        goose)           echo "Goose" ;;
        junie)           echo "Junie (JetBrains)" ;;
        amp)             echo "Amp" ;;
    esac
}

agent_dir() {
    case "$1" in
        universal|codex|goose) echo "$HOME/.agents/skills" ;;
        claude)                echo "$HOME/.claude/skills" ;;
        antigravity)           echo "$HOME/.gemini/config/skills" ;;
        antigravity-cli)       echo "$HOME/.gemini/antigravity-cli/skills" ;;
        kiro)                  echo "$HOME/.kiro/skills" ;;
        gemini)                echo "$HOME/.gemini/skills" ;;
        cursor)                echo "$HOME/.cursor/skills" ;;
        copilot)               echo "$HOME/.copilot/skills" ;;
        opencode)              echo "$HOME/.config/opencode/skills" ;;
        roo)                   echo "$HOME/.roo/skills" ;;
        junie)                 echo "$HOME/.junie/skills" ;;
        amp)                   echo "$HOME/.config/amp/skills" ;;
    esac
}

agent_docs() {
    case "$1" in
        universal)       echo "https://agentskills.io/client-implementation/adding-skills-support" ;;
        claude)          echo "https://code.claude.com/docs/en/skills" ;;
        antigravity|antigravity-cli) echo "https://antigravity.google/docs/skills/" ;;
        kiro)            echo "https://kiro.dev/docs/skills/" ;;
        codex)           echo "https://developers.openai.com/codex/skills/" ;;
        gemini)          echo "https://geminicli.com/docs/cli/skills/" ;;
        cursor)          echo "https://cursor.com/docs/context/skills" ;;
        copilot)         echo "https://docs.github.com/en/copilot/concepts/agents/about-agent-skills" ;;
        opencode)        echo "https://opencode.ai/docs/skills/" ;;
        roo)             echo "https://docs.roocode.com/features/skills" ;;
        goose)           echo "https://block.github.io/goose/docs/guides/context-engineering/using-skills/" ;;
        junie)           echo "https://junie.jetbrains.com/docs/agent-skills.html" ;;
        amp)             echo "https://ampcode.com/docs/customize/skills" ;;
    esac
}

# Agents whose documented discovery path includes ~/.agents/skills.
agent_reads_universal() {
    case "$1" in codex|gemini|cursor|copilot|opencode|roo|goose|junie|amp) return 0 ;; *) return 1 ;; esac
}

UNIVERSAL_READERS="Codex, Gemini CLI, Cursor, GitHub Copilot, OpenCode, Roo Code, Goose, Junie, Amp"

have() { command -v "$1" >/dev/null 2>&1; }

# Detection only drives the default selection. Being wrong costs a checkbox, nothing else.
agent_detected() {
    case "$1" in
        universal)       [ -d "$HOME/.agents" ] ;;
        claude)          have claude || [ -d "$HOME/.claude" ] ;;
        antigravity)     [ -d "$HOME/.gemini/config" ] || [ -d "/Applications/Antigravity.app" ] || have antigravity ;;
        antigravity-cli) [ -d "$HOME/.gemini/antigravity-cli" ] ;;
        kiro)            have kiro || [ -d "$HOME/.kiro" ] ;;
        codex)           have codex || [ -d "$HOME/.codex" ] ;;
        gemini)          have gemini || [ -f "$HOME/.gemini/settings.json" ] ;;
        cursor)          have cursor || [ -d "$HOME/.cursor" ] ;;
        copilot)         have copilot || [ -d "$HOME/.copilot" ] ;;
        opencode)        have opencode || [ -d "$HOME/.config/opencode" ] ;;
        roo)             [ -d "$HOME/.roo" ] ;;
        goose)           have goose || [ -d "$HOME/.config/goose" ] ;;
        junie)           have junie || [ -d "$HOME/.junie" ] ;;
        amp)             have amp || [ -d "$HOME/.config/amp" ] ;;
        *) return 1 ;;
    esac
}

is_agent_id() { case " $AGENT_IDS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
in_list()     { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# Universal covers nine agents in one link; add a native link only for detected agents that
# do not read it.
default_selection() {
    local sel="universal" id
    for id in claude antigravity antigravity-cli kiro; do
        if agent_detected "$id"; then sel="$sel $id"; fi
    done
    echo "$sel"
}

parse_agents_arg() {
    local raw id out=""
    raw="$(echo "$1" | tr ',' ' ' | tr 'A-Z' 'a-z')"
    for id in $raw; do
        case "$id" in
            all)      out="$AGENT_IDS"; break ;;
            detected) out="$out $(default_selection)" ;;
            *) is_agent_id "$id" || die "unknown agent '$id'. Known: $AGENT_IDS (or all, detected)"
               out="$out $id" ;;
        esac
    done
    echo $out
}

# Turn a selection into "label<TAB>dir" lines: deduplicated by directory, and — unless
# --no-dedupe — dropping agents already covered by ~/.agents/skills (otherwise they list the
# skill twice).
resolve_targets() {
    local sel="$1" custom="$2" id dir out="" seen=" " p
    local universal_on=false
    if in_list universal "$sel" || in_list codex "$sel" || in_list goose "$sel"; then universal_on=true; fi
    for id in $AGENT_IDS; do
        in_list "$id" "$sel" || continue
        if [ "$universal_on" = true ] && [ "$NO_DEDUPE" = false ] && [ "$id" != universal ] \
           && [ "$id" != codex ] && [ "$id" != goose ] && agent_reads_universal "$id"; then
            continue
        fi
        dir="$(agent_dir "$id")"
        case "$seen" in *" $dir "*) continue ;; esac
        seen="$seen$dir "
        out="$out$(agent_label "$id")$TAB$dir"$'\n'
    done
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        p="$(expand_path "$p")"
        case "$seen" in *" $p "*) continue ;; esac
        seen="$seen$p "
        out="${out}Custom$TAB$p"$'\n'
    done <<EOF
$custom
EOF
    printf '%s' "$out"
}

expand_path() {
    local p="$1"
    # a literal "~" typed by the user (quoted, so the shell did not expand it) — matched on purpose
    # shellcheck disable=SC2088
    case "$p" in "~")   p="$HOME" ;; "~/"*) p="$HOME/${p#\~/}" ;; esac
    case "$p" in /*|[A-Za-z]:*) ;; *) p="$PWD/$p" ;; esac
    # a path that already ends in the skill folder means "put it here", not "nest it again"
    case "$p" in */"$SKILL_NAME") p="${p%/$SKILL_NAME}" ;; esac
    echo "${p%/}"
}

# ════════════════════════════════════════════════════════════════════════
# Wizard
# ════════════════════════════════════════════════════════════════════════
wizard() {
    local sel custom="" input tok i id mark det
    sel=" $(default_selection) "
    while true; do
        {
            echo ""
            echo "${B}Which agents should get the skill?${R}  ${D}(✓ = found on this machine)${R}"
            echo ""
            i=0
            for id in $AGENT_IDS; do
                i=$((i + 1))
                mark="[ ]"; in_list "$id" "$sel" && mark="${G}[x]${R}"
                det="";     agent_detected "$id" && det=" ${G}✓${R}"
                printf "  %s %2d) %-32s %s%s\n" "$mark" "$i" "$(agent_label "$id")" \
                    "${D}$(pretty "$(agent_dir "$id")")${R}" "$det"
                if [ "$id" = universal ]; then
                    printf "          ${D}read by %s${R}\n" "$UNIVERSAL_READERS"
                    echo ""
                fi
            done
            i=$((i + 1))
            mark="[ ]"; [ -n "$custom" ] && mark="${G}[x]${R}"
            printf "  %s %2d) %-32s %s\n" "$mark" "$i" "Custom path…" "${D}$(echo "$custom" | tr '\n' ' ')${R}"
            echo ""
            echo "  Toggle by number (e.g. ${B}2 3${R}), ${B}a${R} all, ${B}n${R} none, ${B}Enter${R} to continue."
        } >/dev/tty
        printf "  > " >/dev/tty
        IFS= read -r input </dev/tty || input=""
        [ -z "$input" ] && break
        for tok in $input; do
            case "$tok" in
                a|A) sel=" $AGENT_IDS " ;;
                n|N) sel=" "; custom="" ;;
                *[!0-9]*) echo "  ${Y}ignored '$tok'${R}" >/dev/tty ;;
                *)
                    if [ "$tok" -ge 1 ] && [ "$tok" -le "$i" ]; then
                        if [ "$tok" -eq "$i" ]; then
                            if [ -n "$custom" ]; then custom=""; else
                                printf "  Skills directory (the folder that CONTAINS skill folders): " >/dev/tty
                                IFS= read -r input </dev/tty || input=""
                                [ -n "$input" ] && custom="$input"
                            fi
                        else
                            id="$(echo $AGENT_IDS | cut -d' ' -f"$tok")"
                            if in_list "$id" "$sel"; then sel="$(echo "$sel" | sed "s/ $id / /")"; else sel="$sel$id "; fi
                        fi
                    else echo "  ${Y}no option $tok${R}" >/dev/tty; fi ;;
            esac
        done
    done
    # the wizard runs in a subshell, so custom paths travel back inside the selection string
    echo $sel "${custom:+@custom:$custom}"
}

confirm() {
    local q="$1" def="${2:-y}" ans hint="[Y/n]"
    [ "$def" = n ] && hint="[y/N]"
    [ "$TTY_OK" = true ] || { [ "$def" = y ]; return; }
    printf "\n%s %s " "$q" "$hint" >/dev/tty
    IFS= read -r ans </dev/tty || ans=""
    ans="$(echo "${ans:-$def}" | tr 'A-Z' 'a-z')"
    [ "$ans" = y ] || [ "$ans" = yes ]
}

# ════════════════════════════════════════════════════════════════════════
# Source: GitHub tarball (default) or a local checkout (--source)
# ════════════════════════════════════════════════════════════════════════
obtain_source() {
    local work="$1" url tarball top
    if [ -n "$SOURCE_DIR" ]; then
        [ -d "$SOURCE_DIR" ] || die "--source: not a directory: $SOURCE_DIR"
        (cd "$SOURCE_DIR" && pwd)
        return
    fi
    url="https://codeload.github.com/$REPO_OWNER/$REPO_NAME/tar.gz/$REF"
    tarball="$work/src.tar.gz"
    # ${REF} braced: bash 3.2 in a UTF-8 locale reads a non-ASCII byte right after a name as part
    # of the name, so an unbraced REF followed by an ellipsis looked up a variable called
    # REF\xe2... and died under set -u. tests/lint/check_sources.py now rejects that pattern.
    info "Downloading ${REPO_OWNER}/${REPO_NAME}@${REF}…" >&2
    download "$url" "$tarball" || die "download failed: $url  (is --ref '$REF' a real branch or tag?)"
    mkdir -p "$work/src"
    tar -xzf "$tarball" -C "$work/src" || die "could not extract the downloaded archive"
    for top in "$work/src"/*/; do echo "${top%/}"; return; done
    die "the archive was empty"
}

download() {
    if have curl; then curl -fsSL --retry 2 --max-time 120 -o "$2" "$1"
    elif have wget; then wget -q --timeout=120 -O "$2" "$1"
    else return 1; fi
}

validate_source() {
    local src="$1" name
    [ -f "$src/SKILL.md" ] || die "no SKILL.md in $src — not a $REPO_NAME checkout"
    [ -d "$src/references" ] || die "no references/ in $src"
    name="$(sed -n '1,15p' "$src/SKILL.md" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '\r"'"'"' ')"
    [ "$name" = "$SKILL_NAME" ] || die "SKILL.md name is '$name', expected '$SKILL_NAME'"
}

skill_version() {
    sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$1/metadata.json" 2>/dev/null | head -1
}

# ════════════════════════════════════════════════════════════════════════
# Install
# ════════════════════════════════════════════════════════════════════════
# The payload is what an agent reads. Repo-only material (evals, tools, installer) stays out.
install_payload() {
    local src="$1" version="$2" new="$STORE/.new.$$" old="$STORE/.old.$$" f
    step "Installing skill into $(pretty "$PAYLOAD")"
    if [ "$DRY" = true ]; then dry "copy SKILL.md, metadata.json, references/ … → $PAYLOAD"; return; fi
    mkdir -p "$STORE"
    rm -rf "$new"; mkdir -p "$new"
    for f in SKILL.md metadata.json LICENSE README.md CHANGELOG.md; do
        [ -f "$src/$f" ] && cp "$src/$f" "$new/"
    done
    cp -R "$src/references" "$new/references"
    printf 'managed-by=%s install.sh\nversion=%s\ninstalled=%s\n' "$REPO_NAME" "$version" "$STAMP" > "$new/$MARKER"
    # swap in place: links point at $PAYLOAD, so they follow the new content automatically
    [ -e "$PAYLOAD" ] && mv "$PAYLOAD" "$old"
    mv "$new" "$PAYLOAD"
    rm -rf "$old"
    [ -f "$src/install.sh" ] && cp "$src/install.sh" "$STORE/install.sh" && chmod +x "$STORE/install.sh"
    ok "Skill v$version stored"
}

# Place $SKILL_NAME inside a skills directory: a symlink when possible, a marked copy otherwise.
link_into() {
    local dir="$1" dest="$1/$SKILL_NAME" target
    if [ -L "$dest" ]; then
        target="$(readlink "$dest")"
        if [ "$target" = "$PAYLOAD" ]; then
            ok "$(pretty "$dest") ${D}(already linked)${R}"; manifest_add link "$dest"; return
        fi
        if [ "$FORCE" = false ]; then
            warn "$(pretty "$dest") is a symlink to $(pretty "$target") — left untouched (use --force to replace)"
            return
        fi
        backup_entry "$dest"
    elif [ -e "$dest" ]; then
        if [ -f "$dest/$MARKER" ]; then
            [ "$DRY" = true ] && { dry "refresh managed copy $dest"; return; }
            rm -rf "$dest"
        else
            backup_entry "$dest"
        fi
    fi
    if [ "$DRY" = true ]; then dry "link $dest → $PAYLOAD"; return; fi
    mkdir -p "$dir"
    if [ "$FORCE_COPY" = false ] && ln -s "$PAYLOAD" "$dest" 2>/dev/null && [ -L "$dest" ]; then
        ok "$(pretty "$dest") → store"
        manifest_add link "$dest"
    else
        # Git Bash without Developer Mode silently turns `ln -s` into a copy; handle both cases.
        [ -e "$dest" ] && [ ! -L "$dest" ] && rm -rf "$dest"
        cp -R "$PAYLOAD" "$dest"
        ok "$(pretty "$dest") ${D}(copy — re-run with --update after upgrades)${R}"
        manifest_add copy "$dest"
    fi
}

# Anything that is not ours is moved aside, never deleted. Backups live OUTSIDE every skills
# directory: a backup containing SKILL.md inside a scanned folder would load as a duplicate skill.
backup_entry() {
    local dest="$1" bdir
    bdir="$STORE/backups/$STAMP$(dirname "$dest" | sed 's#[:\\]#_#g')"
    if [ "$DRY" = true ]; then dry "back up existing $dest → $bdir/"; return; fi
    mkdir -p "$bdir"
    mv "$dest" "$bdir/"
    warn "existing $(pretty "$dest") moved to $(pretty "$bdir")/"
}

manifest_add() {
    [ "$DRY" = true ] && return
    mkdir -p "$STORE"; touch "$MANIFEST"
    grep -vxF "$1$TAB$2" "$MANIFEST" > "$MANIFEST.tmp" 2>/dev/null || true
    printf '%s\t%s\n' "$1" "$2" >> "$MANIFEST.tmp"
    mv "$MANIFEST.tmp" "$MANIFEST"
}

manifest_targets() {
    [ -f "$MANIFEST" ] || return 0
    local mode path
    while IFS="$TAB" read -r mode path; do
        [ -n "$path" ] && printf 'Previous\t%s\n' "$(dirname "$path")"
    done < "$MANIFEST"
}

# Older README instructions installed under names or paths that now cause duplicates.
warn_legacy_installs() {
    local legacy="$HOME/.claude/skills/roblox-dev"
    if echo "$1" | grep -q "/.claude/skills\$" && [ -e "$legacy" ] && grep -q "^name: $SKILL_NAME" "$legacy/SKILL.md" 2>/dev/null; then
        if [ -L "$legacy" ]; then
            warn "$(pretty "$legacy") also points to this skill (old folder name) — Claude Code will list it twice. Remove it when ready: rm \"$legacy\""
        else
            backup_entry "$legacy"
            info "that was an old install under the non-standard name 'roblox-dev'; the spec requires the folder to match the skill name"
        fi
    fi
    local plugin="$HOME/.gemini/config/plugins/roblox-dev-suite/skills/$SKILL_NAME"
    if [ -e "$plugin" ] && echo "$1" | grep -q "/.gemini/config/skills"; then
        warn "Antigravity also loads this skill through your roblox-dev-suite plugin — it may appear twice."
    fi
}

# ════════════════════════════════════════════════════════════════════════
# RobloxDocs
# ════════════════════════════════════════════════════════════════════════
find_python() {
    local c
    for c in python3 python; do
        if have "$c" && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)' >/dev/null 2>&1; then
            echo "$c"; return 0
        fi
    done
    return 1
}

install_docs() {
    local src="$1" tools="$1/tools/robloxdocs" py f bdir="" cfg
    step "Setting up $(pretty "$DOCS_HOME")"
    if ! py="$(find_python)"; then
        warn "python3 not found — skipping RobloxDocs. The skill works without it, using web docs."
        info "Install Python 3, then run: bash \"$STORE/install.sh\" --docs-only"
        return 0
    fi
    [ -d "$tools" ] || { warn "this version has no tools/robloxdocs — skipping"; return 0; }
    if [ "$DRY" = true ]; then
        dry "install scripts → $DOCS_HOME/scripts/ and run roblox-api-monitor.sh"; return 0
    fi
    mkdir -p "$DOCS_HOME/scripts"
    for f in "$tools"/*; do
        local name; name="$(basename "$f")"
        # only the tools themselves — never caches or other stray files from a local checkout
        [ -f "$f" ] || continue
        case "$name" in *.py|*.sh) ;; *) continue ;; esac
        if [ -f "$DOCS_HOME/scripts/$name" ] && ! cmp -s "$f" "$DOCS_HOME/scripts/$name"; then
            [ -n "$bdir" ] || { bdir="$DOCS_HOME/scripts/.backup-$STAMP"; mkdir -p "$bdir"; }
            cp "$DOCS_HOME/scripts/$name" "$bdir/"
        fi
        cp "$f" "$DOCS_HOME/scripts/$name"
        case "$name" in *.sh|*.py) chmod +x "$DOCS_HOME/scripts/$name" ;; esac
    done
    [ -n "$bdir" ] && info "your previous scripts were different — kept a copy in $(pretty "$bdir")"
    [ -f "$DOCS_HOME/README.md" ] || cp "$tools/README.md" "$DOCS_HOME/README.md"

    cfg="$DOCS_HOME/config"
    if [ ! -f "$cfg" ]; then
        # Under Git Bash / Cygwin the Python that reads this file is a native Windows program: it cannot
        # resolve "/c/Users/…" or "/tmp/…". MSYS converts paths in arguments and environment variables,
        # never in file contents — so write a native path ourselves.
        local refs="$PAYLOAD/references"
        if have cygpath; then refs="$(cygpath -m "$refs")"; fi
        printf '# RobloxDocs configuration — KEY=VALUE, parsed (never sourced)\nSKILL_REFS=%s\nAUDIT_MODE=warn\n' \
            "$refs" > "$cfg"
    else
        info "kept your existing $(pretty "$cfg")"
    fi
    ok "Scripts installed"

    step "Downloading and splitting the Roblox API dump (one-time, ~8 MB)"
    if ROBLOX_DOCS_HOME="$DOCS_HOME" "$py" "$DOCS_HOME/scripts/roblox-api-monitor.py"; then
        ok "RobloxDocs ready"
    else
        warn "the API dump step did not finish — the skill is installed and works without it."
        info "Retry any time: ~/RobloxDocs/scripts/roblox-api-monitor.sh"
    fi
}

# ════════════════════════════════════════════════════════════════════════
# Uninstall
# ════════════════════════════════════════════════════════════════════════
do_uninstall() {
    banner
    step "Uninstalling $SKILL_NAME"
    local mode path removed=0
    if [ -f "$MANIFEST" ]; then
        while IFS="$TAB" read -r mode path; do
            [ -n "$path" ] || continue
            if [ "$mode" = link ] && [ -L "$path" ] && [ "$(readlink "$path")" = "$PAYLOAD" ]; then
                run rm "$path"; [ "$DRY" = true ] || ok "removed $(pretty "$path")"; removed=$((removed + 1))
            elif [ -d "$path" ] && [ -f "$path/$MARKER" ]; then
                run rm -rf "$path"; [ "$DRY" = true ] || ok "removed $(pretty "$path")"; removed=$((removed + 1))
            elif [ -e "$path" ] || [ -L "$path" ]; then
                warn "$(pretty "$path") is no longer ours — left untouched"
            fi
        done < "$MANIFEST"
    else
        info "no manifest at $(pretty "$MANIFEST")"
    fi
    run rm -rf "$PAYLOAD" "$MANIFEST" "$STORE/install.sh"
    ok "removed $removed agent link(s) and the stored skill"
    [ -d "$STORE/backups" ] && info "backups of anything replaced during install are kept in $(pretty "$STORE/backups")"
    if [ "$PURGE_DOCS" = true ]; then
        if [ -d "$DOCS_HOME" ] && confirm "Delete $(pretty "$DOCS_HOME") including every downloaded API dump?" n; then
            run rm -rf "$DOCS_HOME/RobloxAPI" "$DOCS_HOME/scripts" "$DOCS_HOME/config"
            ok "removed RobloxAPI/, scripts/ and config from $(pretty "$DOCS_HOME")"
        elif [ "$YES" = true ] && [ -d "$DOCS_HOME" ]; then
            info "--purge-docs with --yes still asks for confirmation; nothing deleted from $(pretty "$DOCS_HOME")"
        fi
    elif [ -d "$DOCS_HOME" ]; then
        info "$(pretty "$DOCS_HOME") was kept. Add --purge-docs to remove it too."
    fi
}

# ════════════════════════════════════════════════════════════════════════
# Output
# ════════════════════════════════════════════════════════════════════════
setup_colors() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
        B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; RD=$'\033[31m'; C=$'\033[36m'; R=$'\033[0m'
    else B=""; D=""; G=""; Y=""; RD=""; C=""; R=""; fi
}
B=""; D=""; G=""; Y=""; RD=""; C=""; R=""

info() { printf '  %s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$R" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$R" "$*"; }
step() { printf '\n%s▸ %s%s\n' "$C$B" "$*" "$R"; }
dry()  { printf '  %s[dry-run]%s %s\n' "$Y" "$R" "$*"; }
die()  { printf '\n  %s✗ %s%s\n\n' "$RD" "$*" "$R" >&2; exit 1; }
run()  { if [ "$DRY" = true ]; then dry "$*"; else "$@"; fi; }
pretty() { case "$1" in "$HOME"|"$HOME"/*) echo "~${1#"$HOME"}" ;; *) echo "$1" ;; esac; }

banner() {
    printf '\n%s roblox-dev-skill installer %s\n' "$B" "$R"
    printf '%s Roblox & Luau knowledge for AI coding agents — %s%s\n' "$D" "https://github.com/$REPO_OWNER/$REPO_NAME" "$R"
    [ "$DRY" = true ] && printf '\n  %sDRY RUN — nothing will be changed%s\n' "$Y" "$R"
    return 0
}

preflight() {
    local os
    os="$(uname -s 2>/dev/null || echo unknown)"
    case "$os" in
        Darwin) os="macOS" ;;
        Linux)  grep -qi microsoft /proc/version 2>/dev/null && os="Linux (WSL)" || os="Linux" ;;
        MINGW*|MSYS*|CYGWIN*) os="Windows ($os)" ;;
    esac
    have curl || have wget || die "curl or wget is required"
    have tar || [ -n "$SOURCE_DIR" ] || die "tar is required"
    info "${D}$os · bash ${BASH_VERSION%%(*}${R}"
}

plan_summary() {
    local label dir
    step "Plan"
    info "Skill store: $(pretty "$PAYLOAD")"
    while IFS="$TAB" read -r label dir; do
        [ -n "$dir" ] || continue
        printf '  %s→%s %-26s %s\n' "$G" "$R" "$label" "$(pretty "$dir")/$SKILL_NAME"
    done <<EOF
$1
EOF
    if echo "$1" | grep -q "/.agents/skills"; then
        info "${D}~/.agents/skills is read by $UNIVERSAL_READERS${R}"
    fi
    info "RobloxDocs:  $( [ "$DOCS_MODE" = yes ] && pretty "$DOCS_HOME" || echo "skipped")"
}

list_agents() {
    printf '\n%-16s %-32s %-40s %s\n' "ID" "AGENT" "USER SKILLS DIR" "DETECTED"
    local id
    for id in $AGENT_IDS; do
        printf '%-16s %-32s %-40s %s\n' "$id" "$(agent_label "$id")" "$(pretty "$(agent_dir "$id")")" \
            "$(agent_detected "$id" && echo yes || echo -)"
    done
    printf '\nPaths verified against each agent'"'"'s documentation (2026-09-25). Sources:\n'
    for id in $AGENT_IDS; do printf '  %-16s %s\n' "$id" "$(agent_docs "$id")"; done
    echo
}

finish() {
    step "Done"
    info "Installed $SKILL_NAME v$2."
    info "Restart your agent(s) so they rescan their skills folders."
    echo ""
    info "${B}Update${R}     curl -fsSL https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/master/install.sh | bash -s -- --update"
    # absolute path: a quoted "~/…" is not expanded by the shell, so a pasted command would fail
    info "${B}Uninstall${R}  bash \"$STORE/install.sh\" --uninstall"
    [ "$DOCS_MODE" = yes ] && info "${B}Refresh API${R} ~/RobloxDocs/scripts/roblox-api-monitor.sh"
    echo ""
}

usage() {
    cat <<USAGE
roblox-dev-skill installer

  curl -fsSL https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/master/install.sh | bash
  curl -fsSL …/install.sh | bash -s -- [options]

Interactive by default: pick agents from a list. Without a terminal it installs to the
detected defaults.

Choosing agents
  --agents LIST     comma-separated ids, 'detected', or 'all'. Ids:
                    $(echo $AGENT_IDS | fold -s -w 60 | sed '2,$s/^/                    /')
  --path DIR        also install into DIR (a folder that contains skill folders); repeatable
  --list            show every supported agent, its skills folder, and whether it was detected
  --no-dedupe       also link agents that already read ~/.agents/skills (they will list it twice)

Behaviour
  -y, --yes         no questions; use --agents or the detected defaults
  --dry-run         show what would change, change nothing
  --copy            copy instead of symlink (default: symlink, falling back to copy)
  --force           replace an existing symlink that points somewhere else (it is backed up)
  --ref REF         install a branch or tag (default: $DEFAULT_REF)
  --source DIR      install from a local checkout instead of GitHub

RobloxDocs (local Roblox API reference, needs python3)
  --docs / --no-docs   set up ~/RobloxDocs or skip it (default: ask; yes when non-interactive)
  --docs-only          only (re)install ~/RobloxDocs

Maintenance
  --update          fetch the latest skill; existing links follow automatically
  --uninstall       remove every link/copy this installer made (nothing else)
  --purge-docs      with --uninstall: also delete ~/RobloxDocs data (asks first)

Environment
  ROBLOX_SKILL_REF     default for --ref (e.g. a tag) — handy when options cannot be passed
  ROBLOX_SKILL_LINK    copy = same as --copy
  ROBLOX_SKILL_STORE, ROBLOX_DOCS_HOME, XDG_DATA_HOME, NO_COLOR
USAGE
}

main "$@"
