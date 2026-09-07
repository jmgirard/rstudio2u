# M016: Keep the weekly rebuild alive

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** user-facing — it protects the moving tags' always-fresh commitment and adds commits to the repo's public history
- **Branch/PR:** `m016-weekly-rebuild-keepalive`

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
- [ ] AC2: Driven against a call-logging `git` stub, the script behaves as AC1
      states for each of: an age one day below the threshold, an age exactly at
      it, an age one day above it, an absent argument in each of the three
      positions, a non-date value in each of the first two positions, a
      non-integer third argument, and a commit date one day after the current
      date. On every skip and every rejection the stub's call log is empty.
- [ ] AC3: The `keepalive` job in `.github/workflows/docker.yml` runs on
      `schedule` and `workflow_dispatch` events and on no other event; its
      `permissions:` block grants `contents: read` and no write scope; and it
      pushes with a credential held in a repository secret and scoped to this
      repository, never the workflow's own token.
- [ ] AC4: One `workflow_dispatch` run with the threshold input set to `0`
      moves the default branch by exactly one commit whose diff against its
      parent is empty and whose message identifies it as a keepalive —
      evidenced by the run URL and by the branch tip before and after. A
      `workflow_dispatch` run with the input unset does not move the default
      branch — evidenced by the keepalive job's log recording a skip and by the
      tip being identical before and after.
- [ ] AC5: `.github/keepalive.sh` and `scripts/tests/test_keepalive.sh` pass
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
- [ ] T4: Run `scripts/tests/test_keepalive.sh` from `pr-ci.yml`'s unit-test
      step and add `.github/keepalive.sh` to that workflow's `paths` filter
      (`.github/workflows/**` already matches, the script does not).
- [ ] T5: Hand the maintainer the exact steps to create a push credential
      scoped to this repository and store it as the secret T3 reads; the
      maintainer creates it — cairn never handles credentials — and the
      milestone waits on it before T7.
- [ ] T6: Record the keepalive in `cairn/DESIGN.md` Conventions, and in its
      Known issues the exposure this does not remove: the mechanism rests on
      GitHub continuing to count a pushed commit as repository activity, which
      this repo cannot test.
- [ ] T7: Run AC4's two dispatches from the milestone branch; record both run
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
- 2026-09-06: plan gate chose 50 days over 30 and 55 because it leaves two weekly runs of margin before the 60-day cutoff at roughly one commit per quiet period; falsified by a weekly run missing often enough that two are not reliably available.

## Decisions

## Review
