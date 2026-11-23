# Task: world map batch 3: routes that follow real roads

**Context**:
- On staging, world map batches 1 and 2 give smooth zoom, search, and a route card that draws a straight line (`KstyleUI_Skins/WorldMapRoutes.lua`).
- PR #563 (being finished) builds a sparse road graph per continent from the owner's client navmesh: `Tools/nav/build_graph.py`, with output in `C:/Users/leeba/.cache/kstyleui-navmesh/out/graph/EasternKingdoms.lua` and `Kalimdor.lua`, about 310 KB each.
  - **Nodes** are `{id, name, x, y, kind}`.
  - **Edges** are `{a, b, kind, len, pts = {x1,y1,...}}`, where `kind` is walk, swim, boat, lift or flight. Flight edges are directed, and the special ones carry `about` estimates.
  - Coordinates are world yards.

  Mainland walking connectivity is 95.1% (EK) and 92.7% (Kalimdor).
- Read the design, `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/design.md` ("Route model", "Batches" item 3), and `Tools/nav/README.md` on the #563 branch.

**Change**:
- **Data:**
  - add the two graph files to the addon as load-on-demand data, read only the first time a route is asked for on that continent, never at login. Put them in a small LoD addon such as `KstyleUI_Routes`, or load them lazily inside Skins if the TOC rules allow it. Pick the smaller option that keeps the reload budget flat (`test-perf-path-budgets`, about 15.03M of 15.7M today);
  - regenerate the files from the #563 tool once #563 merges. Until then, use the cached files and say so;
  - data files are ASCII Lua with CRLF (`crlf.py`). Check `check_toc.py`.
- **Routing:**
  - Dijkstra over the graph, with cost in seconds: walk 7 yd/s on foot or 14 mounted (use the mount state the route card already uses), swim 4.7, and boat, lift and flight from their `about` estimates;
  - snap the player and the target to the nearest node within about 60 yards. Draw any leg longer than that as a dashed line with the card note "the ground may block this", as batch 2 does today;
  - a heap or a simple O(n²) is fine at about 1,500 nodes, but measure the cost per route and keep it under about 5 ms in PUC Lua.
- **Drawing:**
  - the route line follows the edge polylines on the current map (world to map coordinates through `C_Map.GetMapPosFromWorldPos`), with diamond turn markers at junctions;
  - flight, boat and swim legs are styled distinctly but in one consistent style.
- **Route card:**
  - total "about N min";
  - steps listed as "Road to X", "Flight from A to B", "Boat to …" and "Swim", with yards and time each;
  - when a flight saves at least a minute over walking, a "Flight path saves N min" chip;
  - KstyleUI card chrome, as today.
- **Fallback:** if the player or target is on another continent, or nothing connects, draw the straight line and say why.
- **Options:** "Follow roads" (ON) under the world map settings; off restores batch 2's straight line.
- **Combat:** no `SetMapID` from addon code in combat, as in #553 and #554; drawing is fine.

**Tests** (behaviour, stubs):
- a small synthetic graph, where Dijkstra picks the road over a mountain shortcut that isn't an edge, flight is chosen when faster, and directed flights are respected;
- the snap and dashed-leg rule;
- lazy loading: no graph memory or instructions at login, loaded once on the first route;
- the toggle off restores the straight line;
- the route cost per query under budget;
- `test-perf-path-budgets` passes.

**Renders**: Durotar to the Crossroads on foot, and Orgrimmar to Thunder Bluff using a flight, at 1920x1080 and 5120x1440, strict, over real game backdrops. Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/worldmap-3/`, never committed.

**PR**: open a PR (not a draft) against `staging` titled `feat(worldmap): routes follow real roads, flights and boats`. Include:
- `## Changelog`: `Added: World map routes follow roads, passes, flights and boats, with turn-by-turn steps and travel time.`
- `## Options`, `## In-game checks`, `## Forever API`, `## Before and after`;
- the data size and the per-route cost.

Do not merge.

**Constraints**:
- Minimal code; one consistent style; CRLF/ASCII; locales synced.
- No Wowhead or wclbox data; the data is Blizzard's, from the owner's client, simplified.
- Beast speed rule: no full local Lua suite, at most 2 renders at a time.

**Files it may edit**: `KstyleUI_Skins/**`, a new `KstyleUI_Routes/**` if chosen (and its `.pkgmeta` line if packaging needs it; say why), `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `.luacheckrc` (only your module's line).

**Gate**: lint, python, the world map and skins tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
