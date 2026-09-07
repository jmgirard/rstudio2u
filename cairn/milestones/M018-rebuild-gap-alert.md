# M018: Alert when no weekly rebuild has succeeded in too long

- **Status:** review
- **Priority:** normal
- **Depends on:** M017
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** internal — CI alerting that reaches only the maintainer; no external consumer of the repo reads it
- **Branch/PR:** m018-rebuild-gap-alert / https://github.com/jmgirard/rstudio2u/pull/26

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

- [x] AC1: `.github/rebuild-gap.sh` decides gap / no-gap from three arguments
      (last-success date, current date, threshold days) and makes no `gh`,
      `curl` or `wget` call while deciding — both outcomes driven in
      `scripts/tests/test_rebuild_gap.sh` against call-logging stubs for all
      three commands, which log zero calls on the deciding path.
- [x] AC2: Each of these is refused with exit 2 and a message naming the
      rejected argument, making no `gh` call: a mis-shaped date, an impossible
      calendar date (`2026-02-30`), a last-success date later than the current
      date, a missing threshold, and a non-integer threshold; and a threshold
      of more than seven digits reads as no-gap rather than wrapping negative
      — one suite case each.
- [x] AC3: On a gap the script invokes `.github/ci-failure-issue.sh` with a
      gap subject; with no gap it makes no `gh` call at all — both asserted
      against the call-logging stub in the suite.
- [x] AC4: A workflow file in `.github/workflows/` carries its own `schedule:`
      trigger and a `workflow_dispatch:` trigger, obtains the newest
      successful scheduled `docker.yml` run's date via `gh run list`, and
      passes that date, today's UTC date, and the threshold to
      `.github/rebuild-gap.sh` — evidenced by the committed file.
- [x] AC5: `.github/ci-failure-issue.sh` renders the gap subject in the issue
      title and body when given one, and renders exactly as it does today when
      not — asserted by one new and one unchanged case in
      `scripts/tests/test_ci_failure_issue.sh`.
- [x] AC6: `cairn/DESIGN.md` records the gap alert and its bound: once GitHub
      has disabled the repository's scheduled workflows, the gap check is
      disabled with them, so that failure mode belongs to the keepalive
      (M016), not to this alert.
- [x] AC7: The active profile's `verify` slot is clean: `hadolint Dockerfile`
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
- 2026-09-07: review — PR #26 opened; every acceptance criterion executed with fresh evidence and ticked; consistency gate clean (`cairn_validate` all checks pass, one pre-existing advisory); three review lenses returned eleven findings, all from the diff-bug lens, logged in the Review section with a proposed triage for the gate.

## Decisions

## Review

Evidence gathered 2026-09-07 at `9544304` (branch head), PR #26.

**AC1 — pass.** `bash scripts/tests/test_rebuild_gap.sh` exits 0 with 111 `ok:`
assertions and no FAIL. Both outcomes are driven: cases 1–2 (14 and 15 days
against a 15-day bound) exit 0 and assert empty `gh`, `curl` and `wget` logs;
case 3 (16 days) alerts and asserts empty `curl`/`wget` logs, the only `gh`
call being the alert itself, not the decision. The suite proves the three stubs
recordable before asserting their silence (a `probe-call` written to each log).
Discrimination re-checked at review: a `curl` call planted on the deciding path
turned 9 assertions red; restoring the file returned the suite to PASS.

**AC2 — pass.** Each rejection was run directly against the committed script,
and each is a suite case (numbers 8–13 in `test_rebuild_gap.sh`, all green in
the run above). A date written with unpadded month and day parts → exit 2, "the last
success date (argument 1) is not a YYYY-MM-DD date". Impossible calendar date `2026-02-30`
→ exit 2, "names day '30', which that month does not have". Last-success later
than current (`2026-01-18` vs `2026-01-17`) → exit 2, "the last success date
(argument 1) is later than the current date". Missing threshold (`""`) → exit
2, "the threshold in days (argument 3) is missing". Non-integer threshold
(`fifteen`) → exit 2, "is not a non-negative integer: 'fifteen'". Every one
names its argument by position. An eight-digit threshold (`99999999`) exits 0
with "within the 99999999-day bound; no alert" — no gap, not a wrapped
negative; suite case 13 drives 8, 19 and 32 digits, case 14 the seven-digit
neighbour that is still compared. `assert_no_gh` holds on every rejection.

**AC3 — pass.** From the same green run. On a gap (case 3, 16 days against a
15-day bound) the call-logging `gh` stub records `issue create ... --label
ci-failure --title No successful weekly rebuild in 16 days (since 2026-01-01)`,
and a negative assertion confirms the build-failure title wording never
appears. Cases 5 and 6 show the two sentinels reaching the same script with
their own subjects (`No successful weekly rebuild on record`, `Could not read
the weekly rebuild history`), and case 4 shows a gap with the issue already
open commenting on it rather than opening a second. On no gap (cases 1 and 2)
`assert_no_gh` passes: the `gh` log is empty.

**AC4 — pass.** `.github/workflows/rebuild-gap.yml` is committed on the branch.
Parsed with PyYAML at review: triggers are `schedule` (cron `0 12 * * 1`) and
`workflow_dispatch` (one `threshold_days` input); the single job `gap` is named
`rebuild-gap` with `contents: read, issues: write, actions: read`; the step runs
`gh run list --workflow docker.yml --event schedule --status success --limit 1
--json createdAt --jq '.[0].createdAt // empty'` and ends with `bash
./.github/rebuild-gap.sh "$last_success" "$today" "$THRESHOLD"`, where `today`
is `date -u +%Y-%m-%d`. Beyond the file-state promise, the step body was
extracted from the YAML and run offline against a stubbed `gh` in all three
modes: a date reduced to `2026-01-01`, an empty result to `none`, and a failed
lookup to `unknown` with the `::warning::` line — each reaching the script with
today's UTC date and the threshold.

**AC5 — pass.** `bash scripts/tests/test_ci_failure_issue.sh` exits 0 with 100
`ok:` assertions and no FAIL, seven of them on the subject argument (a subject
becomes the whole issue title; it is the comment's lead line on the repeat
path; it still owns the title alongside a jobs document; a multi-line subject
is accepted). Byte-identity of the no-subject rendering was checked
independently of the suite at review: `git show origin/main:` and the branch
version were each run under one call-logging `gh` stub with the same
three-argument input, on all three paths — open a new issue, comment on an open
one, close on success — and `diff -u` reports the logged calls identical in
every case. With a subject and an empty jobs document the same stub records
`issue create --label ci-failure --title No successful weekly rebuild in 16
days (since 2026-01-01)`, that line also leading the body.

**AC6 — pass.** `git diff origin/main...HEAD -- cairn/DESIGN.md` shows one
added Conventions bullet, placed after the M016/M017 keepalive bullet it
cross-references. It records the alert (weekly, `gh run list` on scheduled
`docker.yml`, the same `ci-failure` issue, more than 15 days) and states the
bound in the criterion's terms: "this check is itself on a schedule, so once
GitHub has disabled the repository's scheduled workflows it is disabled with
them — that failure mode belongs to the keepalive above, not here."

**AC7 — pass.** All three run at review against the branch tree. `hadolint`
v2.12.0 (the version `hadolint-action@v3.1.0` pins, run from the
`hadolint/hadolint:v2.12.0` image) on `Dockerfile`: exit 0, no violations.
`docker build -t rstudio2u:m018-review .`: exit 0, image `e77c8ff287dd`
(native arm64; every layer served from the cache of the T5 build of this same
tree — the local amd64 cross-build is unavailable on this host and is CI's
job, per the T5 work-log line; `.dockerignore` excludes `.github`, `cairn` and
`scripts/tests`, so no file this milestone changed is in the build context at
all). `shellcheck` v0.11.0 (D-002's pin, from
`koalaman/shellcheck:v0.11.0`) at `-S info` (D-003's floor) with `-x`, over
the same 31-file `git ls-files '*.sh' '*.command'` enumeration `lint.yml`
uses: exit 0, no findings — the changed files among them.

### Consistency gate

Universal cairn-file checks: `cairn_validate.py` exits 0, all sixteen checks
PASS. One advisory WARN stands — the `.gitignore` entry
`cairn/references/pdf/` superseded by `cairn/references/sources/` — which is
pre-existing and already carried as a ROADMAP candidate row. (One transient
FAIL was self-inflicted: an evidence line above quoted a mis-shaped test date
literally and tripped the `iso date format` check; the line was reworded, not
the check.) `cairn_impact.py` not run: the DESIGN diff adds one Conventions
bullet and changes no `IP`/`GP` principle line.

Toolchain checks from the `docker-image` profile's `consistency-gate` slot:
`docker build` succeeds and `hadolint` reports no violations (AC7 above); the
base image is `FROM rocker/r2u:${UBUNTU_VERSION}` with `ARG
UBUNTU_VERSION=24.04`, an explicit version, never a bare `latest`; no secret
is baked into a layer (the only `ARG`/`ENV` values are the Ubuntu version, the
locale, and `RSTUDIO_VERSION="stable"`); `.dockerignore` is present and
excludes `.git`, `.github`, `cairn` and `scripts/tests`; the `changelog` slot
is `none` as a file, so this milestone's user-visible changes go in its
archive summary.

All eight shell suites pass at review: `test_ci_failure_issue.sh` 100 ok,
`test_keepalive.sh` 93 ok (unchanged by the `date-lib.sh` extraction),
`test_launcher_line_endings.sh` 2, `test_parse_pandoc_version.sh` 9,
`test_rebuild_gap.sh` 111, `test_resolve_download_url.sh` 9,
`test_resolve_rstudio_version.sh` 7, `test_retry.sh` 5. PR #26 CI is green:
`build-smoke` pass (3m3s), `shellcheck` pass (6s).

### Independent review

Three fresh-context lenses, distinct evidence bases. **[S] blame-history**: no
findings — the `date-lib.sh` extraction moves `keepalive.sh`'s functions
without logic change, `keepalive.sh` keeps its own "at or past" boundary, the
`ci-failure-issue.sh` subject argument is additive, and no `D-` entry is
contradicted. **[S] prior-PR-comments**: no findings; the GitHub probe
(`pulls/comments?per_page=1`) returned `[]`, so no thread walk. It checked the
diff against four prior-review records and cleared each — M017's multi-word
job-name candidate (this workflow's job is `rebuild-gap`, one word, and the
gap path passes no jobs document at all), M017's `timed_out` candidate
(untouched), M016's wrapping-threshold lesson (the seven-digit bound is
carried forward), M015's omitted-paths candidate (both new scripts are added
to `pr-ci.yml`'s filter). **[O] diff-bug** returned eleven, ranked, below.

Verified before triage: `docker.yml`'s cron is `0 6 * * 1` and this check's is
`0 12 * * 1`, so finding 1's arithmetic holds; a `createdAt` with no `T`
reaches `parse_date` and exits 2 raising nothing, so finding 3 holds.

1. The documented bound and the observable bound differ by a week. Both
   workflows are weekly, so every gap this check can measure is a multiple of
   seven — 0, 7, 14, 21 — and a 15-day threshold first fires at 21 days, three
   missed rebuilds, though the Goal, the DESIGN bullet and the dispatch input
   all say "more than 15 days". A threshold of 8–13 would make the stated
   intent and the behavior agree (alert on the second missed week).
2. The workflow's own reduction logic is the one untested link in the chain:
   its three branches live in YAML shell, AC4 promises only file state, and no
   committed suite exercises them. (Review drove all three offline — AC4
   evidence above — but that is a review act, not a guard.)
3. A malformed `createdAt` is the one lookup failure not funnelled into
   `unknown`: `${created_at%%T*}` passes a string with no `T` straight
   through, `parse_date` refuses it, and the workflow exits 2 having raised
   nothing — the silence this milestone exists to end.
4. `rebuild-gap.yml` has no self-report. If its step fails for any reason —
   a bad dispatch threshold, say — the result is a red run and GitHub's
   default email, where `docker.yml` carries a `notify` job for exactly that.
5. Argument-validation order names the wrong argument first on a bare
   invocation: arguments 2 and 3 are validated before 1, so a no-argument call
   reports argument 2 missing where `keepalive.sh` reports argument 1.
6. The subject trim handles LF but not CR: `${subject%%$'\n'*}` leaves a
   trailing `\r` on a CRLF subject. No current caller can produce one.
7. `ci-failure-issue.sh` still has no upper bound on `$#`; a fifth argument is
   silently ignored. Pre-existing, though the positional tail is now longer.
8. `created_at.txt` is written into the checkout rather than `$RUNNER_TEMP`.
9. Two idioms for the same job: `keepalive.sh` sources via `$(dirname
   "${BASH_SOURCE[0]}")`, `rebuild-gap.sh` via `$(cd "$(dirname ...)" && pwd)`.
10. A comment justifies something that cannot happen here: the `name:
    rebuild-gap` comment explains the one-word job name by the space-joined
    failed-job names in a `ci-failure` title, but this workflow has no
    `notify` job and its job name never reaches an issue title.
11. The threshold `15` is stated in three places bound only by a comment. The
    same pattern already exists for the keepalive's `50`.

The [O] lens did not re-run AC7's gate (no `shellcheck` on that host); this
session ran all three from pinned images, recorded under AC7 above.

Proposed triage, put to the maintainer at the gate: fix now — 1 (the
threshold, so the alert fires on the second missed week), 3 (a shape check
routing an unparseable `createdAt` to the `unknown` sentinel), 10 (the
comment's rationale, a claim its own workflow does not support); follow-up
candidate rows — 2 and 4; reject — 5 (deliberate ordering, no criterion pins
it), 6 (no caller can produce CRLF), 7 (pre-existing, not introduced here),
8 (no later step reads the tree), 9 (both idioms correct), 11 (the repo's
existing convention).
