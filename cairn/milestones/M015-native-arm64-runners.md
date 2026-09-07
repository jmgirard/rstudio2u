# M015: Native arm64 runners for the image build

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP3, GP7
- **Resolves:** —
- **Surface tier:** user-facing — the deliverable is the lane that publishes the moving tags users pull
- **Branch/PR:** m015-native-arm64-runners — https://github.com/jmgirard/rstudio2u/pull/22

## Goal

Build and smoke-test each architecture on a runner of that architecture, so
Quarto's bundled Deno never runs under QEMU and the noble moving tags refresh
on schedule.

## Scope

**In:** `docker.yml` restructured to build and boot each variant/arch pair on a
native runner (`ubuntu-latest` for amd64, GitHub's hosted arm64 label for
arm64), push each arch by digest, and assemble the manifest list with the full
tag list in a per-variant merge job; a dispatch test mode that exercises that
lane without attaching a tag; `docker/setup-qemu-action` dropped; the
scheduled-failure alert kept working against the new job names; the QEMU
motivation corrected wherever the repo's prose states it; `DESIGN.md`
Conventions and Known issues updated. This absorbs the candidate row asking
for the arm64 smoke `quarto render` to be hardened against the same crash —
removing emulation removes it from the render too.

**Out:** an arm64 leg in `pr-ci.yml` → the existing candidate row, rewritten by
T4 now that it needs no emulation. Removing `scripts/retry.sh` or its wrapping
of the quarto calls → stays; it still rides out genuine transients. Image-size
budget, resolute graduation, weekly-rebuild keepalive → their own candidate
rows.

## Acceptance criteria

- [ ] AC1: A test-mode `workflow_dispatch` run of the branch's `docker.yml` —
      layers pushed by digest, no tag attached — prints from
      `docker buildx imagetools create --dry-run` a noble manifest list naming
      both `linux/amd64` and `linux/arm64`, and prints the tag list it would
      apply, containing `latest`, `noble`, `noble-<UTC date>` and
      `noble-<rstudio version>` (GP2's escape hatch).
- [ ] AC2: Reading every step of the merged `.github/workflows/docker.yml` top
      to bottom finds no `docker/setup-qemu-action` step, and finds each build
      step's `platforms:` value equal to the single native architecture of the
      runner its job declares.
- [ ] AC3: In the AC1 run, the arm64 leg boots an image whose
      `docker image inspect --format '{{.Architecture}}'` is `arm64` and whose
      container answers `aarch64` to `uname -m`, and `.github/smoke-test.sh`
      against that image logs `PASS: quarto rendered .qmd to HTML`.
- [ ] AC4: `scripts/tests/test_ci_failure_issue.sh` exercises the shipped
      failed-variant extraction — the merged `docker.yml` invokes it and keeps
      no second inline copy — over fixtures shaped like the new matrix's
      `gh run view --json jobs` output, covering (a) one variant's arm64 leg
      failing, where the issue body names that variant exactly once and does
      not name the all-green variant, and (b) every leg green, where the
      script closes the issue rather than opening one.
- [ ] AC5: Reading every build step of the merged `docker.yml` finds `no-cache`
      set for `schedule` and `workflow_dispatch` events, and the AC1 run's
      build logs show the RStudio/Pandoc/Quarto install layer executed rather
      than reported `CACHED`.
- [ ] AC6: `hadolint Dockerfile` clean, `docker build` succeeds from a clean
      context, and `bash scripts/tests/test_ci_failure_issue.sh` and
      `bash scripts/tests/test_retry.sh` pass (PROFILE `verify`).

## Coverage

- AC1 → T1, T2
- AC2 → T1
- AC3 → T1
- AC4 → T3
- AC5 → T1, T2
- AC6 → T3, T4

## Tasks

- [x] T1: Restructure `docker.yml`'s build job into a (variant × platform)
      matrix — amd64 on `ubuntu-latest`, arm64 on GitHub's hosted arm64 runner
      label — each leg building its single platform with `load: true`,
      asserting the loaded image's architecture and the booted container's
      `uname -m` before running `.github/smoke-test.sh` natively (drop the
      900s arm64 timeout to the amd64 value); each leg builds once, pushes by
      digest (`outputs=type=image,push-by-digest=true,name-canonical=true`),
      pulls that digest back to boot it, and uploads the digest as an artifact
      after the smoke test passes. Delete the `setup-qemu-action` step
      and the emulation comments it anchors.
- [x] T2: Add the per-variant merge job: download that variant's digests,
      compute the tag list once (UTC date + `resolve-rstudio-version.sh
      --tag`), `docker buildx imagetools create` the manifest list carrying
      every tag, and inspect the result. Add a `workflow_dispatch` test-mode
      input that stops at `--dry-run` and prints the manifest and tag list
      instead of publishing. Keep `fail-fast: false` so a resolute failure
      never blocks noble (GP3 preview tier).
- [x] T3: Move the failed-leg → variant extraction out of the inline jq in
      `docker.yml` into `.github/ci-failure-issue.sh` (deduplicating variants
      across a variant's two legs), and extend
      `scripts/tests/test_ci_failure_issue.sh` with fixtures in the new
      matrix's job-name shape — M13's lesson: a matrix `include` leg with
      several keys is named `job (k1, k2, k3)`.
- [x] T4: Correct the prose that states the QEMU motivation as current —
      `scripts/install_quarto.sh:22-27`, `scripts/retry.sh:5-13`, and the
      `docker.yml` step comments — against what the merged workflow does;
      update `DESIGN.md` Conventions (the CI line) and Known issues; reword
      the `pr-ci.yml` arm64 candidate row to drop "emulated".

- [x] T5: Resolve the RStudio version and the UTC date once per run and carry
      both forward, so the `RSTUDIO_VERSION` build-arg and the `<variant>-<ver>`
      / `<variant>-<date>` tags can never disagree (a pre-build job whose
      outputs `build` and `publish` both consume, or the value emitted into the
      digest artifact). This also removes the network scrape from the publish
      job, where a transient failure discards four completed builds. In the same
      job, assert the assembled manifest list names both `linux/amd64` and
      `linux/arm64` rather than only counting two digest artifacts.
- [x] T6: Make the ci-failure fixtures discriminate: add a fixture with every
      build leg green and one `publish (<variant>)` leg failed (today, dropping
      `publish` from the extraction leaves the suite green), make the all-green
      fixture load-bearing rather than inert, and emit a warning when a non-empty
      jobs document parses to zero variants instead of silently falling back to
      the generic text.
- [x] T7: Fix `notify`'s result aggregation so anything that is not
      build-success *and* publish-success is treated as not-success — today
      publish `cancelled`/`skipped` falls through to `success` and closes the
      ci-failure issue on a run that published nothing. Quote or glob-guard the
      inline `$TAGS` loops in the publish job and reconcile `for f in *` with
      the `find . -type f` count above it.

## Work log

- 2026-09-06: created by /milestone-plan.
- 2026-09-06: plan gate chose native arm64 runners over keeping emulation and skipping the crashing build-time quarto call, because the smoke test renders through the same runtime and would keep crashing; falsified by the hosted arm64 label being unavailable to this repo or its build proving slower than the emulated one.
- 2026-09-06: plan gate chose a dispatch test mode (digest-only push + `--dry-run` manifest) over evidencing the publish lane after merge, because approval would otherwise rest on an unexercised publish path; falsified by the test mode failing to reach the manifest step without a tag.
- 2026-09-06: implement gate chose `ubuntu-24.04-arm` (pinned) over a floating arm64 label, push-by-digest-then-pull-back over load-then-push (one build per leg; the tested bytes are the shipped bytes), and removing `docker/setup-qemu-action` outright (recorded as D-007).
- 2026-09-06: T1/T2 minor amendment: T1 wording now says the leg pushes by digest and pulls that digest back to boot it, replacing the `load: true` phrasing, per the gate's push-then-pull choice.
- 2026-09-06: T1+T2: `docker.yml` build job is now a 4-leg (variant x arch) matrix on native runners with one build step per leg, plus a per-variant `publish` job that assembles the manifest list from two verified digests and a `test_mode` dispatch input that stops at `imagetools create --dry-run`.
- 2026-09-06: T3: `ci-failure-issue.sh` now takes the `gh run view --json jobs` document and extracts the failed variants itself (deduplicated); `docker.yml`'s inline jq is gone. Suite extended with six job-listing fixtures and proven to go red under three planted defects (dedup removed, job-name guard removed, variant field untrimmed).
- 2026-09-06: T4: corrected the QEMU-as-current prose in `scripts/install_quarto.sh`, `scripts/retry.sh`, `scripts/tests/test_retry.sh`, `.github/smoke-test.sh`, the `docker.yml` comments, `DESIGN.md` Conventions (marked corrected M015) and the M05 LESSONS line (marked corrected M015, recompressed to keep the file at 49 lines); added a DESIGN Known issue for the hosted-arm64-runner dependency; reworded the pr-ci arm64 candidate row.
- 2026-09-06: T4 also repointed `pr-ci.yml`'s `cache-from` to the new per-arch scope `noble-amd64` and corrected its comment; the old `scope=noble` no longer exists after T1.
- 2026-09-06: verify: shellcheck 0.11.0 (-x -S info) clean over all tracked shell files; both shell suites pass; `hadolint` clean at 2.12.0, the version `hadolint/hadolint-action@v3.1.0` pins. Current hadolint (2.14) reports DL3025 on the Dockerfile's HEALTHCHECK — present identically on main, unrelated to this branch, filed as a [low] candidate row.
- 2026-09-06: verify (T4, build-context change): `docker build` succeeds from a clean context on this arm64 host (exit 0, 849 MB); the built image reports `uname -m` = aarch64 and runs quarto 1.9.38, and the build log carries zero `retry:` diagnostics — the Deno-invoking quarto calls needed no retry when nothing is emulated.
- 2026-09-06: pushed the branch and dispatched the test-mode run for AC1/AC3/AC5 evidence: https://github.com/jmgirard/rstudio2u/actions/runs/34075352828 . All four build legs picked up runners and are in progress, so `ubuntu-24.04-arm` resolves for this repo — the plan's stated falsifier for the native-runner choice does not fire. No watcher left armed; review re-derives the run state.
- 2026-09-06: [O] criteria audit, full mode: 4 findings on 6 criteria — AC3 could not distinguish arm64 from amd64 (fixed: architecture assertions), AC4 tested a mutated filter and allowed a duplicated variant (fixed: shipped extraction under fixtures, deduplicated), AC5 contradicted itself on a cached push run (fixed: scoped to the no-cache dispatch), AC1's evidence timing went to the gate (answered: dispatch test mode).
- 2026-09-06: review: PR #22 opened draft; all six criteria verified with fresh evidence from test-mode run 34075735235 (all green); consistency gate passes; three-lens review returned 13 findings, dispositions pending at the gate.
- 2026-09-06: review send-back (defect return 1): F1 — the publish job re-scrapes the RStudio version and UTC date independently of the build legs, so an immutable `<variant>-<version>` or `-<date>` tag can name an image not built from it; the default branch resolved both once. Filed as T5–T7 with F2/F3/F5/F6/F8/F9; status back to `in-progress`. The six criteria all passed this pass (evidence in the Review section) but are unticked, since T5–T7 change the artifacts that evidence was taken from.
- 2026-09-06: implement gate (T5-T7) chose a pre-build `meta` job over carrying the version with each digest, closing the ci-failure issue only when build and publish both succeeded, moving that aggregation into `ci-failure-issue.sh` where the suite covers it, and making the all-green fixture load-bearing by driving it through the failure path.
- 2026-09-06: T5: `docker.yml` gains a `meta` job resolving the RStudio version and the UTC date once per run; the four build legs take `RSTUDIO_VERSION` from it and both publish legs build the `<variant>-<version>` / `<variant>-<date>` tags from the same two outputs, so the publish job no longer reaches the network. The publish step now parses the index it created (`--dry-run` output in test mode, `imagetools inspect --raw` otherwise) and fails unless the linux platforms are exactly amd64 and arm64; proven able to fail against a planted two-manifest single-arch index, and unmoved by an `unknown/unknown` attestation entry.
- 2026-09-06: T6: added a publish-only-failure fixture (every build leg green, `publish (noble)` failed), so the `publish` half of the extraction filter is now the sole source of a variant name; drove the all-green fixture through the failure path, where the script must fall back to generic text and warn that the listing named no failed leg; and surfaced jq's own diagnostics instead of discarding them. Proven able to fail under five planted defects: filter narrowed to build legs, contradiction warning removed, jq diagnostics back to /dev/null, all-green fixture swapped for a failing one, dedup removed.
- 2026-09-06: T7: the open/close/ignore rule moved out of `notify`'s inline shell into `ci-failure-issue.sh`, whose first argument is now the space-separated list of the needed jobs' results (`meta build publish`); the issue closes only on a unanimous success, a cancelled member is ignored, and a failure outranks a cancellation. Seven aggregation cases added; proven able to fail under three planted defects (unknown result counted as success, cancelled no longer blocking success, failure no longer outranking cancellation). The `$TAGS` quoting and the `for f in *` / `find` reconciliation landed with T5, in the same publish step.

## Decisions

## Review

Evidence run: test-mode `workflow_dispatch` of the branch's `docker.yml`,
https://github.com/jmgirard/rstudio2u/actions/runs/34075735235 (2026-09-07, all
seven jobs green; `notify` skipped, as it is schedule-only). An earlier dispatch
(34075352828) failed on `build (noble, amd64)` when the r2u mirror timed out
mid-smoke-test — an external outage, not a branch defect; re-dispatched.

- AC1 — met. `publish (noble)` in test mode printed from `imagetools create
  --dry-run` an OCI image index with two manifests, `platform.architecture`
  `arm64` and `amd64`, both `os: linux`; and the tag list it would apply:
  `latest`, `noble`, `noble-2026-09-07`, `noble-2026.08.2-200`. No tag was
  attached (the `--dry-run` branch is the only one test mode reaches).
- AC2 — met. `grep -rn "setup-qemu" .github/` returns nothing. The build job
  has one build step, `platforms: linux/${{ matrix.arch }}`, a single platform;
  the matrix pairs `arch: amd64` with `runner: ubuntu-latest` and `arch: arm64`
  with `runner: ubuntu-24.04-arm` for both variants, so each leg's platform is
  its runner's own architecture. The evidence run confirms the pairing at
  runtime: each leg's pull-back step printed `image is <arch> (<arch> /
  <uname>)` matching its declared arch.
- AC3 — met. `build (noble, arm64)` ran on runner image `ubuntu-24.04-arm` and
  printed `image is arm64 (arm64 / aarch64)` — `docker image inspect
  --format '{{.Architecture}}'` = `arm64`, `uname -m` = `aarch64`. Its smoke
  test logged `PASS: quarto rendered .qmd to HTML`, along with `PASS: container
  reported healthy` and the bspm/mirror-hint assertions. `build (resolute,
  arm64)` printed the same architecture pair.
- AC4 — met. `bash scripts/tests/test_ci_failure_issue.sh` exits 0 over 30
  assertions against the shipped `.github/ci-failure-issue.sh`; `docker.yml`
  contains no `jq` at all and calls `bash ./.github/ci-failure-issue.sh
  "$result" "$RUN_URL" jobs.json`, so there is no second copy. (a) The
  `noble arm64 + publish (noble)` failed / all-resolute-green fixture asserts
  the created issue title matches `^issue create .*--title Weekly rebuild
  failed: noble --body ` (anchored both sides, so a repeat or an extra name
  fails) and asserts no `issue create` call mentioning `resolute`. (b) The
  all-green fixture drives `success`, where the script comments on and closes
  each open ci-failure issue and creates nothing.
- AC5 — met. The one build step carries `no-cache: ${{ github.event_name ==
  'schedule' || github.event_name == 'workflow_dispatch' }}`, true for both
  named events. In the evidence run (a `workflow_dispatch`) all four legs
  reported zero `CACHED` lines, and the RStudio/Pandoc/Quarto layer (`#12 RUN
  chmod -R +x /rocker_scripts && /rocker_scripts/install_rstudio.sh &&
  /rocker_scripts/install_pandoc.sh …`) executed in each: 32.1s (noble amd64),
  35.4s (noble arm64), 33.5s (resolute amd64), 35.6s (resolute arm64).
- AC6 — met. `docker build --pull --no-cache` from a clean context (`git
  archive HEAD` unpacked to an empty directory) exits 0. `hadolint Dockerfile`
  is clean (exit 0) at hadolint 2.12.0, the version `hadolint-action@v3.1.0`
  pins and the PR lane runs; at hadolint `latest` it reports one DL3025 warning
  on the HEALTHCHECK, present identically on the default branch and already a
  `[low]` candidate row. `bash scripts/tests/test_ci_failure_issue.sh` and
  `bash scripts/tests/test_retry.sh` both pass.

### Consistency gate

`cairn_validate.py` exits 0, every check PASS; one advisory WARN — the
`.gitignore` entry `cairn/references/pdf/` is superseded by
`cairn/references/sources/`. Advisory, not a gate failure, and unrelated to
this milestone; filed as a candidate row. No IP/GP principle text changed
(the DESIGN edits are a Conventions bullet and a Known issues entry), so
`cairn_impact.py --changed` does not apply. Profile `docker-image`
consistency-gate slot: clean-context `docker build` succeeds and `hadolint` is
clean (AC6); the base image is pinned to an explicit version
(`rocker/r2u:${UBUNTU_VERSION}`, default `24.04`, never bare `latest`); no
secret is baked into a layer — `DOCKERHUB_TOKEN` reaches only
`docker/login-action`, never an `ENV`, `COPY` or `--build-arg`;
`.dockerignore` is present and excludes `.git`, `.github`, `cairn` and the
launchers; the `changelog` slot declares none as a file, so the user-visible
changes go in the archive summary.

### Independent review

Full three-lens fan-out (user-facing tier, executable diff). [O] diff-bug: 13
candidate findings. [S] blame-history: 1 finding plus four
verified-safe confirmations (the QEMU removal, the 900s->300s arm64 timeout
drop, the `pr-ci.yml` cache-scope repoint, and the numbered-known-issue
references converted to principle citations). [S] prior-review-record: no
prior-review evidence — the probe found no real inline review comments and no
archived `## Review` section touches these files; zero findings, clean no-op.

Findings, ranked, deduplicated across lenses. Dispositions are recorded at the
approval gate.

- F1 The publish job re-scrapes the RStudio version and the UTC date
  independently of the build legs, and nothing carries `steps.meta.outputs.rsver`
  forward. On the default branch one `meta` step resolved both once per variant
  and used the same value for the `RSTUDIO_VERSION` build-arg and for the tag
  list; on this branch the four build legs each scrape it and the publish job
  scrapes it again, roughly an hour later. A stable-release or a midnight-UTC
  crossing in that window attaches `noble-<version>` or `noble-<date>` to an
  image not built from it, and a release landing between the amd64 and arm64
  legs puts two different `RSTUDIO_VERSION` values in one manifest list. Verified
  against `git show origin/main:.github/workflows/docker.yml`.
- F2 The `publish (` half of the failed-variant extraction is untested.
  Replacing `^(build|publish) \(` with `^(build) \(` in both jq lines of
  `.github/ci-failure-issue.sh` leaves the suite green — reproduced by planting
  the mutation. Every fixture carrying a failed `publish (…)` leg also carries a
  failed `build (…)` leg for the same variant, so the publish branch is never the
  sole source of a name. A registry hiccup in `imagetools create` with all builds
  green would fall back to the generic "see the run summary" text unnoticed.
- F3 `notify`'s inline result aggregation falls through to
  `result="$BUILD_RESULT"`, so `BUILD_RESULT=success` with `PUBLISH_RESULT`
  anything but `success`/`failure` (cancelled, skipped) yields `success` — the
  script then comments "succeeded; closing" and closes the open ci-failure issue
  on a run where no tag moved. Raised by both the [O] and [S] lenses. It is also
  a second copy of decision logic in YAML, the pattern T3 removed.
- F4 `resolve-rstudio-version.sh` reaches the network from the publish job,
  a new late failure point that can discard four completed builds; on the default
  branch the scrape preceded every build. Subsumed by F1's fix.
- F5 AC4(b)'s all-green fixture is inert: the success path never reads the
  jobs document, so swapping the fixture for a different one leaves the suite
  green. The criterion as written is met — the script does close on `success` —
  but the fixture discriminates nothing.
- F6 Nothing asserts the assembled manifest list carries both architectures.
  The publish guard counts artifact files (`find . -type f | wc -l` = 2), not
  platforms, and the non-test path runs `imagetools inspect` without reading its
  output. AC1 is enforced by a human reading the log.
- F7 Every run pushes four untagged manifests to Docker Hub before any smoke
  test, and test-mode runs never tag any of them. There is no GC step and no
  Known issues note.
- F8 `printf '  %s\n' $TAGS` and `for t in $TAGS` are unquoted with
  `cwd=/tmp/digests`, so they are exposed to pathname expansion as well as word
  splitting, and `for f in *` matches directories while the guard above it
  counted `find . -type f`. Nothing breaks today (tags carry no glob
  metacharacters), but these inline blocks escape the repo's shellcheck lane.
- F9 `extract_variants` sends all jq diagnostics to `/dev/null`, hiding jq
  being absent or a `gh run view --json jobs` schema change as well as the
  malformed-JSON case it intends to swallow; the alert degrades to generic text
  with no warning.
- F10 `pattern: digests-${{ matrix.variant }}-*` is prefix-based; a future
  variant name extending an existing one (e.g. `noble-lts`) would have its
  artifacts pulled into `noble`'s publish leg, surfacing as a count error rather
  than a naming bug.
- F11 `retention-days: 1` makes GitHub's "Re-run failed jobs" unusable after
  24 hours: the re-run finds no digests and fails with "a build leg failed or was
  skipped", which is misleading. Fails safe.
- F12 The acceptance-criteria boxes were unticked at review entry. Not a
  defect — ticking them against fresh evidence is this phase's job.
- F13 `docker.yml`'s `push.paths` filter does not list
  `.github/ci-failure-issue.sh`. Pre-existing on the default branch; this branch
  made that file more load-bearing.

### Finding dispositions (2026-09-06 gate)

The gate chose to send the milestone back rather than patch at review or merge
with follow-ups. Status returns to `in-progress` for T5–T7.

- F1, F4 -> fix now, as T5. F1 is the return-floor finding: a defect the branch
  introduces in what the published tags promise users.
- F6 -> fix now, folded into T5 (the same job learns to check itself).
- F2, F5, F9 -> fix now, as T6 (all three are the same suite and script).
- F3, F8 -> fix now, as T7.
- F7, F10, F11, F13 -> follow-up candidate rows; none blocks the lane and each
  is independent of T5–T7.
- F12 -> rejected. Ticking the criteria against fresh evidence is the review
  phase's own job, done above; not a defect in the work.
- conversation: PR #22 — no reviews, no comments, no unresolved threads. Nothing
  to triage.
