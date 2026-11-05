# M023: Re-print the offline warning at the end

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP3
- **Resolves:** —
- **Surface tier:** user-facing — it changes what students see in all three launchers
- **Branch/PR:** m023-reprint-offline-warning

## Goal

A student whose launcher skipped the image update can still read that fact after the server is ready.

## Scope

**In:** On a start where the pull failed and a copy was started, all three start
launchers repeat a short reminder after the running banner, open the browser, say
that RStudio keeps running after the window closes, and wait for a key press. The
harnesses gain order and count checks and a seam marker for the pause. The README
FAQ describes the new behavior.

**Out:**
- Running `start_mac.command` on real macOS → the candidate row "Run start_mac.command on a macOS runner".
- Running the launchers against a real Compose → the candidate row "Verify the launcher port on real Compose".
- A hands-on run of the Windows key wait: the user chose tests and a code read at the question set, so the record states that no test ran it.
- A changelog file: the `changelog` slot is none, so the archive summary states the user-visible change for the next release's notes.

## Acceptance criteria

- [ ] AC1: On a start where `docker compose pull` fails, every image is on disk, and `docker compose up` succeeds, `start_mac.command`, `start_linux.sh`, and `start_windows.bat` each exit 0 and print a line containing `the update was skipped` both before and after the "RStudio Server is running" line. Evidence: the `offline-fallback` scenarios in `scripts/tests/posix/run_launcher_scenarios.sh` and `scripts/tests/windows/run_launcher_scenarios.ps1`, from the PR head's CI run. `start_mac.command` runs there under bash on Ubuntu, not on macOS.
- [x] AC2: On that same start, each launcher, after its browser step, prints a line containing `keeps running`, then waits for a key press as its last step before exit. Evidence: the `offline-fallback` scenarios show, in order, the second warning, that line, and the pause helper's seam marker, and a read of each launcher shows the browser step comes first. The real key wait is shown by a read on Windows, and no test runs it there.
- [x] AC3: On a start where the pull and `docker compose up` both succeed, each launcher prints no line containing `the update was skipped` or `keeps running` and does not wait for a key press, and `start_windows.bat` still ends with its 3-second timeout. Evidence: the harnesses' pull-succeeded guard, the `port-default` scenario forbidding the seam marker, and a read of `start_windows.bat`.
- [x] AC4: On a start where the pull fails, every image is on disk, and `docker compose up` fails, each launcher exits 1, prints its "did not become ready" error, and prints exactly one line containing `the update was skipped`. Evidence: a new `offline-health-timeout` scenario in both harnesses.
- [x] AC5: The `README.md` FAQ entry "How do I update to the latest version?" says that a launcher started without internet access repeats the warning once the server is ready and waits for a key press before its window closes, and that RStudio keeps running after that.

## Coverage

- AC1 → T1, T2, T3, T4
- AC2 → T1, T2, T3, T4
- AC3 → T1, T2, T3, T4
- AC4 → T1, T4
- AC5 → T5

## Tasks

- [x] T1: In both harnesses, add an order check (first occurrence before the running line, last occurrence after it), a count check, and the new assertions: `offline-fallback` order, the `keeps running` line, and the seam marker; `port-default` forbids the marker; the pull-succeeded guard also forbids `keeps running` (not the marker, because `health-timeout` prints it); a new `offline-health-timeout` scenario with `STUB_PULL_FAIL=1 STUB_UP_FAIL=1`. See them fail first.
- [x] T2: In `launcher_common.sh`, add the reminder and the `keeps running` line, and make `launcher_pause`'s seam branch print a marker. In `start_mac.command` and `start_linux.sh`, record that the update was skipped, print the reminder after the banner, run the browser step, print the `keeps running` line, then `launcher_pause; exit 0`, because `read` at end of input returns 1. Reminder text: "Reminder: the update was skipped, so this is the copy already on this computer. To get the latest version, connect to the internet and run this again later." Line text: "RStudio keeps running after you close this window."
- [x] T3: In `start_windows.bat`, make the same change with the same words. Replace the `goto :done` at line 128 with a guard around the browser lines only, so the seam flow reaches the offline block. Make `:wait`'s seam branch print the marker. On the skipped path call `:wait` in place of the 3-second timeout, and keep the timeout on a normal start. Keep CRLF.
- [x] T4: Plant defects on all three launchers and see the harness fail: both warnings before the banner, both after it, only one warning; two warnings on the `up`-fails branch; the pause removed on the offline path; the pause made unconditional. Run `shellcheck` at the repo's floor and `scripts/tests/test_launcher_line_endings.sh`. On this Mac, run `start_mac.command` without the seam under a pseudo-terminal, with stub `docker` and `open`, and confirm that it waits for a key and then exits 0. Write one work-log line with the results.
- [x] T5: Update the README FAQ entry at `README.md:212-216`.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — a small change to running launcher code that is not a bug.
- 2026-11-05: idea vet: gap — a double-clicked Windows launcher closes about 3 seconds after the banner, so a re-print alone can go unread; reading taken: repeat and hold the window on the skipped-update path on all three launchers, confirmed at the question set. gap — repeating "Starting the copy already on this computer instead" after the server is up would be false; reading taken: the second message is a shorter reminder holding the same anchor text.
- 2026-11-05: lessons used: none.
- 2026-11-05: collision check: absorbed the candidate row "Re-print the offline warning at the end"; M10 shipped the first warning and its review filed the row; no D-entry heading bears on launchers; inbox sweep found 0 open issues and 0 open PRs.
- 2026-11-05: plan gate chose repeat and hold over repeat only because a re-print in a window that closes after about 3 seconds can go unread; falsified by reports that the key wait confuses students or that they read it as needing the window open.
- 2026-11-05: plan chose a seam marker over driving the launchers without the seam in the harness because `start` and `timeout` in the batch file cannot run unattended in CI; falsified by the marker printing on a path whose real wait does not happen.
- 2026-11-05: question set: a real Windows check before the merge — no, tests and a code read; the real key wait on Windows is not run.
- 2026-11-05: question set: start the build right after the plan — yes, asked on 2026-11-04 and not withdrawn at the rerun.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): nine findings, all fixed in the wording or the tasks: seam blind to the pause (marker, T1-T3), `goto :done` skips the offline block (T3), AC3 too broad (narrowed to pull and up succeeding), no order or count check (T1), warning text undefined and partly false after the banner (anchor text, reminder), POSIX exit status becomes `read`'s (T2), macOS and the real key wait are not executed (stated in AC1, AC2, and T4's local probe), AC6 only promised CI status (deleted, with CI named in AC1), new checks need planted defects (T4).
- 2026-11-05: T1: both harnesses gained order and count checks and the new assertions; the POSIX run fails `offline-fallback` on both launchers for the missing second warning, `keeps running`, and marker; `offline-health-timeout` already passes because it pins behavior the change leaves alone; the PowerShell edits have not run, because this Mac has no `pwsh` or `cmd`.
- 2026-11-05: T2: `launcher_remind_offline` and `launcher_hold_offline` added, and `launcher_pause` prints a marker under the seam; the POSIX harness passes on both launchers.
- 2026-11-05: T3: `start_windows.bat` carries the same words and flow, all 243 lines still CRLF in the working tree; it has not run, because this Mac has no `cmd`.
- 2026-11-05: T5: the README FAQ entry states the repeat, the key wait, and that RStudio keeps running.
- 2026-11-05: question set: push a temporary branch `m023-windows-probe` to run the Windows lane, planted Windows defects, and shell lint before the merge question, then delete it — yes; asked at a stop because this Mac has no `cmd`, `pwsh`, or `shellcheck` and these lanes run only on pull requests.
- 2026-11-05: T4: planted defects: POSIX 10 of 10 red on both launchers (local); Windows 11 of 11 red (run 41978769374 on the probe branch, head e45993d carrying T3's code), each for the expected scenario and reason; the same run's real Windows scenarios, POSIX scenarios, and line-endings guard passed; shellcheck at `-S info` passed (run 41978769304); probe branch deleted from GitHub and locally.
- 2026-11-05: T4: `start_mac.command` without the seam in a pseudo-terminal on this Mac: on a skipped update it shows the prompt, is alive after 3 s with no key, and exits 0 about 0.05 s after a key; with no terminal on stdin it exits 0; a normal start shows no prompt and exits 0 alone. No test runs the real key wait on Windows.
- 2026-11-05: implementation choice: the seam marker text is `[test seam] key wait skipped`, printed by `launcher_pause` and `:wait` on every path that reaches them; it prints only under `RS_LAUNCHER_NONINTERACTIVE`.
- 2026-11-05: the simple-english hook flagged 44 older hits across `README.md` on the T5 edit; left alone as outside this milestone's scope; the two added lines carry none of the flagged forms.
- 2026-11-05: claim audit: 55 claims read, 6 corrected — launcher_common.sh, start_windows.bat, scripts/tests/posix/run_launcher_scenarios.sh, scripts/tests/windows/run_launcher_scenarios.ps1
- 2026-11-05: claim audit finding on the row's premise: under a pseudo-terminal on this Mac with Compose 5.6.1, `up -d --wait` redraws in place for a net 4 rows, so the first warning does not scroll off a 24-row window; the reader read the byte stream, not a real window, and did not measure Windows or older Compose; the goal stands on the 3-second Windows close and the browser taking focus, and the comments no longer claim scrolling; to be stated at the merge question.
- 2026-11-05: the double-clicked window closing when a batch file ends (`start_windows.bat` comment) stays not checkable on this Mac; it is standard Windows behavior.

## Decisions

## Review

Evidence gathered 2026-11-05 at 21e3c0e, level with origin/main 9bfa381 as its base. POSIX harness: 56 scenarios, all ok, run on this Mac. Windows harness: run 41978769374 on the probe branch at T3's code; `git diff 163a01d HEAD` on `start_windows.bat` and the PowerShell harness changes only comment lines.

- AC1: POSIX `offline-fallback` passes on `start_mac.command` and `start_linux.sh`, exit 0, with the order warning, running line, warning, and a count of 2; Windows `offline-fallback` passed the same checks in run 41978769374. The criterion names the PR head's CI run, which does not exist before the approval, so the box stays open until that run passes (step 8).
- AC2: `offline-fallback` shows second warning, `keeps running`, then `[test seam] key wait skipped` in order on all three launchers (same runs). Read: browser step before the hold at `start_mac.command:85,89`, `start_linux.sh:79,84`, `start_windows.bat:142,151`. Real key wait: pseudo-terminal run on macOS (work log, T4); read only on Windows at `start_windows.bat:151` and `:wait`, no test runs it there.
- AC3: pull-succeeded guard passes on every POSIX scenario and in run 41978769374; `port-default` forbids the marker and passes on all three; `start_windows.bat:154` keeps `timeout /t 3` for a normal start.
- AC4: `offline-health-timeout` passes on all three, exit 1, `did not become ready`, count 1, no `keeps running` (same runs).
- AC5: `README.md:215-218` states the repeat, the key wait before the window closes, and that RStudio keeps running.
