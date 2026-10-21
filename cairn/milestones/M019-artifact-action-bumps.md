<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M019: Take the artifact action bumps and fix the digest artifacts

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP3
- **Resolves:** —
- **Surface tier:** internal — a change to the CI workflow only; the image contents and its tags do not change
- **Branch/PR:** —

## Goal

The image build workflow carries its build digests with `actions/upload-artifact@v7` and `actions/download-artifact@v8`, each publish leg downloads only its own variant's two digests by exact name, and the digests stay available for six days.

## Scope

**In:** In `.github/workflows/docker.yml`: move `actions/upload-artifact` from v4 to v7 (Dependabot #29) and `actions/download-artifact` from v4 to v8 (Dependabot #28), as the user approved at the plan question set. Replace the publish job's prefix pattern `digests-<variant>-*` with a pattern that names the two artifacts exactly. Raise the digest artifacts' `retention-days` from 1 to 6, so "Re-run failed jobs" works for the rest of the week and the artifacts expire before the next Monday scheduled run. One test-mode `docker.yml` run on the milestone branch proves the change, and a D-entry records the dependency change, as D-010 did for the earlier bumps.

**Out:** Other `docker.yml` candidate rows ("Scope permissions on the docker.yml jobs", "Add the failure script to push.paths", "Prune untagged manifests on Docker Hub", "Keep r2u timeouts from failing publish") stay as candidate rows. Closing #28 and #29 is left to Dependabot, which closes a bump PR once the default branch has the new version; post-merge hygiene reads their state.

## Acceptance criteria

- [ ] AC1: `.github/workflows/docker.yml` calls `actions/upload-artifact@v7` and `actions/download-artifact@v8`, and `grep -rnE 'actions/(upload|download)-artifact@' .github/workflows/` lists no other version of either action.
- [ ] AC2: The publish job's digest download step has `pattern: digests-${{ matrix.variant }}-{amd64,arm64}`, which spells out the variant's two artifact names and holds no wildcard.
- [ ] AC3: The digest upload step sets `retention-days: 6`, and in AC4's run each of the four `digests-*` artifacts has an `expires_at` six days after its `created_at` (`gh api repos/jmgirard/rstudio2u/actions/runs/<id>/artifacts`).
- [ ] AC4: A test-mode `docker.yml` run (`workflow_dispatch` with `test_mode: true`) on the milestone branch, at a commit whose `docker.yml` equals the version that merges, concludes `success`: all four build legs pass, and each publish leg's `Create the manifest list` step succeeds, which requires its 2-digest count check and its check that the dry-run index names both linux architectures to pass.

## Coverage

- AC1 → T1, T4
- AC2 → T2, T4
- AC3 → T3, T4
- AC4 → T1, T2, T3, T4

## Tasks

- [ ] T1: Move `actions/upload-artifact@v4` to `@v7` (`docker.yml:181`) and `actions/download-artifact@v4` to `@v8` (`docker.yml:226`). Read the v5 to v8 release notes for any change to the inputs this file uses (`name`, `path`, `if-no-files-found`, `retention-days`, `pattern`, `merge-multiple`); the v8 hash-mismatch default (error) needs no input.
- [ ] T2: Change the download `pattern:` (`docker.yml:229`) to `digests-${{ matrix.variant }}-{amd64,arm64}`, and say in the step's comment why it names both architectures: a prefix pattern would also pull a future variant whose name extends this one (for example `noble-minimal`), and a brace pattern that matched nothing would fail the 2-digest check, not pass silently.
- [ ] T3: Change `retention-days: 1` to `6` (`docker.yml:186`), with a comment: six days lets "Re-run failed jobs" find the other legs' digests for the rest of the week, and the digests expire before the next Monday scheduled run, so a late re-run cannot publish digests older than that run's.
- [ ] T4: Push the branch and start a test-mode run: `gh workflow run docker.yml --ref <branch> -f test_mode=true`. Watch it, then record the run URL, its conclusion, each publish leg's `Create the manifest list` result, and the four `digests-*` artifacts' `created_at` and `expires_at` from the run's artifact listing. The dispatch also runs the keepalive job, which commits only after 50 quiet days on the default branch.
- [ ] T5: Append a D-entry recording the approved move to upload-artifact v7 and download-artifact v8, in D-010's form, naming the test-mode run as the evidence that `docker.yml` works with them.

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

## Decisions

## Review
