# M024: Verify the launcher port on real Compose

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, IP2, IP4
- **Resolves:** —
- **Surface tier:** internal — a CI job and a test script over the launchers; no external consumer relies on them
- **Branch/PR:** m024-launcher-real-compose

## Goal

CI runs `start_linux.sh` against real Docker and Compose and fails when the port the launcher announces is not the port that answers.

## Scope

**In:**
- A new script, `scripts/tests/posix/run_launcher_real_compose.sh`, that runs the launcher from a temporary copy under its own Compose project and pulls the published image through the launcher's own `docker compose pull`.
- A job in `launchers.yml` that runs the script, with `docker-compose.yml` added to that workflow's `paths` filter. Today no pull-request lane runs on a change to that file.
- A weekly `launcher-compose` job in `docker.yml` that reports through the existing `ci-failure` issue, so a new Compose on the runner is seen with no launcher PR.
- A reworded comment at `launcher_common.sh:167`, a Known issues line in `DESIGN.md`, and updated headers in `launchers.yml` and the POSIX harness.

**Out:**
- `start_windows.bat` on real Compose: hosted Windows runners have no Linux containers. It lives in the new parked row "Run start_windows.bat on real Compose".
- `start_mac.command` on real macOS: it stays in the row "Run start_mac.command on a macOS runner". This script covers the logic that launcher shares through `launcher_common.sh`.
- Any launcher behavior change, and any change to what `docker compose port` falling back does. A defect the script finds goes to `/hotfix`.
- Replacing the stub harnesses. They still drive the failure branches that real Docker cannot produce on demand.

## Acceptance criteria

- [ ] AC1: `bash scripts/tests/posix/run_launcher_real_compose.sh` runs `start_linux.sh` from a temporary copy, against real Docker and Compose, in three scenarios: no `.env` and no `RS_PORT` (expected port 8787), a `.env` holding `RS_PORT=8888` (expected 8888), and that `.env` with `RS_PORT=8889` in the environment (expected 8889). In each scenario the launcher exits 0, its banner names `http://localhost:<expected>`, an HTTP request to that URL gets a response, and `docker compose port rstudio2u 8787` prints exactly `127.0.0.1:<expected>`.
- [ ] AC2: In the 8888 and 8889 scenarios of AC1, a request to port 8787 fails with curl exit code 7 (connection refused).
- [ ] AC3: The script compares `launcher_requested_port` with the published port in `docker compose config --format json` for these nine `.env` contents, and they agree, an empty reader result counting as 8787: `RS_PORT=8888`; `RS_PORT="8890"`; `RS_PORT='8891' # c`; `RS_PORT=8892 # c`; `export RS_PORT=8893`; `  RS_PORT = 8894`; `RS_PORT=1111` then `RS_PORT=8896` on the next line; `RS_PORT=`; `# RS_PORT=1111`.
- [ ] AC4: The script exits non-zero and names the failed check in each of these three cases: `launcher_url` returns a hardcoded `http://localhost:8787`; the mapping in `docker-compose.yml` binds `0.0.0.0` instead of `127.0.0.1`; `launcher_requested_port` stops removing an inline comment.
- [ ] AC5: After a run that exits 0 and after a run that fails on one AC4 case: a `rstudio2u_rstudio_home` volume created before the run still holds a sentinel file placed in it beforehand, a `.env` in the checkout that existed before the run is byte-identical, and `docker ps -a` and `docker volume ls`, each filtered on `label=com.docker.compose.project=<the script's project>`, print nothing.
- [ ] AC6: `launchers.yml` has a job on `ubuntu-latest` that runs the script, and its `paths` filter lists `docker-compose.yml`. That job and `lint.yml` pass on the milestone's PR head.
- [ ] AC7: `docker.yml` has a `launcher-compose` job whose `needs` includes `publish`, whose `if:` is true on `schedule` and `workflow_dispatch` whatever `publish`'s result and false on `push`, and whose steps run the script. `notify` lists the job in both `needs` and `RESULTS`, and the job passes in a test-mode dispatch of the milestone branch.

## Coverage

- AC1 → T1, T3
- AC2 → T1, T3
- AC3 → T2, T3
- AC4 → T1, T2, T3
- AC5 → T1, T3
- AC6 → T4, T7
- AC7 → T5, T7

## Tasks

- [x] T1: Write the script's sandbox, project name, cleanup trap, and the three boot scenarios. It copies `start_linux.sh`, `launcher_common.sh`, and `docker-compose.yml` to a temporary directory, sets `RS_LAUNCHER_NONINTERACTIVE=1` and a fixed `COMPOSE_PROJECT_NAME`, and removes only that project with `down -v`. It names each failed check.
- [x] T2: Add the nine-content `.env` table, read from `docker compose config --format json` with no container started.
- [x] T3: Run the script on this Mac (Docker 29.9.2, Compose 5.6.1). The first run pulls about 1 GB. Plant each AC4 defect in a temporary copy of the repo and see it red, and run the AC5 sentinel check after one green and one red run.
- [x] T4: Add the job to `launchers.yml`, add `docker-compose.yml` to its `paths`, and correct the workflow's header comment, which says the lane needs no Docker.
- [x] T5: Add the `launcher-compose` job to `docker.yml` with `if: always() && (github.event_name == 'schedule' || github.event_name == 'workflow_dispatch')`, add it to `notify`'s `needs` and `RESULTS`, and extend the comment there that explains why a needed job must never read `skipped`.
- [x] T6: Reword the comment at `launcher_common.sh:167` to what was observed: Compose 5.6.1 exits 1 with `no port 8787/tcp` when nothing is published, and the `:0` check stays for a Compose that exits 0. Point the POSIX harness header at the new script. Add a `DESIGN.md` Known issues line: the real-Compose check runs only `start_linux.sh`, only on amd64, and only on the runner's Compose version.
- [x] T7: Stop for the user's yes, then push the branch and run `gh workflow run docker.yml --ref <branch> -f test_mode=true`. This run builds every leg and attaches no tag. The question set did not cover it. `shellcheck`, `launchers.yml`, and `lint.yml` run only on a PR, so review sees AC6 on the PR head.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: gap, the row says to fold into the container smoke lane, but `pr-ci.yml`'s `paths` skip launcher files and `docker-compose.yml` and the launcher's own pull replaces a locally built image; reading taken: a `launchers.yml` job plus a weekly `docker.yml` job. gap, hosted Windows and macOS runners cannot run Linux containers; reading taken: `start_linux.sh` only, with the remainder in rows. gap, the check sees only the runner's Compose version, not what students run; reading taken: state it in DESIGN Known issues. No flaw found.
- 2026-11-05: lessons used: 2026-07-18 (M09) a stub resolving the same config as the code under test gives false coverage; 2026-07-18 (M09) ask `docker compose port` for the real binding; 2026-11-05 (M023) `launchers.yml` and `lint.yml` run only on pull requests and this Mac has no `shellcheck`.
- 2026-11-05: question set: what to work on — "Launcher port, real Compose". The set granted no permission; T7's test-mode dispatch is a stop.
- 2026-11-05: collision check: absorbed the candidate row "Verify the launcher port on real Compose"; M09 (done) deferred this work; no D-entry heading matched launchers or Compose; GitHub inboxes hold 0 issues and 0 PRs. Checker-regress shape does not apply: the launchers are shipped to users, and this adds a check rather than hardening one.
- 2026-11-05: local probe, Compose 5.6.1, scratch project: `launcher_requested_port` agreed with `docker compose config` on 12 of 12 `.env` shapes (10 values, one interpolation that the reader passes through, one both refuse); `docker compose port` printed `127.0.0.1:18787` with a mapping, and exited 1 with `no port 8787/tcp` with none, so the `:0` comment does not describe this version; `launcher_url` then fell back to 8787.
- 2026-11-05: plan gate chose a job in `launchers.yml` over folding into `pr-ci.yml` because that lane's `paths` skip the files under test and the launcher's pull replaces its built image; falsified by a launcher-relevant change that merges with this job not having run.
- 2026-11-05: plan gate chose the weekly `docker.yml` job through `notify` over a `schedule` trigger in `launchers.yml` because `ci-failure-issue.sh` closes on the next fully green `docker.yml` run and a second caller would close it wrongly; falsified by a green `docker.yml` run closing an issue the job should keep open.
- 2026-11-05: split: `start_windows.bat` on real Compose became a new parked row; `start_mac.command` stays in its existing row.
- 2026-11-05: no RB tripwire tag: the script asserts IP2 and IP4 and changes neither.
- 2026-11-05: criteria audit (reduced mode, fresh Opus reader): returned no finding on AC1, AC2, AC3, AC4, and AC6, two on AC5 (the phrase "a run" named no ending, and "same content" named no comparison), and one on AC7 (the claim over all runs had one dispatch as evidence). All three fixed by narrowing to the reader's wording, and AC7 also states the job's `if:` holds whatever `publish`'s result.
- 2026-11-05: no changelog entry and no release: nothing changes for users (D-005).
- 2026-11-05: T1: script written with the sandbox, the project `rstudio2u-real-compose-test`, the cleanup trap, and three boot scenarios; first run is T3. The profile's `verify` slot does not apply: no Dockerfile or build-context change (`scripts/tests` is in `.dockerignore`).
- 2026-11-05: T2: nine `.env` contents compared through `compare_env`; first run is T3.
- 2026-11-05: T3: on this Mac (Compose 5.6.1) the script passed 23 of 23 checks in 58 s. Planted in temporary copies, each run red and naming the check: hardcoded `launcher_url` (4 checks), `0.0.0.0` mapping (3), no inline-comment removal (1), and an extra 8787 mapping (3, including the refuse check). After the green run and all four red runs the marker file in `rstudio2u_rstudio_home` and the marker `.env` were intact and the project's label filters printed nothing; the markers are removed. `shellcheck` 0.11.0 from its Docker image reported two SC2030 notes, fixed by using `env` in place of subshell exports, then clean.
- 2026-11-05: T4, T5, T6: `launcher-compose` job in `launchers.yml` with `docker-compose.yml` in its `paths`; `launcher-compose` job in `docker.yml` wired into `notify`'s `needs` and `RESULTS`; comment at `launcher_common.sh:167`, POSIX harness header, and a DESIGN Known issues line updated.
- 2026-11-05: T7 stop: asked whether to push the branch and run one test-mode dispatch of `docker.yml` — the user chose "Push and run".
- 2026-11-05: T7: test-mode run 41983783693 at bb2e7c7: `launcher-compose` passed 23 of 23 checks, running after `publish (resolute)` failed. The run is red because `build (resolute, amd64)` could not connect to `r2u.stat.illinois.edu` in the smoke test; the branch changes no `Dockerfile` or image script, so the sighting went to the existing parked row and no re-run was made. `notify` was skipped, as it is on any dispatch.
- 2026-11-05: claim audit: not owed — internal tier.
- 2026-11-05: review stop: Docker Desktop off and fixes changed the script; asked whether to start Docker and whether to run a second test-mode dispatch — the user chose "Start Docker for me" and "Push and run again".

## Decisions

## Review

spawned: diff-bug, blame-history, prior-review, ripple

Review stopped before evidence: Docker Desktop shut down cleanly at 00:56 local on 2026-11-05 (its backend log), so the first evidence run, `docker build`, and `hadolint` all failed with `failed to connect to the docker API`. Those runs tested nothing and count as no evidence.

- diff-bug #1: a red `launcher-compose` turns the scheduled run red, so two such weeks raise a false "No successful weekly rebuild" — follow-up: parked row "Keep launcher failures out of the gap", and the coupling is stated in DESIGN, as keepalive already has it, fixed 673b783
- diff-bug #2: requested and bound ports match in all three scenarios, so a broken `launcher_bound_port` falls back to the same value and stays green — fix now: fourth scenario where only Compose knows the port, fixed 673b783
- diff-bug #3: AC6 has no PR-head evidence — reject (false): not a defect, D-138 opens the PR after approval and the merge waits on these checks; AC6 stays unticked until then
- diff-bug #4: `needs.launcher-compose.result` has never been evaluated, because `notify` runs only on schedule — reject (false): no defect shown; same shape as its neighbors and `actionlint` passed it; the first evaluation is the first Monday after merge
- diff-bug #5: a failed pull with a local image still goes green — reject (false): no check rests on a fresh image, and a clean runner's first scenario still needs the pull
- diff-bug #6: a failed `down -v` only warns — reject (edge): a daemon that fails during cleanup, outside normal use; the effect is a warning
- diff-bug #7: inherited `COMPOSE_FILE` and similar variables could aim `down -v` elsewhere — fix now, fixed 673b783
- diff-bug #8: `always()` also runs on a cancelled run — reject (edge): needs a cancelled scheduled run in which this job also fails; the effect is an issue the next green run closes; AC7 asks for `always()`-like behavior
- diff-bug #9: one Docker Hub failure on the weekly run opens the issue — follow-up: parked row "Retry the launcher check's image pull"
- diff-bug #10: no lock between two runs on one host — reject (edge): two local runs at once; the effect is failed checks
- diff-bug #11: a failure leaves little to diagnose — fix now: print the container's logs when the launcher fails, fixed 673b783
- diff-bug #12: the pull replaces a local `latest` — fix now: stated in the script header, fixed 673b783
- diff-bug #13: no `timeout-minutes` on either job — fix now: 20 minutes on both, fixed 673b783
- diff-bug #14: `curl` passes on any HTTP status — reject (planned change): AC1 asks for a response
- diff-bug #15: `ci-failure-issue.sh` header omits the job — fix now, fixed 673b783
- diff-bug #16: DESIGN Conventions omit the job — fix now, with #1, fixed 673b783
- diff-bug #17: "Its own paths filter" reads as the job's — fix now, fixed 673b783; the `scripts/tests/posix/**` overlap it also names predates this diff
- diff-bug #18: merging starts a full publish — reject (false): existing behavior, stated at the merge question
- diff-bug #19: failures print `FAIL:`, not `::error::` — reject (style)
- diff-bug test #1: the script guards code the change does not touch — reject (false): AC1 to AC3 name the checks, and the script is the deliverable
- diff-bug test #2: scenario 3 repeats scenario 2's code path — reject (planned change): AC1 and AC2 name it
- diff-bug test #3: scenario 3's port check mostly tests Compose's own rule — reject (planned change): AC1 names it
- diff-bug test #4: the URL check depends on the banner's wording — fix now: read the URL by its form, fixed 673b783
- diff-bug test #5: the 5.6.1 comment has no test — reject (false): a comment, written from the probe the work log records
- diff-bug test #6: two header comments restate the code — reject (style)
- blame-history #1: the `notify` path for this job is unexercised, and `needs` relies on the job's `if:` — reject (false): same as diff-bug #4, and the `docker.yml` comment records the coupling
- blame-history #2: no `timeout-minutes` — fix now, same as diff-bug #13, fixed 673b783
- blame-history #3: the comment rewrite pins a version and sets aside M09's observation — reject (false): it keeps the `:0` branch and names the version measured
- blame-history #4: the PR job uses the published image with the PR's Compose file — reject (planned change): Scope states it
- blame-history #5: the script says the ports must be free but does not check — reject (edge): a busy local port; the effect is a failed check
- prior-review #1: same as diff-bug #1 — follow-up: same row
- prior-review #2: the `:0` branch has only a stub test — reject (false): same as ripple #1 to #3; Scope leaves that branch alone
- ripple #1, #2, #3: `:0` comments in `start_windows.bat:113` and both harnesses — reject (false): each describes the branch it guards, which still handles a Compose that prints `:0`
- ripple #4, #5: `test_ci_failure_issue.sh` says three values — fix now, fixed 673b783
- ripple #6: the `test_mode` input description omits the job — fix now, fixed 673b783
- ripple #7: `launchers.yml:5` "without needing Docker" — reject (false): that sentence is about the stub jobs, and the next one names the job that needs Docker
- ripple #8: `docker.yml:43` does not list the new job — reject (false): it says "as notify and keepalive do" and then speaks of `meta`, `build`, and `publish` only
- ripple #9: same as diff-bug #15 — fix now, fixed 673b783
- ripple #10: the comment at `docker.yml:422` gives no reason for the job — reject (false): the job's own comment gives it
- ripple #11: same as diff-bug #16 — fix now, fixed 673b783
- ripple #12: same as diff-bug #17 — fix now, fixed 673b783
