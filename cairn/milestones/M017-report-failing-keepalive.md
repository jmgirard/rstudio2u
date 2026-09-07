# M017: Report a failing keepalive job

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** internal — CI alerting that reaches only the maintainer; no external consumer of the repo reads it
- **Branch/PR:** m017-report-failing-keepalive / https://github.com/jmgirard/rstudio2u/pull/24

## Goal

A scheduled run whose `keepalive` job fails opens the `ci-failure` issue and
names that job, instead of reading as all-success and closing the issue.

## Scope

**In:** `docker.yml`'s `notify` job gains `keepalive` in both `needs:` and
`RESULTS`. `.github/ci-failure-issue.sh` generalizes its extraction from
"failed variant names" to "failed job names" — build/publish legs still
collapse to a deduped variant, any other failed job contributes its own name —
and its contradiction warning re-bases on that. `scripts/tests/test_ci_failure_issue.sh`
covers the new aggregation, naming, and warning behavior. The `notify` job
comment and the DESIGN Conventions keepalive bullet are brought into step.

**Out:** the rebuild-gap alert → M018. Push contention on the keepalive push
(no `concurrency:` group, no retry, stub always exits 0) → existing candidate
row. Reading the first scheduled keepalive run for the null-`inputs` fallback →
existing candidate row. Reporting a keepalive failure on `workflow_dispatch`
runs → out: a dispatch has a person behind it, which is why `notify` is
schedule-only.

## Acceptance criteria

- [x] AC1: Given a results list that includes a `keepalive` result of
      `failure`, `.github/ci-failure-issue.sh` aggregates to `failure` and
      takes the open/comment path, never the close path — asserted by a case
      in `scripts/tests/test_ci_failure_issue.sh` against its call-logging
      `gh` stub.
- [x] AC2: `docker.yml`'s `notify` job names `keepalive` in both its `needs:`
      list and its `RESULTS` env value, so the set of `needs.<job>.result`
      expressions in `RESULTS` equals the job's `needs:` list — evidenced by
      the committed diff of those two lines.
- [x] AC3: For a run whose job listing names `keepalive` as the only failed
      job, the issue title and body name `keepalive` rather than the
      `(see the run summary for the failed job)` fallback — asserted in
      `scripts/tests/test_ci_failure_issue.sh`.
- [x] AC4: For a run whose listing names failed `build (noble, amd64)`,
      `build (noble, arm64)` and `publish (resolute)` legs, the issue names
      `noble resolute` — deduped, in that order, and nothing else — asserted
      in the suite.
- [x] AC5: For a failure-aggregating run whose listing names a failed
      `keepalive` job the script emits no contradiction warning, and for one
      whose listed jobs all concluded `success` it emits one — both asserted
      in the suite.
- [x] AC6: The active profile's `verify` slot is clean: `hadolint Dockerfile`
      reports no violations and `docker build` succeeds; `shellcheck` at the
      repo's severity floor (D-003) is clean over the changed shell files.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T1, T2
- AC4 → T1, T2
- AC5 → T1, T2
- AC6 → T4

## Tasks

- [x] T1: Add the failing cases to `scripts/tests/test_ci_failure_issue.sh`
      first: keepalive-failure aggregation (AC1), `keepalive` named in title
      and body (AC3), the build/publish dedup case unchanged (AC4), and the
      two warning cases (AC5). Confirm red before touching the script.
- [x] T2: Generalize `extract_variants` in `.github/ci-failure-issue.sh` into
      a failed-job-name extraction: `build (`/`publish (` legs keep the
      existing variant parse and dedup, every other failed job contributes its
      own `.name`. Re-base the contradiction warning on "names no failed job
      at all". Update the script's usage header, which currently documents
      only variant names. Suite green.
- [x] T3: Add `keepalive` to `notify`'s `needs:` list and a fourth
      `needs.keepalive.result` to its `RESULTS` env value in
      `.github/workflows/docker.yml`; update the job comment that says "the
      three needed jobs".
- [x] T4: Run the profile `verify` gate (hadolint + `docker build` +
      shellcheck) and record the output. Update the DESIGN Conventions
      keepalive bullet to state that a failing keepalive job now reports
      through the `ci-failure` issue.

## Work log

- 2026-09-07: created by /milestone-plan.
- 2026-09-07: plan gate chose a general failed-job-name extraction over a keepalive-specific special case in `ci-failure-issue.sh`, because a third reportable job (M018's gap check, a future lane) would need the same widening again and the special case would collect one branch per job; falsified by a job whose name cannot be rendered usefully in an issue title.
- 2026-09-06: T1: suite gains a keepalive-only listing, an AC4 dedup listing, and a results-list case carrying a failed keepalive member; the non-matrix and meta cases flip from fallback text to being named; issue wording moves to job-neutral "Weekly run failed:" / "The scheduled run failed in:" per the implementation gate. 16 assertions red against the unchanged script; shellcheck 0.11.0 -S info clean.
- 2026-09-06: T2: `extract_variants` became `extract_failed_names` — the build/publish variant parse and its dedup kept behind a jq `if`, every other failed job named by itself, so a later reportable job needs no new branch. Contradiction warning re-based on "names no failed job"; usage header, file header and label description brought into step. Suite green (all assertions), shellcheck 0.11.0 -S info clean.
- 2026-09-06: T3: `notify` now needs [meta, build, publish, keepalive] and RESULTS carries the matching fourth `needs.keepalive.result`; parsed the workflow and confirmed the two lists are equal as sets and in length, and that every needed job exists. Job comment re-based off "the three needed jobs".
- 2026-09-06: T4: verify gate clean — hadolint 2.12.0 no violations on `Dockerfile`; `docker build` exit 0 (all 12 steps cached, and a context probe confirmed the context holds only `scripts/`, none of the five files this branch changes); shellcheck 0.11.0 -S info clean on both changed shell files. DESIGN Conventions keepalive bullet now states that a failing keepalive job is reported through the `ci-failure` issue.
- 2026-09-06: all four tasks done, verify gate clean, status -> review.
- 2026-09-07: reduced criteria audit ([O] fresh-context reader, internal tier) returned two findings on this milestone — the draft AC4 bound an instrument property ("every case already in the suite passes unmodified") and the draft AC5 promised "emitted only when" over all listings on two example cases. Both fixed before writing: AC4 became a deliverable property over one named listing, AC5 narrowed to its two demonstrated inputs.
- 2026-09-07: review: PR #24 opened draft; all six criteria verified against fresh evidence and ticked; consistency gate pass (one pre-existing `.gitignore` advisory). Three fresh-context reviewers still running; PR CI shellcheck green, build-smoke pending.

## Decisions

## Review

Evidence gathered 2026-09-07 on `m017-report-failing-keepalive` at 79fd531,
branch even with `main` (c07adaf); PR #24 (draft).

**AC1 — verified.** `bash scripts/tests/test_ci_failure_issue.sh` exit 0, 82
assertions, `PASS: all ci-failure-issue assertions`. The AC1 case (results
`success success success failure`, two open issues, the keepalive-fail
listing) passes four assertions against the call-logging `gh` stub: "keepalive
failure in the results list exits 0", "a failed keepalive never closes the
issue" (no `issue close` call), "... it comments on the open issue instead"
(`issue comment 41`), "... naming the failed job".

**AC2 — verified.** The committed diff of `.github/workflows/docker.yml` moves
`needs: [meta, build, publish]` to `needs: [meta, build, publish, keepalive]`
and appends `${{ needs.keepalive.result }}` to `RESULTS`. Parsing the workflow
fresh: `needs` = [meta, build, publish, keepalive]; the `needs.<job>.result`
expressions in `RESULTS` = [meta, build, publish, keepalive]; equal as sets and
equal in length (so no duplicate hides a gap), and every needed job is defined
in the file.

**AC3 — verified.** Same suite run. Against `FIX_KEEPALIVE_FAIL` (every build
and publish leg `success`, `keepalive` `failure`): "a keepalive-only failure
names keepalive in the title" matches `issue create … --title Weekly run
failed: keepalive`, "... and in the body" matches `--body The scheduled run
failed in: keepalive`, "... and names no variant" confirms neither `noble` nor
`resolute` appears. The `(see the run summary for the failed job)` fallback is
not taken.

**AC4 — verified.** Same suite run. Against `FIX_DEDUP_MIX` (failed `build
(noble, amd64)`, `build (noble, arm64)`, `publish (resolute)`; everything else
green): "both failed variants named once each, in listing order" matches
`--title Weekly run failed: noble resolute --body`, anchored so the title is
exactly those two names in that order and nothing else; "... and the green
keepalive job is not named" confirms no `keepalive` in the create call.

**AC5 — verified.** Same suite run, both directions. Against
`FIX_KEEPALIVE_FAIL` under a `failure` aggregation: "... and warns about
nothing, having named a job" — no `::warning::` on stdout at all. Against
`FIX_ALL_GREEN` (a run reported failed whose listed jobs all concluded
`success`): "... and says the listing named no failed leg" matches
`::warning::the run is reported failed but its job listing names no failed`,
and "... without blaming the parser" confirms no `could not parse` warning.

**AC6 — verified.** `hadolint Dockerfile` (Haskell Dockerfile Linter 2.12.0,
run as `hadolint/hadolint:v2.12.0`, the version `lint.yml` pins): no output,
exit 0. `docker build .`: exit 0, all 12 steps cached off the M016 build —
`.dockerignore` admits only `scripts/` minus `scripts/tests`, so none of the
five files this branch changes is in the context and a cached build is the
expected result rather than a stale one. `shellcheck -S info` (0.11.0, the
D-003 floor and the D-002 pin) over both changed shell files —
`.github/ci-failure-issue.sh` and `scripts/tests/test_ci_failure_issue.sh` —
no output, exit 0.

### Consistency gate

Universal cairn-file checks: `cairn_validate.py` exit 0 — all checks passed,
including `coverage complete`, `binding criteria`, `scaffold present` and
`roadmap<->disk orphans`. One advisory warning, `scaffold deprecations`: the
`.gitignore` entry `cairn/references/pdf/` is superseded by
`cairn/references/sources/` — pre-existing, already carried as a ROADMAP
candidate row, and not a gate failure. No `DESIGN.md` principle (IP/GP) text
changed on this branch — only the Conventions keepalive bullet — so
`cairn_impact.py --changed` does not apply.

Toolchain checks, the `docker-image` profile's `consistency-gate` slot:
`docker build .` exit 0 from the repo context and `hadolint Dockerfile` (2.12.0)
no violations; the base image is pinned to an explicit version tag
(`FROM rocker/r2u:${UBUNTU_VERSION}`, `ARG UBUNTU_VERSION=24.04`), never
`latest`; no secrets baked into layers — the only `ENV`/`ARG` values are
`LANG`, `UBUNTU_VERSION` and `RSTUDIO_VERSION`, and the sole `COPY` is
`scripts /rocker_scripts`; `.dockerignore` is present and excludes `.git`,
`.github`, `cairn`, `.DS_Store` and the launchers; the `## changelog` slot
declares none as a file and no `CHANGELOG.md` exists, so this milestone's
user-visible change is stated in its archive summary.

Gate result: pass.
