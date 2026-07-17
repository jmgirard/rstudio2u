# Design

## Purpose & Scope

<!-- Seeded by cairn-init from README + Dockerfile; refine via /design-interview. -->

rstudio2u is a multi-arch (amd64 + arm64) Docker image that layers RStudio
Server, Pandoc, and Quarto on top of the rocker `r2u` base, giving fast binary
R package installation via bspm/apt. It targets classrooms and non-technical
users: double-click launcher scripts (macOS/Windows/Linux) wrap a Docker
Compose setup with a persistent home volume and no-auth localhost access.
All tags build from a single `Dockerfile`; the Ubuntu base is selected with
`UBUNTU_VERSION` (24.04 → `noble`/`latest`, 26.04 → `resolute`). Published to
Docker Hub as `jmgirard/rstudio2u`, with moving version tags plus immutable
tags for reproducibility. The image itself is the sole deliverable — no R
package or language-registry artifact ships from this repo.

## Function Families

<!-- The image has no exported functions; the analogous units are: -->

- **Install scripts** (`scripts/install_*.sh`): build-time installers for
  RStudio Server, Pandoc, Quarto, and the s6 init system (rocker-derived).
- **Runtime init** (`scripts/init_*.sh`, `default_user.sh`, `pam-helper.sh`):
  s6-driven container startup, user/env configuration.
- **Launchers** (`start_*`/`stop_*` at repo root): user-facing wrappers around
  `docker compose`.

## Conventions

<!-- Seeded honestly from the current Dockerfile/CI; refine via /design-interview. -->

- Dependency version policy: RStudio Server floats to newest stable at build
  time (`RSTUDIO_VERSION="stable"`, pinnable via build arg); Pandoc and Quarto
  default to the versions bundled with RStudio; s6-overlay is pinned exactly
  (`S6_VERSION`). Base image is pinned to a versioned tag
  (`rocker/r2u:<ubuntu-version>`), never `latest`.
- CI (`.github/workflows/docker.yml`) builds both variants for
  `linux/amd64,linux/arm64` on push to main and on a weekly schedule to pick
  up base-image security updates.
- User-facing docs (README) never reference milestone numbers.

## Design Principles

<!-- IP<n> = Inviolable (hard constraint) first, then GP<n> = Guiding
     (tradeable with justification). Numbers never reused. None elicited yet —
     run /design-interview to populate. -->

## Architecture

Single-stage `Dockerfile`: rocker/r2u base → COPY `scripts/` →
install RStudio/Pandoc/Quarto → configure bspm (sudo mode) and staff-group
R library permissions → healthcheck on :8787 → s6 `/init` entrypoint.
`docker-compose.yml` provides the named home volume and port mapping the
launchers rely on.

## Known issues

<!-- None recorded yet. -->
