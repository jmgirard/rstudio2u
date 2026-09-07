#!/usr/bin/env bash
#
# Open, update, or close the repo's `ci-failure` issue from a workflow job's
# result. Called by the `notify` job in .github/workflows/docker.yml on
# scheduled runs, so a failed weekly rebuild reaches the maintainer as an
# issue and the next green rebuild closes it (GP7).
#
# Usage: .github/ci-failure-issue.sh <result> <run-url> [jobs-json]
#   result    the run's aggregate result: "failure" opens or updates the issue,
#             "success" closes any open ones; any other value (cancelled,
#             skipped) is reported and ignored.
#   run-url   link to the workflow run, put in the issue/comment body.
#   jobs-json path to `gh run view --json jobs` output (or "-" for stdin). The
#             failed variant names are extracted from it here — this is the one
#             copy of that parsing, so it can be unit-tested. Omitted, empty, or
#             unparseable means the issue falls back to generic text; a document
#             that is present but yields no variant is warned about rather than
#             quietly falling back.
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
    echo "usage: $0 <result> <run-url> [jobs-json]" >&2
    exit 2
}

[ $# -ge 2 ] || usage
result="$1"
run_url="$2"
jobs_json="${3:-}"

# Recover the failed variant names from the run's job list. The build legs are
# named "build (<variant>, <arch>)" and the publish legs "publish (<variant>)",
# so the variant is the first field inside the parentheses; a variant whose two
# build legs both failed must be named once, not twice, hence the dedup. A job
# name GitHub generated from a matrix `include` with several keys carries the
# extra keys after the first comma, which the same parse discards.
extract_variants() {
    jq -r '
        .jobs[]
        | select(.conclusion == "failure")
        | .name
        | select(test("^(build|publish) \\("))
        | sub("^(build|publish) \\("; "")
        | sub("[,)].*$"; "")
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

variants=()
if [ -n "$jobs_doc" ]; then
    while IFS= read -r v; do
        [ -n "$v" ] && variants+=("$v")
    done < <(printf '%s' "$jobs_doc" | extract_variants)
fi

# Emitted outside the extraction pipeline, so it reaches stdout as a workflow
# annotation instead of being read back as a variant name.
if [ -s "$JQ_ERR" ]; then
    echo "::warning::could not parse the job listing ($(head -1 "$JQ_ERR")); the issue will not name the failed variants"
fi

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
        # A failed run whose own job listing names no failed build or publish
        # leg is a contradiction — the extraction, the job names, or the
        # aggregation is wrong. Say so rather than quietly shipping the
        # generic text.
        if [ ${#variants[@]} -eq 0 ] && [ -n "$jobs_doc" ] && [ ! -s "$JQ_ERR" ]; then
            echo "::warning::the run is reported failed but its job listing names no failed build or publish leg; the issue falls back to generic text"
        fi
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
