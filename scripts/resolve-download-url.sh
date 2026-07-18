#!/usr/bin/env bash
#
# Resolve and validate a release download URL scraped from a JSON endpoint.
#
# Fetches a release-index endpoint (a GitHub releases API object, or Quarto's
# _download.json / _prerelease.json), extracts the value of a named URL field
# that points at the arch-matched .deb, and validates its shape BEFORE anyone
# hands it to wget. An empty / HTML-error / format-changed / wrong-arch
# response is a hard failure (non-zero exit, message on stderr, nothing on
# stdout) rather than a silent wget against an empty or wrong-but-plausible URL
# (GP4-licensed hardening of the owned fork; the M03 scrape-guard pattern
# applied to Pandoc/Quarto).
#
# Usage: resolve-download-url.sh <endpoint-url> <json-key> <arch>
#   <json-key>  the JSON field holding the URL — "browser_download_url"
#               (GitHub API) or "download_url" (Quarto)
#   <arch>      dpkg architecture the .deb must match, e.g. amd64 / arm64
#   prints the resolved https://…<arch>.deb URL on stdout.
#
# Extraction uses bash's own ERE engine (no PCRE / grep -P dependency), so the
# validator is testable offline on any platform.
#
# Test seam: if RESOLVE_DL_RESPONSE is set (even to empty), its value is used as
# the raw endpoint body instead of fetching — every branch is driven by a
# fixture with no network.
#
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "resolve-download-url: usage: resolve-download-url.sh <endpoint-url> <json-key> <arch>" >&2
    exit 2
fi
endpoint="$1"
key="$2"
arch="$3"

# Raw endpoint body: injected under test, fetched otherwise.
if [ -n "${RESOLVE_DL_RESPONSE+set}" ]; then
    body="$RESOLVE_DL_RESPONSE"
else
    body="$(wget -qO- "$endpoint")" || {
        echo "resolve-download-url: failed to fetch $endpoint" >&2
        exit 1
    }
fi

# Match  "<key>" : "https://…<arch>.deb"  — [^"]* is bounded by the closing
# quote of the JSON string, so it captures exactly one URL and the trailing
# <arch>.deb anchor guarantees the asset is for the requested architecture
# (a body carrying only the other arch matches nothing and fails below).
re="\"${key}\"[[:space:]]*:[[:space:]]*\"(https://[^\"]*${arch}\.deb)\""

if [[ "$body" =~ $re ]]; then
    url="${BASH_REMATCH[1]}"
else
    echo "resolve-download-url: no '$key' URL for arch '$arch' in endpoint response (format change, empty/error body, or arch not published?)" >&2
    exit 1
fi

# Defensive re-validation of the extracted URL's shape.
if [[ ! "$url" =~ ^https://[^[:space:]]+${arch}\.deb$ ]]; then
    echo "resolve-download-url: resolved URL '$url' does not match the expected https://…${arch}.deb shape" >&2
    exit 1
fi

printf '%s\n' "$url"
