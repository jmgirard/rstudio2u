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

<!-- IP<n> = Inviolable first, then GP<n> = Guiding. Numbers never reused.
     Phase 2 of /design-interview pending — candidates banked below. -->

### Banked candidates (interview 2026-07-17, Phase 2 pending)

1. Infrastructure-only boundary — no preinstalled R packages (candidate IP).
2. Root-capable is the permanent identity; no locked-down mode ships here;
   no-auth defaults only ever behind a localhost bind (candidate IP).
3. Frozen runtime interface (port/user/volume/env/entrypoint) (candidate IP).
4. Classroom-first tiebreaker — double-click simplicity outranks
   flexibility (candidate GP).
5. amd64+arm64 parity; all three launchers supported (candidate GP or IP).
6. Always-fresh moving tags; every moving tag has an immutable escape hatch
   (candidate GP; escape-hatch half derived from the tag scheme).
7. Owned-fork scripts posture — simplify freely, hand-pick upstream fixes
   (candidate GP).
8. Resolute is preview tier; Docker Hub is the sole registry (likely
   conventions, not principles — classify or skip in Phase 2).

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
  endpoint with grep; a format change breaks tag naming or pins wrongly.
- arm64 relies on bundled/symlinked fallbacks in places where upstream only
  ships amd64 (see `install_quarto.sh`); parity can silently diverge.
- The Windows launcher path sees the least real-world testing.
- `scripts/` is a fork of rocker_scripts: upstream fixes do not flow in
  automatically (accepted cost of the owned-fork posture).
