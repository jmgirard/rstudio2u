# M015: Native arm64 runners for the image build

**Status:** done (2026-09-06, PR #22 https://github.com/jmgirard/rstudio2u/pull/22)

**Goal:** Build and smoke-test each architecture on a runner of that architecture, so
Quarto's bundled Deno never runs under QEMU and the noble moving tags refresh on schedule.

**Outcome:** `setup-qemu-action` is gone; `docker.yml` is a (variant x arch) matrix on
native runners (`ubuntu-latest`, `ubuntu-24.04-arm`), each leg building one platform,
pushing by digest untagged, pulling that digest back, asserting `.Architecture` and
`uname -m`, then smoke-testing it. A per-variant `publish` job assembles the manifest
list and attaches every tag in one `imagetools` call, refusing a list not covering both
architectures before any tag moves. A `meta` job resolves the RStudio version and UTC
date once per run, so an immutable `<variant>-<version>` / `<variant>-<date>` tag cannot
name an image built from something else. `ci-failure-issue.sh` owns the failed-variant
extraction and the weekly alert's rule under 70 assertions, closing its issue only when
every needed job succeeded. User-visible: arm64 is built and tested on arm64 hardware,
and `latest` cannot go single-arch.

**Decisions:** D-007 (drop `setup-qemu-action`; one architecture per runner).

**Review:** Two three-lens passes. First: 13 findings, returned for T5-T7 over stale
version/date tags. Second: 14 — seven fixed at the gate, two filed `[low]`, three
rejected, four already filed. Retired the M05 arm64 boot-check lesson, now enforced by
`docker.yml`'s pull-back step.
