#!/usr/bin/env bash
#
# Boot a locally-built rstudio2u image and confirm RStudio Server answers on
# :8787 before CI publishes any tag. Exits 0 once the container reports healthy
# within the timeout, non-zero if it exits, reports unhealthy, or times out.
# This is the gate that keeps an unattended rebuild from pushing a moving tag
# whose server won't start (GP7).
#
# Usage: .github/smoke-test.sh <image-tag>
# Env:
#   SMOKE_TIMEOUT  seconds to wait for health         (default 180)
#   SMOKE_PORT     host port to publish container :8787 on (default 8787)
#
set -euo pipefail

IMAGE="${1:?usage: smoke-test.sh <image-tag>}"
TIMEOUT="${SMOKE_TIMEOUT:-180}"
PORT="${SMOKE_PORT:-8787}"
NAME="rstudio2u-smoke-$$"
SMOKE_OK=0

cleanup() {
  # Dump recent container logs on failure to make CI triage possible, then
  # always remove the container.
  if [ "$SMOKE_OK" != "1" ]; then
    echo "--- container logs (tail) ---"
    docker logs --tail 50 "$NAME" 2>&1 || true
  fi
  docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> booting $IMAGE as $NAME (timeout ${TIMEOUT}s)"
docker run -d --name "$NAME" -p "127.0.0.1:${PORT}:8787" "$IMAGE" >/dev/null

# .State.Health is null when the image declares no HEALTHCHECK; in that case we
# fall back to probing the published port directly.
has_healthcheck() {
  [ "$(docker inspect --format '{{if .State.Health}}yes{{end}}' "$NAME" 2>/dev/null)" = "yes" ]
}

status="n/a"
deadline=$(( $(date +%s) + TIMEOUT ))
while :; do
  running="$(docker inspect --format '{{.State.Running}}' "$NAME" 2>/dev/null || echo false)"
  if [ "$running" != "true" ]; then
    echo "FAIL: container exited before becoming healthy"
    exit 1
  fi

  if has_healthcheck; then
    status="$(docker inspect --format '{{.State.Health.Status}}' "$NAME")"
    case "$status" in
      healthy)   echo "PASS: container reported healthy"; SMOKE_OK=1; exit 0 ;;
      unhealthy) echo "FAIL: healthcheck reported unhealthy"; exit 1 ;;
    esac
  elif curl -fsS -o /dev/null "http://127.0.0.1:${PORT}/"; then
    echo "PASS: :8787 answered (no HEALTHCHECK; probed directly)"; SMOKE_OK=1; exit 0
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "FAIL: not healthy within ${TIMEOUT}s (last status: ${status})"
    exit 1
  fi
  sleep 3
done
