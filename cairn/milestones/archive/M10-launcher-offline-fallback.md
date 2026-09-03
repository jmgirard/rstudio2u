# M10: Launcher offline fallback

**Status:** done (2026-09-03, PR #17 https://github.com/jmgirard/rstudio2u/pull/17)

**Goal:** When the image update cannot be downloaded but a copy is already on
the machine, the three launchers start that copy with a warning, not a refusal.

**Outcome:** `launcher_images_present` / `launcher_warn_offline` in
`launcher_common.sh`, `:images_present` / `:trim_image` in `start_windows.bat`:
on a failed `docker compose pull` the launcher lists images with `docker
compose config --images` and `docker image inspect`s each; all present →
warning, fall through to `compose up`; any absent, an empty list, or an
unsupported flag → the existing hard error, exit 1. Both harnesses: stub call
log, `offline-fallback`, `offline-second-image-absent`,
`offline-config-unsupported`, `offline-config-empty`, up-never-ran on
`pull-failure`, warning-absent on every pull-success run. README FAQ + CHANGELOG.

**Decisions:** none (plan-gate choices in git: check presence first; ask Compose for the list).

**Review:** three-lens fan-out. Diff lens: five harness gaps fixed at the gate
(argument-blind `inspect` stub, warning not forbidden on the hard-error path,
shared message prefix, empty list untested, `info` unlogged), one candidate row
(warning scrolls off before the running banner), three rejected (old-Compose
doc claim → Known issues; CR/space trim asymmetry; batch variable leak).
History and prior-review lenses: no conflicts.
