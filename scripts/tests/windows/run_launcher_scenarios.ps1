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
        // Every call is appended to STUB_CALLS so a scenario can assert which
        // subcommands ran (e.g. that `compose up` never ran after a failed pull).
        string log = Environment.GetEnvironmentVariable("STUB_CALLS");
        if (!string.IsNullOrEmpty(log)) File.AppendAllText(log, string.Join(" ", a) + "\n");
        if (a.Length >= 1 && a[0] == "info") return Fail("STUB_INFO_FAIL");
        // The image list the Compose file references. Fixed on purpose: what is
        // under test is whether the launcher checks the images, not how Compose
        // resolves them. Two images, so a launcher that stops after the first
        // is caught, and the first is padded with spaces, so a launcher that
        // does not trim both ends inspects a name the stub does not know.
        // STUB_CONFIG_EMPTY=1 models a Compose that lists nothing.
        if (a.Length >= 3 && a[0] == "compose" && a[1] == "config" && a[2] == "--images") {
            if (Fail("STUB_CONFIG_FAIL") == 1) return 1;
            if (Fail("STUB_CONFIG_EMPTY") == 1) return 0;
            Console.WriteLine("  jmgirard/rstudio2u:latest  ");
            Console.WriteLine("busybox:stable");
            return 0;
        }
        // `image inspect <name>` succeeds only for a name the config list
        // carries. STUB_IMAGE_ABSENT=1 makes every image absent;
        // STUB_IMAGE_ABSENT=<name> makes only that one absent.
        if (a.Length >= 2 && a[0] == "image" && a[1] == "inspect") {
            if (Fail("STUB_IMAGE_ABSENT") == 1) return 1;
            string name = a.Length >= 3 ? a[2] : "";
            if (Environment.GetEnvironmentVariable("STUB_IMAGE_ABSENT") == name) return 1;
            return (name == "jmgirard/rstudio2u:latest" || name == "busybox:stable") ? 0 : 1;
        }
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
$callsPath = Join-Path $work 'calls.txt'
$fails = 0

# The offline warning must appear only when the pull failed AND the fallback
# ran; every scenario whose stubbed pull succeeds asserts it is absent, and the
# hard-error scenarios forbid it explicitly.
$offlineWarning = 'the update was skipped'
# The hard error's own second line -- its first line is a prefix of the warning,
# so it cannot tell the two branches apart.
$hardError = 'Check your internet connection'

function Invoke-Scenario {
    param(
        [string]   $Name,
        [string]   $PathValue,
        [hashtable]$ExtraEnv,
        [int]      $ExpectExit,
        [string[]] $ExpectText,
        [string]   $DotEnv,
        # A prefix of a stub argv line (e.g. 'compose up') that must / must not
        # have been called.
        [string]   $ExpectCall,
        [string]   $ForbidCall,
        # A substring that must be absent from the launcher's output.
        [string]   $ForbidText
    )
    # Seed (or clear) the sandbox .env for this scenario.
    if (Test-Path $dotenvPath) { Remove-Item $dotenvPath -Force }
    if ($DotEnv) { Set-Content -Path $dotenvPath -Value $DotEnv -Encoding Ascii }
    if (Test-Path $callsPath) { Remove-Item $callsPath -Force }
    # Generate a wrapper that sets PATH + env in the child shell itself, then
    # calls the launcher and forwards its exit code.
    $lines = @('@echo off', "set `"PATH=$PathValue`"", 'set "RS_LAUNCHER_NONINTERACTIVE=1"',
               "set `"STUB_CALLS=$callsPath`"")
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
    $called = @()
    if (Test-Path $callsPath) { $called = Get-Content $callsPath }
    if ($ExpectCall -and -not ($called | Where-Object { $_.StartsWith($ExpectCall) })) {
        $ok = $false
        Write-Host "FAIL: $Name - docker '$ExpectCall' was not called"
    }
    if ($ForbidCall -and ($called | Where-Object { $_.StartsWith($ForbidCall) })) {
        $ok = $false
        Write-Host "FAIL: $Name - docker '$ForbidCall' was called"
    }
    if ($ForbidText -and $out -match [regex]::Escape($ForbidText)) {
        $ok = $false
        Write-Host "FAIL: $Name - output contains forbidden '$ForbidText'"
    }
    if ($ExtraEnv['STUB_PULL_FAIL'] -ne '1' -and $out -match [regex]::Escape($offlineWarning)) {
        $ok = $false
        Write-Host "FAIL: $Name - offline warning printed although the pull succeeded"
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

# A failed pull with no local copy is still a hard stop, and the server must
# not be started.
Invoke-Scenario -Name 'pull-failure'         -PathValue $stubPath `
    -ExtraEnv @{ STUB_PULL_FAIL = '1'; STUB_IMAGE_ABSENT = '1' } `
    -ExpectExit 1 -ExpectText @($hardError) -ForbidCall 'compose up' -ForbidText $offlineWarning

# --- offline fallback --------------------------------------------------------
# A failed pull with every image already downloaded starts that copy, with a
# warning that the update was skipped and no hard error.
Invoke-Scenario -Name 'offline-fallback'     -PathValue $stubPath -ExtraEnv @{ STUB_PULL_FAIL = '1' } `
    -ExpectExit 0 -ExpectText @($offlineWarning, 'RStudio Server is running') `
    -ExpectCall 'compose up' -ForbidText $hardError

# Only the second listed image is missing: the launcher must check every image,
# not just the first.
Invoke-Scenario -Name 'offline-second-image-absent' -PathValue $stubPath `
    -ExtraEnv @{ STUB_PULL_FAIL = '1'; STUB_IMAGE_ABSENT = 'busybox:stable' } `
    -ExpectExit 1 -ExpectText @($hardError) -ForbidCall 'compose up' -ForbidText $offlineWarning

# If Compose cannot even list its images, keep the hard error rather than guess.
Invoke-Scenario -Name 'offline-config-unsupported' -PathValue $stubPath `
    -ExtraEnv @{ STUB_PULL_FAIL = '1'; STUB_CONFIG_FAIL = '1' } `
    -ExpectExit 1 -ExpectText @($hardError) -ForbidCall 'compose up' -ForbidText $offlineWarning

# A Compose that lists no images at all is treated the same way.
Invoke-Scenario -Name 'offline-config-empty' -PathValue $stubPath `
    -ExtraEnv @{ STUB_PULL_FAIL = '1'; STUB_CONFIG_EMPTY = '1' } `
    -ExpectExit 1 -ExpectText @($hardError) -ForbidCall 'compose up' -ForbidText $offlineWarning

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
