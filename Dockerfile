# syntax=docker/dockerfile:1

# Ubuntu release of the r2u base image to build on. Override to build the
# different tags, e.g. build the "resolute" tag with:
#   docker build --build-arg UBUNTU_VERSION=26.04 .
ARG UBUNTU_VERSION=24.04
FROM rocker/r2u:${UBUNTU_VERSION}

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/jmgirard/rstudio2u" \
      org.label-schema.vendor="Girard Consulting" \
      maintainer="Jeffrey Girard <me@jmgirard.com>"

# Set up environmental variables
ENV LANG=en_US.UTF-8
ENV S6_VERSION="v3.2.3.0"
ENV DEFAULT_USER="rstudio"

# RStudio Server version. "stable" installs the newest released version at
# build time; pin a specific version to override, e.g.:
#   docker build --build-arg RSTUDIO_VERSION=2026.06.0-242 .
ARG RSTUDIO_VERSION="stable"
ENV RSTUDIO_VERSION=${RSTUDIO_VERSION}

# Install RStudio Server, Pandoc, and Quarto
COPY scripts /rocker_scripts
RUN chmod -R +x /rocker_scripts \
    && /rocker_scripts/install_rstudio.sh \
    && /rocker_scripts/install_pandoc.sh \
    && /rocker_scripts/install_quarto.sh

# Set up bspm and permissions
RUN sed -i '/suppressMessages(bspm::enable())/i options(bspm.sudo = TRUE)' /etc/R/Rprofile.site

# Add apt hook to automatically fix R library permissions after bspm/apt installs
RUN echo 'DPkg::Post-Invoke {"chown -R root:staff /usr/local/lib/R/site-library /usr/lib/R/site-library || true"; "chmod -R g+ws /usr/local/lib/R/site-library /usr/lib/R/site-library || true";};' > /etc/apt/apt.conf.d/99fix-r-lib-perms

# Grant the 'staff' group write access to the system package libraries
RUN chown -R root:staff /usr/local/lib/R/site-library /usr/lib/R/site-library \
    && chmod -R g+ws /usr/local/lib/R/site-library /usr/lib/R/site-library

# Report container health by checking that RStudio Server is serving HTTP
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -q -O /dev/null http://localhost:8787/ || exit 1

# Start RStudio Server
EXPOSE 8787
CMD ["/init"]
