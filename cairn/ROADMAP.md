# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-18 (M09 archived; M04 terminal row pruned to keep 5)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M09 | Launcher port consistency | done | — | normal | milestones/archive/M09-launcher-port-consistency.md |
| M08 | Windows launcher hardening | done | — | normal | milestones/archive/M08-windows-launcher-hardening.md |
| M07 | bspm mirror-failure UX | done | — | normal | milestones/archive/M07-bspm-mirror-ux.md |
| M06 | Harden the Pandoc version parses | done | — | normal | milestones/archive/M06-pandoc-version-parse-guard.md |
| M05 | Deepen the smoke test | done | — | normal | milestones/archive/M05-deepen-smoke-test.md |
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
- Pre-merge arm64 emulated smoke in `pr-ci.yml` — run the deepened smoke on an emulated arm64 build in the PR lane too; deferred from M05 for PR-CI speed — added 2026-07-17 — GP3; from M05
- Verify the launcher-resolved port against a real Compose (both launcher harnesses stub `docker`) — fold into the container smoke lane — added 2026-07-18 — GP3; deferred from M09
- macOS runner executing `start_mac.command` on real macOS in the launcher lane — added 2026-07-18 — GP3; deferred from M09
