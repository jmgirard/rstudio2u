#!/usr/bin/env bash
#
# Unit tests for .github/tag-order.sh.
#
# A stub `docker` on PATH logs every invocation and answers only the one query
# the script is meant to make: `buildx imagetools inspect --raw <ref>`. Each ref
# gets its own canned answer (stdout, stderr and exit status) from a per-ref
# file set, so a list of tags can mix every shape the registry can return (M09's
# lesson: a stub answering a looped query must be argument-sensitive and
# multi-item). Any other argument list exits 97, which the script must report as
# a read it cannot settle. Runs offline: no network, no registry login.
#
# Every verdict is asserted on the file the script writes — the tags the publish
# leg may attach — and on the warning or error that names each tag it leaves out
# or cannot settle.
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
[ -f "$dir/$key.out" ] && cat "$dir/$key.out"
[ -f "$dir/$key.err" ] && cat "$dir/$key.err" >&2
exit "$(cat "$dir/$key.rc" 2>/dev/null || echo 0)"
EOF
chmod +x "$WORK/bin/docker"
export DOCKER_STUB_LOG="$DOCKER_LOG" DOCKER_STUB_ANSWERS="$WORK/answers"
export PATH="$WORK/bin:$PATH"

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

reset() { rm -f "$WORK/answers/"*; : > "$DOCKER_LOG"; rm -f "$WORK/attach"; }

# run_script <run-stamp> <ref>... — echoes the script's exit status.
run_script() {
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
    if [ ! -s "$WORK/attach" ]; then echo "ok: $desc"; else
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

# assert_queried <desc> <ref>... — the stub saw exactly one read per ref, in order.
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

# --- Refusal: a later stamp leaves that tag out, with a warning --------------

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

echo "== 9. a not-found line for another ref is not absence"
reset
answer_error "$T1" "ERROR: docker.io/$IMG:other: not found"
assert_rc "not settled" 1 "$(run_script "$R" "$T1")"
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
done
assert_no_attach "nothing to attach"

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

echo "== 16. usage"
assert_rc "no tags" 2 "$(bash "$SCRIPT" "$R" "$WORK/attach" >"$WORK/out" 2>&1; echo $?)"
assert_rc "no arguments" 2 "$(bash "$SCRIPT" >"$WORK/out" 2>&1; echo $?)"
assert_rc "empty output path" 2 "$(bash "$SCRIPT" "$R" "" "$T1" >"$WORK/out" 2>&1; echo $?)"

echo
if [ "$fails" -eq 0 ]; then echo "all tag-order tests passed"; else echo "$fails tag-order test(s) FAILED"; exit 1; fi
