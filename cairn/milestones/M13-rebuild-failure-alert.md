# M13: Weekly rebuild failure alert

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP7
- **Resolves:** —
- **Branch/PR:** m013-rebuild-failure-alert · https://github.com/jmgirard/rstudio2u/pull/20

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

- [x] AC1: `.github/ci-failure-issue.sh` given a failing result opens a
      `ci-failure`-labelled issue naming the failed variant(s) and linking
      the run when its `gh issue list --label ci-failure --state open
      --limit 100` returns nothing, and comments on the first returned issue
      otherwise; given a passing result it comments on and closes each issue
      that listing returns, and does nothing when it returns nothing — the
      four branches asserted by `scripts/tests/test_ci_failure_issue.sh`
      against a stubbed `gh` that records its invocations.
- [x] AC2: `pr-ci.yml` runs that test, and its `paths` filter includes
      `.github/ci-failure-issue.sh` and the test file.
- [ ] AC3: `docker.yml` has a final job that `needs` the matrix job, whose
      condition is `always() && github.event_name == 'schedule'`, and which
      calls the script with the matrix job's result; a manual dispatch of the
      workflow shows that job skipped in the run summary.
- [x] AC4: `CHANGELOG.md` is unchanged by the milestone.

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
- [x] T3: Add the `notify` job to `docker.yml`: `needs: build`,
      `if: always() && github.event_name == 'schedule'`,
      `permissions: issues: write`, passes `needs.build.result` and
      `github.server_url/.../actions/runs/github.run_id`. Note the matrix
      job's result is `failure` if any variant failed; the variant names come
      from a matrix-output step, or the issue names the run and the summary
      names the variant.
- [x] T4: After the branch's `docker.yml` change is reviewed, the AC3 skip
      is shown by a manual dispatch post-merge (dispatch runs the default
      branch's file); pre-merge, `actionlint` and a read of the `if:` stand in.

## Work log

- 2026-09-03: created by /milestone-plan.
- 2026-09-03: criteria audit ran in reduced mode ([O] fresh reader); returned: the job condition lacked `always()` and would be skipped on the very failure it alerts on (fixed in AC3), "every open issue" exceeded what the test enumerates (narrowed to the script's own `--limit 100` listing), the script path was outside pr-ci's filter (AC2).
- 2026-09-03: plan gate chose "scheduled runs only, one reused issue, auto-close on green" over "every failed run" because push and dispatch failures already have a person watching; falsified by a push-triggered publish failure going unnoticed for a week.

- 2026-09-03: implement gate chose "query the run's jobs with gh run view" for the failed-variant names over matrix outputs (undocumented empty-output overwrite behavior) and over naming only the run.
- 2026-09-03: T1+T2 done: script + stubbed-gh test (4 branches, plus cancelled-stays-silent and usage error); planted defects (no close; comment on newest not oldest) turned the test red; mapfile replaced by a read loop for macOS bash 3.2; pinned shellcheck 0.11.0 (docker) clean; pr-ci runs the test and lists the script path (the test file is under the existing scripts/** entry).
- 2026-09-03: T3 done: `notify` job appended to docker.yml (needs: build; if: always() && schedule; permissions issues:write + actions:read); build legs named `build (<variant>)` so `gh run view --json jobs` maps failed legs to variant names; actionlint (docker rhysd/actionlint, includes shellcheck on run blocks) clean; the jq filter checked against a synthetic jobs payload; CHANGELOG untouched.
- 2026-09-03: T4 pre-merge half done (actionlint + the `if:` read); the post-merge manual dispatch showing the job skipped is left to /milestone-review. Profile verify (hadolint + docker build) not run: no Dockerfile or build-context change on the branch.
- 2026-09-03: review fix-now (reviewer findings): notify step captures `gh run view` output and warns instead of silently dropping variant names on a listing error; `$GITHUB_RUN_ID` replaces the inline expression; a comment ties the build job name to the notify jq filter; the test asserts `--limit 100`, adds the no-variant fallback-title scenario, and fails loudly without jq.
- 2026-09-03: step-7 approval: PR #20 approved for merge; AC1 wording finding rejection accepted; AC3 dispatch clause to be evidenced post-merge on main; noble QEMU build failure to extend the existing candidate row.

## Decisions

## Review

2026-09-03, PR #20 (draft), branch synced with `origin/main` (no movement since cut).

- AC1: `bash scripts/tests/test_ci_failure_issue.sh` green on macOS bash 3.2 (create / comment-on-oldest / comment+close each / no writes, plus cancelled-silent, usage error, and the review-added no-variant fallback); the script's listing sorts ascending so "the first returned issue" is the oldest open one (#41 in the fixture), and the test asserts identity, not counts. Reviewer mutation probes: dropping `--force`, dropping `gh issue close`, reversing the sort, and the wrong issue number all turn the suite red. → ticked.
- AC2: `pr-ci.yml` runs the test (line 34) and its `paths` filter lists `.github/ci-failure-issue.sh` (line 16); the test file matches the pre-existing `scripts/**` entry (line 13), and PR #20's push triggered pr-ci. → ticked.
- AC3: `docker.yml` `notify` job: `needs: build`, `if: always() && github.event_name == 'schedule'`, calls the script with `needs.build.result`; actionlint clean. Manual dispatch on the branch (run 33819236280) was cancelled before its publish step, which cancelled `notify` before its condition was evaluated, so the run-summary skip is not yet shown; T4 places that dispatch post-merge (it publishes images). → not ticked pending the post-merge dispatch.
- AC4: `git diff origin/main..HEAD --name-only -- CHANGELOG.md` empty. → ticked.

Consistency gate: `cairn_validate.py` all checks pass (one pre-existing scaffold-deprecation advisory on the `.gitignore` references entry). Toolchain: local `docker build --build-arg UBUNTU_VERSION=24.04` succeeds (arm64 host, no cache); hadolint 2.12.0 (CI's pin) clean, hadolint latest reports the pre-existing DL3025 on Dockerfile:68; base image `rocker/r2u:${UBUNTU_VERSION}` tag-pinned; no credentials in Dockerfile; `.dockerignore` present (excludes `.git`, `.github`, `cairn`, `scripts/tests`); CHANGELOG entry not required (internal tier, AC4). No DESIGN principle changed.

Pre-existing, outside the diff, surfaced for the maintainer: the noble weekly build has failed on 2026-08-17, 2026-08-31, and today's branch dispatch at `quarto check install` (exit 132, QEMU SIGILL, 5 retries exhausted) in the arm64 leg — the alert will open an issue on the first scheduled run after merge; today's two main pushes failed at Docker Hub login (401) before the secret was updated at 23:27Z, and the branch dispatch logged in fine after.

Independent review (three-lens fan-out; surface tier slot absent). [S] blame-history and [S] prior-review-record reported no findings; the blame lens's one question (a required check pinned to the old job name) was checked: main has no branch protection and no rulesets. [O] diff-bug findings and disposition:
1. AC1 text "first returned issue" vs. comment-on-oldest — rejected: the script's own listing sorts by number, so its first returned issue is the oldest; the test the criterion names pins that.
2. AC3 dispatch clause unevidenced pre-merge — accepted: evidenced post-merge by the planned dispatch (T4).
3. AC2 "the test file" not listed explicitly — rejected: `scripts/**` covers it and the run triggered.
4. Failing `gh run view` silently drops variant names — fixed: output captured, warning annotation, fallback payload.
5. `--limit 100` unasserted — fixed: regex extended.
6. Empty-variant fallback untested — fixed: scenario 5 added.
7. Test needs jq with no guard — fixed: loud failure without jq.
8. `always()` also runs notify on cancel — rejected: `always()` is the criterion's text; the script's `*)` branch is silent.
9. Inline `${{ github.run_id }}` in a run block — fixed: `$GITHUB_RUN_ID`.
10. jq filter's coupling to the job name undocumented — fixed: comment on the build job name.
11. `name: build (<variant>)` claimed a no-op — rejected: pre-branch runs show the default `build (noble, 24.04, latest noble)`; the explicit name is load-bearing.
12. Inconsistent stdout suppression — rejected: cosmetic, the created-issue URL in the log is useful.
13. Missing blank line before `## Decisions` — fixed.
14. printf format-recycling note — rejected: advisory only.

PR CI: the first run's noble smoke failed on an r2u mirror connection timeout (transient, outside the diff); the run on the fix-now commit is green (build-smoke, shellcheck).
