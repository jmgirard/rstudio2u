#!/usr/bin/env bash
#
# Drives start_mac.command and start_linux.sh through every branch of their
# failure/success logic using a stub `docker` on PATH instead of the real
# engine -- the POSIX counterpart to scripts/tests/windows/run_launcher_
# scenarios.ps1, so all three launchers are executed by CI rather than eyeballed.
#
# Two details this harness must respect:
#   * PATH is fully controlled (env -i) so the runner's real docker cannot leak
#     in -- "docker not installed" cannot be simulated by merely omitting the
#     stub dir, since ubuntu-latest ships docker in /usr/bin. The clean dir
#     holds symlinks to ONLY the externals the launchers call (dirname, chmod);
#     everything else they use is a bash builtin.
#   * Both launchers run under bash on Linux. start_mac.command's mac-only
#     calls (xattr, open) are best-effort or seam-suppressed, so driving it here
#     exercises its real logic; executing it on genuine macOS is a separate,
#     deferred concern.
#
# Each scenario runs a launcher with RS_LAUNCHER_NONINTERACTIVE so it completes
# unattended, then asserts the exit code and expected message substrings.
# No network, no real Docker, no browser.
#
# Run by .github/workflows/launchers.yml (ubuntu-latest).

set -uo pipefail

repo=$(cd "$(dirname "$0")/../../.." && pwd)
[ -f "$repo/start_mac.command" ] || { echo "launchers not found under $repo"; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --- stub docker: outcomes driven by STUB_* env vars -------------------------
stub="$work/stub"
mkdir -p "$stub"
# Absolute shebang on purpose: the stub is invoked through the scrubbed PATH,
# so `/usr/bin/env bash` would fail to resolve an interpreter.
cat > "$stub/docker" <<'STUB'
#!/bin/sh
if [ "${1:-}" = "info" ]; then
    [ "${STUB_INFO_FAIL:-}" = "1" ] && exit 1
    exit 0
fi
if [ "${1:-}" = "compose" ] && [ "${2:-}" = "pull" ]; then
    [ "${STUB_PULL_FAIL:-}" = "1" ] && exit 1
    exit 0
fi
if [ "${1:-}" = "compose" ] && [ "${2:-}" = "up" ]; then
    [ "${STUB_UP_FAIL:-}" = "1" ] && exit 1
    exit 0
fi
# `docker compose port <service> <port>` reports the real host binding; the
# launcher trusts this over any value it parsed itself.
if [ "${1:-}" = "compose" ] && [ "${2:-}" = "port" ]; then
    [ "${STUB_PORT_FAIL:-}" = "1" ] && exit 1
    printf '127.0.0.1:%s\n' "${STUB_BOUND_PORT:-8787}"
    exit 0
fi
exit 0
STUB
chmod +x "$stub/docker"

# --- clean dir with the externals the launchers need, but no docker ----------
nodock="$work/nodock"
mkdir -p "$nodock"
for t in dirname chmod; do
    src=$(command -v "$t") || { echo "missing required tool: $t"; exit 1; }
    ln -sf "$src" "$nodock/$t"
done

stub_path="$stub:$nodock"
fails=0

# `env -i` resolves the interpreter against the *scrubbed* PATH, so bash itself
# must be named absolutely -- the launchers' own PATH is the thing under test.
bash_bin=$(command -v bash) || { echo "bash not found"; exit 1; }

# run_scenario <name> <launcher> <PATH> <expected-exit> <env-assignments> <expected-substring>...
run_scenario() {
    local name=$1 launcher=$2 pathv=$3 expect=$4 envs=$5
    shift 5
    local out code ok=1

    # shellcheck disable=SC2086  # $envs is a controlled list of VAR=VAL pairs
    out=$(cd "$repo" && env -i PATH="$pathv" HOME="$HOME" TERM=dumb \
            RS_LAUNCHER_NONINTERACTIVE=1 $envs \
            "$bash_bin" "./$launcher" 2>&1)
    code=$?

    if [ "$code" != "$expect" ]; then
        ok=0
        echo "FAIL: $name - expected exit $expect, got $code"
    fi
    local t
    for t in "$@"; do
        case "$out" in
            *"$t"*) ;;
            *) ok=0; echo "FAIL: $name - output missing '$t'" ;;
        esac
    done

    if [ "$ok" = 1 ]; then
        echo "ok: $name (exit $code)"
    else
        echo "----- $name output -----"
        echo "$out"
        echo "------------------------"
        fails=$((fails + 1))
    fi
}

for launcher in start_mac.command start_linux.sh; do
    run_scenario "$launcher/docker-not-installed" "$launcher" "$nodock" 1 "" \
        'does not appear to be installed'

    run_scenario "$launcher/docker-not-running" "$launcher" "$stub_path" 1 \
        'STUB_INFO_FAIL=1' 'installed but not running'

    run_scenario "$launcher/pull-failure" "$launcher" "$stub_path" 1 \
        'STUB_PULL_FAIL=1' 'Could not download the latest image'

    run_scenario "$launcher/health-timeout" "$launcher" "$stub_path" 1 \
        'STUB_UP_FAIL=1' 'did not become ready in time'

    run_scenario "$launcher/success" "$launcher" "$stub_path" 0 "" \
        'RStudio Server is running'
done

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails launcher scenario(s)"
    exit 1
fi
echo "PASS: all launcher scenarios"
