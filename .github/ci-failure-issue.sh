#!/usr/bin/env bash
#
# Open, update, or close the repo's `ci-failure` issue from a scheduled run's
# job results. Called by the `notify` job in .github/workflows/docker.yml on
# scheduled runs, so a failure anywhere in the run — a build or publish leg, or
# the keepalive job that keeps next week's run scheduled at all — reaches the
# maintainer as an issue, and the next fully green run closes it (GP7).
#
# Usage: .github/ci-failure-issue.sh <results> <run-url> [jobs-json]
#   results   the needed jobs' results, space-separated (`needs.<job>.result`
#             for each). They are aggregated here — the one copy of that rule,
#             so the suite covers it. The issue is closed only when EVERY
#             result is "success"; a run where any of them was cancelled is
#             reported and ignored; anything else — a failure, a skipped job, a
#             value GitHub has yet to invent — opens or updates the issue,
#             because none of those is a job that did its work. A single value is a
#             list of one, so "failure" / "success" / "cancelled" behave as
#             they always did.
#   run-url   link to the workflow run, put in the issue/comment body.
#   jobs-json path to `gh run view --json jobs` output (or "-" for stdin). The
#             failed job names are extracted from it here — this is the one copy
#             of that parsing, so it can be unit-tested. A build or publish leg
#             is named by its variant rather than its own leg name, since a
#             variant with several failed legs is one thing wrong; every other
#             failed job contributes its own name. Omitted, empty, or
#             unparseable means the issue falls back to generic text; a document
#             that is present but names no failed job is warned about rather
#             than quietly falling back.
# Env: GH_TOKEN (or a logged-in `gh`) with issues:write on the repo.
#
# One issue is reused: with an open ci-failure issue, a failure comments on
# the first one the listing returns instead of opening another.
#
set -euo pipefail

LABEL="ci-failure"

# jq's own diagnostics land here rather than in /dev/null, so an absent jq or a
# changed `gh run view --json jobs` schema is reported instead of silently
# degrading the alert to its generic text.
JQ_ERR="$(mktemp)"
trap 'rm -f "$JQ_ERR"' EXIT

usage() {
    echo "usage: $0 <results> <run-url> [jobs-json]" >&2
    exit 2
}

# Collapse the needed jobs' results to one of failure / success / cancelled.
# Success is unanimous or it is not success: the old rule fell through to the
# build job's own result, so a green build with a cancelled or skipped publish
# read as "success" and closed the issue on a run that moved no tag. An empty
# list is a failure too — nothing reported success.
aggregate_result() {
    local all_success=1 any_failure=0 any_cancelled=0 r
    [ $# -gt 0 ] || all_success=0
    for r in "$@"; do
        case "$r" in
            success)   ;;
            failure)   all_success=0; any_failure=1 ;;
            cancelled) all_success=0; any_cancelled=1 ;;
            *)         all_success=0 ;;
        esac
    done
    if [ "$all_success" -eq 1 ]; then
        echo success
    elif [ "$any_failure" -eq 1 ]; then
        echo failure
    elif [ "$any_cancelled" -eq 1 ]; then
        echo cancelled
    else
        echo failure
    fi
}

[ $# -ge 2 ] || usage
# Deliberately unquoted: the first argument is a space-separated list.
# shellcheck disable=SC2086
result="$(aggregate_result $1)"
run_url="$2"
jobs_json="${3:-}"

# Recover the failed job names from the run's job list. The build legs are
# named "build (<variant>, <arch>)" and the publish legs "publish (<variant>)",
# so for those the variant is the first field inside the parentheses — a
# variant whose two build legs both failed is one thing wrong and must be named
# once, hence the dedup. A job name GitHub generated from a matrix `include`
# with several keys carries the extra keys after the first comma, which the
# same parse discards. Every other failed job — `meta`, `keepalive`, whatever
# a later lane adds — has no variant to recover and is named by itself, so a
# reportable job never has to be enumerated here to be reported.
extract_failed_names() {
    jq -r '
        .jobs[]
        | select(.conclusion == "failure")
        | .name
        | if test("^(build|publish) \\(") then
              sub("^(build|publish) \\("; "") | sub("[,)].*$"; "")
          else
              .
          end
        | select(length > 0)
    ' 2>"$JQ_ERR" | awk '!seen[$0]++' || true
}

jobs_doc=""
if [ -n "$jobs_json" ]; then
    if [ "$jobs_json" = "-" ]; then
        jobs_doc="$(cat)"
    else
        jobs_doc="$(cat "$jobs_json" 2>/dev/null || true)"
    fi
fi

failed_names=()
if [ -n "$jobs_doc" ]; then
    while IFS= read -r v; do
        [ -n "$v" ] && failed_names+=("$v")
    done < <(printf '%s' "$jobs_doc" | extract_failed_names)
fi

# Emitted outside the extraction pipeline, so it reaches stdout as a workflow
# annotation instead of being read back as a job name.
if [ -s "$JQ_ERR" ]; then
    echo "::warning::could not parse the job listing ($(head -1 "$JQ_ERR")); the issue will not name the failed jobs"
fi

if [ ${#failed_names[@]} -gt 0 ]; then
    failed_text="${failed_names[*]}"
else
    failed_text="(see the run summary for the failed job)"
fi

# Fill the `open` array with the numbers of the open ci-failure issues,
# oldest first (gh's default order is newest first; the reused issue should
# be the one opened first). A read loop, not mapfile: macOS bash 3.2 runs
# the test.
list_open() {
    open=()
    while IFS= read -r n; do
        [ -n "$n" ] && open+=("$n")
    done < <(gh issue list --label "$LABEL" --state open --limit 100 \
        --json number --jq 'sort_by(.number) | .[].number')
}

case "$result" in
    failure)
        # A failed run whose own job listing names no failed job at all is a
        # contradiction — the extraction, the job names, or the aggregation is
        # wrong. Say so rather than quietly shipping the generic text.
        if [ ${#failed_names[@]} -eq 0 ] && [ -n "$jobs_doc" ] && [ ! -s "$JQ_ERR" ]; then
            echo "::warning::the run is reported failed but its job listing names no failed job; the issue falls back to generic text"
        fi
        gh label create "$LABEL" --force \
            --description "Opened by the scheduled run when a job fails" \
            --color B60205 >/dev/null
        list_open
        if [ ${#open[@]} -eq 0 ]; then
            gh issue create --label "$LABEL" \
                --title "Weekly run failed: $failed_text" \
                --body "$(printf 'The scheduled run failed in: %s\n\nRun: %s\n\nThis issue is closed automatically by the next fully green scheduled run.' "$failed_text" "$run_url")"
            echo "opened a $LABEL issue for: $failed_text"
        else
            gh issue comment "${open[0]}" \
                --body "$(printf 'The scheduled run failed again in: %s\n\nRun: %s' "$failed_text" "$run_url")"
            echo "commented on open $LABEL issue #${open[0]}"
        fi
        ;;
    success)
        list_open
        if [ ${#open[@]} -eq 0 ]; then
            echo "the scheduled run was fully green; no open $LABEL issue"
            exit 0
        fi
        for n in "${open[@]}"; do
            gh issue comment "$n" \
                --body "$(printf 'The scheduled run was fully green; closing.\n\nRun: %s' "$run_url")"
            gh issue close "$n"
            echo "closed $LABEL issue #$n"
        done
        ;;
    *)
        echo "the run was $result; neither opening nor closing a $LABEL issue"
        ;;
esac
