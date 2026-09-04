# Lessons

_Durable, append-only repo lessons (build quirks, testing tricks). Captured at
milestone end, surfaced at plan time. Capped at 50 lines (D-015)._

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
- 2026-07-18 (M07): simulate an r2u mirror outage in the container smoke by
  blackholing non-Ubuntu apt hosts (`/etc/hosts` → 127.0.0.1) and pointing
  `options(repos=)` at a dead port to kill bspm's source fallback; apt's
  `Acquire::Retries` shows as repeated `Ign:/Err:` lines in bspm's `apt-get update`.
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
- 2026-07-18 (M09): a stub resolving the same config as the code under test gives
  false coverage; force the code's own parse to reach the output, then mutate to
  confirm. A stub answering a looped query must be argument-sensitive, multi-item (M10).
- 2026-07-18 (M09): PowerShell variable names are case-insensitive — a `$DotEnv`
  parameter silently shadows a script-scope `$dotenv`.
- 2026-07-18 (M09): batch `for /f "tokens=* delims= "` is trim-LEFT only; trim
  both ends with a `:~0,1` / `:~-1` loop.
- 2026-07-18 (M09): ask `docker compose port <svc> <port>` for the real host
  binding instead of re-deriving it from RS_PORT/.env — authoritative across
  every override mechanism.
- 2026-09-03 (M11): a shellcheck severity floor can pass the defect it is meant to
  catch (SC2086 is info, not warning) — plant it and see red before trusting `-S`.
- 2026-09-03 (M12): `gh secret list` prints each secret's update time — verify a rotation with it.
- 2026-09-04 (M13): cancelling a workflow run cancels its downstream jobs before their `if:` runs, so a cancelled run shows `cancelled`, never `skipped` — a skip needs a run that completes.
- 2026-09-04 (M13): a matrix `include` leg with several keys is named `job (k1, k2, k3)`; set `name: job (${{ matrix.variant }})` when a script parses job names.
