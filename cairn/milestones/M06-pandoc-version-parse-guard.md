<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M06: Harden the Pandoc version parses

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** GP4
- **Branch/PR:** m06-pandoc-version-parse-guard

## Goal

Replace the three non-portable `grep -oP` Pandoc version parses in
`install_pandoc.sh` (installed compare :29, bundled compare :45, and the
templates-download parse :81) with a pure-bash, offline-testable helper that
fails loud with a clear diagnostic on empty/format-changed `pandoc --version`
output — closing the last `grep -P` scrape wart carved out of M04 (GP4).

## Scope

**In:**
- A pure-bash helper `scripts/parse-pandoc-version.sh` that reads raw
  `pandoc --version` / `pandoc -v` text on stdin, extracts the version off the
  `pandoc <ver>` line via bash ERE + parameter expansion (no PCRE / `grep -P`),
  validates it against the pandoc version shape, and on empty/garbage/
  format-changed input exits non-zero with a stderr message and nothing on
  stdout (the M03/M04 resolver contract).
- Rewire all three `install_pandoc.sh` sites (:29, :45, :81) through the helper;
  no `grep -oP` (or any `grep -P`) remains in the file.
- Offline unit test `scripts/tests/test_parse_pandoc_version.sh` driving valid,
  empty, HTML/garbage, and format-changed inputs via stdin.
- Wire the new test into `pr-ci.yml`'s existing resolver-unit-tests step.

**Out:**
- The Pandoc/Quarto *download-URL* scrapes — already guarded by
  `resolve-download-url.sh` (M04).
- The RStudio version scrape — `resolve-rstudio-version.sh` (M03).
- Quarto's `--version` handling — it compares raw strings, no `grep -P`; nothing
  to harden.

## Acceptance criteria

- [x] `install_pandoc.sh` contains no `grep -oP` / `grep -P`; all three version
      parses go through `parse-pandoc-version.sh`.
- [x] The helper extracts the correct version from realistic `pandoc --version`
      and `pandoc -v` output, and exits non-zero with a stderr diagnostic
      (nothing on stdout) on empty, HTML/garbage, and format-changed input —
      proven by `test_parse_pandoc_version.sh` running green offline.
- [x] `test_parse_pandoc_version.sh` is wired into `pr-ci.yml`'s resolver
      unit-tests step so it gates PRs.
- [x] `hadolint Dockerfile` clean and the noble image builds, with `pandoc`
      installed and `/opt/pandoc/templates` populated (the templates parse still
      yields a working download).

## Coverage

- AC1 → T2, T3
- AC2 → T1, T2
- AC3 → T1, T4
- AC4 → T5

## Tasks

- [x] T1: Write `scripts/tests/test_parse_pandoc_version.sh` (tests-first) —
      assert_ok on realistic `pandoc --version` / `pandoc -v` bodies, assert_fail
      on empty, HTML/garbage, and format-changed bodies; stdin seam, offline.
- [x] T2: Write `scripts/parse-pandoc-version.sh` to pass T1 — bash ERE extract
      off the `pandoc <ver>` line + shape validation, fail loud (non-zero +
      stderr, empty stdout).
- [x] T3: Rewire `install_pandoc.sh` :29, :45, :81 to pipe `pandoc --version`
      through the helper; remove all `grep -oP`.
- [x] T4: Add `test_parse_pandoc_version.sh` to the resolver-unit-tests `run:`
      block in `pr-ci.yml`.
- [x] T5: Verify — run the unit test; `hadolint Dockerfile`; build the noble
      image and confirm `pandoc --version` and populated `/opt/pandoc/templates`.

## Work log

- 2026-07-18: created by /milestone-plan (promoted from the M04 version-parse
  carve-out candidate; continues the M03/M04 scrape-guard thread).
- 2026-07-18: set in-progress; branch m06-pandoc-version-parse-guard.
- 2026-07-18: T1+T2 — parse-pandoc-version.sh (pure-bash stdin parser, no
  grep -P) + offline unit test; 9/9 green.
- 2026-07-18: T3 — install_pandoc.sh :29/:45/:81 rewired through the helper;
  no grep -P remains; bash -n clean.
- 2026-07-18: T4 — test_parse_pandoc_version.sh wired into pr-ci.yml resolver
  unit-tests step (gates PRs).
- 2026-07-18: T5 — verify: unit test 9/9; hadolint clean; noble amd64 build
  succeeds; image ships pandoc 3.8.3 + 64 populated /opt/pandoc/templates (the
  :81 templates parse ran on the real build path). Status → review.

## Decisions

## Review

_Reviewed 2026-07-18 on branch m06-pandoc-version-parse-guard._

**Acceptance criteria (fresh evidence):**
- AC1 — `grep -nE 'grep -o?P' scripts/install_pandoc.sh` → no match; the three
  parses (:29/:45/:81) all call `/rocker_scripts/parse-pandoc-version.sh`. PASS.
- AC2 — `bash scripts/tests/test_parse_pandoc_version.sh` → 9/9 (valid
  --version/-v + four-component + version-not-first resolve; empty, HTML,
  extra-word, non-numeric, trailing-junk, single-component fail loud). PASS.
- AC3 — `test_parse_pandoc_version.sh` present in pr-ci.yml resolver
  unit-tests step (line 31). PASS.
- AC4 — noble amd64 build succeeds; `docker run` shows `pandoc 3.8.3` and 64
  files in `/opt/pandoc/templates` (the :81 templates parse ran on the real
  build path). PASS.

**Consistency gate:** `cairn_validate` all-pass (exit 0). No principle change
(works under GP4) → `cairn_impact` skipped. Toolchain (docker-image): hadolint
clean, `docker build` succeeds, base pinned `rocker/r2u:24.04`. PASS.

