#!/bin/bash

## Remove files that RStudio Server and its libclang-dev dependency install but
## that RStudio does not need to run. Run this in the same RUN instruction that
## installs them: a removal in a later instruction hides the files and leaves them
## in the download.
##
## - Copilot's copies for other platforms. Its language server loads
##   copilot-sdk-${process.platform}-${process.arch} and no other.
## - The static archives of libclang-dev and RStudio's libgit2. RStudio loads
##   libclang's shared library, and the rstudio-server package depends on
##   libclang-dev, so the package stays and only these files go.
## - RStudio's JavaScript debug symbol maps.
##
## SLIM_ROOT replaces / for scripts/tests/test_slim_rstudio.sh.

set -e

ROOT="${SLIM_ROOT:-}"
ARCH=$(dpkg --print-architecture)

case "$ARCH" in
    amd64) KEEP=copilot-sdk-linux-x64 ;;
    arm64) KEEP=copilot-sdk-linux-arm64 ;;
    *)
        echo "slim_rstudio.sh: no Copilot folder is known for architecture '$ARCH'" >&2
        exit 1
        ;;
esac

SDK="$ROOT/usr/lib/rstudio-server/bin/copilot-language-server-js/node_modules/@github"

# Without the folder for this image, the layout is not the one this script knows,
# so nothing is removed here. .github/smoke-test.sh reports that case.
if [ -d "$SDK/$KEEP" ]; then
    for dir in "$SDK"/copilot-sdk-*; do
        case "${dir##*/}" in
            "$KEEP") ;;
            copilot-sdk-darwin-* | copilot-sdk-win32-* | copilot-sdk-linux-*) rm -rf "$dir" ;;
        esac
    done
else
    echo "slim_rstudio.sh: $KEEP not found; removing no Copilot folder"
fi

rm -f "$ROOT"/usr/lib/llvm-*/lib/*.a
rm -f "$ROOT/usr/lib/rstudio-server/lib/libgit2.a"
rm -rf "$ROOT/usr/lib/rstudio-server/www-symbolmaps"
