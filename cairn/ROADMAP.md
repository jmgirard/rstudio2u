# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-06 (M016 planned; the keepalive candidate row absorbed and replaced by a rebuild-gap-alert row)_
_Released 2.2.0 2026-09-04 (tag v2.2.0 at e0893aa; history re-released under semver, D-005)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M016 | Keep the weekly rebuild alive | in-progress | — | normal | milestones/M016-weekly-rebuild-keepalive.md |
| M015 | Native arm64 runners for the image build | done | — | high | milestones/archive/M015-native-arm64-runners.md |
| M014 | Semver release history | done | — | normal | milestones/archive/M014-semver-release-history.md |
| M13 | Weekly rebuild failure alert | done | — | normal | milestones/archive/M13-rebuild-failure-alert.md |
<!-- rows grouped by status, not sorted by ID; keep only the 3 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
- Pre-merge arm64 smoke in `pr-ci.yml` — run the deepened smoke on a native arm64 build in the PR lane too; deferred from M05 for PR-CI speed, and no longer needs emulation since M015 — added 2026-07-17 — GP3; from M05
- Verify the launcher-resolved port against a real Compose (both launcher harnesses stub `docker`) — fold into the container smoke lane — added 2026-07-18 — GP3; deferred from M09
- macOS runner executing `start_mac.command` on real macOS in the launcher lane — added 2026-07-18 — GP3; deferred from M09
- Rebuild-gap alert: notice that no successful weekly rebuild has run in too long (any cause, not just a disabled schedule) and raise the existing ci-failure issue — added 2026-09-06 — GP2, GP7; deferred from M016 planning
- Untagged manifests accumulate on Docker Hub: push-by-digest leaves four per run (test-mode runs tag none) with no GC step — added 2026-09-06 — from M015 review
- Re-print the offline "update was skipped" warning after the running banner: it prints before the up-to-180s health wait and scrolls off — added 2026-09-03 — GP1; deferred from M10 review
- [low] `HEALTHCHECK ... CMD wget … || exit 1` trips DL3025 on hadolint newer than the 2.12.0 the PR lane pins; the shell form is required for the `||`, so this is a JSON-form rewrite or a pinned ignore — added 2026-09-06 — found running current hadolint at M015
- [low] `digests-<variant>-*` artifact pattern is prefix-based: a future variant name extending an existing one would be pulled into the shorter one's publish leg — added 2026-09-06 — from M015 review
- [low] `retention-days: 1` on the digest artifacts makes GitHub's "Re-run failed jobs" fail with a misleading message after 24h — added 2026-09-06 — from M015 review
- [low] `docker.yml`'s `push.paths` filter omits `.github/ci-failure-issue.sh`, now load-bearing — added 2026-09-06 — from M015 review
- [low] `scripts/resolve-rstudio-version.sh` and `scripts/mirror_hint.R` cite "Known issue #2" / "#1" against a DESIGN Known issues list that is unnumbered — convert to principle citations as M015 did for #3 — added 2026-09-06 — from M015 review
- [low] `docker.yml`'s `meta`, `build` and `publish` jobs carry no `permissions:` block, where `notify` scopes itself — added 2026-09-06 — from M015 review
- [low] `.gitignore` entry `cairn/references/pdf/` is superseded by `cairn/references/sources/` (cairn_validate advisory); repair via `/cairn-init` — added 2026-09-06
