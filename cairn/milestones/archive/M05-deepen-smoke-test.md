# M05: Deepen the smoke test — DONE (2026-07-18)

Goal: make the CI smoke test exercise the toolchain (bspm binary install +
Quarto render) and boot arm64 before publish, so arm64 parity drift is caught
instead of shipping silently (Known issue #3). PR #6.

Outcome:
- .github/smoke-test.sh: phase 1 (server up on :8787, now breaks not exits) +
  phase 2 — bspm install of data.table asserted apt-registered (r-cran-*, the
  binary path not source) and loads; chunk-free .qmd rendered to HTML (targets
  the arch-sensitive Quarto CLI, no R package needed).
- docker.yml: single-platform arm64 load + QEMU smoke before publish
  (SMOKE_TIMEOUT 900); a broken arm64 toolchain now blocks the ship (GP3/GP7).
- Both workflows' paths: filters watch .github/smoke-test.sh (absorbed the M02
  follow-up, candidate #8).
- CHANGELOG smoke-test bullet strengthened to the deepened both-arch guarantee.

Verified: deepened smoke green on amd64 (pr-ci) and native arm64 (local);
forced-failures exit non-zero. Gate clean; 3-lens review 0 findings.

Decisions (gate): arm64 on publish path only (pre-merge arm64 emulation
deferred → candidate); HTML render only (no PDF/LaTeX). install_quarto.sh
native-arm64 .deb refresh stays a separate candidate (remediation vs detection).

Principles: IP1 (bspm binary path), GP3 (arm64 parity), GP7 (never ship broken).
