# Task: find whether KstyleUI piles up work after alt-tabbing (FPS drops until /reload)

**Goal**: a player on v0.2.6 from CurseForge reports FPS drops that start after alt-tabbing out of the game and back in. They last "for a while till I hit /reload". Their screen looks like a 32:9 ultrawide (about 5120x1440), in the Medallions style. The in-game profiler, run while not lagging, showed KstyleUI at 0.03 ms recent average and the total at 0.09 ms. So the cost appears only after focus changes, and a reload clears it. That is the signature of something that accumulates: handlers, timers, `OnUpdate` scripts, animation groups, frames or textures added on every display, scale or focus event and never removed. It could also be a layout loop that keeps re-running.

**Investigate** (latest `origin/staging`):
1. List every handler for the events alt-tab can fire on Forever, and cite the Forever UI source (`C:/Users/leeba/.cache/wow-ui-source`, `forever` at `9dc84f0`) for each event:
   - `DISPLAY_SIZE_CHANGED`, `UI_SCALE_CHANGED`, `CVAR_UPDATE` (for example `gxWindow` or `uiScale`);
   - `PLAYER_ENTERING_WORLD` (check whether it fires);
   - any `OnSizeChanged` on `UIParent` or the root;
   - `Scale.Root()` changes and `Layout.Update`.

   Include the code that resizes, re-applies the layout, rebuilds textures, restarts animations (the Medallions looping animations, the vignette), or calls `C_Timer.NewTicker` or `SetScript("OnUpdate")`.
2. In the stub environments, fire those events 50 times in a row, the way repeated alt-tabs would, with Medallions at 5120x1440 and at 1920x1080. After each round, count tickers, `OnUpdate` scripts, animation groups that are playing, frames, textures and registered events, and the VM instructions per simulated frame. Anything that grows with the number of rounds is a leak. Also check for a resize feedback loop, where one event re-triggers itself.
3. Fix each leak with the smallest change, so the result is idempotent: reuse, guard or cancel instead of adding again. Add a regression test that fails on the leak before the fix and passes after. Visuals must stay pixel-identical (owner rule); prove it with before and after renders at 1920x1080 and 5120x1440.
4. If nothing leaks in KstyleUI, report that with the counts, and name what else could cause it, such as engine-side looping animations, the vignette or texture memory after a device reset, with what to measure in game.

**Constraints**: minimal code; AGENTS.md rules (one event handler per owner, secret values, combat lockdown, CRLF/ASCII); evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/alttab-lag/`). If you fix something, open a **draft** PR against `staging` titled `fix(perf): alt-tabbing no longer piles up work` with `## Changelog` (`Fixed: Frame rate no longer drops after alt-tabbing out of the game and back.`), `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: any addon module that holds a leak, plus `Core/**` and `Tools/regression/**`.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the findings with counts, plus SHA, PR URL and run id if you fixed something.
