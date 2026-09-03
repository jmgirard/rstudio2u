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

### D-003 (2026-09-03): Shell-lint severity floor is info, superseding D-002's floor

**Context:** D-002 set the shellcheck floor at `-S warning`. The M11
discrimination check showed shellcheck ranks SC2086 (unquoted expansion) as
info, so that floor cannot fail on the defect AC2 names.
**Decision:** `.github/workflows/lint.yml` runs `-S info`. The D-002 pin
(0.11.0, checksum-verified tarball) stands unchanged; only the floor moves.
Considered amending AC2 to a warning-level code; rejected — unquoted
expansions are the defect class worth catching in launchers that take user
input.
**Consequences:** Info-level findings fail the check; each must be fixed or
disabled inline with a one-line reason.

### D-004 (2026-09-03): Add peter-evans/dockerhub-description, SHA-pinned, for the Hub description sync

**Context:** M12 publishes `README.md` as the Docker Hub description for
`jmgirard/rstudio2u`. The Hub has no first-party GitHub Action for this.
**Decision:** Use `peter-evans/dockerhub-description` in
`.github/workflows/dockerhub-description.yml`, pinned to commit
`1b9a80c056b620d92cedb9d9b5a223409c68ddfa` (release v5.0.0) with the version
in a trailing comment. Considered a hand-written `curl` against the Hub API;
rejected — the action already handles login, the 25,000-byte README limit,
and the 100-byte short-description limit. Considered a major tag (`@v5`, the
repo's style for other actions); rejected at the implement gate — a movable
tag runs unreviewed code with a Hub credential. Bumping the pin is a
dependency change: question gate plus a superseding entry.
**Consequences:** The workflow's credential choice is milestone-local
(M12 Decisions); only the action and its pin are decided here.
