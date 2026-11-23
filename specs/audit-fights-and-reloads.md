# Task: audit — KstyleUI must never fight other addons or redo work it does not need (no PR)

The owner (2026-11-22): "make sure stuff isn't loading over and over if it doesn't need to, and we're not competing against other addons. The prime example was Zygor: it took ages to fix the frame rate issues that caused (#685: Zygor reset its font, KstyleUI reset it again, every frame). Ensure this doesn't occur anywhere else."

**Find, with file:line and a proof for each:**
1. **Fights**: every `hooksecurefunc` / script hook / `HookScript` / metatable hook KstyleUI puts on frames it does not own (Blizzard frames, other addons' frames: RestedXP, Zygor, Questie, DBM, Details, WeakAuras, Bartender, ElvUI-likes, Leatrix, BugSack, the skins in `KstyleUI_Skins/Addons/`), where KstyleUI re-applies a value (font, size, point, alpha, texture, scale, colour, parent, shown) in response to the owner setting it. Each is a potential ping-pong. Check whether it guards with "already what I want" / a re-entrancy flag / once per frame, and whether the other side re-applies on its own schedule (OnUpdate, every event, every layout) so the two loop.
2. **Redundant work**: anything that rebuilds, restyles, relayouts, re-reads saved settings or re-creates frames/tables when nothing changed: OnUpdate scripts that run while idle, `C_Timer.NewTicker`/repeating timers, handlers on high-frequency events (UNIT_AURA, UNIT_POWER_FREQUENT, UNIT_HEALTH, COMBAT_LOG_EVENT_UNFILTERED, BAG_UPDATE, NAME_PLATE_*, SPELL_UPDATE_COOLDOWN, ACTIONBAR_UPDATE_*, CURSOR_CHANGED, MODIFIER_STATE_CHANGED) that do full passes instead of the changed unit/slot, restyles that ignore an unchanged-input cache, and settings reads in hot paths.
3. **Load work**: modules that do heavy work at login/reload for features that are off, or repeat it on every zone change/PLAYER_ENTERING_WORLD.

Measure the worst ones in the harness (instructions/allocs per event, per second idle) and rank by real cost. Read `Tools/regression/perf/`, `test-perf*`, `event_guard.lua`, `test-perf-idle-draw`, and #685/#711/#700 for the patterns already fixed.

**Deliver** `C:/Users/leeba/.cache/kstyleui-evidence/audit-fights/<your-family>-REPORT.md`: ranked findings (severity, cost, file:line, proof, minimal fix), plus a proposal for an automated guard that would have caught the Zygor bug (e.g. a harness "fight detector": for every hook KstyleUI installs on a foreign frame, the stub re-applies the foreign value N times and the test asserts KstyleUI's writes stay bounded; or an idle-cost guard), with its expected failure message naming the fix. No code changes, no PR.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the top 5 findings in one line each and the report path.
