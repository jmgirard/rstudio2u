# M026: Hold the image to a size limit in CI

- **Status:** review
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

- [x] AC1: `.github/image-size-limits` holds one limit per variant (noble, resolute), each the larger of that variant's two compressed sizes published after M025 merges plus 10%, rounded up to the next 10 MB, with those measurements, their date, and the command that produced them beside it. `grep -rnw` for each limit's number across `.github` and `scripts` finds it only in that file and in `scripts/tests/test_image_size.sh`.
- [x] AC2: `pr-ci.yml` measures the noble amd64 image it builds, as the sum of `layers[].size` in an OCI export of that build, and its job fails with a message naming the measured size and the limit when the size is over the limit. Its `paths` include the limits file and the measuring script.
- [x] AC3: `image-size.yml`, on a weekly schedule and on dispatch, reads the manifests of the `noble` and `resolute` tags on Docker Hub and logs each of the four variant and architecture sizes against its limit.
- [x] AC4: When a size read by `image-size.yml` is over its limit, the run opens or comments on one open GitHub issue labeled `image-size`, naming the variant, architecture, size, and limit. When all four are read and within their limits, the run closes any open issue with that label. It opens and closes no issue labeled `ci-failure`.
- [x] AC5: When `image-size.yml` cannot read any of the four sizes, or an answer holds no layer sizes, the run reports that size as unread in the same issue, does not count it as within its limit, and does not close the issue.
- [x] AC6: `git diff --stat origin/main...HEAD` names none of `Dockerfile`, any file under `scripts/` outside `scripts/tests/`, `.github/smoke-test.sh`, `.github/tag-order.sh`, `.github/ci-failure-issue.sh`, `.github/rebuild-gap.sh`, `.github/last-rebuild-success.sh`, `.github/workflows/docker.yml`, or `.github/workflows/rebuild-gap.yml`.
- [x] AC7: In `scripts/tests/test_image_size.sh`, a size under and a size equal to the limit pass, a size over it fails, and a manifest with no layers fails the pull request check and reads as unread in the weekly report. With a stub `gh`, the test sees the AC4 and AC5 issue actions, including that an unread size never closes the issue and that no call names `ci-failure`. The test runs in `pr-ci.yml`. DESIGN.md's Conventions state the limit rule and how a pull request raises a limit.

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
- [x] T6: Add the DESIGN.md Conventions bullet: the metric, the 10% rule, that the pull request lane fails and the weekly check reports, and that a pull request raises a limit by editing the limits file with a stated reason (GP5).
- [x] T7: Run the AC6 diff. Then, with the permission granted at the plan gate, push a temporary branch with a limit set below the real size and `image-size.yml` on `on: push`, because a dispatch needs the workflow on the default branch (lesson M023). See the pull request step red naming the size and limit. See the weekly check open a real `image-size` issue, then green close it. Delete the temporary branch and confirm that the issue is closed.

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
- 2026-11-05: T6 done: DESIGN.md Conventions bullet added. It also states the bound that growth in the three images the pull request lane does not build shows only after they publish.
- 2026-11-05: T7 done on temporary branch m026-temp-size-check, both workflows `on: push`, as granted at the plan gate. With noble's limit at 500: `pr-ci.yml` run 42062583727 failed only at its size step with "noble amd64 is 723.1 MB, over its 500 MB limit" and the raise-the-limit text; `image-size.yml` run 42062584097 opened issue #37 under `image-size`, naming both noble sizes and the limit. With the real limit restored: `image-size.yml` run 42062731641 closed #37, and `pr-ci.yml` run 42062731742 passed at 723.1 MB, the same as the published image. No `ci-failure` issue was opened or closed. The real runs covered no unread size: that outcome has stub-driven cases only. Temporary branch deleted, #37 confirmed closed, AC6 diff names none of the listed files. Local shellcheck 0.11.0 at `-S info` is clean on the three new shell files, and all 12 `scripts/tests/test_*.sh` files pass.
- 2026-11-05: claim audit: not owed — internal tier

## Decisions

## Review

- AC1 evidence: `.github/image-size-limits` holds `noble 800` and `resolute 840`. A fresh read of Docker Hub gives noble 723074024 and 712425637 bytes, resolute 759219681 and 744276741. Larger plus 10%: 795.38 and 835.14 MB, which round up to 800 and 840. The file holds these measurements, their date, the source run, and the command. `grep -rnw` for 800 and for 840 across `.github` and `scripts` finds each only in that file.
- AC2 evidence: temporary-branch run 42062583727 (noble limit 500) failed only at "Hold noble (amd64) to its size limit", with the annotation "noble amd64 is 723.1 MB, over its 500 MB limit" and how to raise it. Run 42062731742 (real limit) passed at 723.1 MB. The step reads an OCI export's `layers[].size` through `image-size.sh --from-oci`. `pr-ci.yml`'s `paths` lines 22 and 23 name the limits file and the script. The two heads differ from this branch only in the temporary `on: push` lines, the planted limit, and one log word.
- AC3 evidence: `image-size.yml` has `schedule` cron `0 12 * * 1` and `workflow_dispatch`. Run 42062731641 logged noble amd64 723.1, noble arm64 712.5, resolute amd64 759.3, and resolute arm64 744.3 MB, each against its limit, from the `noble` and `resolute` tags. It ran on the temporary `on: push`; a schedule or dispatch cannot run until the file is on the default branch.
- AC4 evidence: real run 42062584097 opened issue #37 labeled `image-size`, naming noble amd64 723.1 and arm64 712.5 MB against the 500 MB limit. Real run 42062731641 closed #37 with all four within. The comment-on-open path ran on the stub only: "it comments on the oldest open issue" passes in `test_image_size.sh`. The newest `ci-failure` issue is #25, last updated 2026-09-11, and the test's "no gh call names ci-failure" passes over every case.
- AC5 evidence: stub cases only, no real run. In `test_image_size.sh`, a manifest read failing 3 times, a tag read failing 3 times, a tag with no entry for an architecture, and an answer with `layers: []` each report the size as unread in the issue and make no `issue close` call, though the other sizes are within. A planted defect that ignored unread sizes when deciding to close turned the suite red in T4.
- AC6 evidence: `git diff --stat origin/main...HEAD` names nine files: the limits file, the two new scripts, `image-size.yml`, `pr-ci.yml`, `cairn/DESIGN.md`, `cairn/ROADMAP.md`, the milestone file, and `scripts/tests/test_image_size.sh`. It names none of the files AC6 lists.
- AC7 evidence: `test_image_size.sh` exits 0 with 86 ok lines and no FAIL line. It covers a size under, equal to, and over the limit, a no-layers manifest failing the archive check (exit 2) and reading as unread in the report, the AC4 and AC5 issue actions on a stub `gh`, and no call naming `ci-failure`. `pr-ci.yml` line 48 runs it, and the check ran green in run 42062731742. DESIGN.md line 136 states the limit rule and how a pull request raises a limit.
- Consistency gate: `cairn_validate.py` exit 0, one advisory (the old `.gitignore` pdf entry, already a candidate row). `Dockerfile` and `scripts/` outside `scripts/tests/` are unchanged. hadolint 2.15.1 reports no violation locally. The build ran from a clean checkout in run 42062731742, not locally. The base image is an explicit version tag through `UBUNTU_VERSION`, no secret is in `ENV` or `ARG`, and `.dockerignore` is present. No changelog: nothing changes for users. No principle changed, so `cairn_impact` is skipped.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: a pull request unrelated to size can go red from upstream growth, because the lane builds `stable` RStudio on the current base, and DESIGN did not say so — fix now (the design keeps failing the lane; DESIGN now states the bound), fixed 02db7ea
- diff-bug #2: a failed `gh label create` withheld the comment on an already open issue — fix now (label call moved to the create path), fixed 02db7ea
- diff-bug #3: when the report script itself fails, nothing raises an alert beyond a red run — follow-up: parked row "Alert when the size report itself fails", plus a DESIGN bound sentence in 02db7ea
- diff-bug #4: jq's exit status was ignored, so `{"layers":[{"size":5}]} <html>oops` counted as a real size and could close the issue — fix now (`jq -s`, one document only), fixed 02db7ea
- diff-bug #5: the test named "before the issue opens" did not check order — fix now, fixed 02db7ea
- diff-bug #6: two manifests for one architecture had no test — fix now, fixed 02db7ea
- diff-bug #7: buildx is not pinned, so a change to the export's `index.json` shape fails every pull request closed, and DESIGN did not say so — fix now (DESIGN bound), fixed 02db7ea
- diff-bug #8: an unreadable result in the pull request lane gave no annotation — fix now, fixed 02db7ea
- diff-bug #9: the 10-second pause had no test — fix now, fixed 02db7ea
- diff-bug #10: the unreadable-blob branch had no test — fix now, fixed 02db7ea
- diff-bug #11: other untested branches — fix now for `%` and carriage return, run-link stand-in, OS filter, zero sum, negative size, width bound, no `::error::` in plain mode, and the "still publish" text, fixed 02db7ea; rejected, edge, for the jq-missing guard (only a runner with no jq reaches it, and it exits 2), the silent-script fallback line (only a deleted or crashed `image-size.sh` reaches it, and it reads as unread), and the `.size` type and floor checks (only a fractional layer size from a registry, and later checks catch nearly all of it)
- diff-bug #12: the variant list is hard-coded — rejected, planned change: AC3 names the `noble` and `resolute` tags
- diff-bug #13: nothing bounded a read that hangs — fix now (`timeout-minutes: 10`), fixed 02db7ea
- diff-bug #14: the anonymous read's rate-limit risk was unstated — fix now (DESIGN bound), fixed 02db7ea
- diff-bug #15: no `concurrency` setting — rejected, edge: only a manual dispatch racing the Monday schedule reaches it, its effect is a second alert issue, which an all-within run closes, and `rebuild-gap.yml` has none either
- diff-bug #16: an issue opened as unread keeps that title when a later comment reports an over size — follow-up: parked row "Retitle a reused image-size issue"
- diff-bug #17: the export re-resolves `rocker/r2u:24.04`, so a tag move during the smoke test would measure another build — follow-up: parked row "Measure the build that smoke tested"
- diff-bug #18: the limit rule uses published sizes that a pull request does not have — fix now (limits file and DESIGN state what figure it has), fixed 02db7ea
- diff-bug #19: exit 0 with empty stdout would record as within — rejected, false: `image-size.sh` prints its line before every exit 0
- diff-bug #20: a not-found answer is retried 3 times, unlike `tag-order.sh` — rejected, edge: only a deleted tag reaches it, its effect is 20 seconds, and it ends as unread
- diff-bug #21: the three new scripts were mode 100644 where neighbors are 100755 — fix now, fixed 02db7ea
- diff-bug #22: `.dockerignore` is not in `paths`, in `pr-ci.yml` or `docker.yml`, and this predates the diff — follow-up: parked row "Add .dockerignore to the build paths"
- diff-bug #23: `scripts/**` in `docker.yml` matches the new test, so this merge starts a publish — rejected, planned change: AC7 fixes the test's path, and every test under `scripts/tests/` already does this; shown at the merge question
- diff-bug (c): refusal cases asserted only the exit code — fix now, fixed 02db7ea; the header comment restated stub behavior — fix now, fixed 02db7ea; repeated exit-0 asserts on separate recording routes — rejected, style; stub probes — rejected, false: check discrimination asks for them and `test_rebuild_gap.sh` has the same probe
- blame-history #1: `image-size.yml` has no failure path, unlike M020's `notify` job — follow-up: same parked row as diff-bug #3
- blame-history #2: a pull request can raise its own limit in the same diff — rejected, planned change: T6 and AC7 name that path
- blame-history #3: the pull request gate covers amd64 only — rejected, planned change: the milestone's Scope `Out:`
- blame-history #4: the retry treats every failure alike, unlike `tag-order.sh` — rejected, edge: same as diff-bug #20
- blame-history #5: the `pr-ci.yml` header omitted the size step — fix now, fixed 02db7ea
- prior-review #1: digit-width bounds had no over-wide, zero-padded, or widest-in-range cases (lesson M016) — fix now, fixed 02db7ea
- prior-review #2: refusal cases asserted only the exit status (lesson M024) — fix now, fixed 02db7ea
- ripple #1: the `pr-ci.yml` header omitted the size step — fix now, fixed 02db7ea; the workflow's `name:` stays
- ripple #2: the step named "Resolver unit tests" gained another script that is no resolver test — follow-up: absorbed by the low row "Rename the PR lane's unit test step"
- ripple #3: "Both workflows are weekly" in DESIGN and `rebuild-gap.yml` — rejected, false: the sentence names `docker.yml` and `rebuild-gap.yml`, and stays true of them
- ripple #4: the candidate row "Set an image-size budget with a CI guard" still reads as open — rejected, false: post-merge hygiene removes it
- After the fixes, on 02db7ea: `test_image_size.sh` exits 0 with 130 ok lines, shellcheck 0.11.0 at `-S info` is clean on the three scripts, `cairn_validate.py` exits 0, and AC1's grep still finds each limit only in the limits file. Six planted defects against the new cases each turned the suite red. These fixes have not run on a real runner yet: the pull request's own checks run them at the merge wait, except the report script, which first runs for real after the merge.
