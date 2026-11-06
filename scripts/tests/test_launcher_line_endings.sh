#!/usr/bin/env bash
#
# Guard: every tracked Windows launcher (*.bat) must be stored with CRLF line
# endings in the git blob itself.
#
# `.gitattributes` marks *.bat as `-text`. Under `-text`, `git add` stores a
# .bat file's CRLF bytes unchanged in the blob, and `.gitattributes` gives a
# command that shows it.
#
# `git cat-file -p :<file>` reads the stored blob from the index. Runs offline,
# no network, no dependencies.
#
set -uo pipefail
# Count bytes, not characters: in a UTF-8 locale, BSD grep skips a line that
# holds a non-UTF-8 byte and BSD tr stops at one.
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
cd "$REPO" || { echo "FAIL: cannot cd to repo root"; exit 1; }
fails=0

# Prints why the bytes that the command "$@" writes are not CRLF-only, or
# nothing when they are. CRLF-only means that the bytes hold at least one LF,
# every LF has a CR before it, and every CR has an LF after it. Text after the
# last LF is checked only for CR bytes, so `a\r\nb` passes.
not_crlf() {
    local n_lf n_crlf n_cr n
    if ! "$@" >/dev/null 2>&1; then
        echo "cannot be read"; return
    fi
    # LF bytes, lines that end in CR, and CR bytes. The appended x keeps a
    # final CR with no LF after it from counting as a line that ends in CR.
    n_lf="$("$@" | wc -l | tr -d ' ')"
    n_crlf="$({ "$@"; printf x; } | grep -c $'\r$' || true)"
    n_cr="$("$@" | tr -cd '\r' | wc -c | tr -d ' ')"
    for n in "$n_lf" "$n_crlf" "$n_cr"; do
        case "$n" in
            '' | *[!0-9]*) echo "gave unreadable counts '$n_lf' '$n_crlf' '$n_cr'"; return ;;
        esac
    done
    if [ "$n_lf" -eq 0 ]; then
        echo "has no line breaks at all"
    elif [ "$n_crlf" -ne "$n_lf" ]; then
        echo "has $((n_lf - n_crlf)) LF-only line(s) of $n_lf"
    elif [ "$n_cr" -ne "$n_lf" ]; then
        echo "has $((n_cr - n_lf)) CR byte(s) with no LF after"
    fi
}

# Built-in check of not_crlf: two shapes that it must fail, then one that it
# must pass. Each case is "<bad|good> <bytes as printf %b escapes>".
for c in 'bad a\r\nb\nc\r' 'bad a\r\nb\r' 'good a\r\nb\r\n'; do
    want="${c%% *}"
    bytes="${c#* }"
    why="$(not_crlf printf '%b' "$bytes")"
    if { [ "$want" = bad ] && [ -z "$why" ]; } || { [ "$want" = good ] && [ -n "$why" ]; }; then
        printf '%s\n' "FAIL: built-in check: not_crlf judges '$bytes' wrongly (${why:-no reason given})"
        exit 1
    fi
done

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
    why="$(not_crlf git cat-file -p ":$f")"
    if [ -n "$why" ]; then
        echo "FAIL: $f — blob $why; expected all CRLF"; fails=$((fails + 1)); continue
    fi
    echo "ok: $f — every line break in the blob is CRLF"
done

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails launcher(s) not CRLF in blob"; exit 1
fi
echo "PASS: all *.bat launchers stored with CRLF"
