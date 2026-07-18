#!/usr/bin/env bash
#
# Unit tests for scripts/resolve-rstudio-version.sh.
#
# A valid endpoint body resolves and renders both forms; empty, HTML/error, and
# format-changed bodies fail loud (non-zero exit, nothing usable on stdout).
# Runs offline via the RS_UPDATE_RESPONSE seam — no network, no dependencies.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$HERE/../resolve-rstudio-version.sh"
fails=0

# A realistic endpoint body: key=value pairs joined by '&', build encoded %2B.
GOOD='update-version=2024.12.1%2B563&update-url=https://download.rstudio.org/x&update-message=A%20new%20version'

# assert_ok <desc> <body> <expected-stdout> [resolver-args...]
assert_ok() {
    local desc="$1" body="$2" expected="$3"; shift 3
    local out rc
    out="$(RS_UPDATE_RESPONSE="$body" "$RESOLVER" "$@" 2>/dev/null)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: $desc — expected exit 0, got $rc"; fails=$((fails + 1)); return
    fi
    if [ "$out" != "$expected" ]; then
        echo "FAIL: $desc — expected '$expected', got '$out'"; fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

# assert_fail <desc> <body> [resolver-args...]
assert_fail() {
    local desc="$1" body="$2"; shift 2
    local out rc
    out="$(RS_UPDATE_RESPONSE="$body" "$RESOLVER" "$@" 2>/dev/null)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "FAIL: $desc — expected non-zero exit, got 0 (stdout: '$out')"; fails=$((fails + 1)); return
    fi
    if [ -n "$out" ]; then
        echo "FAIL: $desc — expected empty stdout on failure, got '$out'"; fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

assert_ok   "valid body -> plus form"        "$GOOD" "2024.12.1+563"
assert_ok   "valid body -> tag form"         "$GOOD" "2024.12.1-563" --tag
assert_fail "empty body"                      ""
assert_fail "HTML error body"                 "<html><body>503 Service Unavailable</body></html>"
assert_fail "format change: no build number"  "update-version=2024.12.1&x=1"
assert_fail "format change: non-numeric"      "update-version=garbage%2Bxyz&x=1"
assert_fail "format change: truncated"        "update-version=2024.12%2B563&x=1"

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all resolver assertions"
