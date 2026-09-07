# M016: Keep the weekly rebuild alive

**Status:** done (2026-09-07, PR #23 https://github.com/jmgirard/rstudio2u/pull/23)

**Goal:** A default branch left quiet for weeks gets an automated empty commit,
so GitHub's 60-day inactivity rule cannot silently disable the weekly rebuild.

**Outcome:** `.github/keepalive.sh` holds the whole staleness rule: three
validated arguments, a proleptic-Gregorian day-number conversion in shell
arithmetic, and on the stale branch exactly two git calls — `commit
--allow-empty` as `github-actions[bot]`, then `push`. Fresh means no git call at
all; an over-wide threshold is bounded by digit width, so it can never wrap and
invert. `scripts/tests/test_keepalive.sh` drives it offline against a
call-logging `git` stub, 93 assertions. A `keepalive` job in `docker.yml` runs
it on schedule and dispatch only, `contents: read`, two checkouts, pushing with
a write-enabled deploy key in `KEEPALIVE_DEPLOY_KEY` — never the workflow's own
token. Threshold 50 days; the commit matches no `paths` filter, so starts no build.

**Decisions:** D-008 (a CI keepalive commit may write to the default branch with
a repo-scoped credential), D-009 (that credential is a deploy key, no expiry).

**Review:** Two three-lens passes. The first returned the milestone on an
unbounded threshold that wrapped and inverted the comparison — one defect
return. The second verified all five criteria, actioned five documentation and
latent-trap fixes, routed one follow-up to a candidate row, rejected two cosmetics.
