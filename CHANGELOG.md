# Changelog

Notable user-visible changes to the rstudio2u image. Format follows
[Keep a Changelog](https://keepachangelog.com/); newest first.

## Unreleased

### Changed

- Published tags are now smoke-tested before release: CI boots the freshly
  built image and waits for RStudio Server to answer on port 8787 before
  pushing any tag, so an automated rebuild can no longer publish an image
  whose server fails to start.

### Fixed

- The RStudio version behind the `<variant>-<rstudio>` image tags is now
  validated before publishing. If the upstream version lookup returns an empty
  or unexpected response, the build fails loudly instead of publishing an image
  under a blank or wrong version tag.
