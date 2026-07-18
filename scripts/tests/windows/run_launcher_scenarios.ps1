<#
Drives start_windows.bat through every branch of its failure/success logic on a
real Windows runner, using a stub `docker` on PATH instead of the real engine —
so the least-tested launcher path is actually executed, not just eyeballed.

Two Windows details this harness must respect (both bit the first attempt):
  * The stub must be a real docker.exe, not a docker.cmd. The launcher invokes
    bare `docker ...`; if that resolves to a .cmd, cmd.exe *chains* to it and
    never returns to the launcher (batch-to-batch without `call` is a goto).
    Production docker.exe returns control normally, so an .exe stub matches
    reality; a .cmd stub would silently abort the launcher mid-run.
  * PATH/env must be set INSIDE the child shell (a generated wrapper .cmd), not
    via inherited-environment overrides — the latter proved unreliable and let
    the real Docker CLI leak onto PATH.

Each scenario sets a controlled PATH (+ STUB_*_FAIL) in the wrapper, calls the
launcher with RS_LAUNCHER_NONINTERACTIVE so it runs unattended, and asserts the
forwarded exit code and a message substring. No network, no real Docker.

Run by .github/workflows/windows-launcher.yml (windows-latest).
#>
$ErrorActionPreference = 'Stop'
$repo     = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$launcher = Join-Path $repo 'start_windows.bat'
if (-not (Test-Path $launcher)) { throw "launcher not found: $launcher" }

$work    = Join-Path $env:RUNNER_TEMP 'launcher-test'
$stubDir = Join-Path $work 'stub'
New-Item -ItemType Directory -Force -Path $stubDir | Out-Null

# Compile a docker.exe stub whose info / compose-pull / compose-up outcomes are
# driven by STUB_*_FAIL env vars. csc.exe (.NET Framework) ships on the runner.
$cs = @'
using System;
class DockerStub {
    static int Fail(string v) { return Environment.GetEnvironmentVariable(v) == "1" ? 1 : 0; }
    static int Main(string[] a) {
        if (a.Length >= 1 && a[0] == "info") return Fail("STUB_INFO_FAIL");
        if (a.Length >= 2 && a[0] == "compose" && a[1] == "pull") return Fail("STUB_PULL_FAIL");
        if (a.Length >= 2 && a[0] == "compose" && a[1] == "up") return Fail("STUB_UP_FAIL");
        return 0;
    }
}
'@
$csFile = Join-Path $work 'DockerStub.cs'
Set-Content -Path $csFile -Value $cs -Encoding Ascii
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "csc.exe not found at $csc" }
& $csc /nologo /out:"$stubDir\docker.exe" $csFile | Out-Null
if (-not (Test-Path "$stubDir\docker.exe")) { throw "failed to build docker.exe stub" }

# Minimal PATH with no docker anywhere (real docker lives under Program Files,
# not System32) — used to simulate "Docker not installed".
$sysPath  = "$env:WINDIR\System32;$env:WINDIR"
$stubPath = "$stubDir;$sysPath"
$wrapper  = Join-Path $work 'run.cmd'
$fails = 0

function Invoke-Scenario {
    param(
        [string]   $Name,
        [string]   $PathValue,
        [hashtable]$ExtraEnv,
        [int]      $ExpectExit,
        [string[]] $ExpectText
    )
    # Generate a wrapper that sets PATH + env in the child shell itself, then
    # calls the launcher and forwards its exit code.
    $lines = @('@echo off', "set `"PATH=$PathValue`"", 'set "RS_LAUNCHER_NONINTERACTIVE=1"')
    foreach ($k in $ExtraEnv.Keys) { $lines += "set `"$k=$($ExtraEnv[$k])`"" }
    $lines += "call `"$launcher`""
    $lines += 'exit /b %errorlevel%'
    Set-Content -Path $wrapper -Value $lines -Encoding Ascii

    $out  = (& cmd.exe /c $wrapper 2>&1 | Out-String)
    $code = $LASTEXITCODE

    $ok = $true
    if ($code -ne $ExpectExit) {
        $ok = $false
        Write-Host "FAIL: $Name - expected exit $ExpectExit, got $code"
    }
    foreach ($t in $ExpectText) {
        if ($out -notmatch [regex]::Escape($t)) {
            $ok = $false
            Write-Host "FAIL: $Name - output missing '$t'"
        }
    }
    if ($ok) { Write-Host "ok: $Name (exit $code)" }
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
