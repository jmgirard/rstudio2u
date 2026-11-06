# M031: Fix the CRLF guard's miss and comment

- **Status:** in-progress
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

- AC1 → T1, T2, T5, T7
- AC2 → T3, T4, T6

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
- [x] T6: (review return 2) Give the commit side as the reason for `-text`
      in both comments, with the `git hash-object --path` command whose output
      shows CRLF kept under `-text` and LF under any `text` setting; drop the
      checkout claim that command does not show.
- [x] T7: (review return 2, fix-now) Run the guard's counts under
      `LC_ALL=C`; correct the "not checked" comment and the `.gitattributes`
      summary of what the guard checks.

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
- 2026-11-05: review pass 2: AC2 fails a second time by the same shape (diff-bug #1, pass 2), the repeated review-failure stop (thrash rule (b)); the plan recorded no alternative for AC2; posed to the user with a tested commit-side command as the recommended repair.
- 2026-11-05: user chose "Commit-side command" at the stop.
- 2026-11-05: review return 2: AC2 — the `.gitattributes` command prints the same output under `-text`, `text`, and `text eol=lf`, so it does not show that `-text` is what keeps the blob CRLF (diff-bug #1, pass 2); repair by the user's choice: show the commit side. The same return carries pass 2's fix-now items: diff-bug #2 (`LC_ALL=C`), diff-bug #4 / blame-history #2 (the "not checked" comment), ripple #3 (the `.gitattributes` summary).
- 2026-11-05: minor amendment: added T6 (return 2's AC2 failure) and T7 (its fix-now items); Coverage now AC1 → T1, T2, T5, T7 and AC2 → T3, T4, T6.
- 2026-11-05: T6 done: both comments now give the commit side as the reason for `-text` and drop the checkout claim; the `.gitattributes` command, run as written in scratch repos, printed `od -c` output `a \r \n b \r \n` under `*.bat -text` and `a \n b \n` under `text`, `text eol=crlf`, and `text eol=lf`; in this repo it prints the `-text` form.
- 2026-11-05: T7 done: `export LC_ALL=C` after `set`; under `LANG=en_US.UTF-8` a CRLF-only `cp.bat` holding byte `e9` passes, and a copy without the line fails it as "1 LF-only line(s) of 3" with `tr: Illegal byte sequence`; the `not_crlf` comment now says text after the last LF is checked only for CR bytes, and `a\r\nb` passes while `a\r\nb\r` fails as "1 CR byte(s) with no LF after"; AC1 fixtures still fail with their LF-only lines; repo exit 0; shellcheck clean.
- 2026-11-05: implement done after review return 2: all tasks checked; status → review.
- 2026-11-05: review pass 3: AC2 fails a third time (diff-bug #1, pass 3: `git add` is not a delivery path, and no path tested here separates `-text` from `text eol=crlf`); thrash rule (a) third return and (b) same criterion by the same shape both fire; the plan recorded no AC2 alternative; posed descope-or-park to the user, with escalation offered.
- 2026-11-05: user chose "Narrow the criterion" at the stop.
- 2026-11-05: review return 3: AC2 — its "names a delivery path" clause fails (diff-bug #1, pass 3); by the user's choice, narrowed by amendment, not retried. The same return carries pass 3's fix-now items: diff-bug #2, #5, #7 (shell part), #9, #10, and blame-history #7.
- 2026-11-05: amendment routed: AC2 — no delivery path tested in this repo separates `-text` from `text eol=crlf`, so the clause asking a reason to name one cannot be met; narrow to claims a command shows.
- 2026-11-05: checkpoint, half done: pass 3 fix-now edits made (`.gitattributes` command wording and Git Bash note, "each *.bat blob", guard header "a blob stored at that path", the corrected row "Show why .bat files use -text", new parked row "Fail launcher blobs that hold NUL bytes"); command still prints `a \r \n b \r \n`, guard passes, shellcheck clean; the AC2 amendment waits on its fresh re-audit reader, and no task box is ticked yet.

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
- diff-bug #1 (pass 2): the `.gitattributes` command prints `a \n b \n` under `*.bat text`, `text eol=lf`, and no `*.bat` line, the same as under `-text`, so it separates `-text` only from `text eol=crlf`; what `-text` changes is the commit side (a CRLF file keeps CR in the blob) — AC2 fails a second time by the same shape (a command that cannot tell `-text` apart); stop for the user. A commit-side command, `printf 'a\r\nb\r\n' | git hash-object -w --stdin --path=start_windows.bat | xargs git cat-file -p | xxd -p`, printed `610d0a620d0a` under `-text` and `610a620a` under `text`, `text eol=crlf`, `text eol=lf`, and no `*.bat` line, from the root and a subdirectory.
- diff-bug #2 (pass 2): in a UTF-8 locale on macOS a CRLF-only blob with one non-UTF-8 byte fails as an LF-only line, and `tr` prints "Illegal byte sequence"; the grep miss is on main, the `tr` miscount is new — fix now: `export LC_ALL=C`.
- diff-bug #3 (pass 2): a lone CR inside a line (`a\rb\r\n`) now fails though cmd.exe drops CR bytes — reject: planned change; T5 calls for failing a CR with no LF after it, and no tracked launcher holds one.
- diff-bug #4 (pass 2): "Text after the last LF is not checked" contradicts the CR rule, since `a\r\nb\r` fails — fix now: say that text after the last LF is checked only for CR bytes.
- diff-bug #5 (pass 2): only the first of the four producer runs has its exit status checked, so a read that changes between runs (a concurrent `git add`) can give a wrong count in the message — reject: edge; only an index change during the run reaches it, and the guard still fails.
- diff-bug #6 (pass 2): an unmerged `.bat` is listed once per stage, giving three "cannot be read" lines — reject: edge; only a merge conflict in a launcher during the run reaches it, and the run fails as it should.
- diff-bug #7 (pass 2): "of N" counts LF-ended lines, not every line — reject: style.
- diff-bug #8 (pass 2): the command writes an object into the reader's repo — reject: false; the comment says "It stores an LF-only blob".
- diff-bug #9 (pass 2): the built-in check never runs the read-failure or numeric branch — reject: false as a gap; T5's runs fired both (an unmerged `stop_windows.bat`, a `tr` that prints nothing), and the built-in check is scoped to the count.
- diff-bug #10 (pass 2): the good case is the one built-in case a test-scope rule might exclude — reject: false; it is the only case that fails before the loop when `grep` never matches `\r$`, which the reviewer confirmed.
- diff-bug #11, #12 (pass 2): `launchers.yml` lines 6–7 and the missing reason for `-text` over `text eol=crlf` — follow-up: row "Show why .bat files use -text" already holds both.
- blame-history #1 (pass 2): the reason for `-text` over `text eol=crlf` is gone and no record states one — follow-up: row "Show why .bat files use -text".
- blame-history #2 (pass 2): the "not checked" comment contradicts the CR count — fix now, same as diff-bug #4.
- blame-history #3 (pass 2): `a\rb\r\n`, `a\r\r\n`, and `a\r\nb\rc` changed from pass to fail — reject: planned change (T5), as diff-bug #3.
- blame-history #4 (pass 2): `a\nb\r` changed from pass to fail, fixing main's miss — noted, no finding (AC1 fixture 2).
- blame-history #5 (pass 2): `a\r` reads "has no line breaks at all" though it holds a CR — reject: style.
- blame-history #6 (pass 2): the command writes a loose object — reject: false, as diff-bug #8.
- prior-review #1 (pass 2): M08's archived ZIP claim is the one this branch corrects — noted, no finding.
- prior-review #2 (pass 2): T5's work-log line gives the plants' exit codes without their `FAIL:` lines — reject: false; the plant run printed `FAIL: built-in check: not_crlf judges 'a\r\nb\nc\r' wrongly (no reason given)`, the same for `'a\r\nb\r'`, and for `'a\r\nb\r\n'` with `(gave unreadable counts '' '2' '')`, each naming its own case.
- ripple #1, #2 (pass 2): `launchers.yml` lines 6–7 and README line 30 still rest on the ZIP path — follow-up: row "Show why .bat files use -text".
- ripple #3 (pass 2): `.gitattributes` says the guard "checks that each blob is CRLF", broader than the check — fix now: say that it checks every line break in each blob.
- pass 3 (after review return 2, head 7ffde3c); pass 2 fix-now lines: diff-bug #2, fixed 7ffde3c; diff-bug #4 and blame-history #2, fixed 7ffde3c; ripple #3, fixed 7ffde3c; pass 1 fix-now lines: diff-bug #2, #3, #4, #6, #7 and blame-history #1, fixed 750dd30 (#4's shell note superseded by c6c183d's single `sh` command); diff-bug #1 (pass 1), fixed c6c183d; diff-bug #1 (pass 2), fixed 24ab7e5.
- AC1 evidence (pass 3, fresh clone at 7ffde3c): `fixture1.bat` (`610d0a620a630d`), `fixture2.bat` (`610a620d`), `fixture3.bat` (`610d0a620a630d0a`) each staged alone; exit 1 on each with `FAIL: fixtureN.bat — blob has 1 LF-only line(s) of 2/1/3; expected all CRLF`; exit 0 on the clean clone's 2 tracked `.bat` blobs. Pass.
- AC2 evidence (pass 3, read at 7ffde3c): neither file mentions `git archive` (`git grep -i archive` exit 1). The one reason for `-text` names the commit path (`git add`) and the `git hash-object --path=start_windows.bat` command; in the clone its `od -c` output was `a \r \n b \r \n`, and T6's scratch runs gave `a \n b \n` under `text`, `text eol=crlf`, and `text eol=lf`, so its output shows the reason. Pass.
- gate (pass 3): cairn_validate all checks passed; no principle changed; docker-image slot as in pass 2 (diff limited to `.gitattributes`, `scripts/tests/`, `cairn/`, all outside the build context).
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1 (pass 3): the one reason for `-text` names `git add`, which puts bytes into the blob, not a path by which they reach a user; under `text eol=crlf` the reviewer measured an LF blob but CRLF from both a checkout and `git archive` — AC2's "names a delivery path" fails a third time; thrash stop.
- diff-bug #2 (pass 3): "It stores CRLF bytes as a commit of start_windows.bat would" is false when the `*.bat` line is removed and the index already holds CRLF, since `text=auto` then keeps CRLF on `git add` — fix now: say it applies the conversion `git add` applies to a new file at that path.
- diff-bug #3, #4 (pass 3): a CR right before a NUL byte (`a\r\0b\n`) passes on BSD and GNU, and `a\r\0b\r\n` reads "-1 LF-only line(s)" on GNU; grep's NUL handling, which the branch does not change — follow-up: new parked row "Fail launcher blobs that hold NUL bytes".
- diff-bug #5 (pass 3): the parked row "Show why .bat files use -text" still says the comment names a checkout and `git archive` — fix now: rewrite the row's detail.
- diff-bug #6 (pass 3): the built-in check does not cover the zero-LF branch, the read check, the number check, or `LC_ALL=C` — reject: false as a gap; T5 and T7 runs showed the read check, the number check, and the locale line red when broken, the comment claims no more, and the zero-LF branch is main's.
- diff-bug #7 (pass 3): with `core.safecrlf=true` the command fails under `text` instead of printing a blob, and it needs a POSIX shell — `core.safecrlf=true` part: reject: edge (a non-default setting; the effect is an error message); shell part: fix now: name Git Bash for Windows readers.
- diff-bug #8 (pass 3): an unmerged `.bat` gives three FAIL lines — reject: edge, as pass 2 diff-bug #6.
- diff-bug #9 (pass 3): "checks every line break in each blob" sits above `*.cmd -text` too, but the guard reads only `*.bat` — fix now: say each `*.bat` blob.
- diff-bug #10 (pass 3): "a command that shows the blob keeping CRLF" reads as if it inspects the tracked launcher — fix now: say it shows git keeping CRLF in a blob stored at that path.
- diff-bug #11 (pass 3): the good built-in case is a test-scope judgment call — reject: false, as pass 2 diff-bug #10.
- blame-history #1, #2 (pass 3): the refuted M08 reason for `-text` has no replacement record, and `launchers.yml` lines 6–7 rest on it — follow-up: row "Show why .bat files use -text".
- blame-history #3 (pass 3): `a\r\r\n`, `a\rb\r\n`, `a\r\nb\rc`, `a\r\r\r\n` changed from pass to fail — reject: planned change (T5).
- blame-history #4–#6 (pass 3): the AC1 fixtures and `a\n\r` now fail, `a\xe9\r\n` passes in a UTF-8 locale, and three shapes keep their verdict with a new message — noted, no finding.
- blame-history #7 (pass 3): the parked row lists the ZIP path as a place the settings differ, but a local `git archive` writes CRLF under both — fix now with diff-bug #5: name only GitHub's server-side ZIP as untested.
- prior-review #1 (pass 3): `launchers.yml` lines 6–7 — follow-up: row "Show why .bat files use -text".
- ripple #1, #2 (pass 3): `launchers.yml` lines 6–7 and README line 30 — follow-up: row "Show why .bat files use -text"; its note on the row's stale detail is diff-bug #5.
