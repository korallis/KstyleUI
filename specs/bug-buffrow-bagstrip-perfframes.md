# Task: two follow-ups from hotfix v0.2.8.4

**1. Target buff row reaches the bag strip.** With the target aura filter "Debuffs and buffs" and timers below icons, the timer-lane fix (#637) lowers the buff row, and in the unitframes HUD scene it now reaches the bag strip. Reproduce at all four sizes and three styles, and keep the buff row clear of every HUD element (the target's aura block should grow upward or cap rows where it would collide, matching how other frames handle their aura room). Defaults unchanged. Report: `C:/Users/leeba/.cache/kstyleui-evidence/hotfix-0284/report.md`.

**2. Flaky Mac headroom check.** `test-perf-frames` "Nameplates UNIT_FLAGS while casting" fails the Mac headroom rule intermittently (budget 40 us is ~4.9x the 8.1 us measured; the rule needs 5x). It failed a hotfix Mac shard and recent staging pushes. Either make that path cheaper (preferred, behaviour identical) or set its budget to 5x a measured Mac median with the calibration noted per `Tools/regression/README.md`. Prove with several Mac-equivalent runs.

**Checks**: regressions that fail first; lint, python, the touched module tests, `test-taint-scan`, `test-perf-path-budgets`, `test-perf-frames` under PUC Lua 5.1; renders `--strict` at four sizes for item 1; hosted CI green. One PR to `staging`, `fix(unitframes): ...` with a `Fixed:` line for item 1. Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_Nameplates/**` (perf only), `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
