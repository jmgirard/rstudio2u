# Design

## Purpose & Scope

rstudio2u is a multi-arch (amd64 + arm64) Docker image that layers RStudio
Server, Pandoc, and Quarto on top of the rocker `r2u` base, giving fast binary
R package installation via bspm/apt. **Classroom first:** the design center is
non-technical students using the double-click launchers
(macOS/Windows/Linux), which wrap a Docker Compose setup with a persistent
home volume and no-auth localhost access; when audience needs conflict, the
simplicity of that path wins (interview 2026-07-17). General `docker run`
users and derivative-image authors are served but do not set the design.

**Contract boundary — infrastructure only.** The image ships the IDE and
toolchain (RStudio Server, Pandoc, Quarto, bspm, s6 init) and nothing that
bspm/apt can cheaply deliver at runtime; no preinstalled R packages, ever —
fast runtime binary install is the point of r2u.

All tags build from a single `Dockerfile`; the Ubuntu base is selected with
`UBUNTU_VERSION`. `noble`/`latest` (24.04) is the committed variant;
`resolute` (26.04) is **preview tier** — a resolute-only failure does not
block shipping noble. Both architectures are hard commitments. Published to
Docker Hub as `jmgirard/rstudio2u` (single registry, by choice), with moving
tags plus immutable `<variant>-<date>` and `<variant>-<rstudio>` tags for
reproducibility.

## Function Families

- **Install scripts** (`scripts/install_*.sh`): build-time installers for
  RStudio Server, Pandoc, Quarto, and the s6 init system. An **owned fork**
  of rocker_scripts: upstream is reference only; local simplification is
  allowed and upstream fixes are hand-picked (interview 2026-07-17).
- **Runtime init** (`scripts/init_*.sh`, `default_user.sh`, `pam-helper.sh`):
  s6-driven container startup, user/env configuration.
- **Launchers** (`start_*`/`stop_*` at repo root): user-facing wrappers around
  `docker compose`. All three OS launchers are supported surfaces — a
  launcher break is a user-visible bug (hotfix tier).

## Conventions

- **Runtime interface is frozen:** port 8787, user `rstudio`, home volume at
  `/home/rstudio`, env vars `PASSWORD`/`ROOT`/`DISABLE_AUTH`/`USERID`, s6
  `/init` entrypoint. A semester-old `docker-compose.yml` or derivative
  `FROM` keeps working against moving tags; breaking any of it requires a
  deprecation period and README notice.
- **Always-fresh is a commitment:** moving tags track the newest stable
  RStudio (and bundled Pandoc/Quarto) via weekly no-cache CI rebuilds; R
  floats with the r2u base. Silent failure of the rebuild or version
  auto-detect is a bug worth engineering against. s6-overlay is pinned
  exactly (`S6_VERSION`); base image is pinned to a versioned tag, never
  `latest`.
- **Security model:** root-capable by design (passwordless sudo so bspm can
  install system binaries); safety comes from the localhost-only bind.
  Compose/launcher defaults never publish the port beyond `127.0.0.1` while
  auth is disabled.
- CI (`.github/workflows/docker.yml`) builds both variants for
  `linux/amd64,linux/arm64` on push to main and weekly.
- User-facing docs (README) never reference milestone numbers.

## Design Principles

<!-- IP<n> = Inviolable (hard constraint; changing one takes a D-entry) first,
     then GP<n> = Guiding (tradeable with stated justification). Numbers are
     never reused or renumbered. Adopted in the 2026-07-17 design interview. -->

- IP1: **Infrastructure only.** The image ships nothing bspm/apt can cheaply
  deliver at runtime; no preinstalled R packages, ever. The
  runtime-deliverability test decides edge cases.
- IP2: **Root-capable is the identity.** No locked-down mode ships from this
  repo (rocker/rstudio exists for that), and no default — compose, launcher,
  or doc example — ever pairs disabled auth with a bind beyond `127.0.0.1`.
- IP3: **The runtime interface is frozen.** Port 8787, user `rstudio`,
  `/home/rstudio` volume, `PASSWORD`/`ROOT`/`DISABLE_AUTH`/`USERID`, s6
  `/init` keep working against moving tags; changes require a deprecation
  period and README notice — never a silent break.
- IP4: **Student work is sacrosanct.** Stopping, restarting, and updating
  never destroy the home volume; no launcher or documented flow wipes data
  implicitly — only an explicit, warned command may.
- GP1: **Classroom first.** When audience needs conflict, the simplicity of
  the double-click path wins.
- GP2: **Always fresh, always an escape hatch.** Moving tags track newest
  stable automatically; every build also publishes immutable date/version
  tags, and the README keeps teaching courses to pin. Freshness may never
  shed its escape hatch.
- GP3: **Both architectures, all three launchers.** amd64/arm64 parity and
  macOS/Windows/Linux launcher coverage are supported surfaces; a break is a
  ship-blocking or hotfix-tier bug (documented temporary asymmetry allowed
  when an upstream forces it).
- GP4: **Owned fork.** `scripts/` is this repo's code: simplify freely;
  upstream rocker fixes are hand-picked, not synced.
- GP5: **Lean image.** Size is a feature; additions justify their megabytes,
  and periodic slimming is licensed work.
- GP6: **One Dockerfile.** All variants build from a single Dockerfile via
  build args, never per-variant forks.
- GP7: **Never knowingly ship a broken moving tag.** An unattended rebuild
  must not publish an image whose server fails to come up (see M01 for the CI
  smoke test closing the current gap).

## Architecture

Single-stage `Dockerfile`: rocker/r2u base → COPY `scripts/` →
install RStudio/Pandoc/Quarto → configure bspm (sudo mode) and staff-group
R library permissions → healthcheck on :8787 → s6 `/init` entrypoint.
`docker-compose.yml` provides the named home volume and the
`127.0.0.1`-only port mapping the launchers rely on.

## Known issues

_Warts confirmed in the 2026-07-17 interview:_

- The server bspm downloads r2u binaries from can be unreliable — runtime
  package installs can fail through no fault of the image.
- CI's RStudio version auto-detect scrapes rstudio.org's check_for_update
  endpoint; the scraped value is now validated against the expected version
  shape, so a format change fails the build loudly instead of mis-tagging
  (M03) — the scrape still depends on that endpoint's format.
- arm64 relies on bundled/symlinked fallbacks in places where upstream only
  ships amd64 (see `install_quarto.sh`); parity can silently diverge.
- The Windows launcher path sees the least real-world testing.
- `scripts/` is a fork of rocker_scripts: upstream fixes do not flow in
  automatically (accepted cost of the owned-fork posture).
