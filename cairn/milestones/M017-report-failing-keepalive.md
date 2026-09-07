# M017: Report a failing keepalive job

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** internal — CI alerting that reaches only the maintainer; no external consumer of the repo reads it
- **Branch/PR:** m017-report-failing-keepalive

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

- [ ] AC1: Given a results list that includes a `keepalive` result of
      `failure`, `.github/ci-failure-issue.sh` aggregates to `failure` and
      takes the open/comment path, never the close path — asserted by a case
      in `scripts/tests/test_ci_failure_issue.sh` against its call-logging
      `gh` stub.
- [ ] AC2: `docker.yml`'s `notify` job names `keepalive` in both its `needs:`
      list and its `RESULTS` env value, so the set of `needs.<job>.result`
      expressions in `RESULTS` equals the job's `needs:` list — evidenced by
      the committed diff of those two lines.
- [ ] AC3: For a run whose job listing names `keepalive` as the only failed
      job, the issue title and body name `keepalive` rather than the
      `(see the run summary for the failed job)` fallback — asserted in
      `scripts/tests/test_ci_failure_issue.sh`.
- [ ] AC4: For a run whose listing names failed `build (noble, amd64)`,
      `build (noble, arm64)` and `publish (resolute)` legs, the issue names
      `noble resolute` — deduped, in that order, and nothing else — asserted
      in the suite.
- [ ] AC5: For a failure-aggregating run whose listing names a failed
      `keepalive` job the script emits no contradiction warning, and for one
      whose listed jobs all concluded `success` it emits one — both asserted
      in the suite.
- [ ] AC6: The active profile's `verify` slot is clean: `hadolint Dockerfile`
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
- [ ] T2: Generalize `extract_variants` in `.github/ci-failure-issue.sh` into
      a failed-job-name extraction: `build (`/`publish (` legs keep the
      existing variant parse and dedup, every other failed job contributes its
      own `.name`. Re-base the contradiction warning on "names no failed job
      at all". Update the script's usage header, which currently documents
      only variant names. Suite green.
- [ ] T3: Add `keepalive` to `notify`'s `needs:` list and a fourth
      `needs.keepalive.result` to its `RESULTS` env value in
      `.github/workflows/docker.yml`; update the job comment that says "the
      three needed jobs".
- [ ] T4: Run the profile `verify` gate (hadolint + `docker build` +
      shellcheck) and record the output. Update the DESIGN Conventions
      keepalive bullet to state that a failing keepalive job now reports
      through the `ci-failure` issue.

## Work log

- 2026-09-07: created by /milestone-plan.
- 2026-09-07: plan gate chose a general failed-job-name extraction over a keepalive-specific special case in `ci-failure-issue.sh`, because a third reportable job (M018's gap check, a future lane) would need the same widening again and the special case would collect one branch per job; falsified by a job whose name cannot be rendered usefully in an issue title.
- 2026-09-06: T1: suite gains a keepalive-only listing, an AC4 dedup listing, and a results-list case carrying a failed keepalive member; the non-matrix and meta cases flip from fallback text to being named; issue wording moves to job-neutral "Weekly run failed:" / "The scheduled run failed in:" per the implementation gate. 16 assertions red against the unchanged script; shellcheck 0.11.0 -S info clean.
- 2026-09-07: reduced criteria audit ([O] fresh-context reader, internal tier) returned two findings on this milestone — the draft AC4 bound an instrument property ("every case already in the suite passes unmodified") and the draft AC5 promised "emitted only when" over all listings on two example cases. Both fixed before writing: AC4 became a deliverable property over one named listing, AC5 narrowed to its two demonstrated inputs.

## Decisions

## Review
