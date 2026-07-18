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
