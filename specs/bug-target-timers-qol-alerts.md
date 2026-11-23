# Task: two player-visible overlap bugs on staging

**1. Target aura timers over the buff row.** On the target frame with the aura filter "Debuffs and buffs" and timers placed below their icons, the debuff timers draw over the buff row (found by the #617 fixer; predates it). Reproduce in the harness (`frames_text_slots` or the unit-frame aura scenes), then make the rows leave room for the timer lane when timers sit below, as the other frames already do. Default look unchanged.

**2. QoL alert lines under the Options window.** With QoL alerts on, the Options-page render fails `--strict` because HUD alert lines draw under the Options window (on staging today; found by the #623 fixer). Decide what the game does: alerts should sit on a strata that never collides with an open Options window, or hide while it is open, whichever matches how the other HUD text behaves around Options. Smallest change.

**Evidence**: a regression for each that fails on today's staging; before/after renders at all four sizes (`--strict`, game backdrop); zero pixel change elsewhere. Lint, python, unit-frame, QoL and Options tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. One PR to `staging`, `fix(unitframes,qol): ...` (or two PRs if they share nothing), `Fixed:` changelog lines in player words. Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_QoL/**`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number(s), SHA and run id.
