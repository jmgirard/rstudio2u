# rstudio2u

Adds RStudio Server, pandoc, and Quarto to [r2u](https://github.com/rocker-org/r2u)

Binary R package installation on Ubuntu for AMD64 and ARM64 via [bspm](https://cloud.r-project.org/package=bspm)

(Just use `install.packages()` and `update.packages()`)

## Use Examples

### Option 1: Pull and run from Dockerhub

1. Install and open Docker Desktop
2. Enter the following command in your terminal

    ```
    docker pull jmgirard/rstudio2u
    docker run --rm -p 8787:8787 -e PASSWORD=pass -t jmgirard/rstudio2u
    ```

3. Navigate to <https://localhost:8787> and enter user `rstudio` and password `pass`

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
