FROM rocker/r2u:24.04

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/jmgirard/rstudio2u" \
      org.label-schema.vendor="Girard Consulting" \
      maintainer="Jeffrey Girard <me@jmgirard.com>"

ENV LANG=en_US.UTF-8
ENV S6_VERSION="v2.1.0.2"
ENV RSTUDIO_VERSION="2024.12.1+563"
ENV DEFAULT_USER="rstudio"
ENV R_LIBS_USER=/home/rstudio/R/library
ENV R_LIBS_SITE=/usr/local/lib/R/site-library:/usr/lib/R/site-library:/usr/lib/R/library

# Enable D-Bus Service for BSPM
RUN sed -i '/suppressMessages(bspm::enable())/i options(bspm.sudo = TRUE)' /etc/R/Rprofile.site

# Install RStudio Server
COPY scripts /rocker_scripts
RUN chmod -R +x /rocker_scripts \
    && /rocker_scripts/install_rstudio.sh

# Configure R library for rstudio user
RUN mkdir -p /home/rstudio/R/library
RUN chown -R rstudio:rstudio /home/rstudio/R

# Start RStudio Server
EXPOSE 8787
CMD ["/init"]

# Install Quarto
RUN /rocker_scripts/install_pandoc.sh \
    && /rocker_scripts/install_quarto.sh
