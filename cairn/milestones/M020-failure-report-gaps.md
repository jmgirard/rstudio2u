# M020: Close the gaps in CI failure reports

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** internal — CI failure alerting and its tests; no consumer of the published image relies on it
- **Branch/PR:** m020-failure-report-gaps

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

- [x] AC1: `.github/ci-failure-issue.sh`'s `extract_failed_names` selects jobs
      whose conclusion is `failure` or `timed_out`; the naming rule is
      otherwise unchanged (a build or publish leg by its variant, once per
      variant, any other job by its own name). Called with result `failure`
      and a listing whose only non-passing job timed out, the script names
      that job and prints no "names no failed job" warning.
- [x] AC2: `rebuild-gap.yml` has a `notify` job that needs `gap` and whose
      `if:` admits only a scheduled run whose `gap` result is `failure`. It
      passes `.github/ci-failure-issue.sh` that result, the run URL, and this
      run's jobs listing, so the script opens an issue titled
      `Weekly run failed: rebuild-gap` or comments on the open `ci-failure`
      issue naming `rebuild-gap`. On any other `gap` result or event the job
      is skipped, so it never closes the issue.
- [x] AC3: The reduction of the `gh run list` answer to
      `.github/rebuild-gap.sh`'s first argument lives in a script under
      `.github/`, not in `rebuild-gap.yml`. It maps an answer matching
      `^[0-9]{4}-[0-9]{2}-[0-9]{2}T` to its first ten characters, an empty
      answer to `none`, any other answer to `unknown`, and a failed lookup to
      `unknown`. A test file that `pr-ci.yml` runs covers the new script, and
      `pr-ci.yml`'s `paths` list it. The `gap` job's step in `rebuild-gap.yml`
      holds no `if`, `case`, or `[[ ]]` test over the answer.
- [x] AC4: `docker.yml`'s `on.push.paths` lists `.github/ci-failure-issue.sh`.
- [x] AC5: `docker.yml`'s `meta`, `build`, and `publish` jobs each carry a
      `permissions:` block granting `contents: read` and no other scope, and
      those jobs succeed under it.

## Coverage

- AC1 → T1
- AC2 → T1, T3
- AC3 → T2
- AC4 → T4
- AC5 → T4, T5

## Tasks

- [x] T1: Tests first in `scripts/tests/test_ci_failure_issue.sh`: listings for
      a timed-out non-matrix job, one variant with a `failure` leg and a
      `timed_out` leg (named once), a timed-out leg alone, and a failed
      `rebuild-gap` job; assert the title for each and no contradiction
      warning under result `failure`. See them red, then widen the `select` in
      `extract_failed_names` and its usage comment (LESSONS M017).
- [x] T2: New `.github/` script that runs the `gh run list` query now in
      `rebuild-gap.yml` and prints the date, `none`, or `unknown` with the
      existing warnings. Tests first in a new `scripts/tests/` file with an
      argument-sensitive `gh` stub (LESSONS M09) driving all four outcomes and
      asserting the query's arguments; plant a broken branch and see red.
      Add the script and test to `pr-ci.yml` (`paths` and run lines). Rewire
      the `gap` step; update the comments in `rebuild-gap.yml` and
      `rebuild-gap.sh`.
- [x] T3: Add the `notify` job to `rebuild-gap.yml` (`needs: gap`;
      `if: always() && github.event_name == 'schedule' && needs.gap.result == 'failure'`;
      `contents: read`, `issues: write`, `actions: read`; `gh run view --json jobs`
      handed to the failure script as in `docker.yml`'s `notify`). Update the
      DESIGN.md Conventions rebuild-gap bullet.
- [x] T4: In `docker.yml`, add `.github/ci-failure-issue.sh` to `on.push.paths`
      and `permissions: contents: read` to `meta`, `build`, `publish`.
- [x] T5: Run every `scripts/tests/test_*.sh` and shellcheck 0.11.0 (`-x -S info`)
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
- 2026-10-20: implement: branch m020-failure-report-gaps cut from main at 85dd3e3; status in-progress.
- 2026-10-20: T1 done: five new cases (5o–5r) in test_ci_failure_issue.sh; the timed-out job and timed-out leg cases were red before the fix (4 assertions), all green after widening the `select`.
- 2026-10-20: T2 done: `.github/last-rebuild-success.sh <output-file>` writes the word to a file so its `::warning::` lines stay on stdout for the run log; every outcome exits 0, only a missing argument exits 2. `scripts/tests/test_last_rebuild_success.sh` (16 assertions) red before the script existed; five planted defects (empty→unknown, untrimmed date, shape without T, lookup failure→none, wrong event) each turned it red. Wired into `rebuild-gap.yml` and `pr-ci.yml`.
- 2026-10-20: correction to the T2 line: the new suite has 17 assertions, not 16.
- 2026-10-20: T3 done: `notify` job appended to `rebuild-gap.yml` (parsed with ruby's YAML: jobs `gap`, `notify`; `needs: gap`; the planned `if:`); the `gap` job's name comment, `ci-failure-issue.sh`'s caller list and the DESIGN rebuild-gap bullet updated. The job runs only on a schedule, so no pre-merge run exercises it; its script path is covered by T1's case 5r.
- 2026-10-20: T4 done: `.github/ci-failure-issue.sh` added to `docker.yml`'s `on.push.paths`; `permissions: contents: read` on `meta`, `build`, `publish` (ruby YAML parse shows exactly that per job). No step in those jobs calls `gh` or passes a `GITHUB_TOKEN`; login uses Docker Hub secrets, cache and artifacts the runtime token.
- 2026-10-20: T5 done: all nine `scripts/tests/test_*.sh` suites exit 0. Test-mode dispatch 39533199085 at a7866e9: `meta`, the four `build` legs and both `publish` legs succeeded, `keepalive` succeeded with main unchanged at 85dd3e3, `notify` skipped (dispatch). Shellcheck is not installed locally; pulling its image was not granted, so the PR's shell-lint lane runs it at review (minor amendment of T5).
- 2026-10-20: claim audit: not owed — internal tier.
- 2026-10-20: implement complete; status review.

## Decisions

## Review

Evidence gathered 2026-10-20 at f124d07; `origin/main` had not moved (0 commits ahead of the branch base).

- AC1: `.github/ci-failure-issue.sh:121` reads `select(.conclusion == "failure" or .conclusion == "timed_out")`; the variant parse and dedup after it are unchanged in the diff. `test_ci_failure_issue.sh` PASS, including 5o (timed-out `keepalive` named, no `::warning::`) and 5q (timed-out leg alone names `resolute`, no `::warning::`), both called with result `failure`; 5p names `noble` once for a failure plus timed-out leg.
- AC2: ruby YAML parse of `rebuild-gap.yml`: `notify.needs` = `gap`, `if:` = `always() && github.event_name == 'schedule' && needs.gap.result == 'failure'`; its step passes `RESULTS: ${{ needs.gap.result }}`, `RUN_URL` and `jobs.json` from `gh run view "$GITHUB_RUN_ID" --json jobs` to `ci-failure-issue.sh`. The `if:` admits no other result or event, so the script only ever receives `failure` and never takes its close branch. Case 5r: a failed `rebuild-gap` job titles a new issue `Weekly run failed: rebuild-gap` and comments on open #41 naming it, closing nothing.
- AC3: `.github/last-rebuild-success.sh` holds the lookup and the four branches (failed lookup → `unknown`, empty → `none`, `^[0-9]{4}-[0-9]{2}-[0-9]{2}T` → text before the T, else `unknown`). The `gap` step's `run` block (ruby parse) has 0 lines with `if`, `case` or `[[`. `pr-ci.yml` lists the script in `paths` (line 19) and runs `test_last_rebuild_success.sh` (line 41); that suite PASS (17 assertions).
- AC4: ruby parse of `docker.yml`: `on.push.paths` includes `.github/ci-failure-issue.sh` (true).
- AC5: ruby parse: `meta`, `build`, `publish` each `{contents: read}` and nothing else. Test-mode dispatch 39533199085 at a7866e9 (no `.github/` change between a7866e9 and f124d07): conclusion success; `meta`, all four `build` legs and both `publish` legs success.
- Gate: `cairn_validate.py` all checks passed (one pre-existing advisory, the old pdf `.gitignore` entry). No IP/GP changed (DESIGN edit is a Conventions bullet), so `cairn_impact` skipped. Profile gate: the diff touches no `Dockerfile`, `.dockerignore` or build context; the image built from a clean context in run 39533199085; base stays `rocker/r2u:${UBUNTU_VERSION}` with versioned args; no secret added. hadolint is not installed locally and runs in `pr-ci.yml` on the PR. Shellcheck 0.11.0 runs in `lint.yml` on the PR (not installed locally).
- spawned: diff-bug, blame-history, prior-review, ripple
