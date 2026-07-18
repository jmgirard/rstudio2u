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
#   SMOKE_MIRROR_PKG  small uninstalled CRAN package for the mirror-failure check (default praise)
#
set -euo pipefail

IMAGE="${1:?usage: smoke-test.sh <image-tag>}"
TIMEOUT="${SMOKE_TIMEOUT:-180}"
PORT="${SMOKE_PORT:-8787}"
PKG="${SMOKE_PKG:-data.table}"
MIRROR_PKG="${SMOKE_MIRROR_PKG:-praise}"
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

# --- Phase 3: mirror-failure UX ---------------------------------------------
# Known issue #1: the r2u binary mirror is occasionally unreachable, and a raw
# apt failure is opaque to a classroom user. Prove three behaviours on the built
# image: (a) an ordinary "package does not exist" error does NOT masquerade as a
# mirror outage, (b) the hint wrapper does not mask or fabricate errors on odd
# call forms, and (c) a genuine mirror-unreachable failure surfaces a
# plain-language hint after apt has retried. Runs last: 3c deliberately breaks
# apt networking, so it must never precede the happy-path checks above.
HINT_SENTINEL="r2u package mirror looks unreachable"

echo "==> [3a] no false mirror hint on an unrelated install error"
# A CRAN package that does not exist: the install fails, but every mirror is
# still reachable, so the outage hint must NOT fire (AC3).
fp_out="$(docker exec "$NAME" Rscript -e 'try(install.packages("nosuchpkg1234321"))' 2>&1 || true)"
if printf '%s' "$fp_out" | grep -qF "$HINT_SENTINEL"; then
  echo "FAIL: mirror-outage hint fired on a non-network error (false positive)"
  printf '%s\n' "$fp_out" | tail -8
  exit 1
fi
echo "PASS: unrelated install error did not trigger the mirror hint"

echo "==> [3b] no-arg install.packages() keeps its real error (no masking, no hint)"
# The wrapper must pass a bare install.packages() straight through: surface R's
# own error, never a forced "argument \"pkgs\" is missing", and fire no hint.
rob_out="$(docker exec "$NAME" Rscript -e 'tryCatch(install.packages(), error=function(e) cat("ERR:", conditionMessage(e), "\n"))' 2>&1 || true)"
if printf '%s' "$rob_out" | grep -qF "$HINT_SENTINEL"; then
  echo "FAIL: mirror hint fired on a no-arg install.packages()"; printf '%s\n' "$rob_out" | tail -5; exit 1
fi
if printf '%s' "$rob_out" | grep -qF 'argument "pkgs" is missing'; then
  echo "FAIL: no-arg install.packages() masked its real error with a forced missing-pkgs error"
  printf '%s\n' "$rob_out" | tail -5; exit 1
fi
echo "PASS: no-arg install.packages() kept its real error and fired no hint"

echo "==> [3c] mirror unreachable -> apt retries + plain-language hint"
# apt must be configured to retry a failed fetch at least 3 times (AC1).
retries="$(docker exec "$NAME" apt-config dump Acquire::Retries 2>/dev/null \
  | sed -nE 's/^Acquire::Retries[^"]*"([0-9]+)".*/\1/p' | head -1)"
if [ -z "${retries:-}" ] || [ "$retries" -lt 3 ]; then
  echo "FAIL: Acquire::Retries is '${retries:-unset}', expected >= 3"
  exit 1
fi
echo "PASS: apt configured to retry fetches ${retries}x"

# Blackhole every non-Ubuntu apt host (the r2u binary repo *and* the CRAN
# source mirror) by pointing them at 127.0.0.1 — nothing listens on :80/:443
# there, so connections are refused: fast and deterministic. Both the binary
# (apt/r2u) and source-fallback paths must fail for the install to fail.
mirror_hosts="$(docker exec "$NAME" bash -c \
  "grep -rhoE 'https?://[^ /]+' /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null \
   | sed -E 's#https?://##' | sort -u | grep -viE 'ubuntu\.(com|org)'")"
if [ -z "${mirror_hosts:-}" ]; then
  echo "FAIL: could not identify the r2u mirror host(s) from apt sources"; exit 1
fi
echo "    blackholing mirror host(s): $(printf '%s' "$mirror_hosts" | tr '\n' ' ')"
for h in $mirror_hosts; do
  docker exec "$NAME" bash -c "printf '127.0.0.1 %s\n' '$h' >> /etc/hosts"
done

# Retries are visible in apt's own output: an `apt-get update` (which bspm runs
# before installing) attempts each unreachable mirror Acquire::Retries times
# (Ign:/Err: lines) before giving up. Assert at least one mirror was fetched >=3
# times, i.e. the retries actually happened (AC1, behavioural).
upd_out="$(docker exec "$NAME" bash -c 'apt-get update 2>&1' || true)"
max_attempts=0
for h in $mirror_hosts; do
  c="$(printf '%s' "$upd_out" | grep -cE "(Ign|Err):[0-9]+ https?://$h" || true)"
  [ "$c" -gt "$max_attempts" ] && max_attempts="$c"
done
if [ "$max_attempts" -lt 3 ]; then
  echo "FAIL: apt did not retry the unreachable mirror >=3x (max attempts: $max_attempts)"
  printf '%s\n' "$upd_out" | grep -iE 'Ign|Err|Failed to fetch' | head
  exit 1
fi
echo "PASS: apt retried an unreachable mirror ${max_attempts}x before failing"

# Request an uninstalled package with the source fallback also dead (repos ->
# a closed port), so the install genuinely fails and the hook can diagnose it.
mf_out="$(docker exec "$NAME" Rscript -e \
  'options(repos=c(CRAN="http://127.0.0.1:9")); try(install.packages("'"$MIRROR_PKG"'"))' 2>&1 || true)"
if ! printf '%s' "$mf_out" | grep -qF "$HINT_SENTINEL"; then
  echo "FAIL: mirror-unreachable install did not surface the plain-language hint"
  printf '%s\n' "$mf_out" | tail -15
  exit 1
fi
echo "PASS: mirror-unreachable install surfaced the hint"

echo "PASS: smoke test (server + toolchain + mirror-failure UX) succeeded"
SMOKE_OK=1
exit 0
