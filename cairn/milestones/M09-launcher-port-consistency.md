<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M09: Launcher port consistency

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** IP2, GP1, GP3
- **Branch/PR:** m09-launcher-port-consistency · https://github.com/jmgirard/rstudio2u/pull/10

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

- 2026-07-18: created by /milestone-plan from the candidate M08's review filed; plan gate chose env var + `.env`, bash harness on ubuntu-latest, pre-flight validation.
- 2026-07-18: set in-progress; implement gate chose a shared launcher_common.sh for the POSIX pair and lenient validation (unreadable values pass through to Compose).
- 2026-07-18: T1 done — launcher_common.sh with launcher_interactive/launcher_pause; mac + Linux source it.
- 2026-07-18: T2 done — POSIX harness, 10/10 green as baseline; `env -i` resolves interpreters against the scrubbed PATH, so bash and the stub shebang need absolute paths.
- 2026-07-18: T3+T4 done — requested_port/check_port/bound_port/url helpers; all three launchers validate pre-Compose and announce what `docker compose port` reports.
- 2026-07-18: T5 done — timeout hint names RS_PORT and .env on all three; manual-URL line added to mac + Linux.
- 2026-07-18: T6 done — harness to 32 scenarios; sandbox copy keeps .env out of the repo; stub models Compose's resolution so precedence is not circular.
- 2026-07-18: T6 mutation check — restoring the 8787 hardcode fails 13 scenarios, so the guards are real.
- 2026-07-18: three batch defects caught pre-commit — `::` inside `( )` is a parse error (use `rem`); `if defined X call :label || (...)` parses ambiguously; `%%~B` strips quotes without a fragile substitution.
- 2026-07-18: T7 done — Windows harness gained the same scenarios + a `compose port` stub; NOT runnable locally (no pwsh), so CI is its first execution.
- 2026-07-18: T8 done — windows-launcher.yml → launchers.yml, posix-scenarios job added, paths widened.
- 2026-07-18: T9 done — README FAQ rewritten around .env; CHANGELOG Fixed+Changed; .env ignored by git and Docker.
- 2026-07-18: discovered sub-task — sourcing a helper broke the copy-one-file case; both launchers now explain it (seam honored inline), scenario added, 34 total.
- 2026-07-18: verify slot PARTIAL — hadolint clean; `docker build` unrunnable here (credential helper hangs, buildkit cannot resolve the syntax frontend). Not worked around. pr-ci.yml verifies AC8.
- 2026-07-18: out-of-scope noted — Dockerfile:33 ships scripts/tests/ into the image (pre-existing, GP5); filed for the image-size candidate.

- 2026-07-18: review round-trip 1 — windows-scenarios failed. Root cause is the
  harness, not the launcher: PowerShell variable names are case-insensitive, so
  the `$DotEnv` parameter shadowed the script-level `$dotenv` path, and
  Set-Content wrote to a path named after the content. Status back to
  in-progress.
- 2026-07-18: fixed — script path renamed $dotenvPath; stale windows-launcher.yml
  reference in the harness header corrected. Back to review pending CI.
- 2026-07-18: CI all green after the fix (build-smoke, line-endings, posix, windows).
- 2026-07-18: review round-trip 2 — gate FAILED on four confirmed diff-bug
  findings; AC3 evidence proved to be false coverage. Details in Review section.
- 2026-07-18: all four fixed — .env values now read the way Compose reads them (inline comments stripped, quoted values end at the closing quote, both ends trimmed) in bash and batch alike; shared launcher_port_ok / :port_ok range-check the Compose-reported port so a :0 binding falls back instead of announcing localhost:0.
- 2026-07-18: harness gained 12 scenarios that force the launcher's own parse to reach the output (46 total). Mutations now caught: deleting .env support 11 failures, dropping comment-stripping 5, accepting an out-of-range bound port 2 — the last needed a scenario pairing :0 with a requested port, since launcher_url's guard otherwise masks launcher_bound_port's.

## Decisions

- 2026-07-18: the announced URL comes from `docker compose port`, not from the
  launcher's own reading of RS_PORT/.env. A launcher-side parser would have to
  agree with Compose's resolution in every case; asking Compose removes that
  whole class of divergence, and reduces the launcher's own parse to a
  best-effort typo check. Milestone-local: it constrains these three files, not
  the repo at large.

## Review

_PR: https://github.com/jmgirard/rstudio2u/pull/10 — CI all green
(build-smoke, line-endings, posix-scenarios, windows-scenarios)._

### Acceptance-criteria evidence

Scenario names below are from the two harnesses; POSIX run locally + in CI
(34 scenarios), Windows run in CI (16 scenarios). All green.

- AC1 default: `port-default` passes on all three launchers; each announces
  `http://localhost:8787` with no RS_PORT and no .env.
- AC2 env var: `port-from-env` (RS_PORT=8888) announces `http://localhost:8888`
  on all three.
- AC3 .env + precedence: `port-from-dotenv`, `port-from-dotenv-quoted`
  (RS_PORT="8899"), and `port-env-beats-dotenv` (env 8899 over .env 8888) pass
  on all three. The stub models Compose's own resolution, so precedence is
  tested against Compose's behavior rather than against the assertion.
- AC4 invalid values: `port-invalid-88ss`, `-0`, `-70000`, `-0.0.0.0:8888` all
  exit 1 before Compose is invoked, message naming the value and the 1–65535
  range, on all three.
- AC5 Compose is authority: `port-compose-is-authority` (requested 8888, stub
  reports 9999 → announces 9999) and `port-query-failure-falls-back` (query
  fails → falls back to 8888) pass on all three.
- AC6 parity: `health-timeout` asserts both `RS_PORT` and `.env` in the timeout
  message on all three; `port-default` asserts the manual-URL line.
- AC7 CI + docs: line-endings, posix-scenarios, windows-scenarios all pass on
  the PR; README FAQ rewritten around .env; CHANGELOG Fixed+Changed entries.
- AC8 profile verify: hadolint exit 0 locally; `docker build` verified by the
  build-smoke CI job (pass, 3m18s) — it could not run in the authoring
  environment (credential helper hang), so CI is the evidence.

Guards are not false coverage: reverting `launcher_url` to the 8787 hardcode
fails 13 POSIX scenarios.

### Consistency gate

`cairn_validate` exit 0, all checks PASS; one advisory (8 ACs vs the >7
tripwire) — not a gate failure, carried knowingly. No principle changed, so
`cairn_impact` skipped. Profile consistency-gate slot: docker build (CI) and
hadolint clean; base image pinned to `rocker/r2u:${UBUNTU_VERSION}` (24.04),
never bare latest; no secrets in layers (the two `--build-arg` mentions are
comments documenting UBUNTU_VERSION/RSTUDIO_VERSION); `.dockerignore` present
and excluding `.git`, `cairn`, `.env`; changelog entry present with no
milestone numbers in user-facing text.

### Round-trips

One, caught by CI: `windows-scenarios` failed on the first run. Root cause was
the harness, not the launcher — PowerShell variable names are case-insensitive,
so the `$DotEnv` parameter shadowed the script-level `$dotenv` path and
Set-Content wrote to a path named after the content. Fixed in b144ee4; the
launcher itself had behaved correctly (reporting 8787 when no .env existed).

### Independent review

Three fresh-context reviewers, distinct evidence bases. Blame-history: no
findings (verified M08's CRLF guarantee, the seam, the `rem`-in-block lesson,
and that the workflow rename widened rather than narrowed coverage).
Prior-PR-comments: no findings (confirmed the new missing-helper branches follow
the pause convention M08's review established). Diff-bug (Opus): four findings,
all confirmed by execution or inspection rather than scored — direct evidence
supersedes an estimated confidence.

1. `launcher_common.sh:42` — inline `#` comments in `.env` are not stripped, so
   a `.env` Compose accepts is hard-rejected. `RS_PORT=8888  # avoid clash`
   parses as the whole string and `launcher_check_port` exits 1, while Compose
   would have bound 8888. Contradicts this milestone's own lenient policy.
   VERIFIED by execution.
2. `start_windows.bat:53` — the trim is leading-only (`for /f "tokens=* delims= "`
   is trim-left), so a trailing space in `.env` (`RS_PORT=8888 `) is rejected on
   Windows while mac/Linux and Compose accept it. A consistency milestone
   shipping a Windows-only rejection. VERIFIED by inspection.
3. `launcher_common.sh:94` — no lower/upper-bound check on the Compose-reported
   port, so a `:0` binding (a compose override dropping `ports`) announces
   `http://localhost:0`. Windows is accidentally immune, so this is also a
   platform divergence. VERIFIED by execution (`:0` and `:70000`).
4. Both harnesses give the `.env` parsers zero effective coverage: each stub
   resolves `.env` itself, so every `.env` assertion is satisfied by the stub's
   parse regardless of the launcher's. VERIFIED by mutation — deleting `.env`
   support outright still yields 34/34 PASS. The work-log claim that the stub
   design avoided circularity was wrong: it removed circularity from the stub's
   resolution, not the launcher's.

### Gate outcome

FAILED. AC3's evidence is false coverage (finding 4), so the criterion cannot be
ticked under AC fencing. Findings 1-3 are correctness defects in criteria-relevant
behavior. Status back to in-progress; nothing merged. Round-trip 2.

