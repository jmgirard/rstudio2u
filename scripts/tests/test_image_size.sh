#!/usr/bin/env bash
#
# Unit tests for .github/image-size.sh and .github/image-size-report.sh.
#
# Stub `docker` and `gh` commands sit on PATH and log every call. The docker
# stub answers only `buildx imagetools inspect --raw <ref>`, from one set of
# files per ref, and exits 97 on anything else. The gh stub answers
# `issue list` with canned JSON through the real --jq filter. Runs offline: no
# network, no token. Limits come from a fixture file, so raising a real limit
# changes no case here. One case reads the committed file for its shape only.
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIZE="$HERE/../../.github/image-size.sh"
REPORT="$HERE/../../.github/image-size-report.sh"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/refs"
GH_LOG="$WORK/gh.log"
GH_ALL="$WORK/gh-all.log"
DOCKER_LOG="$WORK/docker.log"

cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GH_STUB_LOG"
printf '%s\n' "${args//$'\n'/ }" >> "$GH_STUB_ALL"
if [ "${1:-} ${2:-}" = "issue list" ]; then
    [ "${GH_STUB_LIST_FAILS:-0}" = "1" ] && { echo "HTTP 502" >&2; exit 1; }
    jqf=""
    while [ $# -gt 0 ]; do
        if [ "$1" = "--jq" ]; then jqf="$2"; shift; fi
        shift
    done
    printf '%s' "$GH_STUB_LIST" | jq -r "$jqf"
elif [ "${1:-} ${2:-}" = "issue create" ]; then
    echo "https://github.com/o/r/issues/99"
fi
exit 0
EOF
# A ref's answer comes from <key>.out, with <key>.fail holding how many reads
# fail before it answers (a large number means every read fails).
cat > "$WORK/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCKER_STUB_LOG"
[ "${1:-} ${2:-} ${3:-} ${4:-}" = "buildx imagetools inspect --raw" ] && [ $# -eq 5 ] || exit 97
key="$DOCKER_STUB_REFS/$(printf '%s' "$5" | tr '/:@' '___')"
fail=0; [ -f "$key.fail" ] && fail="$(cat "$key.fail")"
if [ "$fail" -gt 0 ]; then
    echo "$((fail - 1))" > "$key.fail"
    echo "WARNING: a line before the error" >&2
    echo "ERROR: unexpected status from HEAD request: 503 Service Unavailable" >&2
    exit 1
fi
[ -f "$key.out" ] || { echo "ERROR: docker.io/$5: not found" >&2; exit 1; }
cat "$key.out"
EOF
chmod +x "$WORK/bin/gh" "$WORK/bin/docker"
export GH_STUB_LOG="$GH_LOG" GH_STUB_ALL="$GH_ALL" DOCKER_STUB_LOG="$DOCKER_LOG" DOCKER_STUB_REFS="$WORK/refs"
export GH_STUB_LIST='[]'
export PATH="$WORK/bin:$PATH"
export IMAGE_SIZE_RETRY_DELAY=0

for c in gh docker; do
    if [ "$(command -v "$c")" != "$WORK/bin/$c" ]; then
        echo "FAIL: the $c stub is not first on PATH ($(command -v "$c"))"; exit 1
    fi
done
gh probe-call >/dev/null 2>&1
if ! grep -q '^probe-call$' "$GH_LOG"; then echo "FAIL: the gh stub did not record a call"; exit 1; fi
docker probe-call >/dev/null 2>&1
if ! grep -q '^probe-call$' "$DOCKER_LOG"; then echo "FAIL: the docker stub did not record a call"; exit 1; fi
: > "$GH_ALL"
echo "ok: the gh and docker stubs are on PATH and record what they are given"

LIMITS="$WORK/limits"
cat > "$LIMITS" <<'EOF'
# noble 1 is a comment, not a limit
noble 100
resolute 200
twice 100
twice 200
broken 12x
EOF
export IMAGE_SIZE_LIMITS="$LIMITS"

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc — expected exit $want, got $got"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

assert_out() {
    local desc="$1" want="$2"
    if grep -qF -- "$want" "$WORK/out"; then echo "ok: $desc"; else
        echo "FAIL: $desc — no output line holding: $want"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

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
        echo "FAIL: $desc — a gh call matched /$re/"; sed 's/^/    gh /' "$GH_LOG"
        fails=$((fails + 1))
    else
        echo "ok: $desc"
    fi
}

# --- The comparison ----------------------------------------------------------

manifest() { # <file> <size>...
    local f="$1" sizes="" s; shift
    for s in "$@"; do sizes="$sizes${sizes:+,}{\"size\":$s}"; done
    printf '{"schemaVersion":2,"layers":[%s]}' "$sizes" > "$f"
}

run_size() { bash "$SIZE" "$@" >"$WORK/out" 2>&1; echo $?; }

M="$WORK/m.json"

manifest "$M" 60000000 39900000
assert_rc "a size under the limit passes, over all the layers" 0 "$(run_size noble amd64 "$M")"
assert_out "the within line names the size and limit" "noble amd64: 99.9 MB, limit 100 MB"

manifest "$M" 100000000
assert_rc "a size equal to the limit passes" 0 "$(run_size noble amd64 "$M")"

manifest "$M" 100000001
assert_rc "one byte over the limit fails" 1 "$(run_size noble amd64 "$M")"
assert_out "an over size never prints as equal to the limit" "noble amd64: 100.1 MB, over the 100 MB limit"

manifest "$M" 150000000
assert_rc "150 MB is over noble's limit" 1 "$(run_size noble arm64 "$M")"
assert_rc "the same 150 MB is within resolute's limit" 0 "$(run_size resolute arm64 "$M")"

printf '{"layers":[]}' > "$M"
assert_rc "an empty layers list is unreadable, not a size of 0" 2 "$(run_size noble amd64 "$M")"
assert_out "the unread line says what is wrong" "noble amd64: unread (the manifest holds no layer sizes)"

printf '{"manifests":[]}' > "$M"
assert_rc "a missing layers list is unreadable" 2 "$(run_size noble amd64 "$M")"

printf '{"layers":[{"size":5},{"digest":"sha256:abc"}]}' > "$M"
assert_rc "a layer with no size is unreadable, not a smaller sum" 2 "$(run_size noble amd64 "$M")"

printf '<html>rate limited</html>' > "$M"
assert_rc "an answer that is not JSON is unreadable" 2 "$(run_size noble amd64 "$M")"

assert_rc "a missing manifest file is unreadable" 2 "$(run_size noble amd64 "$WORK/absent.json")"
assert_out "the missing-file line names the file" "cannot read $WORK/absent.json"

manifest "$M" 1
assert_rc "a variant with no limit is unreadable" 2 "$(run_size jammy amd64 "$M")"
assert_out "the no-limit line names the variant and the file" "no single limit for jammy in $LIMITS"
assert_rc "a variant with two limits is unreadable" 2 "$(run_size twice amd64 "$M")"
assert_rc "a limit that is not a whole number is unreadable" 2 "$(run_size broken amd64 "$M")"
assert_rc "a missing limits file is unreadable" 2 "$(IMAGE_SIZE_LIMITS="$WORK/absent" run_size noble amd64 "$M")"
assert_rc "too few arguments is refused" 2 "$(run_size noble amd64)"

for v in noble resolute; do
    rc="$( (unset IMAGE_SIZE_LIMITS; run_size "$v" amd64 "$M") )"
    assert_rc "the committed limits file holds one limit for $v" 0 "$rc"
    if grep -qE "^$v amd64: 0\.1 MB, limit [1-9][0-9]* MB$" "$WORK/out"; then
        echo "ok: the committed limit for $v is the one printed"
    else
        echo "FAIL: the committed limit for $v did not print"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
done

# --- The pull request lane: a manifest read out of an OCI archive -------------

oci() { # <file> <arch> <manifest-json>
    local d="$WORK/oci" hex
    hex="$(printf '%064d' 7)"
    rm -rf "$d"; mkdir -p "$d/blobs/sha256"
    printf '%s' "$3" > "$d/blobs/sha256/$hex"
    printf '{"manifests":[{"digest":"sha256:%s","platform":{"architecture":"%s","os":"linux"}}]}' "$hex" "$2" > "$d/index.json"
    tar -cf "$1" -C "$d" index.json blobs
}

A="$WORK/x.oci.tar"

oci "$A" amd64 '{"layers":[{"size":40000000},{"size":50000000}]}'
assert_rc "an archive within the limit passes" 0 "$(run_size --from-oci noble amd64 "$A")"
assert_out "the archive's layers are the ones summed" "noble amd64: 90.0 MB, limit 100 MB"

oci "$A" amd64 '{"layers":[{"size":123456789}]}'
assert_rc "an archive over the limit fails the check" 1 "$(run_size --from-oci noble amd64 "$A")"
assert_out "the failure names the size and limit" "::error::noble amd64 is 123.5 MB, over its 100 MB limit"
assert_out "the failure says how to raise the limit" "raise the limit in .github/image-size-limits"

oci "$A" amd64 '{"layers":[]}'
assert_rc "an archive whose manifest has no layers fails the check" 2 "$(run_size --from-oci noble amd64 "$A")"
assert_out "that failure is the missing layers" "the manifest holds no layer sizes"

oci "$A" arm64 '{"layers":[{"size":1}]}'
assert_rc "an archive with no manifest for the architecture fails the check" 2 "$(run_size --from-oci noble amd64 "$A")"
assert_out "that failure names the architecture" "no single amd64 manifest"

printf 'not a tar' > "$A"
assert_rc "a file that is not an archive fails the check" 2 "$(run_size --from-oci noble amd64 "$A")"
assert_out "that failure names the index it could not read" "cannot read index.json"

# --- The weekly report --------------------------------------------------------

IMAGE="jmgirard/rstudio2u"

ref_key() { printf '%s/%s' "$WORK/refs" "$(printf '%s' "$1" | tr '/:@' '___')"; }

digest_of() { # <variant> <arch>: a distinct, well-formed digest for each leg
    case "$1 $2" in
        "noble amd64")    printf 'sha256:%064d' 1 ;;
        "noble arm64")    printf 'sha256:%064d' 2 ;;
        "resolute amd64") printf 'sha256:%064d' 3 ;;
        "resolute arm64") printf 'sha256:%064d' 4 ;;
    esac
}

# Every tag answers, and all four sizes are within the fixture limits. Each
# case then changes only what it is about.
reset_registry() {
    local v a
    rm -f "$WORK"/refs/*
    for v in noble resolute; do
        printf '{"manifests":[{"digest":"%s","platform":{"architecture":"amd64","os":"linux"}},{"digest":"%s","platform":{"architecture":"arm64","os":"linux"}},{"digest":"sha256:%064d","platform":{"architecture":"unknown","os":"unknown"}}]}' \
            "$(digest_of "$v" amd64)" "$(digest_of "$v" arm64)" 9 > "$(ref_key "$IMAGE:$v").out"
        for a in amd64 arm64; do
            manifest "$(ref_key "$IMAGE@$(digest_of "$v" "$a")").out" 50000000
        done
    done
}

set_leg_size() { manifest "$(ref_key "$IMAGE@$(digest_of "$1" "$2")").out" "$3"; }
leg_answer()   { printf '%s' "$3" > "$(ref_key "$IMAGE@$(digest_of "$1" "$2")").out"; }
leg_fails()    { echo "$3" > "$(ref_key "$IMAGE@$(digest_of "$1" "$2")").fail"; }

run_report() {
    : > "$GH_LOG"; : > "$DOCKER_LOG"
    RUN_URL="https://github.com/o/r/actions/runs/456" bash "$REPORT" >"$WORK/out" 2>&1
    echo $?
}

reset_registry
GH_STUB_LIST='[]'
assert_rc "all four within and no open issue: the report passes" 0 "$(run_report)"
for leg in "noble amd64" "noble arm64" "resolute amd64" "resolute arm64"; do
    assert_out "the log names $leg against its limit" "$leg: 50.0 MB, limit"
done
assert_call "the report looks for an open issue under its own label" "issue list --label image-size --state open"
assert_no_call "with nothing to report it creates no issue" "issue create"
assert_no_call "with nothing to report it closes no issue" "issue close"

GH_STUB_LIST='[{"number":9},{"number":7}]'
assert_rc "all four within with open issues: the report passes" 0 "$(run_report)"
assert_call "all four within closes the first open issue" "^issue close 7$"
assert_call "all four within closes the other open issue" "^issue close 9$"
assert_call "the closing comment names the run" "issue comment 7 .*actions/runs/456"
assert_no_call "all four within creates no issue" "issue create"

reset_registry
set_leg_size noble arm64 150000000
GH_STUB_LIST='[]'
assert_rc "an over size still passes the run: nothing here stops a publish" 0 "$(run_report)"
assert_call "the label is ensured before the issue opens" "^label create image-size --force"
assert_call "an over size opens an issue under the label" "issue create --label image-size"
assert_call "the issue title names the variant and architecture" "--title Image over its size limit: noble arm64 "
assert_call "the issue names the variant, architecture, size, and limit" "--body .*noble arm64: 150\.0 MB, over the 100 MB limit"
assert_call "the issue names the run" "--body .*actions/runs/456"
assert_no_call "an over size closes no issue" "issue close"

GH_STUB_LIST='[{"number":9},{"number":7}]'
assert_rc "an over size with open issues passes the run" 0 "$(run_report)"
assert_call "it comments on the oldest open issue" "issue comment 7 --body .*noble arm64: 150\.0 MB, over the 100 MB limit"
assert_no_call "it opens no second issue" "issue create"
assert_no_call "an over size with an open issue closes nothing" "issue close"

reset_registry
leg_fails resolute arm64 99
GH_STUB_LIST='[{"number":7}]'
assert_rc "an unread size passes the run: the report is the alert" 0 "$(run_report)"
n="$(grep -c "@$(digest_of resolute arm64)" "$DOCKER_LOG")"
if [ "$n" -eq 3 ]; then echo "ok: a manifest read that keeps failing stops at 3 reads"; else
    echo "FAIL: expected 3 reads of the failing manifest, got $n"; fails=$((fails + 1))
fi
assert_out "the retry notice names the read and the registry's error, not its warning" "::notice::read 2 of 3 of $IMAGE@$(digest_of resolute arm64) failed: ERROR: unexpected status"
assert_call "the unread size goes in the same issue, with its cause" "issue comment 7 --body .*resolute arm64: unread \(cannot read the manifest after 3 reads: ERROR: unexpected status"
assert_no_call "an unread size never closes the issue, though the other three are within" "issue close"
assert_no_call "an unread size with an open issue opens no second one" "issue create"

GH_STUB_LIST='[]'
leg_fails resolute arm64 99
assert_rc "an unread size with no open issue passes the run" 0 "$(run_report)"
assert_call "an unread size alone opens the issue, titled as unread" "issue create --label image-size --title Image size not read: resolute arm64 "

reset_registry
leg_answer noble amd64 '{"layers":[]}'
GH_STUB_LIST='[{"number":7}]'
assert_rc "an answer with no layer sizes passes the run" 0 "$(run_report)"
assert_call "an answer with no layer sizes reads as unread" "issue comment 7 --body .*noble amd64: unread \(the manifest holds no layer sizes\)"
assert_no_call "an answer with no layer sizes never closes the issue" "issue close"

reset_registry
echo 99 > "$(ref_key "$IMAGE:noble").fail"
GH_STUB_LIST='[{"number":7}]'
assert_rc "an unread tag passes the run" 0 "$(run_report)"
assert_call "an unread tag reports its first architecture as unread" "--body .*noble amd64: unread \(cannot read the tag after 3 reads"
assert_call "an unread tag reports its second architecture as unread" "--body .*noble arm64: unread \(cannot read the tag after 3 reads"
assert_no_call "an unread tag never closes the issue" "issue close"

reset_registry
printf '{"manifests":[{"digest":"%s","platform":{"architecture":"amd64","os":"linux"}}]}' "$(digest_of noble amd64)" > "$(ref_key "$IMAGE:noble").out"
GH_STUB_LIST='[{"number":7}]'
assert_rc "a tag missing an architecture passes the run" 0 "$(run_report)"
assert_call "the missing architecture reads as unread" "--body .*noble arm64: unread \(the tag's index names no single linux/arm64 manifest\)"
assert_no_call "a missing architecture never closes the issue" "issue close"

reset_registry
set_leg_size noble amd64 150000000
leg_fails resolute amd64 99
GH_STUB_LIST='[]'
assert_rc "an over size and an unread size together pass the run" 0 "$(run_report)"
assert_call "the issue holds the over size" "--body .*noble amd64: 150\.0 MB, over the 100 MB limit"
assert_call "the same issue holds the unread size" "--body .*resolute amd64: unread"

reset_registry
leg_fails noble amd64 2
GH_STUB_LIST='[{"number":7}]'
assert_rc "a read that recovers on the third try passes the run" 0 "$(run_report)"
assert_call "a recovered read counts as read, so the issue closes" "^issue close 7$"

reset_registry
set_leg_size noble amd64 150000000
GH_STUB_LIST='[]'
rc="$(GH_STUB_LIST_FAILS=1 run_report)"
if [ "$rc" -ne 0 ]; then echo "ok: a failed issue listing fails the run"; else
    echo "FAIL: a failed issue listing passed the run"; fails=$((fails + 1))
fi
assert_no_call "a failed issue listing opens no duplicate issue" "issue create"

if grep -q 'ci-failure' "$GH_ALL"; then
    echo "FAIL: a gh call named ci-failure"; grep 'ci-failure' "$GH_ALL" | sed 's/^/    gh /'
    fails=$((fails + 1))
elif [ -s "$GH_ALL" ]; then
    echo "ok: across every case above, no gh call names ci-failure"
else
    echo "FAIL: no gh call was recorded, so the ci-failure check saw nothing"; fails=$((fails + 1))
fi

if [ "$fails" -gt 0 ]; then
    echo "FAILED: $fails case(s)"
    exit 1
fi
echo "all image-size tests passed"
