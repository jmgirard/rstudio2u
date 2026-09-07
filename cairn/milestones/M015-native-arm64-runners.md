# M015: Native arm64 runners for the image build

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP3, GP7
- **Resolves:** —
- **Surface tier:** user-facing — the deliverable is the lane that publishes the moving tags users pull
- **Branch/PR:** m015-native-arm64-runners

## Goal

Build and smoke-test each architecture on a runner of that architecture, so
Quarto's bundled Deno never runs under QEMU and the noble moving tags refresh
on schedule.

## Scope

**In:** `docker.yml` restructured to build and boot each variant/arch pair on a
native runner (`ubuntu-latest` for amd64, GitHub's hosted arm64 label for
arm64), push each arch by digest, and assemble the manifest list with the full
tag list in a per-variant merge job; a dispatch test mode that exercises that
lane without attaching a tag; `docker/setup-qemu-action` dropped; the
scheduled-failure alert kept working against the new job names; the QEMU
motivation corrected wherever the repo's prose states it; `DESIGN.md`
Conventions and Known issues updated. This absorbs the candidate row asking
for the arm64 smoke `quarto render` to be hardened against the same crash —
removing emulation removes it from the render too.

**Out:** an arm64 leg in `pr-ci.yml` → the existing candidate row, rewritten by
T4 now that it needs no emulation. Removing `scripts/retry.sh` or its wrapping
of the quarto calls → stays; it still rides out genuine transients. Image-size
budget, resolute graduation, weekly-rebuild keepalive → their own candidate
rows.

## Acceptance criteria

- [ ] AC1: A test-mode `workflow_dispatch` run of the branch's `docker.yml` —
      layers pushed by digest, no tag attached — prints from
      `docker buildx imagetools create --dry-run` a noble manifest list naming
      both `linux/amd64` and `linux/arm64`, and prints the tag list it would
      apply, containing `latest`, `noble`, `noble-<UTC date>` and
      `noble-<rstudio version>` (GP2's escape hatch).
- [ ] AC2: Reading every step of the merged `.github/workflows/docker.yml` top
      to bottom finds no `docker/setup-qemu-action` step, and finds each build
      step's `platforms:` value equal to the single native architecture of the
      runner its job declares.
- [ ] AC3: In the AC1 run, the arm64 leg boots an image whose
      `docker image inspect --format '{{.Architecture}}'` is `arm64` and whose
      container answers `aarch64` to `uname -m`, and `.github/smoke-test.sh`
      against that image logs `PASS: quarto rendered .qmd to HTML`.
- [ ] AC4: `scripts/tests/test_ci_failure_issue.sh` exercises the shipped
      failed-variant extraction — the merged `docker.yml` invokes it and keeps
      no second inline copy — over fixtures shaped like the new matrix's
      `gh run view --json jobs` output, covering (a) one variant's arm64 leg
      failing, where the issue body names that variant exactly once and does
      not name the all-green variant, and (b) every leg green, where the
      script closes the issue rather than opening one.
- [ ] AC5: Reading every build step of the merged `docker.yml` finds `no-cache`
      set for `schedule` and `workflow_dispatch` events, and the AC1 run's
      build logs show the RStudio/Pandoc/Quarto install layer executed rather
      than reported `CACHED`.
- [ ] AC6: `hadolint Dockerfile` clean, `docker build` succeeds from a clean
      context, and `bash scripts/tests/test_ci_failure_issue.sh` and
      `bash scripts/tests/test_retry.sh` pass (PROFILE `verify`).

## Coverage

- AC1 → T1, T2
- AC2 → T1
- AC3 → T1
- AC4 → T3
- AC5 → T1, T2
- AC6 → T3, T4

## Tasks

- [x] T1: Restructure `docker.yml`'s build job into a (variant × platform)
      matrix — amd64 on `ubuntu-latest`, arm64 on GitHub's hosted arm64 runner
      label — each leg building its single platform with `load: true`,
      asserting the loaded image's architecture and the booted container's
      `uname -m` before running `.github/smoke-test.sh` natively (drop the
      900s arm64 timeout to the amd64 value); each leg builds once, pushes by
      digest (`outputs=type=image,push-by-digest=true,name-canonical=true`),
      pulls that digest back to boot it, and uploads the digest as an artifact
      after the smoke test passes. Delete the `setup-qemu-action` step
      and the emulation comments it anchors.
- [x] T2: Add the per-variant merge job: download that variant's digests,
      compute the tag list once (UTC date + `resolve-rstudio-version.sh
      --tag`), `docker buildx imagetools create` the manifest list carrying
      every tag, and inspect the result. Add a `workflow_dispatch` test-mode
      input that stops at `--dry-run` and prints the manifest and tag list
      instead of publishing. Keep `fail-fast: false` so a resolute failure
      never blocks noble (GP3 preview tier).
- [x] T3: Move the failed-leg → variant extraction out of the inline jq in
      `docker.yml` into `.github/ci-failure-issue.sh` (deduplicating variants
      across a variant's two legs), and extend
      `scripts/tests/test_ci_failure_issue.sh` with fixtures in the new
      matrix's job-name shape — M13's lesson: a matrix `include` leg with
      several keys is named `job (k1, k2, k3)`.
- [x] T4: Correct the prose that states the QEMU motivation as current —
      `scripts/install_quarto.sh:22-27`, `scripts/retry.sh:5-13`, and the
      `docker.yml` step comments — against what the merged workflow does;
      update `DESIGN.md` Conventions (the CI line) and Known issues; reword
      the `pr-ci.yml` arm64 candidate row to drop "emulated".

## Work log

- 2026-09-06: created by /milestone-plan.
- 2026-09-06: plan gate chose native arm64 runners over keeping emulation and skipping the crashing build-time quarto call, because the smoke test renders through the same runtime and would keep crashing; falsified by the hosted arm64 label being unavailable to this repo or its build proving slower than the emulated one.
- 2026-09-06: plan gate chose a dispatch test mode (digest-only push + `--dry-run` manifest) over evidencing the publish lane after merge, because approval would otherwise rest on an unexercised publish path; falsified by the test mode failing to reach the manifest step without a tag.
- 2026-09-06: implement gate chose `ubuntu-24.04-arm` (pinned) over a floating arm64 label, push-by-digest-then-pull-back over load-then-push (one build per leg; the tested bytes are the shipped bytes), and removing `docker/setup-qemu-action` outright (recorded as D-007).
- 2026-09-06: T1/T2 minor amendment: T1 wording now says the leg pushes by digest and pulls that digest back to boot it, replacing the `load: true` phrasing, per the gate's push-then-pull choice.
- 2026-09-06: T1+T2: `docker.yml` build job is now a 4-leg (variant x arch) matrix on native runners with one build step per leg, plus a per-variant `publish` job that assembles the manifest list from two verified digests and a `test_mode` dispatch input that stops at `imagetools create --dry-run`.
- 2026-09-06: T3: `ci-failure-issue.sh` now takes the `gh run view --json jobs` document and extracts the failed variants itself (deduplicated); `docker.yml`'s inline jq is gone. Suite extended with six job-listing fixtures and proven to go red under three planted defects (dedup removed, job-name guard removed, variant field untrimmed).
- 2026-09-06: T4: corrected the QEMU-as-current prose in `scripts/install_quarto.sh`, `scripts/retry.sh`, `scripts/tests/test_retry.sh`, `.github/smoke-test.sh`, the `docker.yml` comments, `DESIGN.md` Conventions (marked corrected M015) and the M05 LESSONS line (marked corrected M015, recompressed to keep the file at 49 lines); added a DESIGN Known issue for the hosted-arm64-runner dependency; reworded the pr-ci arm64 candidate row.
- 2026-09-06: T4 also repointed `pr-ci.yml`'s `cache-from` to the new per-arch scope `noble-amd64` and corrected its comment; the old `scope=noble` no longer exists after T1.
- 2026-09-06: verify: shellcheck 0.11.0 (-x -S info) clean over all tracked shell files; both shell suites pass; `hadolint` clean at 2.12.0, the version `hadolint/hadolint-action@v3.1.0` pins. Current hadolint (2.14) reports DL3025 on the Dockerfile's HEALTHCHECK — present identically on main, unrelated to this branch, filed as a [low] candidate row.
- 2026-09-06: [O] criteria audit, full mode: 4 findings on 6 criteria — AC3 could not distinguish arm64 from amd64 (fixed: architecture assertions), AC4 tested a mutated filter and allowed a duplicated variant (fixed: shipped extraction under fixtures, deduplicated), AC5 contradicted itself on a cached push run (fixed: scoped to the no-cache dispatch), AC1's evidence timing went to the gate (answered: dispatch test mode).

## Decisions
