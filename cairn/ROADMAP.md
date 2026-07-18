# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-17 (M01 archived)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M02 | Pre-merge PR CI lane | review | — | normal | milestones/M02-pr-ci-lane.md |
| M01 | CI smoke test before publishing moving tags | done | — | normal | milestones/archive/M01-ci-smoke-test.md |
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
<!-- (CI smoke test candidate promoted to M01 on 2026-07-17) -->
<!-- (Pre-merge PR CI candidate promoted to M02 on 2026-07-17) -->
- Guard RStudio version auto-detect: validate the scraped version, fail loudly on a bad scrape instead of mis-tagging — added 2026-07-17 — GP2; Known issue #2
- Deepen smoke test to bspm binary install + quarto render (catches arm64 parity drift) — added 2026-07-17 — GP3/GP7; Known issue #3
- Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- Windows launcher hardening: robustness + clearer error messages for the least-tested path — added 2026-07-17 — GP3; Known issue #4
- bspm mirror-failure UX: retry or clearer diagnostic when r2u installs fail — added 2026-07-17 — Known issue #1
- resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
