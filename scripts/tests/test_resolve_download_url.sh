#!/usr/bin/env bash
#
# Unit tests for scripts/resolve-download-url.sh.
#
# A valid release-endpoint body yields the arch-matched .deb URL; empty,
# HTML/error, format-changed, and wrong-arch bodies fail loud (non-zero exit,
# nothing usable on stdout). Runs offline via the RESOLVE_DL_RESPONSE seam —
# no network, no dependencies.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$HERE/../resolve-download-url.sh"
fails=0

# A GitHub-API-style release body (pandoc): several browser_download_url
# entries — both arch .debs plus a source tarball — so arch selection matters.
GH_API='{
  "tag_name": "3.1.11",
  "assets": [
    { "name": "pandoc-3.1.11-1-amd64.deb",
      "browser_download_url": "https://github.com/jgm/pandoc/releases/download/3.1.11/pandoc-3.1.11-1-amd64.deb" },
    { "name": "pandoc-3.1.11-1-arm64.deb",
      "browser_download_url": "https://github.com/jgm/pandoc/releases/download/3.1.11/pandoc-3.1.11-1-arm64.deb" },
    { "name": "pandoc-3.1.11-linux-amd64.tar.gz",
      "browser_download_url": "https://github.com/jgm/pandoc/releases/download/3.1.11/pandoc-3.1.11-linux-amd64.tar.gz" }
  ]
}'

# A Quarto _download.json / _prerelease.json-style body: a download_url field.
QUARTO_REL='{"version": "1.4.550", "download_url": "https://github.com/quarto-dev/quarto-cli/releases/download/v1.4.550/quarto-1.4.550-linux-amd64.deb"}'
QUARTO_PRE='{"version": "1.5.23", "download_url": "https://github.com/quarto-dev/quarto-cli/releases/download/v1.5.23/quarto-1.5.23-linux-amd64.deb"}'

# assert_ok <desc> <body> <key> <arch> <expected-stdout>
assert_ok() {
    local desc="$1" body="$2" key="$3" arch="$4" expected="$5"
    local out rc
    out="$(RESOLVE_DL_RESPONSE="$body" "$RESOLVER" "https://example.invalid" "$key" "$arch" 2>/dev/null)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: $desc — expected exit 0, got $rc"; fails=$((fails + 1)); return
    fi
    if [ "$out" != "$expected" ]; then
        echo "FAIL: $desc — expected '$expected', got '$out'"; fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

# assert_fail <desc> <body> <key> <arch>
assert_fail() {
    local desc="$1" body="$2" key="$3" arch="$4"
    local out rc
    out="$(RESOLVE_DL_RESPONSE="$body" "$RESOLVER" "https://example.invalid" "$key" "$arch" 2>/dev/null)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "FAIL: $desc — expected non-zero exit, got 0 (stdout: '$out')"; fails=$((fails + 1)); return
    fi
    if [ -n "$out" ]; then
        echo "FAIL: $desc — expected empty stdout on failure, got '$out'"; fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

assert_ok   "GitHub API -> amd64 .deb (skips arm64 + tarball)" "$GH_API" browser_download_url amd64 \
            "https://github.com/jgm/pandoc/releases/download/3.1.11/pandoc-3.1.11-1-amd64.deb"
assert_ok   "GitHub API -> arm64 .deb (skips amd64)"           "$GH_API" browser_download_url arm64 \
            "https://github.com/jgm/pandoc/releases/download/3.1.11/pandoc-3.1.11-1-arm64.deb"
assert_ok   "Quarto release JSON -> amd64 .deb"                "$QUARTO_REL" download_url amd64 \
            "https://github.com/quarto-dev/quarto-cli/releases/download/v1.4.550/quarto-1.4.550-linux-amd64.deb"
assert_ok   "Quarto prerelease JSON -> amd64 .deb"             "$QUARTO_PRE" download_url amd64 \
            "https://github.com/quarto-dev/quarto-cli/releases/download/v1.5.23/quarto-1.5.23-linux-amd64.deb"

assert_fail "empty body"                        ""                          browser_download_url amd64
assert_fail "HTML error body"                   "<html><body>503 Service Unavailable</body></html>" browser_download_url amd64
assert_fail "format change: key renamed"        "${GH_API//browser_download_url/download_link}" browser_download_url amd64
assert_fail "format change: no .deb (tarball)"  '{"download_url": "https://x/quarto-1.4.550-linux-amd64.tar.gz"}' download_url amd64
assert_fail "wrong-arch only (amd64 body, want arm64)" "$QUARTO_REL" download_url arm64

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all resolver assertions"
