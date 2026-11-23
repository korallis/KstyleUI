# KstyleUI_Routes

## Why

Road geometry must stay out of login. This load-on-demand data addon exports
`KstyleUI_RouteData`, with one deferred constructor per world continent (0 is
Eastern Kingdoms, 1 is Kalimdor), a deferred `overlays` constructor and a small
`travel` table. Skins constructs and indexes each graph once
on its first route, then releases that constructor. The other continent remains
unconstructed. Neither file runs at login.

The simplified ASCII points come from the owner's Forever 1.60.1.70959 client.
These wrappers use the corrected `~/.cache/kstyleui-navmesh/out/graph/` outputs
from `Tools/nav/build_graph.py` at `23dcea6ef6e9710161417f9e441f93fee4b3253a`
(PR #563, merged into staging), including duplicate travel-edge removal.
No client art, meshes, Wowhead, wclbox or third-party addon data are included.
Regenerate with that tool and wrap its returned table in the existing deferred
constructor. Run `python Tools/dev/crlf.py KstyleUI_Routes`.

Edges use world yards. Flights are directed and offered only when both endpoint
names match discovered, same-faction (or neutral) client taxi nodes. Boat/lift
seconds include the graph's fixed wait estimate. Remote transport endpoints
belong to another coordinate system and are excluded from continent searches.
Off-road connectors over 60 yards are dashed and carry the ground warning.

`C_Map.GetWorldPosFromMapPos` returns the world continent ID used by the graphs.
The client extract's `Map.csv` identifies 0 as Azeroth / Eastern Kingdoms and
1 as Kalimdor; these are not UI map IDs. Taxi queries use the player's
`C_Map.GetMapInfo` parent chain up to `Enum.UIMapType.Continent`, with no fixed
UI map IDs. At UI source `9dc84f0`, `MapDocumentation.lua` defines `GetMapInfo`,
`UiMapDetails.mapType` and `parentMapID`; `Blizzard_WorldMapTemplates.lua` follows
that parent chain and `ZoneLabelDataProvider.lua` uses the Continent enum.

Movement re-snaps the player's connector. The existing path and its map dots
stay cached until the nearest start node changes (or the destination or travel
settings change); canvas changes only reproject the path. Both road and direct
lines use a bright three-unit fill and a dark five-unit outline compensated for
canvas scale, below zone labels. The movement-tick check lives in
`test-perf-worldmap-roads.lua` beside the real-graph query budget.

## Overlays and travel stops

`Overlays.lua` and `Travel.lua` come from the owner's Forever 1.60.1.71037
client (build key `0acab1e6aa41b46165d2ca66853b417b`) through
`Tools/nav/build_travel.py` (git blob `e866dbb966f168e72bbf96d9f2e99d7612708a8d`),
which uses the same TACTTool and DBC2CSV export as the graph tool. Copy its two
cache outputs here and run `python Tools/dev/crlf.py KstyleUI_Routes`.

- `overlays()` returns `{[uiMapID]={{width,height,offsetX,offsetY,fileID,...},...}}`:
  579 `WorldMapOverlay` rows whose art `UiMapXMapArt` assigns to a UI map, with
  their layer-0 `WorldMapOverlayTile` file ids in row-major order. One row whose
  tile count does not match its size is left out. Skins builds it only when
  Reveal unexplored areas is on and the map is open, then releases the constructor.
- `travel.zeppelins` lists the `TaxiPath` ids of `Transport,` paths that rise
  above 30 yards between stops; boat docks whose path id is listed are zeppelin
  towers. The road graphs' dock ids are `b<TaxiPath>_<stop>`.
- `travel.tram` holds the Deeprun Tram's two ends on continent 0: the centre of
  each capital's straight gnome tunnel WMO group (`Straight06` in Stormwind,
  `straight01` in Ironforge; Stormwind's lies 55 yards from `Map.db2`'s Deeprun
  Tram corpse point, and the tool refuses more than 80), and 118.5 seconds: the
  tram car's `TransportAnimation` one-way travel of 58.6 seconds plus the fixed
  60-second wait the boats use.

The client lists no static world portal on either continent (`AreaPOI` and
`TaxiNodes` name none), so none ship. Class teleport arrivals are shipped graph
places named by each spell (`Teleport: Stormwind` arrives at the `Stormwind`
AreaPOI); `SpellTargetPosition` is not in the client.
