# Lessons

_Durable, append-only repo lessons (build quirks, testing tricks). Captured at
milestone end, surfaced at plan time. Capped at 50 lines (D-015)._

- 2026-07-17 (M01): buildx `no-cache: true` ignores `cache-from`, so a
  build-then-push pair that sets no-cache on both rebuilds independently — to
  publish exactly what you smoke-tested, build once into the gha cache and have
  the publish step reuse it (`cache-from` only, no `no-cache`).
- 2026-07-17 (M01): multi-arch buildx images can't be `--load`ed into the
  daemon; load a single-platform (native amd64) build from the shared cache to
  boot-test, and let the multi-arch push reuse the same cache.
- 2026-07-17 (M01): `.github/workflows/docker.yml` runs on push-to-main /
  schedule / dispatch, not on PRs — there is no pre-merge CI, so verify image
  build + smoke locally before merging.
- 2026-07-17 (M02): a GitHub Actions `pull_request` `paths` filter matches the
  whole-PR diff (base…head), not just the latest push — so once a PR's cumulative
  diff contains a watched path, every later push retriggers the workflow, even
  pushes touching only unwatched files (e.g. tracking-only commits).
- 2026-07-17 (M03): `grep -oP` (PCRE) isn't portable — BSD grep (macOS) rejects
  `-P`. For shell version-parsing, validate with bash's own `[[ =~ ]]` (ERE) +
  parameter-expansion field extraction; no `grep -P`, testable anywhere.
- 2026-07-17 (M03): unit-test a network-scraping shell script offline by giving
  it an env seam (`RS_UPDATE_RESPONSE`) that injects the raw response body in
  place of the fetch — fixtures drive every branch with no network.
- 2026-07-18 (M05): assert bspm's *binary* install path (not a source fallback)
  by checking `dpkg -s r-cran-<lowercased-pkg>` after install.packages() — r2u
  names binaries r-cran-<name>; a source compile would load but register no apt
  package.
- 2026-07-18 (M05): smoke-test the Quarto CLI on an image that ships no R
  packages (IP1) with a chunk-free .qmd — quarto's markdown engine renders via
  bundled Pandoc, no knitr/jupyter needed; add an R code chunk only if you first
  install knitr.
- 2026-07-18 (M05): boot-check an arm64-only image with a single-platform
  `load:true` build + `docker run` under QEMU binfmt (multi-arch images can't be
  --load'ed); a native-arm64 host verifies the real arch without emulation.
- 2026-07-18 (M06): offline-test a parser of a local command's `--version` by
  piping fixture text on stdin — no env seam needed (simpler than M03's
  RS_UPDATE_RESPONSE network seam, since there is no fetch to intercept).
