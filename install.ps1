<#
roblox-dev-skill installer for Windows PowerShell 5.1+ and PowerShell 7+
https://github.com/MSayib/roblox-dev-skill

    irm https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.ps1 | iex

With options:

    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.ps1))) -Agents claude,universal -Yes

Installs the skill once and links it into every agent you pick (symlink, else a junction, else a
copy), then optionally sets up ~\RobloxDocs with a freshly downloaded Roblox API dump.
No git needed. RobloxDocs needs Python 3.6+.

This file is deliberately ASCII-only: Windows PowerShell 5.1 reads BOM-less UTF-8 as ANSI.
#>
param(
    [string[]]$Agents,
    [string[]]$Path,
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Copy,
    [switch]$Docs,
    [switch]$NoDocs,
    [switch]$DocsOnly,
    [string]$Ref = $(if ($env:ROBLOX_SKILL_REF) { $env:ROBLOX_SKILL_REF } else { 'master' }),
    [string]$Source,
    [switch]$NoDedupe,
    [switch]$Update,
    [switch]$Uninstall,
    [switch]$PurgeDocs,
    [switch]$List,
    [switch]$Help
)

# Everything runs in a child scope: when piped into `iex` this script executes inside the user's
# own session, so nothing -- preferences, functions, variables -- may leak into it, and nothing may
# call `exit`, which would close their window.
& {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # the 5.1 progress bar slows downloads dramatically

$RepoOwner  = 'MSayib'
$RepoName   = 'roblox-dev-skill'
$SkillName  = 'roblox-dev-skill'   # must equal SKILL.md `name` and the folder name (agentskills.io)
$Marker     = '.roblox-dev-skill-install'
$OnWindows  = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
# ROBLOX_SKILL_HOME lets tests run against a throwaway profile ($HOME cannot be redirected in pwsh on Windows)
if ($env:ROBLOX_SKILL_HOME) { $HomeDir = $env:ROBLOX_SKILL_HOME } else { $HomeDir = $HOME }
$Stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'

if ($env:ROBLOX_SKILL_STORE) { $Store = $env:ROBLOX_SKILL_STORE }
elseif ($OnWindows)         { $Store = Join-Path $env:LOCALAPPDATA $RepoName }
elseif ($env:XDG_DATA_HOME) { $Store = Join-Path $env:XDG_DATA_HOME $RepoName }
else                        { $Store = Join-Path (Join-Path (Join-Path $HomeDir '.local') 'share') $RepoName }
$Payload  = Join-Path $Store $SkillName
$Manifest = Join-Path $Store 'manifest.tsv'
if ($env:ROBLOX_DOCS_HOME) { $DocsHome = $env:ROBLOX_DOCS_HOME } else { $DocsHome = Join-Path $HomeDir 'RobloxDocs' }

# ======================================================================
# Output
# ======================================================================
function Say([string]$m)  { Write-Host "  $m" }
function Ok([string]$m)   { Write-Host '  [ok] ' -ForegroundColor Green -NoNewline; Write-Host $m }
function Warn([string]$m) { Write-Host '  [!]  ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Step([string]$m) { Write-Host ''; Write-Host "> $m" -ForegroundColor Cyan }
function Dry([string]$m)  { Write-Host '  [dry-run] ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Fail([string]$m) { throw "roblox-dev-skill installer: $m" }
function P([string]$p) {
    if ($p -and $p.StartsWith($HomeDir, [StringComparison]::OrdinalIgnoreCase)) { return '~' + $p.Substring($HomeDir.Length) }
    return $p
}
function J { param([Parameter(ValueFromRemainingArguments = $true)][string[]]$parts)
    $r = $parts[0]; for ($i = 1; $i -lt $parts.Count; $i++) { $r = Join-Path $r $parts[$i] }; return $r }

# ======================================================================
# Agent registry -- every path verified against the agent's own docs on 2026-09-25.
# ReadsUniversal: the agent documents ~/.agents/skills as a discovery path, so the one universal
# link already covers it (a second link would list the skill twice).
# ======================================================================
function Under-Home([string]$rel) { Join-Path $HomeDir ($rel -replace '/', [IO.Path]::DirectorySeparatorChar) }
function New-Agent($Id, $Label, $Rel, $ReadsUniversal, $Docs, $Cmd, $DetectRel) {
    [pscustomobject]@{ Id = $Id; Label = $Label; Dir = (Under-Home $Rel); ReadsUniversal = $ReadsUniversal
                       Docs = $Docs; Cmd = $Cmd; DetectRel = $DetectRel }
}
$Registry = @(
    (New-Agent 'universal'       'Universal ~/.agents/skills'      '.agents/skills'               $false 'https://agentskills.io/client-implementation/adding-skills-support' $null '.agents'),
    (New-Agent 'claude'          'Claude Code'                     '.claude/skills'               $false 'https://code.claude.com/docs/en/skills'                        'claude'   '.claude'),
    (New-Agent 'antigravity'     'Antigravity (2.0 / IDE)'         '.gemini/config/skills'        $false 'https://antigravity.google/docs/skills/'                       'antigravity' '.gemini/config'),
    (New-Agent 'antigravity-cli' 'Antigravity CLI'                 '.gemini/antigravity-cli/skills' $false 'https://antigravity.google/docs/skills/'                     $null '.gemini/antigravity-cli'),
    (New-Agent 'kiro'            'Kiro'                            '.kiro/skills'                 $false 'https://kiro.dev/docs/skills/'                                 'kiro'     '.kiro'),
    (New-Agent 'codex'           'Codex (OpenAI)'                  '.agents/skills'               $true  'https://developers.openai.com/codex/skills/'                   'codex'    '.codex'),
    (New-Agent 'gemini'          'Gemini CLI'                      '.gemini/skills'               $true  'https://geminicli.com/docs/cli/skills/'                        'gemini'   '.gemini/settings.json'),
    (New-Agent 'cursor'          'Cursor'                          '.cursor/skills'               $true  'https://cursor.com/docs/context/skills'                        'cursor'   '.cursor'),
    (New-Agent 'copilot'         'GitHub Copilot (CLI / VS Code)'  '.copilot/skills'              $true  'https://docs.github.com/en/copilot/concepts/agents/about-agent-skills' 'copilot' '.copilot'),
    (New-Agent 'opencode'        'OpenCode'                        '.config/opencode/skills'      $true  'https://opencode.ai/docs/skills/'                              'opencode' '.config/opencode'),
    (New-Agent 'roo'             'Roo Code'                        '.roo/skills'                  $true  'https://docs.roocode.com/features/skills'                      $null      '.roo'),
    (New-Agent 'goose'           'Goose'                           '.agents/skills'               $true  'https://block.github.io/goose/docs/guides/context-engineering/using-skills/' 'goose' '.config/goose'),
    (New-Agent 'junie'           'Junie (JetBrains)'               '.junie/skills'                $true  'https://junie.jetbrains.com/docs/agent-skills.html'            'junie'    '.junie'),
    (New-Agent 'amp'             'Amp'                             '.config/amp/skills'           $true  'https://ampcode.com/docs/customize/skills'                     'amp'      '.config/amp')
)
$UniversalReaders = 'Codex, Gemini CLI, Cursor, GitHub Copilot, OpenCode, Roo Code, Goose, Junie, Amp'

function Get-Agent([string]$id) { $Registry | Where-Object { $_.Id -eq $id } | Select-Object -First 1 }

function Test-Detected($a) {
    if ($a.Cmd -and (Get-Command $a.Cmd -ErrorAction SilentlyContinue)) { return $true }
    return (Test-Path -LiteralPath (Under-Home $a.DetectRel))
}

function Get-DefaultSelection {
    $sel = @('universal')
    foreach ($id in 'claude', 'antigravity', 'antigravity-cli', 'kiro') {
        if (Test-Detected (Get-Agent $id)) { $sel += $id }
    }
    return $sel
}

function Resolve-Selection([string[]]$raw) {
    $out = @()
    foreach ($tok in (($raw -join ',') -split '[,\s]+')) {
        $t = $tok.Trim().ToLowerInvariant()
        if (-not $t) { continue }
        if ($t -eq 'all') { return @($Registry | ForEach-Object { $_.Id }) }
        if ($t -eq 'detected') { $out += Get-DefaultSelection; continue }
        if (-not (Get-Agent $t)) { Fail "unknown agent '$t'. Known: $(($Registry | ForEach-Object { $_.Id }) -join ', ') (or all, detected)" }
        $out += $t
    }
    return $out
}

function Resolve-Targets([string[]]$sel, [string[]]$custom) {
    $targets = New-Object System.Collections.ArrayList
    $seen = @{}
    $universalOn = ($sel -contains 'universal') -or ($sel -contains 'codex') -or ($sel -contains 'goose')
    foreach ($a in $Registry) {
        if ($sel -notcontains $a.Id) { continue }
        if ($universalOn -and -not $NoDedupe -and $a.ReadsUniversal -and ($a.Id -ne 'codex') -and ($a.Id -ne 'goose')) { continue }
        $k = $a.Dir.ToLowerInvariant()
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true
        [void]$targets.Add([pscustomobject]@{ Label = $a.Label; Dir = $a.Dir })
    }
    foreach ($c in $custom) {
        if (-not $c) { continue }
        $d = Expand-UserPath $c
        $k = $d.ToLowerInvariant()
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true
        [void]$targets.Add([pscustomobject]@{ Label = 'Custom'; Dir = $d })
    }
    return ,$targets.ToArray()
}

function Expand-UserPath([string]$p) {
    $p = $p.Trim().Trim('"')
    if ($p -eq '~') { $p = $HomeDir }
    elseif ($p.StartsWith('~/') -or $p.StartsWith('~\')) { $p = Join-Path $HomeDir $p.Substring(2) }
    $p = [IO.Path]::GetFullPath($p).TrimEnd('\', '/')
    # a path that already ends in the skill folder means "put it here", not "nest it again"
    if ((Split-Path $p -Leaf) -eq $SkillName) { $p = Split-Path $p -Parent }
    return $p
}

# ======================================================================
# Wizard
# ======================================================================
function Test-Interactive {
    if ($Yes) { return $false }
    try { return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected } catch { return $false }
}

function Invoke-Wizard {
    $sel = New-Object System.Collections.ArrayList
    foreach ($id in (Get-DefaultSelection)) { [void]$sel.Add($id) }
    $custom = ''
    while ($true) {
        Write-Host ''
        Write-Host 'Which agents should get the skill?' -ForegroundColor White -NoNewline
        Write-Host '  (* = found on this machine)' -ForegroundColor DarkGray
        Write-Host ''
        $i = 0
        foreach ($a in $Registry) {
            $i++
            if ($sel -contains $a.Id) { $box = '[x]'; $col = 'Green' } else { $box = '[ ]'; $col = 'Gray' }
            if (Test-Detected $a) { $det = ' *' } else { $det = '' }
            Write-Host ('  {0} {1,2}) ' -f $box, $i) -ForegroundColor $col -NoNewline
            Write-Host ('{0,-32} ' -f $a.Label) -NoNewline
            Write-Host (P $a.Dir) -ForegroundColor DarkGray -NoNewline
            Write-Host $det -ForegroundColor Green
            if ($a.Id -eq 'universal') {
                Write-Host "          read by $UniversalReaders" -ForegroundColor DarkGray
                Write-Host ''
            }
        }
        $i++
        if ($custom) { $box = '[x]'; $col = 'Green' } else { $box = '[ ]'; $col = 'Gray' }
        Write-Host ('  {0} {1,2}) ' -f $box, $i) -ForegroundColor $col -NoNewline
        Write-Host ('{0,-32} {1}' -f 'Custom path...', $custom)
        Write-Host ''
        Write-Host '  Toggle by number (e.g. 2 3), a = all, n = none, Enter to continue.'
        $answer = Read-Host '  >'     # not $input: that is PowerShell's automatic pipeline variable
        if (-not $answer) { break }
        foreach ($tok in ($answer -split '\s+')) {
            if (-not $tok) { continue }
            if ($tok -eq 'a') { $sel.Clear(); foreach ($a in $Registry) { [void]$sel.Add($a.Id) }; continue }
            if ($tok -eq 'n') { $sel.Clear(); $custom = ''; continue }
            $n = 0
            if (-not [int]::TryParse($tok, [ref]$n) -or $n -lt 1 -or $n -gt $i) { Warn "no option '$tok'"; continue }
            if ($n -eq $i) {
                if ($custom) { $custom = '' } else { $custom = Read-Host '  Skills directory (the folder that CONTAINS skill folders)' }
                continue
            }
            $id = $Registry[$n - 1].Id
            if ($sel -contains $id) { $sel.Remove($id) } else { [void]$sel.Add($id) }
        }
    }
    return [pscustomobject]@{ Selection = @($sel); Custom = $custom }
}

function Confirm-Choice([string]$q, [bool]$default = $true) {
    if (-not (Test-Interactive)) { return $default }
    if ($default) { $hint = '[Y/n]' } else { $hint = '[y/N]' }
    $ans = Read-Host "$q $hint"
    if (-not $ans) { return $default }
    return @('y', 'yes') -contains $ans.Trim().ToLowerInvariant()
}

# ======================================================================
# Source
# ======================================================================
function Enable-Tls12 {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
}

function Get-Source([string]$work) {
    if ($Source) {
        if (-not (Test-Path -LiteralPath $Source -PathType Container)) { Fail "-Source: not a directory: $Source" }
        return (Resolve-Path -LiteralPath $Source).ProviderPath
    }
    Enable-Tls12
    $url = "https://codeload.github.com/$RepoOwner/$RepoName/zip/$Ref"
    $zip = Join-Path $work 'src.zip'
    Say "Downloading $RepoOwner/$RepoName@$Ref..."
    try { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing }
    catch { Fail "download failed: $url  (is -Ref '$Ref' a real branch or tag?)  $($_.Exception.Message)" }
    $dest = Join-Path $work 'src'
    Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
    $top = @(Get-ChildItem -LiteralPath $dest -Directory)
    if ($top.Count -lt 1) { Fail 'the archive was empty' }
    return $top[0].FullName
}

function Test-Source([string]$src) {
    $skill = Join-Path $src 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skill)) { Fail "no SKILL.md in $src -- not a $RepoName checkout" }
    if (-not (Test-Path -LiteralPath (Join-Path $src 'references'))) { Fail "no references\ in $src" }
    $line = Get-Content -LiteralPath $skill -TotalCount 15 | Where-Object { $_ -match '^name:\s*' } | Select-Object -First 1
    $name = ($line -replace '^name:\s*', '').Trim().Trim('"', "'")
    if ($name -ne $SkillName) { Fail "SKILL.md name is '$name', expected '$SkillName'" }
}

function Get-SkillVersion([string]$src) {
    try { return (Get-Content -LiteralPath (Join-Path $src 'metadata.json') -Raw | ConvertFrom-Json).version } catch { return 'unknown' }
}

# ======================================================================
# Links -- never Remove-Item -Recurse a link: on 5.1 that can delete the TARGET's contents.
# ======================================================================
function Get-Entry([string]$p) {
    $item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if ($item) { return $item }
    return $null
}

function Get-LinkTarget($item) {
    if (-not $item -or -not $item.LinkType) { return $null }
    $t = @($item.Target)[0]
    if ($t) { $t = $t -replace '^\\\\\?\\', '' }
    return $t
}

function Test-SamePath([string]$a, [string]$b) {
    if (-not $a -or -not $b) { return $false }
    $a = $a.TrimEnd('\', '/'); $b = $b.TrimEnd('\', '/')
    if ($OnWindows) { return [string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase) }
    return $a -ceq $b
}

function Remove-Link([string]$p) {
    if ($OnWindows) { [IO.Directory]::Delete($p, $false) }   # removes the reparse point only
    else { [IO.File]::Delete($p) }                            # unlink(2): removes the symlink only
}

function Backup-Entry([string]$dest) {
    $rel = (Split-Path $dest -Parent) -replace '[:\\/]+', '_'
    $bdir = J $Store 'backups' $Stamp $rel
    if ($DryRun) { Dry "back up existing $dest -> $bdir"; return }
    New-Item -ItemType Directory -Force -Path $bdir | Out-Null
    $item = Get-Entry $dest
    if ($item.LinkType) {
        # record where the link pointed, then remove only the link
        Set-Content -LiteralPath (Join-Path $bdir "$(Split-Path $dest -Leaf).link.txt") -Value (Get-LinkTarget $item)
        Remove-Link $dest
    } else {
        Move-Item -LiteralPath $dest -Destination $bdir
    }
    Warn "existing $(P $dest) moved to $(P $bdir)"
}

function Add-Manifest([string]$mode, [string]$p) {
    if ($DryRun) { return }
    New-Item -ItemType Directory -Force -Path $Store | Out-Null
    $lines = @()
    if (Test-Path -LiteralPath $Manifest) { $lines = @(Get-Content -LiteralPath $Manifest | Where-Object { $_ -and ($_ -ne "$mode`t$p") }) }
    $lines += "$mode`t$p"
    Set-Content -LiteralPath $Manifest -Value $lines
}

function Install-Link([string]$dir) {
    $dest = Join-Path $dir $SkillName
    $item = Get-Entry $dest
    if ($item -and $item.LinkType) {
        $target = Get-LinkTarget $item
        if (Test-SamePath $target $Payload) { Ok "$(P $dest) (already linked)"; Add-Manifest 'link' $dest; return }
        if (-not $Force) { Warn "$(P $dest) is a link to $target -- left untouched (use -Force to replace)"; return }
        Backup-Entry $dest
    } elseif ($item) {
        if (Test-Path -LiteralPath (Join-Path $dest $Marker)) {
            if ($DryRun) { Dry "refresh managed copy $dest"; return }
            Remove-Item -LiteralPath $dest -Recurse -Force   # a real directory we made, not a link
        } else {
            Backup-Entry $dest
        }
    }
    if ($DryRun) { Dry "link $dest -> $Payload"; return }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    # ROBLOX_SKILL_LINK = symlink | junction | copy pins the method (default: try them in that order)
    $mode = "$env:ROBLOX_SKILL_LINK".ToLowerInvariant()
    if ($Copy) { $mode = 'copy' }
    if ($mode -ne 'copy') {
        if ($mode -ne 'junction') {
            try {
                New-Item -ItemType SymbolicLink -Path $dest -Target $Payload | Out-Null
                Ok "$(P $dest) -> store (symlink)"; Add-Manifest 'link' $dest; return
            } catch { }
        }
        if ($OnWindows) {
            # junctions need no admin rights or Developer Mode
            try {
                New-Item -ItemType Junction -Path $dest -Target $Payload | Out-Null
                Ok "$(P $dest) -> store (junction)"; Add-Manifest 'link' $dest; return
            } catch { }
        }
    }
    Copy-Item -LiteralPath $Payload -Destination $dest -Recurse
    Ok "$(P $dest) (copy -- re-run with -Update after upgrades)"
    Add-Manifest 'copy' $dest
}

function Install-Payload([string]$src, [string]$version) {
    Step "Installing skill into $(P $Payload)"
    if ($DryRun) { Dry "copy SKILL.md, metadata.json, references\ ... -> $Payload"; return }
    New-Item -ItemType Directory -Force -Path $Store | Out-Null
    $new = Join-Path $Store ".new.$PID"; $old = Join-Path $Store ".old.$PID"
    if (Test-Path -LiteralPath $new) { Remove-Item -LiteralPath $new -Recurse -Force }
    New-Item -ItemType Directory -Path $new | Out-Null
    foreach ($f in 'SKILL.md', 'metadata.json', 'LICENSE', 'README.md', 'CHANGELOG.md') {
        $p = Join-Path $src $f
        if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $new }
    }
    Copy-Item -LiteralPath (Join-Path $src 'references') -Destination (Join-Path $new 'references') -Recurse
    Set-Content -LiteralPath (Join-Path $new $Marker) -Value @("managed-by=$RepoName install.ps1", "version=$version", "installed=$Stamp")
    # swap in place: links point at $Payload, so they follow the new content automatically
    try {
        if (Test-Path -LiteralPath $Payload) { Rename-Item -LiteralPath $Payload -NewName (Split-Path $old -Leaf) }
        Rename-Item -LiteralPath $new -NewName $SkillName
    } catch {
        Fail "could not replace $Payload -- is an agent holding a file open? Close it and retry. ($($_.Exception.Message))"
    }
    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force }
    $me = Join-Path $src 'install.ps1'
    if (Test-Path -LiteralPath $me) { Copy-Item -LiteralPath $me -Destination (Join-Path $Store 'install.ps1') -Force }
    Ok "Skill v$version stored"
}

function Warn-Legacy($targets) {
    $claudeDir = (Get-Agent 'claude').Dir
    if (-not ($targets | Where-Object { Test-SamePath $_.Dir $claudeDir })) { return }
    $legacy = Join-Path $claudeDir 'roblox-dev'
    $item = Get-Entry $legacy
    if (-not $item) { return }
    $skill = Join-Path $legacy 'SKILL.md'
    if (-not ((Test-Path -LiteralPath $skill) -and (Select-String -LiteralPath $skill -Pattern "^name: $SkillName" -Quiet))) { return }
    if ($item.LinkType) {
        Warn "$(P $legacy) also points to this skill (old folder name) -- Claude Code will list it twice."
    } else {
        Backup-Entry $legacy
        Say "that was an old install under the non-standard name 'roblox-dev'; the spec requires the folder to match the skill name"
    }
}

# ======================================================================
# RobloxDocs
# ======================================================================
function Find-Python {
    foreach ($cand in @(@('py', '-3'), @('python'), @('python3'))) {
        if (-not (Get-Command $cand[0] -ErrorAction SilentlyContinue)) { continue }
        $pyArgs = @($cand | Select-Object -Skip 1)
        try {
            $oldEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try { & $cand[0] @pyArgs -c 'import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)' 2>$null | Out-Null }
            finally { $ErrorActionPreference = $oldEap }
            if ($LASTEXITCODE -eq 0) { return , $cand }   # `python3` on Windows is often a Store stub that fails here
        } catch { }
    }
    return $null
}

function Install-Docs([string]$src) {
    Step "Setting up $(P $DocsHome)"
    $py = Find-Python
    if (-not $py) {
        Warn 'Python 3 not found -- skipping RobloxDocs. The skill works without it, using web docs.'
        Say  "Install Python 3 (https://www.python.org/downloads/), then run: & `"$(Join-Path $Store 'install.ps1')`" -DocsOnly"
        return
    }
    $tools = J $src 'tools' 'robloxdocs'
    if (-not (Test-Path -LiteralPath $tools)) { Warn 'this version has no tools\robloxdocs -- skipping'; return }
    if ($DryRun) { Dry "install scripts -> $DocsHome\scripts and run roblox-api-monitor.py"; return }

    $scripts = Join-Path $DocsHome 'scripts'
    New-Item -ItemType Directory -Force -Path $scripts | Out-Null
    $bdir = $null
    foreach ($f in @(Get-ChildItem -LiteralPath $tools -File | Where-Object { $_.Extension -in '.py', '.sh' })) {
        $dest = Join-Path $scripts $f.Name
        if ((Test-Path -LiteralPath $dest) -and ((Get-FileHash -LiteralPath $dest).Hash -ne (Get-FileHash -LiteralPath $f.FullName).Hash)) {
            if (-not $bdir) { $bdir = Join-Path $scripts ".backup-$Stamp"; New-Item -ItemType Directory -Force -Path $bdir | Out-Null }
            Copy-Item -LiteralPath $dest -Destination $bdir
        }
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }
    if ($bdir) { Say "your previous scripts were different -- kept a copy in $(P $bdir)" }
    $readme = Join-Path $DocsHome 'README.md'
    if (-not (Test-Path -LiteralPath $readme)) { Copy-Item -LiteralPath (Join-Path $tools 'README.md') -Destination $readme }
    $cfg = Join-Path $DocsHome 'config'
    if (-not (Test-Path -LiteralPath $cfg)) {
        Set-Content -LiteralPath $cfg -Value @('# RobloxDocs configuration -- KEY=VALUE, parsed (never executed)',
                                               "SKILL_REFS=$(Join-Path $Payload 'references')", 'AUDIT_MODE=warn')
    } else { Say "kept your existing $(P $cfg)" }
    Ok 'Scripts installed'

    Step 'Downloading and splitting the Roblox API dump (one-time, ~8 MB)'
    $oldHome = $env:ROBLOX_DOCS_HOME; $oldEnc = $env:PYTHONIOENCODING
    $env:ROBLOX_DOCS_HOME = $DocsHome; $env:PYTHONIOENCODING = 'utf-8'
    # Windows PowerShell 5.1 turns a native program's stderr into error records when output is
    # redirected, and under 'Stop' the first Python warning would abort the whole installer.
    $oldEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $pyArgs = @($py | Select-Object -Skip 1)
        & $py[0] @pyArgs (Join-Path $scripts 'roblox-api-monitor.py')
        $code = $LASTEXITCODE
    } finally { $env:ROBLOX_DOCS_HOME = $oldHome; $env:PYTHONIOENCODING = $oldEnc; $ErrorActionPreference = $oldEap }
    if ($code -eq 0) { Ok 'RobloxDocs ready' }
    else {
        Warn 'the API dump step did not finish -- the skill is installed and works without it.'
        Say  "Retry any time: python `"$(Join-Path $scripts 'roblox-api-monitor.py')`""
    }
}

# ======================================================================
# Uninstall
# ======================================================================
function Invoke-Uninstall {
    Step "Uninstalling $SkillName"
    $removed = 0
    if (Test-Path -LiteralPath $Manifest) {
        foreach ($line in @(Get-Content -LiteralPath $Manifest)) {
            if (-not $line) { continue }
            $mode, $p = $line -split "`t", 2
            $item = Get-Entry $p
            if (-not $item) { continue }
            if ($item.LinkType -and (Test-SamePath (Get-LinkTarget $item) $Payload)) {
                if ($DryRun) { Dry "remove link $p" } else { Remove-Link $p; Ok "removed $(P $p)" }; $removed++
            } elseif (-not $item.LinkType -and (Test-Path -LiteralPath (Join-Path $p $Marker))) {
                if ($DryRun) { Dry "remove copy $p" } else { Remove-Item -LiteralPath $p -Recurse -Force; Ok "removed $(P $p)" }; $removed++
            } else {
                Warn "$(P $p) is no longer ours -- left untouched"
            }
        }
    } else { Say "no manifest at $(P $Manifest)" }
    foreach ($p in $Payload, $Manifest, (Join-Path $Store 'install.ps1')) {
        if (Test-Path -LiteralPath $p) { if ($DryRun) { Dry "remove $p" } else { Remove-Item -LiteralPath $p -Recurse -Force } }
    }
    Ok "removed $removed agent link(s) and the stored skill"
    if (Test-Path -LiteralPath (Join-Path $Store 'backups')) { Say "backups of anything replaced during install are kept in $(P (Join-Path $Store 'backups'))" }
    if ($PurgeDocs -and (Test-Path -LiteralPath $DocsHome)) {
        if ((Test-Interactive) -and (Confirm-Choice "Delete $(P $DocsHome) including every downloaded API dump?" $false)) {
            foreach ($sub in 'RobloxAPI', 'scripts', 'config') {
                $p = Join-Path $DocsHome $sub
                if (Test-Path -LiteralPath $p) { if ($DryRun) { Dry "remove $p" } else { Remove-Item -LiteralPath $p -Recurse -Force } }
            }
            Ok "removed RobloxAPI\, scripts\ and config from $(P $DocsHome)"
        } else { Say "nothing deleted from $(P $DocsHome) (purging always asks first)" }
    } elseif (Test-Path -LiteralPath $DocsHome) { Say "$(P $DocsHome) was kept. Add -PurgeDocs to remove it too." }
}

# ======================================================================
# Main
# ======================================================================
function Show-Help {
@"
roblox-dev-skill installer (PowerShell)

  irm https://raw.githubusercontent.com/$RepoOwner/$RepoName/master/install.ps1 | iex
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/$RepoOwner/$RepoName/master/install.ps1))) [options]

  -Agents a,b     agent ids, 'detected' or 'all':
                  $(($Registry | ForEach-Object { $_.Id }) -join ', ')
  -Path DIR       also install into DIR (a folder that CONTAINS skill folders)
  -List           show every supported agent and its skills folder
  -Yes            no questions; use -Agents or the detected defaults
  -DryRun         show what would change, change nothing
  -Copy           copy instead of symlink/junction
  -Force          replace an existing link that points elsewhere (it is backed up)
  -Ref REF        branch or tag (default master)      -Source DIR   install from a local checkout
  -Docs/-NoDocs   set up ~\RobloxDocs or skip it      -DocsOnly     only (re)install RobloxDocs
  -NoDedupe       also link agents that already read ~/.agents/skills
  -Update         fetch the latest skill; links follow automatically
  -Uninstall      remove what this installer made     -PurgeDocs    also delete RobloxDocs data (asks)

  Environment (useful with `irm | iex`, which cannot take options):
  ROBLOX_SKILL_REF=TAG        install that branch or tag instead of master
  ROBLOX_SKILL_LINK=MODE      symlink, junction or copy
"@ | Write-Host
}

function Show-List {
    Write-Host ''
    Write-Host ('{0,-16} {1,-32} {2,-38} {3}' -f 'ID', 'AGENT', 'USER SKILLS DIR', 'DETECTED')
    foreach ($a in $Registry) {
        if (Test-Detected $a) { $d = 'yes' } else { $d = '-' }
        Write-Host ('{0,-16} {1,-32} {2,-38} {3}' -f $a.Id, $a.Label, (P $a.Dir), $d)
    }
    Write-Host ''
    Write-Host "Paths verified against each agent's documentation (2026-09-25):"
    foreach ($a in $Registry) { Write-Host ('  {0,-16} {1}' -f $a.Id, $a.Docs) }
    Write-Host ''
}

function Invoke-Main {
    if ($Help) { Show-Help; return }
    if ($List) { Show-List; return }

    Write-Host ''
    Write-Host ' roblox-dev-skill installer ' -ForegroundColor White
    Write-Host " Roblox & Luau knowledge for AI coding agents -- https://github.com/$RepoOwner/$RepoName" -ForegroundColor DarkGray
    if ($DryRun) { Write-Host ''; Write-Host '  DRY RUN -- nothing will be changed' -ForegroundColor Yellow }
    Say ("PowerShell {0} on {1}" -f $PSVersionTable.PSVersion, $(if ($OnWindows) { 'Windows' } else { [Environment]::OSVersion.Platform }))

    if ($Uninstall) { Invoke-Uninstall; return }

    $work = Join-Path ([IO.Path]::GetTempPath()) ("rds-install-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        $src = Get-Source $work
        Test-Source $src
        $version = Get-SkillVersion $src
        if ($Source) { $from = 'local source' } else { $from = "ref $Ref" }
        Ok "Skill $SkillName v$version ($from)"

        if ($DocsOnly) { Install-Docs $src; return }

        $custom = @($Path)
        if ($Update) {
            $targets = @()
            if (Test-Path -LiteralPath $Manifest) {
                $targets = @(Get-Content -LiteralPath $Manifest | Where-Object { $_ } | ForEach-Object {
                    [pscustomobject]@{ Label = 'Previous'; Dir = (Split-Path (($_ -split "`t", 2)[1]) -Parent) } })
            }
            if ($targets.Count -eq 0) { Fail "nothing to update: no previous install found in $Manifest" }
            $wantDocs = Test-Path -LiteralPath (J $DocsHome 'scripts' 'roblox-api-monitor.py')
        } else {
            if ($Agents) { $sel = Resolve-Selection $Agents }
            elseif (Test-Interactive) {
                $w = Invoke-Wizard
                $sel = $w.Selection
                if ($w.Custom) { $custom += $w.Custom }
            } else {
                $sel = Get-DefaultSelection
                Say "Non-interactive run: using detected defaults ($($sel -join ','))."
            }
            $targets = Resolve-Targets $sel $custom
            if ($targets.Count -eq 0) { Fail 'no agents selected -- nothing to install' }
            if ($Docs) { $wantDocs = $true }
            elseif ($NoDocs) { $wantDocs = $false }
            elseif (Test-Interactive) { $wantDocs = Confirm-Choice 'Also set up ~\RobloxDocs (downloads the ~8 MB Roblox API dump; needs Python 3)?' $true }
            else { $wantDocs = $true }
        }

        Step 'Plan'
        Say "Skill store: $(P $Payload)"
        foreach ($t in $targets) { Write-Host ('  -> {0,-26} {1}' -f $t.Label, (P (Join-Path $t.Dir $SkillName))) }
        if ($targets | Where-Object { $_.Dir -like '*.agents*skills' }) { Say "~/.agents/skills is read by $UniversalReaders" }
        if ($wantDocs) { Say "RobloxDocs:  $(P $DocsHome)" } else { Say 'RobloxDocs:  skipped' }
        if (-not $Update -and (Test-Interactive)) {
            if (-not (Confirm-Choice 'Proceed?' $true)) { Say 'Cancelled -- nothing was changed.'; return }
        }

        Install-Payload $src $version
        foreach ($t in $targets) { Install-Link $t.Dir }
        Warn-Legacy $targets
        if ($wantDocs) { Install-Docs $src }

        Step 'Done'
        Say "Installed $SkillName v$version."
        Say 'Restart your agent(s) so they rescan their skills folders.'
        Write-Host ''
        Say "Update     & ([scriptblock]::Create((irm https://raw.githubusercontent.com/$RepoOwner/$RepoName/master/install.ps1))) -Update"
        Say "Uninstall  & `"$(Join-Path $Store 'install.ps1')`" -Uninstall"   # absolute: a pasted ~ is not reliably expanded
        Write-Host ''
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    Invoke-Main
} catch {
    Write-Host ''
    Write-Host "  [x] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    # Only a dedicated process (install.cmd) may set an exit code; `iex` must never close the window.
    if ($env:ROBLOX_SKILL_EXIT_ON_ERROR -eq '1') { exit 1 }
}
}
