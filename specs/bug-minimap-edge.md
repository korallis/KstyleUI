# Task: the minimap runs off the screen edge on a 5120x1440 screen

**Goal**: the owner's in-game screenshot (`C:\Users\leeba\.cache\lee-shots\minimap-2026-11-19.png`, 5120x1440, Medallions, Spread or Centred; crop `C:\Users\leeba\.cache\lee-shots\minimap-crop.png`) shows the round minimap is not right: the ring is cut off by the right edge of the screen (and touches the top), the zone-name plaque ("TIRISFAL GLADES") sits over the top of the ring, and the coordinates/clock bar under it runs to the screen edge. The minimap, its plaque and its bar must sit fully on screen with a margin that matches the rest of the HUD, the plaque must not cover the map, and the three must line up as one piece, at every supported screen size.

**Target**: KstyleUI on latest `origin/staging`. Find the minimap module and its placement (grep `Minimap` in `KstyleUI_*` and `Core/Setup/Layouts.lua`, `Core/Setup/EditMode.lua`); render scenes `Tools/render/scenes/gallery_minimap.lua`, `minimap_plaque.lua`, `minimap_ornaments.lua`. Check the Forever UI source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`, clone `C:\Users\leeba\.cache\wow-ui-source`) for the minimap cluster's real size and anchors (MinimapCluster, Minimap, zone text) and name the proving file. Find out why the harness did not catch it (the scenes may not place the minimap at the screen corner the way the game does).

**Change**: smallest fix to the minimap's default placement and plaque/bar offsets so the whole minimap group stays inside the screen with the HUD's edge margin, and the plaque sits above (not over) the ring. Existing players with a custom minimap position keep it; only previous defaults move (a store migration, next free number after the latest on staging, if needed). Add a regression test over the screen sizes the layout tests use (1280x720 to 5120x1440, 3456x2234) that the minimap group's bounds are inside the screen with the margin and the plaque does not overlap the map, and make the render scene place the minimap where the game does. Render before/after at 1920x1080 and 5120x1440 over a real backdrop (`--backdrop /c/Users/leeba/.cache/kstyleui-backdrops/game_NN.png`), at most 2 at a time.

**Options**: a fix; no new setting.

**Constraints**: minimal code; AGENTS.md rules (CRLF/ASCII, no new top-level local in `Core/Setup/Layouts.lua`, combat lockdown, Forever API grep). Another worker changes `KstyleUI_Meters` and meter placement in `Layouts.lua`; keep to the minimap entries and rebase before the PR. Open a **draft** PR against `staging`: title `fix(minimap): stays on screen with its plaque above the ring`, `## Summary` (the cause), `## Changelog` (`Fixed: The minimap no longer runs off the edge of wide screens, and the zone name no longer covers the map.`), `## In-game checks`, `## Before and after`.

**Files it may edit**: the minimap module's files, `Core/Setup/Layouts.lua` and `Core/Setup/EditMode.lua` (minimap entries only), `Core/Store.lua` (one migration if needed), `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the minimap/layout tests locally; green Mac CI is the full proof.

**Evidence of done**: the cause; the regression test red before and green after; before/after renders; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
