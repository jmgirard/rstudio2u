<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M05: Deepen the smoke test

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** IP1, GP3, GP7   <!-- owner: plan · create/amend-via-gate -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

Make the CI smoke test actually exercise the toolchain — a bspm binary install
and a Quarto render — and run it on arm64 under emulation before publishing, so
arm64 parity drift is caught instead of shipping silently (Known issue #3).

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:**
- Deepen `.github/smoke-test.sh` beyond the `:8787` server-up probe: after the
  server is healthy, `docker exec` a bspm binary-package install (IP1's fast
  runtime binary path) and a `quarto render` of a minimal `.qmd` to HTML
  (the Pandoc+Quarto path, where the arm64 bundled/symlinked fallback lives).
- Add a single-platform arm64 (`linux/arm64`, `load: true`) build + emulated
  boot to `docker.yml`, running the deepened checks before the publish step, so
  the arm64 image's toolchain is verified pre-ship (closes Known issue #3).
- Run the deepened checks on the existing amd64 boot in both `docker.yml`
  (publish) and `pr-ci.yml` (pre-merge).
- Add `.github/smoke-test.sh` to the `paths:` filters of `pr-ci.yml` and
  `docker.yml` so a change to the harness retriggers the gate (absorbs the
  candidate #8 row from the M02 review).

**Out:**
- Emulated arm64 smoke in the **pre-merge** `pr-ci.yml` lane → deferred for
  PR-CI speed; filed as a candidate row ("pre-merge arm64 emulated smoke").
- PDF/LaTeX render coverage → not this milestone (HTML render only, to avoid
  pulling a LaTeX toolchain into the check).
- Refreshing `install_quarto.sh` to use Quarto's native arm64 `.deb` → stays
  the separate ROADMAP candidate (that is remediation of the fallback; this
  milestone is detection).

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets -->

- [ ] AC1: `smoke-test.sh`, against a healthy container, installs an R package
      with a compiled dependency via bspm and confirms it loads; the install or
      load failing exits the script non-zero. Evidence: a run log showing the
      install + successful `library()` load, and a forced-failure run that exits
      non-zero.
- [ ] AC2: `smoke-test.sh` renders a minimal `.qmd` to HTML via `quarto render`
      inside the container and asserts the output `.html` exists; render failure
      exits non-zero. Evidence: a run log showing the produced HTML, and a
      forced-failure run that exits non-zero.
- [ ] AC3: The existing server-up check is preserved — the deepened script still
      requires RStudio Server to answer on `:8787` before the functional phase,
      and a container that never becomes healthy still fails. Evidence: a run
      against a non-starting container exits non-zero before the functional phase.
- [ ] AC4: `docker.yml` boots a single-platform arm64 image under QEMU and runs
      the deepened bspm-install + quarto-render checks before the publish step;
      a failure blocks that variant's publish (fail-fast:false keeps variants
      independent). Evidence: a green `docker.yml` run (or equivalent local
      emulated run) showing the arm64 functional checks passing pre-publish.
- [ ] AC5: `pr-ci.yml` runs the deepened checks on the amd64 pre-merge build.
      Evidence: a green PR-CI run log showing the bspm-install + quarto-render
      checks.
- [ ] AC6: The `paths:` filters in both `pr-ci.yml` and `docker.yml` include
      `.github/smoke-test.sh`. Evidence: the diff of both filter blocks.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T5
- AC2 → T1, T5
- AC3 → T1, T5
- AC4 → T4, T3, T1, T5
- AC5 → T2, T1, T5
- AC6 → T2, T3

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [ ] T1: Deepen `.github/smoke-test.sh` — after the existing server-up/health
      check passes, add a functional phase that `docker exec`s into the
      container to (a) install a compiled-dependency R package via bspm and
      confirm it loads, and (b) `quarto render` a minimal inline `.qmd` (created
      in-container, no repo fixture) to HTML and assert the output file exists;
      either failure exits non-zero. Preserve the cleanup trap and failure
      log-dump.
- [ ] T2: `.github/workflows/pr-ci.yml` — ensure the amd64 pre-merge smoke step
      runs the deepened script (raise `SMOKE_TIMEOUT` for install+render), and
      add `.github/smoke-test.sh` to its `paths:` filter.
- [ ] T3: `.github/workflows/docker.yml` — the amd64 smoke step already calls
      the script (now deepened); add `.github/smoke-test.sh` to its `paths:`
      filter and raise `SMOKE_TIMEOUT` if needed.
- [ ] T4: `.github/workflows/docker.yml` — add a single-platform `linux/arm64`
      `load: true` build (reusing the variant cache scope) and a smoke step that
      boots it under QEMU and runs the deepened checks, placed before the publish
      step, with a generous emulation `SMOKE_TIMEOUT`.
- [ ] T5: End-to-end verification — build the noble amd64 image locally and run
      the deepened smoke green; validate the arm64 emulated path (local QEMU run
      or a CI run); confirm this CI-internal change needs no `CHANGELOG.md`
      entry (no user-visible behavior change); record evidence lines.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates -->

- 2026-07-17: created by /milestone-plan. Promotes ROADMAP candidate "deepen
  smoke test" (GP3/GP7, Known issue #3); absorbs candidate #8 (pr-ci watches
  smoke-test.sh). Gate: arm64 on publish path only; bspm install + HTML render.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive; EXEMPT from the 150-line cap (M55). -->
