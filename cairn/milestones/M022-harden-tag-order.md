# M022: Harden the tag-order check

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP7
- **Resolves:** —
- **Surface tier:** user-facing — it decides which images the published Docker Hub tags point at
- **Branch/PR:** m022-harden-tag-order

## Goal

A failed registry read fails a publish leg only after 3 reads of that ref fail, and a tag stamped later than the current UTC time fails the leg instead of being left out with a warning.

## Scope

**In:** a retry of failed reads inside `.github/tag-order.sh`, with a logged line per retried failure. A clock read at
the start of the script, and the refusal of a stamp later than that clock. Two environment variables,
`TAG_ORDER_NOW` and `TAG_ORDER_RETRY_DELAY`, for tests. New cases and stubs in `scripts/tests/test_tag_order.sh`.
The comments of `.github/tag-order.sh` and `.github/workflows/docker.yml` and the tag-order bullet of
`cairn/DESIGN.md`. One test-mode dispatch of `docker.yml` on the branch.

**Out:** a buildx version pin, which the plan gate declined (the work log has the reason). The empty attach path in
a workflow run stays the candidate row "Run the empty attach path in CI". A retry of the r2u install in the smoke
test stays the candidate row "Keep r2u timeouts from failing publish".

## Acceptance criteria

- [ ] AC1: A read is a failed read when `docker buildx imagetools inspect --raw` exits non-zero with stderr that is
      not the buildx not-found line for that ref. After a failed read, `.github/tag-order.sh` pauses and reads the
      ref again, up to 3 reads in all. Each retried failure logs a line that names the ref, the read number, and the
      cause. The first read that exits 0 or answers not-found decides the ref as before. If all 3 reads fail, the ref
      is unsettled: exit 1, no output file, and an `::error::` that names the ref and the cause from read 3. A ref
      whose first read exits 0 or answers not-found is read once. `scripts/tests/test_tag_order.sh` shows these
      cases. 1 failure (an `ERROR` line with a 5xx status), then a stamped answer: decided by the answer, 2 reads.
      2 failures (empty stderr), then a stamped answer: decided by the answer, 3 reads. 3 failures, each with text
      that names its read number: unsettled, 3 reads, and the `::error::` holds the text of read 3. 1 failure, then
      a not-found answer: kept, 2 reads. A not-found ref and a stamped ref with no failures: 1 read of each. An
      exit-0 answer that is not JSON: unsettled after 1 read.
- [ ] AC2: The pause between reads is `TAG_ORDER_RETRY_DELAY` seconds, with a default of 10. If the value is set and
      is not a whole number of 1 to 3 digits, the script exits 1 with an `::error::` before any read and leaves no
      output file. The tests show 2 pauses of 10 seconds for the 3-failure case with the variable unset, and exit 1
      for the values `-1`, `1.5`, `abc`, and `1000`.
- [ ] AC3: Before any read, the script takes the current UTC time in the fixed form `YYYY-MM-DDTHH:MM:SSZ`. If
      `TAG_ORDER_NOW` is set (empty included), it uses that value. Otherwise it uses `date -u +%Y-%m-%dT%H:%M:%SZ`.
      It logs the time and its source. A `TAG_ORDER_NOW` not in the fixed form, or a run stamp later than the time,
      exits 1 with an `::error::`, makes no read, and leaves no output file, a stale one included. A ref whose index
      carries a fixed-form stamp later than the time is unsettled: exit 1, no output file, and an `::error::` that
      names the ref, its stamp, and the time. A stamp equal to or earlier than the time is judged as before. With
      `TAG_ORDER_NOW` set, the tests show: a stamp 1 second later than the time (unsettled, with that error line), a
      stamp equal to the time and later than the run stamp (left out with a warning), a run stamp 1 second later than
      the time (exit 1, no read), and the values `2026-10-20T06:00:00.5Z`, `2026-10-20`, and empty (exit 1, no read,
      a stale file removed).
- [ ] AC4: With `TAG_ORDER_NOW` removed from the environment (`env -u`), the script reads `date -u`. With a `date`
      stub that answers only `-u +%Y-%m-%dT%H:%M:%SZ`, the tests show a stamp 1 second later than the stub's time
      unsettled, and a stamp equal to it decided as before. With the real `date`, the tests show a stamp
      `2999-01-01T00:00:00Z` unsettled.
- [ ] AC5: On the branch's pull request, `scripts/tests/test_tag_order.sh` passes in `pr-ci.yml`, and the shellcheck
      step of `lint.yml` passes at its `-S info` floor. `docker.yml` sets neither `TAG_ORDER_NOW` nor
      `TAG_ORDER_RETRY_DELAY`. In a test-mode dispatch of `docker.yml` on the branch, both publish legs log the time
      `tag-order.sh` read from `date -u` and the tags they can attach, show no `::error::` from the script, and
      conclude `success`. This run covers the path with no failed read.
- [ ] AC6: A whole read of `.github/tag-order.sh`, `docker.yml`, and the tag-order bullet of `cairn/DESIGN.md` finds
      that each comment, input description, and bullet sentence that says when a read or a stamp fails the leg
      states the 3-read retry and its pause, and the refusal of a stamp later than the clock. The header comment of
      the script names both environment variables. No such text still says that one failed read fails the leg.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T3
- AC4 → T1, T3
- AC5 → T4, T5
- AC6 → T4

## Tasks

- [x] T1: In `scripts/tests/test_tag_order.sh`, extend the `docker` stub with a per-ref count of failed reads
      before the answer, each failure with its own stderr (an `ERROR` 5xx line, empty, or text naming the read
      number). Add a `sleep` stub that logs its argument and a `date` stub for AC4 that exits 97 on any other
      arguments. Make `run_script` set `TAG_ORDER_NOW=9999-12-31T23:59:59Z` by default, so the existing 2026 and
      2027 stamps stay earlier than the time. Write the AC1 to AC4 cases first and see them fail.
- [x] T2: Put the retry loop inside `tag-order.sh`, not in `scripts/retry.sh`, because a not-found answer must end
      the loop. Validate `TAG_ORDER_RETRY_DELAY` first. Read the cause for the `::error::` from the last read's
      stderr only.
- [x] T3: Add the clock read, its log line, the `TAG_ORDER_NOW` and run-stamp checks after `rm -f "$out"`, and the
      refusal of a later stamp.
- [ ] T4: Update the header comment and the inline comments of `tag-order.sh`, and in `docker.yml` the `test_mode`
      input description and the comments above and in the `Create the manifest list` step. Update the tag-order
      bullet of `cairn/DESIGN.md`. Its bounds name the refusal and the hand re-point remedy. They also name that a
      future stamp on one moving tag now blocks the date and version tags of that variant each week, that the retry
      widens the gap between read and create, that a 20-second retry does not outlast a Docker Hub rate limit, and
      that a buildx release that rewords its not-found line fails every publish, because the date tag of each run is
      new. Plant each defect (the retry cut to one read, the clock check removed, the delay check removed) and see
      the suite fail.
- [ ] T5: Push the branch and dispatch `docker.yml` in test mode on it once (`gh workflow run docker.yml --ref
      <branch> -f test_mode=true`). The user granted one dispatch, so a second dispatch needs the user's yes.

## Work log

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: not run — work named at the question set.
- 2026-10-20: question set: which work to plan — "Harden the tag-order check".
- 2026-10-20: question set: pin the buildx version in the publish job — no. A reworded not-found line fails every publish loudly and moves no tag.
- 2026-10-20: question set: one test-mode dispatch of docker.yml during the milestone — yes, one run.
- 2026-10-20: collision check: absorbed candidate rows "Refuse tag stamps later than the clock" and "Retry the tag-order registry reads" in full (the buildx pin part declined at the gate). "Run the empty attach path in CI" stays a candidate. No D-entry collides. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-10-20: lessons applied: argument-sensitive stubs (M09/M10) for the docker, date, and sleep stubs. Bound the delay by digit width (M016).
- 2026-10-20: criteria audit (full mode, fresh Opus reader): 15 findings, all fixed in the criteria. Goal reworded to match. Stub detail moved to T1. Retry cases vary the failure kind and check the last cause. Added the read-once non-JSON case, the pause and its validation, the retry log line, empty `TAG_ORDER_NOW`, stale-file and no-read checks, three bad clock values, the run-stamp-later-than-clock exit, the `date` stub, the lint wording, the observable clock in the dispatch, and the widened comment sweep and DESIGN bounds.
- 2026-10-20: no issue assignment option: the Resolves slot is empty.
- 2026-10-20: plan gate chose a retry loop inside tag-order.sh over scripts/retry.sh because a not-found answer must end the loop at once; falsified by a retry.sh form that can stop on a named stderr line.
- 2026-10-20: plan gate chose an exact clock comparison with no skew margin over a margin, because a stamp from a real run is minutes old when another run reads it; falsified by a red run whose later stamp came from a real run.
- 2026-10-20: plan gate chose failing the leg on a future stamp over leaving the tag out with a warning, as the candidate row asked; falsified by a future stamp that a person set on purpose and that must stay.
- 2026-10-20: plan gate chose failing on a run stamp later than the clock over letting the clock rule decide each tag, because both stamps come from runner clocks and a reversed pair means skew; falsified by a red run from sub-second skew between real runners.
- 2026-10-20: started on branch m022-harden-tag-order, cut from main at a72d0ca.
- 2026-10-20: T1 done: docker stub fails read n of a ref from a `fail<n>.err` file, `sleep` stub logs pauses, `date` stub in its own PATH dir; cases 18a-21b added and seen red (65 failures, all in new cases). `TAG_ORDER_NOW` is exported for the whole file rather than set in `run_script`, so direct `bash "$SCRIPT"` calls (case 15) get it too.
- 2026-10-20: T2 and T3 done in one commit: retry loop (3 reads, `::warning::` per retried failure, pause validated before the clock), clock read logged with its source, run-stamp-later-than-clock exit, future-stamp refusal pointing at the re-point command now in the script header. Header comment rewritten with them. test_tag_order.sh 168 ok, 0 FAIL (local bash 3.2). shellcheck 0.11.0 `-x -S info` clean on both files (local koalaman/shellcheck:v0.11.0 image).
- 2026-10-20: implementation choice: retried failures log as `::warning::` so an absorbed failure shows in the run's annotations. The future-stamp error points at the script header for the re-point command rather than repeating it.

## Decisions

## Review
