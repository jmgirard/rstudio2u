#!/bin/bash
set -o nounset

## Enforces the custom password specified in the PASSWORD environment variable
## The accepted RStudio username is the same as the USER environment variable (i.e., local user name).


IFS='' read -r password

# shellcheck disable=SC2153  # PASSWORD is the container env var, set by init_userconf.sh
[ "${USER}" = "${1}" ] && [ "${PASSWORD}" = "${password}" ]
