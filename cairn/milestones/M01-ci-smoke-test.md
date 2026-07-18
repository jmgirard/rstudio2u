<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M01: CI smoke test before publishing moving tags

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** GP7, GP3
- **Branch/PR:** m01-ci-smoke-test · https://github.com/jmgirard/rstudio2u/pull/1

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

- [x] `.github/smoke-test.sh` exists: given a local image tag, it runs a
      container publishing `:8787`, polls the container health signal, tears the
      container down, and exits `0` when healthy within the timeout / non-zero on
      failure or timeout (GP7).
- [x] Evidence the script gates correctly: run against a freshly-built healthy
      amd64 image exits `0`; run against a container that never serves `:8787`
      exits non-zero (the failure path fires — the behavior this milestone must
      test).
- [x] `.github/workflows/docker.yml` is restructured so each matrix variant
      builds its amd64 image with `--load`, runs the smoke test, and performs the
      multi-arch build-and-push only if the smoke test passed; variants stay
      independent — a resolute smoke failure fails the resolute job (red) and
      never blocks noble's build/smoke/push (GP3, preview-tier).
- [x] `CHANGELOG.md` "Unreleased" notes the pre-push smoke gate.
- [x] verify slot clean: `hadolint Dockerfile` reports no violations and
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
- [x] T2: Verify locally — build the amd64 image
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
- [x] T5: Run the verify slot (`hadolint Dockerfile`, `docker build`) and confirm
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
- 2026-07-17: T5 — hadolint clean; `docker build --build-arg UBUNTU_VERSION=24.04`
  succeeds (native arm64, ~846MB; Dockerfile unchanged & arch-agnostic, amd64
  build exercised by CI).
- 2026-07-17: T2 — smoke script verified against the real image (exit 0) and
  three failure cases (unhealthy stand-in, container-exit, missing arg → exit 1).
  All tasks done; status → review.
- 2026-07-17: review — opened PR #1; AC evidence + consistency gate recorded.
  3-lens review: diff-bug found 2 cache-wiring findings (scored 85/80), fixed
  in place by restructuring docker.yml into build-both-arches → load-amd64-smoke
  → publish-from-cache (published image == smoke-tested image; arm64 emulated
  once). blame-history + prior-PR clean. actionlint clean post-fix.

## Decisions

## Review

_Reviewed 2026-07-17 · PR #1 · branch `m01-ci-smoke-test` · diff vs `main`:
5 files, +130/−9._

### Acceptance-criteria evidence (fresh, this session)

- **AC1** — `.github/smoke-test.sh` present (66 lines); `bash -n` + shellcheck
  (koalaman container) clean. Boots via `docker run -d -p 127.0.0.1:8787:8787`,
  polls `docker inspect .State.Health.Status`, `trap`-teardown always runs.
- **AC2** — healthy `rstudio2u` image → `PASS: container reported healthy`,
  exit 0. Failure paths all non-zero: unhealthy stand-in (same `:8787`
  HEALTHCHECK, no server) → `FAIL: healthcheck reported unhealthy`, exit 1;
  container that exits immediately → `FAIL: container exited before becoming
  healthy`, exit 1; missing image-tag arg → usage error, exit 1.
- **AC3** — `docker.yml` restructured (final, post-review) into three steps:
  (1) build BOTH arches once into the cache (`push: false`, owns cache-to),
  (2) load amd64 from that cache (`load: true`, cache-from only) → `Smoke-test`
  step (`bash ./.github/smoke-test.sh …`), (3) multi-arch `push: true`
  (cache-from only) — so the published image is exactly the one smoke-tested.
  Smoke abort precedes the push step, so a failure blocks publishing.
  `fail-fast: false` keeps noble/resolute as independent jobs (resolute failure
  red, noble unaffected). actionlint clean. NOTE: the live in-Actions gate first
  runs on merge to `main` (workflow triggers on push-to-main / dispatch /
  schedule, not feature branches) — restructure validated by actionlint + local
  script runs.
- **AC4** — `CHANGELOG.md` "Unreleased / Changed" entry present, user-facing,
  no milestone number.
- **AC5** — `hadolint Dockerfile` clean; `docker build --build-arg
  UBUNTU_VERSION=24.04` → exit 0 (~846 MB). Local build is native arm64; the
  Dockerfile is unchanged & arch-agnostic and CI exercises the amd64 build.

### Consistency gate

- Universal: `cairn_validate` exit 0, all checks pass. No DESIGN principle
  changed on this branch (the plan-phase principle-format fix landed on `main`
  earlier) → `cairn_impact` skipped.
- Toolchain (docker-image `consistency-gate`): `docker build` succeeds from a
  clean context; `hadolint` clean; base pinned to a version tag
  (`rocker/r2u:${UBUNTU_VERSION}` → 24.04, not bare `latest`); no secrets in
  `ENV`/`ARG`/`COPY`; `.dockerignore` present (excludes `.git`, `.github`,
  `cairn`, `CHANGELOG.md`); changelog entry present for the user-visible change.

### Independent review — 3 lenses + scorer

- **[O] diff-bug (Opus):** 2 findings, both in the cache wiring between the two
  build steps (see resolution). Script logic, gating, IP2 localhost bind all
  judged sound.
- **[S] blame-history (Sonnet):** No findings — weekly no-cache rebuild,
  `pull: true`, multi-arch push, and immutable+moving tag set all preserved; no
  D-entry contradicted.
- **[S] prior-PR-comments (Sonnet):** No prior-PR evidence (PR #1 is the first).
- **[S] scorer (Sonnet):** F1 = 85, F2 = 80 (both actioned, ≥80).

**Findings actioned (both fixed in review, commit on branch):**

1. (85) On `schedule`/`workflow_dispatch` runs `no-cache: true` made BuildKit
   ignore `cache-from`, so the old push step rebuilt amd64 from scratch instead
   of reusing the smoke-tested layers — the unattended weekly rebuild (exactly
   the GP7 scenario) would publish a *second, un-smoke-tested* amd64 build.
2. (80) The amd64-only smoke build's `cache-to` on the shared scope shadowed the
   prior run's arm64 cache, forcing a full QEMU-emulated arm64 rebuild every
   push — an efficiency regression the diff introduced.

**Resolution:** restructured into three steps — build both arches once into the
cache (sole cache writer) → load amd64 from cache for smoke → publish both arches
from the same cache (cache-from only, no `no-cache`). The published image is now
byte-for-byte the smoke-tested one, and the emulated arm64 build runs exactly
once per run. actionlint clean after the fix.
