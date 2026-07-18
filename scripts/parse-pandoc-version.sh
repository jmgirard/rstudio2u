#!/usr/bin/env bash
#
# Parse and validate a Pandoc version from `pandoc --version` / `pandoc -v` output.
#
# Reads the raw version text on stdin, extracts the version off the leading
# `pandoc <ver>` line, and validates it against the pandoc version shape BEFORE
# anyone compares it or builds a pandoc-templates download URL from it. Empty,
# HTML/error, or format-changed input is a hard failure (non-zero exit, message
# on stderr, nothing on stdout) rather than a silent empty/wrong version feeding
# a bad wget (GP4-licensed hardening of the owned fork; the M03/M04 scrape-guard
# pattern applied to install_pandoc.sh's version parses).
#
# Usage: pandoc --version | parse-pandoc-version.sh
#   prints the bare version (e.g. 3.1.11) on stdout.
#
# Extraction uses bash's own ERE engine (no PCRE / grep -P dependency), so it is
# testable offline on any platform by piping a fixture in on stdin.
#
set -euo pipefail

# The version line looks like `pandoc 3.1.11` (2+ dot-separated numeric fields;
# pandoc has shipped four-component versions such as 2.14.0.3). Anchored to the
# whole line so a renamed field or trailing junk fails instead of mis-matching.
re='^pandoc[[:space:]]+([0-9]+(\.[0-9]+)+)[[:space:]]*$'

version=""
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ $re ]]; then
        version="${BASH_REMATCH[1]}"
        break
    fi
done

if [ -z "$version" ]; then
    echo "parse-pandoc-version: no 'pandoc <version>' line in input (format change, empty/error body, or not pandoc output?)" >&2
    exit 1
fi

printf '%s\n' "$version"
