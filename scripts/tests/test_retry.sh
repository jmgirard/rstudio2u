#!/usr/bin/env bash
#
# Unit tests for scripts/retry.sh.
#
# A transiently-failing command (fails a few times, then succeeds) is retried to
# success and its stdout passes through untouched; a command that always fails
# exits non-zero after the cap; the command's own exit code is propagated. This
# mirrors the motivating case — Quarto's bundled Deno aborting with SIGILL
# (exit 132) under QEMU emulation during the multi-arch build, where a re-run of
# the identical command succeeds. Runs offline with RETRY_DELAY=0 (no sleeps, no
# network, no dependencies).
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RETRY="$HERE/../retry.sh"
export RETRY_DELAY=0
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A command that fails its first N invocations (exit 132, the SIGILL code) and
# then succeeds, printing "done". State persists across attempts in a counter
# file so retry.sh sees the same command flake then recover.
#   make_flaky <counter-file> <fail-count>
make_flaky() {
    local counter="$1" failcount="$2"
    printf '0' > "$counter"
    cat > "$WORK/flaky.sh" <<EOF
#!/usr/bin/env bash
n=\$(cat "$counter")
n=\$((n + 1))
printf '%s' "\$n" > "$counter"
if [ "\$n" -le "$failcount" ]; then
    exit 132
fi
echo done
EOF
    chmod +x "$WORK/flaky.sh"
}

# assert_ok <desc> <expected-stdout> -- <cmd...>
assert_ok() {
    local desc="$1" expected="$2"; shift 2; shift  # drop the "--"
    local out rc
    out="$("$RETRY" "$@" 2>/dev/null)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: $desc — expected exit 0, got $rc"; fails=$((fails + 1)); return
    fi
    if [ "$out" != "$expected" ]; then
        echo "FAIL: $desc — expected stdout '$expected', got '$out'"; fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

# assert_fail <desc> <expected-rc> -- <cmd...>
assert_fail() {
    local desc="$1" want_rc="$2"; shift 2; shift  # drop the "--"
    local rc
    "$RETRY" "$@" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "FAIL: $desc — expected non-zero exit, got 0"; fails=$((fails + 1)); return
    fi
    if [ "$rc" -ne "$want_rc" ]; then
        echo "FAIL: $desc — expected exit $want_rc, got $rc"; fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

# Transient SIGILL-like failure recovers within the attempt budget.
make_flaky "$WORK/c1" 2
assert_ok   "fails twice (exit 132) then succeeds within 5 attempts" "done" -- 5 "$WORK/flaky.sh"

# A single-attempt cap still runs the command exactly once (happy path).
assert_ok   "max=1 runs a succeeding command once"                  "once" -- 1 /bin/echo once

# A command that never recovers exhausts the budget and propagates its exit code.
make_flaky "$WORK/c2" 99
assert_fail "always fails -> exits with the command's code (132)"    132   -- 3 "$WORK/flaky.sh"

# A non-SIGILL failure code is propagated just the same.
assert_fail "always fails with exit 7 -> propagates 7"              7      -- 2 bash -c 'exit 7'

# Usage error (fewer than the required args) exits 2 without running anything.
assert_fail "missing command -> usage error (exit 2)"              2      -- 5

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all retry assertions"
