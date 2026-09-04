# M014: Semver release history

**Status:** done (2026-09-04, PR #21 https://github.com/jmgirard/rstudio2u/pull/21)

**Goal:** Replace the fourteen meaningless `v0.1`–`v1.4` git tags and GitHub releases with a semver history of recipe changes, and make the GitHub release body, not a changelog file, the notes of record.

**Outcome:** Fourteen tags/releases deleted; ten annotated tags v1.0.0, v1.0.1,
v1.1.0, v1.1.1, v1.1.2, v1.1.3, v1.2.0, v2.0.0, v2.1.0, v2.2.0 created with
`GIT_COMMITTER_DATE` backdated to their commits and `--cleanup=verbatim`, each
with a release whose body equals the tag message (v2.2.0 Latest). The v2.x
bodies carry the former v1.2/v1.3/v1.4 notes; the seven earlier bodies were
written from the commit diffs. `CHANGELOG.md` removed (and its `.dockerignore`
line); PROFILE `## changelog` → none as a file, release-walk rewritten around
the tag message/release body and `docker.yml`'s path-gated publish; README
Reproducibility paragraph and DESIGN "Two version records" convention state
the major/minor/patch rule; ROADMAP header names the 2.2.0 release.

**Decisions:** D-005 (two version records; release body is the notes of record);
D-006 (the one exception: v2.1.0/v2.2.0 compare links retargeted to the new tags).

**Review:** three-lens fan-out, two rounds. Round 1: AC3 amendment return (compare
links retargeted), v1.1.0 and v1.1.2 bodies rewritten from their commits, PROFILE
publish wording fixed; D-005 enumeration and ROADMAP stamp findings rejected.
Round 2: D-006 written; v1.0.0/v1.1.3 fold notes and the body captures noted.
History and prior-review lenses clean both rounds. PR reported no checks (path
filters); merged on local green. `M014-bodies/` captures deleted at archive.
