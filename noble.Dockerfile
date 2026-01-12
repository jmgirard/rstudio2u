FROM rocker/r2u:24.04

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/jmgirard/rstudio2u" \
      org.label-schema.vendor="Girard Consulting" \
      maintainer="Jeffrey Girard <me@jmgirard.com>"

# Set up environmental variables
ENV LANG=en_US.UTF-8
ENV S6_VERSION="v2.1.0.2"
ENV RSTUDIO_VERSION="2026.01.0-392"
ENV DEFAULT_USER="rstudio"

# Install RStudio Server
COPY scripts /rocker_scripts
RUN chmod -R +x /rocker_scripts
RUN /rocker_scripts/install_rstudio.sh

# Set up bspm and permissions
RUN sed -i '/suppressMessages(bspm::enable())/i options(bspm.sudo = TRUE)' /etc/R/Rprofile.site
RUN chown -R rstudio:rstudio /usr/local/lib/R/site-library/bspm

# Start RStudio Server
EXPOSE 8787
CMD ["/init"]

# Install Pandoc and Quarto
RUN /rocker_scripts/install_pandoc.sh && /rocker_scripts/install_quarto.sh
