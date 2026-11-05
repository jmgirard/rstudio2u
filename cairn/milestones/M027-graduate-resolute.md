# M027: Graduate resolute under a written rule

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP2, GP3, GP7
- **Resolves:** —
- **Surface tier:** user-facing — the README tells image users which tags are supported and when `latest` moves
- **Branch/PR:** m027-graduate-resolute

## Goal

Write down when a preview Ubuntu variant becomes a committed one, and graduate
`resolute`, which meets that rule today.

## Scope

**In:**
- The graduation rule in `cairn/DESIGN.md` (Purpose & Scope), with `noble` and
  `resolute` both committed, and the DESIGN text that calls resolute preview or
  the pull request lane noble-only.
- `.github/workflows/pr-ci.yml`: one job per variant (noble 24.04, resolute
  26.04), each building amd64, running `.github/smoke-test.sh`, and holding the
  image to its size limit; unit tests and hadolint in a job of their own, in a
  step whose name says it runs every script's unit tests (absorbs the candidate
  row "Rename the PR lane's unit test step").
- README text: both variants supported, `latest` scheduled to move to
  `resolute` on 2027-06-07, and how to stay on 24.04.
- Comments in `docker.yml`, `pr-ci.yml`, and `.github/image-size-limits` that
  call resolute preview tier or the lane noble-only. `docker.yml` keeps
  publishing each variant independently.

**Out:**
- Moving `latest` and `docker-compose.yml`'s `UBUNTU_VERSION` to 26.04 → the
  parked candidate row "Move latest to resolute on 2027-06-07".
- arm64 in the pull request lane → the candidate row "Pre-merge arm64 smoke in
  `pr-ci.yml`".

## Acceptance criteria

- [x] AC1: `cairn/DESIGN.md` states the graduation rule: a new Ubuntu LTS
      variant starts as a preview and becomes committed when (a) Ubuntu's
      `https://changelogs.ubuntu.com/meta-release-lts` lists that release at a
      `.1` or later version, (b)
      `https://r2u.stat.illinois.edu/ubuntu/dists/<codename>/Release` answers
      HTTP 200, and (c) the variant's two build jobs and its publish job
      concluded `success` in each of the 4 most recent scheduled `docker.yml`
      runs; it says that a pull request whose noble or resolute job in
      `pr-ci.yml` fails is not merged, and that the weekly rebuild still
      publishes each variant independently; it says that `latest` moves to a
      newly committed variant only on a date the README announces at least one
      academic term ahead; and it names `noble` and `resolute` as committed.
- [x] AC2: Each of AC1's three conditions holds for `resolute` on the day of
      review: under `Dist: resolute`, the meta-release-lts file has a
      `Version: 26.04.N LTS` line with N ≥ 1;
      `curl -s -o /dev/null -w '%{http_code}'` of the r2u `dists/resolute/Release`
      URL prints 200; and for each run that
      `gh run list --workflow docker.yml --event schedule --limit 4` lists,
      `gh run view <id> --json jobs` shows `build (resolute, amd64)`,
      `build (resolute, arm64)`, and `publish (resolute)` with conclusion
      `success`.
- [ ] AC3: On the milestone's own pull request, `pr-ci.yml` runs a separate job
      for each of noble and resolute, each job builds amd64, runs the smoke
      test, and runs the size check for its own variant, and both jobs conclude
      `success`.
- [ ] AC4: The resolute job of `pr-ci.yml` fails on a resolute-only defect in
      each of three forms, each planted alone on a temporary pull request that
      is closed unmerged and whose branch is deleted: a change that fails only
      the resolute build, a change that builds but makes only resolute's smoke
      test fail, and a resolute limit in `.github/image-size-limits` strictly
      between the noble amd64 and resolute amd64 sizes that AC3's run printed.
      In each run, `gh run view --json jobs` shows the expected step of the
      resolute job (build, smoke test, or size check) with conclusion
      `failure`, and the noble job with conclusion `success`.
- [x] AC5: README.md says that `noble` and `resolute` are both supported, that
      `latest` points at `noble` and is scheduled to move to `resolute` on
      2027-06-07, and that a user who wants to stay on Ubuntu 24.04 after that
      date should use the `noble` tag or an immutable `noble-` tag.
- [x] AC6: `git grep -n -i preview -- ':!cairn/milestones' ':!cairn/DECISIONS.md' ':!cairn/ROADMAP.md'`
      prints only lines in `scripts/install_rstudio.sh` (RStudio's preview
      release channel) and the rule's own definition in `cairn/DESIGN.md`; and
      every line that
      `git grep -n -i noble -- .github/workflows/pr-ci.yml .github/image-size-limits cairn/DESIGN.md`
      prints and that describes what the pull request lane builds also names
      resolute.
- [ ] AC7: The profile's verify slot is clean: `hadolint Dockerfile` reports
      nothing, and `docker build` succeeds with `UBUNTU_VERSION=24.04` and
      with `UBUNTU_VERSION=26.04`; each `test_*.sh` directly under
      `scripts/tests/` exits 0; and if `lint.yml` runs on the milestone's pull
      request, it concludes `success`.

## Coverage

- AC1 → T1
- AC2 → T1
- AC3 → T2
- AC4 → T5
- AC5 → T4
- AC6 → T1, T2, T3
- AC7 → T6

## Tasks

- [x] T1: Rewrite the variant paragraph in `cairn/DESIGN.md` Purpose & Scope
      (lines 19-22) as the rule in AC1; run AC2's three checks and note the
      results in the work log; update the image-size bullet (lines 141, 149-150)
      and any other DESIGN line AC6's greps print.
- [x] T2: Split `pr-ci.yml`'s `build-smoke` job into a `checks` job (unit tests
      in a step named for running every script's unit tests, and hadolint) and
      a `build-smoke` job with a `variant` matrix (`fail-fast: false`, job
      name `build-smoke (${{ matrix.variant }})`), each leg with its own
      `UBUNTU_VERSION`, image tag, gha cache scope, OCI archive, and size check;
      update the header and step comments.
- [x] T3: Update the comments in `docker.yml` (lines 97, 229) and the header of
      `.github/image-size-limits` (line 9) that call resolute preview or the
      lane noble-only; no behavior change.
- [x] T4: Add the README text in AC5 near the tag table (lines 12-19) and in
      Reproducibility (line 133).
- [x] T5: After the milestone PR's first green run, open the three probe pull
      requests in AC4 one at a time from branches off the milestone branch,
      record each run's job conclusions, close each unmerged and delete its
      branch.
- [x] T6: Run the verify slot and the unit tests locally (AC7).

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — a design decision (the graduation rule) plus a change to the pull request CI lane.
- 2026-11-05: idea vet: gap — whether graduation moves `latest`; reading taken from the set: `latest` stays on noble and is announced to move on 2027-06-07. gap — the trigger, and whether to graduate now when it is met; set chose the upstream-readiness rule and graduating now. No flaw. Earlier "native RStudio build" trigger dropped: rstudio.org serves the same jammy build for jammy, noble, and resolute (checked 2026-11-05).
- 2026-11-05: readiness at planning: meta-release-lts lists resolute at 26.04.1 LTS; r2u `dists/resolute/Release` answers 200; the 8 most recent scheduled `docker.yml` runs (2026-09-14 to 2026-11-02) concluded `success` for all three resolute jobs.
- 2026-11-05: collision check: extends M02 (noble-only PR lane, chosen because resolute was preview tier) and M026 (size check in the PR lane); absorbs the candidate rows "Define the resolute graduation path" and "Rename the PR lane's unit test step"; no D-entry covers variants. Inbox: 0 open issues, 0 open PRs.
- 2026-11-05: noted: a second PR-lane build doubles PR exposure to the r2u timeout in the parked row "Keep r2u timeouts from failing publish"; that row's promotion condition is unchanged.
- 2026-11-05: question set: graduation timing — graduate now; `latest` — announce now, move 2027-06-07; probe pull requests — user allowed three temporary PRs on GitHub, each closed unmerged with its branch deleted.
- 2026-11-05: plan gate chose a matrix job per variant over adding resolute steps to the one `build-smoke` job, because a job per variant gives each variant its own conclusion (AC4 reads it) and runs in parallel; falsified by a required check name breaking (main has no branch protection today).
- 2026-11-05: plan gate chose a 2027-06-07 move of `latest` over 2027-01-04, no date, and moving at merge, because a summer change gives instructors a full term's notice (GP1); falsified by users asking for the newer base sooner.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): 14 findings, all fixed in the wording above — ship-blocking made concrete; AC2's commands named; a job per variant required; probe PRs closed rather than deleted; size probe limit placed between the two sizes; step conclusions instead of log text; "scheduled to move"; the preview sweep widened to `git grep -i preview` with an allow-list and a noble-line sweep; lint conditional on running; build checked for both versions; tests limited to `scripts/tests/test_*.sh` (the posix/windows harnesses run in `launchers.yml`).
- 2026-11-05: lessons used: 2026-11-05 (M026) measuring a PR build's size by rerunning build-push-action with an OCI output; 2026-11-05 (M024) a plant counts as red only when the expected check fails; 2026-11-05 (M023) PR-only workflows need a pushed branch to see them fail.
- 2026-11-05: no release: docs and CI only under D-005; the 2027-06-07 move of `latest` is the major version.
- 2026-11-05: implement started on branch m027-graduate-resolute, cut from main at 585b4d5.
- 2026-11-05: T1 done: DESIGN Purpose & Scope names both variants committed and adds the graduation rule; image-size bullet names both amd64 images. AC2 checks on 2026-11-05: meta-release-lts `Version: 26.04.1 LTS`; r2u Release 200; scheduled runs 41460259596, 40318529715, 39245939988, 38259252021 each show the three resolute jobs `success`.
- 2026-11-05: T2 done: `pr-ci.yml` has a `checks` job (step renamed "Script unit tests", hadolint) and a `build-smoke (<variant>)` matrix job for noble 24.04 and resolute 26.04, each with its own cache scope, OCI archive, and size check; YAML parsed with Ruby (no actionlint here); the PR run is the real test.
- 2026-11-05: T3 done: the two `docker.yml` comments and the `image-size-limits` header no longer call resolute preview tier or the lane noble-only; comments only, and `test_image_size.sh` still passes. The `preview` sweep now prints only DESIGN's rule line and `install_rstudio.sh`.
- 2026-11-05: T4 done: README paragraph after the tag table (both supported, amd64 PR build and smoke test on both, `latest` scheduled to move 2027-06-07, pin `noble` to stay) and one sentence in Reproducibility. The simple-english hook reports 44 hits in README text that predates M027; the count did not change with these edits, and the old text is left as it is (out of scope).
- 2026-11-05: T6 run before T5 finished (T5 waits on CI): all 12 `scripts/tests/test_*.sh` exit 0; `hadolint/hadolint:v2.14.0` on the Dockerfile exits 0 with no output (hadolint is not installed here); local arm64 `docker build` succeeded for `UBUNTU_VERSION=24.04` and `26.04`.
- 2026-11-05: T5 started: probe PRs #39 (resolute-only build failure in `install_rstudio.sh`), #40 (Dockerfile removes `rserver` on resolute only), #41 (resolute limit 740) opened as drafts from branches off the milestone branch, under the plan's question-set permission.
- 2026-11-05: T5 done (minor amendment: run before the milestone PR exists, since review opens that PR only after approval; the size probe's own run printed both sizes): run 42115719986 resolute job failed at "Build resolute (amd64) for smoke test" with the planted message; run 42115724132 at "Smoke-test resolute (amd64)" ("FAIL: healthcheck reported unhealthy"); run 42115727824 at "Hold resolute (amd64) to its size limit" (759.3 MB over 740; noble 723.1 MB within 800). Noble job `success` in all three. PRs #39-#41 closed unmerged, branches deleted on origin and locally.
- 2026-11-05: claim audit: 19 claims read, 2 corrected — .github/workflows/pr-ci.yml (header said "then" for jobs that run in parallel; the unit-test comment read as covering every script); the corrected lines re-read TRUE by the same reader. Comments only, after the probe runs.
- 2026-11-05: implement complete; status review.
- 2026-11-05: review: evidence for AC1, AC2, AC4-AC7 and the gate recorded; AC3 and AC4's size comparison wait for the milestone PR's run at step 8; four review lenses spawned (in progress, checkpoint).
- 2026-11-05: review: 17 findings settled (6 fixed in a3510c7, 4 follow-up, 7 rejected); AC7 unticked again because the `image-size.sh` fix makes `lint.yml` run on the PR.
- 2026-11-05: step-7 approval: m027-graduate-resolute approved for merge

## Decisions

## Review

Evidence gathered 2026-11-05 on branch m027-graduate-resolute at 741c622, main unmoved (0 commits behind origin/main).

- AC1: `cairn/DESIGN.md` lines 19-41 name `noble` and `resolute` as committed and state conditions (a), (b), and (c) as worded, the not-merged rule for a failed noble or resolute `pr-ci.yml` job, independent weekly publishing, and the README-announced, one-term-ahead move of `latest`. Pass.
- AC2: meta-release-lts under `Dist: resolute` prints `Version: 26.04.1 LTS`; `curl -w '%{http_code}'` of r2u `dists/resolute/Release` prints 200; the 4 scheduled runs `gh run list` lists (41460259596 2026-11-02, 40318529715 2026-10-26, 39245939988 2026-10-19, 38259252021 2026-10-12) each show `build (resolute, amd64)`, `build (resolute, arm64)`, `publish (resolute)` = success. Pass.
- AC3: not yet observable. The milestone PR opens at step 8 after approval (D-138). Evidence comes from that PR's run, read at step 8 before the merge; the box stays unticked until then.
- AC4: runs re-read with `gh run view --json jobs`: 42115719986 (probe-m027-build) resolute job failure at "Build resolute (amd64) for smoke test", noble success; 42115724132 (probe-m027-smoke) resolute failure at "Smoke-test resolute (amd64)", noble success; 42115727824 (probe-m027-size) resolute failure at "Hold resolute (amd64) to its size limit", noble success. PRs #39-#41 read CLOSED with `mergedAt` null; `git ls-remote --heads origin 'probe-*'` lists 0 branches. The probes ran on the branch at 9c404c5; later `pr-ci.yml` changes are comments only. The size probe's limit of 740 MB sat between that run's noble 723.1 MB and resolute 759.3 MB. "Strictly between the sizes AC3's run printed" is checked against the step-8 run; the box stays unticked until then.
- AC5: README.md:21 says both tags are supported, `latest` points at `noble`, is scheduled to move to `resolute` on 2027-06-07, and to stay on 24.04 use `noble` or an immutable `noble-` tag; README.md:136-137 repeats the date. Pass.
- AC6: the `preview` sweep prints DESIGN.md:27 (the rule's definition) and `scripts/install_rstudio.sh`:6 and :70 (RStudio's release channel), nothing else. The `noble` sweep's lines that describe the PR lane (`image-size-limits`:9, `pr-ci.yml`:4, DESIGN.md:157, 165-166) each name resolute; the rest are limit values, measured sizes, a command, the matrix entry, and the committed-variant text. Pass.
- AC7: all 12 `scripts/tests/test_*.sh` exit 0; `hadolint/hadolint:v2.14.0` on the Dockerfile exits 0 with no output; local `docker build` succeeds for 24.04 and 26.04. `lint.yml` triggers only on `**.sh`, `**.command`, and `lint.yml`, and the diff touches none of them, so it does not run on this PR. Pass.
- AC7 (superseded): the fix-now edit to `.github/image-size.sh` (a `**.sh` path) means `lint.yml` now runs on this PR. AC7 is unticked again and is read from that run at step 8. The verify slot and unit tests are re-run after the fix-now commit.
- Gate: `cairn_validate.py` all checks passed (1 advisory: the old pdf `.gitignore` entry, which has a candidate row). No principle text changed, so `cairn_impact` is skipped. Toolchain: hadolint clean, build clean, base pinned (`FROM rocker/r2u:${UBUNTU_VERSION}`, version tags), no secret added in the diff, `.dockerignore` present; changelog none, so the user-visible change goes in the archive summary.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: AC3 has no evidence from the milestone's own PR — reject (false): AC3 is read at step 8 from that PR's run before any merge, and its box stays unticked until then.
- diff-bug #2: "is not merged" rests on no branch protection — fix now: DESIGN says it is the repo's never-merge-red rule, not a protection setting., fixed a3510c7
- diff-bug #3: `.github/image-size.sh` header still says pr-ci sizes "the image it builds" — fix now: names the noble and resolute amd64 images., fixed a3510c7
- diff-bug #4: the "Script unit tests" step is a hand-written list, so a new test file runs nowhere — follow-up: new [low] row "Run every unit test in the PR lane" (a maintainer adding a test meets it; low because none is pending).
- diff-bug #5: README does not tell launcher users that they switch on the date or how to stay — fix now: README says the launchers switch at their first online start after 2027-06-07 and to put a `noble` tag in `docker-compose.yml`'s `image:` line (the launchers run `docker compose pull` at each start)., fixed a3510c7
- diff-bug #6: the graduation rule has no D-entry — fix now: D-012., fixed a3510c7
- diff-bug #7: rewrapped DESIGN lines run past 80 columns; "(M027)" mid-sentence — reject (style).
- diff-bug #8: `checks` and the image jobs now run in parallel, so a lint failure no longer saves runner time — reject (planned change): the plan chose parallel per-variant jobs.
- diff-bug #9: uncommitted milestone-file edit — reject (false): committed as f41bb80 before the reviewers' reads ended.
- blame-history #1: the preview-tier decision is reversed with no DECISIONS entry — fix now: D-012 (same fix as diff-bug #6)., fixed a3510c7
- blame-history #2: DESIGN's merge rule reads as covering arm64 though the PR jobs build amd64 only — fix now: DESIGN says the PR job builds the amd64 image and arm64 is checked at publish., fixed a3510c7
- blame-history #3: GP1 cited for the `latest` timing rule — reject (false): the launchers pull `latest`, so the move's timing is a double-click path concern.
- blame-history #4: the README date has no mechanism in code — reject (planned change): the plan's Out sends the move to the parked row "Move latest to resolute on 2027-06-07".
- prior-review #1: the M026 gap "Measure the build that smoke tested" now covers resolute too — follow-up: that parked row now names `rocker/r2u:26.04` (same edit as ripple #1).
- prior-review #2: a new `#reproducibility` anchor may not work on Docker Hub — reject (false): README.md:19 on main already links that anchor.
- ripple #1: ROADMAP row "Measure the build that smoke tested" names only `rocker/r2u:24.04` — follow-up: row text extended to 26.04.
- ripple #2: GP3 allows an asymmetry only when an upstream forces it, but the amd64-only PR lane is chosen and cites GP3 (predates M027) — follow-up: added to the [low] row "Pre-merge arm64 smoke in `pr-ci.yml`".
- After the fixes (a3510c7): all 12 `scripts/tests/test_*.sh` exit 0; `koalaman/shellcheck:v0.11.0 -x -S info` (lint.yml's pinned version and flags) on `.github/image-size.sh` exits 0; the Dockerfile and `scripts/` are unchanged since the local builds, so no rebuild. Changed snapshot files: none (`git diff --name-only` lists no `_snaps` or `__snapshots__` path).
