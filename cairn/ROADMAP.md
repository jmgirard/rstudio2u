# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-03 (M12 done and archived; M07 row pruned; LESSONS M06 stdin-fixture line pruned for the cap)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M13 | Weekly rebuild failure alert | review | — | normal | milestones/M13-rebuild-failure-alert.md |
| M12 | Docker Hub description sync | done | — | normal | milestones/archive/M12-dockerhub-description-sync.md |
| M11 | Shell lint in CI | done | — | normal | milestones/archive/M11-shell-lint-ci.md |
| M10 | Launcher offline fallback | done | — | normal | milestones/archive/M10-launcher-offline-fallback.md |
| M09 | Launcher port consistency | done | — | normal | milestones/archive/M09-launcher-port-consistency.md |
| M08 | Windows launcher hardening | done | — | normal | milestones/archive/M08-windows-launcher-hardening.md |
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
- Pre-merge arm64 emulated smoke in `pr-ci.yml` — run the deepened smoke on an emulated arm64 build in the PR lane too; deferred from M05 for PR-CI speed — added 2026-07-17 — GP3; from M05
- Verify the launcher-resolved port against a real Compose (both launcher harnesses stub `docker`) — fold into the container smoke lane — added 2026-07-18 — GP3; deferred from M09
- macOS runner executing `start_mac.command` on real macOS in the launcher lane — added 2026-07-18 — GP3; deferred from M09
- Harden the arm64 emulated smoke `quarto render` against the same transient QEMU/Deno SIGILL the build install now retries — `.github/smoke-test.sh` runs Deno under emulation and can flaky-crash identically — added 2026-07-21 — GP3, GP7; from the quarto-qemu-retry hotfix
- Keep the weekly rebuild alive: GitHub disables scheduled workflows after 60 days without repo activity, silently ending the always-fresh commitment — a keepalive step or a documented check — added 2026-09-03 — GP7; from M13 planning
- Re-print the offline "update was skipped" warning after the running banner: it prints before the up-to-180s health wait and scrolls off — added 2026-09-03 — GP1; deferred from M10 review
