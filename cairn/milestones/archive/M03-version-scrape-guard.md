# M03: Guard the RStudio version auto-detect — done

- **Status:** done · **PR:** https://github.com/jmgirard/rstudio2u/pull/4
- **Merged:** 2026-07-18 · **Principles:** GP2

## Goal
Make a bad/format-changed RStudio version scrape fail the build loudly instead
of publishing a mis-named immutable tag (Known issue #2).

## Outcome
Added `scripts/resolve-rstudio-version.sh`: a pure-bash resolver that fetches
the current stable RStudio version, validates it against the version shape
(`YYYY.MM.P+BBB`) via bash ERE + parameter expansion (no `grep -P`/PCRE), and
exits non-zero on an empty/HTML/format-changed scrape. Wired into `docker.yml`'s
meta step (under `pipefail` — a bad scrape aborts before any `<variant>-` tag is
built) and `install_rstudio.sh`'s stable/latest branch (format check added to
its empty-only check). First shell unit test (`scripts/tests/`) drives it
offline via an `RS_UPDATE_RESPONSE` seam and gates `pr-ci.yml`. Verified: test
7/7; live fetch 2026.07.0+139; hadolint clean; noble build succeeds; three-lens
review zero findings.

## Notes
- Pure-bash validation (dropped `grep -P`) — portable + offline-testable.
- Pandoc/Quarto scrapes (same wart) deferred → ROADMAP candidate.
- DESIGN Known issue #2 updated: mitigated (fails loud); scrape format
  dependence remains.
