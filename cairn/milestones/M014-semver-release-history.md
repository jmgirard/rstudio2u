# M014: Semver release history

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — public GitHub releases and the README's versioning text
- **Branch/PR:** `m014-semver-release-history` · https://github.com/jmgirard/rstudio2u/pull/21

## Goal

Replace the fourteen meaningless `v0.1`–`v1.4` git tags and GitHub releases with a semver history of recipe changes (annotated tags backdated to their commits; the release pages themselves will show today's publish date), and make the GitHub release body, not a changelog file, the notes of record, mirroring rocker-bayes D-002.

## Scope

**In:** the versioning rule (major = the environment changes under users: base image family, Docker tag scheme, runtime interface; minor = something added or upgraded: variant, launcher feature, bundled tool, script behavior; patch = a fix; docs, refactors, and rebuilds with no recipe change get no release); deleting the 14 existing tags and releases; recreating the ten releases in the Release map below as annotated tags backdated to their commits, each GitHub release body equal to its tag message; the three existing release bodies with real notes (v1.2, v1.3, v1.4) carried over unchanged onto v2.0.0, v2.1.0, v2.2.0; removing `CHANGELOG.md` (and its `.dockerignore` line) and setting the PROFILE changelog slot to none; PROFILE release-walk, README, DESIGN Conventions, and ROADMAP header text; a D-entry recording the rule.

**Out:** any image, launcher, or CI change (none); the `/cairn-release` skill's own conduct (plugin); retroactive Docker tags (the Hub tag list is already the build record).

### Release map

Tag dates and commits are historical; release notes for pre-CHANGELOG versions are one to three lines written from the commit diffs (the derived-claims rule).

| Tag | Date | Commit | Notes |
|---|---|---|---|
| v1.0.0 | 2025-03-24 | f48e0be | Initial image: RStudio Server on rocker/r2u noble, compose file |
| v1.0.1 | 2025-06-29 | e5104af | Compose pulls the multi-arch `latest` tag instead of `noble-amd64` |
| v1.1.0 | 2025-10-27 | 8a2e30b | Compose without a password, bound to localhost only |
| v1.1.1 | 2025-10-28 | 8471f74 | Fix bspm permissions |
| v1.1.2 | 2026-03-07 | 0e3715b | `usermod` instead of `adduser` when setting USERID |
| v1.1.3 | 2026-04-02 | c525a17 | Package-library permissions (staff group), removing install warnings |
| v1.2.0 | 2026-04-26 | 6e110e8 | `resolute` (Ubuntu 26.04) variant |
| v2.0.0 | 2026-07-05 | 98f3a44 | former v1.2 body: unified Dockerfile, RStudio auto-detect, s6-overlay v3, CI, launchers, named home volume, slim image |
| v2.1.0 | 2026-07-05 | 11ef521 | former v1.3 body: immutable date/version tags, CITATION |
| v2.2.0 | 2026-09-03 | e0893aa | former v1.4 body: `.env` port, pre-publish smoke test, launcher offline fallback, rebuild failure alert, and the rest of that body |

Skipped by rule: the seven RStudio-version-bump-only commits (2025-06-29 … 2026-07-01) — after v2.0.0 the same event is a weekly rebuild with no release. The old v0.2, v0.3, v0.5, v0.7 pointed at README edits and map to nothing.

## Acceptance criteria

- [x] AC1: `git ls-remote --tags origin | grep -v '\^{}'` lists exactly the ten tags in the Release map and no others; for each, `git cat-file -t` prints `tag`, `git log -1 --format=%H <tag>^{commit}` starts with the map's commit, and `git for-each-ref --format='%(taggerdate:short)' refs/tags/<tag>` prints the map's date.
- [x] AC2: `gh release list --limit 50` lists exactly those ten releases with `v2.2.0` marked Latest, and for each the release body (`gh release view <tag> --json body -q .body`) equals the tag message (`git tag -l --format='%(contents)' <tag>`) after both are passed through `sed -e 's/\r$//'` and trailing blank lines are trimmed.
- [x] AC3: The release bodies of v2.0.0, v2.1.0, v2.2.0 are the former v1.2, v1.3, v1.4 bodies unchanged except that the `**Full changelog:**` compare link in v2.1.0 and v2.2.0 is retargeted to `compare/v2.0.0...v2.1.0` and `compare/v2.1.0...v2.2.0`: `gh release view <new> --json body -q .body` is byte-identical to the T1 capture after that one line's substitution (`sed` over the capture).
- [x] AC4: `CHANGELOG.md` is absent from the tree; `git grep -il changelog HEAD --` on the branch head matches only `cairn/PROFILE.md`, `cairn/DECISIONS.md`, and paths under `cairn/milestones/`; the PROFILE `## changelog` slot declares none as a file; `python3 "$CAIRN/scripts/cairn_validate.py"` (the plugin script, `CAIRN=/Users/jmgirard/.claude/skills/cairn`) passes.
- [x] AC5: README's Reproducibility section carries a paragraph stating that Docker date tags record builds and GitHub releases record recipe changes, giving the major/minor/patch rule from Scope and linking `https://github.com/jmgirard/rstudio2u/releases`; DESIGN Conventions state the same in one line; `grep -nE '\bM[0-9]+\b|[Mm]ilestone' README.md` and the same grep over the DESIGN Conventions section both return nothing.
- [x] AC6: `cairn/DECISIONS.md` gains a D-entry stating the rule in Scope, naming the fourteen deleted tags `v0.1`–`v1.4` and the ten recreated tags, and recording that release notes live in the release body with no changelog file; the ROADMAP header release line names v2.2.0.

## Coverage

- AC1 → T2, T3
- AC2 → T3, T4
- AC3 → T1, T4
- AC4 → T5
- AC5 → T5
- AC6 → T5

## Tasks

- [x] T1: Capture the pre-deletion state: every release body via `gh release view <tag> --json body -q .body > cairn/milestones/M014-bodies/<tag>.md` (all 14, committed on the branch), plus the tag→commit list in the work log. Draft the seven short bodies for v1.0.0–v1.2.0 from `git show <commit>`. (Captures committed under `cairn/milestones/M014-bodies/` as the AC3 reference, deleted at archive time.)
- [x] T2: Delete the 14 old releases and tags first (`gh release delete <tag> --cleanup-tag --yes` for each, `git tag -d` locally; confirm `git ls-remote --tags origin` is empty), then create the ten annotated tags with `GIT_COMMITTER_DATE="<date> 12:00:00" git tag -a <tag> <commit> -F <body-file>` and push them (`git push origin <tag>…`). (Direct remote operation, approved at the pre-implementation gate; the T1 captured bodies make it recoverable.)
- [x] T3: Verify the tag set after T2 (AC1 by command): `git ls-remote --tags origin | grep -v '\^{}'` shows ten refs, each `git cat-file -t` prints `tag`, dates and commits match the map.
- [x] T4: `gh release create <tag> --title <tag> --notes-file <body-file>` for each, oldest first, `--latest` only for v2.2.0; verify AC2 and AC3 by command.
- [x] T5: On branch `m014-semver-release-history`: `git rm CHANGELOG.md` and drop the `CHANGELOG.md` line from `.dockerignore`; PROFILE `## changelog` → none as a file with notes in the release body (rocker-bayes `cairn/PROFILE.md` lines 112–117 as the model), release-walk bullets rewritten so the version decision and notes come from the milestone's user-visible changes and the handoff creates the annotated tag and release; README paragraph after the Reproducibility tag table (rocker-bayes README 196–201 as the model, adapted: R/RStudio/Pandoc/Quarto bumps are rebuilds, not releases); DESIGN Conventions line; D-005 in DECISIONS.md; ROADMAP header line `_Released 2.2.0 …_`; run `cairn_validate`.

- [x] T6: Amend AC3 through the step-6 gate to permit retargeting the `**Full changelog:**` compare link in the v2.1.0 and v2.2.0 bodies to the recreated tags; then edit both release bodies and recreate both tags (`--cleanup=verbatim`, same commits and dates) with `compare/v2.0.0...v2.1.0` (former v1.2 is v2.0.0) and `compare/v2.1.0...v2.2.0`; re-verify AC2 and the amended AC3 by command (review finding 1).
- [x] T7: Rewrite the v1.1.0 body from `8a2e30b` (localhost bind, the `127.0.0.1:2222:22` SSH mapping, the hardcoded 8787 port replacing `${RS_PORT}`; no-password was pre-existing) and the v1.1.2 body from `0e3715b` (sudo granted with `usermod -aG sudo` instead of `adduser`; not about `USERID`); recreate both tags and edit both releases; re-verify AC1 and AC2 (review findings 2, 3).

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: criteria audit ran in full mode ([O] fresh reader); returned 9 findings (AC4 unsatisfiable via `.dockerignore`; AC3 instrument-bound; AC1/AC2/AC4 command literals; AC5 proxy probe; coverage gaps; AC6/Goal wording) — all fixed in the wording written here.
- 2026-09-04: plan gate chose one release v2.2.0 at e0893aa carrying the whole former v1.4 body over splitting a v2.2.0 at dac1119 (2026-07-21) plus v2.3.0, because the v1.4 body covers both spans and splitting it would rewrite preserved notes; falsified by a reader needing the July and September changes dated separately.
- 2026-09-04: plan chose the release body as the notes of record (changelog file removed) over keeping CHANGELOG.md, because the 1.4 body already duplicated the file and rocker-bayes D-002 has the same shape; falsified by a consumer needing notes inside the repo checkout (the annotated tag message carries them).

- 2026-09-04: T1: captured all 14 release bodies under `cairn/milestones/M014-bodies/` (v0.1–v1.1 bodies carry CRLF, normalized to LF by git at commit; v1.2–v1.4, the AC3 bodies, carry none); pre-deletion tag→commit: v0.1→f48e0be, v0.2→8b0d8f9, v0.3→867f786, v0.4→6244d5c, v0.5→3ef2e7c, v0.6→375cd98, v0.7→17297c6, v0.8→1b60ada, v0.9→e4db9a9, v1.0→0230e8e, v1.1→36e36f6, v1.2→98f3a44, v1.3→11ef521, v1.4→e0893aa (only v1.4 was an annotated tag). Seven short bodies drafted from the commit diffs; shown at the implement gate.
- 2026-09-04: plan gate chose delete-old-then-create-new over create-new-then-delete-old (user choice: a clean slate); the captured bodies bound the recovery cost. Release window declared by the user at the gate ("create them now"); old bodies committed on the branch under `cairn/milestones/M014-bodies/`, deleted at archive.
- 2026-09-04: implement gate approved the remote operations (delete-then-create) and the seven plain-sentence bodies as drafted. T2: `gh release delete --cleanup-tag` removed all 14 releases and tags (`git ls-remote --tags origin` empty afterwards; the old tags had never been fetched locally, so `git tag -d` had nothing to remove); ten annotated tags created with `GIT_COMMITTER_DATE=<date> 12:00:00` and pushed. T3: remote lists exactly the ten map tags; each is type `tag`, points at the map commit, and carries the map taggerdate (AC1 by command).
- 2026-09-04: T4: ten releases created oldest-first, `--latest` only on v2.2.0. First pass failed AC2/AC3 for v2.0.0–v2.2.0: `git tag -F` stripped the `### …` heading lines as comments, and the notes file carried the trailing newline jq adds at capture. Those three tags were recreated with `--cleanup=verbatim` (same commits and dates), force-pushed, and their releases re-edited from the capture minus that one byte. Re-verified: all ten bodies equal their tag message after CR-strip and trailing-blank trim (AC2); v2.0.0/v2.1.0/v2.2.0 bodies `cmp` byte-identical to the v1.2/v1.3/v1.4 captures (AC3).
- 2026-09-04: T5: removed `CHANGELOG.md` and its `.dockerignore` line; PROFILE changelog slot → none, release-walk and consistency-gate bullets rewritten around the release body; README Reproducibility paragraph; DESIGN Conventions line (and the existing "never reference milestone numbers" convention reworded to "project-tracking IDs" so the AC5 grep over Conventions is empty); D-005; ROADMAP release line. hadolint is not installed locally and no Dockerfile or build-context content changed, so the verify slot's lint/build was not run here; CI lint runs on the PR.
- 2026-09-04: T5 pushed PROFILE to 128 lines (cap <120); compressed the release-walk and changelog slots in one pass to 119. `cairn_validate` all checks passed; AC4–AC6 greps by command as written. Status → review.

- 2026-09-04: review: PR #21 opened as draft; AC1–AC6 verified by command; consistency gate clean (hadolint 2.12.0, cached build). Three-lens review: [O] 10 findings, [S] history none, [S] prior-review "no prior-review evidence". Triage at the gate: 1 fix (amendment), 2–4 fix, 5–6 rejected, 7 logged, 8–10 noted (Review section).
- 2026-09-04: amendment return: AC3 — "The release bodies of v2.0.0, v2.1.0, v2.2.0 are the former v1.2, v1.3, v1.4 bodies unchanged except that the `**Full changelog:**` compare link in v2.1.0 and v2.2.0 is retargeted to `compare/v1.2.0...v2.1.0` and `compare/v2.1.0...v2.2.0`: `gh release view <new> --json body -q .body` is byte-identical to the T1 capture after that one line's substitution (`sed` over the capture), the captures committed under `cairn/milestones/M014-bodies/` and deleted at archive time." Status → in-progress for the amendment (T6) plus fix-now T7; finding 4 fixed on the branch here. Amendment-return count for AC3: 1.
- 2026-09-04: re-audit: AC3 (full) — the trailing clause (captures committed under `M014-bodies/`, deleted at archive time) binds an instrument, not the bodies, and is unverifiable at review; satisfiability, reachability, bounded promise, proportionality clean.
- 2026-09-04: AC3 amendment fixed at the mini gate (user: adopt corrected wording): compare-link target for v2.1.0 corrected from `compare/v1.2.0...v2.1.0` (the return text; `v1.2.0` is the resolute tag) to `compare/v2.0.0...v2.1.0`, the original `v1.2...v1.3` link's predecessor being former v1.2 = v2.0.0; the instrument clause moved to T1; T6 wording reconciled. AC3 box cleared for fresh review evidence.
- 2026-09-04: re-audit: AC3 (full) — nothing on the wording; two adjacent notes, both handled: T6 and the return line still named `v1.2.0` (T6 reconciled; the return line stands as the record of what was returned), and D-005's "bodies unchanged" now overstates AC3 (milestone Decisions entry below).
- 2026-09-04: T6 (partial): v2.1.0 and v2.2.0 annotated tags recreated (`--cleanup=verbatim`, same commits and taggerdates) with the retargeted links and force-pushed. `gh release edit` for both bodies was blocked by the session's command classifier; the two release-body edits are pending the user, after which AC2 and AC3 are re-verified by command.
- 2026-09-04: T7 (partial): v1.1.0 body rewritten from `8a2e30b` (localhost bind, fixed host port 8787 replacing `${RS_PORT}`, `127.0.0.1:2222:22` SSH mapping; no-password not credited) and v1.1.2 from `0e3715b` (sudo via `usermod -aG sudo` when `ROOT=true`, not about `USERID`); both annotated tags recreated locally at the same commits and taggerdates. The tag force-push and both `gh release edit` calls were blocked by the classifier; pending the user, then AC1 and AC2 re-verified by command.
- 2026-09-04: T6/T7 done: the user ran the pending `gh release edit` calls and the v1.1.0/v1.1.2 tag push between sessions (local and remote tag objects identical). The v2.1.0/v2.2.0 bodies were one trailing newline short of the substituted captures; re-edited here from the capture minus jq's final newline (`gh release view` appends one). Re-verified by command: AC1 (ten remote tags, type `tag`, map commits and taggerdates), AC2 (all ten bodies equal tag messages after CR-strip and trailing-blank trim), AC3 (v2.0.0 `cmp` identical to the v1.2 capture; v2.1.0/v2.2.0 identical to the v1.3/v1.4 captures after the compare-link `sed`). `cairn_validate` all checks passed; no Dockerfile or build-context change, so lint/build not rerun. Status → review.

## Decisions

- 2026-09-04: D-005 says the v2.x bodies are the former v1.2, v1.3, v1.4 bodies unchanged; D-entries are append-only, so the one exception lives here: the `**Full changelog:**` compare link in v2.1.0 and v2.2.0 is retargeted to the recreated tags (`v2.0.0...v2.1.0`, `v2.1.0...v2.2.0`) because the `v1.2`/`v1.3`/`v1.4` tags no longer exist. Everything else in those bodies is byte-identical to the captures.

## Review

- 2026-09-04 AC1: `git ls-remote --tags origin` lists exactly the ten map tags; each `cat-file -t` prints `tag`, points at the map commit (f48e0be … e0893aa), and carries the map taggerdate (2025-03-24 … 2026-09-03). Pass.
- 2026-09-04 AC2: `gh release list --limit 50` shows the ten releases, v2.2.0 Latest; all ten bodies equal their tag message after CR-strip and trailing-blank trim (`cmp` clean). Pass.
- 2026-09-04 AC3: v2.0.0/v2.1.0/v2.2.0 bodies `cmp` byte-identical to `M014-bodies/v1.2.md`, `v1.3.md`, `v1.4.md` (2288, 1038, 4123 bytes). Pass.
- 2026-09-04 AC4: `CHANGELOG.md` absent; `git grep -il changelog HEAD --` matches only PROFILE, DECISIONS, and `cairn/milestones/` paths; PROFILE `## changelog` slot reads none as a file; `cairn_validate` all checks passed (one pre-existing scaffold-deprecation advisory). Pass.
- 2026-09-04 AC5: README Reproducibility paragraph states date tags = builds, releases = recipe changes, gives major/minor/patch, links `/releases`; DESIGN Conventions "Two version records" line says the same; both greps for milestone IDs return nothing. Pass.
- 2026-09-04 AC6: D-005 present, names the fourteen deleted tags and the ten recreated ones, records release body as notes of record with no changelog file; ROADMAP header `_Released 2.2.0 …_`. Pass.
- 2026-09-04 consistency gate: `cairn_validate` exit 0; no IP/GP principle text changed (`cairn_impact` skipped); diff is markdown plus one `.dockerignore` line, no Dockerfile or build-context change; `docker build` succeeds (fully cached, exit 0); base image `rocker/r2u:${UBUNTU_VERSION}` with default 24.04 (pre-existing); no credentials in ENV/COPY/ARG; `.dockerignore` present and excludes `.git`, `cairn`, tests. hadolint: CI's pinned 2.12.0 is clean; local 2.15.1 adds DL3025 (HEALTHCHECK CMD shell form, line 68, unchanged since 2026-07-17) — pre-existing, not introduced here.
- 2026-09-04 findings triage (user at the gate): (1) dead compare links in v2.1.0/v2.2.0 bodies — fix via AC3 amendment, T6; (2) v1.1.2 body causal claim unsupported by 0e3715b — fix now, T7; (3) v1.1.0 body credits pre-existing no-password, omits hardcoded port — fix now, T7; (4) PROFILE release-walk said every merge publishes an image — fixed on the branch (paths-gated wording); (5) D-005 enumerations vs the D-entry rule — rejected: AC6 required the enumeration and D-entries are append-only; (6) ROADMAP stamp/date — rejected: step 9 rewrites the stamp, the release line names the publish date; (7) DESIGN convention widened to "project-tracking IDs" — logged as a deliberate superset, kept; (8) v1.1.3 folds 368cf74 — noted, per D-005 folding; (9) v1.0.0 at a README-only commit — noted, matches old v0.1; (10) `.dockerignore` — noted, harmless. History lens: no conflicts (its two flags — implement skipped local lint/build, convention rewording — covered by this review's gate run and finding 7). Prior-review lens: no prior-review evidence.
- 2026-09-04 re-review AC1: `git ls-remote --tags origin` lists exactly the ten map tags; each `cat-file -t` prints `tag`, points at the map commit (f48e0be … e0893aa), taggerdates match the map (2025-03-24 … 2026-09-03). Pass.
- 2026-09-04 re-review AC2: `gh release list --limit 50` shows exactly ten releases, v2.2.0 Latest; all ten bodies equal their tag message after CR-strip and trailing-blank trim (`cmp` clean, v1.1.0/v1.1.2 rewritten bodies included). Pass.
- 2026-09-04 re-review AC3 (amended wording): v2.0.0 body `cmp` byte-identical to `M014-bodies/v1.2.md`; v2.1.0 and v2.2.0 byte-identical to `v1.3.md`/`v1.4.md` after the one-line `sed` retargeting the compare link to `v2.0.0...v2.1.0` / `v2.1.0...v2.2.0` — release and capture both read through the same `gh release view --json body -q .body` extraction (2288, 1042, 4127 bytes). Pass.
- 2026-09-04 re-review AC4: `CHANGELOG.md` absent; `git grep -il changelog HEAD --` matches only PROFILE, DECISIONS, and `cairn/milestones/` paths; `.dockerignore` has no CHANGELOG line; PROFILE `## changelog` declares none as a file; `cairn_validate` exit 0. Pass.
- 2026-09-04 re-review AC5: README Reproducibility paragraph (date tags = builds, releases = recipe, major/minor/patch, `/releases` link); DESIGN Conventions "Two version records" line; both milestone-ID greps return nothing. Pass.
- 2026-09-04 re-review AC6: D-005 names the fourteen deleted and ten recreated tags and states no changelog file; ROADMAP header `_Released 2.2.0 …_`. Pass.
- 2026-09-04 re-review consistency gate: `cairn_validate` exit 0 (one pre-existing scaffold-deprecation advisory); no IP/GP text changed (`cairn_impact` skipped); hadolint 2.12.0 (CI's pin, via its container image) clean; `docker build` exit 0; base image `rocker/r2u:${UBUNTU_VERSION}` (pre-existing); no credentials in ENV/ARG/COPY; `.dockerignore` excludes `.git`, `cairn`, tests. PR reports no checks (workflows path-filtered; diff is markdown plus one `.dockerignore` line) — mergeable on local green per the profile gate.
