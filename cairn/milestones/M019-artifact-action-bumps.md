<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M019: Take the artifact action bumps and fix the digest artifacts

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP3
- **Resolves:** —
- **Surface tier:** internal — a change to the CI workflow only; the image contents and its tags do not change
- **Branch/PR:** m019-artifact-action-bumps

## Goal

The image build workflow carries its build digests with `actions/upload-artifact@v7` and `actions/download-artifact@v8`, each publish leg downloads only its own variant's two digests by exact name, and the digests stay available for six days.

## Scope

**In:** In `.github/workflows/docker.yml`: move `actions/upload-artifact` from v4 to v7 (Dependabot #29) and `actions/download-artifact` from v4 to v8 (Dependabot #28), as the user approved at the plan question set. Replace the publish job's prefix pattern `digests-<variant>-*` with a pattern that names the two artifacts exactly. Raise the digest artifacts' `retention-days` from 1 to 6, so "Re-run failed jobs" works for the rest of the week and the artifacts expire before the next Monday scheduled run. One test-mode `docker.yml` run on the milestone branch proves the change, and a D-entry records the dependency change, as D-010 did for the earlier bumps.

**Out:** Other `docker.yml` candidate rows ("Scope permissions on the docker.yml jobs", "Add the failure script to push.paths", "Prune untagged manifests on Docker Hub", "Keep r2u timeouts from failing publish") stay as candidate rows. Closing #28 and #29 is left to Dependabot, which closes a bump PR once the default branch has the new version; post-merge hygiene reads their state.

## Acceptance criteria

- [x] AC1: `.github/workflows/docker.yml` calls `actions/upload-artifact@v7` and `actions/download-artifact@v8`, and `grep -rnE 'actions/(upload|download)-artifact@' .github/workflows/` lists no other version of either action.
- [x] AC2: The publish job's digest download step has `pattern: digests-${{ matrix.variant }}-{amd64,arm64}`, which spells out the variant's two artifact names and holds no wildcard.
- [x] AC3: The digest upload step sets `retention-days: 6`, and in AC4's run each of the four `digests-*` artifacts has an `expires_at` within one minute of six days after its `created_at` (`gh api repos/jmgirard/rstudio2u/actions/runs/<id>/artifacts`).
- [x] AC4: A test-mode `docker.yml` run (`workflow_dispatch` with `test_mode: true`) on the milestone branch, at a commit whose `docker.yml` equals the version that merges, concludes `success`: all four build legs pass, and each publish leg's `Create the manifest list` step succeeds, which requires its 2-digest count check and its check that the dry-run index names both linux architectures to pass.

## Coverage

- AC1 → T1, T4
- AC2 → T2, T4
- AC3 → T3, T4
- AC4 → T1, T2, T3, T4

## Tasks

- [x] T1: Move `actions/upload-artifact@v4` to `@v7` (`docker.yml:181`) and `actions/download-artifact@v4` to `@v8` (`docker.yml:226`). Read the v5 to v8 release notes for any change to the inputs this file uses (`name`, `path`, `if-no-files-found`, `retention-days`, `pattern`, `merge-multiple`); the v8 hash-mismatch default (error) needs no input.
- [x] T2: Change the download `pattern:` (`docker.yml:229`) to `digests-${{ matrix.variant }}-{amd64,arm64}`, and say in the step's comment why it names both architectures: a prefix pattern would also pull a future variant whose name extends this one (for example `noble-minimal`), and a brace pattern that matched nothing would fail the 2-digest check, not pass silently.
- [x] T3: Change `retention-days: 1` to `6` (`docker.yml:186`), with a comment: six days lets "Re-run failed jobs" find the other legs' digests for the rest of the week, and the digests expire before the next Monday scheduled run, so a late re-run cannot publish digests older than that run's.
- [x] T4: Push the branch and start a test-mode run: `gh workflow run docker.yml --ref <branch> -f test_mode=true`. Watch it, then record the run URL, its conclusion, each publish leg's `Create the manifest list` result, and the four `digests-*` artifacts' `created_at` and `expires_at` from the run's artifact listing. The dispatch also runs the keepalive job, which commits only after 50 quiet days on the default branch.
- [x] T5: Append a D-entry recording the approved move to upload-artifact v7 and download-artifact v8, in D-010's form, naming the test-mode run as the evidence that `docker.yml` works with them.

## Work log

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: not run — work named at the question set.
- 2026-10-20: question set: which work to plan — the artifact bumps (#28, #29) with the two digest-artifact fixes on the same steps.
- 2026-10-20: question set: may the agent start test-mode `docker.yml` runs on the milestone branch — yes.
- 2026-10-20: question set: approve upload-artifact v7 and download-artifact v8 (a dependency change) — approved both; T5 records the D-entry.
- 2026-10-20: collision check: absorbed candidate rows "Take the two artifact bumps (#28, #29)", "Match digest artifacts by exact variant", "Keep digest artifacts longer than a day"; D-010 is the precedent for action bumps, no conflict; no archived milestone already does this.
- 2026-10-20: inbox sweep: 0 open issues; 2 open PRs (#28, #29, Dependabot) overlap and are the absorbed row; Resolves stays `—` because both are PRs, not issues.
- 2026-10-20: lessons surfaced: M016 (only a real dispatch shows a workflow gap) shapes T4; M015 (`imagetools --dry-run` before any tag moves) is the check AC4 relies on.
- 2026-10-20: plan gate chose a brace pattern over two exact-`name:` downloads because a missing artifact under `name:` fails the step before the 2-digest check can report the failed leg; falsified by a test-mode publish leg that finds other than 2 digests while all four legs uploaded.
- 2026-10-20: plan gate chose 6 retention days over 7 or more because a longer retention lets a late re-run publish digests older than the next scheduled run's; falsified by a maintainer need to re-run a failed job more than six days after it ran.
- 2026-10-20: criteria audit (reduced mode, fresh Opus reader): AC1 passed; AC2's "cannot be pulled" clause was unbounded, narrowed to the exact pattern text; AC3's "each run" claim was unbounded, narrowed to the setting plus AC4's run; AC4 bound log text the workflow never prints, narrowed to the `Create the manifest list` step succeeding. All three fixed as suggested.
- 2026-10-20: started; branch m019-artifact-action-bumps cut from main at a950dd2.
- 2026-10-20: T1–T3 done: upload-artifact v7, download-artifact v8, pattern `digests-${{ matrix.variant }}-{amd64,arm64}`, retention 6 days, each with a comment; the v8 and v7 `action.yml` (read via `gh api`) keep every input the file uses with unchanged defaults. The verify slot does not fire (no Dockerfile or build-context change); no local YAML parser or actionlint is installed, so T4's run is the first parse.
- 2026-10-20: T4 done: test-mode run https://github.com/jmgirard/rstudio2u/actions/runs/39529671936 at 7ba240a concluded success; all four build legs and both publish legs passed, `Create the manifest list` succeeded in each publish leg; each leg's download logged "Found 8 artifact(s)" and downloaded only its own `digests-<variant>-amd64` and `-arm64`; the four `digests-*` artifacts expire 6 days less 1 second after `created_at`; keepalive made no commit (origin/main still a950dd2).
- 2026-10-20: T5 done: D-011 records the approved bumps, citing run 39529671936.
- 2026-10-20: claim audit: not owed — internal tier.
- 2026-10-20: all tasks done; status review.
- 2026-10-20: amendment routed: AC3 — in run 39529671936 each digest artifact's `expires_at` is `created_at` + 6 days − 1 second, so "six days after its `created_at`" fails at second resolution; the 6-day setting is correct, the wording needs a stated precision.
- 2026-10-20: re-audit: AC3 (reduced) — nothing; bounded to AC4's run's four artifacts, proportionate, a deliverable property.
- 2026-10-20: amendment return: AC3 — "each of the four `digests-*` artifacts has an `expires_at` within one minute of six days after its `created_at`"
- 2026-10-20: amendment done, no code change; status review.
- 2026-10-20: review fix-now: narrowed the retention comment and extended the download comment in `docker.yml` (comments only); added candidate row "Refuse to move moving tags backward"; AC4 needs a new test-mode run at this `docker.yml`.
- 2026-10-20: step-7 approval: m019-artifact-action-bumps approved for merge

## Decisions

## Review

Pass 1 (2026-10-20), branch at 7687462, level with main a950dd2.

- AC1: `grep -rnE 'actions/(upload|download)-artifact@' .github/workflows/` lists exactly `docker.yml:184 actions/upload-artifact@v7` and `docker.yml:233 actions/download-artifact@v8`, no other version. Pass.
- AC2: `grep -n 'pattern:' docker.yml` shows `236: pattern: digests-${{ matrix.variant }}-{amd64,arm64}`, the only download pattern; run 39529671936 logged it as `digests-noble-{amd64,arm64}` and `digests-resolute-{amd64,arm64}`. Pass.
- AC3: `docker.yml:189 retention-days: 6`; in run 39529671936 each of the four `digests-*` artifacts has `expires_at` = `created_at` + 6 days − 1 second (e.g. resolute-amd64 created 2026-10-21T01:55:19Z, expires 2026-10-27T01:55:18Z). Fails as written at second resolution; the setting is right and the wording is too exact. Routed as an amendment return, not ticked.
- AC4: run https://github.com/jmgirard/rstudio2u/actions/runs/39529671936, `workflow_dispatch` with `test_mode: true` (logged in the build legs), head 7ba240a, conclusion success; four build legs success; `publish (noble)` and `publish (resolute)` success, each with `Create the manifest list` success; `git diff --quiet 7ba240a HEAD -- .github/workflows/docker.yml` exits 0. Pass.

Pass 2 (2026-10-20), after the AC3 amendment at 722b24a; main still a950dd2, `docker.yml` unchanged since pass 1, so AC1, AC2 and AC4 evidence stands.

- AC3 (amended): `docker.yml:189 retention-days: 6`; for run 39529671936, `expires_at − created_at − 518400 s` is −1 s for each of digests-noble-amd64, digests-noble-arm64, digests-resolute-amd64, digests-resolute-arm64, inside one minute. Pass.

Consistency gate (pass 2):
- `cairn_validate.py`: all checks passed; 1 advisory (the old `cairn/references/pdf/` .gitignore entry, an existing candidate row).
- `cairn_impact.py`: skipped, no principle changed.
- docker build: `Dockerfile`, `.dockerignore`, `scripts/` are byte-identical to main (`git diff --quiet main HEAD --` exits 0); run 39529671936 built all four legs from this branch with no cache (dispatch). hadolint is not installed locally; the PR lane's `build-smoke` (hadolint-action v3.5.0 + build) runs on the PR, since its paths include `.github/workflows/**`, and step 8 waits for it.
- Base image pinned by explicit tag (`rocker/r2u:${UBUNTU_VERSION}`, `UBUNTU_VERSION=24.04`); no secrets in `ENV`/`COPY`; `.dockerignore` present and excludes `.git`. All unchanged by this diff.
- Changelog: none as a file; no user-visible change (CI only), so the archive summary records none.

Independent review (pass 2):
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: the retention comment's "a late re-run cannot publish digests older than that run's" holds only for the Monday scheduled run; a push or dispatch run on another day keeps its digests past the next publish — fix now (comment narrowed).
- diff-bug #2: the arch names in the download pattern are hard-coded with no note to keep them in step with the build matrix — fix now (comment says so).
- diff-bug #3: the download comment names only a no-match case, where the 2-digest check also catches a one-arch match — fix now (comment says "fewer than two").
- diff-bug #4: brace pattern is valid YAML and expanded as intended (run logged 2 of 8 artifacts per leg) — reject, false as a defect (informational).
- diff-bug #5: v7/v8 changes (archive default, digest-mismatch error, ESM, Node 24, inputs) do not affect this workflow — reject, false as a defect (informational).
- diff-bug #6: v8 prints a Node DEP0005 deprecation warning in the publish log — reject, dependency behavior with no failure.
- diff-bug #7: D-011's "which the PR checks do not run" could attach to the actions rather than `docker.yml` — reject, style.
- blame-history #1: 6-day retention widens the window in which "Re-run failed jobs" of an older run moves `latest`/`noble`/`resolute` back over a newer push build — follow-up, new candidate row "Refuse to move moving tags backward"; the comment now states the risk.
- blame-history #2: the retention comment reads as a stronger guarantee than it gives — fix now (same fix as diff-bug #1).
- blame-history #3: the no-match claims in the comments were written from v4 behavior and unverified for v8 — reject, false: the v8 source (`src/download-artifact.ts` at ref v8, read via `gh api`) filters by pattern and throws on no match only for `name` and `artifact-ids`, so a pattern matching nothing downloads nothing and reaches the 2-digest check.
- prior-review: no prior-review evidence (no archived Review finding on the artifact steps; PR comment probe returned `[]`).
- ripple #1–#3: the three absorbed candidate rows (marked `— started M019`) still describe v4, the prefix pattern, and 1-day retention — reject, planned change: post-merge hygiene graduates these rows.
- Fix-now items diff-bug #1–#3 and blame-history #2: fixed 3c0a02d (comments only).

Evidence after the fixes (2026-10-20), branch `docker.yml` at 3c0a02d, equal to HEAD (`git diff --quiet 3c0a02d HEAD -- .github/workflows/docker.yml` exits 0); main still a950dd2:
- AC1: unchanged by the fixes; `grep` still lists only `@v7` (upload) and `@v8` (download). Pass.
- AC2: unchanged by the fixes; pattern line identical; run 39530697446 logged `digests-noble-{amd64,arm64}` and `digests-resolute-{amd64,arm64}`. Pass.
- AC3: in run 39530697446 (AC4's run), `expires_at − created_at − 518400 s` is −1 s, −1 s, −1 s and 0 s for the four `digests-*` artifacts, inside one minute; `retention-days: 6` unchanged. Pass.
- AC4: run https://github.com/jmgirard/rstudio2u/actions/runs/39530697446, `workflow_dispatch` with `test_mode: true`, head 3c0a02d, conclusion success; four build legs success; both publish legs success with `Create the manifest list` success; each publish leg "Found 8 artifact(s)" and downloaded only its own amd64 and arm64 digests. Pass. This run supersedes run 39529671936 as AC4's run.
