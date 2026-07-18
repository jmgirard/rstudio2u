<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M07: bspm mirror-failure UX

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** IP1, GP1   <!-- owner: plan · create/amend-via-gate; works under infra-only + classroom-first; adds/changes none -->
- **Branch/PR:** m07-bspm-mirror-ux · https://github.com/jmgirard/rstudio2u/pull/8   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

When the r2u mirror is transiently unreliable, a runtime `install.packages()`
retries automatically before failing, and a genuine failure surfaces a
plain-language hint instead of only a raw wall of apt error text.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** apt retry + connection-timeout hardening baked into the image
(`Acquire::Retries`, `Acquire::http/https::Timeout`); an `Rprofile.site`
diagnostic hook that appends a plain-language "mirror may be down, retry later"
hint when a bspm/apt install fails on a network/fetch error; a smoke-test
scenario that induces a dead-mirror failure and asserts both behaviors.

**Out:** adding a fallback/alternate r2u mirror or changing the mirror itself
(a bigger dependency + design decision → candidate row if wanted, not this
milestone); general launcher error UX (→ Windows-launcher candidate); image
slimming (→ image-size candidate, GP5). "Out" means not in *this* milestone.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets -->

- [x] AC1 — With the apt source pointed at an unreachable mirror, a runtime
      `install.packages()` retries the fetch **≥3 times** before failing, visible
      in the install output (driven by `Acquire::Retries "3"`).
- [x] AC2 — When such a fetch fails, the R session emits a plain-language hint
      naming a likely mirror outage and suggesting a retry, in addition to the
      underlying apt error.
- [x] AC3 — The hint is scoped to network/mirror failures: a normal unrelated
      install error (a package name apt cannot find) does **not** emit the
      mirror-outage hint.
- [x] AC4 — Happy path unregressed: a normal `install.packages()` of a CRAN
      package installs as an apt binary (`r-cran-<pkg>` present via `dpkg -s`)
      and loads — the M05 binary-path check still passes.
- [x] AC5 — Both scenarios (happy-path binary install and dead-mirror failure)
      run in `.github/smoke-test.sh` on the built image.
- [x] AC6 — verify slot clean: `hadolint Dockerfile` reports no violations and
      `docker build` succeeds; `CHANGELOG.md` has a user-visible entry for the
      retry + diagnostic behavior (consistency-gate; no milestone numbers).

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number. Review reads to fence evidence. -->

- AC1 → T1, T2
- AC2 → T1, T3
- AC3 → T1, T3
- AC4 → T4
- AC5 → T1, T4
- AC6 → T2, T3, T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate -->

- [x] T1 — Extend `.github/smoke-test.sh` with a mirror-failure scenario, run
      *after* the existing happy-path bspm check (so it doesn't poison it):
      repoint the r2u apt source to an unreachable host, attempt an install, and
      assert (a) retry attempts appear in the output and (b) the friendly
      mirror-down hint appears; add a companion assertion that a genuinely
      unavailable package name does **not** emit the mirror hint. Written to fail
      against the current image (`.github/smoke-test.sh:79-92` is the existing
      bspm block to build on).
- [x] T2 — Add an apt retry + timeout config layer to the `Dockerfile` (the
      bspm-config `RUN`, `Dockerfile:42`): write `/etc/apt/apt.conf.d/80-retries`
      with `Acquire::Retries "3";`, `Acquire::http::Timeout "30";`,
      `Acquire::https::Timeout "30";`. Confirm the dead-mirror scenario now shows
      ≥3 retry attempts.
- [x] T3 — Append an `Rprofile.site` diagnostic hook (after the
      `bspm::enable()` line the `Dockerfile:44` sed targets in
      `/etc/R/Rprofile.site`): wrap the bspm install path so that on apt/network
      failure signatures ("Could not resolve", "Failed to fetch", "Connection
      timed out", "Temporary failure") it appends the plain-language hint, and
      passes unrelated errors through unchanged. Log the apt-text-matching
      fragility in the work log.
- [x] T4 — Full local build of the noble image + end-to-end smoke run (happy
      path + dead mirror + false-positive); `hadolint Dockerfile` clean; add the
      `CHANGELOG.md` entry; capture evidence for AC4/AC5/AC6.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates -->

- 2026-07-18: created by /milestone-plan (candidate: bspm mirror-failure UX,
  Known issue #1). Scope = retry-hardening + friendly diagnostic; test bar =
  live dead-mirror smoke scenario (both chosen at the plan gate).
- 2026-07-18: T1 — added smoke Phase 3 (mirror-failure UX): 3a false-positive
  guard (nonexistent pkg, no hint) + 3b dead-mirror (blackhole r2u host via
  /etc/hosts + dead source repo → retries asserted via apt-config + hint
  sentinel). bash -n clean; exercised at the T4 build. Sentinel:
  "r2u package mirror looks unreachable".
- 2026-07-18: T2 — added /etc/apt/apt.conf.d/80-retries (Retries "3",
  http/https Timeout "30") to the bspm-config layer. hadolint clean
  (hadolint/hadolint image).
- 2026-07-18: T3 — added scripts/mirror_hint.R (reachability-probe hook, see
  MD-1) and appended it to /etc/R/Rprofile.site after bspm::enable() in the
  Dockerfile. R parse clean; parsing/probe/wrapper control-flow validated
  offline (4 cases). hadolint clean. Full behaviour verified at T4.
- 2026-07-18: T4 — built the noble image (docker build exit 0, hadolint clean)
  and ran the full smoke end-to-end (exit 0): AC1 apt retried the dead mirror
  4x (3 Ign + 1 Err), AC2 hint printed, AC3 no false hint, AC4 data.table
  binary install intact, AC5 both scenarios in CI smoke. Added the CHANGELOG
  Unreleased/Changed entry. Fixed the T1 blackhole targeting (blackhole *all*
  non-Ubuntu apt hosts, not just the first — the first was the CRAN source
  mirror, so praise still installed from r2u) and added an in-CI retry-
  visibility assertion (>=3 attempts) so AC5 covers AC1 behaviourally.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md -->

- MD-1 (2026-07-18, T3): Detect the outage by a TCP reachability probe of the
  configured apt mirrors, not by matching apt-error text. Text matching is
  brittle across apt versions and cannot separate a transient outage from an
  ordinary "package does not exist" error (both leave the package
  uninstalled). The hook checks the post-install state (requested packages
  still missing?) then probes reachability — so a missing-but-reachable
  install (nonexistent package) never fires the hint (AC3). The hint is
  additive; the original error/warning is always preserved and re-raised.

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55). -->

_Reviewed 2026-07-18 on branch m07-bspm-mirror-ux (PR #8). Image
`rstudio2u:m07-test` built from the committed Dockerfile + scripts (T4);
only tracking/CHANGELOG changed since, none of which enter the image._

### Acceptance-criteria evidence (fresh)

- AC1 ✓ — `apt-config dump Acquire::Retries` = 3 in the image; against a
  blackholed mirror `apt-get update` attempts each mirror 4× (3 `Ign:` + 1
  `Err:`) before failing. Smoke Phase 3b: "apt configured to retry fetches 3x"
  + "apt retried an unreachable mirror 4x before failing".
- AC2 ✓ — a mirror-unreachable `install.packages()` prints the plain-language
  hint ("the r2u package mirror looks unreachable … Wait a minute and run
  install.packages(...) again") and re-raises the original error. Smoke
  Phase 3b: "mirror-unreachable install surfaced the hint".
- AC3 ✓ — `install.packages("nosuchpkg1234321")` (mirror reachable) fails with
  no mirror hint. Smoke Phase 3a: "unrelated install error did not trigger the
  mirror hint".
- AC4 ✓ — `install.packages("data.table")` installs as `r-cran-data.table`
  (`dpkg -s` present) and loads. Smoke Phase [1/2] PASS.
- AC5 ✓ — happy-path + dead-mirror scenarios both run in
  `.github/smoke-test.sh`; full run exit 0.
- AC6 ✓ — `hadolint Dockerfile` no violations; `docker build` (noble) exit 0;
  `CHANGELOG.md` Unreleased/Changed entry present (no milestone numbers).

### Consistency gate

- Universal: `cairn_validate` exit 0 (all checks pass); no DESIGN principle
  changed → `cairn_impact` skipped.
- Toolchain (docker-image `consistency-gate`): `docker build` from clean
  context succeeds + `hadolint` clean; base image pinned (`rocker/r2u:24.04`
  via `UBUNTU_VERSION`, not bare `latest`); no secrets in `ENV`/`COPY`;
  `.dockerignore` present (excludes `.git`, `cairn`, build noise); CHANGELOG
  entry present.

### Independent review

_pending — three-lens fan-out + scorer._
