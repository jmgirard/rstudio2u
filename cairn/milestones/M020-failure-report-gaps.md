# M020: Close the gaps in CI failure reports

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** internal — CI failure alerting and its tests; no consumer of the published image relies on it
- **Branch/PR:** —

## Goal

Every way a scheduled job can fail reaches the `ci-failure` issue with the job named, and the rebuild-gap check's lookup is tested.

## Scope

**In:** name timed-out jobs in `.github/ci-failure-issue.sh`; a `notify` job in
`rebuild-gap.yml` that reports a failed `gap` job; move `rebuild-gap.yml`'s
date reduction into a tested script; two `docker.yml` ride-alongs (the failure
script in `push.paths`, `permissions:` on `meta`, `build`, `publish`). Absorbs
the candidate rows "Name timed-out jobs in ci-failure issues", "Add a notify
job to rebuild-gap.yml", "Test the rebuild-gap date reduction", "Add the
failure script to push.paths", "Scope permissions on the docker.yml jobs".

**Out:** the job-name separator (candidate row "Pick an unambiguous job-name
separator"); keepalive push contention (candidate row "Retry the keepalive
push on contention"); r2u smoke timeouts (candidate row "Keep r2u timeouts
from failing publish"); moving-tag rollback (candidate row "Refuse to move
moving tags backward").

## Acceptance criteria

- [ ] AC1: `.github/ci-failure-issue.sh`'s `extract_failed_names` selects jobs
      whose conclusion is `failure` or `timed_out`; the naming rule is
      otherwise unchanged (a build or publish leg by its variant, once per
      variant, any other job by its own name). Called with result `failure`
      and a listing whose only non-passing job timed out, the script names
      that job and prints no "names no failed job" warning.
- [ ] AC2: `rebuild-gap.yml` has a `notify` job that needs `gap` and whose
      `if:` admits only a scheduled run whose `gap` result is `failure`. It
      passes `.github/ci-failure-issue.sh` that result, the run URL, and this
      run's jobs listing, so the script opens an issue titled
      `Weekly run failed: rebuild-gap` or comments on the open `ci-failure`
      issue naming `rebuild-gap`. On any other `gap` result or event the job
      is skipped, so it never closes the issue.
- [ ] AC3: The reduction of the `gh run list` answer to
      `.github/rebuild-gap.sh`'s first argument lives in a script under
      `.github/`, not in `rebuild-gap.yml`. It maps an answer matching
      `^[0-9]{4}-[0-9]{2}-[0-9]{2}T` to its first ten characters, an empty
      answer to `none`, any other answer to `unknown`, and a failed lookup to
      `unknown`. A test file that `pr-ci.yml` runs covers the new script, and
      `pr-ci.yml`'s `paths` list it. The `gap` job's step in `rebuild-gap.yml`
      holds no `if`, `case`, or `[[ ]]` test over the answer.
- [ ] AC4: `docker.yml`'s `on.push.paths` lists `.github/ci-failure-issue.sh`.
- [ ] AC5: `docker.yml`'s `meta`, `build`, and `publish` jobs each carry a
      `permissions:` block granting `contents: read` and no other scope, and
      those jobs succeed under it.

## Coverage

- AC1 → T1
- AC2 → T1, T3
- AC3 → T2
- AC4 → T4
- AC5 → T4, T5

## Tasks

- [ ] T1: Tests first in `scripts/tests/test_ci_failure_issue.sh`: listings for
      a timed-out non-matrix job, one variant with a `failure` leg and a
      `timed_out` leg (named once), a timed-out leg alone, and a failed
      `rebuild-gap` job; assert the title for each and no contradiction
      warning under result `failure`. See them red, then widen the `select` in
      `extract_failed_names` and its usage comment (LESSONS M017).
- [ ] T2: New `.github/` script that runs the `gh run list` query now in
      `rebuild-gap.yml` and prints the date, `none`, or `unknown` with the
      existing warnings. Tests first in a new `scripts/tests/` file with an
      argument-sensitive `gh` stub (LESSONS M09) driving all four outcomes and
      asserting the query's arguments; plant a broken branch and see red.
      Add the script and test to `pr-ci.yml` (`paths` and run lines). Rewire
      the `gap` step; update the comments in `rebuild-gap.yml` and
      `rebuild-gap.sh`.
- [ ] T3: Add the `notify` job to `rebuild-gap.yml` (`needs: gap`;
      `if: always() && github.event_name == 'schedule' && needs.gap.result == 'failure'`;
      `contents: read`, `issues: write`, `actions: read`; `gh run view --json jobs`
      handed to the failure script as in `docker.yml`'s `notify`). Update the
      DESIGN.md Conventions rebuild-gap bullet.
- [ ] T4: In `docker.yml`, add `.github/ci-failure-issue.sh` to `on.push.paths`
      and `permissions: contents: read` to `meta`, `build`, `publish`.
- [ ] T5: Run every `scripts/tests/test_*.sh` and shellcheck 0.11.0 (`-x -S info`)
      over the changed scripts. Dispatch `docker.yml` with `test_mode` on the
      milestone branch; its `meta`, `build`, and `publish` jobs green is
      AC5's evidence.

## Work log

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: not run — work named at the question set.
- 2026-10-20: question set: what to work on — the three failure-report rows ("Failure-report gaps").
- 2026-10-20: question set: may the agent dispatch `docker.yml` test-mode runs on the milestone branch — allowed. No other dispatch (for example of `rebuild-gap.yml`) was asked; AC3's evidence is local.
- 2026-10-20: question set: take the two small `docker.yml` rows along if `docker.yml` is edited — yes.
- 2026-10-20: question set: r2u smoke strictness — "retry, then fail"; moot here, recorded on the r2u candidate row.
- 2026-10-20: collision check: absorbs five candidate rows (Scope); extends done M13, M017, M018; no D-entry collision; checker-regress shape not hit (the alerts watch the live publish lane, not repo-internal artifacts).
- 2026-10-20: inbox sweep: 0 open issues, 0 open PRs.
- 2026-10-20: lessons harvested: M017 (`timed_out` vs `failure`), M09 (argument-sensitive stub), M011 (plant before trusting a check).
- 2026-10-20: criteria audit (reduced): 7 findings, all fixed: AC1 narrowed to the `select` predicate plus the one no-warning case under result `failure`; the test listings of AC1, AC2, AC3 moved to T1/T2; AC2's update case reworded to a comment; AC3 names the date shape; AC5's dispatch run moved to T5.
- 2026-10-20: plan gate chose a separate lookup script over a reduction function fed the raw answer and `gh`'s exit status from YAML, because the lookup-failure branch would stay untested in YAML; falsified by the query needing workflow-only context a stubbed test cannot represent.
- 2026-10-20: plan gate chose a `notify` job that runs only on a failed `gap` over one that passes every result, because a `success` would close the issue the `gap` job just opened; falsified by a non-failure `gap` outcome that should reach the issue.
- 2026-10-20: plan gate chose `contents: read` alone for `meta`, `build`, `publish` (gha cache, artifacts and the Docker Hub login use no `GITHUB_TOKEN` scope); falsified by a job failing for a missing token scope in the dispatch run.
- 2026-10-20: note on AC4: `docker.yml`'s `notify` runs on schedule only, so a push run started by the new path rebuilds and publishes but does not exercise the failure script; kept as approved.

## Decisions

## Review
