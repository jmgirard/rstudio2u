#!/usr/bin/env bash
#
# Runs start_linux.sh against real Docker and Compose and fails when the port
# the launcher announces is not the port that answers. It is the counterpart of
# run_launcher_scenarios.sh, whose stub `docker` models Compose instead of
# asking it. The launcher's own `docker compose pull` fetches the published
# image, so the first run on a machine downloads about 1 GB.
#
# The launcher runs from a temporary copy under its own Compose project, so a
# run cannot touch a .env in this checkout or the home volume of a real
# rstudio2u project. Ports 8787, 8888, and 8889 must be free.
#
# Run by the launcher-compose jobs in .github/workflows/launchers.yml and
# .github/workflows/docker.yml (ubuntu-latest).

set -uo pipefail

repo=$(cd "$(dirname "$0")/../../.." && pwd)
[ -f "$repo/start_linux.sh" ] || { echo "launchers not found under $repo"; exit 1; }

for tool in docker curl jq; do
    command -v "$tool" >/dev/null 2>&1 || { echo "missing required tool: $tool"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "the Docker daemon cannot be reached"; exit 1; }

# A value from the calling shell would decide every scenario.
unset RS_PORT
export COMPOSE_PROJECT_NAME=rstudio2u-real-compose-test

work=$(mktemp -d)
sandbox="$work/sandbox"
output="$work/launcher-output"
mkdir -p "$sandbox"
cp "$repo/start_linux.sh" "$repo/launcher_common.sh" "$repo/docker-compose.yml" "$sandbox/"

compose_in_sandbox() {
    (cd "$sandbox" && docker compose "$@")
}

cleanup() {
    compose_in_sandbox down -v --remove-orphans >/dev/null 2>&1 ||
        echo "warning: could not remove Compose project $COMPOSE_PROJECT_NAME"
    rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

fails=0
failed=""

# check <name> <actual> <expected>
check() {
    if [ "$2" = "$3" ]; then
        echo "PASS: $1"
    else
        echo "FAIL: $1: expected [$3], got [$2]"
        fails=$((fails + 1))
        failed="$failed
  $1"
    fi
}

# run_scenario <name> <.env content or empty> <RS_PORT or empty> <expected port>
run_scenario() {
    local name=$1 dotenv=$2 env_port=$3 expected=$4 code url raw status

    compose_in_sandbox down >/dev/null 2>&1
    rm -f "$sandbox/.env"
    [ -z "$dotenv" ] || printf '%s\n' "$dotenv" > "$sandbox/.env"

    env ${env_port:+"RS_PORT=$env_port"} RS_LAUNCHER_NONINTERACTIVE=1 \
        bash "$sandbox/start_linux.sh" > "$output" 2>&1
    code=$?
    check "$name: launcher exit status" "$code" 0
    [ "$code" = 0 ] || tail -n 20 "$output"

    url=$(sed -n 's/^.*RStudio Server is running at \([^ ]*\)$/\1/p' "$output")
    check "$name: announced URL" "$url" "http://localhost:$expected"

    curl -sS -o /dev/null --max-time 10 "$url" 2>/dev/null
    check "$name: announced URL gets a response" "$?" 0

    raw=$(cd "$sandbox" && env ${env_port:+"RS_PORT=$env_port"} \
        docker compose port rstudio2u 8787 2>/dev/null)
    check "$name: docker compose port output" "$raw" "127.0.0.1:$expected"

    if [ "$expected" != 8787 ]; then
        curl -sS -o /dev/null --max-time 5 http://localhost:8787 2>/dev/null
        status=$?
        check "$name: port 8787 refuses the connection (curl exit 7)" "$status" 7
    fi
}

# compare_env <.env content>: the launcher's reader against Compose's own
# resolution, with no container started. An empty reader result means the
# launcher leaves the 8787 default to Compose.
compare_env() {
    local dotenv=$1 reader compose
    printf '%s\n' "$dotenv" > "$sandbox/.env"
    # shellcheck source=launcher_common.sh disable=SC1091
    reader=$(cd "$sandbox" && . ./launcher_common.sh && launcher_requested_port)
    compose=$(compose_in_sandbox config --format json 2>/dev/null |
        jq -r '.services.rstudio2u.ports[0].published')
    check ".env reader agrees with Compose on: ${dotenv//$'\n'/ then }" "${reader:-8787}" "$compose"
}

compare_env 'RS_PORT=8888'
compare_env 'RS_PORT="8890"'
compare_env "RS_PORT='8891' # c"
compare_env 'RS_PORT=8892 # c'
compare_env 'export RS_PORT=8893'
compare_env '  RS_PORT = 8894'
compare_env $'RS_PORT=1111\nRS_PORT=8896'
compare_env 'RS_PORT='
compare_env '# RS_PORT=1111'

run_scenario "default port" "" "" 8787
run_scenario ".env port" "RS_PORT=8888" "" 8888
run_scenario "environment beats .env" "RS_PORT=8888" 8889 8889

echo ""
if [ "$fails" -gt 0 ]; then
    echo "$fails check(s) failed:$failed"
    exit 1
fi
echo "All real-Compose launcher checks passed."
