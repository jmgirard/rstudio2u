# M12: Docker Hub description sync

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP2
- **Resolves:** —
- **Branch/PR:** m012-dockerhub-description-sync

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

- [ ] AC1: A workflow triggered by a push to the default branch that changes
      `README.md`, and by manual dispatch, updates the Hub full description
      from `README.md` and the short description from a fixed string, using a
      pinned `peter-evans/dockerhub-description` step.
- [ ] AC2: The workflow contains no image build or push step (no
      `docker/build-push-action`, no `docker push`), and `docker.yml` is
      byte-identical to its state on the default branch at branch time.
- [ ] AC3: The workflow file passes `actionlint`.

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

## Decisions

- 2026-09-03: The workflow authenticates with a new `DOCKERHUB_PASSWORD` secret (account password), not the existing `DOCKERHUB_TOKEN`. The action's README now accepts a personal access token, but only one with read, write, and delete permission; the existing token's permissions are not readable from the repo. The user chose the password secret at the implement gate over reusing the token and over pausing to check its scope. If Hub later accepts a token verified to carry all three permissions, the secret reference is the only change.

## Review
