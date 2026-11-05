#!/usr/bin/env bash
#
# Read the compressed size of each published image and report on the repo's
# `image-size` issue. Called by .github/workflows/image-size.yml. The rule lives
# here, so scripts/tests/test_image_size.sh can test each outcome offline.
#
# This report never stops a publish, and it never touches the `ci-failure`
# issue, because a lasting over-limit size would otherwise turn weekly runs red.
#
# For each of the four tag and architecture pairs, the script reads the tag's
# index and then the manifest it names with
# `docker buildx imagetools inspect --raw`, up to 3 reads each, and asks
# .github/image-size.sh for the verdict. Each size falls into one of three sets:
#   within  at or under its limit;
#   over    over its limit;
#   unread  a read failed 3 times, or the index names no single manifest for
#           that architecture, or the manifest holds no layer sizes.
#
# All four within: comment on and close every open `image-size` issue.
# Anything over or unread: comment on the oldest open `image-size` issue, or
# open one if none is open. An unread size is never counted as within, so it
# never closes the issue.
#
# Exit 0 once the issue is up to date, whatever the sizes are: the issue is the
# alert, as with .github/rebuild-gap.sh. A failed `gh` call exits non-zero, so a
# listing that failed cannot read as "no issue is open" and open a second one.
#
# Env: RUN_URL   link to this run, put in the issue text. A missing one is a
#                stand-in line, never a withheld report.
#      GH_TOKEN  (or a logged-in `gh`) with issues:write.
#
# One environment variable exists for the tests, and the workflow does not set
# it: IMAGE_SIZE_RETRY_DELAY, the seconds between reads, a whole number of 1 to
# 3 digits. It is 10 when unset.
#
set -euo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="jmgirard/rstudio2u"
LABEL="image-size"
run_url="${RUN_URL:-(this run did not receive its link)}"

delay="${IMAGE_SIZE_RETRY_DELAY-10}"
if ! [[ $delay =~ ^[0-9]{1,3}$ ]]; then
    echo "::error::IMAGE_SIZE_RETRY_DELAY '$delay' is not a whole number of 1 to 3 digits"
    exit 2
fi
command -v jq >/dev/null || { echo "::error::jq is not installed"; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# read_ref <ref>: the answer lands in $answer, and the last failure in $cause.
# Globals rather than stdout, so the retry notice reaches the run log.
read_ref() {
    local ref="$1" attempt
    answer=""; cause=""
    for attempt in 1 2 3; do
        if answer="$(docker buildx imagetools inspect --raw "$ref" 2>"$work/err")"; then
            return 0
        fi
        # buildx can print a WARNING line before its ERROR line.
        cause="$(grep -m 1 '^ERROR' "$work/err" || head -n 1 "$work/err")"
        cause="${cause//$'\r'/}"
        cause="${cause:-no message}"
        if [ "$attempt" -lt 3 ]; then
            # The runner decodes %-escapes in a workflow command.
            echo "::notice::read $attempt of 3 of $ref failed: ${cause//%/%25}; reading again in ${delay}s"
            sleep "$delay"
        fi
    done
    return 1
}

within_lines=""; over_lines=""; unread_lines=""
over_names=""; unread_names=""

# record <exit status from image-size.sh> <variant> <arch> <line>
record() {
    local name="$2 $3" line="$4"
    echo "$line"
    case "$1" in
        0)  within_lines+="- $line"$'\n' ;;
        1)  over_lines+="- $line"$'\n'
            over_names+="${over_names:+, }$name" ;;
        *)  unread_lines+="- $line"$'\n'
            unread_names+="${unread_names:+, }$name" ;;
    esac
}

for variant in noble resolute; do
    if ! read_ref "$IMAGE:$variant"; then
        for arch in amd64 arm64; do
            record 2 "$variant" "$arch" "$variant $arch: unread (cannot read the tag after 3 reads: $cause)"
        done
        continue
    fi
    index="$answer"
    for arch in amd64 arm64; do
        digest="$(jq -r --arg a "$arch" \
            '[.manifests[]? | select(.platform.architecture == $a and .platform.os == "linux")] | if length == 1 then .[0].digest else empty end' \
            <<< "$index" 2>/dev/null || true)"
        if ! [[ $digest =~ ^sha256:[0-9a-f]{64}$ ]]; then
            record 2 "$variant" "$arch" "$variant $arch: unread (the tag's index names no single linux/$arch manifest)"
            continue
        fi
        if ! read_ref "$IMAGE@$digest"; then
            record 2 "$variant" "$arch" "$variant $arch: unread (cannot read the manifest after 3 reads: $cause)"
            continue
        fi
        printf '%s' "$answer" > "$work/manifest.json"
        rc=0
        line="$(bash "$HERE/image-size.sh" "$variant" "$arch" "$work/manifest.json")" || rc=$?
        record "$rc" "$variant" "$arch" "${line:-$variant $arch: unread (image-size.sh gave no answer and exited $rc)}"
    done
done

# Oldest first, so the issue reused is the one opened first.
open_issues="$(gh issue list --label "$LABEL" --state open --limit 100 \
    --json number --jq 'sort_by(.number) | .[].number')"

if [ -z "$over_lines" ] && [ -z "$unread_lines" ]; then
    if [ -z "$open_issues" ]; then
        echo "all four sizes are within their limits; no open $LABEL issue"
        exit 0
    fi
    for n in $open_issues; do
        gh issue comment "$n" \
            --body "$(printf 'All four sizes were read and are within their limits; closing.\n\n%s\nRun: %s' "$within_lines" "$run_url")"
        gh issue close "$n"
        echo "closed $LABEL issue #$n"
    done
    exit 0
fi

report=""
[ -z "$over_lines" ] || report+="Over the limit:"$'\n'"$over_lines"$'\n'
[ -z "$unread_lines" ] || report+="Not read, so not counted as within the limit:"$'\n'"$unread_lines"$'\n'
[ -z "$within_lines" ] || report+="Within the limit:"$'\n'"$within_lines"$'\n'
report+="Run: $run_url"

if [ -n "$over_names" ]; then
    title="Image over its size limit: $over_names"
else
    title="Image size not read: $unread_names"
fi

if [ -z "$open_issues" ]; then
    gh label create "$LABEL" --force \
        --description "Opened by the weekly image size check" \
        --color FBCA04 >/dev/null
    gh issue create --label "$LABEL" --title "$title" \
        --body "$(printf '%s\n\nThe images still publish. A pull request raises a limit by editing .github/image-size-limits and stating the reason. The next run that reads all four sizes within their limits closes this issue.' "$report")"
    echo "opened an $LABEL issue: $title"
else
    oldest="${open_issues%%$'\n'*}"
    gh issue comment "$oldest" --body "$report"
    echo "commented on open $LABEL issue #$oldest"
fi
