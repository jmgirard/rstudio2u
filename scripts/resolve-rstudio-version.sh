#!/usr/bin/env bash
#
# Resolve and validate the current stable RStudio Server version.
#
# Scrapes rstudio.org's check_for_update endpoint and validates the result
# against the RStudio version shape BEFORE anyone builds a tag or a download
# URL from it. A format change, or an empty/HTML/error response, is a hard
# failure (non-zero exit, message on stderr, nothing usable on stdout) rather
# than a silently mis-named image tag (Known issue #2 / GP2).
#
# Usage: resolve-rstudio-version.sh [--tag]
#   (default) prints the canonical version with '+', e.g. 2024.12.1+563
#   --tag     prints the tag-safe form with '-',      e.g. 2024.12.1-563
#
# Test seam: if RS_UPDATE_RESPONSE is set (even to empty), its value is used as
# the raw endpoint body instead of fetching, so the validator is testable
# offline with no network and no dependencies.
#
set -euo pipefail

ENDPOINT="https://www.rstudio.org/links/check_for_update?version=1.0.0"
# RStudio Server versions look like 2024.12.1+563 — year.month.patch{+,-}build.
# Validated with bash's own ERE engine (no PCRE / grep -P dependency).
VERSION_RE='^[0-9]{4}\.[0-9]{2}\.[0-9]+[+-][0-9]+$'

render="plus"
case "${1:-}" in
    --tag) render="dash" ;;
    "")    ;;
    *)     echo "resolve-rstudio-version: unknown argument '$1'" >&2; exit 2 ;;
esac

# Raw endpoint body: injected under test, fetched otherwise.
if [ -n "${RS_UPDATE_RESPONSE+set}" ]; then
    body="$RS_UPDATE_RESPONSE"
else
    body="$(wget -qO- "$ENDPOINT")" || {
        echo "resolve-rstudio-version: failed to fetch $ENDPOINT" >&2
        exit 1
    }
fi

# Extract the update-version field value (everything up to the next '&') using
# pure parameter expansion, then URL-decode %2B -> +.
if [[ "$body" == *update-version=* ]]; then
    raw="${body#*update-version=}"   # strip up to and including the first key
    raw="${raw%%&*}"                 # keep only up to the next field separator
else
    raw=""
fi
version="${raw//%2B/+}"

if [ -z "$version" ]; then
    echo "resolve-rstudio-version: no update-version in endpoint response (format change or empty/error body?)" >&2
    exit 1
fi

if [[ ! "$version" =~ $VERSION_RE ]]; then
    echo "resolve-rstudio-version: resolved version '$version' does not match the expected RStudio version shape" >&2
    exit 1
fi

if [ "$render" = "dash" ]; then
    printf '%s\n' "${version//+/-}"
else
    printf '%s\n' "$version"
fi
