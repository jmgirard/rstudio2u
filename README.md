# rstudio2u

[![Build](https://github.com/jmgirard/rstudio2u/actions/workflows/docker.yml/badge.svg)](https://github.com/jmgirard/rstudio2u/actions/workflows/docker.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/jmgirard/rstudio2u)](https://hub.docker.com/r/jmgirard/rstudio2u)
[![Image Size](https://img.shields.io/docker/image-size/jmgirard/rstudio2u/latest)](https://hub.docker.com/r/jmgirard/rstudio2u)
[![License: MIT](https://img.shields.io/github/license/jmgirard/rstudio2u)](LICENSE)

Adds RStudio Server, pandoc, and Quarto to [r2u](https://github.com/rocker-org/r2u), works on AMD64 and ARM64 (e.g., Apple Silicon)

Binary package installation from within R via [bspm](https://cloud.r-project.org/package=bspm) for faster installs and smaller image size

| Tag                 | Base image         | Architectures | RStudio version |
| ------------------- | ------------------ | ------------- | --------------- |
| `latest`, `noble`   | `rocker/r2u:24.04` | amd64, arm64  | latest stable   |
| `resolute`          | `rocker/r2u:26.04` | amd64, arm64  | latest stable   |

The R version is whatever the underlying [r2u](https://github.com/rocker-org/r2u) base image ships, and RStudio Server defaults to the newest stable release at build time. All tags are built from a single [`Dockerfile`](Dockerfile); select the base with the `UBUNTU_VERSION` build argument (e.g. `--build-arg UBUNTU_VERSION=26.04` for `resolute`) and pin RStudio with `--build-arg RSTUDIO_VERSION=<version>` if you need a specific version.

These tags **move** as new versions are released. For a frozen, identical environment (e.g. a course), pin an immutable tag instead — see [Reproducibility](#reproducibility).

## Use Examples

### Quick start (recommended): double-click launcher

The easiest way to run the server, good for classrooms and non-technical users.

1. Install and open [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Download this repository (green **Code** button → **Download ZIP**, then unzip)
   or `git clone https://github.com/jmgirard/rstudio2u`
3. Double-click the launcher for your system:
   - **macOS:** `start_mac.command` — the first time, right-click it and choose
     **Open** to get past Gatekeeper (double-click works every time after that)
   - **Windows:** `start_windows.bat`
   - **Linux:** `start_linux.sh`
4. It downloads the latest image, starts the server, waits until it is ready,
   and opens <http://localhost:8787> in your browser (no username or password)
5. When you are done, double-click the matching `stop_...` file. Your session is
   preserved; run the start file again to resume.

The launchers just wrap the Docker Compose commands below, so Docker Desktop must
be installed and running.

> **Your work is saved.** The Compose setup stores the home directory (your
> files, settings, and installed R packages) in a Docker named volume, so it
> survives stopping, restarting, and even updating to a newer image. To wipe it
> and start completely fresh, run `docker compose down -v`.

### Option 1: Pull and run from Dockerhub

1. Install and open [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Enter the following command in your terminal

    ```
    docker pull jmgirard/rstudio2u
    docker run --rm -p 8787:8787 -e PASSWORD=pass -t jmgirard/rstudio2u
    ```

3. Navigate to <http://localhost:8787> and enter username `rstudio` and password `pass`
4. Whenever you use `install.packages()` or `update.packages()`, it will use bspm
5. When done, open Docker Desktop and end the container
6. Next time, you don't need to run `docker pull...` again

### Option 2: Clone, build, and compose

1. Install and open [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Install [Git](https://git-scm.com/downloads)
3. Enter the following command in your terminal

    ```
    git clone https://github.com/jmgirard/rstudio2u
    cd rstudio2u
    docker compose up --build -d
    ```
4. Navigate to <http://localhost:8787> (no username or password needed)
5. Whenever you use `install.packages()` or `update.packages()`, it will use bspm
6. When done, open Docker Desktop and end the container
7. Next time, you don't need to run `git clone...` again

### Getting files in and out

Because the home directory lives in a Docker volume (not an ordinary host
folder), move files through RStudio or Docker:

- **In RStudio (easiest):** use the **Upload** button in the Files pane to bring
  files in, and select a file then **More → Export** to download it out.
- **From a terminal:** with the server running,
  `docker compose cp ./data.csv rstudio2u:/home/rstudio/` copies a file in, and
  `docker compose cp rstudio2u:/home/rstudio/results.csv ./` copies one out.

If you would rather work directly in a folder on your own computer, replace the
`rstudio_home` volume in `docker-compose.yml` with a bind mount, e.g.
`- ./workspace:/home/rstudio/workspace`, and keep your work in that folder.

## Adding R Packages

Thanks to [bspm](https://cloud.r-project.org/package=bspm), packages install as
precompiled binaries — fast, with no compiling.

**Interactively (in a running container):**

- In the RStudio console, `install.packages("dplyr")` transparently pulls the
  binary via bspm; you don't need to do anything special.
- Packages installed this way persist in the home volume (see above), so they
  are still there next time you start the server.
- If a package needs a system library, open the RStudio **Terminal** and
  `sudo apt install <libfoo-dev>` (rarely needed — bspm resolves most
  dependencies for you).

**Baking packages into your own image (recommended for a course or lab):**

Build a small image on top of rstudio2u so everyone gets the same packages
preinstalled. Pin an immutable tag (see below) for reproducibility:

```dockerfile
FROM jmgirard/rstudio2u:noble-2026.06.0-242

# install.packages() uses bspm here too, so these are fast binary installs
RUN Rscript -e 'install.packages(c("tidyverse", "lme4", "brms"))'
```

```
docker build -t my-course .
docker run --rm -p 8787:8787 -e PASSWORD=pass my-course
```

Add `RUN apt-get update && apt-get install -y <lib>` in the same file if a
package needs an extra system library.

## Reproducibility

`latest`, `noble`, and `resolute` are **moving** tags that update as new
versions of R, RStudio, Pandoc, and Quarto are released. For a setting where
everyone should get an identical environment, pin an **immutable** tag instead:

| Tag pattern           | Example               | Frozen at                    |
| --------------------- | --------------------- | ---------------------------- |
| `<variant>-<date>`    | `noble-2026-07-05`    | everything, as of that build |
| `<variant>-<rstudio>` | `noble-2026.06.0-242` | that RStudio version         |

Use one in `docker run`, in `docker-compose.yml`, or as the `FROM` line of a
derivative image and it will not change under you. Browse the
[available tags](https://hub.docker.com/r/jmgirard/rstudio2u/tags) on Docker Hub.

For project-level reproducibility, [renv](https://rstudio.github.io/renv/) works
well inside the container: `renv::init()` records exact package versions in a
lockfile you can commit, and `renv::restore()` rebuilds them — quickly, since
bspm still serves binaries.

## Security

This image is intentionally **root-capable**: the RStudio user has passwordless
`sudo` so that [bspm](https://cloud.r-project.org/package=bspm) can install
system binaries and you can `apt install` additional Ubuntu dependencies from
the terminal. That capability *is* root — installing system packages and having
root inside the container are the same privilege — and it is the whole point of
this image. If you need a locked-down RStudio without root, use
[`rocker/rstudio`](https://rocker-project.org/images/versioned/rstudio.html)
instead (you lose bspm binary installs).

Because a logged-in user effectively has root **inside the container**, run it
safely:

- **Keep it bound to `127.0.0.1`** (as `docker-compose.yml` does). Do not publish
  the port on `0.0.0.0` or a public interface.
- **`DISABLE_AUTH=true` / no-login is only safe on a localhost-only bind.** Never
  combine passwordless access with a network-reachable port; set a strong
  `PASSWORD` (and leave auth enabled) if the server is reachable by others.
- **Don't run with `--privileged`**, don't mount the Docker socket
  (`/var/run/docker.sock`), and be cautious mounting sensitive host directories —
  container root can act on anything you expose to it. In an unprivileged
  container, root is confined by the kernel; those options remove that boundary.

## FAQ / Troubleshooting

**"Cannot connect to the Docker daemon" / the launcher says Docker isn't running.**
Open Docker Desktop, wait until it reports *Running*, then try again.

**Port 8787 is already in use.**
Use a different host port. With the launcher or Compose, set `RS_PORT`, e.g.
`RS_PORT=8888 docker compose up -d`, then browse to <http://localhost:8888>. With
`docker run`, change the mapping to `-p 8888:8787`.

**How do I update to the latest version?**
`docker compose pull` (the launchers do this for you) or
`docker pull jmgirard/rstudio2u`. Your work in the home volume is preserved.

**How do I reset everything / reclaim disk space?**
`docker compose down -v` removes the container and its home volume (this deletes
saved work). `docker image prune` reclaims old image layers.

**Does it work on Apple Silicon?**
Yes — images are built for both amd64 and arm64, so Apple Silicon Macs run
natively without emulation.

**What's the login?**
Username `rstudio`; the password is whatever you pass via `-e PASSWORD=...` (the
Compose default is `rstudio`). The Compose/launcher setup uses `DISABLE_AUTH=true`,
so no login is required at all.

## Derivative Images

- [jmgirard/rocker-bayes](https://github.com/jmgirard/rocker-bayes) - Adds CmdStan and R packages for Bayesian data analysis

## How to Cite

Citation metadata is in [`CITATION.cff`](CITATION.cff); GitHub shows a
ready-to-copy citation via the **Cite this repository** button on the repo page.
