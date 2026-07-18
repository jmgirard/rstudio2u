<#
Drives start_windows.bat through every branch of its failure/success logic on a
real Windows runner, using a stub `docker` on PATH instead of the real engine —
so the least-tested launcher path is actually executed, not just eyeballed.

Each scenario runs the launcher in a child cmd.exe with a controlled PATH and
environment, then asserts the process exit code and a message substring. The
launcher's RS_LAUNCHER_NONINTERACTIVE seam suppresses pause/timeout/browser so
every scenario runs unattended.

Run by .github/workflows/windows-launcher.yml (windows-latest). No network, no
Docker.
#>
$ErrorActionPreference = 'Stop'
$repo     = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$launcher = Join-Path $repo 'start_windows.bat'
if (-not (Test-Path $launcher)) { throw "launcher not found: $launcher" }

# A stub `docker.cmd` whose info/compose-pull/compose-up outcomes are driven by
# STUB_*_FAIL env vars. Written to a temp dir we prepend to PATH per scenario.
$stubDir = Join-Path $env:RUNNER_TEMP 'docker-stub'
New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
$stub = @'
@echo off
if "%~1"=="info" (
    if "%STUB_INFO_FAIL%"=="1" exit /b 1
    exit /b 0
)
if "%~1"=="compose" (
    if "%~2"=="pull" (
        if "%STUB_PULL_FAIL%"=="1" exit /b 1
        exit /b 0
    )
    if "%~2"=="up" (
        if "%STUB_UP_FAIL%"=="1" exit /b 1
        exit /b 0
    )
)
exit /b 0
'@
Set-Content -Path (Join-Path $stubDir 'docker.cmd') -Value $stub -Encoding Ascii

# Minimal PATH with no docker anywhere (real docker lives under Program Files,
# not System32) — used to simulate "Docker not installed".
$sysPath  = "$env:SystemRoot\System32;$env:SystemRoot"
$stubPath = "$stubDir;$sysPath"
$fails = 0

function Invoke-Scenario {
    param(
        [string]   $Name,
        [string]   $PathValue,
        [hashtable]$ExtraEnv,
        [int]      $ExpectExit,
        [string[]] $ExpectText
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = "$env:SystemRoot\System32\cmd.exe"
    $psi.Arguments              = "/c `"$launcher`""
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    # Inherit the current environment, then override PATH + add scenario vars.
    $psi.EnvironmentVariables['PATH'] = $PathValue
    $psi.EnvironmentVariables['RS_LAUNCHER_NONINTERACTIVE'] = '1'
    foreach ($k in $ExtraEnv.Keys) { $psi.EnvironmentVariables[$k] = $ExtraEnv[$k] }

    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    $ok = $true
    if ($p.ExitCode -ne $ExpectExit) {
        $ok = $false
        Write-Host "FAIL: $Name - expected exit $ExpectExit, got $($p.ExitCode)"
    }
    foreach ($t in $ExpectText) {
        if ($out -notmatch [regex]::Escape($t)) {
            $ok = $false
            Write-Host "FAIL: $Name - output missing '$t'"
        }
    }
    if ($ok) { Write-Host "ok: $Name (exit $($p.ExitCode))" }
    else {
        Write-Host "----- $Name output -----"
        Write-Host $out
        Write-Host "------------------------"
        $script:fails++
    }
}

Invoke-Scenario -Name 'docker-not-installed' -PathValue $sysPath  -ExtraEnv @{} `
    -ExpectExit 1 -ExpectText @('does not appear to be installed')

Invoke-Scenario -Name 'docker-not-running'   -PathValue $stubPath -ExtraEnv @{ STUB_INFO_FAIL = '1' } `
    -ExpectExit 1 -ExpectText @('installed but not running')

Invoke-Scenario -Name 'pull-failure'         -PathValue $stubPath -ExtraEnv @{ STUB_PULL_FAIL = '1' } `
    -ExpectExit 1 -ExpectText @('Could not download the latest image')

Invoke-Scenario -Name 'health-timeout'       -PathValue $stubPath -ExtraEnv @{ STUB_UP_FAIL = '1' } `
    -ExpectExit 1 -ExpectText @('did not become ready in time', 'RS_PORT')

Invoke-Scenario -Name 'success'              -PathValue $stubPath -ExtraEnv @{} `
    -ExpectExit 0 -ExpectText @('RStudio Server is running', 'go to that address manually')

if ($fails -ne 0) {
    Write-Host "FAILED: $fails launcher scenario(s)"
    exit 1
}
Write-Host "PASS: all launcher scenarios"
