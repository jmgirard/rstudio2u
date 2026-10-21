#!/usr/bin/env bash
#
# Unit tests for .github/tag-order.sh.
#
# A stub `docker` on PATH logs every invocation and answers only the one query
# the script is meant to make: `buildx imagetools inspect --raw <ref>`. Each ref
# gets its own canned answer (stdout, stderr and exit status) from a per-ref
# file set, so a list of tags can mix every shape the registry can return (the
# M09/M10 stub lesson in cairn/LESSONS.md: a stub answering a looped query must
# be argument-sensitive and multi-item). Any other argument list exits 97,
# so a query that drifted reads as a failed lookup the script cannot settle
# rather than being answered as if it were right. Runs offline: no network, no
# registry login.
#
# Each case asserts the exit status and, in most, the file the script writes
# (the tags the publish leg may attach) and the warning or error that names
# each tag it leaves out or cannot settle.
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required (the script parses the index with it)"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../.github/tag-order.sh"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/answers"
DOCKER_LOG="$WORK/docker.log"
cat > "$WORK/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCKER_STUB_LOG"
if [ "$#" -ne 5 ] || [ "$1 $2 $3 $4" != "buildx imagetools inspect --raw" ]; then
    echo "docker stub: unexpected arguments: $*" >&2
    exit 97
fi
key="${5//[\/:]/_}"
dir="$DOCKER_STUB_ANSWERS"
# Read n of this ref fails with the stderr of $key.fail<n>.err (empty
# included) when that file exists; reads with no such file answer below.
n=$(( $(cat "$dir/$key.n" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$dir/$key.n"
if [ -f "$dir/$key.fail$n.err" ]; then
    cat "$dir/$key.fail$n.err" >&2
    exit 1
fi
[ -f "$dir/$key.out" ] && cat "$dir/$key.out"
[ -f "$dir/$key.err" ] && cat "$dir/$key.err" >&2
exit "$(cat "$dir/$key.rc" 2>/dev/null || echo 0)"
EOF
chmod +x "$WORK/bin/docker"
# The pause between reads: log it instead of waiting, so a test can assert it.
SLEEP_LOG="$WORK/sleep.log"
cat > "$WORK/bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SLEEP_STUB_LOG"
EOF
chmod +x "$WORK/bin/sleep"
# A clock that answers only the one query the script makes, in its own
# directory so only the cases that want it put it on PATH.
mkdir -p "$WORK/datebin"
cat > "$WORK/datebin/date" <<'EOF'
#!/usr/bin/env bash
if [ "$*" != "-u +%Y-%m-%dT%H:%M:%SZ" ]; then
    echo "date stub: unexpected arguments: $*" >&2
    exit 97
fi
echo "$DATE_STUB_NOW"
EOF
chmod +x "$WORK/datebin/date"
export DOCKER_STUB_LOG="$DOCKER_LOG" DOCKER_STUB_ANSWERS="$WORK/answers" SLEEP_STUB_LOG="$SLEEP_LOG"
export PATH="$WORK/bin:$PATH"
# Every case runs against this clock unless it sets or removes the variable: the
# fixture stamps below (2026, 2027) are then always earlier than the time.
export TAG_ORDER_NOW=9999-12-31T23:59:59Z
unset TAG_ORDER_RETRY_DELAY

IMG=jmgirard/rstudio2u
# noble's real tag list shape: two moving tags, the date tag, the version tag.
T1="$IMG:latest" T2="$IMG:noble" T3="$IMG:noble-2026-10-20" T4="$IMG:noble-2026.09.0-387"

key() { local k="${1//[\/:]/_}"; printf '%s' "$k"; }

# index_json [stamp-json-value] — an OCI index with both linux platforms; with an
# argument, it carries that value as the created annotation (raw JSON, so a
# non-string can be planted).
index_json() {
    local ann=""
    [ "$#" -gt 0 ] && ann=", \"annotations\": {\"org.opencontainers.image.created\": $1}"
    printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"sha256:aa","size":1,"platform":{"architecture":"amd64","os":"linux"}},{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"sha256:bb","size":1,"platform":{"architecture":"arm64","os":"linux"}}]%s}\n' "$ann"
}

# Answer setters: each writes the canned reply for one ref.
answer_stamp()     { index_json "\"$2\"" > "$WORK/answers/$(key "$1").out"; }
answer_unstamped() { index_json > "$WORK/answers/$(key "$1").out"; }
answer_raw()       { printf '%s\n' "$2" > "$WORK/answers/$(key "$1").out"; }
answer_error()     { printf '%s\n' "$2" > "$WORK/answers/$(key "$1").err"; echo 1 > "$WORK/answers/$(key "$1").rc"; }
answer_absent()    { answer_error "$1" "ERROR: docker.io/$1: not found"; }
# answer_fail <ref> <n> [stderr] — read n of the ref fails with that stderr.
answer_fail() {
    local f; f="$WORK/answers/$(key "$1").fail$2.err"
    if [ -n "${3-}" ]; then printf '%s\n' "$3" > "$f"; else : > "$f"; fi
}

# assert_slept <desc> <seconds>... — the pauses taken, in order.
assert_slept() {
    local desc="$1" want got; shift
    want="$(printf '%s\n' "$@")"
    [ "$#" -eq 0 ] && want=""
    got="$(cat "$SLEEP_LOG")"
    if [ "$got" = "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected pauses [$want], got [$got]"; fails=$((fails + 1))
    fi
}

reset() { rm -f "$WORK/answers/"*; : > "$DOCKER_LOG"; : > "$SLEEP_LOG"; rm -f "$WORK/attach"; }

# run_noclock <run-stamp> <ref>... — as run_script, with TAG_ORDER_NOW removed.
run_noclock() {
    rm -f "$WORK/answers/"*.n
    env -u TAG_ORDER_NOW bash "$SCRIPT" "$1" "$WORK/attach" "${@:2}" >"$WORK/out" 2>&1
    echo $?
}

# run_script <run-stamp> <ref>... — echoes the script's exit status.
run_script() {
    rm -f "$WORK/answers/"*.n
    bash "$SCRIPT" "$1" "$WORK/attach" "${@:2}" >"$WORK/out" 2>&1
    echo $?
}

show() { sed 's/^/    | /' "$WORK/out"; }

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected exit $want, got $got"; show; fails=$((fails + 1))
    fi
}

# assert_attach <desc> <ref>... — the file holds exactly these refs, in order.
assert_attach() {
    local desc="$1" want got; shift
    want="$(printf '%s\n' "$@")"
    [ "$#" -eq 0 ] && want=""
    got="$(cat "$WORK/attach" 2>/dev/null || echo '<no file>')"
    if [ "$got" = "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected [$want], got [$got]"; show; fails=$((fails + 1))
    fi
}

assert_no_attach() {
    local desc="$1"
    if [ ! -e "$WORK/attach" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — attach file holds [$(cat "$WORK/attach")]"; show; fails=$((fails + 1))
    fi
}

# assert_line <desc> <fixed-string>... — one output line holds every string.
assert_line() {
    local desc="$1" line s ok; shift
    while IFS= read -r line; do
        ok=1
        for s in "$@"; do [[ $line == *"$s"* ]] || { ok=0; break; }; done
        [ "$ok" -eq 1 ] && { echo "ok: $desc"; return; }
    done < "$WORK/out"
    echo "FAIL: $desc — no output line holds all of: $*"; show; fails=$((fails + 1))
}

assert_count() {
    local desc="$1" want="$2" pat="$3" got
    got="$(grep -c -- "$pat" "$WORK/out")"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected $want lines with '$pat', got $got"; show; fails=$((fails + 1))
    fi
}

# assert_queried <desc> <ref>... — the stub saw exactly these reads, in order
# (a ref read again appears again).
assert_queried() {
    local desc="$1" want got r; shift
    want="$(for r in "$@"; do echo "buildx imagetools inspect --raw $r"; done)"
    got="$(cat "$DOCKER_LOG")"
    if [ "$got" = "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected reads [$want], got [$got]"; fails=$((fails + 1))
    fi
}

R=2026-10-20T06:00:00Z
LATER1S=2026-10-20T06:00:01Z
EARLIER1S=2026-10-20T05:59:59Z

# --- Leave out: a later stamp leaves that tag out, with a warning ------------

echo "== 1. later stamp (one second) on the first of four tags"
reset
answer_stamp "$T1" "$LATER1S"; answer_stamp "$T2" "$R"; answer_unstamped "$T3"; answer_absent "$T4"
assert_rc "settled" 0 "$(run_script "$R" "$T1" "$T2" "$T3" "$T4")"
assert_attach "first tag left out" "$T2" "$T3" "$T4"
assert_line "warning names the tag and both stamps" "::warning::" "$T1" "$LATER1S" "$R"
assert_count "one warning" 1 "::warning::"
assert_queried "one read per tag, in order" "$T1" "$T2" "$T3" "$T4"

echo "== 2. later stamp (a day, across a year boundary) on a middle tag"
reset
RY=2026-12-31T12:00:00Z; LY=2027-01-01T12:00:00Z
answer_stamp "$T1" "$RY"; answer_stamp "$T2" "$LY"; answer_stamp "$T3" "$RY"; answer_stamp "$T4" "2026-12-31T11:59:59Z"
assert_rc "settled" 0 "$(run_script "$RY" "$T1" "$T2" "$T3" "$T4")"
assert_attach "middle tag left out" "$T1" "$T3" "$T4"
assert_line "warning names the tag and both stamps" "::warning::" "$T2" "$LY" "$RY"
assert_count "one warning" 1 "::warning::"

echo "== 3. later stamp on the last tag"
reset
answer_unstamped "$T1"; answer_absent "$T2"; answer_stamp "$T3" "$EARLIER1S"; answer_stamp "$T4" "$LATER1S"
assert_rc "settled" 0 "$(run_script "$R" "$T1" "$T2" "$T3" "$T4")"
assert_attach "last tag left out" "$T1" "$T2" "$T3"
assert_line "warning names the tag and both stamps" "::warning::" "$T4" "$LATER1S" "$R"

echo "== 4. later stamps on two tags at once"
reset
answer_stamp "$T1" "$LATER1S"; answer_stamp "$T2" "$R"; answer_stamp "$T3" "$LY"; answer_stamp "$T4" "$R"
assert_rc "settled" 0 "$(run_script "$R" "$T1" "$T2" "$T3" "$T4")"
assert_attach "both later tags left out" "$T2" "$T4"
assert_line "warning names the first later tag" "::warning::" "$T1" "$LATER1S" "$R"
assert_line "warning names the second later tag" "::warning::" "$T3" "$LY" "$R"
assert_count "two warnings" 2 "::warning::"

echo "== 5. every tag later: nothing to attach, still settled"
reset
for t in "$T1" "$T2" "$T3" "$T4"; do answer_stamp "$t" "$LATER1S"; done
assert_rc "settled" 0 "$(run_script "$R" "$T1" "$T2" "$T3" "$T4")"
assert_attach "empty attach list"
assert_count "four warnings" 4 "::warning::"

# --- Publish: absent, unstamped, equal or earlier stays in --------------------

echo "== 6. each publish shape alone"
reset; answer_absent "$T1"
assert_rc "absent: settled" 0 "$(run_script "$R" "$T1")"
assert_attach "absent tag kept" "$T1"
assert_count "absent: no warning" 0 "::warning::"
reset; answer_unstamped "$T1"
assert_rc "unstamped: settled" 0 "$(run_script "$R" "$T1")"
assert_attach "unstamped tag kept" "$T1"
reset; answer_stamp "$T1" "$R"
assert_rc "equal: settled" 0 "$(run_script "$R" "$T1")"
assert_attach "equal stamp kept" "$T1"
reset; answer_stamp "$T1" "$EARLIER1S"
assert_rc "earlier: settled" 0 "$(run_script "$R" "$T1")"
assert_attach "earlier stamp kept" "$T1"
assert_count "earlier: no warning" 0 "::warning::"
reset
answer_raw "$T1" '{"schemaVersion":2,"mediaType":"application/vnd.docker.distribution.manifest.list.v2+json","manifests":[]}'
assert_rc "Docker manifest list, unstamped: settled" 0 "$(run_script "$R" "$T1")"
assert_attach "Docker manifest list kept" "$T1"

echo "== 7. the publish shapes mixed in one list"
reset
answer_absent "$T1"; answer_unstamped "$T2"; answer_stamp "$T3" "$R"; answer_stamp "$T4" "$EARLIER1S"
assert_rc "settled" 0 "$(run_script "$R" "$T1" "$T2" "$T3" "$T4")"
assert_attach "every tag kept" "$T1" "$T2" "$T3" "$T4"
assert_count "no warning" 0 "::warning::"

# --- Cannot settle: the leg fails and attaches nothing ------------------------

echo "== 8. a registry error other than not found"
reset
answer_stamp "$T1" "$R"
answer_error "$T2" "ERROR: failed to authorize: unexpected status from GET request: 429 Too Many Requests: toomanyrequests: You have reached your pull rate limit"
assert_rc "not settled" 1 "$(run_script "$R" "$T1" "$T2")"
assert_no_attach "nothing to attach"
assert_line "error names the tag and the cause" "::error::" "$T2" "toomanyrequests"

echo "== 8b. the ERROR line is named even after a WARNING line"
reset
printf '%s\n' "WARNING: config file is old" "ERROR: unexpected status: 503 Service Unavailable" > "$WORK/answers/$(key "$T1").err"
echo 1 > "$WORK/answers/$(key "$T1").rc"
assert_rc "not settled" 1 "$(run_script "$R" "$T1")"
assert_line "error names the ERROR line, not the warning" "::error::" "$T1" "503 Service Unavailable"

echo "== 8c. the not-found form without the docker.io prefix is absence"
reset
answer_error "$T1" "ERROR: $T1: not found"
assert_rc "settled" 0 "$(run_script "$R" "$T1")"
assert_attach "absent tag kept" "$T1"

echo "== 9. a not-found line for another ref is not absence"
reset
answer_error "$T1" "ERROR: docker.io/$IMG:other: not found"
assert_rc "not settled" 1 "$(run_script "$R" "$T1")"
assert_no_attach "nothing to attach"
assert_line "error names the tag" "::error::" "$T1"

echo "== 10. output that is not JSON"
reset; answer_raw "$T1" '<html>bad gateway</html>'
assert_rc "not settled" 1 "$(run_script "$R" "$T1")"
assert_no_attach "nothing to attach"
assert_line "error names the tag and the cause" "::error::" "$T1" "not JSON"

echo "== 11. JSON that is not an index (a single-platform manifest)"
reset
answer_raw "$T1" '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json","config":{},"layers":[]}'
assert_rc "not settled" 1 "$(run_script "$R" "$T1")"
assert_line "error names the tag and the cause" "::error::" "$T1" "not an index"

echo "== 12. a tag stamp not in the fixed form"
for bad in '"2026-10-20T06:00:00.123Z"' '"2026-10-20 06:00:00"' '""' '20261020' 'null'; do
    reset; index_json "$bad" > "$WORK/answers/$(key "$T1").out"
    assert_rc "stamp $bad: not settled" 1 "$(run_script "$R" "$T1")"
    assert_line "stamp $bad: error names the tag and the cause" "::error::" "$T1" "fixed form"
done

echo "== 13. a run stamp not in the fixed form"
for bad in "2026-10-20T06:00:00.5Z" "2026-10-20" ""; do
    reset; answer_unstamped "$T1"
    assert_rc "run stamp '$bad': not settled" 1 "$(run_script "$bad" "$T1")"
    assert_line "run stamp '$bad': error names the cause" "::error::" "run stamp" "fixed form"
    assert_queried "run stamp '$bad': no registry read"
    assert_no_attach "run stamp '$bad': nothing to attach"
done

echo "== 14. a later stamp and an unsettled tag in one list: failure wins"
reset
answer_stamp "$T1" "$LATER1S"; answer_raw "$T2" 'not json'; answer_stamp "$T3" "$R"
assert_rc "not settled" 1 "$(run_script "$R" "$T1" "$T2" "$T3")"
assert_no_attach "nothing to attach"
assert_line "error names the unsettled tag" "::error::" "$T2"

echo "== 15. a stale attach file from an earlier call is never left behind"
reset
printf '%s\n' "$T1" > "$WORK/attach"; answer_raw "$T1" 'not json'
bash "$SCRIPT" "$R" "$WORK/attach" "$T1" >"$WORK/out" 2>&1
assert_no_attach "failed call leaves no attach list"

echo "== 16. annotations that are not an object"
for bad in '"a string"' '["2026-10-20T06:00:00Z"]' 'null' 'false'; do
    reset
    answer_raw "$T1" "{\"schemaVersion\":2,\"manifests\":[],\"annotations\":$bad}"
    assert_rc "annotations $bad: not settled" 1 "$(run_script "$R" "$T1")"
    assert_no_attach "annotations $bad: nothing to attach"
    assert_line "annotations $bad: error names the tag and the cause" "::error::" "$T1" "not an object"
done

# --- Retry: a failed read is read again, up to 3 reads in all ----------------

echo "== 18a. 1 failure (a 5xx ERROR line), then a stamped answer"
reset
answer_fail "$T1" 1 "ERROR: unexpected status from HEAD request: 502 Bad Gateway"
answer_stamp "$T1" "$R"; answer_stamp "$T2" "$R"
assert_rc "settled" 0 "$(run_script "$R" "$T1" "$T2")"
assert_attach "the answer decides the tag" "$T1" "$T2"
assert_queried "2 reads of the failing tag, 1 of the other" "$T1" "$T1" "$T2"
assert_line "the retried failure is logged with the tag, read number and cause" "::notice::" "$T1" "read 1 of 3" "502 Bad Gateway"
assert_count "a retried failure is not a warning" 0 "::warning::"
assert_slept "one pause of the default 10 seconds" 10

echo "== 18b. 2 failures (empty stderr), then a later stamp"
reset
answer_fail "$T1" 1; answer_fail "$T1" 2; answer_stamp "$T1" "$LATER1S"
assert_rc "settled" 0 "$(run_script "$R" "$T1")"
assert_attach "the answer decides the tag: left out"
assert_line "warning names the tag and both stamps" "::warning::" "$T1" "$LATER1S" "$R"
assert_queried "3 reads" "$T1" "$T1" "$T1"
assert_line "read 2's failure is logged" "$T1" "read 2 of 3"
assert_slept "two pauses" 10 10

echo "== 18c. 3 failures: unsettled, the error names read 3's cause"
reset
for i in 1 2 3; do answer_fail "$T1" "$i" "ERROR: upstream failure on read-$i"; done
answer_stamp "$T1" "$R"
assert_rc "not settled" 1 "$(run_script "$R" "$T1")"
assert_no_attach "nothing to attach"
assert_queried "3 reads, no fourth" "$T1" "$T1" "$T1"
assert_line "error names the tag and read 3's cause" "::error::" "$T1" "read-3"
assert_count "the error does not name read 1's cause" 0 "::error::.*read-1"
assert_slept "two pauses, none after the last read" 10 10

echo "== 18d. 1 failure, then a not-found answer"
reset
answer_fail "$T1" 1 "ERROR: unexpected status: 500 Internal Server Error"
answer_absent "$T1"
assert_rc "settled" 0 "$(run_script "$R" "$T1")"
assert_attach "absent tag kept" "$T1"
assert_queried "2 reads" "$T1" "$T1"

echo "== 18e. not found and stamped with no failure: 1 read each, no pause"
reset
answer_absent "$T1"; answer_stamp "$T2" "$R"
assert_rc "settled" 0 "$(run_script "$R" "$T1" "$T2")"
assert_queried "1 read each" "$T1" "$T2"
assert_slept "no pause"

echo "== 18f. an exit-0 answer that is not JSON is not read again"
reset; answer_raw "$T1" '<html>bad gateway</html>'
assert_rc "not settled" 1 "$(run_script "$R" "$T1")"
assert_queried "1 read" "$T1"

echo "== 18g. a cause holding % or CR is escaped for the workflow command"
reset
for i in 1 2 3; do answer_fail "$T1" "$i" $'ERROR: denied scope=repository%3Aimg%0Apull\r'; done
assert_rc "not settled" 1 "$(run_script "$R" "$T1")"
assert_line "the error carries % as %25" "::error::" "$T1" "repository%253Aimg%250Apull"
assert_line "the notice carries % as %25" "::notice::" "$T1" "repository%253Aimg%250Apull"
assert_count "no raw CR reaches the output" 0 $'\r'

echo "== 18h. the read counter starts over with each run"
reset
answer_fail "$T1" 1 "ERROR: timeout"; answer_stamp "$T1" "$R"
run_script "$R" "$T1" >/dev/null
: > "$DOCKER_LOG"
assert_rc "second run: read 1 fails again and is retried" 0 "$(run_script "$R" "$T1")"
assert_queried "second run: 2 reads" "$T1" "$T1"
assert_line "second run logs read 1's failure" "::notice::" "$T1" "read 1 of 3"

echo "== 19. the pause comes from TAG_ORDER_RETRY_DELAY"
reset
answer_fail "$T1" 1 "ERROR: timeout"; answer_stamp "$T1" "$R"
assert_rc "settled" 0 "$(TAG_ORDER_RETRY_DELAY=5 run_script "$R" "$T1")"
assert_slept "a pause of 5 seconds" 5
for bad in -1 1.5 abc 1000 ""; do
    reset; answer_stamp "$T1" "$R"
    printf '%s\n' "$T1" > "$WORK/attach"
    assert_rc "delay '$bad': exit 1" 1 "$(TAG_ORDER_RETRY_DELAY="$bad" run_script "$R" "$T1")"
    assert_line "delay '$bad': error names the variable" "::error::" "TAG_ORDER_RETRY_DELAY"
    assert_queried "delay '$bad': no registry read"
    assert_no_attach "delay '$bad': no attach file, a stale one removed"
done

# --- The clock: a stamp later than the current time fails the leg ------------

N=2026-10-20T07:00:00Z
N1S=2026-10-20T07:00:01Z

echo "== 20a. a stamp 1 second later than the time"
reset; answer_stamp "$T1" "$N1S"; answer_stamp "$T2" "$R"
assert_rc "not settled" 1 "$(TAG_ORDER_NOW=$N run_script "$R" "$T1" "$T2")"
assert_no_attach "nothing to attach"
assert_line "error names the tag, its stamp and the time" "::error::" "$T1" "$N1S" "$N"
assert_line "the time and its source are logged" "$N" "TAG_ORDER_NOW"

echo "== 20b. a stamp equal to the time, later than the run stamp"
reset; answer_stamp "$T1" "$N"; answer_stamp "$T2" "$R"
assert_rc "settled" 0 "$(TAG_ORDER_NOW=$N run_script "$R" "$T1" "$T2")"
assert_attach "left out, the rest kept" "$T2"
assert_line "warning names the tag and both stamps" "::warning::" "$T1" "$N" "$R"

echo "== 20c. a run stamp 1 second later than the time"
reset; answer_unstamped "$T1"
assert_rc "exit 1" 1 "$(TAG_ORDER_NOW=$N run_script "$N1S" "$T1")"
assert_line "error names the run stamp and the time" "::error::" "$N1S" "$N"
assert_queried "no registry read"
assert_no_attach "nothing to attach"

echo "== 20d. a TAG_ORDER_NOW not in the fixed form"
for bad in "2026-10-20T06:00:00.5Z" "2026-10-20" ""; do
    reset; answer_unstamped "$T1"
    printf '%s\n' "$T1" > "$WORK/attach"
    assert_rc "time '$bad': exit 1" 1 "$(TAG_ORDER_NOW="$bad" run_script "$R" "$T1")"
    assert_line "time '$bad': error names the variable" "::error::" "TAG_ORDER_NOW" "fixed form"
    assert_queried "time '$bad': no registry read"
    assert_no_attach "time '$bad': no attach file, a stale one removed"
done

echo "== 21a. with TAG_ORDER_NOW removed, the time comes from date -u (stubbed)"
reset; answer_stamp "$T1" "$N1S"
assert_rc "1 second later: not settled" 1 "$(DATE_STUB_NOW=$N PATH="$WORK/datebin:$PATH" run_noclock "$R" "$T1")"
assert_line "error names the tag, its stamp and the time" "::error::" "$T1" "$N1S" "$N"
assert_line "the time and its source are logged" "$N" "date -u"
reset; answer_stamp "$T1" "$N"
assert_rc "equal: settled" 0 "$(DATE_STUB_NOW=$N PATH="$WORK/datebin:$PATH" run_noclock "$R" "$T1")"
assert_attach "equal to the time, later than the run: left out"

echo "== 21b. with TAG_ORDER_NOW removed, the real clock"
reset; answer_stamp "$T1" "2999-01-01T00:00:00Z"; answer_unstamped "$T2"
assert_rc "a stamp in 2999: not settled" 1 "$(run_noclock "$R" "$T1" "$T2")"
assert_line "error names the tag and its stamp" "::error::" "$T1" "2999-01-01T00:00:00Z"

echo "== 17. usage"
assert_rc "no tags" 2 "$(bash "$SCRIPT" "$R" "$WORK/attach" >"$WORK/out" 2>&1; echo $?)"
assert_rc "no arguments" 2 "$(bash "$SCRIPT" >"$WORK/out" 2>&1; echo $?)"
assert_rc "empty output path" 2 "$(bash "$SCRIPT" "$R" "" "$T1" >"$WORK/out" 2>&1; echo $?)"

echo
if [ "$fails" -eq 0 ]; then echo "all tag-order tests passed"; else echo "$fails tag-order test(s) FAILED"; exit 1; fi
