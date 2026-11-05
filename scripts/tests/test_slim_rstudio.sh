#!/usr/bin/env bash
#
# Unit tests for scripts/slim_rstudio.sh, over a fixture tree (SLIM_ROOT) and a
# stub dpkg. Runs offline, with no Docker.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SLIM="$HERE/../slim_rstudio.sh"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SDK="usr/lib/rstudio-server/bin/copilot-language-server-js/node_modules/@github"

# make_tree <root> <copilot-folder>...
make_tree() {
    local root="$1" d
    shift
    mkdir -p "$root/$SDK/copilot-sdk" \
        "$root/usr/lib/llvm-18/lib" \
        "$root/usr/lib/rstudio-server/lib/pkgconfig" \
        "$root/usr/lib/rstudio-server/www-symbolmaps" \
        "$root/usr/lib/rstudio-server/www"
    for d in "$@"; do
        mkdir -p "$root/$SDK/$d"
        : > "$root/$SDK/$d/runtime.node"
    done
    : > "$root/usr/lib/llvm-18/lib/libclangAST.a"
    : > "$root/usr/lib/llvm-18/lib/libclang-18.so"
    : > "$root/usr/lib/rstudio-server/lib/libgit2.a"
    : > "$root/usr/lib/rstudio-server/lib/pkgconfig/libgit2.pc"
    : > "$root/usr/lib/rstudio-server/www-symbolmaps/app.map"
    : > "$root/usr/lib/rstudio-server/www/index.htm"
}

# run_slim <root> <arch>: runs the script, leaving its output in $out and its
# exit status in $rc.
run_slim() {
    local root="$1" arch="$2"
    mkdir -p "$WORK/bin"
    cat > "$WORK/bin/dpkg" <<EOF
#!/bin/sh
[ "\$1" = "--print-architecture" ] && echo "$arch"
EOF
    chmod +x "$WORK/bin/dpkg"
    out="$(PATH="$WORK/bin:$PATH" SLIM_ROOT="$root" bash "$SLIM" 2>&1)"
    rc=$?
}

fail() {
    echo "FAIL: $1"
    fails=$((fails + 1))
}

# ok <desc>: reports the checks since the last call, when none of them failed.
seen=0
ok() {
    if [ "$fails" -eq "$seen" ]; then
        echo "ok: $1"
    fi
    seen=$fails
}

# folders <root>: the Copilot folders left, on one line.
folders() {
    local d
    for d in "$1/$SDK"/copilot-sdk*; do
        printf '%s ' "${d##*/}"
    done
}

ALL="copilot-sdk-darwin-arm64 copilot-sdk-darwin-x64 copilot-sdk-linux-arm64 copilot-sdk-linux-x64 copilot-sdk-win32-arm64 copilot-sdk-win32-x64"

# shellcheck disable=SC2086  # ALL is a word list on purpose.
check_keep() {
    local arch="$1" want="$2" root="$WORK/keep-$1"
    make_tree "$root" $ALL
    run_slim "$root" "$arch"
    [ "$rc" -eq 0 ] || fail "$arch: exit $rc: $out"
    [ "$(folders "$root")" = "copilot-sdk $want " ] \
        || fail "$arch: expected copilot-sdk and $want, left: $(folders "$root")"
    [ -f "$root/$SDK/$want/runtime.node" ] || fail "$arch: emptied the folder it kept"
    ok "$arch keeps $want"
}
check_keep amd64 copilot-sdk-linux-x64
check_keep arm64 copilot-sdk-linux-arm64

# The other removals, and the files beside them that must stay.
root="$WORK/keep-arm64"
[ ! -e "$root/usr/lib/llvm-18/lib/libclangAST.a" ] || fail "kept an llvm static archive"
[ -e "$root/usr/lib/llvm-18/lib/libclang-18.so" ] || fail "removed libclang's shared library"
[ ! -e "$root/usr/lib/rstudio-server/lib/libgit2.a" ] || fail "kept libgit2.a"
[ -e "$root/usr/lib/rstudio-server/lib/pkgconfig/libgit2.pc" ] || fail "removed a file beside libgit2.a"
[ ! -e "$root/usr/lib/rstudio-server/www-symbolmaps" ] || fail "kept www-symbolmaps"
[ -e "$root/usr/lib/rstudio-server/www/index.htm" ] || fail "removed a file beside www-symbolmaps"
ok "static archives and symbol maps go, shared libraries and www stay"

# An unknown architecture stops the build, names the architecture, and removes
# nothing.
root="$WORK/unknown"
# shellcheck disable=SC2086
make_tree "$root" $ALL
run_slim "$root" riscv64
[ "$rc" -ne 0 ] || fail "riscv64: exit 0, expected a failure"
case "$out" in
    *"architecture"*riscv64*) ;;
    *) fail "riscv64: the message does not name the architecture: $out" ;;
esac
[ "$(folders "$root")" = "copilot-sdk $ALL " ] || fail "riscv64: removed Copilot folders: $(folders "$root")"
[ -e "$root/usr/lib/llvm-18/lib/libclangAST.a" ] || fail "riscv64: removed an llvm static archive"
ok "an unknown architecture stops the build and removes nothing"

# Other architectures' folders, none for this one: an upstream rename must not
# delete every copy.
root="$WORK/no-match"
make_tree "$root" copilot-sdk-darwin-x64 copilot-sdk-win32-x64
run_slim "$root" arm64
[ "$rc" -eq 0 ] || fail "no match: exit $rc: $out"
[ "$(folders "$root")" = "copilot-sdk copilot-sdk-darwin-x64 copilot-sdk-win32-x64 " ] \
    || fail "no match: removed Copilot folders: $(folders "$root")"
[ ! -e "$root/usr/lib/llvm-18/lib/libclangAST.a" ] || fail "no match: skipped the other removals"
ok "no folder for this architecture removes no Copilot folder"

# No platform folders at all.
root="$WORK/none"
make_tree "$root"
run_slim "$root" amd64
[ "$rc" -eq 0 ] || fail "no folders: exit $rc: $out"
[ "$(folders "$root")" = "copilot-sdk " ] || fail "no folders: left: $(folders "$root")"
ok "no platform folders exits 0"

# Nothing to remove at all, such as a release with a different layout.
root="$WORK/empty"
mkdir -p "$root/usr/lib"
run_slim "$root" amd64
[ "$rc" -eq 0 ] || fail "empty tree: exit $rc: $out"
ok "an empty tree exits 0"

if [ "$fails" -ne 0 ]; then
    echo "$fails check(s) failed"
    exit 1
fi
echo "all slim_rstudio.sh checks passed"
