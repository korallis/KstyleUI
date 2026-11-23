# Task: hotfix — targeting one mob makes every same-type nameplate flash

The owner (v0.2.12, live client): right-clicking an enemy (e.g. a wolf) while other wolves are near makes ALL of them flash for a moment as if they were all targeted. It does not happen without KstyleUI.

Find the cause in KstyleUI's nameplates (and anything else that reacts to `PLAYER_TARGET_CHANGED`, `UNIT_TARGET`, soft-target or mouseover on plates: target highlight/glow/size/alpha, "Target and focus" options, the plates growing while they cast, range/target fade, Medallions plate styling). Likely suspects: a target check by name or creature ID instead of `UnitIsUnit(plate.unit, "target")`; a restyle on target change that briefly applies the target look to every plate before the per-plate check; an animation or fade that starts on all plates; the soft-target/interact (right-click) path. Grep Forever's UI source at 9dc84f0 (`~/.cache/wow-ui-source/Interface`) for the events and how Blizzard's own plates handle targets; secret-safe (`issecretvalue` before any comparison; `UnitIsUnit` returns may be secret in combat).

Reproduce it in the harness first: several same-name plates, change target (and the right-click soft-target/interact path), sample every plate's alpha/scale/glow/highlight across the transition including the first frame; the test must fail on staging. Fix minimally so only the real target changes; other plates stay exactly as they were through the transition. Default look otherwise pixel-identical.

Lint, python, Nameplates tests, `test-taint-scan`, `test-perf-path-budgets`, `test-perf*` under PUC Lua 5.1; hosted CI green. PR to `staging`: `fix(nameplates): only the target lights up when you target`, `Fixed:` line. Do not merge (it ships as a hotfix).

**Files it may edit**: `KstyleUI_Nameplates/**`, `Core/Events.lua` (only if needed), `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the cause in one line, PR, SHA, run id.
