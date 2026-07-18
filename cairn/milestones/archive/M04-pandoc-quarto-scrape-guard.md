# M04: Guard the Pandoc/Quarto download-URL scrapes — done

- **Status:** done · **PR:** https://github.com/jmgirard/rstudio2u/pull/5
- **Merged:** 2026-07-18 · **Principles:** GP3, GP4

## Goal
Make a format-drifted Pandoc/Quarto download-URL scrape fail the build loudly
instead of feeding wget an empty or wrong-but-plausible URL — the M03 guard
applied to the two remaining scrape sites.

## Outcome
Added scripts/resolve-download-url.sh: a shared, offline-testable resolver that
fetches a release JSON endpoint, extracts the arch-matched .deb URL via bash ERE
(no grep -P), validates its shape, and exits non-zero on empty/HTML/format-drift/
wrong-arch responses. Wired into the three scrapes — install_pandoc.sh (latest)
and install_quarto.sh (release + prerelease); offline test (RESOLVE_DL_RESPONSE
seam) gates pr-ci.yml. Verified: 16/16 offline; live-fetch 3 endpoints ×
amd64/arm64 (pandoc 3.10, quarto 1.9.38/1.10.15); noble build exit 0; hadolint
clean; CI green; three-lens review zero findings.

## Notes
- Scope: only the download-URL scrapes (silent-wrong-URL risk on format drift);
  the grep -oP version-parses (install_pandoc.sh:29,45,81) already fail loud →
  candidate.
- Quarto now ships linux-arm64.deb; stale "Only amd64" comment (install_quarto.sh:18) → candidate.
