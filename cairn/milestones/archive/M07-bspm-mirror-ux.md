# M07: bspm mirror-failure UX (done 2026-07-18)

**Goal:** Ride out a flaky r2u binary mirror — retry transient fetch failures,
and surface a plain-language hint (not raw apt errors) when an install fails
because the mirror is unreachable. Known issue #1.

**Outcome (PR #8, squash cdb1f85):**
- apt retry/timeout config `/etc/apt/apt.conf.d/80-retries`
  (`Acquire::Retries "3"`, http/https `Timeout "30"`).
- `scripts/mirror_hint.R` appended to `/etc/R/Rprofile.site` after
  `bspm::enable()`: wraps `install.packages`, prints a friendly hint only when
  a requested package stays missing AND a TCP probe finds an R package mirror
  unreachable; the original error is always preserved and re-raised.
- Smoke Phase 3: retry-visibility (≥3 attempts), the hint, a false-positive
  guard, and no-arg robustness. Full smoke exit 0; hadolint clean.

**Key decision:**
- MD-1: detect the outage by a TCP reachability probe of the R package mirrors,
  not by matching apt-error text — distinguishes a real outage from an ordinary
  package-not-found (AC3) and is robust across apt versions.

**Review:** 3-lens fan-out; diff-bug reviewer found 3 hook defects (probe
over-scoped to Ubuntu archives; unsafe missing(pkgs) path; local-file args
mis-counted as missing) — all fixed and re-verified. blame + prior-PR lenses
clean.
