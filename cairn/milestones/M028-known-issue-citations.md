# M028: Replace numbered Known issue citations

- **Status:** in-progress
- **Priority:** low
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — the `mirror_hint.R` header comment is appended to the image's `/etc/R/Rprofile.site`, where users can read it
- **Branch/PR:** m028-known-issue-citations

## Goal

Replace the code comments that cite "Known issue #1" and "#2" by position in
DESIGN.md's unnumbered Known issues list with wording that stays correct when
that list changes.

## Scope

**In:**
- The four comments that cite a Known issue by number: the apt-retries comment
  and the `mirror_hint.R` append comment in `Dockerfile`, the header of
  `scripts/resolve-rstudio-version.sh`, and the header of `scripts/mirror_hint.R`.
- Each keeps naming in words the problem its code guards against. The numbered
  citation is deleted or replaced by that wording. A principle id a comment
  already carries stays (`GP2` in `resolve-rstudio-version.sh`). No principle
  id is added where no principle governs the code.

**Out:**
- `cairn/` files: the archive is history and is never edited; DESIGN.md has no
  numbered citation.
- The stale `cairn/references/pdf/` entry in `.gitignore` → the candidate row
  "Remove the old pdf .gitignore entry".

## Acceptance criteria

- [ ] AC1: `git grep -niE 'known[ -]issues?:? ?(#|no\.? ?)?[0-9]' -- ':!cairn'`
      prints nothing on the milestone branch.
- [ ] AC2: Each of the four In-scope comments, found by its content, still names
      in words the problem its code guards against (an unreliable or
      unreachable r2u mirror, or a change to the format of the RStudio update
      endpoint), and the `resolve-rstudio-version.sh` header still cites `GP2`.
- [ ] AC3: The branch changes only comments: in `git diff main...HEAD -- .
      ':!cairn'`, every added or removed line, after its leading `+` or `-`, is
      blank or has `#` as its first non-space character (the `+++` and `---`
      file headers excluded), and `hadolint Dockerfile` reports no violations
      (run locally or as the `hadolint/hadolint` container).

## Coverage

- AC1 → T1, T2
- AC2 → T1
- AC3 → T1, T2

## Tasks

- [x] T1: Rewrite the four comments (`Dockerfile:46`, `Dockerfile:54`,
      `scripts/resolve-rstudio-version.sh:9`, `scripts/mirror_hint.R:2` at plan
      time), keeping each sentence's description of the problem and the `GP2`
      citation.
- [ ] T2: Run the AC1 grep, the AC3 diff check, and hadolint. Run
      `docker build .` as the profile's verify slot asks; a failure there that
      comes from rstudio.org or the r2u mirror is logged, not fixed, and
      `pr-ci.yml`'s build and smoke test on the PR stay the build gate before
      merge.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: gap — the row asks for principle citations, but no principle governs the mirror retries or hint; reading taken: name the problem in words, keep GP2 where it stands, add no principle id. No other reading changes what users see, so no question.
- 2026-11-05: lessons used: none.
- 2026-11-05: question set: work chosen — the candidate row "Replace numbered Known issue citations"; run — plan and implement.
- 2026-11-05: absorbed candidate row "Replace numbered Known issue citations" in full; the row named two script sites, and the plan's grep found two more in `Dockerfile`.
- 2026-11-05: collision check: M015 (done) replaced "Known issue #3" the same way; no D-entry covers citations; inbox sweep found 0 open issues and 0 open PRs.
- 2026-11-05: a merge that touches `Dockerfile` or `scripts/` starts `docker.yml`, which rebuilds and publishes the images; the merge approval covers it, and D-005 gives a comment change no release.
- 2026-11-05: plan gate chose naming each problem in words over numbering DESIGN.md's Known issues list, because entries are added and removed and numbers would need a never-reuse rule like the principles; falsified by a Known issue that a code comment cannot describe in one clause.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): 5 findings, all fixed — AC1 grep widened to "known-issue", "no." and bare-number forms (still the same 4 hits today); AC2 names sites by content, not line; AC3 names `main`, defines a comment line and excludes diff headers; `docker build .` moved from AC3 to T2 because it depends on rstudio.org and the r2u mirror, with the PR build as the gate.
- 2026-11-05: status in-progress; branch m028-known-issue-citations cut from main at f9b9dcb.
- 2026-11-05: T1 done: each numbered citation deleted, since every sentence already names its problem in words (Dockerfile lines 45 and 52, `mirror_hint.R` lines 1-2 and 4, `resolve-rstudio-version.sh` lines 5-9); `(Known issue #2 / GP2)` became `(GP2)`.

## Decisions

## Review
