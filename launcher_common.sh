#!/bin/bash
# Shared helpers for the macOS and Linux launchers (start_mac.command,
# start_linux.sh). This file is sourced, never double-clicked, and never enters
# the image build context (see .dockerignore). The Windows launcher carries its
# own copy of this logic -- batch cannot source a shell file.
#
# RS_LAUNCHER_NONINTERACTIVE is a test seam: when set, the launcher runs
# unattended -- no keypress pauses, no browser -- so CI can drive every branch
# without a human or a display. It mirrors the seam start_windows.bat already
# honors.
#
# Parsing here is deliberately pure bash (no grep/sed): these launchers must run
# on a bare macOS and on Linux alike, and bash's own [[ =~ ]] is the portable
# choice (BSD grep has no -P).

# True when the launcher is running for a real user, false under the test seam.
launcher_interactive() {
    [ -z "${RS_LAUNCHER_NONINTERACTIVE:-}" ]
}

# Hold the window open so a double-clicking student can read the message before
# it vanishes. Callers print their own blank line first.
launcher_pause() {
    launcher_interactive || return 0
    read -n 1 -s -r -p "Press any key to close..."
}

# The port the user asked for, resolved the way Compose resolves it: the RS_PORT
# environment variable wins, else a RS_PORT line in .env, else empty (meaning
# "the 8787 default"). Used only for the pre-flight check and as a fallback --
# once the container is up, Compose itself is the authority (launcher_url).
launcher_requested_port() {
    if [ -n "${RS_PORT:-}" ]; then
        printf '%s' "$RS_PORT"
        return 0
    fi
    [ -f .env ] || return 0

    local line value=""
    while IFS= read -r line || [ -n "$line" ]; do
        # Last assignment wins, matching Compose.
        if [[ $line =~ ^[[:space:]]*(export[[:space:]]+)?RS_PORT[[:space:]]*=(.*)$ ]]; then
            value=${BASH_REMATCH[2]}
        fi
    done < .env

    # Trim surrounding whitespace, then one layer of matching quotes.
    value=${value#"${value%%[![:space:]]*}"}
    value=${value%"${value##*[![:space:]]}"}
    if [ ${#value} -ge 2 ]; then
        case $value in
            \"*\") value=${value:1:${#value}-2} ;;
            \'*\') value=${value:1:${#value}-2} ;;
        esac
    fi
    printf '%s' "$value"
}

# Catch a typo before Compose fails on it with a cryptic binding error, and stop
# a value like 0.0.0.0:8888 from being interpolated into the
# 127.0.0.1:${RS_PORT}:8787 mapping, which would publish the port beyond
# localhost while auth is disabled (IP2).
#
# A value we cannot confidently read is passed through untouched: Compose
# supports interpolation syntax this reader does not, and refusing a config that
# would have worked is worse than a late, clearer error.
launcher_check_port() {
    local port=$1
    [ -n "$port" ] || return 0

    case $port in
        *'$'*|*'{'*) return 0 ;;
    esac

    if [[ $port =~ ^[0-9]+$ ]]; then
        local n=$((10#$port))
        if [ "$n" -ge 1 ] && [ "$n" -le 65535 ]; then
            return 0
        fi
    fi

    echo ""
    echo "❌ RS_PORT is set to '$port', which is not a usable port number."
    echo "   Use a whole number between 1 and 65535, for example 8888."
    echo "   Check the RS_PORT line in your .env file, or unset RS_PORT to"
    echo "   use the default port 8787."
    echo ""
    launcher_pause
    return 1
}

# The port Compose actually bound. Asking Compose is what keeps the URL we print
# from ever disagreeing with reality, whatever set the port.
launcher_bound_port() {
    local out port
    out=$(docker compose port rstudio2u 8787 2>/dev/null) || return 1
    port=${out##*:}
    port=${port//[!0-9]/}
    [ -n "$port" ] || return 1
    printf '%s' "$port"
}

# The URL to announce and open: what Compose bound, falling back to the
# requested value, then to the default, if that query fails.
launcher_url() {
    local port
    port=$(launcher_bound_port) || port=""
    [ -n "$port" ] || port=$(launcher_requested_port)
    [[ $port =~ ^[0-9]+$ ]] || port=8787
    printf 'http://localhost:%s' "$port"
}
