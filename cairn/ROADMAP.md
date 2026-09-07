# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-06 (M015 T4: reworded the pr-ci arm64 candidate off "emulated"; added the [low] hadolint DL3025 row)_
_Released 2.2.0 2026-09-04 (tag v2.2.0 at e0893aa; history re-released under semver, D-005)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M015 | Native arm64 runners for the image build | in-progress | — | high | milestones/M015-native-arm64-runners.md |
| M014 | Semver release history | done | — | normal | milestones/archive/M014-semver-release-history.md |
| M13 | Weekly rebuild failure alert | done | — | normal | milestones/archive/M13-rebuild-failure-alert.md |
| M12 | Docker Hub description sync | done | — | normal | milestones/archive/M12-dockerhub-description-sync.md |
<!-- rows grouped by status, not sorted by ID; keep only the 3 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Image-size budget: slimming pass + baseline + CI size-regression guard — added 2026-07-17 — GP5
- resolute (26.04) graduation path: define when the preview variant becomes committed — added 2026-07-17 — GP2
- Pre-merge arm64 smoke in `pr-ci.yml` — run the deepened smoke on a native arm64 build in the PR lane too; deferred from M05 for PR-CI speed, and no longer needs emulation since M015 — added 2026-07-17 — GP3; from M05
- Verify the launcher-resolved port against a real Compose (both launcher harnesses stub `docker`) — fold into the container smoke lane — added 2026-07-18 — GP3; deferred from M09
- macOS runner executing `start_mac.command` on real macOS in the launcher lane — added 2026-07-18 — GP3; deferred from M09
- Keep the weekly rebuild alive: GitHub disables scheduled workflows after 60 days without repo activity, silently ending the always-fresh commitment — a keepalive step or a documented check — added 2026-09-03 — GP7; from M13 planning
- [low] `HEALTHCHECK ... CMD wget … || exit 1` trips DL3025 on hadolint newer than the 2.12.0 the PR lane pins; the shell form is required for the `||`, so this is a JSON-form rewrite or a pinned ignore — added 2026-09-06 — found running current hadolint at M015
- Re-print the offline "update was skipped" warning after the running banner: it prints before the up-to-180s health wait and scrolls off — added 2026-09-03 — GP1; deferred from M10 review
