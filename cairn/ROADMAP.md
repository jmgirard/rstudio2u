# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-06 (triage pass: QEMU/Quarto row split into a [high] stale-moving-tags row and the emulated-smoke render row; 13 other items kept; M11 and M10 rows pruned to the 3-row retention; no drops, merges, routes, or compressions; no decision entry; validate green)_
_Released 2.2.0 2026-09-04 (tag v2.2.0 at e0893aa; history re-released under semver, D-005)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M014 | Semver release history | done | — | normal | milestones/archive/M014-semver-release-history.md |
| M13 | Weekly rebuild failure alert | done | — | normal | milestones/archive/M13-rebuild-failure-alert.md |
| M12 | Docker Hub description sync | done | — | normal | milestones/archive/M12-dockerhub-description-sync.md |
<!-- rows grouped by status, not sorted by ID; keep only the 3 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- [high] A 5-attempt build-install retry does not survive the QEMU/Deno SIGILL: it exhausted on the noble weekly rebuild (2026-08-17, 2026-08-31, 2026-09-03) and `latest`/`noble` did not refresh 2026-08-24 → 2026-09-04, so a fix beyond retrying is needed — added 2026-07-21 — GP2, GP7; from the quarto-qemu-retry hotfix, split 2026-09-06 (observed at M13 review)
- Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
- Pre-merge arm64 emulated smoke in `pr-ci.yml` — run the deepened smoke on an emulated arm64 build in the PR lane too; deferred from M05 for PR-CI speed — added 2026-07-17 — GP3; from M05
- Verify the launcher-resolved port against a real Compose (both launcher harnesses stub `docker`) — fold into the container smoke lane — added 2026-07-18 — GP3; deferred from M09
- macOS runner executing `start_mac.command` on real macOS in the launcher lane — added 2026-07-18 — GP3; deferred from M09
- Harden the arm64 emulated smoke `quarto render` against the transient QEMU/Deno SIGILL the build install already retries — `.github/smoke-test.sh` runs Deno under emulation and can flaky-crash identically — added 2026-07-21 — GP3, GP7; from the quarto-qemu-retry hotfix, split 2026-09-06
- Keep the weekly rebuild alive: GitHub disables scheduled workflows after 60 days without repo activity, silently ending the always-fresh commitment — a keepalive step or a documented check — added 2026-09-03 — GP7; from M13 planning
- Re-print the offline "update was skipped" warning after the running banner: it prints before the up-to-180s health wait and scrolls off — added 2026-09-03 — GP1; deferred from M10 review
