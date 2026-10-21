# M019: Take the artifact action bumps and fix the digest artifacts

**Status:** done (2026-10-21, PR #30 https://github.com/jmgirard/rstudio2u/pull/30)

**Goal:** The image build workflow carries its build digests with `actions/upload-artifact@v7` and `actions/download-artifact@v8`, each publish leg downloads only its own variant's two digests by exact name, and the digests stay available for six days.

**Outcome:** `docker.yml` moved `actions/upload-artifact` v4 → v7 and `actions/download-artifact` v4 → v8 (Dependabot #29, #28, superseded by this PR). The publish job's download pattern is now `digests-${{ matrix.variant }}-{amd64,arm64}` (no wildcard) instead of the prefix `digests-<variant>-*`; download-artifact v8 expands the braces and, on a pattern matching nothing, downloads nothing with no error, so the existing 2-digest check still fails the leg. Digest `retention-days` is 6 instead of 1, so "Re-run failed jobs" works for the rest of the week; a scheduled run's digests expire before the next Monday run. Tested by test-mode dispatches 39529671936 and 39530697446 (final). No user-visible change: the image and its tags are unchanged.

**Decisions:** D-011 records the two bumps. The plan gate chose a brace pattern over two exact-`name:` downloads (a missing artifact under `name:` fails before the 2-digest check), and six days over seven or more (a longer retention lets a scheduled run's late re-run publish over the next scheduled run).

**Review:** four-lens fan-out. AC3 failed as written by one second (GitHub sets `expires_at` one second short of `created_at` + 6 days) and was amended to a one-minute tolerance, re-audited clean; the code did not change for it. Four findings fixed at the gate in `docker.yml` comments: the retention comment now says only scheduled runs are bounded, and the download comment names the build-matrix coupling and the fewer-than-two case. One follow-up: candidate row "Refuse to move moving tags backward". Eight rejected. No finding met the return floor. Graduated the candidate rows "Take the two artifact bumps (#28, #29)", "Match digest artifacts by exact variant", "Keep digest artifacts longer than a day".
