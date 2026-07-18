<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M08: Windows launcher hardening

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** GP3   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create -->

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

- [ ] AC1 — The stored git blob for every root `.bat` file contains CRLF
      (`\r\n`) line endings, so a `git archive`/ZIP export delivers CRLF
      (evidence: `git cat-file -p :start_windows.bat | …` and a `git archive`
      extract both show `\r\n`).
- [ ] AC2 — `start_windows.bat` distinguishes Docker **not installed** from
      Docker **not running**, each printing its own actionable message and
      exiting non-zero (evidence: the two windows-latest CI scenarios assert
      the distinct messages + exit code 1).
- [ ] AC3 — `start_windows.bat` distinguishes a `docker compose pull` failure
      from a health-check timeout, each with its own message and non-zero exit,
      and the timeout path surfaces the `RS_PORT` port-in-use hint (evidence:
      the pull-fail and up-timeout windows-latest CI scenarios).
- [ ] AC4 — `start_windows.bat` prints a manual-URL fallback when the browser
      cannot open, and honors a documented non-interactive env seam so the
      happy path runs to a success message and exits 0 without blocking on
      input (evidence: the success-path windows-latest CI scenario exits 0
      unattended; the fallback message is asserted).
- [ ] AC5 — A cross-platform guard test fails when any `.bat` blob is LF-only
      (evidence: guard passes on the fixed blobs; mutation — rewrite a blob to
      LF — makes it fail).
- [ ] AC6 — `start_mac.command` and `start_linux.sh` gain the not-installed vs
      not-running distinction and the pull-failure message, keeping the three
      launchers' diagnostics consistent (evidence: their content shows the
      distinct branches; README troubleshooting wording matches).
- [ ] AC7 — Profile `verify` is satisfied: the new `windows-launcher` workflow
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

- [ ] T1 — Write the cross-platform line-ending guard
      `scripts/tests/test_launcher_line_endings.sh`: fail if the stored blob of
      any root `.bat` (`git cat-file -p :<file>`) lacks CRLF. Tests-first — it
      fails against today's LF blobs.
- [ ] T2 — Fix delivery: set `*.bat -text` in `.gitattributes` (drop
      `eol=crlf`, which only smudges on clone) and re-commit
      `start_windows.bat`/`stop_windows.bat` with CRLF bytes so the blob itself
      carries CRLF; T1 then passes.
- [ ] T3 — Rework `start_windows.bat`: (a) `where docker` → not-installed
      message; else `docker info` → not-running message; (b) check `docker
      compose pull` result → distinct pull-failure message; (c) on
      `up --wait` failure, health-timeout message + `RS_PORT` port-in-use hint;
      (d) manual-URL fallback if `start` fails; (e) a non-interactive env seam
      (e.g. `RS_LAUNCHER_NONINTERACTIVE`) suppressing `pause`/`timeout`/browser
      so CI can run it. Every failure branch keeps `exit /b 1`.
- [ ] T4 — Add `.github/workflows/windows-launcher.yml` (runs-on
      `windows-latest`, own `paths` filter on the `.bat` files + `.gitattributes`
      + the workflow, so the heavy image build in `pr-ci.yml` is not dragged in):
      run `start_windows.bat` under a PATH-shadowing `docker` stub across
      scenarios {not-installed, not-running, pull-fail, up-timeout, success},
      asserting message + exit code; also run the T1 guard (via `shell: bash`).
- [ ] T5 — Port the not-installed vs not-running distinction and the
      pull-failure message to `start_mac.command` and `start_linux.sh` (one-line
      echoes; no new CI lane).
- [ ] T6 — Sync README troubleshooting (around line 175, "the launcher says
      Docker isn't running") to the new clearer messages, including the
      not-installed guidance.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates -->

- 2026-07-18: created by /milestone-plan. Promotes the "Windows launcher
  hardening" candidate (added 2026-07-17; GP3, Known issue #4). Gate decisions:
  guarantee CRLF in blob (`-text`); windows-latest CI + EOL guard; Windows-
  focused with shared-diagnostic parity to mac/linux.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md -->

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55):
     only the plan-owned body above counts; evidence never scrambles it. -->
