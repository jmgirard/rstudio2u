# M025: Remove unused files from the image

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP4, GP5, GP7
- **Resolves:** —
- **Surface tier:** user-facing — every student downloads the published image, and the merge moves the moving tags
- **Branch/PR:** m025-remove-unused-image-files

## Goal

Published images stop carrying files that cannot run on them or serve only static linking, so a student downloads at least 200 MB less, with every image function unchanged.

## Scope

**In:**
- A new script, `scripts/slim_rstudio.sh`, called from `scripts/install_rstudio.sh` in the `RUN` that installs RStudio. It removes the Copilot folders for other platforms, the `.a` files under `/usr/lib/llvm-*/lib`, RStudio's `lib/libgit2.a`, and `www-symbolmaps`.
- Removing the `www-symbolmaps` line from the Dockerfile's second `RUN` (`Dockerfile:61-62`). In that `RUN` the removal only hides files that the install layer still ships.
- New smoke checks for Copilot, libclang, and `apt-get check`, in `.github/smoke-test.sh`.
- Corrected size figures and a DESIGN.md account of what is removed.

**Out:**
- Removing Copilot itself: the user chose at the plan gate to keep it.
- Removing the `libclang-dev` package: `rstudio-server` depends on it, so apt would see a broken dependency. Only its static archives go.
- Anything in the `rocker/r2u` base layers: removing a file from them adds a hide marker and saves no download.
- Static archives from other packages, such as `libssl-dev`: about 3 MB compressed, not worth the risk to source builds.
- Stronger layer compression: the new parked row "Try stronger compression on layers".
- The size limit and its CI checks: M026, which sets the limit from this milestone's published sizes.

## Acceptance criteria

- [ ] AC1: In each of the four images a test-mode `docker.yml` run builds from the branch (noble and resolute, amd64 and arm64), `ls` of `/usr/lib/rstudio-server/bin/copilot-language-server-js/node_modules/@github` shows `copilot-sdk` and exactly one `copilot-sdk-<platform>-<arch>` folder, the one for that image's architecture.
- [ ] AC2: In each of those four images, `find /usr/lib/llvm-*/lib -name '*.a'` prints nothing, and `/usr/lib/rstudio-server/lib/libgit2.a` and `/usr/lib/rstudio-server/www-symbolmaps` do not exist. In a local noble arm64 build from the branch, a listing of every layer names none of the removed files.
- [ ] AC3: For each of those four images, the sum of `layers[].size` in its manifest (`docker buildx imagetools inspect --raw`) is at least 200 MB below the size Docker Hub's tags API reports for the `<variant>-<rstudio>` tag of the same RStudio version and architecture (decimal MB). If that tag does not exist yet, the comparison waits for the next weekly publish of that version. Projection: 260 to 275 MB, measured 2026-11-05.
- [ ] AC4: In each of those four images, RStudio's bundled node loads that architecture's native Copilot module, and the language server answers an LSP `initialize` request. Sign-in and completions need a GitHub account and are not run.
- [ ] AC5: In each of those four images, `libclang.so` under `/usr/lib/llvm-*/lib` loads with `dlopen`, `apt-get check` exits 0, and every smoke check that `.github/smoke-test.sh` holds on `main` still passes.
- [ ] AC6: `scripts/slim_rstudio.sh` stops the build with a message naming the architecture when `dpkg --print-architecture` is neither amd64 nor arm64. It removes no Copilot folder and exits 0 when no folder matches this image's architecture, whether or not other architectures' folders exist. It keeps the matching folder on both amd64 and arm64.
- [ ] AC7: `grep -rniE '[0-9.]+ ?(GB|MB|GiB|MiB)|gigabyte' . --exclude-dir=.git --exclude-dir=cairn` prints no size figure that the change made false, and DESIGN.md's Architecture and Known issues state what is removed and what the removal depends on.

## Coverage

- AC1 → T2, T6
- AC2 → T2, T4, T6
- AC3 → T2, T6
- AC4 → T3, T6
- AC5 → T3, T6
- AC6 → T1, T2
- AC7 → T5

## Tasks

- [x] T1: Write `scripts/tests/test_slim_rstudio.sh` first, over a fixture tree with `SLIM_ROOT` and a stub `dpkg`: amd64 and arm64 each keep their folder (`linux-x64`, `linux-arm64`), an unknown architecture fails and names it, a tree with only other architectures' folders loses none, and a tree with no such folders exits 0. See it fail, then add it to the unit-test step in `pr-ci.yml`.
- [x] T2: Write `scripts/slim_rstudio.sh` and call it from `scripts/install_rstudio.sh` right after the `gdebi` line. Remove the `www-symbolmaps` line and its comment from `Dockerfile:61-62`, keeping the `RUN` valid. Keep `.so` files and the `copilot-sdk` package.
- [ ] T3: Add the checks to `.github/smoke-test.sh`, before the phase that breaks apt networking. Copilot: load `copilot-sdk-${process.platform}-${process.arch}/prebuilds/<same>/runtime.node` under `/usr/lib/rstudio-server/bin/node/bin/node`, then send `initialize` to the language server. `initialize` alone also passes with the native folder gone, so both parts are needed. If no `copilot-sdk-*-*` folder exists at all, print a notice and skip the load, so an upstream layout change does not stop a publish. M026's size check catches that case. If other folders exist and the matching one does not, fail. Also add the libclang `dlopen` and `apt-get check`.
- [ ] T4: Build noble arm64 locally, run the smoke test, and list every layer of a `docker save`. Plant each defect in a throwaway image and see the smoke test red with the expected `FAIL:` line: native folder removed, `libclang.so` target removed. Exit status alone does not count.
- [x] T5: Correct the figures that T4 made false: `scripts/tests/posix/run_launcher_real_compose.sh:7` (with its date and how it was measured). Update DESIGN.md's Architecture. Add a Known issues entry: the removal depends on RStudio's folder layout, a later apt reinstall of `libclang-18-dev` restores its archives, and CI does not test Copilot sign-in.
- [ ] T6: Push the branch and run `gh workflow run docker.yml --ref <branch> -f test_mode=true` (permission granted at the plan gate). From each leg's log, record the digest and the AC1, AC2, AC4, and AC5 results. Read each digest's manifest for AC3.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — changes what the image contains and needs a choice on what to remove.
- 2026-11-05: idea vet: gap, a slimming pass leaves open whether to remove Copilot itself; reading taken: keep Copilot and remove only the folders that cannot run; the set's answer: keep it. No flaw.
- 2026-11-05: lessons used: 2026-11-05 (M024) a planted defect counts as red only when its output names the expected `FAIL:` check.
- 2026-11-05: question set: run a test-mode build on GitHub before the merge question — yes. Copilot — keep it, remove the other platforms' folders.
- 2026-11-05: collision check: absorbed in part the candidate row "Set an image-size budget with a CI guard", with M026 absorbing the rest. D-001 and GP4 license editing `scripts/`; D-005 leaves the version to the next release; no heading matched image size. GitHub inboxes hold 0 issues and 0 PRs. Commit 98f3a44 claimed the `www-symbolmaps` saving in a local image; the published layers still carry those files.
- 2026-11-05: measured on noble arm64 at RStudio 2026.10.1-239: unmodified recipe 987.0 MB (Docker Hub reports 987), with the removals in the install `RUN` 711.8 MB. Removable bytes by `tar | gzip -6`: noble amd64 260 MB, resolute arm64 266 MB, noble arm64 266 MB before `www-symbolmaps`.
- 2026-11-05: plan gate chose deleting the static archives over removing `libclang-dev` because `rstudio-server` depends on that package; falsified by `apt-get check` failing or a bspm install failing on the slimmed image.
- 2026-11-05: plan gate chose `rm` over a dpkg `path-exclude` rule because a lasting rule would also hide those paths from a user's later installs; falsified by an image flow that reinstalls those files during normal use.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): AC3's fixed baseline could pass or fail on an upstream change, so it now compares with the same RStudio version; AC6 now covers other folders with none matching; AC4 and AC5 moved from smoke-script wording to image properties, and the test file moved to T1; AC2's listing is bound to that build; AC7's grep widened; the question of an upstream layout change blocking every publish is settled in T3.
- 2026-11-05: split: the row's slimming pass is M025; its baseline and CI guard are M026 (planned now, depends on M025); stronger compression is a new parked row. Not a feature series: M026 changes nothing users see.
- 2026-11-05: no RB tripwire tag: IP3's runtime interface is not touched.
- 2026-11-05: no changelog file (PROFILE). The merge publishes because it touches `scripts/` and the Dockerfile. The archive summary states the smaller download for the next release's notes.
- 2026-11-05: T1, T2 done: `test_slim_rstudio.sh` failed with exit 127 before the script existed and passes with it. `slim_rstudio.sh` runs from `install_rstudio.sh`; the Dockerfile's `www-symbolmaps` line is gone. Implementation choice: the script stands alone, for its unit test, rather than sitting inside `install_rstudio.sh`.
- 2026-11-05: checkpoint: T3's smoke checks are written and pass on a local noble arm64 build, and T4's planted-defect runs are still going, so T3 and T4 stay unticked. T5 done: the launcher script's comment now says "the whole image" with no figure, a minor change from T5's "with its date", so it cannot go stale; DESIGN.md's Architecture and Known issues updated.

## Decisions

## Review
