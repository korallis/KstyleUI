# Task: spike: real walkable routes from the Forever client's own terrain (read-only, no PR)

**Goal**: world map routes should follow ground a player can actually walk, not a straight line over a mountain. Addons can't query terrain in game, so the plan is offline:
1. build a navmesh from the Forever client's map files;
2. compute walkable paths between key places;
3. simplify those paths into a small graph that ships in the addon as data. A few hundred KB is the target; a navmesh is never shipped.

Read `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/design.md` ("Route model" and "Data size and upkeep") for context. This spike proves whether the pipeline works on one zone. Build no addon code.

**Steps**:
1. **The client:**
   - find the owner's Forever install (see `Tools/dev/link-addons.sh` for the paths it uses) and report the product and build (1.60.1.70862 expected);
   - confirm whether the data is CASC, which is expected for a modern build;
   - only read the install: copy whatever you extract to `C:/Users/leeba/.cache/kstyleui-navmesh/`, and never write inside the game folder.
2. **The tool.** Candidates:
   - [namigator](https://github.com/namreeb/namigator) (MIT). It reads Alpha to WotLK MPQ clients through StormLib and likely can't read modern CASC, ADT, WMO or M2 formats; check this.
   - TrinityCore's `map_extractor`, `vmap4_extractor`, `vmap4_assembler` and `mmaps_generator` (GPL). They read modern CASC retail builds; we would only use their output, never their code, in the addon.
   - CascLib (or wow.export / wow.tools.local) to pull the files.

   Pick the shortest working path to a Recast navmesh for **Durotar** (map 1, Kalimdor). Say what you had to patch, for example a product name, build keys or file data IDs.
3. **Paths:**
   - compute walkable paths between 10 to 20 Durotar places: Razor Hill, the Orgrimmar gate, Sen'jin, the Valley of Trials, the Echo Isles shore, Thunder Ridge, the Barrens crossing and Ragefire's entrance in Orgrimmar if reachable;
   - simplify them, for example with Douglas-Peucker to about 5 yards;
   - report the point count and estimated KB for the zone, and project it to both continents.
4. **Client data for the other edges.** List what the client's DB2 files give, and extract a sample for Durotar and Kalimdor:
   - `TaxiNodes`, `TaxiPath` and `TaxiPathNode` (the real flight geometry, which also gives flight time);
   - `UiMapLink`, `AreaPOI`, `JournalInstance` / entrance tables, `UiMapAssignment` (map to world coordinates);
   - the explored-overlay tables (`WorldMapOverlay` / `UiMapArt*`).

   Check whether wago.tools covers the Forever product as a cross-check. Confirm that NPC spawn positions (innkeepers, trainers) are **not** in the client; they're server-side.
5. **Proof picture:**
   - draw the Durotar paths over the client's own Durotar map art (extracted, kept in the cache, never committed or shipped) next to the straight line, at 1920x1080;
   - at least one path must visibly go around a ridge or cliff the straight line crosses.

**Licence notes for the report**:
- the tools' licences (we use their output only);
- the data is Blizzard's, extracted from the owner's own client;
- Wowhead and wclbox.com may be used only to cross-check by eye: no scraping and no copying their data. Wowhead's terms forbid automated collection, and wclbox gives no licence and no owner.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/navmesh-spike/report.md`. Keep it short:
- works or doesn't;
- the tool chain and the patches it needed;
- the time to build a continent;
- the data size;
- the DB2 tables and what they give;
- the limits, such as water, swimming, doors and elevators (the Great Lift, Thunder Bluff);
- the proposed pipeline script, as a Python tool in `Tools/` that a later PR adds.

Put the picture paths in the report.

**Constraints**:
- No commits and no PR.
- Python with `-I`.
- Downloaded tools each go in their own directory under `C:/Users/leeba/.cache/kstyleui-navmesh/tools/`. Read a build script before you run it.
- Stop every process you started.
- Beast speed rule: one heavy build at a time.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
