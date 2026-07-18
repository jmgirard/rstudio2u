# M09: Launcher port consistency (done 2026-07-18)

**Goal:** Make the host port one consistent, reachable, validated setting across
all three launchers — announced from what Compose actually bound, not a
hardcoded 8787.

**Outcome:**
- All three launchers announce the port `docker compose port rstudio2u 8787`
  reports, so the URL cannot disagree with what Compose bound. Asking Compose
  (rather than re-parsing RS_PORT) removes a whole class of divergence.
- `.env` is now the documented override — the only one a double-clicking user
  can perform (GP1); a shell env var requires a terminal they do not have.
- Pre-flight validation rejects unusable values in plain language, and keeps
  `0.0.0.0:8888` out of the `127.0.0.1:${RS_PORT}:8787` mapping (IP2).
- `launcher_common.sh` (new) shares the logic for the POSIX pair; batch carries
  its own copy. Timeout hint + manual-URL line reached parity on all three (GP3).
- Launcher CI went from one launcher to three: `launchers.yml` (renamed from
  windows-launcher.yml) runs 46 POSIX + 22 Windows scenarios.

**Review:** two round-trips. CI caught a PowerShell case-insensitivity bug in the
harness ($DotEnv shadowed $dotenv). The Opus reviewer then caught four real
defects, incl. that every .env scenario was false coverage — deleting .env
support outright passed 34/34. Fixed and mutation-pinned. PR #10.
