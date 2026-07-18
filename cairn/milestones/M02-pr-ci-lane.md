<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M02: Pre-merge PR CI lane

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** GP7, GP3
- **Branch/PR:** m02-pr-ci-lane · https://github.com/jmgirard/rstudio2u/pull/2

## Goal

Add a `pull_request`-triggered CI lane that lints, builds (amd64/noble), and
smoke-tests the image, so no branch merges without a verified-bootable image —
closing the pre-merge gap M01 left (GP7).

## Scope

**In:** A new `.github/workflows/pr-ci.yml` triggered on `pull_request` to the
default branch, with the same path filter as `docker.yml` (`Dockerfile`,
`scripts/**`, `.github/workflows/**`). One `ubuntu-latest` job: `hadolint
Dockerfile` → build **noble amd64** (`UBUNTU_VERSION=24.04`, `RSTUDIO_VERSION`
default `stable`; `load: true`, `push: false`, `cache-from` the shared gha
`scope=noble`) → run the existing `.github/smoke-test.sh`. No Docker Hub login,
no version scrape, no immutable tags, no push.

**Out:**
- resolute in the PR lane → stays candidate G / noble-only by decision this
  session; a later extension may add it non-blocking (preview tier).
- arm64 boot-check on PRs → not done; multi-arch can't be `--load`ed (M01's
  documented GP3 asymmetry). arm64 is still built + pushed at publish time on
  `docker.yml`.
- Deeper smoke (real bspm install / `quarto render`) → candidate C.
- CHANGELOG entry → none: PR CI is dev-facing and changes nothing a user
  pulling the image sees (deliberate omission, not a miss).
- Branch-protection "required check" toggle → a GitHub repo setting, not a
  committed file; cairn's review gate already refuses to merge red/pending CI.

## Acceptance criteria

- [x] `.github/workflows/pr-ci.yml` exists, triggers on `pull_request` to the
      default branch with the `docker.yml` path filter, and its job runs
      `hadolint` → build(amd64, noble, `push: false`) → `.github/smoke-test.sh`;
      the file contains no Docker Hub login step and no `push: true`.
- [x] This milestone's own PR shows the `pr-ci` check green: hadolint reports no
      violations, the amd64 noble image builds, and smoke confirms RStudio
      Server answers on :8787 (evidence: `gh pr checks`).
- [x] A PR run publishes nothing: no login step runs and no image is pushed
      (`push: false` throughout; no new Docker Hub tags appear).
- [x] The gate blocks a bad image: a scratch branch introducing a smoke-failing
      image change opens a PR whose `pr-ci` check goes red at the smoke step
      (evidence: link to the failed run).
- [x] Profile `verify` floor clean: `hadolint Dockerfile` reports no violations
      and `docker build --build-arg UBUNTU_VERSION=24.04` succeeds locally.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3
- AC5 → T4

## Tasks

- [x] T1: Author `.github/workflows/pr-ci.yml` — `pull_request` trigger on the
      default branch + path filter (`Dockerfile`, `scripts/**`,
      `.github/workflows/**`); one `ubuntu-latest` job: checkout →
      setup-buildx → `hadolint Dockerfile` → `docker/build-push-action`
      (`platforms: linux/amd64`, `load: true`, `push: false`, `build-args:
      UBUNTU_VERSION=24.04`, `cache-from: type=gha,scope=noble`, tag
      `:smoke-noble`) → `bash ./.github/smoke-test.sh`. No login, no
      version-scrape, no `cache-to`, no `push`.
- [x] T2: Green-path evidence — push the `m02-pr-ci-lane` branch, open its PR,
      confirm the `pr-ci` check runs and passes via `gh pr checks`, and confirm
      from the run log that no login/push occurred.
- [x] T3: Negative test — on a throwaway scratch branch introduce a
      smoke-failing image change (e.g. break the entrypoint/healthcheck), open a
      disposable PR, confirm `pr-ci` goes red at the smoke step, capture the
      failing-run link, then close the PR and delete the branch.
- [x] T4: Local profile verify — run `hadolint Dockerfile` and
      `docker build --build-arg UBUNTU_VERSION=24.04 -t rstudio2u-verify .`;
      both clean.

## Work log

- 2026-07-17: created by /milestone-plan (promoted from candidate A; extends M01).
- 2026-07-17: T1 — authored `.github/workflows/pr-ci.yml` (hadolint → build amd64/noble → smoke, no login/push); hadolint clean on Dockerfile (exit 0), actionlint clean on the workflow.
- 2026-07-17: T4 — local verify: `hadolint Dockerfile` clean (exit 0); `docker build --build-arg UBUNTU_VERSION=24.04` succeeds (854MB); bonus local smoke on the built image reported healthy.
- 2026-07-17: T2 — opened milestone PR #2 (https://github.com/jmgirard/rstudio2u/pull/2); pr-ci lane triggered on it.
- 2026-07-17: T2 — pr-ci `build-smoke` PASSED in 2m24s on PR #2 (run 29623616590): hadolint clean, amd64 noble built, smoke "PASS: container reported healthy". Step list confirms no Docker Hub login step and `push: false` (AC2, AC3).
- 2026-07-17: T3 — negative test on throwaway PR #3 (broken entrypoint `CMD ["/bin/false"]`): pr-ci `build-smoke` FAILED in 2m46s (run 29623752356), failure at the *Smoke-test* step — "FAIL: container exited before becoming healthy" (lint+build succeeded first). Gate proven to block a bad image (AC4). PR closed, scratch branch deleted.
- 2026-07-17: all tasks done; status → review. Milestone PR #2 open with green pr-ci. Note: later cairn-only commits don't retrigger pr-ci (path filter excludes `cairn/`), so the green run sits on the image-relevant commit, not the PR head.
- 2026-07-17 (review): CORRECTION to the note above — it is WRONG. For `pull_request`, the `paths` filter matches the whole-PR diff, which always contains `pr-ci.yml` (`.github/workflows/**`), so every push reaching origin retriggers pr-ci regardless of touching only `cairn/` (confirmed: runs on a8a5c92/222789e/c79bbd5; T2/T3 weren't pushed individually, which is why they had no separate run).
- 2026-07-17 (review): CORRECTION — T4 logged the local image as "854MB"; current observed size is 3.37GB (the 854MB figure was inaccurate). Image size is not an M02 criterion; lean-image work is candidate D.

## Decisions

## Review

_Reviewed 2026-07-17. Branch `m02-pr-ci-lane` → PR #2. `main` in sync at review (branch contains all of `main`; no merge needed)._

### Acceptance criteria — fresh evidence

- **AC1 (workflow structure):** PASS. `pr-ci.yml` present; `pull_request` trigger on `branches: [main]`, paths `Dockerfile`/`scripts/**`/`.github/workflows/**` (lines 9–14); steps Lint (hadolint-action@v3.1.0) → Build noble amd64 (`platforms: linux/amd64`, `load: true`, `push: false`, `cache-from scope=noble`) → `bash ./.github/smoke-test.sh` (line 54). No `docker/login-action`; grep confirms only `push: false`.
- **AC2 (green on milestone PR):** PASS. PR #2 run 29623616590 `build-smoke` success in 2m24s — hadolint clean, amd64 noble built, smoke "PASS: container reported healthy"; all steps success.
- **AC3 (publishes nothing):** PASS. No login step and `push: false` throughout — publishing is mechanically impossible on a PR run. (The `"login": "jmgirard"` strings in the build-metadata log are GitHub event-context JSON, not a registry login.)
- **AC4 (gate blocks a bad image):** PASS. Throwaway PR #3 (broken entrypoint `CMD ["/bin/false"]`) run 29623752356 `build-smoke` FAILED in 2m46s at the *Smoke-test* step — "FAIL: container exited before becoming healthy" (lint+build passed first, so the smoke gate itself bites). PR closed, branch deleted.
- **AC5 (local verify floor):** PASS. `hadolint Dockerfile` clean (exit 0, re-run at review); `docker build --build-arg UBUNTU_VERSION=24.04` succeeded (image present, 3.37GB).

### Consistency gate

- Universal: `cairn_validate.py` — all checks PASS (exit 0). No DESIGN principle text changed (GP7/GP3 worked-under, not modified) → `cairn_impact` correctly skipped.
- Toolchain (docker-image): `docker build` succeeds + `hadolint` clean; base image pinned (`rocker/r2u:24.04`); no secrets in layers; `.dockerignore` present, excludes `.git`/`cairn`/etc.; CHANGELOG — N/A (no user-visible image change; deliberate per Scope Out).

### Independent review — 3 lenses + scorer

- **[O] diff-bug (Opus):** one borderline finding (F1 below); confirmed trigger, cache-from read-only, load+amd64, no-publish, pinned actions, and smoke correctness all sound.
- **[S] blame-history (Sonnet):** no findings. `cache-from`-only can't shadow docker.yml's `scope=noble` cache (M01 lesson honored); D-001/GP7/GP3 intact; docker.yml/smoke-test.sh/Dockerfile byte-for-byte unchanged.
- **[S] prior-PR (Sonnet):** no prior-PR evidence — no findings (PR #1 carries no review comments).

Scored: 1 finding. Below-80 findings: none.

- **F1 (score 80) — path filter excludes `.github/smoke-test.sh`.** `pr-ci.yml:9-14` watches `Dockerfile`/`scripts/**`/`.github/workflows/**`, but the harness the lane runs (`.github/smoke-test.sh`) is outside that filter, so a PR editing only that script wouldn't retrigger `pr-ci` — the gate can't self-validate changes to its own health probe. **Triage: follow-up candidate** (user decision 2026-07-17); M02 meets AC1 as written (docker.yml-style filter), and the hardening is tracked as a ROADMAP candidate.
