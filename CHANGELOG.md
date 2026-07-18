# Changelog

Notable user-visible changes to the rstudio2u image. Format follows
[Keep a Changelog](https://keepachangelog.com/); newest first.

## Unreleased

### Changed

- Published tags are now smoke-tested before release: CI boots the freshly
  built image and confirms RStudio Server answers on port 8787, a package
  installs from the binary repository, and Quarto renders a document — on both
  the amd64 and arm64 builds — before pushing any tag. An automated rebuild can
  no longer publish an image whose server, package installation, or Quarto
  toolchain is broken on either architecture.

### Fixed

- The RStudio version behind the `<variant>-<rstudio>` image tags is now
  validated before publishing. If the upstream version lookup returns an empty
  or unexpected response, the build fails loudly instead of publishing an image
  under a blank or wrong version tag.
- The Pandoc and Quarto download URLs scraped when building with a non-default
  version (`latest`/`release`/`prerelease`) are now validated for the target
  architecture before download. A changed upstream response now fails the build
  with a clear message instead of feeding an empty or wrong URL to the
  downloader.
