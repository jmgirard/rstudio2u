<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M09: Launcher port consistency

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** IP2, GP1, GP3
- **Branch/PR:** m09-launcher-port-consistency

## Goal

Make the host port one consistent, reachable, validated setting across all
three launchers — announced from what Compose actually bound, not a hardcoded
8787.

## Scope

**In:** All three launchers announce and open the port Compose actually bound,
obtained from `docker compose port rstudio2u 8787` after a healthy start rather
than recomputed from the raw variable. A pre-flight check reads `RS_PORT` (env,
else `.env`) and rejects a non-numeric or out-of-range value with a plain
message before Compose runs — which also keeps a value like `0.0.0.0:8888` from
being interpolated into the `127.0.0.1:${RS_PORT}:8787` binding (IP2). A `.env`
file becomes the documented override for double-click users, who have no shell
in which to set an env var (GP1). `start_mac.command` and `start_linux.sh` gain
the `RS_LAUNCHER_NONINTERACTIVE` seam and a bash scenario harness mirroring
M08's PowerShell one, so all three launchers run every branch under CI (GP3),
including the timeout-hint and manual-URL parity M08 left Windows-only.

**Out:** Verifying the resolved port against a *real* Compose (both harnesses
stub `docker`) → candidate row, best folded into the existing container smoke
lane. A macOS runner executing `start_mac.command` on real macOS → candidate
row. Changing the in-container port, the `127.0.0.1` bind, or any other part of
the frozen runtime interface (IP3) → not planned. Shipping a `.env.example`
→ deliberately not done; the README teaches creating the file, one less
artifact for a student to misread (GP1).

## Acceptance criteria

- [ ] Default unchanged: with no `RS_PORT` and no `.env`, all three launchers
      announce and open `http://localhost:8787`.
- [ ] Env var honored: with `RS_PORT=8888`, all three announce and open
      `http://localhost:8888`.
- [ ] `.env` honored and precedence correct: `RS_PORT=8888` in `.env` with no
      env var yields 8888 on all three; with env `RS_PORT=8899` also set, 8899
      wins (matching Compose's own precedence).
- [ ] Invalid `RS_PORT` (non-numeric, `0`, `70000`, `0.0.0.0:8888`) is rejected
      on all three before Compose is invoked, exit 1, with a message naming the
      offending value and the valid 1–65535 range.
- [ ] The announced URL is derived from `docker compose port rstudio2u 8787`,
      not from the raw variable — asserted by a scenario where the stub reports
      a port differing from the requested one.
- [ ] Parity: the health-timeout message on all three names the port override
      including `.env`; mac and Linux carry the "if your browser does not open"
      manual-URL line Windows already had.
- [ ] CI runs every branch of all three launchers on a launcher-touching PR
      (both harnesses green); README documents the `.env` override in the
      launcher section and the rewritten port FAQ; CHANGELOG entry present.
- [ ] Profile `verify` slot clean: `hadolint Dockerfile` clean and
      `docker build` succeeds (unaffected by this milestone, confirmed not
      broken).

## Coverage

- AC1 → T2, T4, T6, T7
- AC2 → T4, T6, T7
- AC3 → T3, T4, T6, T7
- AC4 → T3, T6, T7
- AC5 → T4, T6, T7
- AC6 → T5, T6, T7
- AC7 → T8, T9
- AC8 → T9

## Tasks

- [x] T1: Add the `RS_LAUNCHER_NONINTERACTIVE` seam to
      [start_mac.command](start_mac.command) and
      [start_linux.sh](start_linux.sh) — suppress the `read` pauses and the
      `open`/`xdg-open` call, mirroring
      [start_windows.bat:71](start_windows.bat:71).
- [x] T2: Write `scripts/tests/posix/run_launcher_scenarios.sh` — stub `docker`
      on PATH, drive both POSIX launchers through the existing five branches
      (not-installed, not-running, pull-failure, health-timeout, success).
      Green against current behavior before any port change lands.
- [x] T3: Add the pre-flight `RS_PORT` read (env, else `.env`) and 1–65535
      numeric validation to all three launchers; portable bash `[[ =~ ]]`, no
      `grep -P` (M03 lesson).
- [x] T4: Replace the hardcoded banner/browser-open URLs
      ([start_mac.command:46,50](start_mac.command:46),
      [start_linux.sh:40,44](start_linux.sh:40),
      [start_windows.bat:64,74](start_windows.bat:64)) with the port reported
      by `docker compose port rstudio2u 8787`; fall back to the validated value
      if the query fails.
- [x] T5: Parity sweep — timeout message names `RS_PORT` and `.env` on all
      three ([start_windows.bat:53](start_windows.bat:53) is the model); add
      the manual-URL line to mac and Linux.
- [x] T6: Extend the POSIX harness with the port scenarios (default, env var,
      `.env`, env-beats-`.env`, invalid values, compose-reports-different).
- [x] T7: Extend
      [run_launcher_scenarios.ps1](scripts/tests/windows/run_launcher_scenarios.ps1)
      with the same port scenarios; teach the `docker.exe` stub `compose port`.
- [x] T8: CI — add the POSIX job to
      [.github/workflows/windows-launcher.yml](.github/workflows/windows-launcher.yml),
      widen its paths filter to the POSIX launchers and new harness, rename the
      lane from "Windows launcher" to "Launchers".
- [x] T9: Docs — README `.env` instructions in the launcher section plus the
      rewritten port FAQ ([README.md:186](README.md:186)); CHANGELOG entry;
      `.env` added to `.gitignore` and `.dockerignore`; confirm the profile
      verify slot still clean.

## Work log

- 2026-07-18: created by /milestone-plan. Promoted from the candidate filed by
  M08's review; gate chose env-var + `.env` both, a bash harness on
  ubuntu-latest, and pre-flight validation.
- 2026-07-18: set in-progress; branch m09-launcher-port-consistency cut from
  main.
- 2026-07-18: gate chose a shared launcher_common.sh for the POSIX pair and
  lenient validation (unparseable .env values pass through to Compose).
- 2026-07-18: T1 done — launcher_common.sh created with launcher_interactive /
  launcher_pause; mac + Linux source it; helper added to .dockerignore.
- 2026-07-18: T2 done — scripts/tests/posix/run_launcher_scenarios.sh drives
  both POSIX launchers through all 5 branches; 10/10 green against pre-change
  behavior. Two harness bugs fixed: env -i resolves the interpreter against the
  scrubbed PATH, so bash and the stub's shebang both need absolute paths.
- 2026-07-18: T3+T4 done — launcher_common.sh gained launcher_requested_port /
  launcher_check_port / launcher_bound_port / launcher_url; all three launchers
  validate before Compose runs and announce the port `docker compose port`
  reports. Windows carries its own batch copy.
- 2026-07-18: T5 done — timeout message names RS_PORT and .env on all three;
  mac and Linux gained the manual-URL line.
- 2026-07-18: T6 done — POSIX harness extended to 32 scenarios (sandbox copy so
  tests never write .env into the repo; stub models Compose's own resolution so
  precedence is not asserted circularly). Mutation check: restoring the 8787
  hardcode fails 13 scenarios.
- 2026-07-18: three batch defects caught before commit — `::` comments inside a
  parenthesised block are a cmd.exe parse error (use `rem`), `if defined X call
  :label || (...)` parses ambiguously, and `%%~B` strips .env quotes without a
  fragile substitution. CRLF blob guard re-run against the staged blob: 143/143.
- 2026-07-18: T7 done — Windows harness gained the same port scenarios and a
  `compose port`-aware stub; NOT runnable locally (no pwsh/Windows), so CI is
  its first real execution.
- 2026-07-18: T8 done — workflow renamed windows-launcher.yml → launchers.yml
  with a posix-scenarios job; paths widened to start_*/stop_*/launcher_common.sh
  and both harness dirs.
- 2026-07-18: T9 done — README FAQ rewritten around .env, CHANGELOG Fixed+Changed
  entries, .env added to .gitignore and .dockerignore. hadolint clean (exit 0);
  docker build running to confirm the .dockerignore change is safe.
- 2026-07-18: discovered sub-task under T1/T6 — sourcing launcher_common.sh
  introduced a new failure mode (a student copying only the launcher out of the
  folder). Both POSIX launchers now explain it; the pause there honors the seam
  inline, since the helper defining launcher_pause is the missing file. Scenario
  added, 34 total.
- 2026-07-18: noted out-of-scope — Dockerfile:33 copies scripts/tests/ into the
  image (pre-existing, GP5); filed for the image-size candidate, not fixed here.

## Decisions

- 2026-07-18: the announced URL comes from `docker compose port`, not from the
  launcher's own reading of RS_PORT/.env. A launcher-side parser would have to
  agree with Compose's resolution in every case; asking Compose removes that
  whole class of divergence, and reduces the launcher's own parse to a
  best-effort typo check. Milestone-local: it constrains these three files, not
  the repo at large.

## Review
