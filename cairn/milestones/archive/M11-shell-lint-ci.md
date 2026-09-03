# M11: Shell lint in CI

**Status:** done (2026-09-03, PR #18 https://github.com/jmgirard/rstudio2u/pull/18)

**Goal:** Every tracked shell file is shellcheck-clean and stays so, enforced
by a pull-request check.

**Outcome:** `.github/workflows/lint.yml` (own `paths`: `**.sh`, `**.command`,
itself) installs shellcheck 0.11.0 from its release tarball (sha256-checked,
`sudo install`) and runs `-x -S info` over `git ls-files -z '*.sh' '*.command'
| xargs -0`, count asserted > 0. Fixed on the way: unguarded `cd "$(dirname
"$0")"` in the four launchers (now prints the folder and pauses via the
`RS_LAUNCHER_NONINTERACTIVE` seam before exit 1); `ls | head` → glob loop in
`scripts/install_pandoc.sh`; `tr` character classes in `smoke-test.sh`;
disables with reasons for SC2329, SC2153, SC2016. Discrimination: a planted
SC2086 fails the identical command; the warning floor passed it.

**Decisions:** D-002 (pin 0.11.0), D-003 (floor info, superseding D-002's
warning floor — SC2086 is info-level).

**Review:** three-lens fan-out. Fixed at the gate: silent `|| exit 1` guard
(diff + prior-review lenses, M08 archive), word-split file list, missing
`sudo`. Rejected: `branches: [main]` reports no check on shell-free PRs
(convention); sha256 unconfirmable offline (computed in-session, mismatch
fails loudly). History lens: none. LESSONS: plant the defect a floor claims to catch.
