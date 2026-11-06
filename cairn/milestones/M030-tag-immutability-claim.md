# M030: Stop calling the Docker tags immutable

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — README pinning advice that courses follow
- **Branch/PR:** m030-tag-immutability-claim

## Goal

The README, `cairn/DESIGN.md`, and the publish workflow's comments say truthfully which Docker tags can move, so a user who pins one for reproducibility gets what the text promises.

## Scope

**In:** the README's Reproducibility section and the lines that point to it
(19, 21, 116, 138–146); GP2's wording (D-015) and the "immutable" in DESIGN.md
Purpose & Scope and Conventions; the "immutable" in the comments of
`.github/workflows/docker.yml` (lines 35, 276–278) and of
`.github/workflows/pr-ci.yml` (line 84); a README digest pin that covers both
architectures.

**Out:** changing which tags the publish job moves (D-015 keeps it; the freeze
alternative needs a new decision first). The package claim → M029. The CRLF
guard → M031. rocker-bayes's own tag text → done there (its M014).

## Acceptance criteria

- [x] AC1: A read of `README.md`, `cairn/DESIGN.md`, and the comments in
      `.github/workflows/docker.yml` at the milestone head finds nothing that
      calls a date tag or an RStudio-version tag immutable or unchanging.
- [x] AC2: The README's Reproducibility section says that a `<variant>-<date>`
      tag names the date its build started (UTC) and can move to a later build
      with the same date, that a `<variant>-<rstudio>` tag moves with each
      publish while that RStudio version is current, and that an image digest
      never moves. The first two statements match the tag list that
      `.github/workflows/docker.yml` computes and the rule in
      `.github/tag-order.sh`, and the second also matches Docker Hub, where the
      current `noble-<rstudio>` tag and the latest-dated `noble-<date>` tag show
      the same index digest when read at review.
- [x] AC3: The section shows how to read a tag's digest and how to pin it in the
      `image:` line of `docker-compose.yml` and in a `FROM` line. Running the
      shown read command against a published tag prints a digest, `docker pull`
      of the pinned `jmgirard/rstudio2u@sha256:…` reference succeeds, and
      `docker buildx imagetools inspect` of that reference lists both
      `linux/amd64` and `linux/arm64`.
- [x] AC4: GP2 in `cairn/DESIGN.md` reads: "Moving tags track newest stable
      automatically; every build also publishes date and version tags, and the
      README keeps teaching courses to pin a tag or digest. Freshness may never
      shed its escape hatch."

## Coverage

- AC1 → T2, T3, T4
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3

## Tasks

- [x] T1: Read the tag rules in `docker.yml` (meta job date, tag list) and
      `.github/tag-order.sh`; read Docker Hub digests for the current
      `noble-<rstudio>` and latest `noble-<date>` tags; run the digest read
      command and a pinned `docker pull`; one work-log line each.
- [x] T2: Rewrite the README's Reproducibility section from T1's results, with
      the digest pin for Compose and `FROM`; reword lines 19, 21, and 116 to
      point to it.
- [x] T3: Set GP2 to the AC4 wording and drop "immutable" from DESIGN.md Purpose
      & Scope and Conventions, marked `corrected M030`.
- [x] T4: Drop "immutable" from the `docker.yml` comments; read the three files
      whole for any remaining claim (AC1). A `docker.yml` edit publishes on
      merge, the same as a weekly rebuild.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — three independent README, launcher, and test fixes; this part changes a design principle (GP2).
- 2026-11-05: idea vet: gap — "fix the claim" also fits freezing tags at first publish, which changes what users get; posed at the question set, answer: reword and teach digests. No flaw.
- 2026-11-05: question set: how to fix the immutable-tags claim, and approval of GP2's new wording — reword and teach digests; GP2 wording approved (D-015).
- 2026-11-05: plan gate chose rewording over freezing tags at first publish because a frozen RStudio-version tag would stop getting weekly base-image security updates; falsified by courses reporting that a moved version tag broke their setup.
- 2026-11-05: collision check: D-005 calls the tags immutable; D-015 annotates its word. Absorbs rocker-bayes row "Stop calling rstudio2u tags immutable" (rocker-bayes M014, its D-006). Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): 4 findings, all fixed — AC1 a word grep was a proxy, now a read of three files; AC2 the date is the build's start date and tag-order.sh orders by stamp, so "last image published that day" was wrong; AC3 a per-platform digest would pass, so the pin must list both architectures; AC4 needed the user's approval and a D-entry (D-015).
- 2026-11-05: lessons used: 2026-11-05 (M026) on reading a registry answer with jq -s.
- 2026-11-05: in-progress; branch m030-tag-immutability-claim cut from origin/main at f5832b2.
- 2026-11-05: T1 tag rules: docker.yml's meta job takes DATE from one `date -u` stamp before any build, and publish attaches `<variant>-$DATE` and `<variant>-$RSVER` every run; tag-order.sh keeps a tag unless its index carries a later stamp, so a later run with the same date moves the date tag.
- 2026-11-05: T1 Docker Hub (tags API, read 2026-11-05): `noble-2026.10.1-239` and `noble-2026-11-05` both at sha256:a1f45fc4…c4e, last updated 22:55Z the same run; `noble-2026-11-02` at sha256:f438eafa…, so the version tag moved off it.
- 2026-11-05: T1 `docker buildx imagetools inspect jmgirard/rstudio2u:noble-2026-11-05 --format '{{.Manifest.Digest}}'` printed sha256:a1f45fc4…c4e; `docker pull jmgirard/rstudio2u@sha256:a1f45fc4…c4e` succeeded; imagetools inspect of that ref lists linux/amd64 and linux/arm64.
- 2026-11-05: decided: the README shows the `--format '{{.Manifest.Digest}}'` read, because it reads the registry without a pull and prints only the digest.
- 2026-11-05: revised: the README shows plain `docker buildx imagetools inspect <tag>` and names its `Digest:` line, because cmd.exe passes the single-quoted `--format` template wrongly.
- 2026-11-05: minor amendment: the README lines that point to Reproducibility are now 19, 21, and 159 (the Baking section's pin line), not 116 and 138–146; the plan's numbers predate M029's README edits.
- 2026-11-05: T2 README: Reproducibility rewritten (moving date and version tags, digest read, Compose and FROM pins); lines 19, 21, and the Baking pin line point to digests. Scratch checks: `docker compose config` and `pull` accept an `image:` digest pin, `FROM <image>@sha256:…` builds, and the launchers' `config --images` plus `image inspect` check finds the pulled digest. Lint hits on README remain only in text the branch did not write.
- 2026-11-05: T3 DESIGN.md: GP2 set to the AC4 wording (whitespace-normalized match checked) with `(corrected M030, D-015)`; Purpose & Scope and the "Two version records" convention drop "immutable", each marked `corrected M030`.
- 2026-11-05: T4 docker.yml: four comments drop "immutable" (meta job header, resolver step, tag-list step); the tag-list comment now says both tags can move and points to the README. `git diff` shows only comment lines changed; actionlint is not installed here, so CI checks the file. A read of README, DESIGN.md, and docker.yml's tag comments for frozen/unchanging/never-moves wording finds no claim left about date or version tags.
- 2026-11-05: claim audit: 25 claims read, 0 corrected — .github/workflows/docker.yml, README.md (fresh Opus reader; it also flagged "immutable" in pr-ci.yml line 84, outside the diff).
- 2026-11-05: substantive amendment: Scope In adds the "immutable" in the comments of `.github/workflows/pr-ci.yml` (line 84), found by the claim audit; comment wording only, no criterion changed. pr-ci.yml line 84 now reads "produces no date or version tags"; a repo-wide grep outside cairn/ finds no other "immutable".
- 2026-11-05: verify: the branch changes no Dockerfile or build context, so the profile's hadolint + build gate does not apply (hadolint is not installed here); cairn_validate passes. Status review.

## Decisions

## Review

- AC1 evidence (2026-11-06, head 3183421): grep of README.md, cairn/DESIGN.md, docker.yml for immutab/unchang/frozen/freez/never change/never move/not change/identical finds only digest lines (README 19, 196, 198; DESIGN 25; docker.yml 279) and the frozen runtime interface (DESIGN 61, IP3 207); a read of the README Reproducibility section, DESIGN Purpose & Scope, Conventions, GP2, and docker.yml's tag comments (35, 60, 276–282) finds no claim that a date or RStudio-version tag is fixed. Pass.
- AC2 evidence: README Reproducibility says the date tag names the UTC date its build started and moves to a later build with the same date, the version tag moves with each new build while that version is the newest stable, and a digest never moves. Code: docker.yml 74 `DATE=${STAMP%%T*}` from the meta job's one `date -u` read; 300–301 attach `<variant>-$DATE` and `<variant>-$RSVER` every publish; tag-order.sh 197 leaves a tag out only when its stamp is later than the run's, so a later same-date run moves it. Docker Hub read 2026-11-06T00:18Z: current `noble-2026.10.1-239` (resolver prints 2026.10.1-239) and latest-dated `noble-2026-11-05` both at sha256:a1f45fc4…4c4e. Pass.
- AC3 evidence: the section shows the read (`docker buildx imagetools inspect <tag>`, its `Digest:` line), a Compose `image:` pin, and a `FROM` pin. Run 2026-11-06: the read of `noble-2026-11-05` printed `Digest: sha256:a1f45fc4…4c4e`; `docker pull jmgirard/rstudio2u@sha256:a1f45fc4…4c4e` exited 0; imagetools inspect of that ref lists linux/amd64 and linux/arm64. Pass.
- AC4 evidence: whitespace-normalized cairn/DESIGN.md contains "GP2: **Always fresh, always an escape hatch.** Moving tags track newest stable automatically; every build also publishes date and version tags, and the README keeps teaching courses to pin a tag or digest. Freshness may never shed its escape hatch." (check printed True), followed by `(corrected M030, D-015)`. Pass.
- gate: cairn_validate all checks passed; cairn_impact GP2 lists DESIGN 148, 163, 216 and six ROADMAP rows, each read and consistent with the new wording (none relies on fixed tags); `--changed` reports none because it reads the working tree.
- gate (docker-image slot): `git diff main...HEAD -- Dockerfile scripts .dockerignore` is empty and `.dockerignore` drops README, .github, cairn, so the build input equals main's; hadolint is not installed locally, and pr-ci.yml (triggered by the `.github/workflows/**` change) builds the image and lints on the PR, which the merge wait requires green. Base image still `rocker/r2u:${UBUNTU_VERSION}`; no secrets touched; `.dockerignore` present. Changelog none: user-visible change goes in the archive summary.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: the `@sha256:<digest>` placeholder invites a doubled `sha256:` prefix, which `docker compose pull` rejects as an invalid reference — fix now, fixed 7ddcc15 (snippets read `@<digest>`, text says the digest is the whole value).
- diff-bug #2: a digest pin breaks the README's `docker compose up --build -d` option — fix now, fixed 7ddcc15 (run here: Compose build stops with "build tag cannot contain a digest"; README now says start with a start file or `pull` + `up -d`, without `--build`).
- diff-bug #3: the read command needs buildx, which a distro Docker can lack — fix now, fixed 7ddcc15 (`docker pull <tag>` fallback; run here, it prints the same index digest).
- diff-bug #4: DESIGN "date and version tags record builds" is loose, since the tags move — fix now, fixed 7ddcc15 (digests, named by those tags, record builds).
- diff-bug #5: the README omits that a digest pin gets no security updates — fix now, fixed 7ddcc15 (one sentence: move the pin between terms).
- diff-bug #6: a digest whose tag moved is untagged, so a future Hub prune could delete a pinned image — follow-up: absorbed into the parked row "Prune untagged manifests on Docker Hub" (stays parked; its condition has not held, and no prune runs today).
- diff-bug #7: "newest build that started on that date" can fail when two publishes interleave — follow-up: already recorded in DESIGN.md (tag-order bounds: the read and the create are not atomic); no new row, since only concurrent publishes reach it.
- diff-bug #8: moving tags move on every rebuild, not only on new versions (pre-existing wording on README 19 and 179) — fix now, fixed 7ddcc15 (both lines in the rewritten section's scope).
- diff-bug #9: "never changes" is broader than a derivative `FROM` pin, whose installed packages float — fix now, fixed 7ddcc15 (README says the packages still come from r2u at rebuild and points to renv).
- diff-bug #10: pr-ci.yml line 84 is 83 characters and docker.yml 35 reflows unevenly — reject: style.
- blame-history #1: the Baking `FROM` example no longer copy-pastes — fix now, fixed 7ddcc15 (a comment line says what to put in place of `<digest>`); a literal digest would go stale.
- blame-history #2: the example tag `noble-2026-11-05` may not exist — reject: false; the tags API lists it at sha256:a1f45fc4…4c4e, and date tags are not deleted.
- blame-history #3: README 21 does not say `noble`/`noble-` tags move — reject: false; the sentence claims only that they stay on Ubuntu 24.04, and line 19 says they move.
- blame-history #4: a 64-character digest pin is harder for courses than a date tag (GP1) — reject: planned change (D-015, approved at the plan gate).
- blame-history #5: docker.yml comments match tag-order.sh — noted, no finding.
- blame-history #6: inline `(corrected M030)` markers mid-sentence — reject: style; matches the existing `(corrected M015)` pattern.
- prior-review #1: "each run moves the version tag" omits that an older run's re-run cannot move a tag back — fix now, fixed 7ddcc15 (docker.yml comment says "each newer run" and names tag-order.sh; the README's "each new build" already holds).
- prior-review #2: D-015 is not in the diff — reject: false; D-015 is on main at cairn/DECISIONS.md:250.
- ripple #1: DESIGN "fails every publish, because each run's date tag is new and so absent" disagrees with same-date runs — fix now, fixed 7ddcc15 (first run on its date, marked corrected M030).
- ripple #2: DESIGN 147 and ROADMAP 31 "new date and version tags" — reject: false; "new" there names the tags the run would attach, not a claim that they never move.
- ripple #3: the `mutable:` matrix key now differs from the comment's "Moving tags" — reject: style.
- ripple #4: the M030 ROADMAP title still says "immutable" — reject: false; it names the milestone, not a current claim, and the row archives at hygiene.
- ripple #5–10: Dockerfile build-arg example, test fixtures, CITATION.cff, docker-compose.yml, README 135, PROFILE base-image pin — noted, no finding.
- re-verify after 7ddcc15: AC1 grep of the three files finds only digest lines and the frozen runtime interface; AC3's section still shows the read, the Compose pin, and the `FROM` pin, and the substituted reference is `jmgirard/rstudio2u@sha256:…`; both workflow files parse (Ruby YAML) with only comment lines changed; README lint hits remain only in text the branch did not write; cairn_validate below.
