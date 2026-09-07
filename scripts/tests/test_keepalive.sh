#!/usr/bin/env bash
#
# Unit tests for .github/keepalive.sh.
#
# A stub `git` on PATH logs every invocation (one line per call, the arguments
# space-joined) and exits 0, so the script's two behaviours are asserted by
# WHICH git subcommand ran, never by call counts: the stale path must run
# `commit --allow-empty` and then `push`, and every other path must run no git
# command at all. Runs offline: no network, no repository, no credential.
#
# The cases are the ones the acceptance criteria name. Around the threshold,
# all three neighbours are driven — one day below (skip), exactly at it
# (commit), one day above (commit) — so an inverted comparison and an
# off-by-one at the boundary are distinguishable from each other. Each
# rejection is asserted on the argument POSITION it names, so a validator
# wired to the wrong position fails here even though it still rejects.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../.github/keepalive.sh"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
LOG="$WORK/git.log"
cat > "$WORK/bin/git" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GIT_STUB_LOG"
exit 0
EOF
chmod +x "$WORK/bin/git"
export GIT_STUB_LOG="$LOG"
export PATH="$WORK/bin:$PATH"

# The stub must be the git the script finds; otherwise every "no git call"
# assertion below would pass by running nothing at all.
if [ "$(command -v git)" != "$WORK/bin/git" ]; then
    echo "FAIL: the git stub is not first on PATH ($(command -v git))"; exit 1
fi

# run_script <args...> — fresh log each run; echoes the exit status.
run_script() {
    : > "$LOG"
    bash "$SCRIPT" "$@" >"$WORK/out" 2>&1
    echo $?
}

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected exit $want, got $got"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# assert_call <desc> <regex>    — some logged git call matches the regex
assert_call() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$LOG"; then echo "ok: $desc"; else
        echo "FAIL: $desc — no git call matching /$re/"; sed 's/^/    git /' "$LOG"
        fails=$((fails + 1))
    fi
}

# assert_no_git <desc>          — the script ran no git command whatsoever
assert_no_git() {
    local desc="$1"
    if [ -s "$LOG" ]; then
        echo "FAIL: $desc — git was called"; sed 's/^/    git /' "$LOG"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# assert_out <desc> <regex>     — the script's own output matches the regex
assert_out() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$WORK/out"; then echo "ok: $desc"; else
        echo "FAIL: $desc — no output line matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# --- The threshold, and its two neighbours ---------------------------------
# 2026-01-01 + 50 days is 2026-02-20. Below / at / above, same threshold.

# 1. One day below the threshold: a skip, saying so, touching no git.
rc=$(run_script 2026-01-01 2026-02-19 50)
assert_rc     "49 days against a 50-day threshold exits 0" 0 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... and reports the skip with the age it measured" 'is 49 day\(s\) old, below the 50-day threshold'

# 2. Exactly at the threshold: an empty commit, by the bot identity, with a
#    message naming itself, then a push. "at or past" is the boundary rule, so
#    an off-by-one here is the difference between this case and case 1.
rc=$(run_script 2026-01-01 2026-02-20 50)
assert_rc  "50 days against a 50-day threshold exits 0" 0 "$rc"
assert_call "  ... commits, allowing an empty commit" '(^| )commit --allow-empty '
assert_call "  ... as the github-actions bot"         '^-c user\.name=github-actions\[bot\] -c user\.email=[^ ]+ commit '
assert_call "  ... with a message identifying it as a keepalive" 'commit --allow-empty -m keepalive: empty commit'
assert_call "  ... and pushes"                        '^push$'
assert_out  "  ... reporting the age it measured"     'is 50 day\(s\) old, at or past the 50-day threshold'

# 3. One day above the threshold: the same two calls.
rc=$(run_script 2026-01-01 2026-02-21 50)
assert_rc   "51 days against a 50-day threshold exits 0" 0 "$rc"
assert_call "  ... commits"                           '(^| )commit --allow-empty '
assert_call "  ... and pushes"                        '^push$'

# 4. A zero threshold makes any age stale — the shape AC4's dispatch uses.
rc=$(run_script 2026-02-20 2026-02-20 0)
assert_rc   "a same-day commit against a 0-day threshold exits 0" 0 "$rc"
assert_call "  ... commits"                           '(^| )commit --allow-empty '
assert_call "  ... and pushes"                        '^push$'

# 5. A real leap day is a real date: 2024 is a leap year, so this is 50 days
#    of age and not a rejection. Without the leap-aware calendar check this
#    would be refused as an impossible date.
rc=$(run_script 2024-02-29 2024-04-19 50)
assert_rc   "a leap day is accepted as a date" 0 "$rc"
assert_call "  ... and 50 days later it commits"      '(^| )commit --allow-empty '

# --- Rejections: each names its own argument, and touches no git -----------

# 6. An absent argument in each of the three positions. Positions 1 and 2 are
#    given as an empty string (the shape a workflow expression producing
#    nothing yields); position 3 is also driven by simply omitting it.
rc=$(run_script "" 2026-02-20 50)
assert_rc     "an empty commit date exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 1 as missing" 'commit date \(argument 1\) is missing'

rc=$(run_script 2026-01-01 "" 50)
assert_rc     "an empty current date exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 2 as missing" 'current date \(argument 2\) is missing'

rc=$(run_script 2026-01-01 2026-02-20 "")
assert_rc     "an empty threshold exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 3 as missing" 'threshold in days \(argument 3\) is missing'

rc=$(run_script 2026-01-01 2026-02-20)
assert_rc     "an omitted threshold exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 3 as missing" 'threshold in days \(argument 3\) is missing'

rc=$(run_script)
assert_rc     "no arguments at all exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 1 first" 'commit date \(argument 1\) is missing'

# 7. A value that is not a date, in each of the first two positions. Three
#    shapes per position: a word, a wrong separator layout, and a date that is
#    correctly shaped but does not exist. The last is what a shape-only check
#    would let through into the arithmetic.
for bad in yesterday 2026-1-1 2026-02-30 2026-13-01; do
    rc=$(run_script "$bad" 2026-02-20 50)
    assert_rc     "commit date '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming argument 1" '\(argument 1\)'
    rc=$(run_script 2026-01-01 "$bad" 50)
    assert_rc     "current date '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming argument 2" '\(argument 2\)'
done

# 8. A third argument that is not a non-negative integer.
for bad in -1 5.5 fifty " " 50days; do
    rc=$(run_script 2026-01-01 2026-02-20 "$bad")
    assert_rc     "threshold '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming argument 3" 'threshold in days \(argument 3\)'
done

# 9. A commit dated one day after the current date. Not a fresh branch: an
#    input that cannot decide anything. Refused, with no git call — the case
#    that stops a negative age from silently reading as "fresh".
rc=$(run_script 2026-02-21 2026-02-20 50)
assert_rc     "a commit date one day in the future exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... saying which date is later" 'commit date \(argument 1\) is later than the current date'

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all keepalive assertions"
