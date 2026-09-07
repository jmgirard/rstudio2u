#!/usr/bin/env bash
#
# Unit tests for .github/ci-failure-issue.sh.
#
# A stub `gh` on PATH logs every invocation (one line per call, the arguments
# space-joined) and answers `issue list` with canned JSON per scenario, so the
# four branches — failure with no open issue (create), failure with an open
# issue (comment on the first), success with open issues (comment + close each),
# success with none (no gh writes) — are asserted by WHICH subcommand ran and on
# WHICH issue number, never by call counts. Runs offline: no network, no token.
#
# The failed-variant names are extracted by the script itself from a
# `gh run view --json jobs` document, so the fixtures below are job listings in
# the shape docker.yml's matrix produces: one build leg per (variant, arch) plus
# one publish leg per variant. They pin the behaviours that matter — a variant
# named once however many of its legs failed, an all-green variant never named,
# a non-matrix job never mistaken for a variant, and GitHub's auto-generated
# multi-key job name parsed to the same variant as the explicit name.
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required (the gh stub applies the script's --jq filter)"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../.github/ci-failure-issue.sh"
RUN_URL="https://github.com/o/r/actions/runs/123"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
LOG="$WORK/gh.log"
# The stub: append the argv to the log; `issue list` prints the JSON in
# GH_STUB_LIST (the script pipes it through its own --jq filter, so the stub
# applies the filter with the real jq when --jq is given).
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GH_STUB_LOG"
if [ "$1 $2" = "issue list" ]; then
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
elif [ "$1 $2" = "issue create" ]; then
    echo "https://github.com/o/r/issues/99"
fi
exit 0
EOF
chmod +x "$WORK/bin/gh"
export GH_STUB_LOG="$LOG"
export PATH="$WORK/bin:$PATH"

# run_script <result> <list-json> [jobs-json]  — fresh log each run. The third
# argument is the *content* of a jobs document; it is written to a temp file and
# the file's path handed to the script, exactly as the notify job does.
run_script() {
    local result="$1" list="$2" jobs="${3-}"
    : > "$LOG"
    local args=("$result" "$RUN_URL")
    if [ -n "$jobs" ]; then
        printf '%s' "$jobs" > "$WORK/jobs.json"
        args+=("$WORK/jobs.json")
    fi
    GH_STUB_LIST="$list" bash "$SCRIPT" "${args[@]}" >"$WORK/out" 2>&1
    echo $?
}

# job <name> <conclusion>  — one entry of a `gh run view --json jobs` document
job() { printf '{"name":"%s","conclusion":"%s"}' "$1" "$2"; }
jobs_doc() {
    local out="" j
    for j in "$@"; do out="${out:+$out,}$j"; done
    printf '{"jobs":[%s]}' "$out"
}

# noble's arm64 build leg failed, which also fails noble's publish leg; every
# resolute leg is green. "noble" must be named once and "resolute" not at all.
FIX_ARM64_FAIL=$(jobs_doc \
    "$(job 'build (noble, amd64)' success)" \
    "$(job 'build (noble, arm64)' failure)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' success)" \
    "$(job 'publish (noble)' failure)" \
    "$(job 'publish (resolute)' success)")

# Every leg green.
FIX_ALL_GREEN=$(jobs_doc \
    "$(job 'build (noble, amd64)' success)" \
    "$(job 'build (noble, arm64)' success)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' success)" \
    "$(job 'publish (noble)' success)" \
    "$(job 'publish (resolute)' success)")

# Both variants down.
FIX_BOTH_FAIL=$(jobs_doc \
    "$(job 'build (noble, amd64)' failure)" \
    "$(job 'build (noble, arm64)' failure)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' failure)" \
    "$(job 'publish (noble)' failure)" \
    "$(job 'publish (resolute)' failure)")

# Only a job outside the matrix failed: nothing to name.
FIX_NO_MATRIX_JOB=$(jobs_doc \
    "$(job 'build (noble, amd64)' success)" \
    "$(job 'build (noble, arm64)' success)" \
    "$(job 'notify' failure)")

# The job name GitHub generates for a matrix `include` leg when the workflow
# sets no explicit `name:` — every include key, in order (M13's lesson).
FIX_MULTIKEY=$(jobs_doc \
    "$(job 'build (noble, 24.04, amd64, ubuntu-latest)' success)" \
    "$(job 'build (noble, 24.04, arm64, ubuntu-24.04-arm)' failure)" \
    "$(job 'build (resolute, 26.04, amd64, ubuntu-latest)' success)" \
    "$(job 'build (resolute, 26.04, arm64, ubuntu-24.04-arm)' success)")

# assert_call <desc> <regex>     — some logged gh call matches the regex
assert_call() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$LOG"; then echo "ok: $desc"; else
        echo "FAIL: $desc — no gh call matching /$re/"; sed 's/^/    gh /' "$LOG"
        fails=$((fails + 1))
    fi
}

# assert_no_call <desc> <regex>  — no logged gh call matches the regex
assert_no_call() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$LOG"; then
        echo "FAIL: $desc — unexpected gh call matching /$re/"; sed 's/^/    gh /' "$LOG"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected exit $want, got $got"; cat "$WORK/out"; fails=$((fails + 1))
    fi
}

NONE='[]'
TWO='[{"number":57},{"number":41}]'   # newest first, as gh lists them

# 1. failure, no open issue -> create, labelled, naming the variant + run URL.
# The title regex is anchored on both sides ("...: noble --body"), so it fails
# if "noble" were repeated or "resolute" tacked on: exactly-once, by boundary.
rc=$(run_script failure "$NONE" "$FIX_ARM64_FAIL")
assert_rc      "failure/none exits 0" 0 "$rc"
assert_call    "failure/none creates an issue"                '^issue create '
assert_call    "  ... with the ci-failure label"              '^issue create .*--label ci-failure'
assert_call    "  ... whose title names the failed variant exactly once" '^issue create .*--title Weekly rebuild failed: noble --body '
assert_no_call "  ... and never names the all-green variant"  '^issue create .*resolute'
assert_call    "  ... whose body links the run"               "^issue create .*$RUN_URL"
assert_call    "failure/none ensures the label exists"        '^label create ci-failure --force'
assert_no_call "failure/none comments on nothing"             '^issue comment '
assert_no_call "failure/none closes nothing"                  '^issue close '

# 2. failure, open issues -> comment on the first (oldest), create nothing
rc=$(run_script failure "$TWO" "$FIX_ARM64_FAIL")
assert_rc      "failure/open exits 0" 0 "$rc"
assert_call    "failure/open comments on the oldest open issue (#41)" '^issue comment 41 '
assert_call    "  ... naming the failed variant"              '^issue comment 41 .*noble'
assert_no_call "failure/open does not comment on #57"        '^issue comment 57 '
assert_no_call "failure/open creates no second issue"        '^issue create '
assert_no_call "failure/open closes nothing"                  '^issue close '

# 3. success, open issues -> comment on and close each. Driven by the all-green
# job listing: an every-leg-green run must close the issue, never open one.
rc=$(run_script success "$TWO" "$FIX_ALL_GREEN")
assert_rc      "success/open exits 0" 0 "$rc"
assert_call    "success/open comments on #41"                 '^issue comment 41 '
assert_call    "success/open closes #41"                      '^issue close 41$'
assert_call    "success/open comments on #57"                 '^issue comment 57 '
assert_call    "success/open closes #57"                      '^issue close 57$'
assert_no_call "success/open creates nothing"                 '^issue create '

# 4. success, no open issue -> reads the list, writes nothing
rc=$(run_script success "$NONE")
assert_rc      "success/none exits 0" 0 "$rc"
assert_call    "success/none lists open ci-failure issues"    '^issue list .*--label ci-failure .*--state open .*--limit 100'
assert_no_call "success/none creates nothing"                 '^issue create '
assert_no_call "success/none comments on nothing"             '^issue comment '
assert_no_call "success/none closes nothing"                  '^issue close '

# 5. failure, no open issue, no jobs document -> the title carries the fallback
rc=$(run_script failure "$NONE")
assert_rc      "failure/none/no-variants exits 0" 0 "$rc"
assert_call    "failure/none/no-variants creates an issue with the fallback title" '^issue create .*--title Weekly rebuild failed: \(see the run summary'

# 5b. Both variants down -> both named, each once, in job order.
rc=$(run_script failure "$NONE" "$FIX_BOTH_FAIL")
assert_rc      "failure/both-variants exits 0" 0 "$rc"
assert_call    "both failed variants named, each once" '^issue create .*--title Weekly rebuild failed: noble resolute --body '

# 5c. A failed job outside the matrix is not a variant: the fallback text stands.
rc=$(run_script failure "$NONE" "$FIX_NO_MATRIX_JOB")
assert_rc      "failure/non-matrix-job exits 0" 0 "$rc"
assert_call    "a failed non-matrix job yields the fallback title" '^issue create .*--title Weekly rebuild failed: \(see the run summary'
assert_no_call "  ... and is never named as a variant"        '^issue create .*notify'

# 5d. GitHub's auto-generated multi-key job name parses to the same variant.
rc=$(run_script failure "$NONE" "$FIX_MULTIKEY")
assert_rc      "failure/multikey-name exits 0" 0 "$rc"
assert_call    "multi-key job name yields just the variant" '^issue create .*--title Weekly rebuild failed: noble --body '

# 5e. An unparseable jobs document must not abort the alert: fallback text.
rc=$(run_script failure "$NONE" 'not json at all')
assert_rc      "failure/unparseable-jobs exits 0" 0 "$rc"
assert_call    "an unparseable jobs document yields the fallback title" '^issue create .*--title Weekly rebuild failed: \(see the run summary'

# A cancelled run is neither: no gh call at all, exit 0.
rc=$(run_script cancelled "$TWO" "$FIX_ARM64_FAIL")
assert_rc      "cancelled exits 0" 0 "$rc"
if [ -s "$LOG" ]; then echo "FAIL: cancelled made gh calls"; cat "$LOG"; fails=$((fails + 1)); else echo "ok: cancelled makes no gh call"; fi

# Usage error: fewer than two args exits 2 without calling gh.
: > "$LOG"
bash "$SCRIPT" failure >/dev/null 2>&1; rc=$?
assert_rc      "missing run-url -> usage error (exit 2)" 2 "$rc"
[ -s "$LOG" ] && { echo "FAIL: usage error made gh calls"; fails=$((fails + 1)); }

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all ci-failure-issue assertions"
