# M12: Docker Hub description sync

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP2
- **Resolves:** —
- **Branch/PR:** m012-dockerhub-description-sync · https://github.com/jmgirard/rstudio2u/pull/19

## Goal

The Docker Hub page for `jmgirard/rstudio2u` shows the repository README,
updated automatically whenever the README changes on the default branch.

## Scope

Tier: user-facing — the Hub page is the first thing a student or instructor
reads.

**In:** a new `.github/workflows/dockerhub-description.yml`; confirming
which Docker Hub credential can edit the description; a post-merge
verification task.

**Out:** any change to `docker.yml`; a Hub-specific README variant (the
GitHub README is the single source); image publishing.

## Acceptance criteria

- [x] AC1: A workflow triggered by a push to the default branch that changes
      `README.md`, and by manual dispatch, updates the Hub full description
      from `README.md` and the short description from a fixed string, using a
      pinned `peter-evans/dockerhub-description` step.
- [x] AC2: The workflow contains no image build or push step (no
      `docker/build-push-action`, no `docker push`), and `docker.yml` is
      byte-identical to its state on the default branch at branch time.
- [x] AC3: The workflow file passes `actionlint`.

## Coverage

- AC1 → T1, T2
- AC2 → T2
- AC3 → T2

## Tasks

- [x] T1: Credential check. Docker Hub has historically rejected personal
      access tokens for description edits and the action's README says so;
      read the action's current README and Hub docs. If a token cannot, the
      user creates a `DOCKERHUB_PASSWORD` secret (a secret is a user action;
      the plan gate approved this route) and the workflow uses it; if the
      existing `DOCKERHUB_TOKEN` can, use that. Record which in the work log.
- [x] T2: Write the workflow: `push` to the default branch with `paths:
      README.md`, plus `workflow_dispatch`; `peter-evans/dockerhub-description`
      pinned to an exact version; `short-description` set to "RStudio Server
      on rocker/r2u: fast binary R packages via bspm"; run `actionlint`.
- [ ] T3: Post-merge (in `/milestone-review`'s hygiene step, since a
      dispatch is only possible once the file is on the default branch):
      dispatch the workflow, confirm green, and confirm the Hub page opens
      with the README's first heading. A failure here is a hotfix-tier
      follow-up, not a reason to hold the merge.

## Work log

- 2026-09-03: created by /milestone-plan.
- 2026-09-03: criteria audit ran in full mode ([O] fresh reader); returned: the credential may lack authority (now T1, gate-approved fallback), byte-identity against Hub state was unverifiable pre-merge and a process clause rode in the criterion (dropped; post-merge check is T3).
- 2026-09-03: plan gate chose "plan now with a password-secret fallback" over "hold as candidate until the token is confirmed" because the check is one task and the fallback is a single secret; falsified by Hub refusing description edits from any non-interactive credential.

- 2026-09-03: implement gate: credential = new `DOCKERHUB_PASSWORD` secret (user creates it before merge); pin = commit SHA + `# v5.0.0` comment (D-004). Action README read 2026-09-03: token needs read/write/delete scope; T1 done.
- 2026-09-03: T2 done: `.github/workflows/dockerhub-description.yml` (push to main on README.md, workflow_dispatch; SHA-pinned action; `DOCKERHUB_PASSWORD`). actionlint 1.7.7 (docker `rhysd/actionlint:1.7.7`) clean; discrimination: a planted bad job key and an unclosed expression both reported. `docker.yml` diff against main: 0 lines.
- 2026-09-03: CHANGELOG Unreleased/Changed entry added. T3 stays unchecked: it is the post-merge dispatch owned by /milestone-review's hygiene step per the plan. Status → review. Pre-merge user action: create the `DOCKERHUB_PASSWORD` repository secret.
- 2026-09-03: user reports the existing `DOCKERHUB_TOKEN` is read+write only and created a new token with read, write, and delete; workflow now reads `DOCKERHUB_DESCRIPTION_TOKEN` (supersedes the password-secret choice; see Decisions). actionlint re-run clean. User still to add the secret under that name.
- 2026-09-03: user deleted the old read+write token that `DOCKERHUB_TOKEN` held (image pushes in docker.yml fail until the secret is updated). Workflow now reads `DOCKERHUB_TOKEN`; user to update that secret with the new read/write/delete token. No second secret. actionlint clean.

## Decisions

- 2026-09-03: The workflow authenticates with a new `DOCKERHUB_PASSWORD` secret (account password), not the existing `DOCKERHUB_TOKEN`. The action's README now accepts a personal access token, but only one with read, write, and delete permission; the existing token's permissions are not readable from the repo. The user chose the password secret at the implement gate over reusing the token and over pausing to check its scope. If Hub later accepts a token verified to carry all three permissions, the secret reference is the only change.
- 2026-09-03: Supersedes the entry above. The user confirmed `DOCKERHUB_TOKEN` has read and write permission only, and created a new token with read, write, and delete. The workflow reads it as `DOCKERHUB_DESCRIPTION_TOKEN`; no account password is stored in GitHub. `docker.yml` keeps using `DOCKERHUB_TOKEN`.
- 2026-09-03: Supersedes the two entries above. One token, one secret: `DOCKERHUB_TOKEN` holds a token with read, write, and delete permission and serves both `docker.yml` (image pushes) and the description workflow. The old read+write token was deleted by the user, so the secret must be updated to the new token before any push to main.

## Review

- 2026-09-03 AC1: `.github/workflows/dockerhub-description.yml` triggers on `push` to `main` with `paths: [README.md]` and on `workflow_dispatch`; the step is `peter-evans/dockerhub-description@1b9a80c0…` (commit pinned; `gh api …/git/ref/tags/v5.0.0` resolves to the same SHA), `readme-filepath: ./README.md`, `short-description` a fixed string. Verified by reading the file on the branch head. Live Hub update itself is T3, post-merge. ✔
- 2026-09-03 AC2: `grep -n 'build-push-action\|docker push'` over the workflow matches nothing (exit 1); `git diff origin/main HEAD -- .github/workflows/docker.yml` is 0 lines. ✔
- 2026-09-03 AC3: `rhysd/actionlint:1.7.7` (docker) over the workflow file: exit 0, no output. Discrimination: the same command over the file with `runs-on` renamed `runs_on` reports two syntax-check errors, exit 1. ✔

- 2026-09-03 gate: `cairn_validate.py` exit 0 (one pre-existing advisory: `.gitignore` `cairn/references/pdf/` entry superseded; not from this milestone). No principle changed → `cairn_impact` skipped. Toolchain (docker-image slot): Dockerfile untouched by the diff; `hadolint/hadolint:v2.12.0` over `Dockerfile` exit 0; base image `rocker/r2u:${UBUNTU_VERSION}` with `ARG UBUNTU_VERSION=24.04` (explicit tag); no credentials in `ENV`/`COPY`; `.dockerignore` present (excludes `.git`, `.github`, launchers); CHANGELOG Unreleased/Changed entry present, no milestone number in it. `docker build` evidence: PR CI `build-smoke` on PR #19 (recorded below when it finishes).
- 2026-09-03 gate (cont.): PR #19 `build-smoke` (hadolint + amd64 build + boot smoke) passed in 3m5s — the slot's `docker build` evidence.
- 2026-09-03 review fan-out (three lenses; findings ranked by each reviewer, verbatim in chat at the gate). Prior-review lens: no prior-review evidence (archive `## Review` sections searched; PR-comment probe empty). History lens: (S1) the shared `DOCKERHUB_TOKEN` must be rotated before the Monday cron in `docker.yml` — verified: `gh secret list` shows `DOCKERHUB_TOKEN` updated 2026-09-03T23:27:48Z, after the token swap commit; resolved. (S2) commit `11ef521` (2026-07-05) dropped an equivalent job on a PAT 403 — accepted risk, exercised live by T3 post-merge; a 403 is a hotfix-tier follow-up as the plan states. (S3) the dropped job's `continue-on-error: true` is not carried over — rejected: the workflow is isolated from image publishing, so a failed sync should show red. (S4) secret naming churn across commits — no action, recorded in Decisions. Diff lens: (O1) relative README links dead on Hub — fixed now, `enable-url-completion: true`. (O2) `paths` omitted the workflow file, so a short-description edit never re-synced — fixed now. (O3) merge alone does not populate the page (README unchanged) — accepted: T3's dispatch runs in the hygiene step. (O4) Review edits uncommitted — checkpoint commit, this step. (O5) secret rotation — see S1. (O6) `actions/checkout@v4` movable tag beside a rwd credential — rejected: repo-wide convention for first-party `actions/*` (`docker.yml` uses `login-action@v3` with the same secret); D-004's pin covers the third-party action only. (O7) dispatch from a non-default branch would publish that branch's README — fixed now, job `if: github.ref == 'refs/heads/main'`. (O8) no concurrency group, so two quick README pushes could race — fixed now. (O9) README lines that read oddly on Hub ("green Code button", "Cite this repository", `<http://localhost:8787>` autolinks) — accepted limitation, Hub variant is out of scope; Known issues entry at hygiene. (O10) CHANGELOG entry under Changed rather than Added — fixed now. (O11) no `timeout-minutes` — rejected, repo convention. AC3 re-run after the fixes: actionlint exit 0.
- 2026-09-03: step-7 approval: PR #19 approved for merge.
