# M027: Graduate resolute under a written rule

- **Status:** in-progress
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

- [ ] AC1: `cairn/DESIGN.md` states the graduation rule: a new Ubuntu LTS
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
- [ ] AC2: Each of AC1's three conditions holds for `resolute` on the day of
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
- [ ] AC5: README.md says that `noble` and `resolute` are both supported, that
      `latest` points at `noble` and is scheduled to move to `resolute` on
      2027-06-07, and that a user who wants to stay on Ubuntu 24.04 after that
      date should use the `noble` tag or an immutable `noble-` tag.
- [ ] AC6: `git grep -n -i preview -- ':!cairn/milestones' ':!cairn/DECISIONS.md' ':!cairn/ROADMAP.md'`
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
- [ ] T5: After the milestone PR's first green run, open the three probe pull
      requests in AC4 one at a time from branches off the milestone branch,
      record each run's job conclusions, close each unmerged and delete its
      branch.
- [ ] T6: Run the verify slot and the unit tests locally (AC7).

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

## Decisions

## Review
