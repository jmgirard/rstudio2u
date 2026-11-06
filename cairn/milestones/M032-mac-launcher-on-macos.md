# M032: Run the Mac launcher on a macOS runner

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Surface tier:** user-facing — it guards the macOS launcher that students double-click, and any failure it finds is fixed in that launcher
- **Branch/PR:** m032-mac-launcher-on-macos, https://github.com/jmgirard/rstudio2u/pull/50

## Goal

Run `start_mac.command`'s scenario harness on a real macOS runner under the `/bin/bash` that a student's Mac uses.

## Scope

**In:** `scripts/tests/posix/run_launcher_scenarios.sh` runs `start_mac.command` under `/bin/bash` (the interpreter its first line names), runs each launcher from a working directory other than the launcher's folder (as a Finder double-click does), and can be limited to named launchers; a new `launchers.yml` job runs it on `macos-latest` for `start_mac.command`; the comments that say where the launchers run; fixing any `start_mac.command` or harness failure the new job shows.

**Out:** running `start_mac.command` against a real Docker engine on macOS: hosted macOS runners ship none, and `launcher-compose` covers Compose's behavior on Linux. The `open` browser call: the test seam skips it on every platform. `start_linux.sh` on macOS: no student runs it there.

## Acceptance criteria

- [x] AC1: `.github/workflows/launchers.yml` has a job that runs on `macos-latest` and runs `scripts/tests/posix/run_launcher_scenarios.sh` for `start_mac.command` with the launcher's interpreter set to `/bin/bash`, and a step in that job prints `/bin/bash --version` reporting version 3.2. A pull-request run of that job on the milestone PR's head passes.
- [x] AC2: In that same passing run, the set of `ok: start_mac.command/<scenario>` lines in the macOS job's log equals the set of `ok: start_mac.command/<scenario>` lines in the `posix-scenarios` job's log.
- [x] AC3: The `posix-scenarios` job in that run passes, and the set of its `ok:` lines equals the set printed by a local run of the harness from an export of commit `ee1b9cc`, plus any scenario this milestone adds, each named in the work log.
- [x] AC4: On draft PRs into `main` whose heads are branches off the milestone branch, one planted defect each, each of these three defects turns the macOS job red with a `FAIL: start_mac.command/` line, while the same run's `posix-scenarios` job passes: (a) `local plant=X` then `plant=${plant,,}` as the first lines of `launcher_interactive` in `launcher_common.sh`; (b) `launcher_interactive`'s body replaced by `declare -A modes=([batch]=no [user]=yes)`, a lookup keyed `batch` under the test seam and `user` otherwise, and a comparison of the result with `yes` as the function's return value; (c) `dirname -z` in place of `dirname` in `start_mac.command`'s first `cd` line.
- [x] AC5: The header comments of `scripts/tests/posix/run_launcher_scenarios.sh` (today lines 19–21 and 30) and of `.github/workflows/launchers.yml` say that `start_mac.command` also runs on a macOS runner under `/bin/bash`.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T4
- AC4 → T3
- AC5 → T1, T2

## Tasks

- [x] T1: Harness (`scripts/tests/posix/run_launcher_scenarios.sh`): run `start_mac.command` under `/bin/bash` on every platform, in place of `command -v bash` (line 127); run each launcher from a working directory other than the sandbox (for example `cd "$work" && "$bash" "$sandbox/$launcher"`), keeping the stub's `.env` read correct; accept optional launcher names to run (default both); on macOS link `/usr/bin/dirname` and `xattr` into the clean dir; update the header comment (lines 19–21, 30). Run it locally under `/bin/bash` 3.2 and note any scenario added.
- [x] T2: `launchers.yml`: add a `macos-scenarios` job on `macos-latest` that prints `/bin/bash --version` and runs the harness for `start_mac.command`; update the header comment. Fix any failure the job shows.
- [x] T3: Planted-defect probes for AC4 (a), (b), (c): one draft PR into `main` per plant, each from a branch off the milestone branch; read the failed step and the `FAIL:` line from `gh run view --json jobs` and the job log; confirm `posix-scenarios` passed in the same run; close each with `gh pr close --delete-branch`. Show (a) and (b) red locally under `/bin/bash` first.
- [x] T4: Run the harness from an export of `ee1b9cc` (`git archive`, HEAD untouched) and record its `ok:` set for AC3.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: gap — the harness runs launchers with the first `bash` on PATH, which a hosted macOS runner can resolve to a newer Homebrew bash than a student's `/bin/bash` 3.2; reading taken: run `start_mac.command` under `/bin/bash`, the interpreter its first line names. gap — the harness starts each launcher in its own folder, so a broken `cd "$(dirname "$0")"` goes unseen; reading taken: start it from another folder, as a Finder double-click does. No flaw.
- 2026-11-05: question set: work to plan — "Run start_mac.command on a macOS runner" candidate row.
- 2026-11-05: question set: may the work open throwaway draft PRs or temporary branches, one planted defect each, and delete them after — yes, and delete after.
- 2026-11-05: collision check: the candidate row "Run start_mac.command on a macOS runner" absorbed in full (deferred from M09); no D-entry or archived milestone overlaps. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: probe: the harness on this Mac under `/bin/bash` 3.2.57 passed every scenario of both launchers, so the new job guards against regressions and no failing scenario is known.
- 2026-11-05: lessons used: 2026-11-05 (M027) draft PRs off the milestone branch to see a changed workflow fail; 2026-11-05 (M024) a plant counts as red only when its output names the expected `FAIL:` line; 2026-11-05 (M023) `launchers.yml` runs only on pull requests.
- 2026-11-05: criteria audit (full mode, fresh Opus reader) returned 6 findings, all fixed: AC4(c) passed silently because `cd ""` stays in the sandbox, fixed by running launchers from another folder and naming BSD `/usr/bin/dirname`; AC4(b) `declare -A` fails without stopping the function, fixed by making its status the return value; AC4 now names `launcher_interactive`, which every post-helper scenario reaches; AC4 trigger now says draft PRs into `main`; AC3 now compares to a local run of an `ee1b9cc` export plus added scenarios; AC1 now binds the job's interpreter setting and version step, not a log line. AC2 and AC5 had none.
- 2026-11-05: plan gate chose running `start_mac.command` under `/bin/bash` over the first `bash` on PATH because the runner can put a newer bash first; falsified by a Finder double-click that runs a `.command` under another bash.
- 2026-11-05: plan gate chose a separate macOS job over moving `posix-scenarios` to macOS because `start_linux.sh` belongs on Linux; falsified by a macOS job that cannot run the harness's stub setup.
- 2026-11-05: branch m032-mac-launcher-on-macos cut from main at dd70e70; status in-progress. The verify slot (hadolint, docker build) is owed only after Dockerfile or build-context changes, and this milestone makes none.
- 2026-11-05: T1 done: the harness reads each launcher's interpreter from its first line (`/bin/bash` for both), starts each launcher from `$work` by its absolute sandbox path, takes optional launcher names (an unknown name exits 1), and on macOS links `/usr/bin/dirname`, `/bin/chmod`, and `/usr/bin/xattr`. Chose reading the first line over a fixed `/bin/bash` so a changed first line is what the harness runs. Local run under `/bin/bash` 3.2.57: both launchers 56 `ok:`, `start_mac.command` alone 28 `ok:`, no scenario added.
- 2026-11-05: T4 done: `git archive ee1b9cc` export's harness run locally printed 56 `ok:` lines, the same sorted set as the changed harness (diff empty).
- 2026-11-05: local plants under `/bin/bash` 3.2.57 with `start_mac.command` alone: (a) `${plant,,}` in `launcher_interactive` gave 20 `FAIL: start_mac.command/` lines; (c) `dirname -z` in the first `cd` gave 56. (b) as AC4 words it passed all 28: under the seam the function must return nonzero, so returning declare's status 2 is the right answer, and bash 3.2 still creates the array as an indexed one. A `declare -A modes=([batch]=no [user]=yes)` lookup plant gave 1 FAIL (offline-fallback) under 3.2 and the right answers under bash 5 (docker `bash:5`). AC4(b) wording goes to re-audit.
- 2026-11-05: T2 done: `macos-scenarios` job on `macos-latest` prints `/bin/bash --version`, then runs the harness for `start_mac.command`; header comment updated. shellcheck 0.11.0 at `--severity=info` (container `koalaman/shellcheck:v0.11.0`) and actionlint (container) both clean. No job result yet: the PR runs come at T3 and review.
- 2026-11-05: re-audit: AC4 (full) — clause (b) as reworded ("two string keys … whose lookup decides") holds only for one key order, since bash 3.2 puts both keys at index 0 and the last one wins; suggested naming each plant's exact text. Agent adopted that.
- 2026-11-05: re-audit: AC4 (full) — clause (a) "a `${var,,}` expansion evaluated on every call" admits a form inside `$( )` that stays green on 3.2 (the error kills only the subshell); suggested pinning (a)'s text and saying (b)'s comparison with `yes` is the return value. Second line on AC4: further wording churn goes to the user.
- 2026-11-05: T3 probes: draft PRs #47 (a: `local plant=X; plant=${plant,,}` atop `launcher_interactive`), #48 (c: `dirname -z` in the first `cd`), #49 (b: `declare -A modes=([batch]=no [user]=yes)` lookup). macos-scenarios red in each: 18, 27, and 1 failed scenarios, each with `FAIL: start_mac.command/` lines (#49: offline-fallback); each job printed `GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)` and `start_mac.command runs under /bin/bash`; posix-scenarios passed in all three runs. #49 also tripped shellcheck SC2209 on the plant, unrelated to AC4. PRs still open pending the AC4 wording stop.
- 2026-11-05: substantive amendment: AC4 now names each plant's exact text, (a) `local plant=X` then `plant=${plant,,}`, (b) the `declare -A modes=([batch]=no [user]=yes)` body, (c) `dirname -z`, in place of loose descriptions that two readers showed could pass on bash 3.2; the deliverable is unchanged. User chose "Name exact defects" at the wording stop.
- 2026-11-05: T3 done: #47, #48, #49 closed; local and remote `m032-probe-*` branches and their worktrees deleted (`git ls-remote` lists none).
- 2026-11-05: added `timeout-minutes: 10` to `macos-scenarios`, because a regression that reaches a key wait with an open stdin would otherwise hold a macOS runner for the default 360 minutes (second AC4 reader's note); no other change.
- 2026-11-05: claim audit: 16 claims read, 3 corrected — .github/workflows/launchers.yml (the macOS job catches only tested-branch bash 4 or GNU-only dirname/chmod options), scripts/tests/posix/run_launcher_scenarios.sh (the clean dir's tool list; the stub's shebang reason)
- 2026-11-05: claim audit re-read by the same reader: the 3 corrected claims read true. All tasks done; harness local PASS under /bin/bash 3.2.57, shellcheck and actionlint clean; status review.
- 2026-11-05: step-7 approval: m032-mac-launcher-on-macos approved for merge (AC1–AC3 to be verified on the PR run before the merge)

## Decisions

## Review

- 2026-11-05 review pass 1 on branch head after 581891d; main at dd70e70, not moved (fetch: 0 commits behind). No PR yet (route d); Copilot round off (no header line).
- AC1, AC2, AC3: each names the run on the milestone PR's head, which exists only after step 8 opens the PR. Evidence lands at the merge CI wait, before `gh pr merge`; boxes stay unticked until then. Preliminary, not evidence: local harness under `/bin/bash` 3.2.57 passed 56/56 (both) and 28/28 (`start_mac.command`); the three probe runs' macOS jobs passed every scenario the plant did not break.
- AC4: probe runs 42155160672 (#47, head 976f10a), 42155259558 (#49, 19d0624), 42155164282 (#48, f813272), each a draft PR into main from a branch whose parent is 5f8fe9f on the milestone branch. `git show` of each: 976f10a adds `local plant=X` and `plant=${plant,,}` as the first lines of `launcher_interactive`; 19d0624 replaces its body with the `declare -A modes=([batch]=no [user]=yes)` lookup and `[ "${modes[$key]}" = yes ]`; f813272 changes the first `cd` to `dirname -z`. `gh run view`: macos-scenarios=failure, posix-scenarios=success in all three. Job logs: 20, 1, and 56 `FAIL: start_mac.command/` lines (18, 1, 27 failed scenarios). Code since 5f8fe9f differs only in comments and `timeout-minutes: 10` (`git diff 5f8fe9f HEAD` less comment lines). PASS.
- AC5: `run_launcher_scenarios.sh` header lines 17–19 and 33–35 and `launchers.yml` header lines 7–10 say `start_mac.command` runs on a macOS runner (macos-latest) under `/bin/bash`; read at the branch head. PASS.
- gate: cairn_validate all checks passed (exit 0); no DESIGN principle changed, so cairn_impact skipped.
- gate (docker-image slot): `git diff main...HEAD -- Dockerfile scripts .dockerignore` touches only `scripts/tests/posix/run_launcher_scenarios.sh`, and `.dockerignore` drops `scripts/tests` and `.github`, so the build input equals main's; `pr-ci.yml` (`scripts/**`, `.github/workflows/**`) builds the image and runs hadolint on the PR, which the merge wait requires green. Base image unchanged; no secrets touched; `.dockerignore` present. Changelog none: no user-visible change. actionlint (container) and shellcheck 0.11.0 `--severity=info` (container) clean.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: the `launchers.yml` comment says a GNU-only `chmod` option fails the job, but `start_mac.command` discards chmod's error and status (a `chmod --verbose` plant passed) — fix now: the comment now names dirname only and says chmod and xattr errors are discarded.
- diff-bug #2: on Linux an empty `command -v chmod` result vanished in the unquoted tool list, so the "missing required tool" exit could not fire — fix now: each tool is looked up and checked by name; a bash:5 container with no chmod now exits 1 with `missing required tool: chmod`.
- diff-bug #3: `launcher_interpreter` refuses `#!/usr/bin/env bash`, `#! /bin/bash`, and a first line with arguments — reject, edge: both launchers' first line is `#!/bin/bash`, so only a launcher rewritten to another first-line form reaches it, and the effect is a FAIL line, not a wrong pass; the function comment now says only the plain form is read.
- diff-bug #4: a bad first line turned into one FAIL per scenario (28 for one cause) — fix now: the loop checks the interpreter once, prints one FAIL naming the launcher and the CR case, and skips that launcher's scenarios; a CRLF first-line plant gave exactly that line and exit 1.
- diff-bug #5: the `/bin/bash --version` step prints the version and asserts nothing — reject, planned change: AC1 binds a step that prints the version, read at review, so the plan chose a print over a failing assertion that a runner-image change alone would turn red.
- diff-bug #6: `macos-latest` floats to new images and covers no Intel Mac — reject, planned change: the plan named `macos-latest`, the file's other jobs float the same way, and Intel's `/bin/bash` is also 3.2.
- diff-bug #7: running a launcher by a relative path (`./launcher`, dirname `.`) is no longer tested — reject, planned change: the plan starts launchers from another folder, as a Finder double-click does.
- diff-bug #8: `posix-scenarios`, `windows-scenarios`, and `line-endings` have no `timeout-minutes` — follow-up: parked row "Bound the other launcher jobs' time", promote when a launcher job runs past 10 minutes; pre-existing, outside the diff.
- prior-review #1: port precedence on macOS rests only on the stub, with no real-Compose job there — reject, planned change: Scope Out names it (hosted macOS runners ship no Docker engine).
- prior-review #2: the version step asserts nothing — reject, planned change: same as diff-bug #5.
- prior-review #3: the paths filter may not cover the harness — reject, false: `launchers.yml` lists `scripts/tests/posix/**`.
- prior-review #4: the "(none)" interpreter fallback has no plant — fix now: removed with diff-bug #4's fix; the CRLF plant exercises the new path.
- blame-history #1–#6: interpreter from the first line, start from `$work`, xattr linked on macOS, floating `macos-latest`, `open` still seam-skipped, default launcher set unchanged — reject, planned change: each is what the plan called for, and none undoes a past choice.
- ripple #1–#5: no line disagrees with the diff; it noted the source candidate row (graduates at hygiene), DESIGN.md GP3 and Known issues text and `launchers.yml` lines 3–4 (still true), and `run_launcher_scenarios.sh` line 7 (still true; its claim that `start_mac.command` runs only on macOS is false, as the Linux job runs both) — reject, false or not a disagreement.
- 2026-11-05 resume (route d, PR #50 open, approval recorded for this check-then-merge sequence): main not moved; PR head 52fb9b0 equals the pushed commit; no reviews; `gh pr checks 50`: 9 of 9 passed.
- AC1: `launchers.yml` job `macos-scenarios` has `runs-on: macos-latest`, a step running `/bin/bash --version`, and runs the harness with `start_mac.command`, whose interpreter the harness reads as `/bin/bash`. PR #50 run 42156769095 (event pull_request, head 52fb9b0), job 127692675929: conclusion pass; log `GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)`, `start_mac.command runs under /bin/bash`, `PASS: all launcher scenarios`. PASS.
- AC2: same run, sorted `ok: start_mac.command/` lines: macOS job 28, `posix-scenarios` job (127692675894) 28; `diff` empty. PASS.
- AC3: `posix-scenarios` passed; its 56 sorted `ok:` lines equal the 56 from the local run of the `git archive ee1b9cc` export (`diff` empty); no scenario added. PASS.
- after fixes: harness both 56 `ok:` (same sorted set as the ee1b9cc export), `start_mac.command` alone 28; shellcheck 0.11.0 `--severity=info` and actionlint clean.
