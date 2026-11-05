# M024: Verify the launcher port on real Compose

- **Status:** in-progress
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
- [ ] T4: Add the job to `launchers.yml`, add `docker-compose.yml` to its `paths`, and correct the workflow's header comment, which says the lane needs no Docker.
- [ ] T5: Add the `launcher-compose` job to `docker.yml` with `if: always() && (github.event_name == 'schedule' || github.event_name == 'workflow_dispatch')`, add it to `notify`'s `needs` and `RESULTS`, and extend the comment there that explains why a needed job must never read `skipped`.
- [ ] T6: Reword the comment at `launcher_common.sh:167` to what was observed: Compose 5.6.1 exits 1 with `no port 8787/tcp` when nothing is published, and the `:0` check stays for a Compose that exits 0. Point the POSIX harness header at the new script. Add a `DESIGN.md` Known issues line: the real-Compose check runs only `start_linux.sh`, only on amd64, and only on the runner's Compose version.
- [ ] T7: Stop for the user's yes, then push the branch and run `gh workflow run docker.yml --ref <branch> -f test_mode=true`. This run builds every leg and attaches no tag. The question set did not cover it. `shellcheck`, `launchers.yml`, and `lint.yml` run only on a PR, so review sees AC6 on the PR head.

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

## Decisions

## Review
