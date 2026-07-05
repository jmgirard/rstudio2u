#!/bin/bash
set -e

### Sets up the s6-overlay (v3) init system.

S6_VERSION=${1:-${S6_VERSION:-"v3.2.3.0"}}

# Known-good SHA256 checksums for the tarballs of pinned releases. When
# S6_VERSION matches a key here, the download is verified against these
# values; otherwise the checksum published alongside the release is fetched
# and used (still protects against corrupted/partial downloads).
declare -A S6_SHA256=(
    ["v3.2.3.0/s6-overlay-noarch.tar.xz"]="b720f9d9340efc8bb07528b9743813c836e4b02f8693d90241f047998b4c53cf"
    ["v3.2.3.0/s6-overlay-symlinks-noarch.tar.xz"]="a60dc5235de3ecbcf874b9c1f18d73263ab99b289b9329aa950e8729c4789f0e"
    ["v3.2.3.0/s6-overlay-x86_64.tar.xz"]="a93f02882c6ed46b21e7adb5c0add86154f01236c93cd82c7d682722e8840563"
    ["v3.2.3.0/s6-overlay-aarch64.tar.xz"]="0952056ff913482163cc30e35b2e944b507ba1025d78f5becbb89367bf344581"
)

# a function to install apt packages only if they are not installed
function apt_install() {
    if ! dpkg -s "$@" >/dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt-get update
        fi
        apt-get install -y --no-install-recommends "$@"
    fi
}

# s6-overlay uses gcc-style arch names, not dpkg's
ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    amd64) S6_ARCH="x86_64" ;;
    arm64) S6_ARCH="aarch64" ;;
    *) S6_ARCH="$ARCH" ;;
esac

apt_install wget ca-certificates xz-utils

# Download, verify, and extract one s6-overlay tarball into /
install_tarball() {
    local file="$1"
    local url="https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/${file}"
    wget -P /tmp/ "$url"

    local expected="${S6_SHA256["${S6_VERSION}/${file}"]}"
    if [ -z "$expected" ]; then
        echo "No pinned checksum for ${S6_VERSION}/${file}; fetching upstream .sha256"
        wget -P /tmp/ "${url}.sha256"
        expected="$(cut -d' ' -f1 "/tmp/${file}.sha256")"
    fi
    echo "${expected}  /tmp/${file}" | sha256sum -c -

    tar -C / -Jxpf "/tmp/${file}"
    rm -f "/tmp/${file}" "/tmp/${file}.sha256"
}

## Set up s6-overlay
if [ -f "/rocker_scripts/.s6_version" ] && [ "$S6_VERSION" = "$(cat /rocker_scripts/.s6_version)" ]; then
    echo "S6 already installed"
else
    install_tarball "s6-overlay-noarch.tar.xz"
    install_tarball "s6-overlay-${S6_ARCH}.tar.xz"
    # symlinks so the #!/usr/bin/with-contenv shebang keeps working
    install_tarball "s6-overlay-symlinks-noarch.tar.xz"

    echo "$S6_VERSION" >/rocker_scripts/.s6_version
fi

# Clean up
rm -rf /var/lib/apt/lists/*
