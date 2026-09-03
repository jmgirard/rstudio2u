# M10: Launcher offline fallback

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP3, IP4
- **Resolves:** —
- **Branch/PR:** m010-launcher-offline-fallback

## Goal

When the image update cannot be downloaded but a copy is already on the
machine, the three launchers start that copy with a warning instead of
refusing to start.

## Scope

Tier: user-facing — the double-click launchers are the classroom surface (GP1).

**In:** a pull-failure fallback in `start_mac.command`, `start_linux.sh`
(via `launcher_common.sh`), and `start_windows.bat`; new scenarios in both
launcher harnesses; README FAQ and CHANGELOG entries.

**Out:** running the launchers against a real Compose (candidate row, from
M09); any change to what `docker compose up` does when the image is absent
(Compose's own pull-on-up is left as is); offline behavior of the `stop_*`
scripts (they never pull).

## Acceptance criteria

- [ ] AC1: When `docker compose pull` fails and every image the Compose file
      references is already present locally, each of the three launchers
      prints a warning that the update was skipped and the downloaded copy is
      being started, then runs `docker compose up` and exits 0 on a healthy
      start — asserted by an `offline-fallback` scenario for each launcher in
      `scripts/tests/posix/run_launcher_scenarios.sh` (the two POSIX
      launchers) and `scripts/tests/windows/run_launcher_scenarios.ps1`.
- [ ] AC2: When `docker compose pull` fails and at least one referenced image
      is absent locally, each of the three launchers exits 1 with the existing
      "Could not download the latest image" message and issues no
      `docker compose up` — asserted by the `pull-failure` scenario in each
      harness.
- [ ] AC3: Every scenario in both harnesses whose stubbed pull succeeds asserts
      the offline warning is absent from the launcher's output.
- [ ] AC4: The README answer to "How do I update to the latest version?"
      states that a launcher started without internet reuses the last
      downloaded image, and `CHANGELOG.md` `## Unreleased` carries a matching
      entry with no milestone number.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T1, T2, T3
- AC3 → T3
- AC4 → T4

## Tasks

- [x] T1: POSIX: add `launcher_images_present` to `launcher_common.sh` — list
      images with `docker compose config --images`, `docker image inspect`
      each; any failure (including an unsupported flag) returns non-zero so
      the existing hard error stays the fallback. Rework the pull block in
      `start_linux.sh:46` and `start_mac.command:52`: on pull failure call it;
      present → print the warning and fall through to `compose up`; absent →
      existing message, exit 1.
- [x] T2: Windows: same logic in `start_windows.bat:73` (batch `for /f` over
      `docker compose config --images`, `docker image inspect` per line; M09
      lesson: trim both ends of each token).
- [x] T3: Harnesses: extend both stubs with `STUB_IMAGE_ABSENT=1` for
      `image inspect` and a fixed one-line `compose config --images`; add the
      `offline-fallback` scenario (pull fails, image present, exit 0, warning
      text, `up` observed) per launcher; set the image absent in the existing
      `pull-failure` scenarios and assert `up` never ran; add the
      warning-absent assertion to every pull-success scenario. Mutate the
      launcher (skip the inspect) once to confirm the new scenario goes red
      (M09 lesson: the stub must not decide the outcome the code is tested for).
- [ ] T4: README FAQ ([README.md:203](../../README.md)) and CHANGELOG
      `## Unreleased` → `### Changed`.

## Work log

- 2026-09-03: created by /milestone-plan.
- 2026-09-03: criteria audit ran in full mode ([O] fresh reader); returned: AC1 named a Compose flag rather than behavior, AC2 and AC3 stated harness properties, AC3 quantified over all successful runs while enumerating only pre-existing scenarios — all three fixed at the gate as written above.
- 2026-09-03: plan gate chose "check image presence, then fall through to `compose up`" over "on pull failure just attempt `compose up`" because an absent image would then surface as a misleading "did not become ready" timeout; falsified by evidence that Compose reports a missing image distinctly before the health wait.
- 2026-09-03: plan gate chose "ask Compose for the image list (`config --images`)" over "hardcode `jmgirard/rstudio2u:latest`" because the M09 lesson is that Compose is the authority over every override mechanism; falsified by a supported student Docker Desktop whose Compose lacks the flag.
- 2026-09-03: /milestone-implement started; branch m010-launcher-offline-fallback cut from pushed main; question gate skipped (no open choices beyond wording).
- 2026-09-03: T1 done — `launcher_images_present` + `launcher_warn_offline` in launcher_common.sh; both POSIX launchers fall through to `compose up` on pull failure when images are present; POSIX harness gained a stub call log, `offline-fallback` and `offline-config-unsupported` scenarios, `up`-never-ran assertion on `pull-failure`, and a warning-absent check on every pull-success run; mutation (inspect skipped) turned `pull-failure` red on both launchers.
- 2026-09-03: T2 done — start_windows.bat gains `:images_present` (`for /f` over `docker compose config --images`, `docker image inspect` each, both-ends trim) and the same fall-through; PowerShell harness mirrors T1 (stub call log, `offline-fallback`, `offline-config-unsupported`, `up`-never-ran on `pull-failure`, warning-absent on pull-success); CRLF blob verified; runs only in CI (windows-latest).
- 2026-09-03: T3 done — harness work landed with T1/T2; Windows mutation (inspect result ignored) pushed as a temporary commit on draft PR #17: CI run 33813231700 turned only `pull-failure` red ("compose up was called", exit 0 not 1) with all 25 other scenarios green; mutation reverted (git revert, kept in branch history).

## Decisions

## Review
