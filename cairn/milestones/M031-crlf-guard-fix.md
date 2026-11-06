# M031: Fix the CRLF guard's miss and comment

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Surface tier:** internal — a checker over the repo's own launcher blobs and its comments
- **Branch/PR:** m031-crlf-guard-fix

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

- [x] AC1: The guard exits 1 with a `FAIL:` line naming the file on each fixture
      blob `a\r\nb\nc\r`, `a\nb\r`, and `a\r\nb\nc\r\n` staged as a tracked
      `.bat`, and exits 0 on the repo's tracked `.bat` blobs at the milestone
      head.
- [x] AC2: A read of `.gitattributes` and the guard's header comment finds no
      claim that `git archive` applies no line-ending conversion. Any reason
      they give for `-text` names a delivery path and a command whose output a
      reviewer can run to show it.

## Coverage

- AC1 → T1, T2, T5
- AC2 → T3, T4

## Tasks

- [x] T1: Fix the count in the guard's loop and move it into a function the
      loop calls; add the built-in check on `a\r\nb\nc\r`, which fails on the
      default branch's count, printing a `FAIL:` line that names it.
- [x] T2: In a scratch clone, stage each AC1 fixture as a tracked `.bat` and run
      the guard; confirm each red run's output names that file's `FAIL:` line,
      then run it on the repo.
- [x] T3: Rewrite the guard's header and the `.gitattributes` comment; keep any
      reason for `-text` only with the delivery path and command that show it.
- [x] T4: (review return 1) Replace the `.gitattributes` `cmp` commands with
      one whose output differs between `-text` and `text eol=crlf`, and keep
      only the reasons that command shows, in both comments.
- [x] T5: (review return 1, fix-now) Move the guard's verdict into one
      function the built-in check and the loop share: fail a CR with no LF
      after it, an unreadable blob, and an unreadable count; the built-in
      check asserts two bad shapes and one good one.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — three independent README, launcher, and test fixes; planned with its two siblings.
- 2026-11-05: idea vet: none found.
- 2026-11-05: checker-regress check: the guard shipped in M08 and checks repo blobs; this repair keeps its promise (every line CRLF), so it is outside the regress shape.
- 2026-11-05: chose a built-in check inside the guard over a separate fixture test script because a new script needs wiring into `pr-ci.yml` and `launchers.yml` and a repo-path argument; falsified by the built-in check passing a shape the AC1 fixtures fail.
- 2026-11-05: collision check: absorbs rocker-bayes row "Fix rstudio2u's CRLF guard and claim" (rocker-bayes M013). Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: criteria audit (reduced mode, fresh Opus reader): 2 findings, both fixed — AC1 one byte string per case did not enumerate the shapes, now three named fixtures; AC2 a `git archive` run disproves the old reason and cannot support a new one, so a reason must name its delivery path and command.
- 2026-11-05: lessons used: 2026-07-18 (M08) on Windows .bat handling; 2026-11-05 (M024) on counting a planted run as red only when it names the expected FAIL line; 2026-11-05 (M023) on launchers.yml running only on pull requests.

- 2026-11-05: chose `line_counts`, which takes the byte-producing command as arguments and runs it twice, over reading stdin into a temp file; the built-in check passes `printf 'a\r\nb\nc\r'` and the loop passes `git cat-file -p ":$f"`.
- 2026-11-05: T1 done: guard passes the 2 tracked `.bat` blobs; a copy with the old count (no appended x) exits 1 with the built-in check's `FAIL:` line; shellcheck 0.11.0 `-x -S info` clean, run through the `koalaman/shellcheck:v0.11.0` image since shellcheck is not installed locally. Dockerfile and build context unchanged (`scripts/tests` is in `.dockerignore`), so the hadolint and build gate does not apply.
- 2026-11-05: T2 done in a scratch clone of the branch: staged `fixture1.bat` (bytes `610d0a620a630d`), `fixture2.bat` (`610a620d`), and `fixture3.bat` (`610d0a620a630d0a`) one at a time; the guard exited 1 on each with `FAIL: fixtureN.bat — blob has 1 LF-only line(s) …`; the default branch's guard passed fixtures 1 and 2 (exit 0) and failed 3; the guard exits 0 on the clean clone's 2 tracked `.bat` blobs.
- 2026-11-05: T3 claims read from scratch repos (git 2.54.0): under `*.bat -text`, `git archive` and a checkout with `core.autocrlf=true` wrote each blob's bytes unchanged (an LF blob as LF); under `text eol=crlf`, the blob held LF and `git archive` wrote CRLF, so the removed "applies no eol conversion" claim was false.
- 2026-11-05: T3 done: the `.gitattributes` comment states that `-text` turns off conversion and a checkout and `git archive` write the blob's bytes, with two `cmp` commands that print nothing and exit 0 in a clone; the guard header points to them; no reason naming Download ZIP or a raw download, since neither was run; `git check-attr` unchanged; guard exit 0; shellcheck clean.
- 2026-11-05: claim audit: not owed — internal tier.
- 2026-11-05: implement done: all tasks checked, guard and shellcheck clean; status → review.
- 2026-11-05: review return 1: AC2 — the `.gitattributes` comment says its two `cmp` commands show that `-text` turns conversion off, but they print nothing for any CRLF blob under either attribute, so they show only that the written bytes match the blob (diff-bug #1). The same return carries the fix-now guard items: diff-bug #2, #3, #4, #6, #7 and blame-history #1 (Review section).
- 2026-11-05: filed parked row "Show why .bat files use -text" for diff-bug #8 and blame-history #2–#3; parked because no documented or common use is known to fail.
- 2026-11-05: minor amendment: added T4 (the return's AC2 failure) and T5 (the return's fix-now guard items); Coverage now AC1 → T1, T2, T5 and AC2 → T3, T4.
- 2026-11-05: T4 done: the `.gitattributes` command stores an LF-only blob and runs `git cat-file --filters --path=start_windows.bat` on it; in scratch repos under `*.bat -text` `od -c` showed `a \n b \n`, and under `text eol=crlf` it showed `a \r \n b \r \n`, from the repo root and a subdirectory, in `sh`; in this repo it shows `a \n b \n`. Both comments now give only the checkout reason and drop `git archive`, since this command does not show it.
- 2026-11-05: T5 done: `not_crlf` replaces `line_counts` and gives the loop's and the built-in check's verdict; it also counts CR bytes and names an unreadable blob or count. /bin/bash 3.2: repo exit 0; fixtures `610d0a620a630d`, `610a620d`, `610d0a620a630d0a` fail as LF-only lines, `610d0a620d` and `610d620d0a` fail as a CR with no LF after, `610d0a62` passes (text after the last LF is not checked, as the comment says); an unmerged `stop_windows.bat` fails as "cannot be read". Plants, each exit 1 on its own built-in case: no appended x on `a\r\nb\nc\r`, no CR-byte test on `a\r\nb\r`, a `tr` that prints nothing on the good case as unreadable counts. shellcheck 0.11.0 `-x -S info` clean.
- 2026-11-05: implement done after review return 1: all tasks checked; status → review.

## Decisions

## Review

- AC1 evidence (2026-11-05, fresh clone of the branch at 9c1d6ae): staged `fixture1.bat` (blob `610d0a620a630d`), `fixture2.bat` (`610a620d`), and `fixture3.bat` (`610d0a620a630d0a`) one at a time; the guard exited 1 on each with `FAIL: fixtureN.bat — blob has 1 LF-only line(s) of 2/1/3; expected all CRLF`; on the clean clone it exited 0 over the 2 tracked `.bat` blobs (`start_windows.bat`, `stop_windows.bat`). Pass.
- AC2 evidence (2026-11-05, read at 9c1d6ae): `.gitattributes` lines 3–10 and the guard's header lines 3–13 say no conversion happens because `-text` turns it off, never that `git archive` applies none in general; `git grep -i -E 'no (eol|line-ending) conversion|applies no|verbatim|Download ZIP'` over both files finds nothing. The one reason for `-text` names two delivery paths, a checkout and `git archive`, and two `cmp` commands; run in the fresh clone, both printed nothing and exited 0. Pass.
- gate: cairn_validate all checks passed (exit 0); no DESIGN principle changed, so cairn_impact skipped.
- gate (docker-image slot): `git diff main...HEAD -- Dockerfile scripts .dockerignore` touches only `scripts/tests/`, which `.dockerignore` drops, and `.gitattributes` is dropped too, so the build input equals main's; hadolint is not installed locally, and `pr-ci.yml` (triggered by `scripts/**`) builds the image and runs hadolint on the PR, which the merge wait requires green. Base image still `rocker/r2u:${UBUNTU_VERSION}`; no secrets touched; `.dockerignore` present. Changelog none: no user-visible change. A merge to main touches `scripts/**`, so `docker.yml` starts a publish.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: the `.gitattributes` commands print nothing for any CRLF blob under either attribute (a CRLF blob committed before `*.bat text eol=crlf` gives the same result), so they show the written bytes match the blob, not that `-text` turns conversion off, which the comment says they show — fix now; AC2 fails as written, review return 1.
- diff-bug #2: an empty or non-numeric count makes `[ -eq ]` return 2, so the built-in check and the loop pass silently (a `tr` that prints nothing gives PASS, exit 0) — fix now: fail closed on an unreadable count.
- diff-bug #3: the `line_counts` comment says equal counts mean every line is CRLF, but `a\r\nb\r` and `a\r\nb` pass — fix now with blame-history #1.
- diff-bug #4: the `.gitattributes` commands need bash or zsh (process substitution) and the repo root — fix now: say so in the comment.
- diff-bug #5: `git check-attr` still shows `eol: lf` for `*.bat` from `* text=auto eol=lf`, which may confuse a reader — reject: false; `eol` has no effect while `text` is unset, and the reviewer's own runs found the bytes unchanged.
- diff-bug #6: a failed `git cat-file` (an unmerged `.bat`) yields "0 0" and the FAIL line says "no line breaks at all" — fix now: name an unreadable blob as such; it already failed closed.
- diff-bug #7: the built-in check asserts only that the counts differ, so a broken count such as "0 5" passes it, and no good input is checked — fix now: assert a bad and a good input through the same verdict the loop uses.
- diff-bug #8: `launchers.yml` lines 6–7 say the guard keeps "the README-recommended ZIP download" working, a path the rewritten comments no longer claim — follow-up: new parked row "Show why .bat files use -text" (no run backs either reading; promote when a user reports a launcher with LF line endings).
- diff-bug #9: no added test that the test-scope rules exclude — noted, no finding.
- blame-history #1: with the appended x, `a\r\nb\r` (last line ends in a CR with no LF) now passes, where main's count failed it — fix now: also count CR bytes, so a CR with no LF after it fails.
- blame-history #2: the reason for `-text` over `text eol=crlf` is gone and no record states one; the one path where they differ, a raw blob download, was dropped unrun — follow-up: row "Show why .bat files use -text".
- blame-history #3: README line 30's Download ZIP path is not named in the `-text` reason, and GitHub's ZIP was not run — follow-up: row "Show why .bat files use -text".
- blame-history #4: the guard header drops "exactly the bytes `git archive` ships" — reject: planned change; T3 moved that claim to `.gitattributes` beside the commands that show it.
- blame-history #5: `*.cmd -text` has no guard — reject: planned change; Scope Out excludes a `*.cmd` guard (none tracked).
- blame-history #6: the `.gitattributes` commands name `start_windows.bat` and go stale on a rename — reject: edge; only renaming the launcher reaches it, outside both documented and common use, and its effect is a `cmp` error.
- prior-review: archived M08 record and LESSONS read; no regression of a past review point; PR comment probe returned no threads — no findings.
- ripple: no ripple evidence; it noted `launchers.yml` lines 6–7, settled as diff-bug #8.
- pass 2 (after review return 1, head 750dd30):
- AC1 evidence (pass 2, fresh clone at 750dd30): `fixture1.bat` (`610d0a620a630d`), `fixture2.bat` (`610a620d`), `fixture3.bat` (`610d0a620a630d0a`) each staged alone; the guard exited 1 on each with `FAIL: fixtureN.bat — blob has 1 LF-only line(s) of 2/1/3; expected all CRLF`; exit 0 on the clean clone's 2 tracked `.bat` blobs. Pass.
- AC2 evidence (pass 2, read at 750dd30): neither file mentions `git archive` (`git grep -i archive` finds nothing); the one "no line-ending conversion" hit (guard line 7) ties it to `-text` on a checkout. The one reason for `-text` names a checkout and a `git cat-file --filters --path=start_windows.bat` command, which printed `a \n b \n` in the clone and, per T4's scratch runs, `a \r \n b \r \n` under `text eol=crlf`, so its output shows the conversion is off. Pass.
- gate (pass 2): cairn_validate all checks passed; no principle changed. docker-image slot unchanged from pass 1: the diff touches `.gitattributes`, `scripts/tests/`, and `cairn/` only, all dropped by `.dockerignore`; hadolint and the build run in `pr-ci.yml` on the PR; base image pinned by tag; no secrets; changelog none.
- spawned: diff-bug, blame-history, prior-review, ripple
