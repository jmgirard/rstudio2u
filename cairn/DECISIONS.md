# Decisions

_Append-only, cross-cutting decisions (D-001, …). Never renumber or edit
history — supersede with a new entry. Milestone-local decisions live in their
milestone file; deferrals ("not now") are ROADMAP facts, not decisions._

### D-001 (2026-07-17): Own the rocker_scripts fork

**Context:** `scripts/` began as vendored rocker_scripts; local repairs (s6
v3 migration, quarto 'release' alias) had already diverged it, and drift was
confirmed as a wart in the design interview.
**Decision:** The scripts are this repo's code. Considered tracking upstream
with periodic re-syncs; rejected — hand-picking upstream fixes beats a
recurring sync chore against a fork that intentionally simplifies.
**Consequences:** Aggressive simplification is licensed (GP4); upstream fixes
must be noticed and reapplied by hand (recorded in Known issues).

### D-002 (2026-09-03): Pin shellcheck 0.11.0 as the shell-lint dependency

**Context:** M11 adds a pull-request shellcheck check. The runner's apt
package floats with the Ubuntu image, so an unpinned install could turn the
check red without any repo change.
**Decision:** Install shellcheck from the exact v0.11.0 release tarball,
verified by sha256, in `.github/workflows/lint.yml`; run at `-S warning`.
Considered 0.10.0 (the apt version); rejected — nothing in the repo needs
the older behavior and 0.11.0 is current. Bumping the pin is a dependency
change: question gate plus a superseding entry.
**Consequences:** New shellcheck checks arrive only when the pin is bumped
deliberately; the version and checksum live together in the workflow.
