<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M01: CI smoke test before publishing moving tags

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** GP7, GP3
- **Branch/PR:** m01-ci-smoke-test

## Goal

Gate the CI publish step on booting the freshly-built image and confirming
RStudio Server answers on `:8787`, so an unattended rebuild can never push a
moving tag whose server won't start.

## Scope

**In:** A standalone, locally-runnable smoke-test script that boots a container
from a given local image tag, waits for the `:8787` healthcheck, and exits
non-zero on failure or timeout. Restructuring `.github/workflows/docker.yml`
from its current atomic build-and-push into **build amd64 (`--load`) →
smoke-test → multi-arch build-and-push**, per matrix variant, so a failing
smoke test blocks that variant's push. A CHANGELOG entry.

**Out:**
- arm64 boot-testing → not done here; arm64 is still built and pushed, just not
  boot-checked (documented asymmetry licensed by GP3 — QEMU-emulated RStudio
  boot is slow and flaky). Revisit as a candidate if arm64-only breakage recurs.
- Separately smoke-testing the immutable `<variant>-<date>`/`<variant>-<rstudio>`
  tags → same build as the moving tags; if the build is broken they all are, and
  the one gate covers the whole build.
- Vulnerability scanning (trivy/grype) and `container-structure-test` → profile
  marks these optional/diagnostic; not needed to close GP7.

## Acceptance criteria

- [ ] `.github/smoke-test.sh` exists: given a local image tag, it runs a
      container publishing `:8787`, polls the container health signal, tears the
      container down, and exits `0` when healthy within the timeout / non-zero on
      failure or timeout (GP7).
- [ ] Evidence the script gates correctly: run against a freshly-built healthy
      amd64 image exits `0`; run against a container that never serves `:8787`
      exits non-zero (the failure path fires — the behavior this milestone must
      test).
- [ ] `.github/workflows/docker.yml` is restructured so each matrix variant
      builds its amd64 image with `--load`, runs the smoke test, and performs the
      multi-arch build-and-push only if the smoke test passed; variants stay
      independent — a resolute smoke failure fails the resolute job (red) and
      never blocks noble's build/smoke/push (GP3, preview-tier).
- [ ] `CHANGELOG.md` "Unreleased" notes the pre-push smoke gate.
- [ ] verify slot clean: `hadolint Dockerfile` reports no violations and
      `docker build` succeeds.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4
- AC5 → T5

## Tasks

- [x] T1: Write `.github/smoke-test.sh` — argument: local image tag (timeout
      overridable via env). `docker run -d -p 127.0.0.1:8787:8787` the image,
      poll `docker inspect --format '{{.State.Health.Status}}'` (the Dockerfile
      already defines the `:8787` HEALTHCHECK) until `healthy` or timeout, always
      tear the container down, and exit with clear pass/fail logging.
- [ ] T2: Verify locally — build the amd64 image
      (`docker build --build-arg UBUNTU_VERSION=24.04 -t rstudio2u:smoke .`), run
      the script against it (expect exit 0); run the script against a container
      that never serves `:8787` (expect non-zero). Capture both outputs as
      review evidence.
- [x] T3: Restructure `.github/workflows/docker.yml` — before the existing
      build-push step, add an amd64 `load: true` build (cache-to the variant
      scope) plus a step invoking `.github/smoke-test.sh`; keep the multi-arch
      build-push (cache-from the same scope, so amd64 layers are reused). Preserve
      per-variant matrix independence; a resolute smoke failure fails only its own
      job.
- [x] T4: Add a `CHANGELOG.md` "Unreleased" entry for the smoke gate.
- [ ] T5: Run the verify slot (`hadolint Dockerfile`, `docker build`) and confirm
      clean.

## Work log

- 2026-07-17: created by /milestone-plan. Promotes the "CI smoke test before
  push" ROADMAP candidate (added 2026-07-17, GP7).
- 2026-07-17: T1 — wrote `.github/smoke-test.sh` (docker-inspect health poll,
  container-exit + unhealthy + timeout fail paths, always-teardown, port-probe
  fallback for no-healthcheck images). bash -n + shellcheck (via container) clean.
- 2026-07-17: T3 — restructured docker.yml into amd64 `--load` build →
  smoke step → multi-arch push; smoke abort blocks the push, fail-fast:false
  keeps resolute independent of noble. actionlint clean.
- 2026-07-17: T4 — CHANGELOG.md Unreleased/Changed entry for the pre-push
  smoke gate (no milestone number, user-facing).

## Decisions

## Review
