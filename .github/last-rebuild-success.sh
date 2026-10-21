#!/usr/bin/env bash
#
# Find when a scheduled rebuild last succeeded, as the one word that
# .github/rebuild-gap.sh takes as its first argument. Called by the `gap` job
# in .github/workflows/rebuild-gap.yml, which hands that word straight on — the
# reduction of `gh run list`'s answer lives here, not in the workflow, so each
# of its outcomes is unit-tested in scripts/tests/test_last_rebuild_success.sh
# (the keepalive.sh pattern).
#
# Usage: .github/last-rebuild-success.sh <output-file>
#   output-file  where the word is written, alone on one line. A file rather
#                than stdout, so the workflow warnings below reach the run log
#                on stdout instead of being captured as the answer.
# Env: GH_TOKEN (or a logged-in `gh`) with actions:read on the repo.
#
# The word is one of:
#   YYYY-MM-DD  the date of the newest successful scheduled docker.yml run.
#   none        the history was read and holds no such run.
#   unknown     the history could not be read: the lookup failed, or it
#               answered something without the date shape.
# Every outcome exits 0: `none` and `unknown` are both alerts that
# rebuild-gap.sh raises, so none of them may end the run before it is called.
# Anything but exactly one non-empty argument exits 2; an output file that
# cannot be written fails the step like any other shell error.
#
set -euo pipefail

if [ $# -ne 1 ] || [ -z "$1" ]; then
    echo "usage: $0 <output-file>" >&2
    exit 2
fi
out="$1"

# The newest SUCCESSFUL SCHEDULED docker.yml run, and only that: a
# push-triggered or dispatched build proves someone was here, not that the
# unattended lane still works, and the unattended lane is what this checks.
if ! created_at="$(gh run list --workflow docker.yml --event schedule \
        --status success --limit 1 --json createdAt \
        --jq '.[0].createdAt // empty')"; then
    # The lookup itself failed. Not a measured gap and not a clean bill of
    # health, so it is neither reported as one: `unknown` is the sentinel
    # rebuild-gap.sh renders as its own alert.
    echo "::warning::gh run list failed; reporting an unreadable rebuild history"
    last_success=unknown
elif [ -z "$created_at" ]; then
    # The query worked and matched nothing: no successful scheduled run is on
    # record. That is a gap, and saying so explicitly is what keeps an empty
    # string from reaching rebuild-gap.sh as a mis-shaped date and being
    # refused instead of reported.
    last_success=none
elif [[ $created_at =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
    # `createdAt` is RFC 3339 in UTC (a trailing Z), so the date is the ten
    # characters before the T -- no `date` parsing, whose flags differ between
    # GNU and BSD.
    last_success="${created_at%%T*}"
else
    # A value with no T would reach rebuild-gap.sh whole, be refused as a
    # mis-shaped date, and end the run at exit 2 having raised nothing.
    # Silence is the one outcome the check must never have, so an unreadable
    # answer is the `unknown` sentinel like any other unreadable history.
    echo "::warning::gh run list returned an unparseable createdAt ('$created_at'); reporting an unreadable rebuild history"
    last_success=unknown
fi

printf '%s\n' "$last_success" > "$out"
