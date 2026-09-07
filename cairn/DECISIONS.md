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

### D-006 (2026-09-04): One exception to D-005's "bodies unchanged" — the compare links, annotating D-005

**Context:** D-005 states the v2.0.0, v2.1.0, v2.2.0 release bodies are the
former v1.2, v1.3, v1.4 bodies unchanged. After it was written the M014 review
found the `**Full changelog:**` compare links in v2.1.0 and v2.2.0 pointed at
the deleted `v1.2`/`v1.3`/`v1.4` tags.
**Decision:** Those two links were retargeted to
`compare/v2.0.0...v2.1.0` and `compare/v2.1.0...v2.2.0` (former v1.2 is
v2.0.0). Everything else in the three bodies is byte-identical to the
pre-deletion captures. D-005 otherwise stands.
**Consequences:** A recreated body may be edited only to repair a reference
to a tag that no longer exists; any other change is a new release, not an
edit.

### D-007 (2026-09-06): Drop `docker/setup-qemu-action`; build each architecture on its own runner

**Context:** The image build ran both architectures on one amd64 runner with
QEMU binfmt emulation. Quarto's bundled Deno (V8) intermittently aborts with
SIGILL (exit 132) under emulated aarch64, which made the arm64 build and its
smoke render unreliable and left the noble moving tags stale.
**Decision:** `docker/setup-qemu-action` is removed from `docker.yml`. Each
(variant, architecture) leg runs on a runner of that architecture —
`ubuntu-latest` for amd64, `ubuntu-24.04-arm` for arm64 — and builds only its
own platform. `scripts/retry.sh` and its wrapping of the quarto calls stay:
they still ride out genuine transients, they are just no longer riding out an
emulator.
**Consequences:** No workflow in the repo registers binfmt handlers; a future
lane that wants a foreign-architecture build re-adds the action. The arm64
runner label is pinned to a specific Ubuntu version, so a runner-image change
takes an edit here.

### D-008 (2026-09-06): A CI keepalive commit may write to the default branch, using a repo-scoped credential

**Context:** The repo is public, so GitHub disables `docker.yml`'s weekly
`schedule` trigger after 60 days of repository inactivity. Nothing inside the
repo can detect that state once it happens — a disabled workflow runs no
watchdog — so the always-fresh commitment (GP2) would end silently. The only
mechanism that acts without a person is a commit pushed by CI, and until now
the default branch has taken only the maintainer's docs-only tracking commits
and squash-merges of reviewed branches.
**Decision:** A `keepalive` job in `docker.yml` may push an empty commit to the
default branch when that branch's newest commit is 50 or more days old. It
authenticates with a credential scoped to this repository and held in a
repository secret, not with the workflow's own `GITHUB_TOKEN`: the repo-wide
Actions workflow permission stays read-only, so no other workflow gains write
access. Rejected: a documented manual check (leaves the failure dependent on
recall) and raising the repo-wide workflow permission (widens the ceiling for
every present and future workflow).
**Consequences:** The default branch now has a second author. A keepalive
commit matches no `paths` filter in `docker.yml` or `pr-ci.yml`, so it starts
no build. The credential is a maintainer-held secret that must be renewed
before it expires; its lapse is silent in the same way the original failure
is. Whether GitHub counts such a commit as repository activity is untestable
from this repo and is recorded in DESIGN Known issues.

### D-009 (2026-09-07): The keepalive credential is a deploy key with no expiry, annotating D-008

**Context:** D-008's Consequences said the keepalive credential "must be
renewed before it expires". That was written before the credential existed;
implementation then chose a repository deploy key, which is scoped to one
repository by construction and carries no expiry date. The sentence describes
a risk this repo does not have.
**Decision:** The keepalive push credential is an ed25519 repository deploy
key, write-enabled and titled `keepalive`, with its private half in the
repository secret `KEEPALIVE_DEPLOY_KEY`. D-008's decision stands unchanged;
only its renewal sentence is superseded.
**Consequences:** There is no expiry to track and no renewal to forget. The
credential now fails only by being revoked or deleted — a failing keepalive
job, not a silently lapsed one — and reporting that failure is the `notify`
gap carried as a ROADMAP candidate row. A future credential that does expire
re-opens D-008's concern and takes its own entry.
