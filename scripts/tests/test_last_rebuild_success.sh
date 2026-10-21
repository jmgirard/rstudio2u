#!/usr/bin/env bash
#
# Unit tests for .github/last-rebuild-success.sh.
#
# A stub `gh` on PATH logs every invocation and answers only the one query the
# script is meant to make: `run list` for docker.yml's successful scheduled
# runs. It applies the script's own --jq filter to canned run JSON with the real
# jq, so the `// empty` in that filter is exercised rather than assumed. Any
# other argument list exits 97, so a query that drifted (another workflow,
# another event, no status filter) reads as a failed lookup here and is caught
# by the query assertion below rather than answered as if it were right (M09's
# lesson: a stub must be sensitive to the arguments it answers). GH_STUB_RC set
# non-zero makes the right query fail too, which is the lookup-failure case.
# Runs offline: no network, no token.
#
# Every outcome is asserted on the word written to the output file — the value
# rebuild-gap.sh receives as its first argument — and on the warning, if any,
# that the workflow log shows.
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required (the gh stub applies the script's --jq filter)"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../.github/last-rebuild-success.sh"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
GH_LOG="$WORK/gh.log"
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GH_STUB_LOG"
want="run list --workflow docker.yml --event schedule --status success --limit 1 --json createdAt --jq"
if [ "${*:1:$(( $# - 1 ))}" != "$want" ]; then
    echo "gh stub: unexpected arguments: $*" >&2
    exit 97
fi
if [ "${GH_STUB_RC:-0}" -ne 0 ]; then
    echo "gh stub: simulated failure" >&2
    exit "$GH_STUB_RC"
fi
printf '%s' "$GH_STUB_RUNS" | jq -r "${!#}"
EOF
chmod +x "$WORK/bin/gh"
export GH_STUB_LOG="$GH_LOG"
export PATH="$WORK/bin:$PATH"

# run_script <runs-json> [gh-exit-status] — fresh log and output file each run;
# echoes the script's exit status.
run_script() {
    : > "$GH_LOG"; rm -f "$WORK/result"
    GH_STUB_RUNS="$1" GH_STUB_RC="${2:-0}" bash "$SCRIPT" "$WORK/result" >"$WORK/out" 2>&1
    echo $?
}

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected exit $want, got $got"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# assert_result <desc> <word> — the output file holds exactly this word
assert_result() {
    local desc="$1" want="$2" got
    got="$(cat "$WORK/result" 2>/dev/null || echo '<no file>')"
    if [ "$got" = "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected '$want', got '$got'"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

assert_out() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$WORK/out"; then echo "ok: $desc"; else
        echo "FAIL: $desc — no output line matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

assert_no_out() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$WORK/out"; then
        echo "FAIL: $desc — unexpected output matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# 1. A successful scheduled run on record: its date, the ten characters before
# the T, and no warning.
rc=$(run_script '[{"createdAt":"2026-10-19T06:00:12Z"}]')
assert_rc      "a dated run exits 0" 0 "$rc"
assert_result  "  ... and yields its YYYY-MM-DD" 2026-10-19
assert_no_out  "  ... warning about nothing" '::warning::'

# 2. The query asked for the right runs: docker.yml, scheduled, successful, the
# newest one. A push-triggered or dispatched build proves someone was here, not
# that the unattended lane works.
if grep -qxE -- 'run list --workflow docker.yml --event schedule --status success --limit 1 --json createdAt --jq .+' "$GH_LOG"; then
    echo "ok: the lookup asks for the newest successful scheduled docker.yml run"
else
    echo "FAIL: the lookup made an unexpected gh call"; sed 's/^/    gh /' "$GH_LOG"; fails=$((fails + 1))
fi

# 3. The query worked and matched nothing: `none`, a gap with its own wording.
rc=$(run_script '[]')
assert_rc      "an empty history exits 0" 0 "$rc"
assert_result  "  ... and yields none" none
assert_no_out  "  ... warning about nothing" '::warning::'

# 4. An answer without the date shape: `unknown`, and the value is shown.
rc=$(run_script '[{"createdAt":"yesterday"}]')
assert_rc      "an unparseable answer exits 0" 0 "$rc"
assert_result  "  ... and yields unknown" unknown
assert_out     "  ... warning with the value it could not read" "::warning::.*unparseable createdAt .*yesterday"

# 5. A date with no T after it is not the RFC 3339 shape either: the shape is
# checked whole, not just its first ten characters.
rc=$(run_script '[{"createdAt":"2026-10-19"}]')
assert_rc      "a bare date exits 0" 0 "$rc"
assert_result  "  ... and yields unknown" unknown

# 6. The lookup itself failed: `unknown`, never a measured gap and never `none`.
rc=$(run_script '[{"createdAt":"2026-10-19T06:00:12Z"}]' 1)
assert_rc      "a failed lookup exits 0" 0 "$rc"
assert_result  "  ... and yields unknown" unknown
assert_out     "  ... warning that the lookup failed" '::warning::gh run list failed'

# 7. Called without an output path: usage, exit 2, no lookup.
: > "$GH_LOG"
bash "$SCRIPT" >"$WORK/out" 2>&1; rc=$?
assert_rc      "no output path is a usage error (exit 2)" 2 "$rc"
if [ -s "$GH_LOG" ]; then echo "FAIL: a usage error still called gh"; fails=$((fails + 1)); else echo "ok: a usage error calls no gh command"; fi

if [ "$fails" -eq 0 ]; then
    echo "PASS: all last-rebuild-success assertions"
else
    echo "FAILED: $fails assertion(s)"
    exit 1
fi
