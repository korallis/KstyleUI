# Task: world map batch 2: client destinations and search

**Goal**: read `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/design.md` first ("Possible", "Points of interest", "Batches", item 2). Build batch 2 only:
- dungeon and raid entrance level ranges;
- route targets for flight masters, dungeon entrances, map links, tracked quests and live vignettes;
- a search box on the world map.

The route is still a straight line in this batch, and the route card says so. Roads come later from a navmesh, so keep the route drawing behind one small function a later batch can replace.

**Change**:
- **Dungeon entrances:**
  - add the level range to the tooltip and make each entrance a route target. Get the range with `C_EncounterJournal.GetDungeonEntrancesForMap`, then `EJ_GetInstanceInfo`'s `dungeonAreaMapID`, then `C_Map.GetMapLevels`;
  - when that returns 0, 0, leave the range blank (no curated table in this batch);
  - the filter turns on the `showDungeonEntrancesOnMap` CVar.
- **Zone level ranges:** show them on the continent map (`C_Map.GetMapLevels`), with an Options toggle that is ON.
- **Search box:**
  - it searches flight masters (`C_TaxiMap.GetTaxiNodesForMap`), dungeon entrances, map links (`C_Map.GetMapLinksForMap`), area POIs, tracked quests (`C_QuestLog.GetNextWaypoint` / `GetQuestsOnMap`) and live vignettes;
  - picking a result sets `C_Map.SetUserWaypoint` and `C_SuperTrack.SetSuperTrackedUserWaypoint`, then draws the route.
- **Route:**
  - a straight line on the current map from the player to the target;
  - a route card shows the distance and an "about N min" estimate at 7 yd/s on foot, or 14 yd/s when mounted;
  - the card has a clear button.
- **Style:**
  - build the card with `Widgets.Chrome` as a sibling of the docked quest log, in KstyleUI card chrome and fonts (caps titles, number face for yards and minutes);
  - one consistent style with the quest card;
  - draw no duplicate pins: Blizzard already draws flights, entrances, group icons and vignettes.
- **Options:**
  - Search and routes (ON);
  - Dungeon level ranges (ON);
  - Zone level ranges (ON);
  - the dungeon entrance filter (ON).

**Rules**:
- Hook, never replace; no secure frames; works in combat.
- Prove every API, struct field and CVar in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`, guard each with an existence check and `issecretvalue` where relevant, and degrade silently when one is missing.
- A batch 1 PR (smooth zoom, dispatch ctx_e2cb8fde4231) is in flight on the same skin. Keep your code in its own file where you can, and rebase onto `origin/staging` before opening the PR.

**Tests** (behaviour, against the stubs):
- the level range comes from the EJ and map-level chain, with a blank fallback;
- search finds each source type and ignores missing APIs;
- picking a result sets the user waypoint and super track;
- the distance and time maths;
- each toggle off removes its piece and restores Blizzard;
- `test-perf-path-budgets` passes.

Renders at 1920x1080 and 3840x2160 of the world map with a search result and the route card, over real game backdrops.

**Constraints**:
- Minimal code, no new framework. Everything toggleable and ON by default.
- CRLF/ASCII; locales synced with translations.
- Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/worldmap-2/`).
- Update `docs/feature-map.md` and the Skins README.

**PR**: open a PR (not a draft) against `staging` titled `feat(worldmap): search the map and route to dungeons, flights and quests`. Include:
- `## Changelog`: `Added: Search the world map for flight masters, dungeon entrances and your quests, see dungeon and zone level ranges, and get a route card with distance and time.`
- `## Options`, `## In-game checks`, `## Forever API` and `## Before and after`.

Do not merge.

**Files it may edit**: `KstyleUI_Skins/**`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `.luacheckrc` (only your module's line).

**Gate**: lint, python and the world map and skins tests under PUC Lua 5.1, then hosted CI. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
