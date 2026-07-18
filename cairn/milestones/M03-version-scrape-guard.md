<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M03: Guard the RStudio version auto-detect

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** GP2
- **Branch/PR:** m03-version-scrape-guard

## Goal

Make a bad or format-changed RStudio version scrape fail the build loudly
instead of publishing a mis-named immutable tag.

## Scope

**In:**
- A shared, testable resolver (`scripts/resolve-rstudio-version.sh`) that
  fetches the current stable RStudio version, decodes it, validates it against
  the RStudio version shape (`YYYY.MM.P+BBB`), and exits non-zero with a clear
  stderr message on an empty/HTML/malformed scrape — printing nothing usable.
- `docker.yml`'s "Compute tags and RStudio version" step rewired to the
  resolver under `pipefail`, so an empty/garbage scrape aborts the job before
  any tag is built (kills the silent `jmgirard/rstudio2u:noble-` mis-tag path).
- `install_rstudio.sh`'s `stable`/`latest` resolution rewired to the same
  resolver, adding format validation to its existing empty-only check.
- The repo's first shell unit-test harness: fixtures driving the resolver,
  wired as a merge-gating step in `pr-ci.yml`.

**Out:**
- Guarding the Pandoc and Quarto version scrapes (same wart class, distinct
  endpoints — `install_pandoc.sh:68`, `install_quarto.sh:58`) → candidate row.
- Changing the tag-naming scheme or the mutable-tag set → not this milestone.

## Acceptance criteria

- [ ] The resolver exits non-zero with a clear stderr message and emits nothing
      usable to stdout on a bad scrape — empty output, an HTML/error body, or a
      value not matching the RStudio version shape. (fixture test)
- [ ] The resolver accepts a valid version string and prints the canonical
      version, preserving the tag rendering (`%2B`→`-`) `docker.yml` relies on
      and the URL rendering `install_rstudio.sh` relies on. (fixture test)
- [ ] `docker.yml`'s "Compute tags and RStudio version" step calls the resolver
      under `pipefail`; a bad scrape fails the job, so an empty/mis-named
      `<variant>-` immutable tag can never be published. (evidence: wired step
      + resolver non-zero exit)
- [ ] `install_rstudio.sh`'s `stable`/`latest` branch is wired to the shared
      resolver — a nonempty-but-malformed scrape aborts the build with a clear
      message instead of flowing into the download URL. (evidence: wired branch
      + fixture test)
- [ ] The resolver fixture test runs as a merge-gating step in `pr-ci.yml`.
- [ ] Profile `verify` slot clean: `hadolint Dockerfile` reports no violations
      and `docker build` succeeds (`cairn/PROFILE.md`).

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T1, T4

## Tasks

- [x] T1 — Write `scripts/resolve-rstudio-version.sh`: fetch the
      `check_for_update` endpoint (or accept an injected raw body via arg/env
      seam so it is testable offline), URL-decode, validate against the
      `^[0-9]{4}\.[0-9]{2}\.[0-9]+[+-][0-9]+$` shape, fail loud (non-zero +
      stderr) on empty/malformed, and print the canonical version on success
      (supporting both the `-` tag rendering and the `+` URL rendering).
- [x] T2 — Write `scripts/tests/test_resolve_rstudio_version.sh`: assert a good
      fixture yields exit 0 + the expected canonical output, and each bad
      fixture (empty, HTML error page, format-changed string) yields non-zero +
      a message and no usable stdout.
- [ ] T3 — Rewire `docker.yml`'s "Compute tags and RStudio version" step
      ([docker.yml:51-65](.github/workflows/docker.yml:51)) to call the resolver
      under `set -o pipefail`; feed its canonical output to both the immutable
      tag suffix and the `RSTUDIO_VERSION` build-arg.
- [ ] T4 — Rewire `install_rstudio.sh`'s `stable`/`latest` branch
      ([install_rstudio.sh:50-58](scripts/install_rstudio.sh:50)) to the shared
      resolver (script is already copied into the image at build time),
      replacing the inline scrape + empty-only check.
- [ ] T5 — Add a "Resolver unit test" step to `pr-ci.yml` that runs T2's script
      (its `scripts/**` path filter already triggers the lane); confirm a
      failing assertion fails the job.

## Work log

- 2026-07-17: created by /milestone-plan.
- 2026-07-17: T1+T2 — added pure-bash resolver (validates the RStudio version
  shape via bash ERE + parameter expansion, no `grep -P`/PCRE dependency) and
  its offline fixture test (7 assertions pass; live fetch resolves 2026.07.0+139).

## Decisions

## Review
