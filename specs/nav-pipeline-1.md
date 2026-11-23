# Task: the navmesh route pipeline as a repo tool, connecting Durotar and the Barrens

**Context**: the spike proved the idea. Its report, `C:/Users/leeba/.cache/kstyleui-evidence/navmesh-spike/report.md`, describes TACTTool reading the owner's `wowf` 1.60.1.70959 CASC install read-only, then a Python ADT reader, then Recast at a 1-yard cell, then Douglas-Peucker at 5 yards. Its picture is `durotar-routes-1920.png`. But only 3 of 120 Durotar place-pairs connect, because of:
- water (quads under the sea dropped);
- missing WMO geometry: bridges, Orgrimmar, Razor Hill buildings;
- a 2.5-yard climb that rejects chunk borders and canyon lips.

The spike's tools and scratch are in `C:/Users/leeba/.cache/kstyleui-navmesh/`.

**Goal**: turn the spike into a repeatable repo tool and get real connectivity. This PR ships **no addon data** yet, only the tool and its tests.

**Change**:
- Add `Tools/nav/build_routes.py`, run with `python -I`. It:
  1. reads `.build.info` for `wowf` and refuses to write inside the game folder. The install path comes from an argument or an env var; the default is `C:/Program Files (x86)/World of Warcraft`;
  2. extracts with TACTTool (`~/.local/share/wow-dev/casc/TACTTool/TACTTool.exe`) the continent WDT, root and obj ADTs, the WMOs they place (MODF) and the M2 doodads that matter for walking (MDDF, such as bridges and ramps; skip foliage);
  3. builds the triangle soup:
     - terrain with holes;
     - WMO groups, collision only;
     - M2 collision;
     - liquids, where shallow water up to about 1.5 yards deep is walkable and deep water blocks or is marked swim;
  4. runs Recast with climb and slope settings tuned so chunk borders join and cliffs don't, typically walkableClimb near 1 to 1.5 yards with correct border handling. Fix the actual border seam bug rather than raising the climb;
  5. finds paths between places, simplifies them, and writes a Lua point list per zone to `C:/Users/leeba/.cache/kstyleui-navmesh/out/`, not into the repo yet.

  Recast/Detour is zlib. Build it from source into the cache with the Zig toolchain the spike used. Don't vendor its source into the repo; the tool documents how to fetch and build it.
- **Places:** Durotar's 16 places from the spike plus the Barrens: the Crossroads, Ratchet, Camp Taurajo, the Southfury crossing, the Wailing Caverns entrance area and the Barrens flight masters (from `TaxiNodes.csv`).
- **Target:** at least 90% of place-pairs within and between Durotar and the Barrens connect. Every failure is explained: an island, a lift, or water that needs a boat.
- **Picture:** routes over the client's own map art for Durotar and the Barrens at 1920x1080, in the cache only.
- **Tests:** a Python test in `Tools/tests/` for the pure parts (ADT chunk parsing on a tiny synthetic fixture, Douglas-Peucker and the Lua writer). No game files in the repo.
- **README:** `Tools/nav/README.md`, a short how-to-run plus the licences: Recast zlib; TACTTool; the data is Blizzard's, from the owner's client, and only simplified points ever ship; no Wowhead or wclbox data; no GPL source.

**Constraints**:
- Minimal code. Tools are LF.
- Beast speed rule: one heavy build at a time.
- Read-only on the game install.
- Evidence and outputs never committed.

**PR**: open a PR (not a draft) against `staging` titled `build(tools): navmesh route pipeline for the world map`, with the `no changelog` label. Do not merge.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/nav-pipeline-1/report.md`. Include:
- connectivity before and after;
- the points and KB per zone;
- the time to build;
- the picture paths;
- what's needed for the full continents.

**Files it may edit**: `Tools/nav/**`, `Tools/tests/test_nav_*.py`, `.gitignore` (only if needed).

**Gate**: lint and python, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the report path.
