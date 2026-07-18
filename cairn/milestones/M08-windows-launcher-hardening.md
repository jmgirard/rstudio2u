<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M08: Windows launcher hardening

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** GP3   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Branch/PR:** m08-windows-launcher-hardening · https://github.com/jmgirard/rstudio2u/pull/9   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

Make the least-tested launcher path — Windows — deliver reliably from the
README-recommended ZIP download and diagnose its own failures clearly, and put
it under a real Windows CI test so regressions are caught (GP3; Known issue:
"the Windows launcher path sees the least real-world testing").

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:**
- Guarantee CRLF line endings in the *stored* `.bat` blobs so every delivery
  channel — the ZIP download README step 2 recommends, `git clone`, raw
  download — hands `cmd.exe` a parseable file (`.gitattributes` `*.bat -text`
  + committed CRLF bytes).
- Rework `start_windows.bat` failure diagnostics to distinguish, each with its
  own actionable message and a non-zero exit: Docker Desktop **not installed**
  vs **not running**; a `docker compose pull` failure vs a health-check
  timeout (with a port-in-use `RS_PORT` hint on the timeout path); plus a
  manual-URL fallback when the browser can't open.
- Add a **non-interactive test seam** to `start_windows.bat` (an env var that
  suppresses `pause`/`timeout`/browser-open) so CI can drive every branch.
- A new `windows-latest` CI workflow that runs `start_windows.bat` against a
  `docker` stub across the failure/success matrix, asserting message + exit
  code, and runs the cross-platform line-ending guard.
- Port the two genuinely-shared diagnostics (not-installed vs not-running;
  pull-failure messaging) to `start_mac.command` and `start_linux.sh` where
  it is a one-line change, and sync the README troubleshooting wording.

**Out:**
- A full three-launcher rework or new mac/linux CI test lanes → not planned;
  add a `candidate` row later if wanted (this milestone is Windows-focused per
  the plan gate).
- Pre-merge arm64 emulated smoke → separate candidate (from M05).
- Any change to the frozen runtime interface (IP3: port/user/volume/env/init)
  or the localhost-only bind (IP2) — untouched by design.
- Major `stop_windows.bat` rework → only the shared-diagnostic parity touches
  it; it is already minimal.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets -->

- [x] AC1 — The stored git blob for every root `.bat` file contains CRLF
      (`\r\n`) line endings, so a `git archive`/ZIP export delivers CRLF
      (evidence: `git cat-file -p :start_windows.bat | …` and a `git archive`
      extract both show `\r\n`).
- [x] AC2 — `start_windows.bat` distinguishes Docker **not installed** from
      Docker **not running**, each printing its own actionable message and
      exiting non-zero (evidence: the two windows-latest CI scenarios assert
      the distinct messages + exit code 1).
- [x] AC3 — `start_windows.bat` distinguishes a `docker compose pull` failure
      from a health-check timeout, each with its own message and non-zero exit,
      and the timeout path surfaces the `RS_PORT` port-in-use hint (evidence:
      the pull-fail and up-timeout windows-latest CI scenarios).
- [x] AC4 — `start_windows.bat` prints a manual-URL fallback when the browser
      cannot open, and honors a documented non-interactive env seam so the
      happy path runs to a success message and exits 0 without blocking on
      input (evidence: the success-path windows-latest CI scenario exits 0
      unattended; the fallback message is asserted).
- [x] AC5 — A cross-platform guard test fails when any `.bat` blob is LF-only
      (evidence: guard passes on the fixed blobs; mutation — rewrite a blob to
      LF — makes it fail).
- [x] AC6 — `start_mac.command` and `start_linux.sh` gain the not-installed vs
      not-running distinction and the pull-failure message, keeping the three
      launchers' diagnostics consistent (evidence: their content shows the
      distinct branches; README troubleshooting wording matches).
- [x] AC7 — Profile `verify` is satisfied: the new `windows-launcher` workflow
      is green and the existing `pr-ci.yml` build+smoke lane is unaffected (no
      Dockerfile/build-context change, so `hadolint`/`docker build` are not
      re-triggered by this milestone).

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2
- AC2 → T3, T4, T5
- AC3 → T3, T4
- AC4 → T3, T4
- AC5 → T1, T2
- AC6 → T5, T6
- AC7 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate -->

- [x] T1 — Write the cross-platform line-ending guard
      `scripts/tests/test_launcher_line_endings.sh`: fail if the stored blob of
      any root `.bat` (`git cat-file -p :<file>`) lacks CRLF. Tests-first — it
      fails against today's LF blobs.
- [x] T2 — Fix delivery: set `*.bat -text` in `.gitattributes` (drop
      `eol=crlf`, which only smudges on clone) and re-commit
      `start_windows.bat`/`stop_windows.bat` with CRLF bytes so the blob itself
      carries CRLF; T1 then passes.
- [x] T3 — Rework `start_windows.bat`: (a) `where docker` → not-installed
      message; else `docker info` → not-running message; (b) check `docker
      compose pull` result → distinct pull-failure message; (c) on
      `up --wait` failure, health-timeout message + `RS_PORT` port-in-use hint;
      (d) manual-URL fallback if `start` fails; (e) a non-interactive env seam
      (e.g. `RS_LAUNCHER_NONINTERACTIVE`) suppressing `pause`/`timeout`/browser
      so CI can run it. Every failure branch keeps `exit /b 1`.
- [x] T4 — Add `.github/workflows/windows-launcher.yml` (runs-on
      `windows-latest`, own `paths` filter on the `.bat` files + `.gitattributes`
      + the workflow, so the heavy image build in `pr-ci.yml` is not dragged in):
      run `start_windows.bat` under a PATH-shadowing `docker` stub across
      scenarios {not-installed, not-running, pull-fail, up-timeout, success},
      asserting message + exit code; also run the T1 guard (via `shell: bash`).
- [x] T5 — Port the not-installed vs not-running distinction and the
      pull-failure message to `start_mac.command` and `start_linux.sh` (one-line
      echoes; no new CI lane).
- [x] T6 — Sync README troubleshooting (around line 175, "the launcher says
      Docker isn't running") to the new clearer messages, including the
      not-installed guidance.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates -->

- 2026-07-18 (review): independent 3-lens review — 1 finding (score 90) fixed:
  start_linux.sh error branches (pull-failure + timeout) lacked the interactive
  pause; added it. Success-banner RS_PORT mismatch → candidate. cairn_validate +
  consistency-gate green; CHANGELOG entry added.
- 2026-07-18 (review→in-progress): PR #9 windows-latest lane RED — test-harness
  bugs, not launcher defects: (1) `.cmd` docker stub chains without returning
  (bare `docker` → .cmd is a goto in batch; production docker.exe returns fine),
  (2) inherited-env PATH override leaked real docker in. Fix in T4 harness only.
- 2026-07-18 (T6): synced README FAQ — not-installed/not-running split, download-failure entry, RS_PORT-on-timeout hint; wording matches launcher.
- 2026-07-18 (T5): ported not-installed/not-running + pull-failure diagnostics to start_mac.command + start_linux.sh; `bash -n` clean, docker-stub PATH drive of start_linux.sh exercises all four branches (right message + exit code).
- 2026-07-18 (T4): added .github/workflows/windows-launcher.yml + run_launcher_scenarios.ps1 (windows-latest, stub docker on PATH, 5 scenarios) + ubuntu CRLF guard job; own paths filter keeps pr-ci build out; YAML valid, 7 assertions match launcher — real windows run happens on the PR.
- 2026-07-18 (T3): reworked start_windows.bat — not-installed vs not-running, pull-failure vs health-timeout (RS_PORT hint), `RS_LAUNCHER_NONINTERACTIVE` seam, `if errorlevel 1` form. Refinement: `start` gives no reliable rc so the manual URL is always in the success banner (superset). Behavioral check = T4 CI.
- 2026-07-18 (T2): `.gitattributes` `*.bat/.cmd -text` + re-committed .bat with CRLF; blob `i/crlf`, `git archive` delivers CRLF (AC1), guard green.
- 2026-07-18 (T1): added scripts/tests/test_launcher_line_endings.sh (asserts each .bat blob is CRLF via `git cat-file`; fails pre-fix; portable, no mapfile — M03).
- 2026-07-18: created by /milestone-plan; promotes the Windows-launcher-hardening candidate. Gate: CRLF-in-blob (`-text`); windows-latest CI + EOL guard; Windows-focused with mac/linux parity.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md -->

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55):
     only the plan-owned body above counts; evidence never scrambles it. -->

PR #9. Fresh evidence gathered 2026-07-18.

### Acceptance-criteria evidence

- AC1 (ZIP delivers CRLF): `git archive HEAD -- <bat> | tar -xO` →
  start_windows.bat 85 CRLF / 0 bare-LF lines; stop_windows.bat 12 / 0. The
  README-recommended ZIP path ships CRLF.
- AC2 (not-installed vs not-running): windows-latest lane (run 88082391375) —
  `docker-not-installed` exit 1 + "does not appear to be installed";
  `docker-not-running` exit 1 + "installed but not running".
- AC3 (pull-fail vs timeout): same lane — `pull-failure` exit 1 + "Could not
  download the latest image"; `health-timeout` exit 1 + "did not become ready
  in time" + "RS_PORT" hint.
- AC4 (browser fallback + non-interactive seam): same lane — `success` exit 0
  unattended (RS_LAUNCHER_NONINTERACTIVE) with "RStudio Server is running" and
  "go to that address manually" in output.
- AC5 (guard fails on LF blob): guard green on CRLF blobs; mutation (LF blob
  staged in a throwaway index) → guard exit 1, "85 LF-only line(s)". Rule locked.
- AC6 (mac/linux parity): `bash -n` clean; docker-stub PATH drive of
  start_linux.sh — not-installed/not-running/pull-fail/success each give the
  right message + exit code; start_mac.command shares the identical structure.
- AC7 (profile verify): windows-launcher lane green (line-endings +
  launcher-scenarios); pr-ci `build-smoke` green (docker build + hadolint), so
  the image build is unaffected.

### Consistency gate

- `cairn_validate`: all checks pass.
- docker-image consistency-gate: `docker build` + `hadolint` green via pr-ci
  build-smoke; base image pin, secrets, `.dockerignore` unchanged (no
  Dockerfile/build-context change — `.bat`/launchers are `.dockerignore`d);
  CHANGELOG.md gained an Unreleased entry for the user-visible launcher changes.
- No DESIGN principle changed (works under GP3) → `cairn_impact` skipped.

### Round-trips

- 1× review→in-progress→review: windows-latest lane caught two test-harness
  bugs (`.cmd` stub chaining without `call`; real docker.exe reachable via
  System32). Launcher unchanged; harness fixed (exe stub + in-shell PATH +
  docker-free tool dir). All 5 scenarios now green.

### Independent review

Three fresh-context lenses (diff-bug [O], blame-history [S], prior-PR [S]) +
scorer [S].

- **Finding 1 (score 90 → fixed):** start_linux.sh's new pull-failure branch —
  and its pre-existing up-timeout branch — omitted the `read -n 1 -s -r -p
  "Press any key to close..."` pause that the file's other error branches and
  start_mac.command's pull-failure branch have; a double-clicked terminal would
  close before the student reads the error. Fixed: added the pause to both
  error branches; re-drove all five branches (right message + exit code, no
  hang). Corroborated by the blame-history lens.
- **Prior-PR lens:** no prior-PR evidence — the launcher/attrs/test files trace
  to pre-cairn un-reviewed commits; no merged PR touched them. Clean no-op.
- **Observation (out of scope → candidate):** all three launchers' success
  banner + browser-open hardcode `localhost:8787` even when `RS_PORT` is set;
  M08 newly advertises `RS_PORT` on the Windows timeout path, making the
  mismatch more reachable. Pre-existing, not introduced by this diff → filed as
  a ROADMAP candidate, not fixed here.
- No findings scored below 80 (nothing excluded-but-logged).
