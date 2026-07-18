#!/usr/bin/env bash
#
# Boot a locally-built rstudio2u image and confirm the image actually works
# before CI publishes any tag. Two phases:
#   1. Server up  — RStudio Server answers on :8787 (healthcheck or port probe).
#   2. Toolchain  — a bspm binary package installs via apt and loads, and Quarto
#                   renders a document to HTML. These exercise the paths where
#                   arm64 parity can silently diverge (bundled/symlinked Quarto,
#                   the r2u binary install path), so the same checks run on the
#                   emulated arm64 image on the publish path (GP3, Known issue #3).
# Exits 0 only when both phases pass; non-zero if the container exits, reports
# unhealthy, times out, or either toolchain check fails. This is the gate that
# keeps an unattended rebuild from pushing a moving tag whose server won't start
# or whose toolchain is broken on an arch (GP7).
#
# Usage: .github/smoke-test.sh <image-tag>
# Env:
#   SMOKE_TIMEOUT  seconds to wait for server health   (default 180)
#   SMOKE_PORT     host port to publish container :8787 on (default 8787)
#   SMOKE_PKG      CRAN package for the bspm binary-install check (default data.table)
#
set -euo pipefail

IMAGE="${1:?usage: smoke-test.sh <image-tag>}"
TIMEOUT="${SMOKE_TIMEOUT:-180}"
PORT="${SMOKE_PORT:-8787}"
PKG="${SMOKE_PKG:-data.table}"
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

# --- Phase 1: server up -----------------------------------------------------
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
      healthy)   echo "PASS: container reported healthy"; break ;;
      unhealthy) echo "FAIL: healthcheck reported unhealthy"; exit 1 ;;
    esac
  elif curl -fsS -o /dev/null "http://127.0.0.1:${PORT}/"; then
    echo "PASS: :8787 answered (no HEALTHCHECK; probed directly)"; break
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "FAIL: not healthy within ${TIMEOUT}s (last status: ${status})"
    exit 1
  fi
  sleep 3
done

# --- Phase 2: toolchain -----------------------------------------------------
# bspm binary install: request a CRAN package and confirm it (a) loads and
# (b) landed as an apt binary (r-cran-<pkg>). The dpkg check is what proves the
# r2u/bspm *binary* path worked rather than a silent source-compile fallback —
# fast binary install is the whole point of the image (IP1).
apt_pkg="r-cran-$(printf '%s' "$PKG" | tr 'A-Z' 'a-z')"
echo "==> [1/2] bspm binary install ($PKG -> $apt_pkg)"
if ! docker exec "$NAME" Rscript -e "install.packages('$PKG'); library($PKG)"; then
  echo "FAIL: bspm install/load of $PKG failed"; exit 1
fi
if ! docker exec "$NAME" dpkg -s "$apt_pkg" >/dev/null 2>&1; then
  echo "FAIL: $PKG did not install as an apt binary ($apt_pkg absent) — bspm binary path broken"
  exit 1
fi
echo "PASS: $PKG installed via bspm as $apt_pkg and loads"

# Quarto render: render a chunk-free .qmd to HTML. No code engine (so no R/py
# package is needed — IP1), which targets the Quarto CLI + Pandoc binary itself,
# exactly the arch-sensitive surface that the arm64 bundled/symlinked fallback
# can break (Known issue #3).
echo "==> [2/2] quarto render to HTML"
if ! docker exec "$NAME" bash -c '
  set -e
  d=$(mktemp -d)
  cat > "$d/smoke.qmd" <<"QMD"
---
title: "smoke"
format: html
---

# Heading

A paragraph with **bold** text and a table.

| a | b |
|---|---|
| 1 | 2 |
QMD
  quarto render "$d/smoke.qmd"
  test -s "$d/smoke.html"
'; then
  echo "FAIL: quarto render did not produce HTML output"; exit 1
fi
echo "PASS: quarto rendered .qmd to HTML"

echo "PASS: smoke test (server + toolchain) succeeded"
SMOKE_OK=1
exit 0
