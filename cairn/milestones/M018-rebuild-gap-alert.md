# M018: Alert when no weekly rebuild has succeeded in too long

- **Status:** review
- **Priority:** normal
- **Depends on:** M017
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** internal — CI alerting that reaches only the maintainer; no external consumer of the repo reads it
- **Branch/PR:** m018-rebuild-gap-alert

## Goal

When no scheduled rebuild has succeeded for more than fifteen days — whatever
the cause — the repo raises the `ci-failure` issue instead of going quiet.

## Scope

**In:** `.github/rebuild-gap.sh` holds the staleness rule (the `keepalive.sh`
pattern: validated arguments in, a decision out, no network of its own),
driven offline by `scripts/tests/test_rebuild_gap.sh`. A new scheduled
workflow asks `gh run list` for the newest successful scheduled `docker.yml`
run and hands the script its date; on a gap the script raises the `ci-failure`
issue through `.github/ci-failure-issue.sh`, which gains an optional subject
argument so the issue reads as a gap rather than a build failure. The DESIGN
Conventions record the alert and its bound.

**Out:** reading Docker Hub tag dates as a second oracle → candidate row
(added in this plan commit). Alerting on `pr-ci.yml` → out of scope; it has a
person behind every run. A live `workflow_dispatch` demonstration as an
acceptance promise → out: it crosses a process boundary the internal tier
excludes, so the dispatch run happens as T5 and is logged, not graded.

## Acceptance criteria

- [ ] AC1: `.github/rebuild-gap.sh` decides gap / no-gap from three arguments
      (last-success date, current date, threshold days) and makes no `gh`,
      `curl` or `wget` call while deciding — both outcomes driven in
      `scripts/tests/test_rebuild_gap.sh` against call-logging stubs for all
      three commands, which log zero calls on the deciding path.
- [ ] AC2: Each of these is refused with exit 2 and a message naming the
      rejected argument, making no `gh` call: a mis-shaped date, an impossible
      calendar date (`2026-02-30`), a last-success date later than the current
      date, a missing threshold, and a non-integer threshold; and a threshold
      of more than seven digits reads as no-gap rather than wrapping negative
      — one suite case each.
- [ ] AC3: On a gap the script invokes `.github/ci-failure-issue.sh` with a
      gap subject; with no gap it makes no `gh` call at all — both asserted
      against the call-logging stub in the suite.
- [ ] AC4: A workflow file in `.github/workflows/` carries its own `schedule:`
      trigger and a `workflow_dispatch:` trigger, obtains the newest
      successful scheduled `docker.yml` run's date via `gh run list`, and
      passes that date, today's UTC date, and the threshold to
      `.github/rebuild-gap.sh` — evidenced by the committed file.
- [ ] AC5: `.github/ci-failure-issue.sh` renders the gap subject in the issue
      title and body when given one, and renders exactly as it does today when
      not — asserted by one new and one unchanged case in
      `scripts/tests/test_ci_failure_issue.sh`.
- [ ] AC6: `cairn/DESIGN.md` records the gap alert and its bound: once GitHub
      has disabled the repository's scheduled workflows, the gap check is
      disabled with them, so that failure mode belongs to the keepalive
      (M016), not to this alert.
- [ ] AC7: The active profile's `verify` slot is clean: `hadolint Dockerfile`
      reports no violations and `docker build` succeeds; `shellcheck` at the
      repo's severity floor (D-003) is clean over the changed shell files.

## Coverage

- AC1 → T1, T3
- AC2 → T1, T3
- AC3 → T1, T2, T3
- AC4 → T4
- AC5 → T2
- AC6 → T5
- AC7 → T5

## Tasks

- [x] T1: Write `scripts/tests/test_rebuild_gap.sh` first — the gap and no-gap
      outcomes, the five rejections, the over-wide threshold, and the
      zero-call assertions — against `gh`/`curl`/`wget` stubs modelled on
      `scripts/tests/test_keepalive.sh`'s call-logging `git` stub. Confirm red.
- [x] T2: Add an optional subject argument to `.github/ci-failure-issue.sh`
      (default: today's wording), and cover both renderings in
      `scripts/tests/test_ci_failure_issue.sh`.
- [x] T3: Write `.github/rebuild-gap.sh`, reusing `keepalive.sh`'s
      `days_from_civil` / `parse_date` / digit-width bound rather than
      re-deriving them. Suite green.
- [x] T4: Add the scheduled workflow: `gh run list --workflow docker.yml
      --event schedule --status success --limit 1 --json createdAt`, reduce to
      a UTC `YYYY-MM-DD`, and call `rebuild-gap.sh` with it, today, and `15`.
      An empty result means no successful scheduled run is on record, which is
      a gap — handle it explicitly rather than letting it parse as a bad date.
- [x] T5: Update the DESIGN Conventions for the alert and its bound, and run
      the profile `verify` gate. The dispatch run (not an acceptance promise)
      moves to post-merge: GitHub refuses `workflow_dispatch` for a workflow
      file that is not yet on the default branch, so it cannot happen on this
      branch. Its log is recorded in the work log when it runs.

## Work log

- 2026-09-07: created by /milestone-plan.
- 2026-09-07: plan gate chose workflow run history (`gh run list`) over the Docker Hub `<variant>-<date>` tag date as the gap oracle, because it is authoritative, needs no scrape, and reports a renamed or broken workflow as an empty result; falsified by a run that reports success without moving a tag. The tag-date oracle is carried as a candidate row.
- 2026-09-07: plan gate chose reusing the `ci-failure` issue stream over a separate `rebuild-gap` label, because the next green scheduled rebuild is exactly the right close condition for a gap and one stream is one thing to watch; falsified by gap and build-failure alerts needing different close conditions.
- 2026-09-07: reduced criteria audit ([O] fresh-context reader, internal tier) returned three findings on this milestone. Draft AC1's "no network call" and draft AC2's "every argument is validated" were unbounded promises over domains their named procedures could not enumerate; both were narrowed before writing — AC1 to three call-logging stubs, AC2 to its listed rejections. Draft AC4 required a live `workflow_dispatch` demonstration (a process/environment boundary the internal tier excludes) and bound an evidence-quotation act; posed at the gate, which chose the file-state promise and moved the dispatch run to T5.
- 2026-09-07: T1 — wrote `scripts/tests/test_rebuild_gap.sh` against call-logging `gh`/`curl`/`wget` stubs; confirmed red (exit 127, no `.github/rebuild-gap.sh`). Gate chose: a fourth positional subject argument on `ci-failure-issue.sh`; a gap alert raised (not swallowed) when the run history cannot be read; a weekly Monday cadence a few hours after the rebuild.

- 2026-09-07: minor amendment — T2 and T3 swapped, because the gap script's alert wording is what T2 (the subject argument) provides; Coverage renumbered with them (AC5 → T2, AC1/AC2 → T1, T3).
- 2026-09-07: T2 — `.github/ci-failure-issue.sh` takes an optional fourth argument that replaces the failed-job wording in the title and in the lead line of both the body and the repeat comment; omitted, every rendering is byte-identical to before. Four cases added to `scripts/tests/test_ci_failure_issue.sh` and the no-subject body lead newly asserted; planting an appending-instead-of-replacing defect turned 6 assertions red, restoring it turned them green. Suite passes; pinned shellcheck 0.11.0 clean over the changed files.

- 2026-09-07: T3 — `.github/rebuild-gap.sh` written; the date parsing, calendar check and threshold width bound moved to a new `.github/date-lib.sh` sourced by it and by `keepalive.sh`, whose suite stays green unchanged. The boundary is not shared: keepalive acts at or past its threshold, the gap check only past its own. Both `scripts/tests/test_rebuild_gap.sh` and `test_keepalive.sh` pass. Discrimination checked by planting three defects — the boundary off by one (3 red), a `curl` call on the deciding path (10 red), the unreadable-history sentinel claiming a measured gap (3 red) — each green again on restore. Pinned shellcheck 0.11.0 clean over every tracked shell file plus the two new ones.

- 2026-09-07: T4 — `.github/workflows/rebuild-gap.yml` added: `schedule:` Mondays 12:00 UTC (six hours after the 06:00 rebuild) plus `workflow_dispatch:` with a threshold input, `gh run list --workflow docker.yml --event schedule --status success --limit 1` reduced to the UTC date before the `T`, then `.github/rebuild-gap.sh` with that, today and 15. Its three branches were exercised offline against a stubbed `gh` — a date, an empty result (`none`), and a failed lookup (`unknown`).
- 2026-09-07: T4 minor addition beyond the plan — `scripts/tests/test_rebuild_gap.sh` wired into `pr-ci.yml`'s unit-test step, with `.github/rebuild-gap.sh` and `.github/date-lib.sh` added to that lane's `paths` filter; a new suite that CI never runs is not a guard.

- 2026-09-07: T5 — DESIGN Conventions gained the gap-alert bullet and its bound (the check is itself scheduled, so a disabled-schedule failure belongs to the keepalive, not here). Profile verify gate clean: `hadolint` 2.12.0 reports no violations, `docker build` succeeds (arm64, image sha256:e77c8ff287dd), pinned shellcheck 0.11.0 clean over all 31 tracked shell files, and all seven shell suites pass.
- 2026-09-07: T5 minor amendment — the dispatch run moves to post-merge. `gh workflow run rebuild-gap.yml --ref m018-rebuild-gap-alert` returned `HTTP 404: workflow rebuild-gap.yml not found on the default branch`, and `gh workflow list --all` lists only the six workflows already on `main`, so a workflow file can be dispatched only once it is there. Recorded, not graded — the plan already put the dispatch outside the acceptance promises.
- 2026-09-07: local `docker build --platform linux/amd64` failed at the `COPY scripts` layer ("does not provide the specified platform") because this host has no buildx and the classic builder cannot cross-build; the verify build was run natively for arm64 instead. CI builds each architecture on a runner of that architecture, so nothing about the image is unevidenced by this — only the local flag was wrong.

## Decisions

## Review
