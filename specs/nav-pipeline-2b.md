# Task: route graph connectivity: why is the continent navmesh fragmented? (continue PR #563)

PR https://github.com/korallis/KstyleUI/pull/563, branch at `a8c89221c1098264b8799a0409b0fbfe6d660306`. Read the report, `C:/Users/leeba/.cache/kstyleui-evidence/nav-pipeline-2/report.md`, and the pictures `Azeroth.png` and `Kalimdor.png` beside it.

**Problem**:
- out of 500 random place-pairs, the **navmesh itself** connects only 300 in the Eastern Kingdoms and 228 in Kalimdor;
- the graph then keeps almost all of those (299/300 and 226/228), so the graph is fine and the mesh is fragmented.

In the real game nearly all of mainland Kalimdor and the Eastern Kingdoms is walkable from anywhere, through passes, bridges, tunnels and towns. Players can't be routed with 46-60% coverage.

**Do**:
1. **Diagnose:**
   - list the mesh components by size;
   - for the largest disconnected components, find the cut between neighbours: which ADT, at what coordinates, on what geometry (a tile seam, a WMO-contained doodad such as a bridge plank, gate or stairs, WMO liquids, a steep but walkable road the 50-degree slope or 1.4-yard climb rejects, a door in a city WMO, a tunnel such as the Thandol Span, the Deeprun approach or Southfury);
   - give picture crops of the 10 biggest cuts over client art.
2. **Fix the causes in the tool**, smallest first:
   - WMO-contained doodads (the MODD and MODS sets of placed WMOs) for collision;
   - WMO liquids;
   - walkable slope and climb tuned against known passes, while a 10-yard cliff stays rejected (keep the native cliff test);
   - seam handling at streamed tile borders at continent scale;
   - any coordinate or rotation bug for WMOs and M2s far from the origin.
3. **Target:** navmesh-direct connectivity of at least 90% of sampled mainland place-pairs on each continent. Exclude true islands, instanced or underground places and other unreachable places from the denominator **only** with a stated reason per place, and list them. The graph must keep at least 98% of the navmesh-direct pairs. Graph size stays under about 350 KB per continent.
4. **Report and pictures:** update the report and the pictures, with before and after connectivity and the cut list.

**Push to the same PR branch**: tool code and tests only. The output stays in the cache.

**Constraints**:
- Minimal code; read-only on the install; no GPL source; no Wowhead or wclbox data.
- Beast speed rule: one heavy build at a time, no full local Lua suite.

**Files it may edit**: `Tools/nav/**`, `Tools/tests/test_nav_*.py`.

**Gate**: lint, python and the native seam and cliff checks, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, run id, the connectivity before and after, and the report path.
