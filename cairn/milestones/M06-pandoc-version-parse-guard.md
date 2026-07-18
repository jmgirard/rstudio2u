<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M06: Harden the Pandoc version parses

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** GP4
- **Branch/PR:** —

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

- [ ] `install_pandoc.sh` contains no `grep -oP` / `grep -P`; all three version
      parses go through `parse-pandoc-version.sh`.
- [ ] The helper extracts the correct version from realistic `pandoc --version`
      and `pandoc -v` output, and exits non-zero with a stderr diagnostic
      (nothing on stdout) on empty, HTML/garbage, and format-changed input —
      proven by `test_parse_pandoc_version.sh` running green offline.
- [ ] `test_parse_pandoc_version.sh` is wired into `pr-ci.yml`'s resolver
      unit-tests step so it gates PRs.
- [ ] `hadolint Dockerfile` clean and the noble image builds, with `pandoc`
      installed and `/opt/pandoc/templates` populated (the templates parse still
      yields a working download).

## Coverage

- AC1 → T2, T3
- AC2 → T1, T2
- AC3 → T1, T4
- AC4 → T5

## Tasks

- [ ] T1: Write `scripts/tests/test_parse_pandoc_version.sh` (tests-first) —
      assert_ok on realistic `pandoc --version` / `pandoc -v` bodies, assert_fail
      on empty, HTML/garbage, and format-changed bodies; stdin seam, offline.
- [ ] T2: Write `scripts/parse-pandoc-version.sh` to pass T1 — bash ERE extract
      off the `pandoc <ver>` line + shape validation, fail loud (non-zero +
      stderr, empty stdout).
- [ ] T3: Rewire `install_pandoc.sh` :29, :45, :81 to pipe `pandoc --version`
      through the helper; remove all `grep -oP`.
- [ ] T4: Add `test_parse_pandoc_version.sh` to the resolver-unit-tests `run:`
      block in `pr-ci.yml`.
- [ ] T5: Verify — run the unit test; `hadolint Dockerfile`; build the noble
      image and confirm `pandoc --version` and populated `/opt/pandoc/templates`.

## Work log

- 2026-07-18: created by /milestone-plan (promoted from the M04 version-parse
  carve-out candidate; continues the M03/M04 scrape-guard thread).

## Decisions

## Review
