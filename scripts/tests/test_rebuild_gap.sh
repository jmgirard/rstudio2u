#!/usr/bin/env bash
#
# Unit tests for .github/rebuild-gap.sh.
#
# Three stubs sit on PATH — `gh`, `curl` and `wget` — each logging every
# invocation to its own file and exiting 0, so "the script decided without
# reaching the network" is asserted by three empty logs rather than by trusting
# the source. The gh stub is the one from test_ci_failure_issue.sh: it also
# answers `issue list` with canned JSON, because a gap runs the real
# .github/ci-failure-issue.sh, and what that script does with the gap subject
# is visible only in the gh calls it makes. Runs offline: no network, no token.
#
# The bound is "more than <threshold> days", so the three neighbours are driven
# — one day below, exactly at it, one day above — and only the last is a gap.
# Each rejection is asserted on the argument POSITION it names, so a validator
# wired to the wrong position fails here even though it still rejects.
#
# The stubs themselves are proved able to record before anything is asserted
# about their silence: a log that can never fill would make every "no call"
# assertion below pass for the wrong reason.
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required (the gh stub applies ci-failure-issue.sh's --jq filter)"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../.github/rebuild-gap.sh"
RUN_URL="https://github.com/o/r/actions/runs/456"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
GH_LOG="$WORK/gh.log"
CURL_LOG="$WORK/curl.log"
WGET_LOG="$WORK/wget.log"

cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GH_STUB_LOG"
if [ "${1:-} ${2:-}" = "issue list" ]; then
    jqf=""
    while [ $# -gt 0 ]; do
        if [ "$1" = "--jq" ]; then jqf="$2"; shift; fi
        shift
    done
    if [ -n "$jqf" ]; then
        printf '%s' "$GH_STUB_LIST" | jq -r "$jqf"
    else
        printf '%s' "$GH_STUB_LIST"
    fi
elif [ "${1:-} ${2:-}" = "issue create" ]; then
    echo "https://github.com/o/r/issues/99"
fi
exit 0
EOF
# curl and wget exist only to be logged: this script has no use for either, and
# that is the claim under test. Written out one at a time rather than from a
# loop over the two names, because the log variable each needs is its own and
# bash 3.2 (the macOS bash this suite runs under) has no case conversion.
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$CURL_STUB_LOG"
exit 0
EOF
cat > "$WORK/bin/wget" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$WGET_STUB_LOG"
exit 0
EOF
chmod +x "$WORK/bin/gh" "$WORK/bin/curl" "$WORK/bin/wget"
export GH_STUB_LOG="$GH_LOG" CURL_STUB_LOG="$CURL_LOG" WGET_STUB_LOG="$WGET_LOG"
export GH_STUB_LIST='[]'
export PATH="$WORK/bin:$PATH"

# --- The stubs are the commands the script would find, and they do record ----
# Without this, every "made no call" assertion below could pass because the log
# file can never be written, not because the script stayed offline.
for c in gh curl wget; do
    if [ "$(command -v "$c")" != "$WORK/bin/$c" ]; then
        echo "FAIL: the $c stub is not first on PATH ($(command -v "$c"))"; exit 1
    fi
done
gh probe-call >/dev/null 2>&1
curl probe-call >/dev/null 2>&1
wget probe-call >/dev/null 2>&1
for pair in "gh:$GH_LOG" "curl:$CURL_LOG" "wget:$WGET_LOG"; do
    c="${pair%%:*}"; f="${pair#*:}"
    if ! grep -q '^probe-call$' "$f" 2>/dev/null; then
        echo "FAIL: the $c stub did not record a call it was given"; exit 1
    fi
done
echo "ok: the gh, curl and wget stubs are on PATH and record what they are given"

# run_script <args...> — fresh logs each run; echoes the exit status.
run_script() {
    : > "$GH_LOG"; : > "$CURL_LOG"; : > "$WGET_LOG"
    RUN_URL="$RUN_URL" bash "$SCRIPT" "$@" >"$WORK/out" 2>&1
    echo $?
}

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected exit $want, got $got"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# assert_call <desc> <regex>   — some logged gh call matches the regex
assert_call() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$GH_LOG"; then echo "ok: $desc"; else
        echo "FAIL: $desc — no gh call matching /$re/"; sed 's/^/    gh /' "$GH_LOG"
        fails=$((fails + 1))
    fi
}

assert_no_call() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$GH_LOG"; then
        echo "FAIL: $desc — unexpected gh call matching /$re/"; sed 's/^/    gh /' "$GH_LOG"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# assert_no_gh <desc>          — the script ran no gh command whatsoever
assert_no_gh() {
    local desc="$1"
    if [ -s "$GH_LOG" ]; then
        echo "FAIL: $desc — gh was called"; sed 's/^/    gh /' "$GH_LOG"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# assert_offline <desc>        — neither curl nor wget was called
assert_offline() {
    local desc="$1" bad=0
    [ -s "$CURL_LOG" ] && { echo "FAIL: $desc — curl was called"; sed 's/^/    curl /' "$CURL_LOG"; bad=1; }
    [ -s "$WGET_LOG" ] && { echo "FAIL: $desc — wget was called"; sed 's/^/    wget /' "$WGET_LOG"; bad=1; }
    if [ "$bad" -eq 1 ]; then fails=$((fails + 1)); else echo "ok: $desc"; fi
}

assert_out() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$WORK/out"; then echo "ok: $desc"; else
        echo "FAIL: $desc — no output line matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# --- The bound, and its two neighbours -------------------------------------
# 2026-01-01 + 15 days is 2026-01-16. The rule is "more than <threshold> days",
# so 15 is not yet a gap and 16 is.

# 1. One day below the bound: no gap, saying so, touching nothing.
rc=$(run_script 2026-01-01 2026-01-15 15)
assert_rc      "14 days against a 15-day bound exits 0" 0 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_offline "  ... and neither curl nor wget"
assert_out     "  ... reporting the gap it measured" 'succeeded 14 day\(s\) ago, within the 15-day'

# 2. Exactly at the bound: still not a gap. An off-by-one here is the
#    difference between this case and case 3.
rc=$(run_script 2026-01-01 2026-01-16 15)
assert_rc      "15 days against a 15-day bound exits 0" 0 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_offline "  ... and neither curl nor wget"
assert_out     "  ... reporting it as within the bound" 'succeeded 15 day\(s\) ago, within the 15-day'

# 3. One day above the bound: a gap, which raises the issue through
#    ci-failure-issue.sh with a subject that says what is wrong. The title is
#    anchored on both sides, so the build-failure wording appearing anywhere in
#    it fails here.
rc=$(run_script 2026-01-01 2026-01-17 15)
assert_rc      "16 days against a 15-day bound exits 0" 0 "$rc"
assert_offline "  ... having called neither curl nor wget"
assert_call    "  ... creates a ci-failure issue"  '^issue create .*--label ci-failure'
assert_call    "  ... whose title names the gap and its size" \
    '^issue create .*--title No successful weekly rebuild in 16 days \(since 2026-01-01\) --body '
assert_no_call "  ... and never uses the build-failure wording" '--title Weekly run failed'
assert_call    "  ... whose body links this run"   "^issue create .*$RUN_URL"
assert_out     "  ... and says it raised the alert" 'succeeded 16 day\(s\) ago, past the 15-day'

# 4. A gap with the issue already open: a comment on it, no second issue.
GH_STUB_LIST='[{"number":57},{"number":41}]'
rc=$(run_script 2026-01-01 2026-01-17 15)
export GH_STUB_LIST='[]'
assert_rc      "a gap with an open issue exits 0" 0 "$rc"
assert_call    "  ... comments on the oldest open issue (#41)" '^issue comment 41 '
assert_call    "  ... naming the gap"              '^issue comment 41 .*No successful weekly rebuild in 16 days'
assert_no_call "  ... and opens no second issue"   '^issue create '

# 5. No successful scheduled run is on record at all. The workflow reduces an
#    empty `gh run list` to this sentinel rather than an empty date, so the gap
#    is reported as what it is instead of being refused as a bad date.
rc=$(run_script none 2026-01-17 15)
assert_rc      "the 'none' sentinel exits 0" 0 "$rc"
assert_offline "  ... having called neither curl nor wget"
assert_call    "  ... raises the alert"            '^issue create .*--label ci-failure'
assert_call    "  ... saying no successful rebuild is on record" \
    '^issue create .*--title No successful weekly rebuild on record --body '

# 6. The run history could not be read. A watchdog that goes quiet when its own
#    lookup fails is the silence this script exists to end, so this alerts too —
#    and says which of the two happened, never claiming a measured gap.
rc=$(run_script unknown 2026-01-17 15)
assert_rc      "the 'unknown' sentinel exits 0" 0 "$rc"
assert_offline "  ... having called neither curl nor wget"
assert_call    "  ... raises the alert"            '^issue create .*--label ci-failure'
assert_call    "  ... saying the history could not be read" \
    '^issue create .*--title Could not read the weekly rebuild history --body '
assert_no_call "  ... and claims no measured gap"  '--title No successful weekly rebuild in'

# 7. A real leap day is a real date: 2024 is a leap year, so this is 16 days of
#    gap and not a rejection. Without the leap-aware calendar check it would be
#    refused as an impossible date.
rc=$(run_script 2024-02-29 2024-03-16 15)
assert_rc      "a leap day is accepted as a date" 0 "$rc"
assert_call    "  ... and 16 days later it alerts" '^issue create .*--title No successful weekly rebuild in 16 days'

# --- Rejections: each names its own argument, and touches no gh -------------

# 8. A value that is not a date, in each of the first two positions. A word, a
#    wrong separator layout, a correctly shaped date that does not exist, and a
#    month that is not a month. The third is what a shape-only check lets
#    through into the arithmetic.
for bad in yesterday 2026-1-1 2026-02-30 2026-13-01; do
    rc=$(run_script "$bad" 2026-01-17 15)
    assert_rc      "last-success date '$bad' exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_offline "  ... and neither curl nor wget"
    assert_out     "  ... naming argument 1" '\(argument 1\)'
    rc=$(run_script 2026-01-01 "$bad" 15)
    assert_rc      "current date '$bad' exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_out     "  ... naming argument 2" '\(argument 2\)'
done

# 9. The sentinels are argument 1's alone: a current date that is not a date is
#    a rejection whatever word it is.
for bad in none unknown; do
    rc=$(run_script 2026-01-01 "$bad" 15)
    assert_rc      "current date '$bad' exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_out     "  ... naming argument 2" '\(argument 2\)'
done

# 10. A last-success date after today. Not a fresh rebuild: an input that cannot
#     decide anything. Refused, rather than computing a negative gap that would
#     always read as within the bound.
rc=$(run_script 2026-01-18 2026-01-17 15)
assert_rc      "a last-success date one day in the future exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... saying which date is later" 'last success date \(argument 1\) is later than the current date'

# 11. A missing threshold, and a threshold that is not a non-negative integer.
rc=$(run_script 2026-01-01 2026-01-17 "")
assert_rc      "an empty threshold exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... naming argument 3 as missing" 'threshold in days \(argument 3\) is missing'

rc=$(run_script 2026-01-01 2026-01-17)
assert_rc      "an omitted threshold exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... naming argument 3 as missing" 'threshold in days \(argument 3\) is missing'

for bad in -1 5.5 fifteen " " 15days; do
    rc=$(run_script 2026-01-01 2026-01-17 "$bad")
    assert_rc      "threshold '$bad' exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_out     "  ... naming argument 3" 'threshold in days \(argument 3\)'
done

# 12. An empty first argument is missing, not a sentinel.
rc=$(run_script "" 2026-01-17 15)
assert_rc      "an empty last-success date exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... naming argument 1 as missing" 'last success date \(argument 1\) is missing'

# 13. A threshold too wide for 64-bit shell arithmetic. `10#$threshold` on a 19-
#     or 20-digit value wraps negative, which would read as "the gap is past it"
#     and raise a false alert every week. Every one of these is a non-negative
#     integer, so the script accepts it and must find no gap: no bound can be
#     smaller than a gap it is larger than.
for huge in 10000000 9999999999999999999 99999999999999999999999999999999; do
    rc=$(run_script 2026-01-01 2026-01-17 "$huge")
    assert_rc      "a ${#huge}-digit threshold exits 0" 0 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_out     "  ... reporting no gap"        'within the '"$huge"'-day'
done

# 14. A seven-digit threshold is inside the arithmetic and is compared, not
#     short-circuited — the neighbour of case 13's eight-digit value.
rc=$(run_script 2026-01-01 2026-01-17 9999999)
assert_rc      "a 7-digit threshold exits 0" 0 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... having compared it"      'succeeded 16 day\(s\) ago, within the 9999999-day'

# 15. The digit-width shortcut reads the value, not the string length: a
#     19-character threshold whose leading zeros strip to 15 is a 15-day bound,
#     and a 16-day gap is past it.
rc=$(run_script 2026-01-01 2026-01-17 0000000000000000015)
assert_rc      "a zero-padded 15 is still a 15-day bound" 0 "$rc"
assert_call    "  ... so a 16-day gap alerts"  '^issue create .*--title No successful weekly rebuild in 16 days'

# 16. A fourth argument. The script takes three and refuses more, saying how
#     many it got; nothing about the extra reaches gh.
rc=$(run_script 2026-01-01 2026-01-17 15 extra)
assert_rc      "a fourth argument exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... saying how many it got" 'expected 3 arguments, got 4'

# 17. No RUN_URL in the environment. The alert is the point; it goes out with a
#     stand-in link rather than being withheld over a missing convenience.
: > "$GH_LOG"; : > "$CURL_LOG"; : > "$WGET_LOG"
env -u RUN_URL bash "$SCRIPT" 2026-01-01 2026-01-17 15 >"$WORK/out" 2>&1; rc=$?
assert_rc      "a gap with no RUN_URL still exits 0" 0 "$rc"
assert_call    "  ... and still raises the alert" '^issue create .*--title No successful weekly rebuild in 16 days'

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all rebuild-gap assertions"
