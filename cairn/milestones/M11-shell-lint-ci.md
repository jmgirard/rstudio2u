# M11: Shell lint in CI

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Branch/PR:** —

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

- [ ] AC1: A pull-request workflow runs shellcheck over every tracked file
      `git ls-files '*.sh' '*.command'` enumerates, and that step passes on
      the milestone branch.
- [ ] AC2: The step exits non-zero when a file the AC1 enumeration lists
      contains an unquoted variable expansion (SC2086).
- [ ] AC3: The workflow's `paths` trigger lists `**.sh` and `**.command` and
      its own file, so a change to any enumerated file runs the lint.
- [ ] AC4: The shellcheck version is pinned to an exact version in the
      workflow, never a floating `latest`.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T1
- AC4 → T1

## Tasks

- [ ] T1: Write `.github/workflows/lint.yml`: `pull_request` on the AC3
      paths; install a pinned shellcheck release (download the exact version's
      tarball, not the runner's apt package); run it over the `git ls-files`
      enumeration, `-S warning` or stricter, external-sources enabled so the
      `# shellcheck source=` directives in the launchers resolve.
- [ ] T2: Run the same command locally on every enumerated file; fix each
      finding, or add a `# shellcheck disable=SCnnnn` with a one-line reason.
      `.github/smoke-test.sh` and the launchers have never been linted, so
      expect findings there.
- [ ] T3: Discrimination check: plant an SC2086 in one enumerated file on the
      branch, observe the step fail in CI (or the identical command locally at
      the pinned version), remove it; record the run in the work log.

## Work log

- 2026-09-03: created by /milestone-plan.
- 2026-09-03: criteria audit ran in reduced mode ([O] fresh reader); returned: AC2 ended in a work-log recording clause (moved to T3), `launcher_common.sh` redundant in the pathspec (dropped).
- 2026-09-03: plan gate chose a separate `lint.yml` over a job in `pr-ci.yml` because pr-ci's path filter would then pull the image build into launcher-only PRs; falsified by GitHub Actions gaining per-job path filters.

## Decisions

## Review
