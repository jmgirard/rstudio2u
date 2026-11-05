# M026: Hold the image to a size limit in CI

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M025
- **Driving RR:** —
- **Principles touched:** GP2, GP5
- **Resolves:** —
- **Surface tier:** internal — CI checks over this repo's own image; no external consumer relies on them
- **Branch/PR:** m026-image-size-limit-ci

## Goal

CI holds each image to a recorded compressed-size limit, failing a pull request that crosses it and reporting a published image that crosses it without stopping any publish.

## Scope

**In:**
- `.github/image-size-limits`: one limit per variant, with the measurements behind it.
- `.github/image-size.sh`: the comparison rule, reading a manifest and the limits file.
- A size step in `pr-ci.yml` over the noble amd64 image that lane already builds.
- `.github/workflows/image-size.yml` and its reporting script, on their own schedule and with their own `image-size` issue label.
- A DESIGN.md Conventions bullet on the limit and how to raise it.

**Out:**
- Stopping a publish over size: the user chose at the plan gate to report and still publish.
- Measuring arm64 or resolute in the pull request lane: that lane builds noble amd64 only (GP3 asymmetry, documented in `pr-ci.yml`). The weekly check reads all four.
- Disk size after unpacking: the limit is on what a student downloads.
- Slimming: M025.

## Acceptance criteria

- [ ] AC1: `.github/image-size-limits` holds one limit per variant (noble, resolute), each the larger of that variant's two compressed sizes published after M025 merges plus 10%, rounded up to the next 10 MB, with those measurements, their date, and the command that produced them beside it. `grep -rnw` for each limit's number across `.github` and `scripts` finds it only in that file and in `scripts/tests/test_image_size.sh`.
- [ ] AC2: `pr-ci.yml` measures the noble amd64 image it builds, as the sum of `layers[].size` in an OCI export of that build, and its job fails with a message naming the measured size and the limit when the size is over the limit. Its `paths` include the limits file and the measuring script.
- [ ] AC3: `image-size.yml`, on a weekly schedule and on dispatch, reads the manifests of the `noble` and `resolute` tags on Docker Hub and logs each of the four variant and architecture sizes against its limit.
- [ ] AC4: When a size read by `image-size.yml` is over its limit, the run opens or comments on one open GitHub issue labeled `image-size`, naming the variant, architecture, size, and limit. When all four are read and within their limits, the run closes any open issue with that label. It opens and closes no issue labeled `ci-failure`.
- [ ] AC5: When `image-size.yml` cannot read any of the four sizes, or an answer holds no layer sizes, the run reports that size as unread in the same issue, does not count it as within its limit, and does not close the issue.
- [ ] AC6: `git diff --stat origin/main...HEAD` names none of `Dockerfile`, any file under `scripts/` outside `scripts/tests/`, `.github/smoke-test.sh`, `.github/tag-order.sh`, `.github/ci-failure-issue.sh`, `.github/rebuild-gap.sh`, `.github/last-rebuild-success.sh`, `.github/workflows/docker.yml`, or `.github/workflows/rebuild-gap.yml`.
- [ ] AC7: In `scripts/tests/test_image_size.sh`, a size under and a size equal to the limit pass, a size over it fails, and a manifest with no layers fails the pull request check and reads as unread in the weekly report. With a stub `gh`, the test sees the AC4 and AC5 issue actions, including that an unread size never closes the issue and that no call names `ci-failure`. The test runs in `pr-ci.yml`. DESIGN.md's Conventions state the limit rule and how a pull request raises a limit.

## Coverage

- AC1 → T5
- AC2 → T3
- AC3 → T4
- AC4 → T1, T4
- AC5 → T1, T4
- AC6 → T7
- AC7 → T1, T2, T6

## Tasks

- [x] T1: Write `scripts/tests/test_image_size.sh` first, with fixture manifests and stub `docker` and `gh`, in the shape of `scripts/tests/test_rebuild_gap.sh`. See it fail, then add it to the unit-test step in `pr-ci.yml`.
- [x] T2: Write `.github/image-size.sh`: given a variant, an architecture, and a manifest file, it reads the limit from `.github/image-size-limits`, prints the size and limit in decimal MB, and exits 0 within, 1 over, 2 unreadable. An empty or missing `layers` list is unreadable, never a size of 0.
- [x] T3: In `pr-ci.yml`, after the build step, export the same build as OCI through the same builder so its cache serves it, read the manifest out of the archive, and run `.github/image-size.sh`. Add the limits file and the script to `paths`. The failure message says how to raise the limit.
- [x] T4: Write `.github/image-size-report.sh` and `.github/workflows/image-size.yml`: Mondays at 12:00 UTC and on dispatch, with `issues: write`. For each tag and architecture it reads `docker buildx imagetools inspect --raw` up to 3 times 10 seconds apart, then opens, comments on, or closes the `image-size` issue. The rule stays in scripts, never in the workflow.
- [x] T5: After M025's publish, read the four published sizes and write `.github/image-size-limits` by AC1's rule, with the date and command beside the figures. Projection from the 2026-11-05 probes: noble about 790 MB, resolute about 840 MB.
- [ ] T6: Add the DESIGN.md Conventions bullet: the metric, the 10% rule, that the pull request lane fails and the weekly check reports, and that a pull request raises a limit by editing the limits file with a stated reason (GP5).
- [ ] T7: Run the AC6 diff. Then, with the permission granted at the plan gate, push a temporary branch with a limit set below the real size and `image-size.yml` on `on: push`, because a dispatch needs the workflow on the default branch (lesson M023). See the pull request step red naming the size and limit. See the weekly check open a real `image-size` issue, then green close it. Delete the temporary branch and confirm that the issue is closed.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — new CI checks with a design decision on what an over-limit image does.
- 2026-11-05: idea vet: gap, a size guard can stop a publish, but noble amd64 moved from 779 MB to 1064 MB between July and October with RStudio and base changes, and stopping a publish over that breaks GP2; reading taken: the pull request lane fails and the weekly check reports; the set's answer: report and still publish. Gap, the size to limit; reading taken: compressed download size, not unpacked disk size, agent's choice. No flaw.
- 2026-11-05: lessons used: 2026-11-05 (M023, used M024) to see a pull-request-only workflow fail before merge, get a yes and push a temporary branch with `on: push`; 2026-11-05 (M024) a plant counts only when its output names the expected check; 2026-10-21 (M020) keep a script's answer out of captured stdout.
- 2026-11-05: question set: run temporary-branch checks and open and close one test issue on GitHub before the merge question — yes. Over-limit behavior — report and still publish. Room above the slimmed size — 10%.
- 2026-11-05: collision check: absorbed in part the candidate row "Set an image-size budget with a CI guard", with M025 absorbing the slimming. Parked row "Keep launcher failures out of the gap" shows the cost that this design avoids. Checker-regress shape does not apply: this adds a check and hardens no earlier one.
- 2026-11-05: plan gate chose a separate workflow and label over a job in `docker.yml` through `notify` because a lasting over-limit size would turn each scheduled run red, and after two weeks `rebuild-gap.sh` would report "No successful weekly rebuild" although images published, and `notify` would close the issue on any green run; falsified by an over-limit week that goes unreported because this workflow did not run while `docker.yml` did.
- 2026-11-05: plan gate chose its own reporting script over a label argument on `ci-failure-issue.sh` because that file is in `docker.yml`'s `paths`, so an edit starts a publish and touches the publish lane's alert; falsified by the two scripts' issue logic needing the same fix twice.
- 2026-11-05: plan gate chose an OCI export over `docker image inspect` `.Size` in the pull request lane because `.Size` changes meaning with the Docker image store on the runner, and the export's layer sum measured 987.0 MB against Docker Hub's 987 MB; falsified by a run where the export and the pushed manifest for one recipe differ by more than 5 MB.
- 2026-11-05: criteria audit (reduced mode, fresh Opus reader): AC1's grep widened to whole words across `.github` and `scripts`; AC2 gained the `paths` clause; AC5 widened from a tag to any of the four sizes; AC6 lost its "so nothing can stop a publish" claim and now lists every file those workflows run; AC7 names outcomes and a stub `gh`. AC3 had no finding.
- 2026-11-05: no RB tripwire tag. No changelog and no release: nothing changes for users, and no path in `docker.yml`'s filter changes, so the merge starts no rebuild (D-005).
- 2026-11-05: correction to the line above: `scripts/tests/test_image_size.sh` matches `scripts/**` in `docker.yml`'s `paths`, so the merge does start one rebuild and publish, as M024's and M025's merges did. `.dockerignore` keeps `scripts/tests` out of the image. AC7 fixes the test's path, so the path stays.
- 2026-11-05: implement started on branch m026-image-size-limit-ci, cut from origin/main at d7e4886.
- 2026-11-05: T1 done: `test_image_size.sh` added to the `pr-ci.yml` unit-test step; it fails on every script-driven case with exit 127 because neither script exists yet. Choices: limits come from a fixture through `IMAGE_SIZE_LIMITS`, so raising a real limit edits no test; `--from-oci` mode on `image-size.sh` holds the archive reading so that it is testable; an over or unread report exits 0, as `rebuild-gap.sh` does after an alert.
- 2026-11-05: T2 done: `.github/image-size.sh` passes every comparison and archive case; the committed-limits cases wait for T5 and the report cases for T4. Choice: sizes print rounded up to 0.1 MB, so an over size never prints as equal to its limit.
- 2026-11-05: T3 done: the export and size steps in `pr-ci.yml`, not run yet (T7 runs them). Choice: they follow the smoke test, so a size failure cannot hide a smoke failure. `paths` also gains the report script, because the unit-test step covers it.
- 2026-11-05: T4 done: `.github/image-size-report.sh` and `image-size.yml`; every report case passes, and eight planted defects (equal counted as over, empty layers as size 0, unread allowing a close, label `ci-failure`, two reads, unread lines dropped, newest issue reused, exit 1 when over) each turned the suite red on the expected check. The committed-limits cases still wait for T5.
- 2026-11-05: T5 done: limits noble 800 MB and resolute 840 MB, from docker.yml run 42058263556 (M025's publish): noble 723.07 and 712.43 MB, resolute 759.22 and 744.28 MB. `grep -rnw` finds each number only in the limits file. The suite passes in full.

## Decisions

## Review
