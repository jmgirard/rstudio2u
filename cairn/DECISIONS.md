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

### D-005 (2026-09-04): Docker tags record builds; semver git releases record recipe changes

**Context:** The fourteen git tags and GitHub releases v0.1, v0.2, v0.3,
v0.4, v0.5, v0.6, v0.7, v0.8, v0.9, v1.0, v1.1, v1.2, v1.3, v1.4 carried no
consistent meaning: v0.2, v0.3, v0.5, and v0.7 pointed at README edits, and
most of the rest marked RStudio version bumps that the weekly rebuild now
performs with no release. `CHANGELOG.md` duplicated the v1.4 release body.
rocker-bayes settled the same question as its D-002.
**Decision:** Two records with distinct meanings. The immutable
`<variant>-<date>` and `<variant>-<rstudio>` Docker tags CI publishes on every
build are the *build* record. Annotated git tags `v<major>.<minor>.<patch>`,
each with a GitHub release whose body equals the tag message, are the
*recipe* record: major when the environment changes under users (base image
family, Docker tag scheme, runtime interface); minor when something is added
or upgraded (variant, launcher feature, bundled tool, script behavior); patch
for a fix. Docs, refactors, and rebuilds with no recipe change get no release;
unreleased changes fold into the next one. Release notes live in the release
body; there is no changelog file (PROFILE `## changelog` slot: none). The
fourteen tags and releases above were deleted and the history re-released as
v1.0.0, v1.0.1, v1.1.0, v1.1.1, v1.1.2, v1.1.3, v1.2.0, v2.0.0, v2.1.0,
v2.2.0 — annotated tags backdated to their commits, the v2.x bodies being the
former v1.2, v1.3, v1.4 bodies unchanged. Considered keeping `CHANGELOG.md`
beside the releases; rejected — it duplicated the release body, and the
weekly toolchain bumps would either clutter it or go unrecorded either way.
**Consequences:** `/cairn-release` decides the version and drafts the notes
from the milestone's user-visible changes and hands off creating the tag and
release (PROFILE release-walk); the consistency gate reads the archive
summary, not a file entry. A tag message carrying Markdown headings is
created with `git tag --cleanup=verbatim`, or git strips the `#` lines as
comments.
