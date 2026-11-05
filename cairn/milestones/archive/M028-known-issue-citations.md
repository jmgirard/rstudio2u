# M028: Replace numbered Known issue citations

**Status:** done (2026-11-05, PR #43 https://github.com/jmgirard/rstudio2u/pull/43)

**Goal:** Replace the code comments that cite "Known issue #1" and "#2" by position in DESIGN.md's unnumbered Known issues list with wording that stays correct when that list changes.

**Outcome:** Four comments lost their numbered citation: the apt-retries comment and the `mirror_hint.R` append comment in `Dockerfile`, the header of `scripts/mirror_hint.R` (which ships in the image's `/etc/R/Rprofile.site`), and the header of `scripts/resolve-rstudio-version.sh`, which now cites `(GP2)` alone. Each comment already named its problem in words (an unreliable or unreachable r2u mirror, or a format change in RStudio's update endpoint), so no principle id was added. No command changed. `git grep -niE 'known[ -]issues?:? ?(#|no\.? ?)?[0-9]' -- ':!cairn'` now prints nothing. Two unnumbered references stay: `docker.yml` "the version-scrape known issue" and `smoke-test.sh` "(a known issue)". No release (D-005): comment text only, and the merge's `docker.yml` run rebuilds the images.

**Decisions:** none. Plan gate: name each problem in words over numbering the Known issues list.

**Review:** Four-lens fan-out, 9 findings, all rejected: 1 style (a missing period), 4 planned (archive citations kept as history, the in-words reading, the shipped Rprofile comment, the ROADMAP row), 4 not defects (two unnumbered references that agree with the diff, two confirmations). Prior-review lens found no evidence. Claim audit: 12 claims, 0 corrected. PR #43 checks, shellcheck, and build-smoke noble and resolute passed. Graduated row: "Replace numbered Known issue citations". No lesson captured or marked.
