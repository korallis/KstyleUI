# KstyleUI_Routes

## Why

Road geometry must stay out of login. This load-on-demand data addon exports
`KstyleUI_RouteData`, with one deferred constructor per world continent (0 is
Eastern Kingdoms, 1 is Kalimdor). Skins constructs and indexes each graph once
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
