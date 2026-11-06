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

These tags **move** as new versions are released. For an environment that never changes, such as a course, pin an image digest. See [Reproducibility](#reproducibility).

Both `noble` (Ubuntu 24.04) and `resolute` (Ubuntu 26.04) are supported. A pull request that changes the image is built and smoke-tested on both (amd64) before it merges. `latest` points at `noble` today. It is scheduled to move to `resolute` on 2027-06-07, between academic terms. The double-click launchers use `latest`, so they switch to Ubuntu 26.04 the first time they start with an internet connection after that date. To stay on Ubuntu 24.04 after that date, use the `noble` tag, a `noble-` tag, or the digest of a `noble` image (see [Reproducibility](#reproducibility)). With the launchers, put that tag or digest in the `image:` line of `docker-compose.yml`.

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
   and opens <http://localhost:8787> in your browser (no username or password).
   If that port is already taken on your machine, see the FAQ below for how to
   pick another one — the launcher will then report and open that address instead
5. When you are done, double-click the matching `stop_...` file. The files in
   your home folder are kept. Run the start file again to start the server.

The launchers just wrap the Docker Compose commands below, so Docker Desktop must
be installed and running.

> **Your files are saved.** The Compose setup stores the home directory (your
> files and settings) in a Docker named volume. The volume survives stopping,
> restarting, and updating to a newer image. By default, packages from
> `install.packages()` are not in that volume. See
> [Keeping installed packages](#keeping-installed-packages). To wipe the volume
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
- Packages installed this way live inside the container, not in the home
  volume, so they are lost each time Compose replaces the container. See
  [Keeping installed packages](#keeping-installed-packages).
- If a package needs a system library, open the RStudio **Terminal** and
  `sudo apt install <libfoo-dev>` (rarely needed — bspm resolves most
  dependencies for you).

### Keeping installed packages

By default, `install.packages()` puts packages in `/usr/lib/R/site-library` or
`/usr/local/lib/R/site-library`. A system library from `sudo apt-get install`
also goes into a system folder. These folders are inside the container. The home volume
holds only `/home/rstudio`, so these packages and libraries last only as long as
the container does.

With the launchers or Docker Compose:

- If you stop the server and start the same container again, your packages
  stay. If no newer image arrived, the `stop_...` file followed by the
  `start_...` file does this. So do `docker compose stop` and
  `docker compose start`.
- Each time Compose replaces the container, your packages are lost. The files in
  your home folder stay. These actions replace the container:
  - You run `docker compose down`, then `docker compose up -d`.
  - A newer image arrives. Each start file downloads the image that
    `docker-compose.yml` names. As shipped, that file names `latest`, and the
    weekly rebuild moves that tag, so this can happen on any start.
    `docker compose pull` followed by `docker compose up -d` does the same.
  - You change `RS_PORT`, or a setting of the service in `docker-compose.yml`
    such as the `image:` line, then run a start file or `docker compose up -d`.

To get your packages back quickly, save a list. Put your install commands in a file in your
home folder, such as `~/my_packages.R`:

```r
# System libraries, only if you need them
system("sudo apt-get update && sudo apt-get install -y libfftw3-dev")
# Your R packages
install.packages(c("glmmTMB", "mice", "metafor"))
```

After Compose replaces the container, run `source("~/my_packages.R")` in the
RStudio console. To give a whole course the same packages, bake them into your
own image instead.

### Baking packages into your own image

This is the recommended way for a course or lab.

Build a small image on top of rstudio2u so everyone gets the same packages
preinstalled. Pin a digest in the `FROM` line so that each rebuild starts from
the same image. [Reproducibility](#reproducibility) shows how to read one:

```dockerfile
FROM jmgirard/rstudio2u@sha256:<digest>

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
versions of R, RStudio, Pandoc, and Quarto are released. `latest` is scheduled
to move from `noble` to `resolute` on 2027-06-07.

Each build also publishes two narrower tags. These tags can move too:

| Tag pattern           | Example               | Points at                                          |
| --------------------- | --------------------- | -------------------------------------------------- |
| `<variant>-<date>`    | `noble-2026-11-05`    | the newest build that started on that date (UTC)   |
| `<variant>-<rstudio>` | `noble-2026.10.1-239` | the newest build with that RStudio version         |

A `<variant>-<date>` tag names the date (UTC) that its build started. If a
later build starts on the same date, the tag moves to that build. A
`<variant>-<rstudio>` tag moves to each new build while that RStudio version is
the newest stable release. It stops moving when a newer RStudio version comes
out.

For an environment that never changes under you, such as a course, pin an image
digest. A digest is an ID that the registry computes from the image contents.
It never moves. To read the digest of a tag, run:

```
docker buildx imagetools inspect jmgirard/rstudio2u:noble-2026-11-05
```

The `Digest:` line near the top of the output gives the digest, which starts
with `sha256:`. That one digest covers both amd64 and arm64, so the same pin
works on Intel and Apple Silicon computers. With the launchers or Docker
Compose, put it in the `image:` line of `docker-compose.yml`:

```yaml
    image: jmgirard/rstudio2u@sha256:<digest>
```

In a derivative image, put it in the `FROM` line:

```dockerfile
FROM jmgirard/rstudio2u@sha256:<digest>
```

Browse the [available tags](https://hub.docker.com/r/jmgirard/rstudio2u/tags)
on Docker Hub.

The image is rebuilt weekly by CI, so the Docker date tags are the record of
*builds*. The [GitHub releases](https://github.com/jmgirard/rstudio2u/releases)
are the record of changes to the *recipe*: a new base image family, tag scheme,
or runtime interface (port, user, volume, environment variables) is a major
version; a new variant, launcher feature, bundled tool, or script behavior is a
minor version; a fix is a patch. New R, RStudio, Pandoc, or Quarto versions
arrive through the weekly rebuild and get no release, and neither do docs or
refactors.

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

**The launcher says Docker isn't installed, or isn't running.**
The launchers tell these two apart. *Not installed:* install
[Docker Desktop](https://www.docker.com/products/docker-desktop/) (Docker Engine
on Linux), then run the launcher again. *Installed but not running* (also shown
as "Cannot connect to the Docker daemon"): open Docker Desktop, wait until it
reports *Running*, then try again.

**The launcher says it couldn't download the latest image.**
That's a network problem, not a broken install — check your internet connection
and that you can reach Docker Hub, then run the launcher again.

**Port 8787 is already in use.**
Use a different host port. With the launchers, create a plain text file named
`.env` next to the launcher containing one line:

```
RS_PORT=8888
```

Then run the launcher again — it reports and opens the new address for you. (A
`.env` file works for double-clicking, which is why it is the recommended way;
setting an environment variable only works if you launch from a terminal, where
`RS_PORT=8888 docker compose up -d` also does the job.) With `docker run`,
change the mapping to `-p 8888:8787` instead. If the launcher reports the server
"did not become ready in time", a busy port is the likely cause.

**How do I update to the latest version?**
`docker compose pull` (the launchers do this for you) or
`docker pull jmgirard/rstudio2u`. The files in your home volume are kept. When a
newer image arrives, the launchers and `docker compose up -d` replace the
container, so the R packages that you installed are lost (see
[Keeping installed packages](#keeping-installed-packages)).
A launcher started without internet access reuses the last downloaded image
and says the update was skipped; run it again once you are online to update.
It repeats that warning once the server is ready and waits for a key press
before its window closes. RStudio keeps running after that.

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
