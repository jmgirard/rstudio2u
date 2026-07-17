# Decisions

_Append-only, cross-cutting decisions (D-001, …). Never renumber or edit
history — supersede with a new entry. Milestone-local decisions live in their
milestone file; deferrals ("not now") are ROADMAP facts, not decisions._

### D-001 (2026-07-17): Own the rocker_scripts fork

**Context:** `scripts/` began as vendored rocker_scripts; local repairs (s6
v3 migration, quarto 'release' alias) had already diverged it, and drift was
confirmed as a wart in the design interview.
**Decision:** The scripts are this repo's code. Considered tracking upstream
with periodic re-syncs; rejected — hand-picking upstream fixes beats a
recurring sync chore against a fork that intentionally simplifies.
**Consequences:** Aggressive simplification is licensed (GP4); upstream fixes
must be noticed and reapplied by hand (recorded in Known issues).
