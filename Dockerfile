# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Base image
# ---------------------------------------------------------------------------
# Ubuntu release of the r2u base to build on. Override to build the different
# tags, e.g. build the "resolute" tag with:
#   docker build --build-arg UBUNTU_VERSION=26.04 .
ARG UBUNTU_VERSION=24.04
FROM rocker/r2u:${UBUNTU_VERSION}

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/jmgirard/rstudio2u" \
      org.label-schema.vendor="Girard Consulting" \
      maintainer="Jeffrey Girard <me@jmgirard.com>"

# ---------------------------------------------------------------------------
# Build configuration
# ---------------------------------------------------------------------------
ENV LANG=en_US.UTF-8 \
    S6_VERSION="v3.2.3.2" \
    DEFAULT_USER="rstudio"

# RStudio Server version. "stable" installs the newest released version at
# build time; pin a specific version to override, e.g.:
#   docker build --build-arg RSTUDIO_VERSION=2026.06.0-242 .
ARG RSTUDIO_VERSION="stable"
ENV RSTUDIO_VERSION=${RSTUDIO_VERSION}

# ---------------------------------------------------------------------------
# Install RStudio Server, Pandoc, and Quarto
# ---------------------------------------------------------------------------
COPY scripts /rocker_scripts
RUN chmod -R +x /rocker_scripts \
    && /rocker_scripts/install_rstudio.sh \
    && /rocker_scripts/install_pandoc.sh \
    && /rocker_scripts/install_quarto.sh

# ---------------------------------------------------------------------------
# Configure bspm and R library permissions (single layer)
# ---------------------------------------------------------------------------
RUN set -eux \
    # Let bspm shell out to apt via sudo so binary packages install system-wide
    && sed -i '/suppressMessages(bspm::enable())/i options(bspm.sudo = TRUE)' /etc/R/Rprofile.site \
    # Retry transient r2u-mirror fetch failures (with a bounded connect timeout)
    # instead of failing on the first hiccup — Known issue #1
    && printf '%s\n' \
       'Acquire::Retries "3";' \
       'Acquire::http::Timeout "30";' \
       'Acquire::https::Timeout "30";' \
       > /etc/apt/apt.conf.d/80-retries \
    # Add a plain-language hint when an install fails on an unreachable mirror.
    # Appended after bspm::enable() so install.packages resolves to bspm's
    # installer when the wrapper captures it — Known issue #1
    && cat /rocker_scripts/mirror_hint.R >> /etc/R/Rprofile.site \
    # Re-apply staff-group write access after every apt/bspm install
    && echo 'DPkg::Post-Invoke {"chown -R root:staff /usr/local/lib/R/site-library /usr/lib/R/site-library || true"; "chmod -R g+ws /usr/local/lib/R/site-library /usr/lib/R/site-library || true";};' > /etc/apt/apt.conf.d/99fix-r-lib-perms \
    # Grant that write access once for the libraries already present
    && chown -R root:staff /usr/local/lib/R/site-library /usr/lib/R/site-library \
    && chmod -R g+ws /usr/local/lib/R/site-library /usr/lib/R/site-library \
    # Drop RStudio's JS debug symbol maps (developer-only, ~34 MB)
    && rm -rf /usr/lib/rstudio-server/www-symbolmaps

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
# Report container health by checking that RStudio Server is serving HTTP
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -q -O /dev/null http://localhost:8787/ || exit 1

EXPOSE 8787
CMD ["/init"]
