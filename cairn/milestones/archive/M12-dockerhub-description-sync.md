# M12: Docker Hub description sync

**Status:** done (2026-09-03, PR #19 https://github.com/jmgirard/rstudio2u/pull/19)

**Goal:** The Docker Hub page for `jmgirard/rstudio2u` shows the repository
README, updated automatically whenever the README changes on the default branch.

**Outcome:** `.github/workflows/dockerhub-description.yml`: `push` to main with
`paths` README.md + the workflow itself, plus `workflow_dispatch` guarded to
main; `peter-evans/dockerhub-description` SHA-pinned (v5.0.0), fixed
`short-description`, `enable-url-completion: true` (relative links → GitHub
URLs), one concurrency group; `contents: read` only. No image build/push;
`docker.yml` untouched. Credential: the shared `DOCKERHUB_TOKEN`, now a
read/write/delete token (user rotated the secret 2026-09-03). Post-merge
dispatch succeeded; Hub shows the short description and `# rstudio2u`.

**Decisions:** D-004 (action + SHA pin). Milestone-local: one token, one
secret — `DOCKERHUB_TOKEN` serves both image pushes and the description sync
(superseded a password-secret plan and a second dedicated secret).

**Review:** three-lens fan-out. Fixed at the gate: url completion, workflow
path in `paths`, main-only dispatch guard, concurrency group, CHANGELOG under
Added. Token rotation resolved via `gh secret list` update time. Accepted: the
July-2026 PAT 403 risk (T3 went green live); Hub-unfriendly README lines →
Known issues. Rejected: checkout pin, `continue-on-error`, `timeout-minutes`.
