# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-07 (M018 done and archived; the untested date reduction and the missing self-report filed as candidates)_
_Released 2.2.0 2026-09-04 (tag v2.2.0 at e0893aa; history re-released under semver, D-005)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M017 | Report a failing keepalive job | done | — | high | milestones/archive/M017-report-failing-keepalive.md |
| M018 | Alert when no weekly rebuild has succeeded in too long | done | M017 | normal | milestones/archive/M018-rebuild-gap-alert.md |
| M016 | Keep the weekly rebuild alive | done | — | normal | milestones/archive/M016-weekly-rebuild-keepalive.md |
<!-- rows grouped by status, not sorted by ID; keep only the 3 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
- Pre-merge arm64 smoke in `pr-ci.yml` — run the deepened smoke on a native arm64 build in the PR lane too; deferred from M05 for PR-CI speed, and no longer needs emulation since M015 — added 2026-07-17 — GP3; from M05
- Verify the launcher-resolved port against a real Compose (both launcher harnesses stub `docker`) — fold into the container smoke lane — added 2026-07-18 — GP3; deferred from M09
- macOS runner executing `start_mac.command` on real macOS in the launcher lane — added 2026-07-18 — GP3; deferred from M09
- `.github/ci-failure-issue.sh` names only jobs whose `.conclusion` is `failure`, but `needs.<job>.result` reports `failure` for a `timed_out` job too — such a run falls back to generic text and emits the contradiction warning blaming the parser — added 2026-09-07 — from M017 review
- Failed job names are joined on a space in the `ci-failure` title, so a future multi-word job name would render ambiguously; a separator change falsifies M017's AC4 wording — added 2026-09-07 — from M017 review (corrected M018: the gap check ships a one-word job name, so it is no longer the example)
- The keepalive `git push` has no contention handling: a bare push from a shallow checkout with no `concurrency:` group in `docker.yml`, so a maintainer push landing between checkout and push fails non-fast-forward with no retry; the test stub always exits 0, so no failing-push path is exercised — added 2026-09-07 — from M016 review
- `rebuild-gap.yml`'s date reduction has no committed test: its three branches (a date, an empty result, an unreadable answer) live in YAML shell, so a lost branch would surface only in production as a red run raising nothing — added 2026-09-07 — from M018 review
- `rebuild-gap.yml` has no self-report: a step that fails for any reason yields a red run and GitHub's default email, where `docker.yml` carries a `notify` job for exactly that — added 2026-09-07 — from M018 review
- Docker Hub tag date as a second gap oracle: alert when the newest published `<variant>-<date>` tag is stale, measuring the user-visible freshness commitment rather than that a run happened — added 2026-09-07 — GP2; rejected as M018's oracle in favour of run history
- Read the first scheduled keepalive run: only dispatches have been exercised, so the schedule path's null `inputs` fallback and its `github.event.repository.default_branch` value are unevidenced — added 2026-09-07 — from M016 review
- Untagged manifests accumulate on Docker Hub: push-by-digest leaves four per run (test-mode runs tag none) with no GC step — added 2026-09-06 — from M015 review
- Re-print the offline "update was skipped" warning after the running banner: it prints before the up-to-180s health wait and scrolls off — added 2026-09-03 — GP1; deferred from M10 review
- A timeout reaching `r2u.stat.illinois.edu` in the noble amd64 smoke test (bspm install of data.table) fails the whole noble publish. Only a later run recovers. Seen in the 2026-09-07 scheduled run and in push run 34645083284 on 2026-09-11 — added 2026-09-11 — GP7; found merging the Dependabot bumps
- [low] `digests-<variant>-*` artifact pattern is prefix-based: a future variant name extending an existing one would be pulled into the shorter one's publish leg — added 2026-09-06 — from M015 review
- [low] `retention-days: 1` on the digest artifacts makes GitHub's "Re-run failed jobs" fail with a misleading message after 24h — added 2026-09-06 — from M015 review
- [low] `docker.yml`'s `push.paths` filter omits `.github/ci-failure-issue.sh`, now load-bearing — added 2026-09-06 — from M015 review
- [low] `scripts/resolve-rstudio-version.sh` and `scripts/mirror_hint.R` cite "Known issue #2" / "#1" against a DESIGN Known issues list that is unnumbered — convert to principle citations as M015 did for #3 — added 2026-09-06 — from M015 review
- [low] `docker.yml`'s `meta`, `build` and `publish` jobs carry no `permissions:` block, where `notify` scopes itself — added 2026-09-06 — from M015 review
- [low] `.gitignore` entry `cairn/references/pdf/` is superseded by `cairn/references/sources/` (cairn_validate advisory); repair via `/cairn-init` — added 2026-09-06
