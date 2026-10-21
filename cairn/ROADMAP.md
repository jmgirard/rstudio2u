# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-10-21 (M019 done: graduated "Take the two artifact bumps (#28, #29)", "Match digest artifacts by exact variant", "Keep digest artifacts longer than a day"; added "Refuse to move moving tags backward"; pruned the M016 row; validate green)_
_Released 2.2.0 2026-09-04 (tag v2.2.0 at e0893aa; history re-released under semver, D-005)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M019 | Take the artifact action bumps and fix the digest artifacts | done | — | normal | milestones/archive/M019-artifact-action-bumps.md |
| M017 | Report a failing keepalive job | done | — | high | milestones/archive/M017-report-failing-keepalive.md |
| M018 | Alert when no weekly rebuild has succeeded in too long | done | M017 | normal | milestones/archive/M018-rebuild-gap-alert.md |
<!-- rows grouped by status, not sorted by ID; keep only the 3 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Set an image-size budget with a CI guard: Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- Define the resolute graduation path: resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
- Pre-merge arm64 smoke in `pr-ci.yml` — run the deepened smoke on a native arm64 build in the PR lane too; deferred from M05 for PR-CI speed, and no longer needs emulation since M015 — added 2026-07-17 — GP3; from M05
- Verify the launcher port on real Compose: Verify the launcher-resolved port against a real Compose (both launcher harnesses stub `docker`) — fold into the container smoke lane — added 2026-07-18 — GP3; deferred from M09
- Run start_mac.command on a macOS runner: macOS runner executing `start_mac.command` on real macOS in the launcher lane — added 2026-07-18 — GP3; deferred from M09
- Name timed-out jobs in ci-failure issues: `.github/ci-failure-issue.sh` names only jobs whose `.conclusion` is `failure`, but `needs.<job>.result` reports `failure` for a `timed_out` job too — such a run falls back to generic text and emits the contradiction warning blaming the parser — added 2026-09-07 — from M017 review
- Pick an unambiguous job-name separator: Failed job names are joined on a space in the `ci-failure` title, so a future multi-word job name would render ambiguously; a separator change falsifies M017's AC4 wording — added 2026-09-07 — from M017 review (corrected M018: the gap check ships a one-word job name, so it is no longer the example)
- Retry the keepalive push on contention: The keepalive `git push` has no contention handling: a bare push from a shallow checkout with no `concurrency:` group in `docker.yml`, so a maintainer push landing between checkout and push fails non-fast-forward with no retry; the test stub always exits 0, so no failing-push path is exercised — added 2026-09-07 — from M016 review
- Test the rebuild-gap date reduction: `rebuild-gap.yml`'s date reduction has no committed test: its three branches (a date, an empty result, an unreadable answer) live in YAML shell, so a lost branch would surface only in production as a red run raising nothing — added 2026-09-07 — from M018 review
- Add a notify job to rebuild-gap.yml: `rebuild-gap.yml` has no self-report: a step that fails for any reason yields a red run and GitHub's default email, where `docker.yml` carries a `notify` job for exactly that — added 2026-09-07 — from M018 review
- Alert on stale Docker Hub tag dates: Docker Hub tag date as a second gap oracle: alert when the newest published `<variant>-<date>` tag is stale, measuring the user-visible freshness commitment rather than that a run happened — added 2026-09-07 — GP2; rejected as M018's oracle in favour of run history
- Prune untagged manifests on Docker Hub: Untagged manifests accumulate on Docker Hub: push-by-digest leaves four per run (test-mode runs tag none) with no GC step — added 2026-09-06 — from M015 review
- Re-print the offline warning at the end: Re-print the offline "update was skipped" warning after the running banner: it prints before the up-to-180s health wait and scrolls off — added 2026-09-03 — GP1; deferred from M10 review
- Keep r2u timeouts from failing publish: A timeout reaching `r2u.stat.illinois.edu` in the noble amd64 smoke test (bspm install of data.table) fails the whole noble publish. Only a later run recovers. Seen in the 2026-09-07 scheduled run and in push run 34645083284 on 2026-09-11 — added 2026-09-11 — GP7; found merging the Dependabot bumps
- Refuse to move moving tags backward: a "Re-run failed jobs" of an older `docker.yml` run's publish leg, inside the six-day digest retention, moves `latest`/`noble`/`resolute` back to that run's images over a newer publish; the publish leg could refuse when its date is older than the date tag the moving tag now carries — added 2026-10-20 — GP2; from M019 review
- [low] Add the failure script to push.paths: `docker.yml`'s `push.paths` filter omits `.github/ci-failure-issue.sh`, now load-bearing — added 2026-09-06 — from M015 review
- [low] Replace numbered Known issue citations: `scripts/resolve-rstudio-version.sh` and `scripts/mirror_hint.R` cite "Known issue #2" / "#1" against a DESIGN Known issues list that is unnumbered — convert to principle citations as M015 did for #3 — added 2026-09-06 — from M015 review
- [low] Scope permissions on the docker.yml jobs: `docker.yml`'s `meta`, `build` and `publish` jobs carry no `permissions:` block, where `notify` scopes itself — added 2026-09-06 — from M015 review
- [low] Remove the old pdf .gitignore entry: `.gitignore` entry `cairn/references/pdf/` is superseded by `cairn/references/sources/` (cairn_validate advisory); repair via `/cairn-init` — added 2026-09-06
