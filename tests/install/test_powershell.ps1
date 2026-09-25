<#
Functional tests for install.ps1, for Windows PowerShell 5.1 and PowerShell 7 on any OS.

    powershell -NoProfile -ExecutionPolicy Bypass -File tests\install\test_powershell.ps1
    pwsh -NoProfile -File tests/install/test_powershell.ps1

Every scenario runs the installer in a CHILD process of the same PowerShell edition, against a
throwaway profile (ROBLOX_SKILL_HOME) and store, so your real agent folders are never touched.
Set SKIP_NETWORK=1 to skip the RobloxDocs download. ASCII-only, like the installer.
#>
$ErrorActionPreference = 'Stop'
$Repo      = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).ProviderPath
$Installer = Join-Path $Repo 'install.ps1'
$Skill     = 'roblox-dev-skill'
$Marker    = '.roblox-dev-skill-install'
$OnWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
$Exe       = (Get-Process -Id $PID).Path
$Work      = Join-Path ([IO.Path]::GetTempPath()) ('rds-pstest-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work | Out-Null
$script:Pass = 0; $script:Fail = 0; $script:Skip = 0

function Ok([string]$m)   { $script:Pass++; Write-Host "  ok    $m" }
function Bad([string]$m)  {
    $script:Fail++; Write-Host "  FAIL  $m" -ForegroundColor Red
    # the installer's own output for this scenario, so a CI failure can be diagnosed from the log
    if ($script:Log) { ($script:Log -split "`r?`n" | Select-Object -Last 25) | ForEach-Object { Write-Host "        | $_" } }
}
function Skip([string]$m) { $script:Skip++; Write-Host "  skip  $m" }
function Check([string]$m, [scriptblock]$cond) { try { if (& $cond) { Ok $m } else { Bad $m } } catch { Bad "$m ($($_.Exception.Message))" } }
function Section([string]$m) { Write-Host ''; Write-Host "## $m" }
function PJoin { $r = $args[0]; for ($i = 1; $i -lt $args.Count; $i++) { $r = Join-Path $r $args[$i] }; $r }

function Fresh([string]$name) {
    $script:H = Join-Path $Work $name
    $script:Store = Join-Path $script:H 'store'
    $script:Payload = Join-Path $script:Store $Skill
    New-Item -ItemType Directory -Force -Path $script:H | Out-Null
}

# Run install.ps1 in a child process; returns the exit code, output goes to $script:Log.
function Run {
    param([string[]]$InstallerArgs, [hashtable]$Env = @{})
    $saved = @{}
    $vars = @{ ROBLOX_SKILL_HOME = $script:H; ROBLOX_SKILL_STORE = $script:Store; ROBLOX_DOCS_HOME = (Join-Path $script:H 'RobloxDocs') }
    foreach ($k in $Env.Keys) { $vars[$k] = $Env[$k] }
    foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    try {
        $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Installer, '-Source', $Repo) + $InstallerArgs
        # 5.1 turns captured native stderr into error records; 'Stop' would end the test run
        $ErrorActionPreference = 'Continue'
        $script:Log = (& $Exe @all 2>&1 | Out-String)
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

function AgentDir([string]$rel) { Join-Path $script:H ($rel -replace '/', [IO.Path]::DirectorySeparatorChar) }

function Get-Target($item) { $t = @($item.Target)[0]; if ($t) { $t = $t -replace '^\\\\\?\\', '' }; $t }

function Test-Installed([string]$dir) {
    $p = Join-Path $dir $Skill
    $item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    if ($item.LinkType) { return [string]::Equals((Get-Target $item).TrimEnd('\', '/'), $script:Payload.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase) }
    return (Test-Path -LiteralPath (Join-Path $p $Marker)) -and (Test-Path -LiteralPath (Join-Path $p 'SKILL.md'))
}

function Get-TreeHash {
    $lines = Get-ChildItem -LiteralPath $script:H -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike '*.log' } |
        ForEach-Object { '{0}|{1}|{2}' -f $_.FullName, $_.LinkType, $(if ($_.PSIsContainer) { '' } else { $_.Length }) } |
        Sort-Object
    ($lines -join "`n").GetHashCode()
}

function New-ForeignLink([string]$link, [string]$target) {
    if ($OnWindows) { New-Item -ItemType Junction -Path $link -Target $target | Out-Null }
    else { New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null }
}

Write-Host ("install.ps1 tests -- PowerShell {0} ({1}) on {2}" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition, $(if ($OnWindows) { 'Windows' } else { [Environment]::OSVersion.Platform }))

try {
    # ------------------------------------------------------------------
    Section 'fresh install, explicit agents'
    Fresh 'a'
    $rc = Run @('-Agents', 'universal,claude,antigravity', '-NoDocs', '-Yes')
    Check 'exits 0' { $rc -eq 0 }
    Check 'universal installed' { Test-Installed (AgentDir '.agents/skills') }
    Check 'claude installed' { Test-Installed (AgentDir '.claude/skills') }
    Check 'antigravity installed' { Test-Installed (AgentDir '.gemini/config/skills') }
    Check 'payload excludes evals, tools, installers' { -not (Test-Path (Join-Path $Payload 'evals')) -and -not (Test-Path (Join-Path $Payload 'tools')) -and -not (Test-Path (Join-Path $Payload 'install.ps1')) }
    Check 'manifest has 3 entries' { @(Get-Content (Join-Path $Store 'manifest.tsv')).Count -eq 3 }

    Section 'idempotent re-run'
    $rc = Run @('-Agents', 'universal,claude,antigravity', '-NoDocs', '-Yes')
    Check 'exits 0' { $rc -eq 0 }
    Check 'still 3 manifest entries' { @(Get-Content (Join-Path $Store 'manifest.tsv')).Count -eq 3 }

    Section 'dedupe'
    Fresh 'b'
    $null = Run @('-Agents', 'universal,cursor,copilot', '-NoDocs', '-Yes')
    Check 'universal installed' { Test-Installed (AgentDir '.agents/skills') }
    Check 'cursor NOT linked natively' { -not (Test-Path (Join-Path (AgentDir '.cursor/skills') $Skill)) }

    Section 'link modes'
    Fresh 'c'
    $null = Run @('-Agents', 'universal', '-NoDocs', '-Yes') @{ ROBLOX_SKILL_LINK = 'copy' }
    Check 'ROBLOX_SKILL_LINK=copy makes a marked copy' {
        $i = Get-Item -LiteralPath (Join-Path (AgentDir '.agents/skills') $Skill) -Force
        (-not $i.LinkType) -and (Test-Path (Join-Path $i.FullName $Marker)) }
    if ($OnWindows) {
        Fresh 'c2'
        $null = Run @('-Agents', 'universal', '-NoDocs', '-Yes') @{ ROBLOX_SKILL_LINK = 'junction' }
        Check 'ROBLOX_SKILL_LINK=junction makes a junction to the store' {
            $i = Get-Item -LiteralPath (Join-Path (AgentDir '.agents/skills') $Skill) -Force
            ($i.LinkType -eq 'Junction') -and (Test-Installed (AgentDir '.agents/skills')) }
        Check 'SKILL.md readable through the junction' { Test-Path (PJoin (AgentDir '.agents/skills') $Skill 'SKILL.md') }
    } else { Skip 'junction mode (Windows only)' }

    Section 'conflicts are backed up, never deleted'
    Fresh 'e'
    $gem = AgentDir '.gemini/config/skills'; $cl = AgentDir '.claude/skills'
    New-Item -ItemType Directory -Force -Path $gem, $cl | Out-Null
    Copy-Item -LiteralPath $Repo -Destination (Join-Path $gem $Skill) -Recurse
    Copy-Item -LiteralPath $Repo -Destination (Join-Path $cl 'roblox-dev') -Recurse
    $null = Run @('-Agents', 'universal,claude,antigravity', '-NoDocs', '-Yes')
    Check 'manual clone replaced by install' { Test-Installed $gem }
    Check 'legacy roblox-dev moved out' { -not (Test-Path (Join-Path $cl 'roblox-dev')) }
    Check 'both backed up in the store' { @(Get-ChildItem (Join-Path $Store 'backups') -Recurse -Directory | Where-Object { $_.Name -like 'roblox-dev*' }).Count -ge 2 }

    Section 'foreign links are left alone; -Force keeps their target intact'
    Fresh 'f'
    $cl = AgentDir '.claude/skills'; $precious = Join-Path $H 'precious'
    New-Item -ItemType Directory -Force -Path $precious, $cl | Out-Null
    Set-Content -LiteralPath (Join-Path $precious 'keep.txt') -Value 'keep'
    New-ForeignLink (Join-Path $cl $Skill) $precious
    $null = Run @('-Agents', 'claude', '-NoDocs', '-Yes')
    Check 'foreign link untouched without -Force' { -not (Test-Installed $cl) -and (Test-Path (Join-Path (Join-Path $cl $Skill) 'keep.txt')) }
    $null = Run @('-Agents', 'claude', '-NoDocs', '-Yes', '-Force')
    Check '-Force replaces it' { Test-Installed $cl }
    Check "the foreign link's TARGET survives (junction removal is not recursive)" { Test-Path (Join-Path $precious 'keep.txt') }

    Section '-DryRun changes nothing'
    Fresh 'g'
    $before = Get-TreeHash
    $rc = Run @('-Agents', 'all', '-Docs', '-Yes', '-DryRun')
    Check 'exits 0' { $rc -eq 0 }
    Check 'file tree unchanged' { (Get-TreeHash) -eq $before }

    Section '-Copy, then -Update refreshes copies'
    Fresh 'h'
    $null = Run @('-Agents', 'kiro', '-Copy', '-NoDocs', '-Yes')
    $luau = PJoin (AgentDir '.kiro/skills') $Skill 'references' 'luau-fundamentals.md'
    Set-Content -LiteralPath $luau -Value 'STALE'
    $rc = Run @('-Update')
    Check '-Update exits 0' { $rc -eq 0 }
    Check 'stale copy refreshed' { (Get-Content -LiteralPath $luau -TotalCount 1) -ne 'STALE' }
    Check 'update did not opt into RobloxDocs' { -not (Test-Path (Join-Path $H 'RobloxDocs')) }

    Section 'custom -Path with a space'
    Fresh 'i'
    $custom = Join-Path $H 'my skills'
    $null = Run @('-Agents', 'universal', '-Path', $custom, '-NoDocs', '-Yes')
    Check 'installed into custom path' { Test-Installed $custom }

    Section 'uninstall removes only what it made'
    Fresh 'j'
    $null = Run @('-Agents', 'universal,claude', '-NoDocs', '-Yes')
    $roo = AgentDir '.roo/skills'; $precious = Join-Path $H 'precious'
    New-Item -ItemType Directory -Force -Path $roo, $precious | Out-Null
    Set-Content -LiteralPath (Join-Path $precious 'keep.txt') -Value 'keep'
    New-ForeignLink (Join-Path $roo $Skill) $precious
    $rc = Run @('-Uninstall')
    Check 'exits 0' { $rc -eq 0 }
    Check 'our links removed' { -not (Test-Path (Join-Path (AgentDir '.agents/skills') $Skill)) -and -not (Test-Path (Join-Path (AgentDir '.claude/skills') $Skill)) }
    Check 'stored skill removed' { -not (Test-Path $Payload) }
    Check 'foreign link and its target survive' { (Get-Item -LiteralPath (Join-Path $roo $Skill) -Force).LinkType -and (Test-Path (Join-Path $precious 'keep.txt')) }

    Section 'errors'
    Fresh 'k'
    $rc = Run @('-Agents', 'claude,nope', '-Yes') @{ ROBLOX_SKILL_EXIT_ON_ERROR = '1' }
    Check 'install.cmd mode: unknown agent exits 1' { $rc -eq 1 }
    Check 'names the bad agent' { $Log -match "unknown agent 'nope'" }

    Section 'irm | iex semantics'
    Fresh 'l'
    $probe = @"
`$env:ROBLOX_SKILL_HOME = '$H'; `$env:ROBLOX_SKILL_STORE = '$Store'; `$env:ROBLOX_SKILL_REF = 'does-not-exist-ref'
`$ErrorActionPreference = 'Continue'
Get-Content -Raw '$Installer' | Invoke-Expression *> `$null
'EAP=' + `$ErrorActionPreference
'LEAKED=' + ((Get-Command Install-Link, Invoke-Main -ErrorAction SilentlyContinue | Measure-Object).Count)
'ALIVE=yes'
"@
    $ErrorActionPreference = 'Continue'
    $out = (& $Exe -NoProfile -ExecutionPolicy Bypass -Command $probe 2>&1 | Out-String)
    $ErrorActionPreference = 'Stop'
    Check 'a failure inside iex does not close the session' { $out -match 'ALIVE=yes' }
    Check "caller's preferences untouched" { $out -match 'EAP=Continue' }
    Check 'no functions leak into the caller' { $out -match 'LEAKED=0' }

    Section 'RobloxDocs (network)'
    if ($env:SKIP_NETWORK -eq '1') { Skip 'RobloxDocs download (SKIP_NETWORK=1)' }
    else {
        Fresh 'm'
        $rc = Run @('-Agents', 'universal', '-Docs', '-Yes')
        Check 'exits 0' { $rc -eq 0 }
        Check 'config points at installed skill' { (Get-Content (PJoin $H 'RobloxDocs' 'config') -Raw) -match "SKILL_REFS=.*$Skill.references" }
        Check 'dump split into >900 classes' { @(Get-ChildItem (PJoin $H 'RobloxDocs' 'RobloxAPI' 'classes')).Count -gt 900 }
        Check 'example audit reports 0 defects' { $Log -match 'DEFECTS: 0' }
    }
} finally {
    # remove links first so a recursive delete can never walk into a target
    Get-ChildItem -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.LinkType } |
        ForEach-Object {
            # directory links are removed as reparse points; file links (e.g. RobloxDocs' latest.json) as files
            if ($OnWindows -and $_.PSIsContainer) { [IO.Directory]::Delete($_.FullName, $false) } else { [IO.File]::Delete($_.FullName) }
        }
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ("{0} passed, {1} failed, {2} skipped" -f $script:Pass, $script:Fail, $script:Skip)
if ($script:Fail -gt 0) { exit 1 }
