#!/usr/bin/env bash
#
# Guard: every tracked Windows launcher (*.bat) must be stored with CRLF line
# endings in the git blob itself.
#
# Why the blob: `.gitattributes` marks *.bat as `-text`, so a checkout writes
# the blob's bytes with no line-ending conversion. A blob stored with LF
# reaches a Windows user as LF files that cmd.exe parses unreliably.
# `.gitattributes` gives a command that shows that the conversion is off.
#
# `git cat-file -p :<file>` reads the stored blob from the index. Runs offline,
# no network, no dependencies.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
cd "$REPO" || { echo "FAIL: cannot cd to repo root"; exit 1; }
fails=0

# Prints "<lines> <crlf_lines>" for the bytes that the command "$@" writes:
# the count of LF bytes, then the count of lines that end in CR. Equal and
# non-zero means that every line is CRLF-terminated. Fewer CRLF than total
# means at least one LF-only line. The appended x keeps a final CR with no LF
# after it from counting as a CRLF, which would hide one LF-only line.
line_counts() {
    local n_lf n_crlf
    n_lf="$("$@" | wc -l | tr -d ' ')"
    n_crlf="$({ "$@"; printf x; } | grep -c $'\r$' || true)"
    echo "$n_lf $n_crlf"
}

# Built-in check of line_counts: these bytes hold one LF-only line and end in
# a CR with no LF, so the counts must differ.
read -r n_lf n_crlf < <(line_counts printf 'a\r\nb\nc\r')
if [ "$n_crlf" -eq "$n_lf" ]; then
    printf '%s\n' "FAIL: built-in check: line_counts passes 'a\r\nb\nc\r', which has an LF-only line"
    exit 1
fi

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
    read -r n_lf n_crlf < <(line_counts git cat-file -p ":$f")
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
