#!/bin/bash
set -e

### Sets up the s6-overlay (v3) init system.

S6_VERSION=${1:-${S6_VERSION:-"v3.2.3.2"}}

# Known-good SHA256 checksums for the tarballs of pinned releases. When
# S6_VERSION matches a key here, the download is verified against these
# values; otherwise the checksum published alongside the release is fetched
# and used (still protects against corrupted/partial downloads).
declare -A S6_SHA256=(
    ["v3.2.3.2/s6-overlay-noarch.tar.xz"]="5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12"
    ["v3.2.3.2/s6-overlay-symlinks-noarch.tar.xz"]="a215675c375aca9efecde3065df22b19fb8dcdc1362566931c6b5e778099a0fb"
    ["v3.2.3.2/s6-overlay-x86_64.tar.xz"]="e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408"
    ["v3.2.3.2/s6-overlay-aarch64.tar.xz"]="b17f17a82e7a515c682a91edaf2ffdabb73f891981b6c1fd712115693a2f8b4c"
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
