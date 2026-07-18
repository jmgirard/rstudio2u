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

Run by .github/workflows/launchers.yml (windows-latest).
#>
$ErrorActionPreference = 'Stop'
$repo   = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$source = Join-Path $repo 'start_windows.bat'
if (-not (Test-Path $source)) { throw "launcher not found: $source" }

$work    = Join-Path $env:RUNNER_TEMP 'launcher-test'
$stubDir = Join-Path $work 'stub'
New-Item -ItemType Directory -Force -Path $stubDir | Out-Null

# Run the launcher from a sandbox copy, never the repo, so a scenario can write
# a .env without touching the working tree. The launcher cd's to its own
# directory, so the copy's location is what it reads .env from.
$sandbox  = Join-Path $work 'sandbox'
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
Copy-Item $source $sandbox -Force
$launcher = Join-Path $sandbox 'start_windows.bat'
# Named $dotenvPath, not $dotenv: PowerShell variable names are case-insensitive,
# so a $DotEnv parameter would shadow it inside Invoke-Scenario.
$dotenvPath = Join-Path $sandbox '.env'

# Compile a docker.exe stub whose info / compose-pull / compose-up outcomes are
# driven by STUB_*_FAIL env vars. csc.exe (.NET Framework) ships on the runner.
#
# `compose port` models Compose's own port resolution (RS_PORT, else .env, else
# 8787) rather than echoing a fixed value, so the precedence assertions test the
# launcher against Compose's behavior instead of against themselves.
# STUB_BOUND_PORT overrides that, which is how the "Compose is the authority"
# scenario forces a disagreement between the requested and the bound port.
$cs = @'
using System;
using System.IO;
class DockerStub {
    static int Fail(string v) { return Environment.GetEnvironmentVariable(v) == "1" ? 1 : 0; }
    static string ResolvePort() {
        string p = Environment.GetEnvironmentVariable("STUB_BOUND_PORT");
        if (!string.IsNullOrEmpty(p)) return p;
        p = Environment.GetEnvironmentVariable("RS_PORT");
        if (!string.IsNullOrEmpty(p)) return p;
        if (File.Exists(".env")) {
            foreach (string line in File.ReadAllLines(".env")) {
                string l = line.Trim();
                if (l.StartsWith("RS_PORT=")) {
                    p = l.Substring(8).Trim().Trim('"');
                }
            }
        }
        return string.IsNullOrEmpty(p) ? "8787" : p;
    }
    static int Main(string[] a) {
        if (a.Length >= 1 && a[0] == "info") return Fail("STUB_INFO_FAIL");
        if (a.Length >= 2 && a[0] == "compose" && a[1] == "pull") return Fail("STUB_PULL_FAIL");
        if (a.Length >= 2 && a[0] == "compose" && a[1] == "up") return Fail("STUB_UP_FAIL");
        if (a.Length >= 2 && a[0] == "compose" && a[1] == "port") {
            if (Fail("STUB_PORT_FAIL") == 1) return 1;
            Console.WriteLine("127.0.0.1:" + ResolvePort());
            return 0;
        }
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

# The runner's real docker.exe turns out to be reachable via System32/Windows,
# so "Docker not installed" cannot be simulated by merely omitting a stub dir.
# Instead point PATH at a clean dir holding ONLY the tools the launcher needs
# (where.exe for `where docker`, chcp.com for the codepage line) and no docker.
$nodockDir = Join-Path $work 'nodock'
New-Item -ItemType Directory -Force -Path $nodockDir | Out-Null
Copy-Item "$env:WINDIR\System32\where.exe" $nodockDir -Force
Copy-Item "$env:WINDIR\System32\chcp.com"  $nodockDir -Force

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
        [string[]] $ExpectText,
        [string]   $DotEnv
    )
    # Seed (or clear) the sandbox .env for this scenario.
    if (Test-Path $dotenvPath) { Remove-Item $dotenvPath -Force }
    if ($DotEnv) { Set-Content -Path $dotenvPath -Value $DotEnv -Encoding Ascii }
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

Invoke-Scenario -Name 'docker-not-installed' -PathValue $nodockDir -ExtraEnv @{} `
    -ExpectExit 1 -ExpectText @('does not appear to be installed')

Invoke-Scenario -Name 'docker-not-running'   -PathValue $stubPath -ExtraEnv @{ STUB_INFO_FAIL = '1' } `
    -ExpectExit 1 -ExpectText @('installed but not running')

Invoke-Scenario -Name 'pull-failure'         -PathValue $stubPath -ExtraEnv @{ STUB_PULL_FAIL = '1' } `
    -ExpectExit 1 -ExpectText @('Could not download the latest image')

# The timeout message must name the port override, including the .env form a
# double-clicking user can actually use.
Invoke-Scenario -Name 'health-timeout'       -PathValue $stubPath -ExtraEnv @{ STUB_UP_FAIL = '1' } `
    -ExpectExit 1 -ExpectText @('did not become ready in time', 'RS_PORT', '.env')

# --- port resolution ---------------------------------------------------------

Invoke-Scenario -Name 'port-default'         -PathValue $stubPath -ExtraEnv @{} `
    -ExpectExit 0 -ExpectText @('RStudio Server is running', 'http://localhost:8787', 'go to that address manually')

Invoke-Scenario -Name 'port-from-env'        -PathValue $stubPath -ExtraEnv @{ RS_PORT = '8888' } `
    -ExpectExit 0 -ExpectText @('http://localhost:8888')

Invoke-Scenario -Name 'port-from-dotenv'     -PathValue $stubPath -ExtraEnv @{} `
    -ExpectExit 0 -ExpectText @('http://localhost:8888') -DotEnv 'RS_PORT=8888'

Invoke-Scenario -Name 'port-from-dotenv-quoted' -PathValue $stubPath -ExtraEnv @{} `
    -ExpectExit 0 -ExpectText @('http://localhost:8899') -DotEnv 'RS_PORT="8899"'

Invoke-Scenario -Name 'port-env-beats-dotenv' -PathValue $stubPath -ExtraEnv @{ RS_PORT = '8899' } `
    -ExpectExit 0 -ExpectText @('http://localhost:8899') -DotEnv 'RS_PORT=8888'

# Compose is the authority: report what was bound, even when it differs from
# what was requested.
Invoke-Scenario -Name 'port-compose-is-authority' -PathValue $stubPath `
    -ExtraEnv @{ RS_PORT = '8888'; STUB_BOUND_PORT = '9999' } `
    -ExpectExit 0 -ExpectText @('http://localhost:9999')

# If the query fails, fall back to the requested value rather than lying.
Invoke-Scenario -Name 'port-query-failure-falls-back' -PathValue $stubPath `
    -ExtraEnv @{ RS_PORT = '8888'; STUB_PORT_FAIL = '1' } `
    -ExpectExit 0 -ExpectText @('http://localhost:8888')

# --- the launcher's OWN .env parse -------------------------------------------
# The scenarios above cannot see it: the stub resolves .env itself, so the
# announced port comes from the stub's parse whatever the launcher does. These
# force the launcher's reading to reach the output -- via validation, which only
# ever uses the launcher's own parse, and via STUB_PORT_FAIL, which makes the
# fallback path observable.

Invoke-Scenario -Name 'dotenv-invalid-is-rejected' -PathValue $stubPath -ExtraEnv @{} `
    -ExpectExit 1 -ExpectText @('not a usable port number') -DotEnv 'RS_PORT=0'

Invoke-Scenario -Name 'dotenv-parse-reaches-output' -PathValue $stubPath `
    -ExtraEnv @{ STUB_PORT_FAIL = '1' } `
    -ExpectExit 0 -ExpectText @('http://localhost:8855') -DotEnv 'RS_PORT=8855'

# An inline comment is a comment to Compose, so it must not become part of the
# value -- rejecting here would refuse a .env that works.
Invoke-Scenario -Name 'dotenv-inline-comment' -PathValue $stubPath `
    -ExtraEnv @{ STUB_PORT_FAIL = '1' } `
    -ExpectExit 0 -ExpectText @('http://localhost:8866') `
    -DotEnv 'RS_PORT=8866  # avoid clash with my other container'

# Trailing whitespace is invisible in an editor and must not reject. The old
# leading-only trim rejected this on Windows while POSIX and Compose accepted it.
Invoke-Scenario -Name 'dotenv-trailing-space' -PathValue $stubPath `
    -ExtraEnv @{ STUB_PORT_FAIL = '1' } `
    -ExpectExit 0 -ExpectText @('http://localhost:8877') -DotEnv 'RS_PORT=8877 '

# A :0 binding means nothing is published; fall back rather than announce it,
# and the fallback must reach the requested value, not skip to the default.
Invoke-Scenario -Name 'bound-port-zero-falls-back' -PathValue $stubPath `
    -ExtraEnv @{ STUB_BOUND_PORT = '0' } `
    -ExpectExit 0 -ExpectText @('http://localhost:8787')

Invoke-Scenario -Name 'bound-port-zero-uses-requested' -PathValue $stubPath `
    -ExtraEnv @{ STUB_BOUND_PORT = '0' } `
    -ExpectExit 0 -ExpectText @('http://localhost:8844') -DotEnv 'RS_PORT=8844'

# --- rejected values ---------------------------------------------------------
# Single-quoted on purpose: '${CUSTOM}' must reach the launcher literally, not
# be interpolated by PowerShell.
foreach ($bad in @('88ss', '0', '70000', '0.0.0.0:8888')) {
    Invoke-Scenario -Name "port-invalid-$bad" -PathValue $stubPath -ExtraEnv @{ RS_PORT = $bad } `
        -ExpectExit 1 -ExpectText @('not a usable port number', $bad)
}

Invoke-Scenario -Name 'port-interpolation-passes-through' -PathValue $stubPath `
    -ExtraEnv @{ RS_PORT = '${CUSTOM}' } `
    -ExpectExit 0 -ExpectText @('RStudio Server is running')

if ($fails -ne 0) {
    Write-Host "FAILED: $fails launcher scenario(s)"
    exit 1
}
Write-Host "PASS: all launcher scenarios"
