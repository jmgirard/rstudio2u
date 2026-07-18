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
