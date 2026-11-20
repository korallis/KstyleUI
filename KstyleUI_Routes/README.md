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
