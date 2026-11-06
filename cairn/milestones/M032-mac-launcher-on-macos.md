# M032: Run the Mac launcher on a macOS runner

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Surface tier:** user-facing — it guards the macOS launcher that students double-click, and any failure it finds is fixed in that launcher
- **Branch/PR:** m032-mac-launcher-on-macos

## Goal

Run `start_mac.command`'s scenario harness on a real macOS runner under the `/bin/bash` that a student's Mac uses.

## Scope

**In:** `scripts/tests/posix/run_launcher_scenarios.sh` runs `start_mac.command` under `/bin/bash` (the interpreter its first line names), runs each launcher from a working directory other than the launcher's folder (as a Finder double-click does), and can be limited to named launchers; a new `launchers.yml` job runs it on `macos-latest` for `start_mac.command`; the comments that say where the launchers run; fixing any `start_mac.command` or harness failure the new job shows.

**Out:** running `start_mac.command` against a real Docker engine on macOS: hosted macOS runners ship none, and `launcher-compose` covers Compose's behavior on Linux. The `open` browser call: the test seam skips it on every platform. `start_linux.sh` on macOS: no student runs it there.

## Acceptance criteria

- [ ] AC1: `.github/workflows/launchers.yml` has a job that runs on `macos-latest` and runs `scripts/tests/posix/run_launcher_scenarios.sh` for `start_mac.command` with the launcher's interpreter set to `/bin/bash`, and a step in that job prints `/bin/bash --version` reporting version 3.2. A pull-request run of that job on the milestone PR's head passes.
- [ ] AC2: In that same passing run, the set of `ok: start_mac.command/<scenario>` lines in the macOS job's log equals the set of `ok: start_mac.command/<scenario>` lines in the `posix-scenarios` job's log.
- [ ] AC3: The `posix-scenarios` job in that run passes, and the set of its `ok:` lines equals the set printed by a local run of the harness from an export of commit `ee1b9cc`, plus any scenario this milestone adds, each named in the work log.
- [ ] AC4: On draft PRs into `main` whose heads are branches off the milestone branch, one planted defect each, each of these three defects turns the macOS job red with a `FAIL: start_mac.command/` line, while the same run's `posix-scenarios` job passes: (a) `local plant=X` then `plant=${plant,,}` as the first lines of `launcher_interactive` in `launcher_common.sh`; (b) `launcher_interactive`'s body replaced by `declare -A modes=([batch]=no [user]=yes)`, a lookup keyed `batch` under the test seam and `user` otherwise, and a comparison of the result with `yes` as the function's return value; (c) `dirname -z` in place of `dirname` in `start_mac.command`'s first `cd` line.
- [ ] AC5: The header comments of `scripts/tests/posix/run_launcher_scenarios.sh` (today lines 19–21 and 30) and of `.github/workflows/launchers.yml` say that `start_mac.command` also runs on a macOS runner under `/bin/bash`.

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

## Decisions

## Review
