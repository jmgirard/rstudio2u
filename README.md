# rstudio2u

Adds RStudio Server, pandoc, and Quarto to [r2u](https://github.com/rocker-org/r2u), works on AMD64 and ARM64 (Mac Silicon)

Binary R package installation on Ubuntu via [bspm](https://cloud.r-project.org/package=bspm) for faster installs and smaller sizes

## Use Examples

### Option 1: Pull and run from Dockerhub

1. Install and open Docker Desktop
2. Enter the following command in your terminal

    ```
    docker pull jmgirard/rstudio2u
    docker run --rm -p 8787:8787 -e PASSWORD=pass -t jmgirard/rstudio2u
    ```

3. Navigate to <https://localhost:8787> and enter user `rstudio` and password `pass`
4. Whenever you use `install.packages()` or `update.packages()`, it will use bspm

### Option 2: Clone, build, and compose

1. Install and open Docker Desktop
2. Install Git
3. Enter the following command in your terminal

    ```
    git clone https://github.com/jmgirard/rstudio2u
    cd rstudio2u
    docker-compose up --build
    ```
4. Navigate to <https://localhost:8787> and enter user `rstudio` and password `pass`
5. Whenever you use `install.packages()` or `update.packages()`, it will use bspm
