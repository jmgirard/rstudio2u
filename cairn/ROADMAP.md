# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-10-20 (M022 done: graduated 2 candidate rows, added 1 parked row, pruned M019's terminal row; no lesson; validate green)_
_Released 2.2.0 2026-09-04 (tag v2.2.0 at e0893aa; history re-released under semver, D-005)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M022 | Harden the tag-order check | done | — | normal | milestones/archive/M022-harden-tag-order.md |
| M021 | Refuse to move moving tags backward | done | — | normal | milestones/archive/M021-no-backward-tag-moves.md |
| M020 | Close the gaps in CI failure reports | done | — | normal | milestones/archive/M020-failure-report-gaps.md |
<!-- rows grouped by status, not sorted by ID; keep only the 3 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Set an image-size budget with a CI guard: Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- Define the resolute graduation path: resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
- Pre-merge arm64 smoke in `pr-ci.yml` — run the deepened smoke on a native arm64 build in the PR lane too; deferred from M05 for PR-CI speed, and no longer needs emulation since M015 — added 2026-07-17 — GP3; from M05
- Verify the launcher port on real Compose: Verify the launcher-resolved port against a real Compose (both launcher harnesses stub `docker`) — fold into the container smoke lane — added 2026-07-18 — GP3; deferred from M09
- Run start_mac.command on a macOS runner: macOS runner executing `start_mac.command` on real macOS in the launcher lane — added 2026-07-18 — GP3; deferred from M09
- Retry the keepalive push on contention: The keepalive `git push` has no contention handling: a bare push from a shallow checkout with no `concurrency:` group in `docker.yml`, so a maintainer push landing between checkout and push fails non-fast-forward with no retry; the test stub always exits 0, so no failing-push path is exercised — added 2026-09-07 — from M016 review
- Alert on stale Docker Hub tag dates: Docker Hub tag date as a second gap oracle: alert when the newest published `<variant>-<date>` tag is stale, measuring the user-visible freshness commitment rather than that a run happened — added 2026-09-07 — GP2; rejected as M018's oracle in favour of run history
- Prune untagged manifests on Docker Hub: Untagged manifests accumulate on Docker Hub: push-by-digest leaves four per run (test-mode runs tag none) with no GC step — added 2026-09-06 — from M015 review
- Re-print the offline warning at the end: Re-print the offline "update was skipped" warning after the running banner: it prints before the up-to-180s health wait and scrolls off — added 2026-09-03 — GP1; deferred from M10 review
- Keep r2u timeouts from failing publish: A timeout reaching `r2u.stat.illinois.edu` in the noble amd64 smoke test (bspm install of data.table) fails the whole noble publish. Only a later run recovers. Seen in the 2026-09-07 scheduled run and in push run 34645083284 on 2026-09-11 — added 2026-09-11 — GP7; found merging the Dependabot bumps; 2026-10-20 plan gate: if taken, retry the install and still fail when every try fails
- Keep the gap wording when alerting fails: if `ci-failure-issue.sh` fails inside the `gap` job's own alert (label or issue create), `rebuild-gap.yml`'s `notify` job reports the generic "Weekly run failed: rebuild-gap" and the measured-gap subject reaches the issue only through the run link — added 2026-10-20 — GP2; from M020 review
- Run the empty attach path in CI: the publish leg's path where `tag-order.sh` leaves out every tag (dry run with no `-t`, then the skip branch) has run only in local buildx probes and unit tests of the script, never in a workflow run — added 2026-10-20 — GP7; from M021 review
- [low] Replace numbered Known issue citations: `scripts/resolve-rstudio-version.sh` and `scripts/mirror_hint.R` cite "Known issue #2" / "#1" against a DESIGN Known issues list that is unnumbered — convert to principle citations as M015 did for #3 — added 2026-09-06 — from M015 review
- [low] Remove the old pdf .gitignore entry: `.gitignore` entry `cairn/references/pdf/` is superseded by `cairn/references/sources/` (cairn_validate advisory); repair via `/cairn-init` — added 2026-09-06
- [parked] Pick an unambiguous job-name separator: Failed job names are joined on a space in the `ci-failure` title, so a future multi-word job name would render ambiguously; a separator change falsifies M017's AC4 wording — added 2026-09-07 — from M017 review (corrected M018: the gap check ships a one-word job name, so it is no longer the example)
- [parked] Publish fresh tags past a future stamp: when one tag carries a stamp later than the clock, `tag-order.sh` fails the whole publish leg, so that variant's new date and version tags stop too (GP2); the alternative publishes the tags that are not future-stamped, then exits 1 so the run still goes red; promote when a run's date or version tags fail to publish because another tag carried a future stamp — added 2026-10-20 — GP2; from M022 review
