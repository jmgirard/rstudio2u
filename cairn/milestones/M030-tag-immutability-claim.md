# M030: Stop calling the Docker tags immutable

- **Status:** in-progress
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
`.github/workflows/docker.yml` (lines 35, 276–278); a README digest pin that
covers both architectures.

**Out:** changing which tags the publish job moves (D-015 keeps it; the freeze
alternative needs a new decision first). The package claim → M029. The CRLF
guard → M031. rocker-bayes's own tag text → done there (its M014).

## Acceptance criteria

- [ ] AC1: A read of `README.md`, `cairn/DESIGN.md`, and the comments in
      `.github/workflows/docker.yml` at the milestone head finds nothing that
      calls a date tag or an RStudio-version tag immutable or unchanging.
- [ ] AC2: The README's Reproducibility section says that a `<variant>-<date>`
      tag names the date its build started (UTC) and can move to a later build
      with the same date, that a `<variant>-<rstudio>` tag moves with each
      publish while that RStudio version is current, and that an image digest
      never moves. The first two statements match the tag list that
      `.github/workflows/docker.yml` computes and the rule in
      `.github/tag-order.sh`, and the second also matches Docker Hub, where the
      current `noble-<rstudio>` tag and the latest-dated `noble-<date>` tag show
      the same index digest when read at review.
- [ ] AC3: The section shows how to read a tag's digest and how to pin it in the
      `image:` line of `docker-compose.yml` and in a `FROM` line. Running the
      shown read command against a published tag prints a digest, `docker pull`
      of the pinned `jmgirard/rstudio2u@sha256:…` reference succeeds, and
      `docker buildx imagetools inspect` of that reference lists both
      `linux/amd64` and `linux/arm64`.
- [ ] AC4: GP2 in `cairn/DESIGN.md` reads: "Moving tags track newest stable
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

## Decisions

## Review
