# M025: Remove unused files from the image

- **Status:** review
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
- [x] T3: Add the checks to `.github/smoke-test.sh`, before the phase that breaks apt networking. Copilot: load `copilot-sdk-${process.platform}-${process.arch}/prebuilds/<same>/runtime.node` under `/usr/lib/rstudio-server/bin/node/bin/node`, then send `initialize` to the language server. `initialize` alone also passes with the native folder gone, so both parts are needed. If no `copilot-sdk-*-*` folder exists at all, print a notice and skip the load, so an upstream layout change does not stop a publish. M026's size check catches that case. If other folders exist and the matching one does not, fail. Also add the libclang `dlopen` and `apt-get check`.
- [x] T4: Build noble arm64 locally, run the smoke test, and list every layer of a `docker save`. Plant each defect in a throwaway image and see the smoke test red with the expected `FAIL:` line: native folder removed, `libclang.so` target removed. Exit status alone does not count.
- [x] T5: Correct the figures that T4 made false: `scripts/tests/posix/run_launcher_real_compose.sh:7` (with its date and how it was measured). Update DESIGN.md's Architecture. Add a Known issues entry: the removal depends on RStudio's folder layout, a later apt reinstall of `libclang-18-dev` restores its archives, and CI does not test Copilot sign-in.
- [x] T6: Push the branch and run `gh workflow run docker.yml --ref <branch> -f test_mode=true` (permission granted at the plan gate). From each leg's log, record the digest and the AC1, AC2, AC4, and AC5 results. Read each digest's manifest for AC3.

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
- 2026-11-05: T3, T4 done on a local noble arm64 build: smoke test exit 0. Plants red with the expected `FAIL:` line: native folder gone with another folder present, truncated `runtime.node`, a language server that never answers, libclang's library gone, `libclang-18-dev` removed. With no platform folders, the smoke test passes with the notice. All 10 layers of `docker save` name none of the removed files.
- 2026-11-05: the `libclang-18-dev` plant first came back `FAIL: quarto render`, not the expected line: with a broken dependency, bspm's apt run removed `rstudio-server`, and the bundled Quarto with it. `apt-get check` now runs before the bspm install, and the plant then fails on it. This also supports the plan gate's choice to keep the package.
- 2026-11-05: T6 done: test-mode run 42051578392 at c7adaa3 was green on every job and attached no tag. Each leg's log shows one native Copilot folder, 0 llvm archives, no `libgit2.a` or `www-symbolmaps`, and every smoke check passing; resolute uses `llvm-21`. Manifest bytes against the same-version tags: noble amd64 722355886 vs 992828358, noble arm64 711709142 vs 986921584, resolute amd64 758501535 vs 1030892868, resolute arm64 743563107 vs 1019615078: 270 to 276 MB less.
- 2026-11-05: claim audit: 31 claims read, 2 corrected — .github/smoke-test.sh, scripts/slim_rstudio.sh. The re-read found the header's corrected wording still too strong for symbol maps, which `rserver` can read, so it now says "does not need to run", which the smoke run with them gone supports. One claim stays unobserved: that Copilot sign-in needs a GitHub account. Comment-only changes after run 42051578392.

## Decisions

## Review

Evidence run: test-mode run 42053189266 at 2fcee06, green on every job, no tag attached, RStudio 2026.10.1-239. Local build of the same commit, noble arm64.

- AC1 evidence: each of the four legs' logs lists `copilot-sdk` and one platform folder: `copilot-sdk-linux-x64` on both amd64 legs, `copilot-sdk-linux-arm64` on both arm64 legs.
- AC2 evidence: each leg's log shows `static archives under llvm: 0` and `ls: cannot access` for `libgit2.a` and `www-symbolmaps`. A `docker save` of the local build: 10 layers, 27454 entries, 0 naming a removed file.
- AC3 evidence: measured against the `<variant>-2026.10.1-239` tags from Docker Hub's API, in bytes: noble amd64 722355811 vs 992828358 (270.5 MB less), noble arm64 711709228 vs 986921584 (275.2 MB less), resolute amd64 758502023 vs 1030892868 (272.4 MB less), resolute arm64 743562784 vs 1019615078 (276.1 MB less). Projected 260 to 275 MB; the floor is 200 MB.
- AC4 evidence: each leg's log shows `PASS: Copilot's native module loads` naming its folder and `PASS: the Copilot language server answered initialize`. Sign-in and completions not run, as the criterion states.
- AC5 evidence: each leg's log shows `loaded /usr/lib/llvm-<n>/lib/libclang.so` (18 on noble, 21 on resolute), `PASS: libclang.so loads`, `PASS: apt-get check`, and the final `PASS: smoke test`; 13 `PASS` lines and no `FAIL` line in each leg. `main`'s smoke checks all still run in that script; the diff removes none.
- AC6 evidence: `bash scripts/tests/test_slim_rstudio.sh` at 2fcee06 passes all seven groups: both architectures keep their folder, an unknown architecture stops and names it and removes nothing, only other folders removes none, no folders and an empty tree exit 0.
- AC7 evidence: the criterion's `grep` prints nothing at 2fcee06 (exit 1), and DESIGN.md's Architecture paragraph and Known issues entry state what is removed and what the removal depends on.

Consistency gate at 2fcee06: `cairn_validate` passes with one advisory (the old `.gitignore` pdf entry, already a candidate row). `hadolint Dockerfile` clean, `docker build` succeeds. The base image is `rocker/r2u:${UBUNTU_VERSION}`, a versioned tag in both variants. No secret in `ENV` or `COPY`. `.dockerignore` lists `.git` and `cairn`. No principle changed, so `cairn_impact` is skipped. User-visible change for the next release's notes: a download about 270 MB smaller.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: the smoke test stops a publish on upstream layout changes that T3's exception does not cover, such as a missing `@github` or a moved language server — fix now.
- diff-bug #2: DESIGN.md says nothing fails after a folder rename, which is false when the new name still has the `copilot-sdk-*-*` form — fix now.
- diff-bug #3: `slim_rstudio.sh` deletes any `copilot-sdk-*-*` folder, so a future helper package would go silently — fix now: it removes only `darwin`, `win32`, and `linux` folders.
- diff-bug #4: the `initialize` half looks like dependency behavior and detects no removal — reject, planned change: AC4 requires it, and a planted silent server and a crashing server turn it red.
- diff-bug #5: the "no platform folders" test takes the same branch as the no-match case — reject, planned change: T1 and AC6 name the case.
- diff-bug #6: the "empty tree" test repeats that branch and otherwise exercises `rm -f` — fix now: removed.
- diff-bug #7: the `runtime.node` and neighbor checks can fail only if a literal path or the wholesale `rm -rf` is rewritten — reject, false: they are the shapes the check must leave alone, which check discrimination asks for.
- diff-bug #8: the unit test passes with the `install_rstudio.sh` call deleted and the smoke listing is report-only, so a slim step that does nothing publishes green — follow-up: M026's size check reports exactly that case; no new row.
- diff-bug #9: the fixture has no nested `.a` and the removal is shallow while AC2's `find` is recursive — reject, false: AC2's recursive `find` prints 0 on all four images, and a recursive delete could take runtime archives under `lib/clang`.
- diff-bug #10: `-lclangAST`-style static links now fail although the Goal says every function is unchanged, and `dpkg --verify` lists 93 missing files — reject, planned change: the Goal and Scope name the removal of static-linking files; DESIGN.md now names the `dpkg --verify` result.
- diff-bug #11: `libgit2.pc` and `lib/cmake/libgit2` still point at the removed `libgit2.a` — reject, edge: only pointing `PKG_CONFIG_PATH` or CMake at RStudio's private `lib` folder reaches it, outside documented and common use, and the effect is a link error.
- diff-bug #12: the check reads `id === 1` without excluding a server request that carries a `method` — fix now.
- diff-bug #13: a server crash waits 60 s and reports "did not answer" — fix now: an `exit` handler reports the exit code.
- diff-bug #14: the native `require` runs before the timer, so a hang there lasts until GitHub's job limit — reject, edge: only a native module whose load hangs reaches it, outside common use, and the effect is slow running; the smoke test's other `docker exec` calls have no timeout either.
- diff-bug #15: `apt-get check` can stop a publish for a dependency break in the base image — reject, false: that stop is wanted, because the planted break showed bspm's next install removes `rstudio-server`.
- diff-bug #16: the Copilot check runs as root, but RStudio runs it as `rstudio` — fix now: `docker exec -u rstudio`.
- diff-bug #17: DESIGN.md names only `libclang-18-dev` and only a reinstall, but resolute uses llvm-21 and an upgrade also restores the archives — fix now.
- diff-bug #18: the `[1/2]` and `[2/2]` labels sit beside unnumbered steps, and `exists("found")` also searches attached packages — the labels: reject, style; the `exists` call: fix now.
- blame-history #1: the build now fails on an architecture other than amd64 or arm64 — reject, planned change: AC6 asks for it, and CI builds only those two (D-007).
- blame-history #2: moving the symbol map removal changes its rationale and may change developer-facing behavior — reject, false: those files were already absent at run time in the published image, so only the download changes.
- blame-history #3: the launcher script's size figure was dropped although T5 asked to correct it with a date — reject, false: the work log records the choice, and the derived-figures rule accepts a derivation in place of a figure.
- blame-history #4: the Known issues entry says sign-in needs a GitHub account, which the audit lists as unobserved — reject, planned change: AC4 states it, and the work log records it as unobserved.
- prior-review #1: the slim listing's `|| true` lets a failed `docker exec` pass — reject, planned change: the listing is a report by design, and the checks after it fail on a dead container.
- prior-review #2: the notice branch lets a missing platform folder pass — reject, planned change: AC6 and T3 specify it, and a plant shows it.
- ripple: no line outside the diff disagrees with it.
- ripple #1: `pr-ci.yml` names its step "Resolver unit tests" though it runs every script's unit tests; pre-existing — follow-up: new row "Rename the PR lane's unit test step", `[low]`, because a maintainer reads that name on each failed run.
