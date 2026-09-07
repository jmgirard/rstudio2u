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
# Both dates are converted to a day number in shell arithmetic rather than by
# `date`, whose parsing flags differ between GNU and BSD; that also makes the
# validation reject an impossible date (2026-02-30) rather than only a
# mis-shaped one.
#
set -euo pipefail

# The commit's author and committer. Set with `git -c` on the commit call
# rather than by a `git config` call, so the stale path is the two git calls
# the tests assert and nothing else.
COMMIT_NAME="github-actions[bot]"
COMMIT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

die() {
    echo "$0: $1" >&2
    exit 2
}

# Days since 1970-01-01 for a proleptic-Gregorian Y-M-D (Howard Hinnant's
# days_from_civil). Every expansion is forced base 10: "08" and "09" are not
# valid octal, and a month or day written that way would otherwise abort.
days_from_civil() {
    local y=$((10#$1)) m=$((10#$2)) d=$((10#$3)) era yoe doy doe
    y=$(( m <= 2 ? y - 1 : y ))
    era=$(( (y >= 0 ? y : y - 399) / 400 ))
    yoe=$(( y - era * 400 ))
    doy=$(( (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1 ))
    doe=$(( yoe * 365 + yoe / 4 - yoe / 100 + doy ))
    echo $(( era * 146097 + doe - 719468 ))
}

days_in_month() {
    local y=$((10#$1)) m=$((10#$2))
    case "$m" in
        1|3|5|7|8|10|12) echo 31 ;;
        4|6|9|11)        echo 30 ;;
        2)
            if (( y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) )); then
                echo 29
            else
                echo 28
            fi
            ;;
    esac
}

# Validate one date argument and echo its day number. The shape check and the
# calendar check are separate so the message can say which one failed.
parse_date() {
    local label="$1" value="$2" y m d
    [ -n "$value" ] || die "$label is missing; expected a YYYY-MM-DD date"
    if ! [[ $value =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        die "$label is not a YYYY-MM-DD date: '$value'"
    fi
    y="${value:0:4}"; m="${value:5:2}"; d="${value:8:2}"
    if (( 10#$m < 1 || 10#$m > 12 )); then
        die "$label names month '$m', which is not a month: '$value'"
    fi
    if (( 10#$d < 1 || 10#$d > $(days_in_month "$y" "$m") )); then
        die "$label names day '$d', which that month does not have: '$value'"
    fi
    days_from_civil "$y" "$m" "$d"
}

[ $# -le 3 ] || die "expected 3 arguments, got $#"

commit_date="${1-}"
current_date="${2-}"
threshold="${3-}"

commit_days="$(parse_date "the commit date (argument 1)" "$commit_date")"
current_days="$(parse_date "the current date (argument 2)" "$current_date")"

[ -n "$threshold" ] || die "the threshold in days (argument 3) is missing; expected a non-negative integer"
if ! [[ $threshold =~ ^[0-9]+$ ]]; then
    die "the threshold in days (argument 3) is not a non-negative integer: '$threshold'"
fi

# Leading zeros stripped, so the digit count below is the value's own width;
# an all-zero threshold collapses to a single 0.
threshold_digits="${threshold#"${threshold%%[!0]*}"}"
[ -n "$threshold_digits" ] || threshold_digits=0

age=$(( current_days - commit_days ))

# A commit dated after today is not a fresh branch, it is a clock or an input
# that cannot be trusted to decide anything. Refuse rather than compute a
# negative age that would always read as fresh.
if (( age < 0 )); then
    die "the commit date (argument 1) is later than the current date: '$commit_date' > '$current_date'"
fi

# A threshold too wide for the arithmetic is larger than any age, not smaller.
# Shell arithmetic is 64-bit, so a 19- or 20-digit argument 3 — a non-negative
# integer this script accepts — would wrap to a negative number and invert the
# comparison. The widest span the YYYY-MM-DD shape admits is
# `days_from_civil 9999 12 31` minus `days_from_civil 0000 01 01` = 3652424
# days, seven digits, so an age can never reach eight; a threshold of more
# than seven digits is therefore above every age the comparison can ever see,
# and the branch is fresh without the arithmetic being asked.
if [ "${#threshold_digits}" -gt 7 ] || (( age < 10#$threshold_digits )); then
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
