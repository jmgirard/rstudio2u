# M031: Fix the CRLF guard's miss and comment

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Surface tier:** internal — a checker over the repo's own launcher blobs and its comments
- **Branch/PR:** —

## Goal

`scripts/tests/test_launcher_line_endings.sh` fails on a `.bat` blob that holds an LF-only line even when the blob ends in a CR with no LF, and its comments and `.gitattributes` no longer claim that `git archive` applies no line-ending conversion.

## Scope

**In:** the guard's line count (the fix rocker-bayes M013 made: append a byte
before counting CR-ended lines); a built-in check that feeds the guard's count
the `a\r\nb\nc\r` bytes and fails if they pass; the guard's header comment and
the `.gitattributes` comment.

**Out:** changing `*.bat -text` to `text eol=crlf` (the blob keeps CRLF); a
guard for `*.cmd` (none tracked); running every unit test in the PR lane →
candidate row "Run every unit test in the PR lane".

## Acceptance criteria

- [ ] AC1: The guard exits 1 with a `FAIL:` line naming the file on each fixture
      blob `a\r\nb\nc\r`, `a\nb\r`, and `a\r\nb\nc\r\n` staged as a tracked
      `.bat`, and exits 0 on the repo's tracked `.bat` blobs at the milestone
      head.
- [ ] AC2: A read of `.gitattributes` and the guard's header comment finds no
      claim that `git archive` applies no line-ending conversion. Any reason
      they give for `-text` names a delivery path and a command whose output a
      reviewer can run to show it.

## Coverage

- AC1 → T1, T2
- AC2 → T3

## Tasks

- [ ] T1: Fix the count in the guard's loop and move it into a function the
      loop calls; add the built-in check on `a\r\nb\nc\r`, which fails on the
      default branch's count, printing a `FAIL:` line that names it.
- [ ] T2: In a scratch clone, stage each AC1 fixture as a tracked `.bat` and run
      the guard; confirm each red run's output names that file's `FAIL:` line,
      then run it on the repo.
- [ ] T3: Rewrite the guard's header and the `.gitattributes` comment; keep any
      reason for `-text` only with the delivery path and command that show it.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — three independent README, launcher, and test fixes; planned with its two siblings.
- 2026-11-05: idea vet: none found.
- 2026-11-05: checker-regress check: the guard shipped in M08 and checks repo blobs; this repair keeps its promise (every line CRLF), so it is outside the regress shape.
- 2026-11-05: chose a built-in check inside the guard over a separate fixture test script because a new script needs wiring into `pr-ci.yml` and `launchers.yml` and a repo-path argument; falsified by the built-in check passing a shape the AC1 fixtures fail.
- 2026-11-05: collision check: absorbs rocker-bayes row "Fix rstudio2u's CRLF guard and claim" (rocker-bayes M013). Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: criteria audit (reduced mode, fresh Opus reader): 2 findings, both fixed — AC1 one byte string per case did not enumerate the shapes, now three named fixtures; AC2 a `git archive` run disproves the old reason and cannot support a new one, so a reason must name its delivery path and command.
- 2026-11-05: lessons used: 2026-07-18 (M08) on Windows .bat handling; 2026-11-05 (M024) on counting a planted run as red only when it names the expected FAIL line; 2026-11-05 (M023) on launchers.yml running only on pull requests.

## Decisions

## Review
