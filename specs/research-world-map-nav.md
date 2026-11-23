# Task: research a "Google Maps" world map for KstyleUI: routes, smooth zoom, and Mapster and Leatrix Maps features (read-only, with mockups)

**Goal**: the owner wants the main world map to feel like Google Maps or Google Earth:
- **Real routes** to points of interest: walkable paths, roads and passes, flight paths, boats and zeppelins, portals. Today the player picks a straight line and tries to climb a mountain they can't cross.
- **Smooth zoom and pan**, like Google Earth.
- **The best features of Mapster and Leatrix Maps.**

Find out what's possible on Forever and how to do it well, then propose a design. Build nothing yet.

**Research** (cite file:line in the Forever UI source, `C:/Users/leeba/.cache/wow-ui-source` at `forever` `9dc84f0`; public pages only for other addons, and copy no code):
1. **Routing feasibility, the key question.**
   - Addons have no terrain or navmesh API. Say exactly what the client exposes: map IDs and positions (`C_Map`), flight masters and taxi nodes (`C_TaxiMap`), map links and zone connections, dungeon entrances, area POIs, waypoints (`C_Map.SetUserWaypoint`, `C_SuperTrack`), and anything else useful.
   - Find how existing addons do routing without terrain: TomTom, Questie, RestedXP's guide arrows, Mapzeroth or Routes, and any "travel planner" (behaviour only). Where do they get path data: hand-made road and node graphs, crowd-sourced data, or recorded player paths? What licences apply?
   - Propose a realistic route model, for example a graph built from known roads and passes, zone connections, flight paths, boats, zeppelins, portals and the player's own known travel (Hearthstone and the class teleports from KstyleUI's TravelData). Routing over the graph should work with no network access. Say honestly what can't be known, such as an exact walkable line over terrain, and how the UI shows it (route along roads and passes, then a straight final leg with a warning).
   - Estimate the data size and the cost of building and maintaining it for Classic-era continents.
2. **Smooth zoom and pan.** What the Forever world map canvas allows: `WorldMapFrame` ScrollContainer, `SetCanvasScale` or zoom levels, pan, and the restrictions on map frames in combat. Is continuous wheel zoom with inertia possible, and does zooming from the world to a continent to a zone to a sub-zone feel like Google Earth? What does it cost?
3. **Mapster and Leatrix Maps features.** List them, from their public docs and pages, and mark each as possible on Forever or not, with the API:
   - map scale and size, fade while moving, coordinates for the player and cursor;
   - unexplored area reveal (needs overlay data: what source and licence?);
   - zone level ranges, dungeon and raid entrances, flight points;
   - remembering zoom, group and raid icons, the quest log beside the map, and others.
4. **Integration with KstyleUI.** Today's world map skin, the minimap module, the crest travel menu (#508's TravelData), the data bar's Hearthstone readout, and the quest card. How does the new map fit the one consistent style? Use the KstyleUI card chrome, its fonts and the Medallions details.

**Mockups**: render the current world map skin (see the gallery scenes) at 1920x1080 over real scenery. With Pillow, mock up:
- a route from the player to a quest POI that follows roads and a pass, with turn markers, a distance and time estimate, and a "flight path saves 3 min" suggestion;
- a zoom-level strip showing world → continent → zone;
- a side panel with route steps in KstyleUI card chrome.

Use only real repo art, and save everything to `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/`.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/design.md`. Keep it short:
- what's possible and what isn't, with honest limits;
- the route model and its data source and licence;
- the zoom approach;
- the feature list with defaults (owner rule: everything toggleable and ON by default, unless it changes Blizzard behaviour in a way players wouldn't expect);
- risks: combat restrictions, data maintenance, reload and memory cost;
- PR-sized batches with line and data estimates.

Change no code.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
