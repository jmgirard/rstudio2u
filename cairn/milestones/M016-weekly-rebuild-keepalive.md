# M016: Keep the weekly rebuild alive

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** user-facing — it protects the moving tags' always-fresh commitment and adds commits to the repo's public history
- **Branch/PR:** `m016-weekly-rebuild-keepalive` / https://github.com/jmgirard/rstudio2u/pull/23

## Goal

A default branch left quiet for weeks gets an automated empty commit, so
GitHub's 60-day inactivity rule cannot silently disable the weekly rebuild.

## Scope

**In:** `.github/keepalive.sh` holding the whole staleness rule and the commit
it produces; its offline unit test; a `keepalive` job in
`.github/workflows/docker.yml` that runs it on schedule and on dispatch, using
a repository-scoped push credential the maintainer creates; the PR-lane wiring
for the new test; DESIGN records for the mechanism and its residual exposure.

**Out:** detecting a rebuild that stopped for some *other* reason (a gap check
over the last successful scheduled run) → `candidate` row, planned later.
Confirming that GitHub's inactivity counter actually resets → not observable
from this repo on any timescale this milestone spans; recorded as a known
issue by T6, and no criterion below claims it.

## Acceptance criteria

- [ ] AC1: `.github/keepalive.sh <commit-date> <current-date> <threshold-days>`
      creates one empty commit on the default branch and pushes it when the
      commit date is the threshold's days or more before the current date, and
      makes no git call and reports that it skipped when it is fewer. An
      argument that is absent, that is not an ISO-8601 `YYYY-MM-DD` date (the
      first two), or that is not a non-negative integer (the third) exits
      non-zero naming which argument it rejected; so does a commit date later
      than the current date.
- [x] AC2: Driven against a call-logging `git` stub, the script behaves as AC1
      states for each of: an age one day below the threshold, an age exactly at
      it, an age one day above it, an absent argument in each of the three
      positions, a non-date value in each of the first two positions, a
      non-integer third argument, and a commit date one day after the current
      date. On every skip and every rejection the stub's call log is empty.
- [x] AC3: The `keepalive` job in `.github/workflows/docker.yml` runs on
      `schedule` and `workflow_dispatch` events and on no other event; its
      `permissions:` block grants `contents: read` and no write scope; and it
      pushes with a credential held in a repository secret and scoped to this
      repository, never the workflow's own token.
- [x] AC4: One `workflow_dispatch` run with the threshold input set to `0`
      moves the default branch by exactly one commit whose diff against its
      parent is empty and whose message identifies it as a keepalive —
      evidenced by the run URL and by the branch tip before and after. A
      `workflow_dispatch` run with the input unset does not move the default
      branch — evidenced by the keepalive job's log recording a skip and by the
      tip being identical before and after.
- [x] AC5: `.github/keepalive.sh` and `scripts/tests/test_keepalive.sh` pass
      `shellcheck` at the floor `.github/workflows/lint.yml` pins, and the
      PR-CI lane on this milestone's branch is green.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T3, T5
- AC4 → T3, T5, T7
- AC5 → T1, T2, T4

## Tasks

- [x] T1: Write `.github/keepalive.sh` — three positional arguments, per-argument
      validation for each class AC1 names (each rejection naming the argument
      it rejected), the age comparison, and on the push branch a
      `git commit --allow-empty` with an identity and a message set in the
      script, then `git push`. The staleness comparison lives only here, never
      in the workflow (the `.github/ci-failure-issue.sh` pattern).
- [x] T2: Write `scripts/tests/test_keepalive.sh` with a call-logging `git`
      stub covering every case AC2 lists. Then show the suite able to fail:
      plant, separately, an inverted comparison, an off-by-one at the
      threshold, a skip path that still calls `git commit`, and a validator
      that accepts a bad value in the wrong argument position — recording each
      planted defect and its red run in this file.
- [x] T3: Add the `keepalive` job to `.github/workflows/docker.yml`: `if:`
      limited to `schedule` and `workflow_dispatch`, `permissions: contents:
      read`, a checkout authenticated with the secret from T5, a
      `keepalive_threshold` dispatch input defaulting to 50, and the call to
      `.github/keepalive.sh` with the branch's newest commit date and today's
      UTC date.
- [x] T4: Run `scripts/tests/test_keepalive.sh` from `pr-ci.yml`'s unit-test
      step and add `.github/keepalive.sh` to that workflow's `paths` filter
      (`.github/workflows/**` already matches, the script does not).
- [x] T5: Hand the maintainer the exact steps to create a push credential
      scoped to this repository and store it as the secret T3 reads; the
      maintainer creates it — cairn never handles credentials — and the
      milestone waits on it before T7.
- [x] T6: Record the keepalive in `cairn/DESIGN.md` Conventions, and in its
      Known issues the exposure this does not remove: the mechanism rests on
      GitHub continuing to count a pushed commit as repository activity, which
      this repo cannot test.
- [x] T7: Run AC4's two dispatches from the milestone branch; record both run
      URLs and both tip comparisons.

## Work log

- 2026-09-06: created by /milestone-plan; absorbed the 2026-09-03 candidate row.
- 2026-09-06: criteria audit ran in FULL mode ([O] fresh reader) — returned findings on all four drafted criteria: open-ended "malformed input" domain, AC2 binding test-harness rather than script properties, one-exemplar rejection probes, AC3's mandated evidence quotation, AC4 unsatisfiable against AC1's own staleness rule, and AC4's unbounded "pushes nothing"; all repaired above, plus a reachability blocker (the repo's workflow token is read-only) taken to the gate.
- 2026-09-06: plan gate chose an automated empty keepalive commit over a documented manual check because the manual check leaves the guarded failure dependent on recall; falsified by evidence that GitHub does not count a bot-pushed commit as repository activity.
- 2026-09-06: plan gate chose an empty commit over a dated stamp file because the stamp file adds a tracked file existing only to be touched; falsified by evidence that tooling on this repo's path ignores empty commits.
- 2026-09-06: plan gate chose a repository-scoped push credential over raising the repo-wide workflow write permission because the latter widens the ceiling for every present and future workflow; falsified by the credential proving unrenewable in practice.
- 2026-09-06: implement gate chose a repository deploy key over a fine-grained account token (repo-scoped by construction, no expiry to lapse silently), and the `github-actions[bot]` identity for the commit.
- 2026-09-06: T1 — `.github/keepalive.sh` written: three validated positional arguments, dates converted in shell arithmetic (no `date` flag portability, and an impossible date like 2026-02-30 is rejected, not only a mis-shaped one); stale means exactly `git commit --allow-empty` + `git push`, fresh means no git call.
- 2026-09-06: T2 — `scripts/tests/test_keepalive.sh`, 74 assertions, all green offline against a call-logging `git` stub (asserted first on PATH, so "no git call" cannot pass by running nothing).
- 2026-09-06: T2 discrimination — four defects planted in a copy of the script, each run red: an inverted comparison (12 assertions), an off-by-one making the at-threshold case skip (8, and none of the below-threshold ones), a skip path that still calls `git commit` (1 — the "no git call" assertion alone), and the second date validator re-reading argument 1 so a bad argument 2 passes (21).
- 2026-09-06: T3 — `keepalive` job added to `docker.yml`: `if:` admits only `schedule` and `workflow_dispatch`, `permissions: contents: read`, checkout of `github.event.repository.default_branch` with `ssh-key: secrets.KEEPALIVE_DEPLOY_KEY`, and a `keepalive_threshold` dispatch input defaulting to 50. Both dates are taken in UTC (`TZ=UTC git log --date=format-local`, `date -u`) so the comparison cannot straddle a timezone.
- 2026-09-06: T4 — `pr-ci.yml` runs `scripts/tests/test_keepalive.sh` in its unit-test step and lists `.github/keepalive.sh` in its `paths` filter.
- 2026-09-06: T6 — DESIGN Conventions records the keepalive mechanism; DESIGN Known issues records the untestable assumption that GitHub counts a pushed commit as the activity that defers the cutoff.
- 2026-09-06: candidate row added — a failing `keepalive` job is not reported, because `notify` aggregates only meta/build/publish. Adding it there would change the ci-failure alert's shape, so it is deferred rather than folded in.
- 2026-09-06: T5 handed to the maintainer — generate an ed25519 keypair, add the public half as a write-enabled deploy key titled `keepalive`, store the private half as the repository secret `KEEPALIVE_DEPLOY_KEY`. Confirmed beforehand: `main` is unprotected, the repo-wide Actions workflow permission is `read`, and no deploy key or such secret exists yet. T7 waits on it.
- 2026-09-07: T7 first dispatch (run 34080941702) failed the keepalive job with `./.github/keepalive.sh: No such file or directory` — the job checked out only the default branch, which does not carry the script until this milestone merges. The offline suite cannot see this; AC4 is the criterion that caught it. Fixed by two checkouts: the workflow's own ref at the workspace root (rule read from there, `persist-credentials: false`) and the default branch under `default-branch/` with the deploy key (commit lands there). The deploy key and the SSH checkout worked on that run.
- 2026-09-07: T5 done by the maintainer — deploy key `keepalive` (read-write, id 162497767) and repository secret `KEEPALIVE_DEPLOY_KEY` both present.
- 2026-09-07: T7 threshold-0 dispatch, run https://github.com/jmgirard/rstudio2u/actions/runs/34081029032 — keepalive job green; `main` 8970ea5 -> 8f86753, one commit, `git diff 8f86753^ 8f86753` is 0 lines, subject `keepalive: empty commit to keep scheduled workflows enabled`, author and committer `github-actions[bot]`.
- 2026-09-07: T7 threshold-unset dispatch, run https://github.com/jmgirard/rstudio2u/actions/runs/34081061782 — keepalive job green, log line `the newest commit is 0 day(s) old, below the 50-day threshold; no keepalive commit`; `main` 8f86753 before and 8f86753 after. Both runs' build legs were cancelled once the keepalive job finished (test mode, so no tag could move either way).
- 2026-09-07: merged `origin/main` (the keepalive commit) into the branch; re-ran every suite green, shellcheck 0.11.0 `-S info` clean over all 28 tracked shell files, hadolint 2.12.0 clean. No Dockerfile or build-context change in this milestone (`.dockerignore` excludes `.github` and `scripts/tests`), so no image build was run.
- 2026-09-06: plan gate chose 50 days over 30 and 55 because it leaves two weekly runs of margin before the 60-day cutoff at roughly one commit per quiet period; falsified by a weekly run missing often enough that two are not reliably available.
- 2026-09-07: review — all five criteria verified with fresh evidence (Review section); consistency gate clean, cairn_validate exit 0; PR #23 opened, CI green after one re-run of a build-smoke leg that failed on an r2u mirror outage.
- 2026-09-07: review returned M016 to in-progress — defect return 1. AC1 fails inside its own domain: a 19-digit threshold (a non-negative integer AC1 does not reject) wraps in shell arithmetic, so `.github/keepalive.sh 2026-01-01 2026-02-19 9999999999999999999` commits and pushes where AC1 requires no git call. Four further repairs and four follow-ups recorded in the Review section; AC2-AC5 keep their evidence.

## Decisions

## Review

_Fresh evidence gathered 2026-09-07 on `m016-weekly-rebuild-keepalive` at f243c8b, PR #23._

**AC1 — verified.** `.github/keepalive.sh` driven directly against a real git
repository in a scratch directory (a bare remote plus a working clone, one seed
commit). Stale (`2026-01-01 2026-04-11 50`): exit 0, tip moved by exactly one
commit (b556cd7 -> b83efb7, `git rev-list --count` 1 -> 2), `git diff HEAD^ HEAD`
0 lines, subject `keepalive: empty commit to keep scheduled workflows enabled`,
author and committer `github-actions[bot]`, and the bare remote's `main` at the
same sha — so it pushed. Fresh (`2026-01-01 2026-02-19 50`): exit 0, the line
`the newest commit is 49 day(s) old, below the 50-day threshold; no keepalive
commit`, tip and commit count unchanged. Seven rejections each exited 2 naming
their argument: an absent argument 1, a single-digit month-and-day form and
`2026-02-30` in argument 1,
a non-date argument 2, `-1` and an omitted argument 3, and a commit date one day
after the current date (`the commit date (argument 1) is later than the current
date`). The tip was unchanged across all seven.

**AC2 — verified.** `bash scripts/tests/test_keepalive.sh` exits 0 with 74 `ok:`
lines and 0 `FAIL` lines (`PASS: all keepalive assertions`). Read against AC2's
list, the suite drives each named case: 49/50/51 days against a 50-day threshold
(cases 1-3), an absent argument in each of the three positions plus the omitted
and no-argument forms (case 6), `yesterday`, a single-digit month-and-day form,
`2026-02-30` and `2026-13-01` in each of the first two positions (case 7), `-1`, `5.5`, `fifty`,
a space and `50days` as argument 3 (case 8), and a commit date one day after the
current date (case 9). Every skip and every rejection carries an `assert_no_git`
on an empty stub log, and the stub is asserted first on PATH before any case
runs, so "no git call" cannot pass by finding no git at all. Discrimination
re-checked fresh against a scratch copy: an inverted comparison went red with 13
failed assertions, an off-by-one making the at-threshold case skip with 9, and
argument 2's validator re-reading argument 1 with 22; the restored control ran
green (0 failures).

**AC3 — verified.** `.github/workflows/docker.yml` parsed with PyYAML rather
than read by eye. The workflow's triggers are `push`, `schedule` and
`workflow_dispatch`; the `keepalive` job's `if:` is
`github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'`,
so the `push` trigger — the only other one — cannot reach it. Its
`permissions:` block is exactly `{contents: read}`; the workflow declares no
top-level `permissions:`, and the repo-wide default is
`default_workflow_permissions=read` (`gh api
repos/jmgirard/rstudio2u/actions/permissions/workflow`), so no write scope is
granted anywhere on the path. The push is authenticated by
`ssh-key: ${{ secrets.KEEPALIVE_DEPLOY_KEY }}` on the second checkout; that
secret exists on the repository (`gh api .../actions/secrets`, updated
2026-09-07) and its public half is the repository deploy key `keepalive`
(id 162497767, `read_only=false`, `verified=true`) — a deploy key reaches only
the repository it is attached to. The workflow's own token appears nowhere in
this job: the only `secrets.GITHUB_TOKEN` reference in the file is line 347, in
`notify`, and the first checkout sets `persist-credentials: false` so the token
is not left in the tree the script runs from.

**AC4 — verified.** Both dispatch runs re-read fresh with `gh run view`, not
from the implementation notes. Threshold `0`:
https://github.com/jmgirard/rstudio2u/actions/runs/34081029032 —
`event=workflow_dispatch`, keepalive job `conclusion=success`, log lines
`default branch tip is dated 2026-09-07; today is 2026-09-07 (UTC)`, `the newest
commit is 0 day(s) old, at or past the 0-day threshold; committing`, `pushed a
keepalive commit`. The default branch moved 8970ea5 -> 8f86753, one commit;
`git diff 8f86753^ 8f86753` is 0 lines, its parent is 8970ea5, its subject is
`keepalive: empty commit to keep scheduled workflows enabled`, and its author
and committer are `github-actions[bot]` (commit date 2026-09-07T03:51:07Z,
inside that run's 03:51:04-03:51:10 window). Threshold unset:
https://github.com/jmgirard/rstudio2u/actions/runs/34081061782 — same event,
keepalive job `conclusion=success`, log line `the newest commit is 0 day(s) old,
below the 50-day threshold; no keepalive commit` and no `committing` or `pushed`
line. `origin/main` is 8f86753 both before that run (the commit the first run
made) and now, after `git fetch` — unchanged.

**AC5 — verified.** `.github/workflows/lint.yml` pins shellcheck 0.11.0 and runs
it as `shellcheck -x -S info`. Run locally at that exact version through
`koalaman/shellcheck:v0.11.0` (`version: 0.11.0`): the two files named by the
criterion exit 0, and so does the workflow's own whole enumeration —
`git ls-files -z '*.sh' '*.command'` over 28 tracked files, exit 0. CI on PR #23:
`shellcheck` pass (run 34081227702), `build-smoke` pass in 3m17s (run
34081227703, job 101617436244). The first `build-smoke` attempt failed after
3m38s on an external mirror outage — `Could not connect to
r2u.stat.illinois.edu:443 (192.17.190.167), connection timed out`, and the smoke
test's own message says the r2u mirror looks unreachable — not on anything this
branch changed; `gh run rerun --failed` passed with no code change.

### Consistency gate

- `cairn_validate.py` exits 0 — every check PASS. One advisory WARN, not a gate
  failure: the `.gitignore` entry `cairn/references/pdf/` is superseded by
  `cairn/references/sources/`, already carried as a ROADMAP candidate row. An
  earlier run FAILed `iso date format` on two malformed-date exemplars quoted in
  this Review section's own prose; the exemplars were reworded, not the finding
  waived.
- `cairn_impact.py` not run: this milestone changes no numbered DESIGN principle
  — the `cairn/DESIGN.md` diff adds one Conventions bullet and one Known issues
  entry, both unnumbered.
- Toolchain checks, from the `docker-image` profile's `consistency-gate` slot:
  `hadolint` 2.12.0 over the Dockerfile exits 0; `docker build` from a clean
  context succeeds — the PR's green `build-smoke` job, which builds the image and
  runs the container smoke test; the base image is pinned to an explicit version
  tag (`ARG UBUNTU_VERSION=24.04`, `FROM rocker/r2u:${UBUNTU_VERSION}`), never
  `latest`; no secret is baked into a layer (no token/password/key in any `ENV`,
  `ARG` or `COPY` — `PASSWORD` is a runtime variable read by the init scripts);
  `.dockerignore` is present and excludes `.git`, `.github`, `cairn`, and
  `scripts/tests`. The `changelog` slot declares none as a file, so this
  milestone's user-visible change is stated in its archive summary.

### Independent review (three fresh-context lenses)

`[O]` diff-bug, `[S]` blame-history and `[S]` prior-review record, spawned with
distinct evidence bases, none having seen the implementation. Every reported
finding and its disposition:

**[O]-6 — RETURN. A threshold above 18 digits inverts the staleness rule.**
`.github/keepalive.sh:95` accepts any `^[0-9]+$` with no bound and `:108`
evaluates `10#$threshold` in 64-bit shell arithmetic. Reproduced here against a
real git repository: `.github/keepalive.sh 2026-01-01 2026-02-19
9999999999999999999` printed `the newest commit is 49 day(s) old, at or past the
9999999999999999999-day threshold; committing`, made the commit and pushed it.
`9999999999999999999` is a non-negative integer, so AC1's rejection clause does
not cover it; the age (49) is fewer than the threshold, so AC1 requires no git
call and a reported skip. The script committed and pushed instead. That is AC1
failing inside its own domain, so this is a defect return under the review
return floor. Repair: bound argument 3 to a value the arithmetic can hold and
reject the rest, naming argument 3 — and drive it in the suite.

**[O]-1 — follow-up (existing candidate row strengthened). A failed `keepalive`
job on a scheduled run does not just go unreported; the run closes the ci-failure
issue.** `.github/workflows/docker.yml:328-330`: `notify` has
`needs: [meta, build, publish]` and passes only those three into `RESULTS`, so a
scheduled run whose builds pass and whose keepalive fails collapses to all-success
and closes the issue while the guard is broken. Confirmed by reading the job. The
`[S]` blame lens reported the same gap independently. Already carried as a
candidate row from implementation; the row is extended with the closing behaviour,
which it did not state.

**[O]-2 — fix on return. DESIGN overstates the margin the 50-day threshold buys.**
`cairn/DESIGN.md` says the threshold leaves "two weekly runs of margin". The
window in which a weekly run can fire and still commit is ages 50 through 59 —
ten days — and ten consecutive days contain either one or two weekly runs
depending on the phase, so the worst case is one, not two. The threshold itself is
not in question; the claim about it is wrong and is fixed with the return.

**[O]-7 — fix on return. The suite does not assert what the script claims.**
`.github/keepalive.sh:29-30` says the stale path is "exactly two git calls", and
`scripts/tests/test_keepalive.sh:99-102` asserts only that some logged call
matches each regex — an added `git config` or a `push` issued before the `commit`
would pass green. Either the assertion names the two calls in order or the comment
stops claiming it.

**[O]-8 — fix on return. The more-than-three-arguments rejection is untested.**
`.github/keepalive.sh:85` exits 2 on a fourth argument; no case in the suite
drives it and AC2's enumeration does not name it.

**[O]-10 — fix on return. D-008's Consequences paragraph is stale.** It says the
credential "must be renewed before it expires"; the implement gate chose a deploy
key because it does not expire. Reported independently by the `[S]` prior-review
lens. History is superseded, never edited: this takes a new D-entry annotating
D-008.

**[O]-3 — follow-up (new candidate row). The keepalive `git push` has no
contention handling.** `.github/keepalive.sh:123` is a bare `git push` from a
shallow checkout with no `concurrency:` group in `docker.yml`; a maintainer push
landing between checkout and push fails non-fast-forward with no retry, and per
[O]-1 no alarm. Real, but it fails safe — the next scheduled run retries — and it
falsifies no criterion.

**[O]-11 — follow-up (new candidate row). Only the dispatch path has ever run.**
Both AC4 runs are dispatches; the scheduled path depends on `inputs` being null
(falling back to `'50'`) and on `github.event.repository.default_branch` being
populated in a schedule payload. AC4 asks for dispatches only, so this fails no
criterion, but the first dispatch already caught one ref defect the offline suite
could not see, and the first scheduled run is worth reading.

**[O]-9 — follow-up (folded into the [O]-3 row). The git stub always exits 0**, so
`scripts/tests/test_keepalive.sh:28-32` cannot exercise a failing `git commit` or
`git push` — the failure mode [O]-3 describes.

**[O]-4 — rejected.** A `workflow_dispatch` from any branch runs that branch's
`keepalive.sh` against the default branch, where `dockerhub-description.yml:25`
guards the analogous case with `if: github.ref == 'refs/heads/main'`. This is the
two-checkout design the milestone planned, and it is what made T7's verification
from the milestone branch possible at all; dispatching already requires write
access to the repository, so it widens no trust boundary. An intentional change
the plan called for.

**[O]-5 — rejected.** `inputs.keepalive_threshold || '50'` turns an emptied
dispatch field into 50 rather than AC1's "argument 3 is missing" rejection. The
fallback is required for the scheduled run, where the `inputs` context is null;
AC1's missing-argument branch is a property of the script and is driven by the
suite, not by this caller.

**[O]-12 — rejected.** Leading zeros in the threshold echo verbatim
(`the 0050-day threshold`). Pure cosmetics; the comparison is unaffected.

**[O]-13 — rejected, resolved.** AC5 could not be checked by the reviewer, which
had no `shellcheck`. Verified here at the pinned 0.11.0 through
`koalaman/shellcheck:v0.11.0`; see the AC5 evidence above.

**[S] blame-history — no defects.** Its six items are confirmations rather than
findings: the `notify` gap ([O]-1 above), the dispatch exposure ([O]-4 above), the
second checkout's deliberate omission of `persist-credentials: false` (required
for the push to authenticate), D-008 honoured precisely, the `pr-ci.yml` paths and
test-step wiring following the `ci-failure-issue.sh` precedent, and `docker.yml`'s
own `push.paths` correctly not listing a script that cannot affect the image.

**[S] prior-review record — no findings.** No archived `## Review` finding on the
touched files is reintroduced or contradicted; M02's "path filter omits its own
harness script" lesson is honoured. The GitHub probe
(`repos/jmgirard/rstudio2u/pulls/comments?per_page=1`) returned `[]`, so the
per-PR walk was correctly skipped.

### Gate outcome

Returned to `in-progress` on [O]-6, which demonstrates AC1 failing inside its own
domain. AC1's tick is removed; the other four criteria keep their evidence and
their ticks. Not merged; PR #23 stays a draft. Defect returns for this milestone
so far: 1.
