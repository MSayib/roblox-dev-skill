@echo off
rem roblox-dev-skill installer for Windows CMD -- https://github.com/MSayib/roblox-dev-skill
rem
rem   curl -fsSL https://raw.githubusercontent.com/MSayib/roblox-dev-skill/master/install.cmd -o install.cmd && install.cmd
rem
rem A thin launcher: it runs install.ps1 in PowerShell and passes your options through, e.g.
rem   install.cmd -Agents claude,universal -Yes
rem Run "install.cmd -Help" for every option.

setlocal
rem tell install.ps1 it owns this process, so a failure may set a non-zero exit code
set "ROBLOX_SKILL_EXIT_ON_ERROR=1"
rem ROBLOX_SKILL_REF picks a branch, tag or commit; install.ps1 reads the same variable
set "RDS_REF=master"
if defined ROBLOX_SKILL_REF set "RDS_REF=%ROBLOX_SKILL_REF%"
set "PS_EXE="
where powershell >nul 2>nul && set "PS_EXE=powershell"
if not defined PS_EXE ( where pwsh >nul 2>nul && set "PS_EXE=pwsh" )
if not defined PS_EXE (
    echo PowerShell was not found. Install PowerShell, or run install.sh from Git Bash or WSL.
    endlocal & exit /b 1
)

%PS_EXE% -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12;" ^
  "$ProgressPreference = 'SilentlyContinue';" ^
  "$s = Invoke-RestMethod -UseBasicParsing 'https://raw.githubusercontent.com/MSayib/roblox-dev-skill/%RDS_REF%/install.ps1';" ^
  "& ([scriptblock]::Create($s)) %*"
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
