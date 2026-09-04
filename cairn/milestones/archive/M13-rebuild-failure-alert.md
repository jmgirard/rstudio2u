# M13: Weekly rebuild failure alert

**Status:** done (2026-09-04, PR #20 https://github.com/jmgirard/rstudio2u/pull/20)

**Goal:** A failed weekly image rebuild opens or updates a GitHub issue; the next green one closes it.

**Outcome:** `.github/ci-failure-issue.sh` (result, run URL, variants; `GH_TOKEN`):
on `failure` ensures the `ci-failure` label and opens an issue naming the
variants and linking the run, or comments on the oldest open one; on `success`
comments on and closes each open one; other results are silent.
`scripts/tests/test_ci_failure_issue.sh` drives it with a call-logging stub `gh`
(asserts subcommand + issue number); wired into `pr-ci.yml`, script path in its
filter. `docker.yml`: build legs named `build (<variant>)`; a `notify` job
(`needs: build`, `if: always() && github.event_name == 'schedule'`, `issues:
write`) recovers failed variant names via `gh run view --json jobs` and calls the
script; push and dispatch runs skip it. CHANGELOG untouched (internal tier).

**Decisions:** none cross-cutting; local: variant names from the run's job list,
not matrix outputs; scheduled runs only.

**Review:** three-lens fan-out, two lenses clean. Fixed: failing `gh run view`
warns and falls back; `$GITHUB_RUN_ID`; `--limit 100` + no-variant title
asserted; jq guard. Rejected: AC1 "first returned" reading, explicit test path in
the filter, `always()` on cancel, job-name no-op claim. AC3 skip shown by the
post-merge dispatch (run 33821023680: builds green, `notify` skipped). Hygiene: QEMU candidate row extended.
