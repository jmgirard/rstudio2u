# Lessons

_Durable, append-only repo lessons (build quirks, testing tricks). Captured at
milestone end, surfaced at plan time. Capped at 50 lines (D-015)._

- 2026-07-17 (M01): buildx `no-cache: true` ignores `cache-from`, so a
  build-then-push pair that sets no-cache on both rebuilds independently — to
  publish exactly what you smoke-tested, build once into the gha cache and have
  the publish step reuse it (`cache-from` only, no `no-cache`).
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
- 2026-07-18 (M07): simulate an r2u mirror outage in the container smoke by
  blackholing the non-Ubuntu apt hosts (`/etc/hosts` → 127.0.0.1, refused fast)
  and pointing `options(repos=)` at a dead port to kill bspm's source fallback;
  apt's `Acquire::Retries` shows as repeated `Ign:/Err:` lines during the
  `apt-get update` bspm runs first, so retry count is assertable there.
- 2026-07-18 (M07): to add a friendly hint on install failure, key on
  post-install state (is the package still missing?) + a scoped reachability
  probe, not apt-error text — and scope the probe to the R package mirrors
  (drop `*.ubuntu.com/.org`), or an unrelated Ubuntu-archive blip false-fires.
- 2026-07-18 (M08): to ship CRLF on every download channel use `*.bat -text` +
  committed CRLF bytes — `eol=crlf` only smudges on `git clone`, while
  `git archive` (GitHub "Download ZIP") exports blobs verbatim; guard the blob
  with `git cat-file -p :file`.
- 2026-07-18 (M08): to run a Windows `.bat` in CI, stub `docker` as a real `.exe`
  (bare `docker`→`.cmd` chains via goto, never returns), set PATH inside a
  wrapper `.cmd`, fake "not installed" with a tool-only dir (real docker.exe is on the runner's System32).
