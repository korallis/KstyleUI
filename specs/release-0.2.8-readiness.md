# Task: v0.2.8 readiness check on staging (read-only): GO or NO-GO

**Goal**: v0.2.8 goes to the owner and to players through the stores. Since v0.2.7, staging gained:
- the world map zoom, search and routes;
- the setup addons step;
- the action bar picker and two batches of per-bar options;
- the consumables bar at half size;
- Layout Mode label fixes;
- the player frame power text change;
- the guide card size-to-fit and the durability move;
- the Options Tasks and Text pages.

Check that nothing ships broken. Use the latest `origin/staging`, and name the SHA.

**Check** (renders in `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.8/`, never committed; at most 2 renders at a time):
1. **The HUD:** a `hud_reference --strict` matrix of 3 HUD styles x DPS/Tank/Healer at 1920x1080, 2560x1440, 5120x1440 (Centred and Spread) and 3840x2160, over real game backdrops. Every render must pass strict. Look at:
   - the consumables bar;
   - the action bars;
   - the unit frames' power text;
   - the right column (minimap, durability, quest and guide cards);
   - any overlap.
2. **The other screens:** the world map (zoom, search and route card), the setup's Your addons step, the Action Bars Options page with Bar 2 selected, and Layout Mode, at 1920x1080 and 5120x1440. Use the scenes in `Tools/render/scenes/` and `docs/feature-map.md`.
3. **Upgrade safety:** boot staging with a v0.2.7-shaped saved profile (`git show v0.2.7:` fixtures, or the upgrade regressions) for every module, and confirm there are no errors.
4. **Checks:** `test-perf-path-budgets` passes (report the reload number against 15.7M); `bash scripts/gate.sh lint` and `python` pass.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.8/readiness.md`, giving **GO**, or **NO-GO with the exact blockers** (file:line, render path). Change no code. Be fast.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
