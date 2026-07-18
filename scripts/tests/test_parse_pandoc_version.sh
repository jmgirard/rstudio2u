#!/usr/bin/env bash
#
# Unit tests for scripts/parse-pandoc-version.sh.
#
# Valid `pandoc --version` / `pandoc -v` output resolves to the bare version;
# empty, HTML/garbage, and format-changed bodies fail loud (non-zero exit,
# nothing usable on stdout). Runs offline — the raw text is piped in on stdin,
# no network, no pandoc, no dependencies.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="$HERE/../parse-pandoc-version.sh"
fails=0

# Realistic multi-line `pandoc --version` output — the version is on the first
# line, `Features:`/`Scripting engine:` lines follow.
GOOD=$'pandoc 3.1.11\nFeatures: +server +lua\nScripting engine: Lua 5.4\nUser data directory: /root/.pandoc'
# A four-component version (pandoc has shipped e.g. 2.14.0.3).
GOOD_FOUR=$'pandoc 2.14.0.3\nCompiled with pandoc-types 1.22'
# The version line not first (defensive: some `-v` layouts prepend a banner).
GOOD_LATER=$'This is pandoc\npandoc 3.6.4\nFeatures: +server'

# assert_ok <desc> <body> <expected-stdout>
assert_ok() {
    local desc="$1" body="$2" expected="$3"
    local out rc
    out="$(printf '%s' "$body" | "$PARSER" 2>/dev/null)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: $desc — expected exit 0, got $rc"; fails=$((fails + 1)); return
    fi
    if [ "$out" != "$expected" ]; then
        echo "FAIL: $desc — expected '$expected', got '$out'"; fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

# assert_fail <desc> <body>
assert_fail() {
    local desc="$1" body="$2"
    local out rc
    out="$(printf '%s' "$body" | "$PARSER" 2>/dev/null)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "FAIL: $desc — expected non-zero exit, got 0 (stdout: '$out')"; fails=$((fails + 1)); return
    fi
    if [ -n "$out" ]; then
        echo "FAIL: $desc — expected empty stdout on failure, got '$out'"; fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

assert_ok   "valid --version output"            "$GOOD"       "3.1.11"
assert_ok   "four-component version"            "$GOOD_FOUR"  "2.14.0.3"
assert_ok   "version line not first"           "$GOOD_LATER" "3.6.4"
assert_fail "empty body"                        ""
assert_fail "HTML error body"                   "<html><body>503 Service Unavailable</body></html>"
assert_fail "format change: extra word"         $'pandoc version 3.1.11\nFeatures: +server'
assert_fail "format change: non-numeric"        $'pandoc unknown\nFeatures: +server'
assert_fail "format change: trailing junk"      $'pandoc 3.1.11 (nightly)\nFeatures: +server'
assert_fail "format change: single component"   $'pandoc 3\nFeatures: +server'

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all parser assertions"
