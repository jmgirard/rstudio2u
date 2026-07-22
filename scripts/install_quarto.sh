#!/bin/bash

## Install quarto cli or symlink quarto cli so they are available system-wide.
##
## In order of preference, first argument of the script, the QUARTO_VERSION variable.
## ex. latest, default, 0.9.16
##
## 'default' means the version bundled with RStudio if RStudio is installed, but 'latest' otherwise.
## 'latest', 'release' means installing the latest release version.
## 'prerelease' means installing the latest prerelease version.

set -e

## build ARGs
NCPUS=${NCPUS:--1}

QUARTO_VERSION=${1:-${QUARTO_VERSION:-"default"}}
# Detected target arch (amd64/arm64). Every install path below resolves the
# arch-matched .deb (or symlinks the arch-native RStudio-bundled quarto), so
# arm64 installs natively — Quarto has published linux-arm64 since 1.9.38.
ARCH=$(dpkg --print-architecture)

# Every `quarto …` invocation below runs Quarto's bundled Deno (V8), which
# intermittently aborts with SIGILL (exit 132) under QEMU aarch64 emulation
# during the arm64 image build — a re-run of the identical command succeeds. So
# each Deno-invoking call is wrapped in retry.sh; a genuinely broken quarto
# still fails every attempt and aborts the build.

# a function to install apt packages only if they are not installed
function apt_install() {
    if ! dpkg -s "$@" >/dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt-get update
        fi
        apt-get install -y --no-install-recommends "$@"
    fi
}

apt_install wget ca-certificates

if [ -x "$(command -v quarto)" ]; then
    INSTALLED_QUARTO_VERSION=$(/rocker_scripts/retry.sh 5 quarto --version)
fi

# Check RStudio bundled quarto cli
if [ -f "/usr/lib/rstudio-server/bin/quarto/bin/quarto" ]; then
    BUNDLED_QUARTO="/usr/lib/rstudio-server/bin/quarto/bin/quarto"
fi

if [ -n "$BUNDLED_QUARTO" ]; then
    BUNDLED_QUARTO_VERSION="$(/rocker_scripts/retry.sh 5 "$BUNDLED_QUARTO" --version)"
fi

# Install quarto cli
if [ "$QUARTO_VERSION" != "$INSTALLED_QUARTO_VERSION" ]; then

    # Check RStudio bundled quarto cli
    if [ "$QUARTO_VERSION" = "default" ] && [ -z "$BUNDLED_QUARTO" ]; then
        QUARTO_VERSION="latest"
    fi

    if [ "$QUARTO_VERSION" = "$BUNDLED_QUARTO_VERSION" ] || [ "$QUARTO_VERSION" = "default" ]; then
        ln -fs "$BUNDLED_QUARTO" /usr/local/bin
    else
        if [ "$QUARTO_VERSION" = "latest" ] || [ "$QUARTO_VERSION" = "release" ]; then
            # Resolve + validate the release .deb URL; a format-changed or
            # arch-missing scrape fails loudly here instead of feeding wget an
            # empty/wrong URL (see resolve-download-url.sh).
            QUARTO_DL_URL=$(/rocker_scripts/resolve-download-url.sh https://quarto.org/docs/download/_download.json download_url "${ARCH}")
        elif [ "$QUARTO_VERSION" = "prerelease" ]; then
            QUARTO_DL_URL=$(/rocker_scripts/resolve-download-url.sh https://quarto.org/docs/download/_prerelease.json download_url "${ARCH}")
        else
            QUARTO_DL_URL="https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${ARCH}.deb"
        fi
        wget "$QUARTO_DL_URL" -O quarto.deb
        dpkg -i quarto.deb
        rm quarto.deb
    fi

    /rocker_scripts/retry.sh 5 quarto check install

fi

# Clean up
rm -rf /var/lib/apt/lists/*
