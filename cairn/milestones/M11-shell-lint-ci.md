# M11: Shell lint in CI

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Branch/PR:** m011-shell-lint-ci · https://github.com/jmgirard/rstudio2u/pull/18

## Goal

Every tracked shell file is shellcheck-clean and stays so, enforced by a
pull-request check.

## Scope

Tier: internal — a PR-time checker over repo scripts; no external consumer
relies on it.

**In:** a new `.github/workflows/lint.yml` running a pinned shellcheck over
the enumerated shell files; fixing (or disabling with a stated reason) every
finding it raises today.

**Out:** hadolint (already in `pr-ci.yml`); linting `start_windows.bat` (no
comparable tool; the Windows harness stays its check); adding shellcheck to
`pr-ci.yml` (gate chose a separate workflow so launcher-only edits do not
trigger the image build).

## Acceptance criteria

- [x] AC1: A pull-request workflow runs shellcheck over every tracked file
      `git ls-files '*.sh' '*.command'` enumerates, and that step passes on
      the milestone branch.
- [x] AC2: The step exits non-zero when a file the AC1 enumeration lists
      contains an unquoted variable expansion (SC2086).
- [x] AC3: The workflow's `paths` trigger lists `**.sh` and `**.command` and
      its own file, so a change to any enumerated file runs the lint.
- [x] AC4: The shellcheck version is pinned to an exact version in the
      workflow, never a floating `latest`.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T1
- AC4 → T1

## Tasks

- [x] T1: Write `.github/workflows/lint.yml`: `pull_request` on the AC3
      paths; install a pinned shellcheck release (download the exact version's
      tarball, not the runner's apt package); run it over the `git ls-files`
      enumeration, `-S warning` or stricter, external-sources enabled so the
      `# shellcheck source=` directives in the launchers resolve.
- [x] T2: Run the same command locally on every enumerated file; fix each
      finding, or add a `# shellcheck disable=SCnnnn` with a one-line reason.
      `.github/smoke-test.sh` and the launchers have never been linted, so
      expect findings there.
- [x] T3: Discrimination check: plant an SC2086 in one enumerated file on the
      branch, observe the step fail in CI (or the identical command locally at
      the pinned version), remove it; record the run in the work log.

## Work log

- 2026-09-03: created by /milestone-plan.
- 2026-09-03: criteria audit ran in reduced mode ([O] fresh reader); returned: AC2 ended in a work-log recording clause (moved to T3), `launcher_common.sh` redundant in the pathspec (dropped).
- 2026-09-03: plan gate chose a separate `lint.yml` over a job in `pr-ci.yml` because pr-ci's path filter would then pull the image build into launcher-only PRs; falsified by GitHub Actions gaining per-job path filters.
- 2026-09-03: T1 done — `.github/workflows/lint.yml` written: tarball download of v0.11.0 verified by sha256, `-x -S warning` over the `git ls-files` list, list asserted non-empty; gate picked 0.11.0 and the warning floor.
- 2026-09-03: T2 done — 4 findings at the warning floor, all SC2164 (`cd "$(dirname "$0")"` unguarded) in the four launchers; fixed with `|| exit 1`; lint exit 0 over 24 files; POSIX launcher harness and CRLF guard pass.
- 2026-09-03: T3 planted SC2086 in `scripts/retry.sh` under bash at the warning floor: exit 0 — the floor cannot catch it; first T3 attempt under the zsh tool shell failed for an unrelated reason (zsh does not word-split `$files`), discarded.
- 2026-09-03: T2 continued at the info floor: 7 findings — fixed SC2018/SC2019 (`tr` classes) in smoke-test.sh and SC2012 ×2 in install_pandoc.sh (glob loop replaces `ls | head`, glob branch simulated found/none); disabled with reasons SC2329 (trap-invoked), SC2153 (env-var contract), SC2016 (literal `${CUSTOM}` under test). Lint exit 0 over 24 files; launcher harness and pandoc parser tests pass. Local `docker build` (verify slot, build-context change) running.
- 2026-09-03: T3 at the info floor: planted SC2086 → exit 1 naming SC2086 at retry.sh:49; reverted; clean tree exit 0.
- 2026-09-03: local `docker build` (noble, arm64) exit 0; the built image's pandoc resolves via the rewritten glob branch (`.../tools/aarch64/pandoc`), so the SC2012 fix took the path it replaced. hadolint not run locally (not installed; Dockerfile unchanged, pr-ci.yml lints it). Status → review.

## Decisions

- 2026-09-03: shellcheck pinned at 0.11.0, severity floor `-S warning` (gate). Promoted to D-002.
- 2026-09-03: floor moved to `-S info` (mini gate) because SC2086 is info-level and the warning floor passed a planted SC2086; D-002's floor superseded by D-003.

## Review

_2026-09-03, PR #18, branch head 6d0c2eb; main not moved since cut._

- AC1: `.github/workflows/lint.yml` runs `shellcheck -x -S info` over `git ls-files '*.sh' '*.command'` (24 files, asserted non-empty). Local run at 0.11.0: exit 0. CI `shellcheck` job on PR #18: pass (run 33815790449). ✔
- AC2: planted `echo $v` in `launcher_common.sh`; identical command exits 1 reporting SC2086 at launcher_common.sh:163; reverted, clean tree exit 0. ✔
- AC3: parsed `paths` = `**.sh`, `**.command`, `.github/workflows/lint.yml`; every enumerated file ends in `.sh` or `.command`. ✔
- AC4: `SHELLCHECK_VERSION: "0.11.0"` with a sha256 for the tarball; the only `latest` in the file is `ubuntu-latest` (runner label). ✔
- Gate: `cairn_validate` exit 0 (one pre-existing advisory: `.gitignore` `cairn/references/pdf/` naming); hadolint v2.12.0 (container) clean; Dockerfile unchanged on the branch; local noble build of this tree exit 0 (image created after the last script commit); base image `rocker/r2u:${UBUNTU_VERSION}` with the version passed by build-arg; no secrets in Dockerfile; `.dockerignore` present excluding `.git`, `cairn`, tests; CHANGELOG untouched — judged no user-visible change (the launcher `cd` guard only converts a continue-after-failed-cd into exit 1).

Independent review (fresh-context: [O] diff-bug, [S] blame-history, [S] prior-review; blame-history reported none). Findings and triage:
- F1 (diff-bug #1, prior-review #1; M08 archive): the `cd "$(dirname "$0")" || exit 1` guard exits a double-clicked window silently, where every other launcher error prints and pauses; before the branch a failed cd fell through to the missing-file message. **Fix now:** the guard prints the folder it could not open and pauses via the `RS_LAUNCHER_NONINTERACTIVE` seam before `exit 1`, all four launchers; harness passes; permission-denied simulation takes the message branch.
- F2 (diff-bug #2): `$files` word-split in `lint.yml` would mis-handle a path with a space. **Fix now:** `git ls-files -z | xargs -0`, count asserted > 0 from the NUL-separated list; F5 (inert `disable` comment in the `run:` block) disappears with it. Local run: 24 files, exit 0; planted SC2086 still exits 1.
- F3 (diff-bug #3): `install` into `/usr/local/bin` without `sudo`. **Fix now:** `sudo install`.
- F4 (diff-bug #4): `branches: [main]` plus the paths filter means a PR without shell changes reports no check. **Reject:** matches `pr-ci.yml`/`launchers.yml` convention; noted for anyone making the check required.
- F6 (diff-bug #6): the sha256 could not be independently confirmed by the reviewer. **Reject:** computed in-session from the downloaded v0.11.0 linux.x86_64 tarball; a mismatch fails loudly at `sha256sum -c`.
