# Task: player bug — "drops fps by half" (investigate deeply, fix what you prove)

A player (0xDAB, Discord #chat, 2026-11-21, latest release; Mac) says KstyleUI "also drops fps by half", right after reporting that tooltips follow the mouse. More details have been requested from them; the coordinator will forward replies. Released code: tag `v0.2.9` (and v0.2.8.5).

**Investigate, ranked by likelihood, with measurements:**
1. **Tooltips following the cursor** (Tooltips module "Mouse cursor out of combat", default): is any KstyleUI work running every frame while a tooltip is shown or moving: OnUpdate scripts, `OnTooltipSetUnit/Item/Spell` hooks re-firing, restyling, backdrop/border rebuilds, item level or player info lookups, `GameTooltip_SetDefaultAnchor` hooks, NotifyInspect loops, font rescans? Measure instructions per frame with a tooltip shown over a unit, an item, a spell and a data bar readout.
2. **Per-frame OnUpdate scripts across the suite** introduced since v0.2.8.2 (`git log v0.2.8.2..v0.2.9`): cursor ring/trail/cast circle/GCD circle (should cost nothing when off), movement alert, crosshair/range text, distance text, data bar tickers (fps/latency), swing timer, nameplate distance/range fade, spark animations, hit sparks, combat timer, meters refresh. List every OnUpdate/C_Timer ticker, whether it runs at defaults, and its cost per frame.
3. **Event storms**: handlers on UNIT_AURA/UNIT_HEALTH/COMBAT_LOG/UNIT_POWER_FREQUENT doing more work since 0.2.8.2 (the perf budgets cover reload, not steady state).
Use the harness instruction counters (`test-perf*`, `perf_*` helpers) to build a steady-state per-frame benchmark at defaults for each HUD style (idle, in combat with a target, with a tooltip shown), compare `v0.2.8.2` vs `v0.2.9`, and report the deltas.

**Fix** every real per-frame cost you prove, behaviour and pixels identical (perf-only, see the pixel-identical rule), each with a regression budget in `test-perf*` that fails on today's code. If nothing large shows up, write the findings and the exact in-game measurements to ask the player for.

**Checks**: lint, python, affected module tests, `test-taint-scan`, `test-perf-path-budgets`, `test-perf*` under PUC Lua 5.1; pixel-identical renders for touched modules; hosted CI green. One PR to `staging`, `perf(...)`, `Fixed:` line if players feel it. Do not merge.

**Files it may edit**: any addon file for proven perf fixes, `Tools/regression/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report findings (table of per-frame costs before/after), PR, SHA and run id.
