# Client navigation routes

Run from the repository root with Python 3.12+ and Pillow:

```powershell
python -I Tools/nav/build_routes.py --install 'C:/Program Files (x86)/World of Warcraft'
```

`KSTYLEUI_WOW` supplies the install when `--install` is omitted; the default is
shown above. Close WoW first: locked CASC archives can make TACTTool fall back to
Blizzard's CDN. The active `wowf` build/CDN keys come from `.build.info`.
The install and repository are read-only; all generated files stay under
`~/.cache/kstyleui-navmesh/`. Tested with Forever 1.60.1.70959 on Windows.

## Prepare the tools

- Install Pillow with `python -m pip install Pillow` and have Git on PATH.
- Use TACTTool at `~/.local/share/wow-dev/casc/TACTTool/TACTTool.exe`.
- Install the .NET 10 runtime at `~/.local/share/wow-dev/dotnet/dotnet.exe`
  and [DBC2CSV v1.0.11](https://github.com/Marlamin/DBC2CSV/releases/tag/v1.0.11)
  (Windows x64) at `~/.local/share/wow-dev/casc/DBC2CSV/DBC2CSV.dll`, keeping its
  `definitions/` folder. `Tools/icons/casc_export.py` exports TaxiNodes and AreaPOI
  through the same TACTTool/DBC2CSV path used by the icon tools.
- Unpack the official [Zig 0.17.1 Windows x86-64 archive](https://ziglang.org/download/)
  to `~/.cache/kstyleui-navmesh/tools/zig/zig-x86_64-windows-0.17.1/`.

The first run fetches Recast/Detour into the cache and checks out
`9f4ce64458dfae86e1239c525ddc219c4e9e06f1`. To fetch it yourself:

```powershell
git clone --filter=blob:none https://github.com/recastnavigation/recastnavigation.git "$HOME/.cache/kstyleui-navmesh/tools/recastnavigation"
git -C "$HOME/.cache/kstyleui-navmesh/tools/recastnavigation" checkout --detach 9f4ce64458dfae86e1239c525ddc219c4e9e06f1
```

The tool builds `nav.cpp` and the Recast/Detour sources with `zig c++ -O2
-std=c++17 -DDT_POLYREF64`, using both include directories; source changes rebuild
it. No third-party source is vendored. A shared `build.lock` permits one build at
a time; after an interruption, verify its PID has exited before removing it.

## Outputs and rules

- `out/Durotar.lua` and `out/Barrens.lua`: complete routes simplified at 5 yards,
  as `{from,to,{{x,y,z},...},mode="walk"}` records. Cross-zone routes occur in both.
- `<version>/<build-key>/summary.json`: connectivity, every endpoint's original,
  seed and final coordinates, source, radius, distance moved, exclusions, failures,
  runtime and per-zone points/bytes; logs, `TaxiNodes.csv` and `AreaPOI.csv` are beside it.
- `durotar-barrens-routes-1920.png` in that build directory: 1920x1080 over client
  map art, using the 1002x668 map viewport rather than padded tile dimensions.

Terrain includes holes and shallow water up to 1.5 yards; deep water blocks
walking. MODF supplies WMO group collision (MOPY/MPY2), MDDF supplies M2 collision,
and filename filtering omits foliage. Recast uses 1-yard cells, 0.2-yard vertical
cells, 1.4-yard climb, 50-degree slope, 2-yard clearance and a radius rounded to one
cell. Its 256-yard tiles share an aligned grid and four cells of border context.
ADT heights alternate rows of 9/8 vertices; treating them as separate arrays was
the spike's seam bug. Model winding also changes with Recast's handedness.

Client AreaPOI/TaxiNodes positions replace invalid centroids first; other seeds
snap to the nearest main-component polygon within 200 yards in xyz (POIs 20,
taxi nodes 8, bridge pivot 80). Ragefire uses Orgrimmar's named DungeonEntrance
WMO group. Echo Isles retains its island point within 8 yards and is excluded as
needing a swim or boat; an inaccessible Ragefire interior is explicitly excluded.
Other failures remain in the target. Below 90% eligible walking connectivity, or
an unresolved eligible endpoint, exits **3**. Partial/truncated paths never ship.
There are **no swim edges** or swimming connectivity claims in this version.

```powershell
python -I -m unittest discover -s Tools/tests -p 'test_nav_*.py'
```

These synthetic tests need no client or compiler. Entrance areas do not prove
server-side instance triggers or in-game walks.

## Continent graphs

```powershell
python -I Tools/nav/build_graph.py --install 'C:/Program Files (x86)/World of Warcraft'
```

This uses the same cache, tools and exclusive build lock. It processes Eastern
Kingdoms and Kalimdor sequentially. `Map`, `AreaTable`, `UiMap` and
`UiMapAssignment` supply continent assignments and map bounds; `AreaPOI` and
`TaxiNodes` supply named destinations. ADT area samples supply other named areas,
including inns, and adjacent zones supply crossing nodes. These are client-named
areas, not a directory of NPCs or quest givers. The named Orgrimmar
`DungeonEntrance` group supplies Ragefire's entrance area.

Python holds one ADT soup and at most 32 decoded collision assets. The native
builder streams these soups into disk-backed 256-yard raster tiles and builds
one tile at a time. The resulting Detour mesh remains resident for queries.
Vertical bounds are local to each tile. Exceptionally tall geometry needs a
larger vertical cell than 0.2 yards to fit Recast's 13-bit spans; the log reports
every such tile, and clearance/climb stay in yards. A bounded A* fallback handles
continent queries that exhaust Detour's 65,535 search nodes. Neither partial nor
truncated corridors ship.

Each place chooses its six shortest reachable walking neighbours within a
3,500-yard horizontal radius. The shortest remaining candidate links join
disconnected neighbour clusters, so a dense town can retain its exit. Longest
edges are then removed one at a time only if an existing two-hop **walking**
alternative is at most 110% of their length. This preserves connectivity; the
10% rule is local and does not guarantee 10% total route stretch. Shared
half-yard xyz path vertices become junctions, identical segments are stored
once, and degree-two bends collapse to a 5-yard Douglas-Peucker polyline.
Overpasses at different heights stay separate.

Precise POI/taxi seeds project within 30 yards, dock seeds within 120, lift
landings within 25 and area/crossing seeds within 120/80 yards. Area/crossing
projections prefer the largest nearby component to avoid isolated props;
precise pins choose the nearest surface. Unresolved places remain in the
500-pair sample and in the endpoint report, rather than disappearing from its
denominator.

Special edges are explicit:

- `swim`: separate queries add MH2O water/ocean surfaces to nearby collision
  soups. `LiquidType.SoundBank` 0/1 permits water/ocean; magma/slime are excluded.
  Only complete paths of at most 600 yards between different walking components
  survive, with the shortest crossing per component pair. The estimate uses
  4.7 yd/s. Static collision still applies to these queries.
- `boat`: delayed spline stops on paths involving a `Transport, ...` taxi node
  supply docks and their actual maps. Several taxi positions are zero or
  offshore, so they are not used as docks. The estimate includes a fixed
  60-second wait plus travel at 20 yd/s. Cross-continent coordinate jumps are
  excluded from the measured length.
- `lift`: the largest upward horizontal floor in the client's named `elevator`
  and `bottom` WMO groups supplies the Great Lift and Thunder Bluff landings.
  A link is added only when the walking mesh cannot join both landings. Its
  estimate includes 30 seconds of waiting and 8 yd/s of travel.
- `flight`: directed `TaxiPath` hops use the `TaxiPathNode` polyline's length
  divided by 32 yd/s. `Cost` is never interpreted as seconds. All travel time
  estimates carry `about=true`; faction/known-flight filtering belongs to the
  future runtime consumer.

Outputs under `~/.cache/kstyleui-navmesh/`:

- `out/graph/EasternKingdoms.lua` and `out/graph/Kalimdor.lua`: one table each,
  `{map=<continent>, nodes={...}, edges={...}}`. Nodes have `id,name,x,y,kind`.
  Edges have `a,b,kind,len,pts={x1,y1,x2,y2,...}`; lift points also retain z.
  Coordinates and lengths round to 0.5 yd. Flights have `directed=true`;
  special edges also have `seconds,about=true`. A remote boat endpoint carries
  its own `map`; other nodes inherit the table's map. Do not draw a line between
  endpoints on different maps as if they shared a coordinate frame. Cross-map
  transport joins the two tables by stable string dock id; other ids are compact
  integers scoped to the continent. The endpoint report maps DB2 ids to graph ids.
- `<version>/<build-key>/graph/summary.json`: per-continent node/edge counts,
  bytes, build seconds, connectivity on a deterministic random sample of 500
  place-pairs, and median walking detour against complete navmesh-direct paths.
  Each continent's `summary.json` also retains projected endpoint coordinates,
  component ids and unresolved endpoints. Detour's random-pair walking success
  and the graph's walking success are reported separately from travel routes.
- `graph/Azeroth.png` and `graph/Kalimdor.png` below that build directory:
  graphs over the client's own Forever `_c60` continent art and DB2 map bounds.
  Cross-continent transport lines are omitted from the single-map pictures.

This is a static walking/travel graph, not a guarantee of an in-game journey.
WMO-contained doodads and WMO liquid surfaces still need verification; terrain
MH2O, WMO group collision and ADT M2 collision are included. Moving transports,
instance triggers, faction restrictions and actual wait times need in-game
checks. No addon data, client art or meshes are written to the repository.

## Licences and data

Recast/Detour is [zlib](https://github.com/recastnavigation/recastnavigation/blob/main/License.txt);
external TACTTool/TACTSharp is [MIT](https://github.com/wowdev/TACTSharp/blob/main/LICENSE).
Preserve their notices if distributing them. Zig and Pillow retain their upstream
licences. DBC2CSV/DBCD uses the WoWDBDefs definitions; geometry format references are the
MIT wow.export readers, and the geometry implementation grew from the owner's
spike. TACTTool obtains a community filename list; all coordinates, geometry, DB2 records and map art are Blizzard's,
from the owner's client. Extracts, meshes, images and evidence stay in cache;
only reviewed simplified points could ship in a later addon-data PR. No Wowhead,
wclbox, GPL source/extractor or third-party addon code is used.
