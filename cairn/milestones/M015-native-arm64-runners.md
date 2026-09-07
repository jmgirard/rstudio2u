# M015: Native arm64 runners for the image build

- **Status:** review
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

- [x] AC1: A test-mode `workflow_dispatch` run of the branch's `docker.yml` —
      layers pushed by digest, no tag attached — prints from
      `docker buildx imagetools create --dry-run` a noble manifest list naming
      both `linux/amd64` and `linux/arm64`, and prints the tag list it would
      apply, containing `latest`, `noble`, `noble-<UTC date>` and
      `noble-<rstudio version>` (GP2's escape hatch).
- [x] AC2: Reading every step of the merged `.github/workflows/docker.yml` top
      to bottom finds no `docker/setup-qemu-action` step, and finds each build
      step's `platforms:` value equal to the single native architecture of the
      runner its job declares.
- [x] AC3: In the AC1 run, the arm64 leg boots an image whose
      `docker image inspect --format '{{.Architecture}}'` is `arm64` and whose
      container answers `aarch64` to `uname -m`, and `.github/smoke-test.sh`
      against that image logs `PASS: quarto rendered .qmd to HTML`.
- [x] AC4: `scripts/tests/test_ci_failure_issue.sh` exercises the shipped
      failed-variant extraction — the merged `docker.yml` invokes it and keeps
      no second inline copy — over fixtures shaped like the new matrix's
      `gh run view --json jobs` output, covering (a) one variant's arm64 leg
      failing, where the issue body names that variant exactly once and does
      not name the all-green variant, and (b) every leg green, where the
      script closes the issue rather than opening one.
- [x] AC5: Reading every build step of the merged `docker.yml` finds `no-cache`
      set for `schedule` and `workflow_dispatch` events, and the AC1 run's
      build logs show the RStudio/Pandoc/Quarto install layer executed rather
      than reported `CACHED`.
- [x] AC6: `hadolint Dockerfile` clean, `docker build` succeeds from a clean
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
- 2026-09-06: T5-T7 complete; status to review. verify: `hadolint Dockerfile` clean at 2.12.0; both shell suites pass; shellcheck 0.11.0 (-x -S info) clean over all tracked shell files and over the two workflow inline blocks extracted from `docker.yml`. No Dockerfile or build-context file changed in T5-T7 (`scripts/tests` is dockerignored), so the T4 clean-context build stands. The Review section's AC1/AC3/AC5 evidence predates these commits and needs a fresh test-mode dispatch.
- 2026-09-06: dispatched a fresh test-mode run against the T5-T7 branch for the review's AC1/AC3/AC5 evidence: https://github.com/jmgirard/rstudio2u/actions/runs/34077353835 . No watcher left armed; review re-derives the run state.
- 2026-09-06: gate-directed fixes for G1-G7: the publish job now assembles and checks the index with `imagetools create --dry-run` BEFORE any tag moves, so a single-architecture list is refused rather than reported (the real `create` runs only after the check passes, and `.manifests[]?` turns a non-index result into the explicit error instead of a jq abort); `publish` no longer runs when `build` was skipped, and the tag step refuses an empty version or date; the `gh run view` fallback writes an empty file rather than `{"jobs":[]}`, so the alert stops blaming the extraction for a listing that never arrived; `publish` drops its dead `actions/checkout`; and the empty-results aggregation rule gained a test, proven to go red under the mutation that previously survived.
- 2026-09-06: review second pass: all six criteria verified with fresh evidence, re-taken after the gate-directed fixes from test-mode run 34078384423 (all green); consistency gate passes; three-lens review returned 14 findings; the gate chose fix-now for G1-G7, two [low] candidate rows for G9 and G11, and rejected G8, G10 and G12.
- 2026-09-06: step-7 approval: PR #22 approved for merge.

## Decisions

## Review

### First pass (2026-09-06) — returned to `in-progress` as T5-T7

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

### Second pass (2026-09-06)

Evidence run: test-mode `workflow_dispatch` of the branch at `dcc3711`,
https://github.com/jmgirard/rstudio2u/actions/runs/34077353835 (2026-09-07,
all eight jobs green; `notify` skipped, as it is schedule-only). `dcc3711`
differs from the reviewed HEAD by one tracking line only, so the run built the
shipped artifacts.

- AC1 — met. `publish (noble)` in test mode printed from `imagetools create
  --dry-run` an OCI image index with two manifests, `platform.architecture`
  `amd64` (`sha256:900d0a8e…`) and `arm64` (`sha256:ccea1dcf…`), both
  `os: linux`; those are the two digests the noble build legs pushed. It then
  printed the tag list it would apply: `latest`, `noble`, `noble-2026-09-07`,
  `noble-2026.08.2-200`. No tag was attached — test mode reaches only the
  `--dry-run` branch. The step also parsed the index and printed `manifest list
  for noble names both architectures: amd64 arm64`.

- AC2 — met. `grep -rn "setup-qemu\|qemu\|binfmt" .github/ scripts/` returns
  nothing. Parsing the merged `docker.yml` step by step, exactly one step
  carries a `platforms:` value: the build job's, `linux/${{ matrix.arch }}` — a
  single platform. Its matrix pairs `noble/amd64` and `resolute/amd64` with
  `ubuntu-latest` and `noble/arm64` and `resolute/arm64` with
  `ubuntu-24.04-arm`, so each leg's platform is its runner's own architecture.
  The evidence run confirms the pairing at runtime: the amd64 legs ran on
  runner image `ubuntu-24.04` and the arm64 legs on `ubuntu-24.04-arm`, and
  each leg's pull-back step printed `image is <arch> (<arch> / <uname>)`
  matching its declared arch. The `meta`, `publish` and `notify` jobs carry no
  build step and no `platforms:`.

- AC3 — met. `build (noble, arm64)` ran on runner image `ubuntu-24.04-arm` and
  printed `image is arm64 (arm64 / aarch64)` for
  `jmgirard/rstudio2u@sha256:ccea1dcf…` — `docker image inspect --format
  '{{.Architecture}}'` = `arm64`, `uname -m` = `aarch64`. That is the same
  digest the noble manifest list carries as its `arm64` entry (AC1). Its
  `.github/smoke-test.sh` run logged `PASS: quarto rendered .qmd to HTML`,
  along with eight other PASS lines including `PASS: container reported
  healthy` and the bspm and mirror-hint assertions. `build (resolute, arm64)`
  printed `image is arm64 (arm64 / aarch64)` for `sha256:c126adde…`; the two
  amd64 legs printed `image is amd64 (amd64 / x86_64)`, so no two legs
  smoke-tested the same architecture.

- AC4 — met. `bash scripts/tests/test_ci_failure_issue.sh` exits 0 over 67
  assertions, driving the shipped `.github/ci-failure-issue.sh`
  (`SCRIPT="$HERE/../../.github/ci-failure-issue.sh"`). `docker.yml` keeps no
  second copy of the failed-variant extraction — it calls
  `bash ./.github/ci-failure-issue.sh "$RESULTS" "$RUN_URL" jobs.json` and
  parses no job conclusions itself; its one remaining `jq` invocation reads the
  manifest index in the publish job, not the job listing. (a) The
  `noble arm64 + publish (noble)` failed / all-resolute-green fixture asserts
  the created issue title matches `^issue create .*--title Weekly rebuild
  failed: noble --body ` — anchored both sides, so a repeat or an extra name
  fails — and asserts no `issue create` call mentioning `resolute`. (b) The
  all-green fixture drives `success`, where the script comments on and closes
  each open ci-failure issue (`^issue close 41$`, `^issue close 57$`) and
  creates nothing. Both fixtures are load-bearing: the suite was re-run under
  eight planted defects during T6/T7 and went red on each.

- AC5 — met. The one build step carries `no-cache: ${{ github.event_name ==
  'schedule' || github.event_name == 'workflow_dispatch' }}`, true for both
  named events. In the evidence run (a `workflow_dispatch`) every leg's action
  log shows `no-cache: true` and the resulting `docker buildx build` command
  line carries `--no-cache --pull`; all four legs reported zero `CACHED` lines.
  The RStudio/Pandoc/Quarto layer (`#12 [3/4] RUN chmod -R +x /rocker_scripts
  && /rocker_scripts/install_rstudio.sh && /rocker_scripts/install_pandoc.sh
  && /rocker_scripts/install_quarto.sh`) executed in each: 32.5s (noble amd64),
  31.5s (noble arm64), 30.6s (resolute amd64), 33.4s (resolute arm64).

- AC6 — met. `docker build --pull --no-cache` from a clean context (`git
  archive HEAD` unpacked into an empty directory) exits 0; the resulting image
  reports `Architecture` `arm64` and 849 MB, answers `aarch64` to `uname -m`,
  runs quarto 1.9.38, and its build log carries zero `retry:` diagnostics.
  `hadolint Dockerfile` exits 0 at hadolint 2.12.0, the version
  `hadolint/hadolint-action@v3.1.0` pins and the PR lane runs; at hadolint
  `latest` it reports one DL3025 warning on the HEALTHCHECK, present
  identically on the default branch and already a `[low]` candidate row.
  `bash scripts/tests/test_ci_failure_issue.sh` (67 assertions) and
  `bash scripts/tests/test_retry.sh` (5 assertions) both exit 0.

#### Consistency gate (second pass)

`cairn_validate.py` exits 0, every check PASS; one advisory WARN — the
`.gitignore` entry `cairn/references/pdf/` is superseded by
`cairn/references/sources/`. Advisory, not a gate failure, unrelated to this
milestone, and already a candidate row. The `release window` advisory did not
fire. The branch changes no IP/GP principle text — the `DESIGN.md` diff is one
Conventions bullet and one Known issues entry — so `cairn_impact.py --changed`
does not apply. Profile `docker-image` consistency-gate slot: clean-context
`docker build` succeeds and `hadolint` is clean (AC6); the base image is pinned
to an explicit version (`FROM rocker/r2u:${UBUNTU_VERSION}`, default `24.04`,
never a bare `latest`); no secret is baked into a layer — `DOCKERHUB_TOKEN`
reaches only `docker/login-action`, never an `ENV`, `COPY` or `--build-arg`;
`.dockerignore` is present and excludes `.git`, `.github`, `cairn`, the
launchers and `scripts/tests`; the `changelog` slot declares none as a file, so
the user-visible changes go in the archive summary. Byte budgets by hand:
`ROADMAP.md` 3,389 bytes and `LESSONS.md` 3,826 bytes at 49 lines, both inside
their caps.

PR #22 checks: `shellcheck` pass, `build-smoke` pass (2m57s). The first
`build-smoke` attempt failed with `Could not connect to
r2u.stat.illinois.edu:443 (192.17.190.167), connection timed out` — the r2u
mirror unreachable from that runner, which is the outage the image's own
mirror-hint UX is built to report, not a branch defect; re-run green.

#### Independent review (second pass)

Full three-lens fan-out (user-facing tier, executable diff), all three
fresh-context and none having seen the implementation. [O] diff-bug: 14
candidate findings. [S] blame-history: 4 findings, each already a filed
candidate row, plus twelve verified-safe confirmations. [S]
prior-review-record: zero findings — it re-derived that every first-pass
finding dispositioned fix-now (F1-F6, F8, F9) is present in the diff, and the
existence probe `gh api repos/jmgirard/rstudio2u/pulls/comments?per_page=1`
returned `[]`, so the per-PR walk was skipped.

Findings, ranked, deduplicated across lenses. Dispositions are recorded at the
approval gate.

- G1 On the real publish path the architecture assertion runs AFTER
  `docker buildx imagetools create` has attached the tags. `latest`, `noble`,
  `noble-<date>` and `noble-<rsver>` already point at the index by the time
  `got != "amd64 arm64"` fires, so the guard reports a bad publish rather than
  preventing one. Reaching it needs a second latent fault — the prefix-based
  `digests-<variant>-*` artifact pattern pulling a future `noble-lts` leg's
  digest into `noble`, or a matrix edit duplicating a runner label — but the
  outcome is a single-arch `latest` that stays wrong until a human intervenes.
- G2 Same root as G1, stated separately: the only pre-publish gate is a file
  count. The per-leg assertions prove each leg built what it claimed and the
  artifact name encodes the arch, but the publish job reads only hex digest
  filenames and never an architecture, so two same-arch digests satisfy it.
- G3 `if: always() && needs.build.result != 'cancelled'` lets `publish` run
  when `build` was skipped. If `meta` fails — the RStudio version scrape is
  this repo's own documented flaky surface — `build` is skipped, both publish
  legs run, `RSVER` and `DATE` are empty, and the tag step emits
  `jmgirard/rstudio2u:noble-` twice. Nothing validates them; they are never
  pushed only because the digest count is 0 and aborts first, so the count
  guard is load-bearing for a second, unstated reason.
- G4 The `gh run view` fallback writes `{"jobs":[]}`, which the script reads
  as a non-empty listing yielding zero variants, so it fires the
  contradiction warning on top of the notify step's own warning. The alert
  carries two warnings blaming different components, the second accusing the
  extraction of a defect that is not there.
- G5 The "an empty results list is a failure" rule is untested. Replacing
  `[ $# -gt 0 ] || all_success=0` with `:` leaves all 67 assertions passing —
  reproduced independently at review. Unreachable from `docker.yml` today,
  since `RESULTS` always interpolates three values.
- G6 `publish` still runs `actions/checkout@v4` although nothing in the job
  reads the repository: after T5 moved the version resolve into `meta`, its
  steps are buildx setup, login, artifact download and two inline scripts that
  touch only `/tmp`. A dead step on both legs of every run.
- G7 A non-index `imagetools inspect --raw` result dies with jq's own
  `Cannot iterate over null` under `set -e` rather than the `::error::` the
  step wrote for exactly that case.
- G8 `cairn/PROFILE.md:112` reads "multi-arch => `docker buildx` + QEMU in
  CI", which no longer describes this repo's CI.
- G9 `scripts/resolve-rstudio-version.sh:9` cites "Known issue #2", but
  `DESIGN.md`'s Known issues list is an unnumbered bullet list; the same
  dangling form is in `scripts/mirror_hint.R` ("Known issue #1").
- G10 `for t in ${{ matrix.mutable }}` is the one remaining deliberate word
  split in the publish step, and workflow inline blocks are outside the repo's
  shellcheck lane.
- G11 `meta`, `build` and `publish` carry no `permissions:` block, where
  `notify` scopes itself. Unchanged from the default branch's pattern, but the
  diff adds two new jobs.
- G12 The acceptance-criteria checkboxes were unticked. Read from the tree
  before this pass's tick commits landed.
- G13 Re-confirmed, no new information: every run pushes four untagged
  manifests before any smoke test with no GC step; `retention-days: 1` makes
  "Re-run failed jobs" fail misleadingly after 24h; the prefix-based
  `digests-<variant>-*` pattern; `docker.yml`'s `push.paths` omitting
  `.github/ci-failure-issue.sh`. All four are already candidate rows.

#### Re-verification after the gate-directed fixes

The gate directed fixes for G1-G7, which changed `docker.yml`'s publish job and
`ci-failure-issue.sh`'s caller. Fresh evidence re-taken against the fixed
branch, run https://github.com/jmgirard/rstudio2u/actions/runs/34078384423
(2026-09-07, all eight jobs green; `notify` skipped). It supersedes the run
34077353835 figures above for AC1, AC3 and AC5; AC2, AC4 and AC6 were re-run
locally against the fixed tree.

- AC1 — still met, and the ordering the gate asked for is visible. The
  `publish (noble)` step printed the tag list (`latest`, `noble`,
  `noble-2026-09-07`, `noble-2026.08.2-200`), then the index from `imagetools
  create --dry-run` with `platform.architecture` `amd64`
  (`sha256:02acf681…`) and `arm64` (`sha256:62460db2…`), both `os: linux`,
  then `manifest list for noble names both architectures: amd64 arm64`, and
  only then `test mode: the manifest list above was printed, not published; no
  tag attached`. The check precedes the publish decision on both paths.
- AC2 — still met; the workflow's only `platforms:` value and the matrix
  pairing are unchanged by the fixes, and each leg's pull-back step again
  printed its declared architecture: two `image is amd64 (amd64 / x86_64)` and
  two `image is arm64 (arm64 / aarch64)`.
- AC3 — still met. `build (noble, arm64)` printed `image is arm64 (arm64 /
  aarch64)` for `sha256:62460db2…` — the same digest the noble index carries
  as its `arm64` entry — and its smoke test logged `PASS: quarto rendered .qmd
  to HTML`. `build (resolute, arm64)` printed the same architecture pair for
  `sha256:0c90bdd3…`.
- AC4 — still met. `bash scripts/tests/test_ci_failure_issue.sh` exits 0 over
  70 assertions (three added for the empty-results rule), against the shipped
  script; `docker.yml` still parses no job conclusions of its own.
- AC5 — still met. Zero `CACHED` lines across all four legs, and the
  RStudio/Pandoc/Quarto layer executed in each: 37.4s (noble amd64), 36.5s
  (noble arm64), 32.3s (resolute amd64), 45.0s (resolute arm64).
- AC6 — still met. `hadolint Dockerfile` exits 0 at 2.12.0; both shell suites
  pass; shellcheck 0.11.0 `-x -S info` is clean over every tracked shell file
  and over the publish and notify inline blocks extracted from the workflow
  (one SC2153 on `$TAGS`, a false positive — it is a workflow-supplied env
  var). The Dockerfile and build context are untouched by these fixes, so the
  clean-context build recorded for AC6 above stands.

#### Finding dispositions (2026-09-06 gate, second pass)

The gate chose to fix the seven load-bearing findings on the branch and merge
after re-verification, rather than merge with follow-ups.

- G1, G2, G7 -> fixed. The publish job assembles and checks the index with
  `imagetools create --dry-run` before any tag moves; the real `create` runs
  only after the check passes, and `.manifests[]?` turns a non-index result
  into the step's own error rather than a jq abort.
- G3 -> fixed. `publish` no longer runs when `build` was skipped, and the tag
  step refuses an empty version or date.
- G4 -> fixed. The `gh run view` fallback writes an empty file, so a listing
  that never arrived is reported as that and not as a contradiction.
- G5 -> fixed. Three assertions added for the empty-results rule; the mutation
  that previously survived now turns the suite red.
- G6 -> fixed. `publish` drops `actions/checkout`.
- G8 -> rejected. The `PROFILE.md` line is a greenfield opener in a template
  slot, identical on the default branch, and states what multi-arch implies for
  a new repo rather than what this repo's CI does.
- G9 -> follow-up candidate row. Pre-existing on the default branch and
  unmodified by this diff; `scripts/mirror_hint.R` carries the same form.
- G10 -> rejected. `matrix.mutable` is a workflow literal with no glob or
  whitespace, so the split is correct and deliberate.
- G11 -> follow-up candidate row.
- G12 -> rejected. Read from the tree before this pass's tick commits landed;
  all six boxes are ticked against recorded evidence.
- G13 -> no action; all four are already candidate rows.
- conversation: PR #22 — no reviews, no comments, no unresolved threads.
  Nothing to triage.
