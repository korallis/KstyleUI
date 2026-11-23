# Task: fix nameless route steps and a nameless raid tile

Two player-visible bugs the v0.3.0 marketing render worker saw on `origin/staging` (both shipped in v0.3.0):

1. World map routes: routing to the nearest innkeeper (Window Skins > World map > Nearest services, from #740) shows a step reading `3. Road to` with no name. Find where route step labels come from (`KstyleUI_Skins/WorldMapRoutes.lua`, `WorldMapRoads.lua`, `WorldMapServices.lua`) and give every step a name: the service NPC's name or kind ("Road to the innkeeper"), the zone or the nearest named node. Check other services, travel stops (#742) and quest routes for the same gap.
2. Raid frames: the `frame_raid` render scene shows one solid blue raid tile with no name. Find out whether it is a fixture problem in the scene (for example a unit with no name or a pet) or real addon behaviour (a tile that loses its name, for example a secret or missing name). If real, fix it; if fixture-only, fix the scene and say why.

Each fix gets a regression test that fails before it. Evidence: before/after renders (the nearest innkeeper route and `frame_raid`) at 1920x1080 and 3840x2160 in `C:/Users/leeba/.cache/kstyleui-evidence/fix-route-step-names/`.

**Files it may edit**: `KstyleUI_Skins/WorldMap*.lua`, `KstyleUI_GroupFrames/**` (only if the tile bug is real), locales, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(worldmap): name every route step` (with a `## Changelog` `Fixed:` line per bug in player words). Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests only locally, hosted CI as proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and what each cause was.
