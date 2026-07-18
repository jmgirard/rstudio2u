#!/usr/bin/env bash
#
# Guard: every tracked Windows launcher (*.bat) must be stored with CRLF line
# endings *in the git blob itself*, not merely smudged to CRLF on checkout.
#
# Why the blob and not the working tree: the README's recommended install path
# is "Download ZIP" (git archive), which exports blobs verbatim and applies no
# eol conversion. So `*.bat text eol=crlf` (clone-only smudging) is not enough —
# a ZIP-download student on Windows would get LF files that cmd.exe parses
# unreliably. Only CRLF *in the blob* (via `*.bat -text` + committed CRLF bytes)
# survives every delivery channel: ZIP, clone, and raw download alike.
#
# `git cat-file -p :<file>` reads the stored blob (post-clean-filter) — exactly
# the bytes `git archive` ships. Runs offline, no network, no dependencies.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
cd "$REPO" || { echo "FAIL: cannot cd to repo root"; exit 1; }
fails=0

# Portable collection (no `mapfile` — macOS ships bash 3.2; M03 portability
# lesson). NUL-delimited to survive any path oddities.
bats=()
while IFS= read -r -d '' f; do
    bats+=("$f")
done < <(git ls-files -z '*.bat')
if [ "${#bats[@]}" -eq 0 ]; then
    echo "FAIL: no tracked *.bat files found — guard would silently pass"
    exit 1
fi

for f in "${bats[@]}"; do
    # Count total lines (\n) vs. lines ending in CR. Equal and non-zero ⇒ every
    # line is CRLF-terminated; fewer CRLF than total ⇒ at least one bare LF.
    n_lf="$(git cat-file -p ":$f" | wc -l | tr -d ' ')"
    n_crlf="$(git cat-file -p ":$f" | grep -c $'\r$' || true)"
    if [ "$n_lf" -eq 0 ]; then
        echo "FAIL: $f — blob has no line breaks at all"; fails=$((fails + 1)); continue
    fi
    if [ "$n_crlf" -ne "$n_lf" ]; then
        echo "FAIL: $f — blob has $((n_lf - n_crlf)) LF-only line(s) of $n_lf; expected all CRLF"
        fails=$((fails + 1)); continue
    fi
    echo "ok: $f — all $n_lf lines CRLF-terminated in blob"
done

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails launcher(s) not CRLF in blob"; exit 1
fi
echo "PASS: all *.bat launchers stored with CRLF"
