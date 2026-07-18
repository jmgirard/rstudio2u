# Changelog

Notable user-visible changes to the rstudio2u image. Format follows
[Keep a Changelog](https://keepachangelog.com/); newest first.

## Unreleased

### Fixed

- The double-click launchers no longer send you to the wrong address when the
  server is running on a port other than 8787. They previously announced and
  opened `http://localhost:8787` unconditionally; they now report the address
  the server was actually started on.

### Changed

- You can change the port the launchers use by putting `RS_PORT=8888` in a file
  named `.env` next to the launcher. This works when double-clicking, which
  setting an environment variable does not — previously the only documented way
  to change the port required launching from a terminal. A value that is not a
  usable port number is now reported in plain language before startup rather
  than surfacing as a raw Docker error.

- The double-click launchers now explain failures in plain language instead of
  blaming a generic timeout. They tell apart Docker not being *installed* from
  Docker being installed but not *running*, report a failed image download as a
  network problem, and — on Windows — suggest setting `RS_PORT` when port 8787
  is already in use. The clearer messages apply on Windows, macOS, and Linux.

- Runtime package installs now ride out a flaky binary mirror instead of
  failing on the first hiccup: apt retries a failed download up to three times
  with a bounded connection timeout, so a brief outage of the r2u mirror is
  usually invisible. When an install does ultimately fail because the mirror is
  unreachable, RStudio now prints a short plain-language note explaining it is a
  temporary network/mirror problem — not your code — and to try again shortly,
  instead of only a wall of raw `apt` errors. An ordinary "that package does not
  exist" error is unaffected and shows no such note.

- Published tags are now smoke-tested before release: CI boots the freshly
  built image and confirms RStudio Server answers on port 8787, a package
  installs from the binary repository, and Quarto renders a document — on both
  the amd64 and arm64 builds — before pushing any tag. An automated rebuild can
  no longer publish an image whose server, package installation, or Quarto
  toolchain is broken on either architecture.

### Fixed

- The Windows double-click launchers now work when the project is obtained via
  **Download ZIP**, not only `git clone`. The `.bat` files are stored with
  Windows (CRLF) line endings, so every download path produces launchers that
  Windows runs reliably.

- The RStudio version behind the `<variant>-<rstudio>` image tags is now
  validated before publishing. If the upstream version lookup returns an empty
  or unexpected response, the build fails loudly instead of publishing an image
  under a blank or wrong version tag.
- The Pandoc and Quarto download URLs scraped when building with a non-default
  version (`latest`/`release`/`prerelease`) are now validated for the target
  architecture before download. A changed upstream response now fails the build
  with a clear message instead of feeding an empty or wrong URL to the
  downloader.
