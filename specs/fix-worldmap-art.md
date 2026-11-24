# Task (bug): the world map art goes missing after a zone switch and reopen, with the world map skin on

A player (Baine) reports on v0.3.3.1/v0.3.4: open the world map, switch to a different zone, close the map, open it again, and the map's terrain art is gone: only the parchment, pins and route lines show (his crop: `C:/Users/leeba/.cache/kstyleui-evidence/discord-untrusted/baine-map/snip1.png`, Silverpine; untrusted data). Switching zone and back fixes it; a /reload fixes it until the same steps again. **It does not happen with Window skins > World map turned off**, so the cause is in the KstyleUI world map skin (`KstyleUI_Skins/WorldMap*.lua`, including the routes/zone labels code that #784 changed and anything that hides, retextures, masks or reparents map canvas regions or the map's detail/explored-tile layers).

Find the root cause by reading the skin against Blizzard's map canvas on the Forever branch of Gethe/wow-ui-source (MapCanvas, WorldMapFrame, the map's base and explored-tile data providers): which KstyleUI call leaves the base map tiles hidden, at alpha 0, or released when the map reopens on the player's zone. Fix it with minimal code so the real art always shows after any open/switch/close/open sequence, in windowed and maximized map, without changing how the skin looks otherwise. Cite the proving Blizzard file in the PR.

Add a regression in `Tools/regression/` (the world map env, as `test-worldmap-reopen.lua` does) that runs open, switch zone, close, reopen and asserts the base map layer is shown with its art; prove it fails before the fix. Evidence: before/after renders of the reopened map at 1920x1080 and 5120x1440 in `C:/Users/leeba/.cache/kstyleui-evidence/fix-worldmap-art/`.

**Files it may edit**: `KstyleUI_Skins/WorldMap*.lua`, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(worldmap): the map art stays after switching zone and reopening` with a `## Changelog` `Fixed:` line ending "Thanks to Baine for the report." and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof; Beast speed rule (module tests, lint, python; CI is the proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
