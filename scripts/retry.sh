#!/usr/bin/env bash
#
# Run a command with bounded retries, for commands that fail *transiently*.
#
# Motivating case, since resolved: Quarto's bundled Deno (V8) intermittently
# aborted with SIGILL (exit 132) when executed under QEMU aarch64 emulation
# during the multi-arch image build. CI no longer emulates anything — each
# architecture builds on a runner of that architecture (D-007) — so that crash
# class is gone. The wrapper stays for the posture it encodes: ride out a
# transient hiccup, the same as the apt/bspm retries (GP4-licensed hardening of
# the owned fork). A genuinely broken command fails every attempt and still
# exits non-zero, so retrying hardens against flakiness without masking a real
# failure.
#
# Usage: retry.sh <max-attempts> <command> [args...]
#   stdout/stderr of the command pass through untouched; retry diagnostics go to
#   stderr only, so a captured stdout ($(retry.sh …)) is not polluted.
#   Exit code is 0 on the first success, else the last attempt's exit code.
#
# RETRY_DELAY (seconds, default 3) sets the pause between attempts; set to 0
# under test to run instantly.
#
set -uo pipefail

if [ "$#" -lt 2 ]; then
    echo "retry: usage: retry.sh <max-attempts> <command> [args...]" >&2
    exit 2
fi

max="$1"; shift
delay="${RETRY_DELAY:-3}"

attempt=1
while true; do
    # Capture the command's own exit code: `if "$@"; then …; fi` would report
    # the if-statement's status (0 when the then-branch is skipped), masking a
    # failure — so run it directly and read $? on the next line.
    "$@" && exit 0
    rc=$?
    if [ "$attempt" -ge "$max" ]; then
        echo "retry: '$*' failed after $attempt attempt(s) (last exit $rc)" >&2
        exit "$rc"
    fi
    echo "retry: '$*' attempt $attempt/$max failed (exit $rc), retrying in ${delay}s" >&2
    sleep "$delay"
    attempt=$((attempt + 1))
done
