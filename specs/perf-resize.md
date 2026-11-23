# Task: make a screen-size change cheap (the alt-tab hitch), pixel-identical

**Goal**: a player reports frame drops after alt-tabbing out of the game and back. The #518 investigation (`C:/Users/leeba/.cache/kstyleui-evidence/alttab-lag/probe-alttab.txt`) found no leak. But each real screen-size change, such as alt-tab in exclusive fullscreen or a resolution or scale change, costs **17.7M to 22.6M addon instructions**, more than a whole reload (13.8M). That's a hitch on every alt-tab, and possibly several if the events fire more than once.

**Change** (latest `origin/staging`):
- Find what runs on `DISPLAY_SIZE_CHANGED`, `UI_SCALE_CHANGED`, `CVAR_UPDATE` and root size changes (`Core/Scale.lua`, `Core/Layout/**` and module `ScaleChanged` and `Refresh` handlers). Profile it per function with the existing perf tooling.
- **Coalesce:** if several events fire for one alt-tab, do the work once, on the next frame, after the last one.
- **Skip no-ops:** if the effective root size and scale come out the same as before, as they do when alt-tab only toggles focus, do nothing.
- **Do less:** re-lay out and rebuild only what depends on the size. Don't rebuild textures, fonts or option schemas that don't change.
- Never raise a budget. The result is **pixel-identical**: base and after renders at all four sizes (1920x1080, 2560x1440, 5120x1440, 3840x2160) after a simulated size change and back.

**Tests**:
- a new budget test: one size change and back costs less than X instructions (set X from your measurement with headroom, and justify it);
- 3 events in a row do the work once;
- a no-op size event does nothing;
- `test-perf-path-budgets.lua` and the scale and layout tests still pass.

**Constraints**: minimal code; AGENTS.md rules (combat lockdown, so protected re-layout waits for `Combat.Queue`); evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/perf-resize/`). Stay clear of the Layout Shown rules, which another PR is changing. Open a PR (not a draft) against `staging` titled `perf(scale): alt-tab and screen-size changes do far less work` with `## Changelog` (`Fixed: Alt-tabbing out of the game and back no longer causes a stutter.`), `## In-game checks` and `## Before and after`. Do not merge. Lua shard 1 may fail only on `test-perf-path-budgets` until #519 merges.

**Gate**: lint, python and the touched tests under PUC Lua 5.1, never LuaJIT. Send worker_done once local proof is done, without waiting for queued CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the before and after instruction counts, SHA, PR URL and run id.
