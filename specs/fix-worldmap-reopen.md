# Task (bug): the world map goes wrong after viewing another zone and reopening

A player (Baine, German client, running current staging) reports in #chat: "open map, open different zone, close map, open map. get snip 1". His screenshot isn't available to us yet (the coordinator has asked for it; if it arrives it will be forwarded). Nothing merged so far targets this sequence.

Reproduce the exact sequence in the world map harness (`Tools/regression/worldmap_env.lua`, `worldmap_roads_env.lua`, the `worldmap_*` and `gallery_skins_worldmap` render scenes): open the map on the player's zone, change the shown map to a different zone (both a sibling zone and the continent, via the dropdown, a click and the zoom-out button), close the map, open it again. Check everything KstyleUI draws or changes on the map after the reopen: the skin's panes and their sizes, the quest pane and story rail, nearest-services pins and picker, route lines and the route panel, the reveal overlays, travel stop labels, roads, the player arrow, zoom and any cached map ID. Compare against what Blizzard does on reopen (Forever UI source at `9dc84f0`: `Blizzard_WorldMap` OnShow resets to the player's map). Find whatever is stale, misplaced, duplicated or missing, fix the cause (state cached across map changes, hooks that run once, a resize missed on reopen), and add a regression that runs this sequence and fails on staging today.

If nothing reproduces in the harness, say exactly which states you checked, and list the in-game checks that would pin it down.

Evidence: before/after renders of the reopened map at 1920x1080 and 5120x1440 in both HUD styles, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-worldmap-reopen/`.

**Files it may edit**: the world map files in `KstyleUI_Skins/**` (WorldMap*.lua and their skins), `KstyleUI_Routes/**` (only if routing state is the cause), `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(worldmap): the map is right again after viewing another zone and reopening` with `## Changelog` `Fixed:` lines (credit Baine for the report), `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; never fight Blizzard's map (no repeated hooks, no per-frame work, `test-perf-fights` and `test-perf-worldmap-roads` with no new ceiling); Beast speed rule.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the cause.
