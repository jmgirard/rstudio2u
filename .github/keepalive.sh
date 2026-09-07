#!/usr/bin/env bash
#
# Decide whether the checked-out branch is stale enough to need a keepalive
# commit, and make one if it is. Called by the `keepalive` job in
# .github/workflows/docker.yml, which checks out the default branch with a
# push credential and hands this script three dates/numbers and nothing else
# — the staleness rule lives here, in one place, so it can be unit-tested
# offline (the .github/ci-failure-issue.sh pattern).
#
# Usage: .github/keepalive.sh <commit-date> <current-date> <threshold-days>
#   commit-date     ISO-8601 YYYY-MM-DD; the date of the branch's newest commit.
#   current-date    ISO-8601 YYYY-MM-DD; today, in UTC.
#   threshold-days  a non-negative integer; the age at which a commit is made.
#
# The branch is stale when current-date minus commit-date is threshold-days or
# more. Stale means exactly two git calls — an empty commit and then a push,
# in that order and with nothing else on the path. Fresh means no git call at
# all, a line saying so, and exit 0. Every argument is validated before either
# date is compared; a rejection names the argument it rejected and exits 2,
# making no git call either. A threshold wider than the arithmetic can hold is
# fresh, never stale — see the comparison below.
#
# The argument validation itself — the date parsing, the calendar check and the
# threshold's width bound — lives in .github/date-lib.sh, shared with
# .github/rebuild-gap.sh, which asks the same shape of question about a
# different pair of dates. The boundary is not shared: this script acts at or
# past its threshold, and that comparison stays here.
#
set -euo pipefail

# shellcheck source=.github/date-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/date-lib.sh"

# The commit's author and committer. Set with `git -c` on the commit call
# rather than by a `git config` call, so the stale path is the two git calls
# the tests assert and nothing else.
COMMIT_NAME="github-actions[bot]"
COMMIT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

[ $# -le 3 ] || die "expected 3 arguments, got $#"

commit_date="${1-}"
current_date="${2-}"
threshold="${3-}"

commit_days="$(parse_date "the commit date (argument 1)" "$commit_date")"
current_days="$(parse_date "the current date (argument 2)" "$current_date")"

threshold_digits="$(parse_threshold "the threshold in days (argument 3)" "$threshold")"

age=$(( current_days - commit_days ))

# A commit dated after today is not a fresh branch, it is a clock or an input
# that cannot be trusted to decide anything. Refuse rather than compute a
# negative age that would always read as fresh.
if (( age < 0 )); then
    die "the commit date (argument 1) is later than the current date: '$commit_date' > '$current_date'"
fi

# A threshold too wide for the arithmetic is larger than any age, not smaller
# (date-lib.sh states why), so it is fresh without the arithmetic being asked.
# Below the threshold is fresh; at or past it is stale.
if threshold_is_unreachable "$threshold_digits" || (( age < 10#$threshold_digits )); then
    echo "the newest commit is $age day(s) old, below the ${threshold}-day threshold; no keepalive commit"
    exit 0
fi

message="keepalive: empty commit to keep scheduled workflows enabled

The newest commit on this branch was $age day(s) old, at or past the
${threshold}-day threshold. GitHub disables a public repository's scheduled
workflows after 60 days without repository activity; this commit is that
activity and changes nothing else."

echo "the newest commit is $age day(s) old, at or past the ${threshold}-day threshold; committing"
git -c "user.name=$COMMIT_NAME" -c "user.email=$COMMIT_EMAIL" \
    commit --allow-empty -m "$message"
git push
echo "pushed a keepalive commit"
