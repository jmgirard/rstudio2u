# M13: Weekly rebuild failure alert

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP7
- **Resolves:** —
- **Branch/PR:** m013-rebuild-failure-alert

## Goal

A failed weekly image rebuild opens or updates a GitHub issue, and the next
green weekly rebuild closes it.

## Scope

Tier: internal — an alert to the maintainer; no external consumer relies on
it.

**In:** a `gh`-driven script under `.github/`, its stubbed-`gh` test wired
into `pr-ci.yml`, and a final job in `docker.yml` that runs it on scheduled
runs only.

**Out:** alerting on push- or dispatch-triggered failures (gate: someone is
watching those); the 60-day scheduled-workflow auto-disable (candidate row);
email or chat notifications.

## Acceptance criteria

- [ ] AC1: `.github/ci-failure-issue.sh` given a failing result opens a
      `ci-failure`-labelled issue naming the failed variant(s) and linking
      the run when its `gh issue list --label ci-failure --state open
      --limit 100` returns nothing, and comments on the first returned issue
      otherwise; given a passing result it comments on and closes each issue
      that listing returns, and does nothing when it returns nothing — the
      four branches asserted by `scripts/tests/test_ci_failure_issue.sh`
      against a stubbed `gh` that records its invocations.
- [ ] AC2: `pr-ci.yml` runs that test, and its `paths` filter includes
      `.github/ci-failure-issue.sh` and the test file.
- [ ] AC3: `docker.yml` has a final job that `needs` the matrix job, whose
      condition is `always() && github.event_name == 'schedule'`, and which
      calls the script with the matrix job's result; a manual dispatch of the
      workflow shows that job skipped in the run summary.
- [ ] AC4: `CHANGELOG.md` is unchanged by the milestone.

## Coverage

- AC1 → T1, T2
- AC2 → T2
- AC3 → T3, T4
- AC4 → T3

## Tasks

- [x] T1: Write `.github/ci-failure-issue.sh` (args: result, run URL,
      variant list; needs `GH_TOKEN`): the four branches in AC1. Create the
      `ci-failure` label if missing (`gh label create` is idempotent with
      `--force`).
- [x] T2: Write `scripts/tests/test_ci_failure_issue.sh` with a stub `gh` on
      PATH that returns canned `issue list` output per scenario and logs
      every call; assert which subcommand ran and with which issue number
      (identity, not counts). Wire into `pr-ci.yml` beside the resolver tests
      and add both paths to its filter.
- [ ] T3: Add the `notify` job to `docker.yml`: `needs: build`,
      `if: always() && github.event_name == 'schedule'`,
      `permissions: issues: write`, passes `needs.build.result` and
      `github.server_url/.../actions/runs/github.run_id`. Note the matrix
      job's result is `failure` if any variant failed; the variant names come
      from a matrix-output step, or the issue names the run and the summary
      names the variant.
- [ ] T4: After the branch's `docker.yml` change is reviewed, the AC3 skip
      is shown by a manual dispatch post-merge (dispatch runs the default
      branch's file); pre-merge, `actionlint` and a read of the `if:` stand in.

## Work log

- 2026-09-03: created by /milestone-plan.
- 2026-09-03: criteria audit ran in reduced mode ([O] fresh reader); returned: the job condition lacked `always()` and would be skipped on the very failure it alerts on (fixed in AC3), "every open issue" exceeded what the test enumerates (narrowed to the script's own `--limit 100` listing), the script path was outside pr-ci's filter (AC2).
- 2026-09-03: plan gate chose "scheduled runs only, one reused issue, auto-close on green" over "every failed run" because push and dispatch failures already have a person watching; falsified by a push-triggered publish failure going unnoticed for a week.

- 2026-09-03: implement gate chose "query the run's jobs with gh run view" for the failed-variant names over matrix outputs (undocumented empty-output overwrite behavior) and over naming only the run.
- 2026-09-03: T1+T2 done: script + stubbed-gh test (4 branches, plus cancelled-stays-silent and usage error); planted defects (no close; comment on newest not oldest) turned the test red; mapfile replaced by a read loop for macOS bash 3.2; pinned shellcheck 0.11.0 (docker) clean; pr-ci runs the test and lists the script path (the test file is under the existing scripts/** entry).
## Decisions

## Review
