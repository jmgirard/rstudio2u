# M018: Alert when no weekly rebuild has succeeded in too long

**Status:** done (2026-09-07, PR #26 https://github.com/jmgirard/rstudio2u/pull/26)

**Goal:** When no scheduled rebuild has succeeded for too long — whatever the cause — the repo raises the `ci-failure` issue instead of going quiet.

**Outcome:** `.github/workflows/rebuild-gap.yml` runs Mondays 12:00 UTC (plus `workflow_dispatch`), asks `gh run list` for the newest successful *scheduled* `docker.yml` run and reduces it to a date — or to `none` (no such run on record) or `unknown` (history unreadable or unparseable), each itself a gap. `.github/rebuild-gap.sh` holds the staleness rule: three validated arguments in, a decision out, no network of its own; on a gap it raises the same `ci-failure` issue through `.github/ci-failure-issue.sh`, which gained an optional fourth argument so the issue reads as a gap rather than a build failure (omitted, every rendering is byte-identical to before). `.github/date-lib.sh` factors the civil-date arithmetic, date parsing and threshold-width bound out of `keepalive.sh`; the boundary is not shared, since keepalive acts at or past its threshold and this check only past its own. The bound is 8 days: both workflows are weekly, so a real gap is a multiple of seven and 8 makes the second missed rebuild the alert. `scripts/tests/test_rebuild_gap.sh` (111 assertions) runs in the pr-ci lane.

**Decisions:** none. The plan gate chose run history over Docker Hub tag dates as the oracle (the alternative is a candidate row) and reused the `ci-failure` issue stream rather than a separate label.

**Review:** three-lens fan-out; blame-history and prior-review found nothing, diff-bug returned eleven. All seven criteria verified fresh. Three fixed at the gate: the threshold moved 15 → 8, weekly quantization having made a 15-day rule first fire at 21; an unparseable `createdAt` now routes to `unknown` instead of failing the run silently; a job-name comment's rationale corrected. Two filed as candidate rows, six rejected. No finding met the return floor.
