#!/usr/bin/env bash
#
# Open, update, or close the repo's `ci-failure` issue from a workflow job's
# result. Called by the `notify` job in .github/workflows/docker.yml on
# scheduled runs, so a failed weekly rebuild reaches the maintainer as an
# issue and the next green rebuild closes it (GP7).
#
# Usage: .github/ci-failure-issue.sh <result> <run-url> [variant ...]
#   result    the build job's result: "failure" opens or updates the issue,
#             "success" closes any open ones; any other value (cancelled,
#             skipped) is reported and ignored.
#   run-url   link to the workflow run, put in the issue/comment body.
#   variant   names of the failed variants (may be empty).
# Env: GH_TOKEN (or a logged-in `gh`) with issues:write on the repo.
#
# One issue is reused: with an open ci-failure issue, a failure comments on
# the first one the listing returns instead of opening another.
#
set -euo pipefail

LABEL="ci-failure"

usage() {
    echo "usage: $0 <result> <run-url> [variant ...]" >&2
    exit 2
}

[ $# -ge 2 ] || usage
result="$1"
run_url="$2"
shift 2
variants=("$@")

if [ ${#variants[@]} -gt 0 ]; then
    variant_text="${variants[*]}"
else
    variant_text="(see the run summary for the failed job)"
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
        gh label create "$LABEL" --force \
            --description "Opened by the weekly rebuild when it fails" \
            --color B60205 >/dev/null
        list_open
        if [ ${#open[@]} -eq 0 ]; then
            gh issue create --label "$LABEL" \
                --title "Weekly rebuild failed: $variant_text" \
                --body "$(printf 'The scheduled image rebuild failed for: %s\n\nRun: %s\n\nThis issue is closed automatically by the next green weekly rebuild.' "$variant_text" "$run_url")"
            echo "opened a $LABEL issue for: $variant_text"
        else
            gh issue comment "${open[0]}" \
                --body "$(printf 'The weekly rebuild failed again for: %s\n\nRun: %s' "$variant_text" "$run_url")"
            echo "commented on open $LABEL issue #${open[0]}"
        fi
        ;;
    success)
        list_open
        if [ ${#open[@]} -eq 0 ]; then
            echo "rebuild succeeded; no open $LABEL issue"
            exit 0
        fi
        for n in "${open[@]}"; do
            gh issue comment "$n" \
                --body "$(printf 'The weekly rebuild succeeded; closing.\n\nRun: %s' "$run_url")"
            gh issue close "$n"
            echo "closed $LABEL issue #$n"
        done
        ;;
    *)
        echo "result '$result' is neither failure nor success; nothing to do"
        ;;
esac
