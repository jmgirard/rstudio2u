<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M02: Pre-merge PR CI lane

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** GP7, GP3
- **Branch/PR:** m02-pr-ci-lane

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

- [ ] `.github/workflows/pr-ci.yml` exists, triggers on `pull_request` to the
      default branch with the `docker.yml` path filter, and its job runs
      `hadolint` → build(amd64, noble, `push: false`) → `.github/smoke-test.sh`;
      the file contains no Docker Hub login step and no `push: true`.
- [ ] This milestone's own PR shows the `pr-ci` check green: hadolint reports no
      violations, the amd64 noble image builds, and smoke confirms RStudio
      Server answers on :8787 (evidence: `gh pr checks`).
- [ ] A PR run publishes nothing: no login step runs and no image is pushed
      (`push: false` throughout; no new Docker Hub tags appear).
- [ ] The gate blocks a bad image: a scratch branch introducing a smoke-failing
      image change opens a PR whose `pr-ci` check goes red at the smoke step
      (evidence: link to the failed run).
- [ ] Profile `verify` floor clean: `hadolint Dockerfile` reports no violations
      and `docker build --build-arg UBUNTU_VERSION=24.04` succeeds locally.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3
- AC5 → T4

## Tasks

- [ ] T1: Author `.github/workflows/pr-ci.yml` — `pull_request` trigger on the
      default branch + path filter (`Dockerfile`, `scripts/**`,
      `.github/workflows/**`); one `ubuntu-latest` job: checkout →
      setup-buildx → `hadolint Dockerfile` → `docker/build-push-action`
      (`platforms: linux/amd64`, `load: true`, `push: false`, `build-args:
      UBUNTU_VERSION=24.04`, `cache-from: type=gha,scope=noble`, tag
      `:smoke-noble`) → `bash ./.github/smoke-test.sh`. No login, no
      version-scrape, no `cache-to`, no `push`.
- [ ] T2: Green-path evidence — push the `m02-pr-ci-lane` branch, open its PR,
      confirm the `pr-ci` check runs and passes via `gh pr checks`, and confirm
      from the run log that no login/push occurred.
- [ ] T3: Negative test — on a throwaway scratch branch introduce a
      smoke-failing image change (e.g. break the entrypoint/healthcheck), open a
      disposable PR, confirm `pr-ci` goes red at the smoke step, capture the
      failing-run link, then close the PR and delete the branch.
- [ ] T4: Local profile verify — run `hadolint Dockerfile` and
      `docker build --build-arg UBUNTU_VERSION=24.04 -t rstudio2u-verify .`;
      both clean.

## Work log

- 2026-07-17: created by /milestone-plan (promoted from candidate A; extends M01).

## Decisions

## Review
