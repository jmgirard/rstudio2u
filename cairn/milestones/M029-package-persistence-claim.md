# M029: Correct the package persistence claim

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP1
- **Resolves:** —
- **Surface tier:** user-facing — README, Compose file, and launcher text that students read
- **Branch/PR:** m029-package-persistence-claim

## Goal

The README, the Compose file comment, and the stop launchers say truthfully where installed R packages live and when they are lost.

## Scope

**In:** a README section on keeping installed packages (where they live, the
four outcomes, a saved install script that restores them); corrected lines that
now say packages persist (README lines 42, 47–49, 107–108, 217; the
`docker-compose.yml` volume comment at line 15); a corrected closing message in
`stop_linux.sh`, `stop_mac.command`, and `stop_windows.bat`.

**Out:** changing where packages install, or a recipe for a package folder in
the home volume (D-014 keeps packages outside the volume). The "immutable tags"
wording → M030. The CRLF guard → M031. Syncing the new stop message into
rocker-bayes → rocker-bayes's own row "Catch launcher drift from rstudio2u".

## Acceptance criteria

- [ ] AC1: The README section on keeping packages states four outcomes for an R
      package installed with `install.packages()` in the Compose setup: kept
      after `docker compose stop` then `docker compose start`; lost after
      `docker compose down` then `docker compose up -d`; lost after
      `docker compose up -d` with a changed `RS_PORT`; lost after
      `docker compose up -d` when the image that `docker-compose.yml` names
      changed since the container was created, the case a start launcher meets
      when it downloads a newer `latest`. Each stated outcome matches a run with
      `image:` set to a published `noble-<date>` tag, and for the changed-image
      case, `image:` then changed to a second published `noble-` tag.
- [ ] AC2: The same section names `/usr/lib/R/site-library` and
      `/usr/local/lib/R/site-library` as the folders where `install.packages()`
      puts packages by default. This matches `.libPaths()` in a new container of
      a published `noble` tag, and `find.package()` for a package installed
      through bspm returns a path under one of the two.
- [ ] AC3: The section shows a saved install script kept in the home folder and
      run with `source()` to restore packages after Compose replaces the
      container, and running the README's example script in a new container of
      a published `noble` tag installs the packages it names.
- [ ] AC4: A read of every sentence in `README.md`, `docker-compose.yml`,
      `stop_linux.sh`, `stop_mac.command`, and `stop_windows.bat` at the
      milestone head finds none that says installed R packages, or the session
      as a whole, are kept when Compose replaces the container.
- [ ] AC5: The three stop launchers print the same closing statement apart from
      the start file's name, the verb for running it, and the status marker. It
      says that the files in the home folder are kept and does not say "resume
      where you left off". `scripts/tests/test_launcher_line_endings.sh` passes
      on the edited `stop_windows.bat`.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T2, T3, T4
- AC5 → T3

## Tasks

- [x] T1: Hand runs on two published `noble-<date>` tags through Compose: install
      a small package with `install.packages()`, read `.libPaths()` and
      `find.package()` (and `dpkg -s r-cran-<pkg>` for the bspm path), then run
      each of the four actions in AC1 and record kept or lost; run a saved
      `~/my_packages.R` in a new container. One work-log line per outcome.
- [x] T2: Write the README section "Keeping installed packages" under "Adding R
      Packages" from T1's observed results, and point the claims at README
      lines 47–49 and 107–108 to it.
- [x] T3: Reword the closing message in the three stop launchers, keeping
      `stop_windows.bat` CRLF; run `scripts/tests/test_launcher_line_endings.sh`.
- [x] T4: Reword README lines 42 and 217 and the `docker-compose.yml:15`
      comment; read every sentence of the five files for any remaining claim
      (AC4) and fix each one found.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — three independent README, launcher, and test fixes; this part needs a design choice on where packages live.
- 2026-11-05: idea vet: gap — "fix the claim" also fits making packages persist, which changes what users get; posed at the question set, answer: correct the text. No flaw.
- 2026-11-05: question set: how to fix the package claim — correct the text (D-014).
- 2026-11-05: plan gate chose correcting the text over a home-volume package folder or a default library in the volume because bspm installs system-wide and old copies in the volume would hide newer image packages; falsified by the base image moving installs into the home directory.
- 2026-11-05: collision check: absorbs candidate-less work from rocker-bayes row "Correct the claim in rstudio2u too" (rocker-bayes M011, its D-005); no row, milestone, or D-entry here overlaps. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: split: one request covering three independent fixes; M029 takes the package claim, M030 the tag claim, M031 the CRLF guard (planned now, no dependencies).
- 2026-11-05: criteria audit (full mode, fresh Opus reader): 4 findings, all fixed — AC1 needed two published tags for the changed-image case; AC2 one find.package() cannot show both folders; AC4 a word-stem grep was a proxy, now a read of every sentence; AC5 the messages already differ in verb and marker and launchers.yml never runs stop files, so the CI clause narrowed to the CRLF guard. AC3 no finding.
- 2026-11-05: decided the stop launchers change here even though rocker-bayes syncs them, because their "resume where you left off" carries the same claim.
- 2026-11-05: lessons used: 2026-07-18 (M05) on checking bspm's binary path with dpkg; 2026-11-05 (M023) on launchers.yml running only on pull requests.
- 2026-11-05: T1 probe: Compose project `m029probe` on `noble-2026-11-02` (arm64 Mac, Compose from Docker 29.9.2); `.libPaths()` lists `/usr/local/lib/R/site-library`, `/usr/lib/R/site-library`, `/usr/lib/R/library`; `install.packages("praise")` went through bspm to `/usr/lib/R/site-library/praise`, `dpkg -s r-cran-praise` installed.
- 2026-11-05: T1 outcome stop then start: same container, praise kept, home file kept.
- 2026-11-05: T1 outcome down then up -d: new container, praise lost, home file kept.
- 2026-11-05: T1 outcome up -d with RS_PORT 8797 → 8798: new container, praise lost, home file kept.
- 2026-11-05: T1 outcome up -d with image changed to `noble-2026-11-05`: new container, praise lost, home file kept. A `sudo apt-get install tree` was also lost after down then up.
- 2026-11-05: T1 saved script: in a new container of `noble-2026-11-05`, `source("~/my_packages.R")` with `sudo apt-get update && sudo apt-get install -y libfftw3-dev` and `install.packages(c("glmmTMB", "mice", "metafor"))` installed all four. Without `apt-get update`, `sudo apt-get install` in a brand-new container fails with "Unable to locate package" (empty apt lists), so the script keeps the update; README line 109's bare `sudo apt install` hint is the new candidate row "Add apt update to the README's apt hint".
- 2026-11-05: T2 probe: stop, then `docker compose pull` with no newer image, then `up -d --wait` (the start launcher's sequence) kept the same container (a9f692ab2afe) and praise.
- 2026-11-05: T2: README section "Keeping installed packages" added under "Adding R Packages" from the T1 and T2 runs; the "Your work is saved" note and the bullet at old line 107 point to it. The Simple English lint finds no new hit in the added lines (README total 52 → 51); the older hits are the new candidate row "Clear the README's plain-English hits".
- 2026-11-05: T3: the three stop launchers now say "Server stopped. The files in your home folder are kept." then Run/Double-click the start file "to start it again"; edited line by line so `stop_windows.bat` keeps CRLF; the CRLF guard passes (12 of 12 lines), `bash -n` passes on the two shell files, and `stop_linux.sh` printed the new message (shellcheck is not installed here; `lint.yml` runs it on the PR).
- 2026-11-05: T4: README step 5 of the Quick start and the FAQ update answer reworded, `docker-compose.yml` volume comment drops "installed R packages" (`docker compose config -q` passes). Sweep: located candidate sentences in the five files with a wide grep (packag, save, kept, keep, persist, surviv, preserv, resume, session, stay, your work) and read each, plus the renv paragraph; none says packages or the session are kept when Compose replaces the container. Lint delta vs main: one fewer semicolon, one fewer long sentence.

## Decisions

## Review
