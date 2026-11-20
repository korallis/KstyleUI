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

These synthetic tests need no client or compiler. Full continents need streamed
geometry, a sparse route graph, WMO doodad/liquid verification and boat/swim/lift
edges. Entrance areas do not prove server-side instance triggers or in-game walks.

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
