#!/usr/bin/env bash
#
# Compare one image's compressed size with its limit in
# .github/image-size-limits. The pull request lane (pr-ci.yml) calls this on the
# noble and resolute amd64 images it builds, and .github/image-size-report.sh
# calls it on the four published images. The rule lives here, so scripts/tests/test_image_size.sh can
# test it offline.
#
# Usage: .github/image-size.sh <variant> <arch> <manifest-file>
#        .github/image-size.sh --from-oci <variant> <arch> <oci-archive>
#   manifest-file  an image manifest as JSON.
#   oci-archive    the tar file of a `--output type=oci,dest=<file>` build. Its
#                  index.json must name one manifest for <arch>.
#
# The size is the sum of the manifest's layers[].size, which is what a student
# downloads. A limit is in decimal MB (1,000,000 bytes). A size equal to the
# limit is within it. Sizes print rounded up to 0.1 MB, so a size over a limit
# never prints as equal to it.
#
# stdout is one line, which the report script reads as the answer. Exit status:
#   0  within the limit
#   1  over the limit
#   2  unreadable: the input, or the limit, cannot be read. An empty or missing
#      layers list is unreadable, never a size of 0.
# --from-oci adds a ::error:: line when the size is over the limit, saying how a
# pull request raises the limit.
#
# One environment variable exists for the tests, and the workflows do not set
# it: IMAGE_SIZE_LIMITS, a limits file to read in place of the committed one.
#
set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
limits_file="${IMAGE_SIZE_LIMITS-$HERE/image-size-limits}"

from_oci=0
if [ "${1:-}" = "--from-oci" ]; then
    from_oci=1
    shift
fi
if [ $# -ne 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "usage: $0 [--from-oci] <variant> <arch> <manifest-file-or-oci-archive>" >&2
    exit 2
fi
variant="$1"; arch="$2"; manifest="$3"

unread() {
    echo "$variant $arch: unread ($1)"
    if [ "$from_oci" -eq 1 ]; then
        echo "::error::$variant $arch: the size was not read ($1)"
    fi
    exit 2
}

command -v jq >/dev/null || unread "jq is not installed"

if [ "$from_oci" -eq 1 ]; then
    archive="$manifest"
    manifest="$(mktemp)"
    trap 'rm -f "$manifest"' EXIT
    index="$(tar -xOf "$archive" index.json 2>/dev/null)" \
        || unread "cannot read index.json from $archive"
    digest="$(jq -r --arg a "$arch" \
        '[.manifests[]? | select(.platform.architecture == $a)] | if length == 1 then .[0].digest else empty end' \
        <<< "$index" 2>/dev/null)"
    [[ $digest =~ ^sha256:[0-9a-f]{64}$ ]] \
        || unread "$archive has no single $arch manifest"
    tar -xOf "$archive" "blobs/sha256/${digest#sha256:}" > "$manifest" 2>/dev/null \
        || unread "cannot read the $arch manifest from $archive"
fi

[ -r "$limits_file" ] || unread "cannot read $limits_file"
limit="$(awk -v v="$variant" '$1 == v { print $2; n++ } END { exit (n == 1 ? 0 : 1) }' "$limits_file")" \
    || unread "no single limit for $variant in $limits_file"
[[ $limit =~ ^[1-9][0-9]{0,6}$ ]] \
    || unread "the limit for $variant in $limits_file is not a whole number of MB"

[ -r "$manifest" ] || unread "cannot read $manifest"
# -s reads the whole file before any output, so anything beside one JSON document
# is unreadable, not a size taken from the valid part.
size="$(jq -rs '
    if length == 1 and (.[0].layers | type) == "array" and (.[0].layers | length) > 0
       and all(.[0].layers[]; (.size | type) == "number" and .size >= 0 and (.size | floor) == .size)
    then [.[0].layers[].size] | add
    else empty
    end' "$manifest" 2>/dev/null)"
# The width bound keeps the sum inside bash arithmetic. No real image is near it.
[[ $size =~ ^[1-9][0-9]{0,14}$ ]] || unread "the manifest holds no layer sizes"

tenths=$(( (size + 99999) / 100000 ))
shown="$(( tenths / 10 )).$(( tenths % 10 ))"

if (( size > limit * 1000000 )); then
    echo "$variant $arch: $shown MB, over the $limit MB limit"
    if [ "$from_oci" -eq 1 ]; then
        echo "::error::$variant $arch is $shown MB, over its $limit MB limit. If this growth is wanted, raise the limit in .github/image-size-limits in this pull request and state the reason there."
    fi
    exit 1
fi
echo "$variant $arch: $shown MB, limit $limit MB"
