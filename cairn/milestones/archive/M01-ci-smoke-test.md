# M01: CI smoke test before publishing moving tags — done 2026-07-17

**Goal:** Gate the CI publish step on booting the built image and confirming
RStudio Server answers on :8787, so an unattended rebuild can't push a moving
tag whose server won't start (GP7).

**Outcome:** Added `.github/smoke-test.sh` — boot an image, poll its :8787
HEALTHCHECK via `docker inspect`, fail on container-exit / unhealthy / timeout,
always tear down; host-port fallback for no-HEALTHCHECK images. Restructured
`.github/workflows/docker.yml` into: build both arches once into the cache (sole
writer) → load amd64 from cache for smoke → publish both from the same cache —
so the published image is exactly the smoke-tested one and arm64 is emulated
once per run. CHANGELOG entry added.

**Key decisions:** amd64-only smoke gate (multi-arch can't be `--load`ed; QEMU
arm64 boot slow/flaky — arm64 built & pushed but not boot-checked, documented
GP3 asymmetry); resolute smoke failure fails its own job but never blocks noble.

**Review:** 3 lenses + scorer. diff-bug found 2 cache-wiring findings (85/80) —
old design republished an un-smoke-tested amd64 rebuild on scheduled runs and
shadowed the arm64 cache; both fixed in review. blame-history + prior-PR clean.
All 5 ACs verified with fresh evidence. **PR #1** (squash c6d705b).
