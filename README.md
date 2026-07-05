# rstudio2u

Adds RStudio Server, pandoc, and Quarto to [r2u](https://github.com/rocker-org/r2u), works on AMD64 and ARM64 (e.g., Apple Silicon)

Binary package installation from within R via [bspm](https://cloud.r-project.org/package=bspm) for faster installs and smaller image size

| Tag                 | Base image         | Architectures | RStudio version |
| ------------------- | ------------------ | ------------- | --------------- |
| `latest`, `noble`   | `rocker/r2u:24.04` | amd64, arm64  | latest stable   |
| `resolute`          | `rocker/r2u:26.04` | amd64, arm64  | latest stable   |

The R version is whatever the underlying [r2u](https://github.com/rocker-org/r2u) base image ships, and RStudio Server defaults to the newest stable release at build time. All tags are built from a single [`Dockerfile`](Dockerfile); select the base with the `UBUNTU_VERSION` build argument (e.g. `--build-arg UBUNTU_VERSION=26.04` for `resolute`) and pin RStudio with `--build-arg RSTUDIO_VERSION=<version>` if you need a specific version.

## Use Examples

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

## Derivative Images

- [jmgirard/rocker-bayes](https://github.com/jmgirard/rocker-bayes) - Adds CmdStan and R packages for Bayesian data analysis
