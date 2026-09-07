#!/usr/bin/env bash
#
# Date and threshold validation shared by .github/keepalive.sh and
# .github/rebuild-gap.sh. Both answer the same shape of question — is the gap
# between two YYYY-MM-DD dates past a threshold in days — and both have to
# refuse a bad argument before comparing anything, so the parsing lives here
# once rather than in each of them.
#
# Sourced, never executed: `. "$(dirname "$0")/date-lib.sh"`. It defines
# functions and nothing else, so sourcing it runs no logic and touches no
# state. `die` is defined here too, because parse_date and parse_threshold call
# it; it reports `$0`, which sourcing leaves as the calling script.
#
# The comparison itself is deliberately NOT here. keepalive acts at or past its
# threshold and rebuild-gap only past its own, and a shared "is it over" helper
# would have to encode one of those two boundaries for both. Each script states
# its own comparison in one line, against the values this file validates.

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
        # Unreachable while parse_date checks the month range first, below.
        # Present so a reordering there cannot turn this into an empty
        # substitution and an arithmetic syntax error in the caller.
        *) echo 0 ;;
    esac
}

# Validate one date argument and echo its day number. The shape check and the
# calendar check are separate so the message can say which one failed. Both
# dates are converted to a day number in shell arithmetic rather than by
# `date`, whose parsing flags differ between GNU and BSD; that also makes the
# validation reject an impossible date (2026-02-30) rather than only a
# mis-shaped one.
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

# Validate a threshold in days and echo it with its leading zeros stripped, so
# the digit count of what comes back is the value's own width. An all-zero
# threshold collapses to a single 0.
parse_threshold() {
    local label="$1" value="$2" stripped
    [ -n "$value" ] || die "$label is missing; expected a non-negative integer"
    if ! [[ $value =~ ^[0-9]+$ ]]; then
        die "$label is not a non-negative integer: '$value'"
    fi
    stripped="${value#"${value%%[!0]*}"}"
    [ -n "$stripped" ] || stripped=0
    echo "$stripped"
}

# True when a threshold is too wide for the arithmetic to compare, which makes
# it larger than any age rather than smaller. Shell arithmetic is 64-bit, so
# `10#` on a 19- or 20-digit value — a non-negative integer parse_threshold
# accepts — would wrap to a negative number and invert the caller's comparison.
# The widest span the YYYY-MM-DD shape admits is `days_from_civil 9999 12 31`
# minus `days_from_civil 0000 01 01` = 3652424 days, seven digits, so an age can
# never reach eight; a threshold of more than seven digits is therefore above
# every age any comparison can ever see, and the caller can say so without
# asking the arithmetic.
threshold_is_unreachable() {
    [ "${#1}" -gt 7 ]
}
