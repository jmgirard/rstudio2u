# M02: Pre-merge PR CI lane — done 2026-07-17

**Goal:** Add a `pull_request`-triggered CI lane that lints, builds (amd64/noble),
and smoke-tests the image so no branch merges without a verified-bootable image —
closing the pre-merge gap M01 left (GP7).

**Outcome:** Added `.github/workflows/pr-ci.yml` — on PRs touching
Dockerfile/scripts/workflows: hadolint → build noble amd64 (`load`, `push: false`,
`cache-from scope=noble`, no login, no version scrape) → `.github/smoke-test.sh`.
Verifies the branch, never publishes. Proven both ways: milestone PR #2 green
("container reported healthy"); a throwaway PR with a broken entrypoint went red
at the *smoke* step.

**Key decisions:** noble-only (the committed variant that blocks a ship; resolute
is preview tier); amd64-only smoke (multi-arch can't be `--load`ed — arm64 stays
boot-checked at publish, the GP3 asymmetry); no CHANGELOG entry (dev-facing, no
user-visible image change).

**Review:** 3 lenses + scorer. diff-bug F1 (score 80) — path filter omits
`.github/smoke-test.sh`, so the gate can't self-validate its own harness →
follow-up candidate (user decision), M02 shipped as planned. blame-history +
prior-PR clean. All 5 ACs verified with fresh evidence. **PR #2** (squash 78a7b51).
