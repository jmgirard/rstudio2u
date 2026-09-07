#!/usr/bin/env bash
#
# Decide whether too long has passed since a scheduled rebuild last succeeded,
# and raise the `ci-failure` issue if it has. Called by the `gap` job in
# .github/workflows/rebuild-gap.yml, which asks `gh run list` when the newest
# successful scheduled docker.yml run happened and hands this script that date
# and nothing else — the staleness rule lives here, in one place, so it can be
# unit-tested offline (the .github/keepalive.sh pattern).
#
# The alert this raises is the one thing no single workflow run can raise for
# itself: a run that never happens reports nothing, and docker.yml's `notify`
# job only ever speaks about a run that did. Whatever the cause — a disabled
# schedule, a deleted workflow, a GitHub outage, a rebuild that has been red
# for a month — the symptom is the same, and it is this: no rebuild has
# succeeded lately.
#
# Usage: .github/rebuild-gap.sh <last-success-date> <current-date> <threshold-days>
#   last-success-date  ISO-8601 YYYY-MM-DD; when a scheduled rebuild last
#                      succeeded. Two words stand in for a date that does not
#                      exist: `none` (the history is readable and holds no
#                      successful scheduled run) and `unknown` (the history
#                      could not be read at all). Both are a gap, each with its
#                      own wording, so the issue never claims a measured age it
#                      does not have. They are argument 1's alone.
#   current-date       ISO-8601 YYYY-MM-DD; today, in UTC.
#   threshold-days     a non-negative integer; the largest gap that is not yet
#                      an alert.
# Env: RUN_URL   link to this check's run, put in the issue body. A missing one
#                is a stand-in line, never a withheld alert.
#      GH_TOKEN  (or a logged-in `gh`) with issues:write, for the issue itself.
#
# There is a gap when current-date minus last-success-date is MORE than
# threshold-days — a gap exactly that wide is still within the bound. (The
# neighbouring script, keepalive.sh, acts at or past its threshold instead;
# each states its own comparison, which is why date-lib.sh shares the parsing
# and not the boundary.) A gap means the issue is raised through
# .github/ci-failure-issue.sh — the same issue a failed run opens, because the
# next fully green scheduled run is the right close condition for both. No gap
# means no call to anything, a line saying so, and exit 0. Every argument is
# validated before either date is compared; a rejection names the argument it
# rejected and exits 2, raising nothing. A threshold wider than the arithmetic
# can hold is no gap, never a gap — see the comparison below.
#
# This script reaches no network of its own: it asks nothing of `gh`, `curl` or
# `wget` while deciding, and only the alert itself talks to GitHub, through the
# one script that already owns that conversation.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=.github/date-lib.sh
. "$HERE/date-lib.sh"

[ $# -le 3 ] || die "expected 3 arguments, got $#"

last_success="${1-}"
current_date="${2-}"
threshold="${3-}"

# The issue body should link the run that noticed. Missing, the alert still goes
# out: a watchdog that stays silent over a missing convenience is the failure
# this script exists to report.
RUN_URL_FALLBACK="see the Actions tab of this repository for the run that raised this"
run_url="${RUN_URL:-$RUN_URL_FALLBACK}"

# Argument 1 is a date or one of the two sentinels; 2 and 3 are validated the
# same way whichever it is, so a bad threshold is refused on a run with no
# history just as it is on one with a gap to measure.
current_days="$(parse_date "the current date (argument 2)" "$current_date")"
threshold_digits="$(parse_threshold "the threshold in days (argument 3)" "$threshold")"

case "$last_success" in
    none)
        subject="No successful weekly rebuild on record"
        echo "no successful scheduled rebuild is on record; raising the alert"
        ;;
    unknown)
        subject="Could not read the weekly rebuild history"
        echo "the scheduled rebuild history could not be read; raising the alert"
        ;;
    *)
        last_days="$(parse_date "the last success date (argument 1)" "$last_success")"
        gap=$(( current_days - last_days ))

        # A success dated after today is not a fresh rebuild, it is a clock or
        # an input that cannot be trusted to decide anything. Refuse rather
        # than compute a negative gap that would always read as within bounds.
        if (( gap < 0 )); then
            die "the last success date (argument 1) is later than the current date: '$last_success' > '$current_date'"
        fi

        # A threshold too wide for the arithmetic is larger than any gap, not
        # smaller (date-lib.sh states why), so it is within bounds without the
        # arithmetic being asked. At the threshold is still within it; only
        # past it is a gap.
        if threshold_is_unreachable "$threshold_digits" || (( gap <= 10#$threshold_digits )); then
            echo "the weekly rebuild last succeeded $gap day(s) ago, within the ${threshold}-day bound; no alert"
            exit 0
        fi

        subject="No successful weekly rebuild in $gap days (since $last_success)"
        echo "the weekly rebuild last succeeded $gap day(s) ago, past the ${threshold}-day bound; raising the alert"
        ;;
esac

# "failure" is this check's own verdict on the schedule, not a job result: the
# issue script aggregates the first argument, and one value that is not
# "success" is what opens or updates the issue. The empty third argument is the
# jobs document there is none of — nothing here failed in a run, which is the
# whole complaint — and the subject is what the issue says instead.
bash "$HERE/ci-failure-issue.sh" failure "$run_url" "" "$subject"
