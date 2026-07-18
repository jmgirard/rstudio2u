# M08: Windows launcher hardening (done 2026-07-18)

**Goal:** Make the least-tested launcher path — Windows — deliver reliably from
the README-recommended ZIP download, diagnose its own failures clearly, and put
it under real Windows CI (GP3; "Windows launcher sees the least real-world
testing" wart).

**Outcome:**
- `.gitattributes` `*.bat -text` + committed CRLF bytes → the stored blob ships
  CRLF, so `git archive`/ZIP download (not just `git clone`) gives Windows
  parseable launchers. Guarded by `scripts/tests/test_launcher_line_endings.sh`.
- `start_windows.bat` reworked: distinguishes Docker not-installed vs
  not-running, pull-failure vs health-timeout (with `RS_PORT` hint), always
  shows the manual URL, and honors a `RS_LAUNCHER_NONINTERACTIVE` test seam.
- New `.github/workflows/windows-launcher.yml` (windows-latest) runs the
  launcher through all 5 branches against a compiled `docker.exe` stub +
  in-shell PATH; ubuntu job runs the CRLF guard.
- `start_mac.command` / `start_linux.sh` gained matching not-installed /
  not-running / pull-failure diagnostics; README FAQ + CHANGELOG synced.

**Review:** one finding (score 90) fixed — start_linux.sh error branches lacked
the "Press any key" pause. Candidate filed: banner hardcodes `localhost:8787`
even when `RS_PORT` set. One round-trip (windows lane caught two test-harness
bugs, not launcher defects). PR #9 squash-merged; no principle changed (GP3).
