# Task: find and fix the FPS drop after alt-tab (owner's gameplay video), plus list every visible issue

**Input**:
- **The video:** `C:/Users/leeba/Videos/NVIDIA/_forever_/_forever_ 2026.11.20 - 09.11.07.01.mp4`. It's 9:32 long, 5120x1440, 60 fps capture, 4.6 GB, recorded on v0.2.7 with the Medallions HUD.
- **The owner's words:** "the one that's annoying me most is the fps drop when I alt-tabbed."
- **The coordinator's notes:**
  - the KstyleUI data bar shows an FPS readout at about x 2840-2990, y 1365-1395 in the frame;
  - sampled every 3 s it reads about 110-140 FPS from 0:36 to 1:10, then about 60-80 from about 1:12 to about 3:20, then 100-190 afterwards;
  - the KstyleUI Options window is open for much of 0:40-2:10;
  - the strip is at `C:/Users/leeba/.cache/kstyleui-evidence/video-1120/fps-strip.png`: 6 cells per row, 3 s per cell, row-major from 0:00.

**Do**:
1. **Find the alt-tab moment(s):**
   - use frame differences, the FPS readout read every second (OCR or crops), and the cursor or overlay changes;
   - work out whether the drop is during the alt-tab, which is the client's own background frame cap, or **after returning**. A sustained drop after returning, or one that lasts until something else happens, means KstyleUI is the cause;
   - correlate it with what is on screen: the Options window, the map, combat or zoning.

   Frame extraction: ffmpeg is on PATH. Downscale before analysis, keep crops at native resolution, and put scratch output in `C:/Users/leeba/.cache/kstyleui-evidence/video-1120/`.
2. **Find the cause in code (staging):**
   - every handler for `DISPLAY_SIZE_CHANGED`, `UI_SCALE_CHANGED`, `CVAR_UPDATE` (gxWindow / gxMaximize), focus or visibility, and K.Callbacks `ScaleChanged`;
   - any `OnUpdate` or ticker they start that might never stop, such as a resize debounce, a Layout Mode or mover loop, a Scale.Auto re-measure loop, or the Options window's live preview;
   - re-layouts that repeat every frame after a size change.

   Reproduce it in the regression harness: fire the alt-tab event sequence the client sends, which you must prove in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`, then count instructions per frame afterwards. Steady state must return to baseline within a few frames. Also measure per-frame cost with the KstyleUI Options window open against closed.
3. **Fix it**, with minimal code, pixel-identical output (the memory rule: perf changes must not change visuals; prove it with pixel diffs of the HUD gallery scenes at 1920x1080 and 5120x1440), and a regression test that fails on the old code. If the Options window itself costs a lot per frame while open, fix that too, or report the number if it isn't the cause.
4. **List every other visible issue in the video:** layout overlaps, clipped or overlapping text, wrong sizes, flicker, missing art, inconsistent style. For each, give the timestamp, a crop path and a one-line description. The owner said "there are a couple of issues you will be able to spot." The consumables bar size and backdrop are already being fixed elsewhere; skip that one.

**PR**: open a PR (not a draft) against `staging` titled `fix(core): no FPS loss after alt-tab`, or a better title for the actual cause. Include:
- `## Changelog` (`Fixed: ...`);
- `## In-game checks`: alt-tab out and back several times in fullscreen and windowed, with the FPS readout steady;
- `## Before and after`, with numbers.

Do not merge.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/video-1120/report.md`. Include:
- the alt-tab timestamps and the FPS before, during and after;
- the cause, with file:line;
- the fix;
- the full list of other issues, with crops.

**Files it may edit**: any addon or test files needed for the fix; say why for each. Evidence never committed.

**Gate**: lint, python, the touched modules' tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI. Beast speed rule: no full local Lua suite, and at most 2 renders at a time.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the report path.
