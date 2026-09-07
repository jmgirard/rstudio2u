# M017: Report a failing keepalive job

**Status:** done (2026-09-07, PR #24 https://github.com/jmgirard/rstudio2u/pull/24)

**Goal:** A scheduled run whose `keepalive` job fails opens the `ci-failure`
issue and names that job, instead of reading as all-success and closing it.

**Outcome:** `notify` in `docker.yml` now lists `keepalive` in both `needs:`
and `RESULTS`, so the job that keeps the weekly schedule alive is aggregated
like every other. `extract_variants` in `.github/ci-failure-issue.sh` became
`extract_failed_names`: `build (`/`publish (` legs keep the variant parse and
its dedup behind a jq `if`, every other failed job is named by itself, so a
later reportable lane needs no new branch. The contradiction warning re-based
on "names no failed job at all"; issue wording moved from "weekly rebuild" to
"scheduled run" on both the failure and close paths.
`scripts/tests/test_ci_failure_issue.sh` reached 83 assertions.

**Decisions:** none. Implements the reporting gap D-009 recorded.

**Review:** three-lens fan-out, all six criteria verified fresh. Eight
findings: four fixed at the gate (close-path wording left in the old
vocabulary; a comment still naming `extract_variants`; the unrecorded `if:`
coupling that keeps `needs.keepalive.result` from ever being `skipped`; a
missing no-warning assertion), two filed as candidate rows, two rejected. No
finding met the return floor.
