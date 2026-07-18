<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M07: bspm mirror-failure UX

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** IP1, GP1   <!-- owner: plan · create/amend-via-gate; works under infra-only + classroom-first; adds/changes none -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create -->

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

- [ ] AC1 — With the apt source pointed at an unreachable mirror, a runtime
      `install.packages()` retries the fetch **≥3 times** before failing, visible
      in the install output (driven by `Acquire::Retries "3"`).
- [ ] AC2 — When such a fetch fails, the R session emits a plain-language hint
      naming a likely mirror outage and suggesting a retry, in addition to the
      underlying apt error.
- [ ] AC3 — The hint is scoped to network/mirror failures: a normal unrelated
      install error (a package name apt cannot find) does **not** emit the
      mirror-outage hint.
- [ ] AC4 — Happy path unregressed: a normal `install.packages()` of a CRAN
      package installs as an apt binary (`r-cran-<pkg>` present via `dpkg -s`)
      and loads — the M05 binary-path check still passes.
- [ ] AC5 — Both scenarios (happy-path binary install and dead-mirror failure)
      run in `.github/smoke-test.sh` on the built image.
- [ ] AC6 — verify slot clean: `hadolint Dockerfile` reports no violations and
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

- [ ] T1 — Extend `.github/smoke-test.sh` with a mirror-failure scenario, run
      *after* the existing happy-path bspm check (so it doesn't poison it):
      repoint the r2u apt source to an unreachable host, attempt an install, and
      assert (a) retry attempts appear in the output and (b) the friendly
      mirror-down hint appears; add a companion assertion that a genuinely
      unavailable package name does **not** emit the mirror hint. Written to fail
      against the current image (`.github/smoke-test.sh:79-92` is the existing
      bspm block to build on).
- [ ] T2 — Add an apt retry + timeout config layer to the `Dockerfile` (the
      bspm-config `RUN`, `Dockerfile:42`): write `/etc/apt/apt.conf.d/80-retries`
      with `Acquire::Retries "3";`, `Acquire::http::Timeout "30";`,
      `Acquire::https::Timeout "30";`. Confirm the dead-mirror scenario now shows
      ≥3 retry attempts.
- [ ] T3 — Append an `Rprofile.site` diagnostic hook (after the
      `bspm::enable()` line the `Dockerfile:44` sed targets in
      `/etc/R/Rprofile.site`): wrap the bspm install path so that on apt/network
      failure signatures ("Could not resolve", "Failed to fetch", "Connection
      timed out", "Temporary failure") it appends the plain-language hint, and
      passes unrelated errors through unchanged. Log the apt-text-matching
      fragility in the work log.
- [ ] T4 — Full local build of the noble image + end-to-end smoke run (happy
      path + dead mirror + false-positive); `hadolint Dockerfile` clean; add the
      `CHANGELOG.md` entry; capture evidence for AC4/AC5/AC6.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates -->

- 2026-07-18: created by /milestone-plan (candidate: bspm mirror-failure UX,
  Known issue #1). Scope = retry-hardening + friendly diagnostic; test bar =
  live dead-mirror smoke scenario (both chosen at the plan gate).

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md -->

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55). -->
