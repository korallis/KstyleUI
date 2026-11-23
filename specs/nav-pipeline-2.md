# Task: route pipeline step 2: both continents and a sparse shared road graph

`Tools/nav/` is on staging (PR #560). It builds Recast navmeshes from the owner's Forever client: read-only `wowf` 1.60.1.70959 via TACTTool, with terrain, WMO and M2 collision and liquids. It connects 190 of 190 walkable place-pairs in Durotar and the Barrens. Read `Tools/nav/README.md`, `C:/Users/leeba/.cache/kstyleui-evidence/nav-pipeline-1/report.md` (its "next" section) and the world map design `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/design.md` ("Route model").

**Goal**: produce the data the world map will ship. That is a **sparse shared graph** per continent (Kalimdor, the Eastern Kingdoms), not all-pairs routes:
- **nodes:** settlements, flight masters (`TaxiNodes`), docks, zone crossings, dungeon-entrance areas, inns and quest hubs the client names (AreaPOI, area ids), plus junction nodes where routes merge;
- **edges:** simplified walking polylines (5-yard Douglas-Peucker) between nearby nodes, each with its length in yards.

Routes that share a road share its edges. At runtime Dijkstra over this graph finds the path, and a final leg from the nearest node is drawn dashed.

**Change** (tool only; the addon data file is written to the cache, not the repo):
- **Scale to whole continents:**
  - stream tiles so Python memory stays bounded;
  - discover places and map assignments per continent from the DB2 CSVs;
  - one heavy build at a time.
- **Graph building:** connect each node to its k nearest reachable neighbours (k of about 4-6, within a yard cap) through the navmesh, then prune any edge whose path is within about 10% of an existing two-hop path. Keep it simple and explain the rule.
- **Special edges:**
  - deep-water crossings become explicit `swim` edges where short, with a length cap;
  - boats and zeppelins become `boat` edges between the `Transport, …` taxi nodes, with a fixed wait estimate;
  - known lifts (the Great Lift, Thunder Bluff) become `lift` edges where the mesh can't join them;
  - flight hops become `flight` edges from `TaxiPath` / `TaxiPathNode`, with length from the polyline. The `Cost` column isn't proven to be seconds, so use length over a nominal flight speed and label it "about".
- **Output:** one Lua table per continent in `C:/Users/leeba/.cache/kstyleui-navmesh/out/graph/`:
  - nodes `{id, name, x, y, kind}`;
  - edges `{a, b, kind, len, pts = {x1,y1, x2,y2, ...}}` in world coordinates, with z dropped unless it's needed for lifts;
  - compact numbers rounded to 0.5 yd.
- **Report:**
  - node and edge counts per continent;
  - KB per continent, with a target under about 300 KB each;
  - the share of a random sample of 500 place-pairs a graph route connects;
  - the median detour against the navmesh-direct path (it should stay under about 15%);
  - build time;
  - pictures of both continents' graphs over the client's own continent map art (cache only).
- **Tests:** synthetic tests for the graph pruning and the Lua writer in `Tools/tests/test_nav_*.py`.

**PR**: open a PR (not a draft) against `staging` titled `build(tools): continent road graph for world map routes`, with the `no changelog` label. Do not merge.

**Constraints**:
- Minimal code; reuse what's in `Tools/nav/` and `Tools/icons/casc_export.py`.
- Read-only on the game install. LF for tools.
- Data, art and meshes stay in the cache.
- No Wowhead or wclbox data, no GPL source.
- Beast speed rule: one heavy build at a time, no full local Lua suite.

**Files it may edit**: `Tools/nav/**`, `Tools/tests/test_nav_*.py`.

**Gate**: lint and python, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, the report path and the graph file paths.
