#!/usr/bin/with-contenv bash
# shellcheck shell=bash

## Set our dynamic variables in Renviron.site to be reflected by RStudio Server or Shiny Server
exclude_vars="HOME PASSWORD RSTUDIO_VERSION BATCH_USER_CREATION"

## The r2u/Debian base does not export R_HOME, so resolve it here; otherwise
## ${R_HOME}/etc/Renviron.site would expand to /etc/Renviron.site, which R
## does not read (R reads $(R RHOME)/etc/Renviron.site).
R_HOME=${R_HOME:-$(R RHOME)}

## s6-overlay v3 exposes the container environment under /run; fall back to
## the v2 path (/var/run is usually a symlink to /run anyway).
S6_ENV_DIR="/run/s6/container_environment"
[ -d "$S6_ENV_DIR" ] || S6_ENV_DIR="/var/run/s6/container_environment"

mkdir -p "${R_HOME}/etc"
touch "${R_HOME}/etc/Renviron.site"
for file in "${S6_ENV_DIR}"/*; do
    sed -i "/^${file##*/}=/d" "${R_HOME}/etc/Renviron.site"
    regex="(^| )${file##*/}($| )"
    [[ ! $exclude_vars =~ $regex ]] && echo "${file##*/}=$(cat "${file}")" >>"${R_HOME}/etc/Renviron.site" || echo "skipping ${file}"
done

## only file-owner (root) should read container_environment files:
chmod 600 "${S6_ENV_DIR}"/*