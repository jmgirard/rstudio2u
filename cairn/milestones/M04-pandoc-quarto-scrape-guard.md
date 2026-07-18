<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M04: Guard the Pandoc/Quarto download-URL scrapes

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** GP4, GP3   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Branch/PR:** m04-pandoc-quarto-scrape-guard   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

Make a format-drifted Pandoc/Quarto download-URL scrape fail the build loudly
with a clear message instead of feeding an empty or wrong-but-plausible URL to
`wget` — the M03 guard, applied to the two remaining scrape sites.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** A shared, offline-testable resolver (`scripts/resolve-download-url.sh`,
the M03 pattern) that fetches a release endpoint, extracts the arch-matched
`.deb` URL with bash ERE (no `grep -P`/PCRE), validates it against the expected
URL shape, and exits non-zero with a stderr message on an empty / HTML-error /
format-changed / wrong-arch response. Wired into the three download-URL scrape
sites — `install_pandoc.sh:68` (GitHub-API `latest`), `install_quarto.sh:58`
(`_download.json` release), `install_quarto.sh:60` (`_prerelease.json`) — and
gated by an offline unit test in `pr-ci.yml`.

**Out:**
- The `pandoc -v` template-version scrape (`install_pandoc.sh:78`) and the
  other `grep -oP` version parses (`install_pandoc.sh:29,45`) → candidate row
  (they already fail loud: an empty version yields a 404 that aborts under
  `set -e`; only the download-URL scrapes can silently install a wrong artifact
  on a partial format-drift match).
- Any change to the default (bundled-symlink) install path, which never reaches
  these scrapes → untouched by design.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets -->

- [ ] **AC1 — resolves valid responses.** Given a valid endpoint body in either
      shape — GitHub-API `browser_download_url` and Quarto `download_url` — the
      resolver prints the correct arch-matched `.deb` URL and exits 0, selecting
      the requested arch when a body contains both `amd64` and `arm64` assets
      (verified for both arches). Evidence: offline unit test passes.
- [ ] **AC2 — fails loud on bad responses.** Given an empty, HTML/error,
      format-changed (key renamed or no matching `.deb`), or wrong-arch-only
      body, the resolver exits non-zero with a message on stderr and nothing on
      stdout. Evidence: offline unit test passes.
- [ ] **AC3 — all three sites use the resolver.** `install_pandoc.sh:68`,
      `install_quarto.sh:58`, and `install_quarto.sh:60` obtain their download
      URL through the shared resolver; no `grep -oP` remains at those three
      sites. Evidence: file inspection + `docker build` succeeds.
- [ ] **AC4 — gated and green.** The offline resolver test runs as a step in
      `.github/workflows/pr-ci.yml`; `hadolint Dockerfile` is clean and the
      default noble `docker build` succeeds; and the resolver, run live against
      each of the three endpoints at review time, returns a well-formed
      arch-matched URL. Evidence: CI step present, build + hadolint output, live
      fetch transcript.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T1, T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate -->

- [ ] **T1 — Offline test suite first.** Author
      `scripts/tests/test_resolve_download_url.sh`, fixing the resolver
      interface (args: endpoint URL, JSON key, arch; `RESOLVE_DL_RESPONSE`
      injection seam à la M03's `RS_UPDATE_RESPONSE`). Cases: valid GitHub-API
      body → amd64 URL; valid Quarto `_download.json`/`_prerelease.json` body →
      URL; both-arch body selects the requested arch (amd64 and arm64); empty,
      HTML/error, renamed-key, no-`.deb`, and wrong-arch-only bodies each fail
      loud (non-zero, empty stdout).
- [ ] **T2 — Implement the resolver.** Write `scripts/resolve-download-url.sh`
      (pure bash, `set -euo pipefail`, `RESOLVE_DL_RESPONSE` seam, bash-ERE
      extraction of `"<key>": "https…<arch>.deb"`, `^https://…<arch>\.deb$`
      shape re-validation, stderr message + non-zero exit on any miss) until the
      suite is green. No `grep -P`/PCRE anywhere in it.
- [ ] **T3 — Wire the three scrape sites.** Replace the inline scrapes at
      `install_pandoc.sh:68` (GitHub-API `latest`), `install_quarto.sh:58`
      (`_download.json` release/latest), and `install_quarto.sh:60`
      (`_prerelease.json`) with calls to the shared resolver; leave the default
      bundled-symlink path untouched.
- [ ] **T4 — Gate + verify.** Add the resolver test as a step in
      `.github/workflows/pr-ci.yml` (alongside the RStudio resolver unit test);
      confirm `hadolint Dockerfile` clean and default noble `docker build`
      succeeds; run the resolver live against all three endpoints and capture
      the returned URLs as evidence.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates -->

- 2026-07-17: created by /milestone-plan (promoted from ROADMAP candidate;
  extends the M03 scrape-guard pattern to Pandoc/Quarto).

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md -->

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55):
     only the plan-owned body above counts; evidence never scrambles it. -->
