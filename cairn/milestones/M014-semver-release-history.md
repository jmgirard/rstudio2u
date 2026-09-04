# M014: Semver release history

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — public GitHub releases and the README's versioning text
- **Branch/PR:** `m014-semver-release-history`

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

- [ ] AC1: `git ls-remote --tags origin | grep -v '\^{}'` lists exactly the ten tags in the Release map and no others; for each, `git cat-file -t` prints `tag`, `git log -1 --format=%H <tag>^{commit}` starts with the map's commit, and `git for-each-ref --format='%(taggerdate:short)' refs/tags/<tag>` prints the map's date.
- [ ] AC2: `gh release list --limit 50` lists exactly those ten releases with `v2.2.0` marked Latest, and for each the release body (`gh release view <tag> --json body -q .body`) equals the tag message (`git tag -l --format='%(contents)' <tag>`) after both are passed through `sed -e 's/\r$//'` and trailing blank lines are trimmed.
- [ ] AC3: The release bodies of v2.0.0, v2.1.0, v2.2.0 are the former v1.2, v1.3, v1.4 bodies unchanged: `gh release view <new> --json body -q .body` is byte-identical to the file T1 captured from `gh release view <old> --json body -q .body` before deletion (the three captured files are committed under `cairn/milestones/M014-bodies/` as the evidence artifact and deleted at archive time).
- [ ] AC4: `CHANGELOG.md` is absent from the tree; `git grep -il changelog HEAD --` on the branch head matches only `cairn/PROFILE.md`, `cairn/DECISIONS.md`, and paths under `cairn/milestones/`; the PROFILE `## changelog` slot declares none as a file; `python3 "$CAIRN/scripts/cairn_validate.py"` (the plugin script, `CAIRN=/Users/jmgirard/.claude/skills/cairn`) passes.
- [ ] AC5: README's Reproducibility section carries a paragraph stating that Docker date tags record builds and GitHub releases record recipe changes, giving the major/minor/patch rule from Scope and linking `https://github.com/jmgirard/rstudio2u/releases`; DESIGN Conventions state the same in one line; `grep -nE '\bM[0-9]+\b|[Mm]ilestone' README.md` and the same grep over the DESIGN Conventions section both return nothing.
- [ ] AC6: `cairn/DECISIONS.md` gains a D-entry stating the rule in Scope, naming the fourteen deleted tags `v0.1`–`v1.4` and the ten recreated tags, and recording that release notes live in the release body with no changelog file; the ROADMAP header release line names v2.2.0.

## Coverage

- AC1 → T2, T3
- AC2 → T3, T4
- AC3 → T1, T4
- AC4 → T5
- AC5 → T5
- AC6 → T5

## Tasks

- [x] T1: Capture the pre-deletion state: every release body via `gh release view <tag> --json body -q .body > cairn/milestones/M014-bodies/<tag>.md` (all 14, committed on the branch), plus the tag→commit list in the work log. Draft the seven short bodies for v1.0.0–v1.2.0 from `git show <commit>`.
- [x] T2: Delete the 14 old releases and tags first (`gh release delete <tag> --cleanup-tag --yes` for each, `git tag -d` locally; confirm `git ls-remote --tags origin` is empty), then create the ten annotated tags with `GIT_COMMITTER_DATE="<date> 12:00:00" git tag -a <tag> <commit> -F <body-file>` and push them (`git push origin <tag>…`). (Direct remote operation, approved at the pre-implementation gate; the T1 captured bodies make it recoverable.)
- [x] T3: Verify the tag set after T2 (AC1 by command): `git ls-remote --tags origin | grep -v '\^{}'` shows ten refs, each `git cat-file -t` prints `tag`, dates and commits match the map.
- [ ] T4: `gh release create <tag> --title <tag> --notes-file <body-file>` for each, oldest first, `--latest` only for v2.2.0; verify AC2 and AC3 by command.
- [ ] T5: On branch `m014-semver-release-history`: `git rm CHANGELOG.md` and drop the `CHANGELOG.md` line from `.dockerignore`; PROFILE `## changelog` → none as a file with notes in the release body (rocker-bayes `cairn/PROFILE.md` lines 112–117 as the model), release-walk bullets rewritten so the version decision and notes come from the milestone's user-visible changes and the handoff creates the annotated tag and release; README paragraph after the Reproducibility tag table (rocker-bayes README 196–201 as the model, adapted: R/RStudio/Pandoc/Quarto bumps are rebuilds, not releases); DESIGN Conventions line; D-005 in DECISIONS.md; ROADMAP header line `_Released 2.2.0 …_`; run `cairn_validate`.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: criteria audit ran in full mode ([O] fresh reader); returned 9 findings (AC4 unsatisfiable via `.dockerignore`; AC3 instrument-bound; AC1/AC2/AC4 command literals; AC5 proxy probe; coverage gaps; AC6/Goal wording) — all fixed in the wording written here.
- 2026-09-04: plan gate chose one release v2.2.0 at e0893aa carrying the whole former v1.4 body over splitting a v2.2.0 at dac1119 (2026-07-21) plus v2.3.0, because the v1.4 body covers both spans and splitting it would rewrite preserved notes; falsified by a reader needing the July and September changes dated separately.
- 2026-09-04: plan chose the release body as the notes of record (changelog file removed) over keeping CHANGELOG.md, because the 1.4 body already duplicated the file and rocker-bayes D-002 has the same shape; falsified by a consumer needing notes inside the repo checkout (the annotated tag message carries them).

- 2026-09-04: T1: captured all 14 release bodies under `cairn/milestones/M014-bodies/` (v0.1–v1.1 bodies carry CRLF, normalized to LF by git at commit; v1.2–v1.4, the AC3 bodies, carry none); pre-deletion tag→commit: v0.1→f48e0be, v0.2→8b0d8f9, v0.3→867f786, v0.4→6244d5c, v0.5→3ef2e7c, v0.6→375cd98, v0.7→17297c6, v0.8→1b60ada, v0.9→e4db9a9, v1.0→0230e8e, v1.1→36e36f6, v1.2→98f3a44, v1.3→11ef521, v1.4→e0893aa (only v1.4 was an annotated tag). Seven short bodies drafted from the commit diffs; shown at the implement gate.
- 2026-09-04: plan gate chose delete-old-then-create-new over create-new-then-delete-old (user choice: a clean slate); the captured bodies bound the recovery cost. Release window declared by the user at the gate ("create them now"); old bodies committed on the branch under `cairn/milestones/M014-bodies/`, deleted at archive.
- 2026-09-04: implement gate approved the remote operations (delete-then-create) and the seven plain-sentence bodies as drafted. T2: `gh release delete --cleanup-tag` removed all 14 releases and tags (`git ls-remote --tags origin` empty afterwards; the old tags had never been fetched locally, so `git tag -d` had nothing to remove); ten annotated tags created with `GIT_COMMITTER_DATE=<date> 12:00:00` and pushed. T3: remote lists exactly the ten map tags; each is type `tag`, points at the map commit, and carries the map taggerdate (AC1 by command).

## Decisions

## Review
