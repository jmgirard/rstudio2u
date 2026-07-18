# M06: Harden the Pandoc version parses — done

- **Status:** done · **PR:** https://github.com/jmgirard/rstudio2u/pull/7
- **Merged:** 2026-07-18 · **Principles:** GP4

## Goal
Replace the three non-portable grep -oP (PCRE) Pandoc version parses in
install_pandoc.sh with a pure-bash, offline-testable helper that fails loud on
format change — the last grep -P scrape wart, carved out of M04.

## Outcome
Added scripts/parse-pandoc-version.sh: reads pandoc --version / -v text on
stdin, extracts the version off the `pandoc <ver>` line via bash ERE (no PCRE),
validates a 2+-component shape, exits non-zero + stderr on empty/format-changed
input. All three install_pandoc.sh sites (installed :29, bundled :45,
templates-download :81) route through it; no grep -P remains. Offline unit test
(test_parse_pandoc_version.sh, 9 assertions) gated in pr-ci.yml. Verified: test
9/9; hadolint clean; noble amd64 build ships pandoc 3.8.3 + 64 populated
/opt/pandoc/templates. 3-lens review: 0 findings.

## Notes
- Local-command version parse: stdin is the test seam (no network env seam
  needed, unlike M03's RS_UPDATE_RESPONSE).
- Continues the M03/M04 scrape-guard lineage (GP4 owned-fork hardening).
