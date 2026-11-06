<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M033: Smoke-test arm64 in the PR lane

- **Status:** review
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
- [x] T2: Update the amd64-only text: `README.md:21`, `cairn/DESIGN.md`'s graduation paragraph and size-limit bullet (the PR bound, "its own job", "no single amd64 manifest"), `.github/image-size.sh:4-5`, `.github/image-size-limits:6-10`, `.github/smoke-test.sh:10-12`, and the parked ROADMAP row "Measure the build that smoke tested" (the arm64 exports re-resolve the base too). Run AC4's grep and write each hit's classification into the work log as one ledger line.
- [x] T3: Push the milestone branch, then open four draft probe PRs from branches cut off it, one plant each (AC3), read each failed step's name and log with `gh run view --json jobs` and `gh run view --log-failed`, confirm the amd64 jobs passed, and close each with `gh pr close --delete-branch`. A plant counts only when its failure names the expected step and message.
- [x] T4: Check AC2's lines in the logs of the probe jobs that passed, and fix anything that differs before review. The full four-job check is AC2's evidence on the milestone PR run at review.

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
- 2026-11-05: T2 done: README.md:21, DESIGN.md graduation paragraph (two jobs per variant) and size-limit bullet (four images, four figures, the amd64-only bound removed, both manifest messages), image-size.sh:4-5, image-size-limits:8-10, smoke-test.sh:10-13, and the parked row "Measure the build that smoke tested" updated. test_image_size.sh passes; shellcheck clean on the two scripts; actionlint over all workflows reports two existing docker.yml style/info notes, none in pr-ci.yml. The simple-english hook reported 38 README hits in text this milestone did not write (candidate row "Clear the README's plain-English hits"); left alone.
- 2026-11-05: AC4 ledger (grep of T2's pattern, 28 hits on the branch): no hit says the PR lane is one-architecture. Product-arch statements: README 8, 14, 15, 211, 320; DESIGN 5, 183-184, 221 (GP3), 272-274 (arm64 runner dependency). PR lane on both: README 21, DESIGN 36, 162, 178, pr-ci.yml 4, 59, 73, 78, 83, 88, image-size.sh 5, image-size-limits 9-10, smoke-test.sh 10, 12. Measurement data: image-size-limits 14, 15, 18. Launcher check, not the PR build lane: DESIGN 262. smoke-test.sh 111 names arm64's Quarto surface.
- 2026-11-05: T3 probes opened as drafts off d33856d: #51 runner (noble arm64 entry on `ubuntu-latest`), #52 build (`RUN [ "$(uname -m)" != aarch64 ]`), #53 smoke (`rm -f "$(command -v quarto)"` on aarch64), #54 size (130 MB from /dev/urandom on aarch64). Plants 2-4 sit just before the Runtime block so earlier layers come from cache.
- 2026-11-05: T3 done. Runs (failed step from `gh run view --json jobs`; message from the job log): #51 run 42158563820 noble arm64 failed "Check the runner is arm64" with "runner uname -m: x86_64 (the arm64 job expects aarch64)"; #52 run 42158582451 noble and resolute arm64 failed "Build <v> (arm64) for smoke test" with `RUN [ "$(uname -m)" != aarch64 ]` "did not complete successfully: exit code: 1"; #53 run 42158597788 both arm64 failed "Smoke-test <v> (arm64)" with "quarto: command not found" then "FAIL: quarto render did not produce HTML output"; #54 run 42158613996 both arm64 failed "Hold <v> (arm64) to its size limit" with "noble arm64: 842.5 MB, over the 800 MB limit" and "resolute arm64: 874.4 MB, over the 840 MB limit". Every amd64 job concluded success, and #51's unplanted resolute arm64 job too.
- 2026-11-05: #52's resolute amd64 job first failed its smoke step on an r2u outage ("Unable to connect to r2u.stat.illinois.edu", bspm install of data.table), not the plant; rerun of that job alone (attempt 2) succeeded. Same cause as the parked row "Keep r2u timeouts from failing publish"; not a publish, so its condition does not hold. Probes #51-#54 closed unmerged, remote branches deleted.
- 2026-11-05: minor amendment: T4 reworded, since no probe-free run exists before the milestone PR opens; noble arm64 passes all steps only there.
- 2026-11-05: T4 done: passing probe jobs print "runner uname -m: aarch64 (the arm64 job expects aarch64)" with "resolute arm64: 744.3 MB, limit 840 MB" (#51), and "runner uname -m: x86_64 (the amd64 job expects x86_64)" with "noble amd64: 723.1 MB, limit 800 MB" (#51, #54) and "resolute amd64: 759.3 MB, limit 840 MB" (#54). No fix needed.
- 2026-11-05: claim audit: 15 claims read, 1 corrected — .github/workflows/pr-ci.yml (the native-runner comment named docker.yml's "publish legs"; now "build legs", re-read and holds). Reader caveats on README:21 kept as they are: `.dockerignore` is outside pr-ci.yml's paths (parked row "Add .dockerignore to the build paths"), and "before it merges" rests on the never-merge-red rule, not branch protection (text that predates this branch).
- 2026-11-05: implement complete; status review. Verify: hadolint 2.15.1 clean on Dockerfile, actionlint 1.7.7 clean on pr-ci.yml.

## Decisions

## Review
