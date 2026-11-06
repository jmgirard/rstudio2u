<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M033: Smoke-test arm64 in the PR lane

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP5, GP7
- **Resolves:** —
- **Surface tier:** user-facing — README tells users which builds a pull request is checked on before it merges
- **Branch/PR:** m033-arm64-pr-smoke

## Goal

Build, boot, and size-check each committed variant's arm64 image on a native arm64 runner in `pr-ci.yml`, so an arm64-only break fails the pull request instead of the publish.

## Scope

**In:** `.github/workflows/pr-ci.yml`'s `build-smoke` matrix grows from one job per variant (amd64) to one job per variant and architecture, each on a runner of its own architecture, with a runner architecture check before the build. Text that says the pull request lane is amd64 only is updated: `README.md`, `cairn/DESIGN.md` (graduation paragraph, size-limit bullet), comments in `pr-ci.yml`, `.github/image-size.sh`, `.github/image-size-limits`, `.github/smoke-test.sh`, and the parked ROADMAP row "Measure the build that smoke tested". Temporary draft probe PRs with planted defects (approved at the plan gate).

**Out:** running every unit test file in the PR lane → candidate row "Run every unit test in the PR lane". Measuring the exact build that smoke tested → parked row "Measure the build that smoke tested". Changes to `docker.yml`'s publish legs → none planned. A release → none (CI and docs only, D-005).

## Acceptance criteria

- [ ] AC1: `.github/workflows/pr-ci.yml`'s `build-smoke` matrix has exactly four entries, one for each of noble and resolute on each of amd64 and arm64. Each amd64 entry runs on `ubuntu-latest` and each arm64 entry on `ubuntu-24.04-arm`. Each entry builds only `linux/<arch>`, reads the gha cache scope `<variant>-<arch>`, and is named `build-smoke (<variant>, <arch>)`, as a read of the file at the head that merges shows.
- [ ] AC2: Each `build-smoke` job fails before its build unless `uname -m` on the runner prints the job's architecture (`x86_64` for amd64, `aarch64` for arm64). It then builds its image, boots it with `.github/smoke-test.sh`, and holds it to its variant's limit with `.github/image-size.sh --from-oci <variant> <arch>`. In the milestone PR's `PR CI` run at the head that merges, each of the four jobs concludes `success`, and its log shows a line with the runner's `uname -m` value matching the job's architecture and a `<variant> <arch>: … MB, limit … MB` line for its own variant and architecture.
- [ ] AC3: On draft probe PRs cut from the milestone branch and closed unmerged, four planted defects each fail at the step they target while the amd64 jobs conclude `success`: an arm64 entry set to an amd64 runner fails that entry's runner architecture check; a Dockerfile build step that exits non-zero only on aarch64 fails both arm64 jobs' build step; removing `quarto` from the arm64 image fails both arm64 jobs' smoke step; and arm64-only incompressible growth (random bytes) past the variants' limits fails both arm64 jobs' size step. The failed step's name is read from `gh run view --json jobs`, and the step's log names that failure.
- [ ] AC4: `grep -n -i -E 'amd64|arm64|one job per|its own job|publish time|after they publish'` over `README.md`, `cairn/DESIGN.md`, `.github/workflows/pr-ci.yml`, `.github/image-size-limits`, `.github/image-size.sh`, and `.github/smoke-test.sh` at the head that merges finds no line that states, or continues a sentence that states, that the pull request lane builds, smoke-tests, or size-checks one architecture only, or that the arm64 image is checked only when `docker.yml` publishes. `README.md` says that a pull request that changes the image is built and smoke-tested on amd64 and arm64 before it merges.
- [ ] AC5: `hadolint Dockerfile` reports nothing, and the milestone PR's `checks` job in `PR CI` concludes `success` at the head that merges.

## Coverage

- AC1 → T1
- AC2 → T1, T4
- AC3 → T3
- AC4 → T2
- AC5 → T1, T4

## Tasks

- [x] T1: In `pr-ci.yml` (`build-smoke`, lines 59-128), make the matrix four `variant`/`ubuntu_version`/`arch`/`runner` entries, set `runs-on: ${{ matrix.runner }}` and the job name, add a first step that compares the runner's `uname -m` with the job's architecture and prints it, and drive the build, smoke, export, and size steps from `matrix.arch` (platform, tag, cache scope, archive name, size arguments). Update the file's header and step comments. Run `hadolint Dockerfile` and `actionlint` if present.
- [ ] T2: Update the amd64-only text: `README.md:21`, `cairn/DESIGN.md`'s graduation paragraph and size-limit bullet (the PR bound, "its own job", "no single amd64 manifest"), `.github/image-size.sh:4-5`, `.github/image-size-limits:6-10`, `.github/smoke-test.sh:10-12`, and the parked ROADMAP row "Measure the build that smoke tested" (the arm64 exports re-resolve the base too). Run AC4's grep and write each hit's classification into the work log as one ledger line.
- [ ] T3: Push the milestone branch, then open four draft probe PRs from branches cut off it, one plant each (AC3), read each failed step's name and log with `gh run view --json jobs` and `gh run view --log-failed`, confirm the amd64 jobs passed, and close each with `gh pr close --delete-branch`. A plant counts only when its failure names the expected step and message.
- [ ] T4: Check the four jobs' logs on the last probe-free run of the milestone branch (or the first milestone PR run) for AC2's lines, and fix anything that differs before review.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: no flaw. gap: add arm64 jobs or reword the both-architectures principle (posed at the set; answer: add jobs). gap: whether arm64 jobs also size-check (posed; answer: also check size). gap: what "native" means — reading taken: a runner `uname -m` check before the build, since an image's `uname -m` reads `aarch64` under emulation too.
- 2026-11-05: collision check: absorbs candidate row "Run the arm64 smoke test in PR CI". M05's gate kept arm64 on the publish path because pre-merge emulation was slow; M015 (D-007) moved arm64 to native runners, so that reason no longer holds. D-012's "its own pull request job" stays as history; DESIGN's current text is updated in T2. No D-entry rejects this. Not the checker-regress shape: the smoke test checks the image, not repo-internal records.
- 2026-11-05: inbox sweep: 0 open issues, 0 open PRs on jmgirard/rstudio2u.
- 2026-11-05: lessons used: 2026-11-05 (M027, used M032) draft probe PRs off the milestone branch; 2026-11-05 (M024, used M032) a plant counts red only when its output names the expected check; 2026-11-05 (M026, used M027) a second build-push-action run with an OCI output for the size.
- 2026-11-05: question set: temporary draft probe PRs with planted defects — yes, closed with their branches deleted.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): 7 findings, all taken. AC2 "runner architecture line" made checkable (the `uname -m` value). AC3 plant 2 narrowed to "a build step that exits non-zero only on aarch64" (a `scripts/` arm64 break is a different form the probe does not show); plants 2-4 now claim both arm64 jobs; plant 3 wording fixed; plant 4 made incompressible random bytes. AC4 grep widened to catch arch-free wording ("one job per", "its own job", "publish time", "after they publish") and wrapped sentences, and a positive README clause added. Kept: AC2's one-direction runner probe, since all four entries share one step list.
- 2026-11-05: plan gate chose adding arm64 jobs over rewording the both-architectures principle to allow an amd64-only PR lane, because the user wanted pre-merge parity; falsified by arm64 PR jobs failing for runner or Docker Hub causes on PRs that changed nothing arm64-specific.
- 2026-11-05: plan gate chose size-checking arm64 in the PR lane over smoke only, so arm64 growth fails before publish; falsified by an arm64 size failure on a PR that added nothing arm64-specific.
- 2026-11-05: plan chose a runner `uname -m` check over docker.yml's image architecture and container `uname -m` checks, because those read the same under emulation; falsified by a job on an emulated runner passing the check.
- 2026-11-05: implement started on branch m033-arm64-pr-smoke, cut from main at ea8cd73.
- 2026-11-05: T1 done: `build-smoke` is four include entries (variant, ubuntu_version, arch, runner, uname), `runs-on: ${{ matrix.runner }}`, a first step "Check the runner is <arch>" that prints `runner uname -m: <value>` and exits 1 on a mismatch, then build, smoke, export, and size steps keyed on `matrix.arch`; header and job comments updated. Chose to put the runner check before Checkout so nothing is fetched on a wrong runner. actionlint 1.7.7 and hadolint 2.15.1 (local Docker images) clean.

## Decisions

## Review
