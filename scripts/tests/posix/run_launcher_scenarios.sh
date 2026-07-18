#!/usr/bin/env bash
#
# Drives start_mac.command and start_linux.sh through every branch of their
# failure/success logic using a stub `docker` on PATH instead of the real
# engine -- the POSIX counterpart to
# scripts/tests/windows/run_launcher_scenarios.ps1, so all three launchers are
# executed by CI rather than eyeballed.
#
# Details this harness must respect:
#   * PATH is fully controlled (env -i) so the runner's real docker cannot leak
#     in -- "docker not installed" cannot be simulated by merely omitting the
#     stub dir, since ubuntu-latest ships docker in /usr/bin. The clean dir
#     holds symlinks to ONLY the externals the launchers call (dirname, chmod);
#     everything else they use is a bash builtin.
#   * `env -i` resolves the interpreter against the scrubbed PATH, so bash is
#     named absolutely here and the stub carries an absolute /bin/sh shebang.
#   * The launchers run from a sandbox copy, never the repo, so a scenario can
#     write a .env without touching the developer's own file.
#   * Both launchers run under bash on Linux. start_mac.command's mac-only calls
#     (xattr, open) are best-effort or seam-suppressed, so driving it here
#     exercises its real logic; executing it on genuine macOS is separate.
#
# The stub models Compose's own port resolution (RS_PORT, else .env, else 8787)
# rather than echoing a fixed value, so the precedence assertions test the
# launcher against Compose's real behavior instead of against themselves.
# STUB_BOUND_PORT overrides that, which is how the "Compose is the authority"
# scenario forces a disagreement between requested and bound.
#
# Run by .github/workflows/launchers.yml (ubuntu-latest).

set -uo pipefail

repo=$(cd "$(dirname "$0")/../../.." && pwd)
[ -f "$repo/start_mac.command" ] || { echo "launchers not found under $repo"; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --- sandbox: run the launchers outside the repo ------------------------------
sandbox="$work/sandbox"
mkdir -p "$sandbox"
cp "$repo/start_mac.command" "$repo/start_linux.sh" "$repo/launcher_common.sh" "$sandbox/"

# --- stub docker: outcomes driven by STUB_* env vars --------------------------
# Absolute shebang on purpose: the stub is invoked through the scrubbed PATH,
# so `/usr/bin/env bash` would fail to resolve an interpreter.
stub="$work/stub"
mkdir -p "$stub"
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
    if [ -n "${STUB_BOUND_PORT:-}" ]; then
        printf '127.0.0.1:%s\n' "$STUB_BOUND_PORT"
        exit 0
    fi
    # Model Compose's resolution for the plain forms the scenarios use.
    p=${RS_PORT:-}
    if [ -z "$p" ] && [ -f .env ]; then
        while IFS= read -r l || [ -n "$l" ]; do
            case $l in
                RS_PORT=*) p=${l#RS_PORT=} ;;
            esac
        done < .env
        p=${p#\"}; p=${p%\"}
    fi
    printf '127.0.0.1:%s\n' "${p:-8787}"
    exit 0
fi
exit 0
STUB
chmod +x "$stub/docker"

# --- clean dir with the externals the launchers need, but no docker -----------
nodock="$work/nodock"
mkdir -p "$nodock"
for t in dirname chmod; do
    src=$(command -v "$t") || { echo "missing required tool: $t"; exit 1; }
    ln -sf "$src" "$nodock/$t"
done

stub_path="$stub:$nodock"
fails=0

bash_bin=$(command -v bash) || { echo "bash not found"; exit 1; }

# Set before a run_scenario call to seed the sandbox .env; cleared after each.
DOTENV=""

# run_scenario <name> <launcher> <PATH> <expected-exit> <env-assignments> <expected-substring>...
run_scenario() {
    local name=$1 launcher=$2 pathv=$3 expect=$4 envs=$5
    shift 5
    local out code ok=1

    rm -f "$sandbox/.env"
    [ -n "$DOTENV" ] && printf '%s\n' "$DOTENV" > "$sandbox/.env"

    # shellcheck disable=SC2086  # $envs is a controlled list of VAR=VAL pairs
    out=$(cd "$sandbox" && env -i PATH="$pathv" HOME="$HOME" TERM=dumb \
            RS_LAUNCHER_NONINTERACTIVE=1 $envs \
            "$bash_bin" "./$launcher" 2>&1)
    code=$?

    rm -f "$sandbox/.env"
    DOTENV=""

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
    # --- pre-existing failure/success branches --------------------------------
    run_scenario "$launcher/docker-not-installed" "$launcher" "$nodock" 1 "" \
        'does not appear to be installed'

    run_scenario "$launcher/docker-not-running" "$launcher" "$stub_path" 1 \
        'STUB_INFO_FAIL=1' 'installed but not running'

    run_scenario "$launcher/pull-failure" "$launcher" "$stub_path" 1 \
        'STUB_PULL_FAIL=1' 'Could not download the latest image'

    # The timeout message must name the port override, on every launcher.
    run_scenario "$launcher/health-timeout" "$launcher" "$stub_path" 1 \
        'STUB_UP_FAIL=1' 'did not become ready in time' 'RS_PORT' '.env'

    # --- port resolution ------------------------------------------------------
    run_scenario "$launcher/port-default" "$launcher" "$stub_path" 0 "" \
        'RStudio Server is running' 'http://localhost:8787' \
        'go to that address manually'

    run_scenario "$launcher/port-from-env" "$launcher" "$stub_path" 0 \
        'RS_PORT=8888' 'http://localhost:8888'

    DOTENV='RS_PORT=8888'
    run_scenario "$launcher/port-from-dotenv" "$launcher" "$stub_path" 0 "" \
        'http://localhost:8888'

    DOTENV='RS_PORT="8899"'
    run_scenario "$launcher/port-from-dotenv-quoted" "$launcher" "$stub_path" 0 "" \
        'http://localhost:8899'

    DOTENV='RS_PORT=8888'
    run_scenario "$launcher/port-env-beats-dotenv" "$launcher" "$stub_path" 0 \
        'RS_PORT=8899' 'http://localhost:8899'

    # Compose is the authority: the launcher must report what was bound, even
    # when that differs from what was requested.
    run_scenario "$launcher/port-compose-is-authority" "$launcher" "$stub_path" 0 \
        'RS_PORT=8888 STUB_BOUND_PORT=9999' 'http://localhost:9999'

    # If the query fails, fall back to the requested value rather than lying.
    run_scenario "$launcher/port-query-failure-falls-back" "$launcher" "$stub_path" 0 \
        'RS_PORT=8888 STUB_PORT_FAIL=1' 'http://localhost:8888'

    # --- rejected values ------------------------------------------------------
    for bad in 88ss 0 70000 0.0.0.0:8888; do
        run_scenario "$launcher/port-invalid-$bad" "$launcher" "$stub_path" 1 \
            "RS_PORT=$bad" 'not a usable port number' "$bad"
    done

    # Interpolation we cannot read is Compose's business, not ours: pass it
    # through rather than refuse a config that may well work.
    run_scenario "$launcher/port-interpolation-passes-through" "$launcher" "$stub_path" 0 \
        'RS_PORT=${CUSTOM}' 'RStudio Server is running'
done

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails launcher scenario(s)"
    exit 1
fi
echo "PASS: all launcher scenarios"
