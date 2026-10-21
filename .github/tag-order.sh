#!/usr/bin/env bash
#
# Decide which tags a publish leg may attach without moving any of them
# backward. Called by the `publish` job in .github/workflows/docker.yml before
# it assembles the manifest list; the rule lives here, not in the workflow, so
# each of its outcomes is unit-tested in scripts/tests/test_tag_order.sh (the
# keepalive.sh pattern).
#
# Every manifest list the publish job creates carries the run's stamp as the
# index annotation org.opencontainers.image.created. A tag whose current index
# carries a later stamp was published by a newer run, and moving it to this
# run's images would move it backward: "Re-run failed jobs" of an older run's
# publish leg, within the six days its digest artifacts last, is the case this
# exists for.
#
# Usage: .github/tag-order.sh <run-stamp> <output-file> <ref>...
#   run-stamp    this run's stamp, YYYY-MM-DDTHH:MM:SSZ (the meta job's output).
#   output-file  where the refs the leg may attach are written, one per line. A
#                file rather than stdout, so the warnings below reach the run
#                log instead of being captured as the answer.
#   ref          each tag the leg would attach, as a full image reference.
#
# Before any read the script takes the current UTC time, logs it with its
# source, and exits 1 if the run stamp is later than it: both come from runner
# clocks, so a reversed pair means a clock is wrong.
#
# For each ref the index it points at now is read with
# `docker buildx imagetools inspect --raw`. A read that exits non-zero with
# anything but the not-found line for that ref is a failed read. A failed read
# 1 or 2 is logged with a ::warning:: naming the ref, the read number and the
# cause, and after a pause the ref is read again, up to 3 reads in all; a
# failed read 3 is the ::error:: below. The first read that exits
# 0 or answers not-found decides the ref, which is:
#   kept       absent from the registry, or its index carries no stamp, or a
#              stamp equal to or earlier than this run's;
#   left out   its index carries a stamp later than this run's but not later
#              than the current time, with a ::warning:: naming the ref and
#              both stamps;
#   unsettled  anything else: 3 failed reads, output that is not JSON or not
#              an index, an annotations value that is not an object (null and
#              false included), a stamp not in the fixed form, or a stamp later
#              than the current time.
# Exit 0 when every ref is kept or left out (an empty file means attach
# nothing). Exit 1 with a ::error:: per unsettled ref, or for a bad run stamp,
# time or pause, or a missing jq, and no output file: the leg must then attach
# no tag at all. Exit 2 on a usage error.
#
# A stamp later than the current time was most likely not written by a run (a
# run's stamp is its meta job's clock reading, taken before it publishes), so
# it most likely comes from a hand re-point gone wrong, though a runner clock
# that is behind gives the same result. It fails every leg that reads the tag
# until the current time passes the stamp. To clear it sooner, re-point the
# tag by hand with a stamp that is the current UTC time in the fixed form:
#   docker buildx imagetools create \
#     --annotation "index:org.opencontainers.image.created=<stamp>" \
#     -t <image>:<tag> <image>:<tag>
#
# Two environment variables exist for the tests; the workflow sets neither:
#   TAG_ORDER_NOW          the current time, in place of `date -u`. When set,
#                          empty included, it is used and must be in the
#                          fixed form.
#   TAG_ORDER_RETRY_DELAY  seconds to pause between reads, a whole number of
#                          1 to 3 digits; 10 when unset.
#
set -uo pipefail
# [[ a > b ]] collates by locale; byte order is what makes the stamps compare.
export LC_ALL=C

if [ $# -lt 3 ] || [ -z "$2" ]; then
    echo "usage: $0 <run-stamp> <output-file> <ref>..." >&2
    exit 2
fi
run_stamp="$1"; out="$2"; shift 2

# Never leave an earlier call's answer behind: a call that exits 1 leaves no
# file.
rm -f "$out"

# The fixed form, and only it: every stamp this workflow writes has it, and two
# stamps of the same width compare correctly as strings. A fractional-second
# or offset form would compare wrongly, so it is refused rather than guessed at.
stamp_re='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'

if ! [[ $run_stamp =~ $stamp_re ]]; then
    echo "::error::run stamp '$run_stamp' is not in the fixed form YYYY-MM-DDTHH:MM:SSZ; no tag can be checked"
    exit 1
fi
command -v jq >/dev/null || { echo "::error::jq is not installed; no tag can be checked"; exit 1; }

delay="${TAG_ORDER_RETRY_DELAY-10}"
if ! [[ $delay =~ ^[0-9]{1,3}$ ]]; then
    echo "::error::TAG_ORDER_RETRY_DELAY '$delay' is not a whole number of 1 to 3 digits; no tag can be checked"
    exit 1
fi

# ${VAR+set}: set but empty still counts as set, and is then refused below.
if [ -n "${TAG_ORDER_NOW+set}" ]; then
    now="$TAG_ORDER_NOW"; now_from="TAG_ORDER_NOW"
else
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; now_from="date -u"
fi
if ! [[ $now =~ $stamp_re ]]; then
    echo "::error::the current time '$now' from $now_from is not in the fixed form YYYY-MM-DDTHH:MM:SSZ; no tag can be checked"
    exit 1
fi
echo "current UTC time: $now (from $now_from)"
if [[ $run_stamp > $now ]]; then
    echo "::error::run stamp $run_stamp is later than the current UTC time $now (from $now_from); no tag can be checked"
    exit 1
fi

keep=()
unsettled=0
err_file="$(mktemp)"
trap 'rm -f "$err_file"' EXIT

for ref in "$@"; do
    read_ok=0; absent=0; cause=""
    for attempt in 1 2 3; do
        if raw="$(docker buildx imagetools inspect --raw "$ref" 2>"$err_file")"; then
            read_ok=1
            break
        fi
        # buildx reports a missing tag as `ERROR: docker.io/<ref>: not found`
        # with exit 1, the same status as every other failure, so the line is
        # the only signal. It must name this ref: any other failure, a rate
        # limit or an outage, says nothing about what the tag points at, and
        # is read again instead.
        if grep -qxF -- "ERROR: docker.io/$ref: not found" "$err_file" \
            || grep -qxF -- "ERROR: $ref: not found" "$err_file"; then
            absent=1
            break
        fi
        # Name the cause: the first ERROR line, since buildx can print a
        # WARNING line before it; else the first line of whatever it said.
        # err_file is rewritten by each read, so this is this read's cause.
        cause="$(grep -m 1 '^ERROR' "$err_file" || head -n 1 "$err_file")"
        if [ "$attempt" -lt 3 ]; then
            echo "::warning::read $attempt of 3 of $ref failed: ${cause:-(no message)}; reading again in ${delay}s"
            sleep "$delay"
        fi
    done
    if [ "$absent" -eq 1 ]; then
        keep+=("$ref")
        continue
    fi
    if [ "$read_ok" -eq 0 ]; then
        echo "::error::cannot read the index $ref points at after 3 reads: ${cause:-(no message)}"
        unsettled=1
        continue
    fi
    if ! jq -e . >/dev/null 2>&1 <<< "$raw"; then
        echo "::error::the registry's answer for $ref is not JSON"
        unsettled=1
        continue
    fi
    # An index (OCI) or manifest list (Docker) has a manifests array; a
    # single-platform manifest does not, and is not what a publish leg tags.
    if ! jq -e '.manifests | type == "array"' >/dev/null 2>&1 <<< "$raw"; then
        echo "::error::$ref points at JSON that is not an index"
        unsettled=1
        continue
    fi
    # Annotations that are present but not an object (null and false
    # included) would make `has` below error or read as unstamped; refuse them
    # instead. Only an index with no annotations key at all is unstamped that way.
    if ! jq -e 'if has("annotations") then .annotations | type == "object" else true end' >/dev/null <<< "$raw"; then
        echo "::error::$ref points at an index whose annotations are not an object"
        unsettled=1
        continue
    fi
    # Absent key: unstamped, published before stamps existed. A key that is
    # present must hold a string in the fixed form; null included, it is not.
    if ! jq -e '(.annotations // {}) | has("org.opencontainers.image.created")' >/dev/null <<< "$raw"; then
        keep+=("$ref")
        continue
    fi
    stamp="$(jq -r '.annotations["org.opencontainers.image.created"] | if type == "string" then . else "<\(type)>" end' <<< "$raw")"
    if ! [[ $stamp =~ $stamp_re ]]; then
        echo "::error::$ref carries the stamp '$stamp', which is not in the fixed form YYYY-MM-DDTHH:MM:SSZ"
        unsettled=1
        continue
    fi
    if [[ $stamp > $now ]]; then
        echo "::error::$ref carries the stamp $stamp, later than the current UTC time $now: every run fails on it until the clock passes that stamp or the tag is re-pointed by hand (the command is in the header of .github/tag-order.sh)"
        unsettled=1
        continue
    fi
    if [[ $stamp > $run_stamp ]]; then
        echo "::warning::not moving $ref: it points at an index stamped $stamp, later than this run's $run_stamp"
    else
        keep+=("$ref")
    fi
done

if [ "$unsettled" -ne 0 ]; then
    exit 1
fi

if [ "${#keep[@]}" -gt 0 ]; then
    printf '%s\n' "${keep[@]}" > "$out"
else
    : > "$out"
fi
