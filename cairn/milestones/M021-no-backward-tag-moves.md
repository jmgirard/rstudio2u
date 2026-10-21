# M021: Refuse to move moving tags backward

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** user-facing — it decides which image the published Docker Hub tags point at
- **Branch/PR:** m021-no-backward-tag-moves

## Goal

A publish leg does not move a tag to an index stamped earlier than the index the tag points at when the leg reads it.

## Scope

**In:** a run stamp from the `meta` job of `.github/workflows/docker.yml`, written as an index annotation by both
`imagetools create` calls of the `publish` job. A rule script, `.github/tag-order.sh`, that reads each tag's current
index and returns the tags the leg can attach. Its unit test, `scripts/tests/test_tag_order.sh`, runs in the
unit-test step of `pr-ci.yml`. The publish step attaches only the tags that the rule returns. The milestone also
updates the Conventions of `cairn/DESIGN.md` and the `Upload the digest` comment in `docker.yml`. It absorbs the
candidate row "Refuse to move moving tags backward".

**Out:** serializing publish legs across runs. Two runs that publish at the same moment can interleave the read and
the create. AC5 records this as a bound, and no work is planned for it. Also out: a guard against "Re-run all jobs"
on an old commit. That re-run takes a new stamp and builds the old recipe, so a stamp cannot detect it. AC5 records
this as a bound too.

## Acceptance criteria

- [ ] AC1: The `meta` job reads the clock once. From that read it outputs the run stamp in the fixed form
      `YYYY-MM-DDTHH:MM:SSZ` (UTC), and its existing `date` output is the date part of the stamp. Both create calls
      in each publish leg pass the annotation `index:org.opencontainers.image.created=<stamp>` from one shared
      argument array. The two calls are the `--dry-run` assembly and the real create. A test-mode dispatch of the
      branch shows the annotation, with that run's stamp, in the dry-run output of both variants.
- [ ] AC2: Before the `--dry-run` assembly, each publish leg runs `.github/tag-order.sh` over every tag in its tag
      list. The script reads the index that each tag points at now. The script writes the tags that the leg can
      attach, one per line, to a file that an argument names. If a tag's current index carries a stamp later than
      this run's, the script leaves that tag out of the file. It then prints a `::warning::` that names the tag, its
      stamp, and this run's stamp. The leg attaches only the tags in the file. If the file is empty, the leg attaches
      no tag and passes. The unit test drives the script with a stubbed `docker` that answers per tag. It asserts
      the file's contents and a warning for each tag left out. The cases put the later stamp on the first, on a
      middle, and on the last tag of a four-tag list. They also put later stamps on two tags at once. The later
      stamps differ from this run's stamp by one second, and by a day across a year boundary.
- [ ] AC3: A tag that is absent from the registry, carries no stamp, or carries a stamp equal to or earlier than this
      run's stays in the file. The unit test covers each of those three shapes alone and mixed in one list. The
      stub's answer for an absent tag is the buildx line `ERROR: docker.io/jmgirard/rstudio2u:<tag>: not found` with
      exit 1. The test-mode dispatch of AC1 shows every tag of both variants in the file.
- [ ] AC4: If the script cannot resolve a tag's read to absent, unstamped, or a stamp in the fixed form, it exits
      non-zero with a `::error::` that names the tag and the cause. The leg then fails and attaches no tag. This
      holds even when another tag in the list has a later stamp. The unit test covers at least these causes: a
      registry error with other text (a `toomanyrequests` answer), output that is not JSON, JSON that is not an
      index, a tag stamp not in the fixed form, and a run stamp not in the fixed form. It also covers a list that
      mixes a later stamp with a tag the script cannot resolve.
- [ ] AC5: The Conventions of `cairn/DESIGN.md` state the rule and these bounds. A tag published before this change
      carries no stamp, so the rule protects a tag from its first stamped publish on. A re-run of a run that started
      before the merge uses that run's old workflow. A "Re-run all jobs" runs `meta` again and takes a new stamp.
      Equal stamps publish. Two runs that publish at the same moment can interleave. A tag whose stamp is not in the
      fixed form fails its variant's publish each week, and the recovery is to re-point that tag by hand with a
      stamp in the fixed form. The `Upload the digest` comment in `docker.yml` says this: after a newer publish, a
      "Re-run failed jobs" leaves out each newer-stamped tag with a warning. "Re-run all jobs" takes a new stamp and
      publishes.
- [ ] AC6: `bash scripts/tests/test_tag_order.sh` passes in the unit-test step of `pr-ci.yml`. The shellcheck job
      of `lint.yml` passes over `.github/tag-order.sh` and the test file.

## Coverage

- AC1 → T2, T4
- AC2 → T1, T2
- AC3 → T1, T4
- AC4 → T1, T2
- AC5 → T3
- AC6 → T1

## Tasks

- [x] T1: Write `scripts/tests/test_tag_order.sh` first, with a per-tag `docker` stub that answers
      `buildx imagetools inspect --raw <ref>`. Then write `.github/tag-order.sh <run-stamp> <out-file> <tag>...`.
      Add the test to the unit-test step of `pr-ci.yml` and add `.github/tag-order.sh` to its `paths`. Run
      shellcheck at the floor that `lint.yml` sets.
- [x] T2: In `docker.yml`, make `meta` take one clock read and output `stamp` and `date` from it. In the publish
      step, run the rule before the dry run. Build `tag_args` from the out-file. Add the annotation to the shared
      argument array of both create calls. Run the dry run and the architecture check whatever the out-file holds.
      Skip the real create when the out-file is empty or in test mode. Add `.github/tag-order.sh` to `on.push.paths`.
- [ ] T3: Update the Conventions of `cairn/DESIGN.md` and the `Upload the digest` comment in `docker.yml`
      (`docker.yml:189-193`), as AC5 says.
- [ ] T4: Run one test-mode dispatch of the branch. Record the annotation and the out-file of both variants in the
      work log. If resolute fails for a resolute-only cause, run one more dispatch. If it fails again, log the
      failure and take resolute's evidence from the unit test.

## Work log

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: not run — work named at the question set.
- 2026-10-20: question set: which candidate to take — "Refuse to move moving tags backward".
- 2026-10-20: question set: may implement or review run test-mode dispatches of `docker.yml` — yes, test mode only.
- 2026-10-20: collision check: absorbs the candidate row "Refuse to move moving tags backward" (from M019 review). No D-entry rejects it. D-005 and GP2 read; no planned or open milestone overlaps.
- 2026-10-20: inbox sweep: 0 open issues, 0 open PRs on jmgirard/rstudio2u.
- 2026-10-20: lessons surfaced: M015 (assert on the dry run before the create), M09 (argument-sensitive multi-item stub), M020 (write the answer to a file, keep stdout for the log), M016 (only a real dispatch shows the gap).
- 2026-10-20: criteria audit (full mode, fresh Opus reader) returned 15 findings, all fixed in the written criteria: one clock read for stamp and date; dry-run evidence plus a shared argument array for the real create; per-tag refusal (GP2); a four-tag list and one-second and year-boundary stamp forms; a warning per skipped tag; the out-file as the verdict; "at least" causes plus JSON that is not an index; the real not-found line and a 429 probe; failure wins over refusal; the recovery for a bad stamp; the concurrency race as a bound; dry run and architecture check always run; the comment's content; a resolute fallback dispatch.
- 2026-10-20: plan gate chose an index annotation holding the `meta` stamp over the image config's `created` time because BuildKit sets that time and a cached push build makes its meaning unclear; falsified by a buildx that drops or rewrites index annotations on `imagetools create`.
- 2026-10-20: plan gate chose the annotation over listing Docker Hub tags by date because listing needs a second API and paging; falsified by evidence that `imagetools inspect --raw` does not return the live index.
- 2026-10-20: plan gate chose per-tag refusal over refusing the whole leg because a whole-leg refusal drops the old build's date tag (GP2); falsified by a case where a partial tag set leaves users on mixed images in one variant.
- 2026-10-20: plan gate chose to fail on a stamp not in the fixed form over reading it as unstamped because a bad stamp would turn the guard off silently; falsified by weekly publish failures from a stamp source outside this workflow.
- 2026-10-20: plan gate chose to record the cross-run race as a bound over a `concurrency:` group because GitHub cancels a pending job in a group, and a cancelled scheduled publish fails the run; falsified by a backward move seen from two overlapping runs.
- 2026-10-20: started implement on branch m021-no-backward-tag-moves.
- 2026-10-20: T1 done: `.github/tag-order.sh` and `scripts/tests/test_tag_order.sh` (16 cases, all pass), wired into `pr-ci.yml` (test step and `paths`). Live probe with buildx 0.37.2: a missing tag answers `ERROR: docker.io/<ref>: not found`, exit 1, and the live `latest` is an OCI index with no annotations. Seven planted defects (inverted compare, any not-found as absence, null as unstamped, no stamp-form check, unsettled ignored, no stale-file removal, no index check) each turned the suite red. shellcheck is not installed locally, so `lint.yml` on the PR is its first run.
- 2026-10-20: implementation choice: the script takes full image refs, not bare tags, and keeps absence only on the not-found line that names that exact ref; it reports every unsettled ref before exiting 1.
- 2026-10-20: T2 done: `meta` outputs `stamp` and derives `date` from it; `publish` checks out the repo, runs `tag-order.sh` before the dry run, builds `tag_args` from its file, passes one `create_args` annotation array to both create calls, and skips the real create on an empty list with a warning; `.github/tag-order.sh` joined `on.push.paths`. Local probe (buildx 0.37.2): `imagetools create --dry-run --annotation index:...` prints the annotation on the index, with and without `-t`. Pinned shellcheck 0.11.0 (local image) is clean on both new scripts at `-S info`; on the extracted step it reports only SC2153 for the env-provided `TAGS`, which predates this change. No YAML step simulation: no local Linux image has jq, so T4's dispatch is the step's first run.

## Decisions

## Review
