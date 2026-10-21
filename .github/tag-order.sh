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
# For each ref the index it points at now is read with
# `docker buildx imagetools inspect --raw`, and the ref is:
#   kept       absent from the registry, or its index carries no stamp, or a
#              stamp equal to or earlier than this run's;
#   left out   its index carries a later stamp, with a ::warning:: naming the
#              ref and both stamps;
#   unsettled  anything else: a failed read other than "not found", output that
#              is not JSON or not an index, or a stamp not in the fixed form.
# Exit 0 when every ref is kept or left out (an empty file means attach
# nothing). Exit 1 with a ::error:: per unsettled ref, or for a bad run stamp,
# and no output file: the leg must then attach no tag at all. Exit 2 on a
# usage error.
#
set -uo pipefail
# [[ a > b ]] collates by locale; byte order is what makes the stamps compare.
export LC_ALL=C

if [ $# -lt 3 ] || [ -z "$2" ]; then
    echo "usage: $0 <run-stamp> <output-file> <ref>..." >&2
    exit 2
fi
run_stamp="$1"; out="$2"; shift 2

# Never leave an earlier call's answer behind: a failed call has no file.
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

keep=()
unsettled=0
err_file="$(mktemp)"
trap 'rm -f "$err_file"' EXIT

for ref in "$@"; do
    if ! raw="$(docker buildx imagetools inspect --raw "$ref" 2>"$err_file")"; then
        # buildx reports a missing tag as `ERROR: docker.io/<ref>: not found`
        # with exit 1, the same status as every other failure, so the line is
        # the only signal. It must name this ref: any other failure, a rate
        # limit or an outage, says nothing about what the tag points at.
        if grep -qxF -- "ERROR: docker.io/$ref: not found" "$err_file" \
            || grep -qxF -- "ERROR: $ref: not found" "$err_file"; then
            keep+=("$ref")
        else
            echo "::error::cannot read the index $ref points at: $(head -n 1 "$err_file")"
            unsettled=1
        fi
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
