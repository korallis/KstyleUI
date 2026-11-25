# Task (bug, hotfix): world map search covers the map and its Nearest list will not close

A player (Baine, German client, current v0.3.4.2 code) reports two problems with the KstyleUI world map search (`KstyleUI_Skins/WorldMapRoutes.lua`, moved to the canvas top-right in #784). Crop, untrusted data: `C:/Users/leeba/.cache/kstyleui-evidence/discord-untrusted/baine-map/search-dropdown.png` (Orgrimmar).

1. **Placement**: the box and its list sit on top of the map art (on Orgrimmar it covers the top-right of the city map). His point: no fixed spot on the canvas fits every zone. Move the search off the canvas into chrome that never covers map art. First choice: the map's navigation bar row (the breadcrumb strip "Welt > Kalimdor > Orgrimmar"), right-aligned in its empty space, sized to fit and matching the nav bar's height and style, with the results list opening below it over the map only while searching. Prove the nav bar frame name and its layout from the forever branch of Gethe/wow-ui-source (`Blizzard_WorldMap`, the NavBar), and check it in windowed and maximized map, every locale (German breadcrumbs are long), and at 1920x1080, 2560x1440, 5120x1440 and 3840x2160. If the nav bar cannot host it without collisions, pick the next spot that never covers map art and explain why in the PR.
2. **List will not close**: the Nearest list (Naechster Gastwirt, Lehrer, Bank, ...) that opens when the box gets focus stays open when nothing is picked, and is still open after the map is closed and reopened. #784 meant to clear it on close; that did not cover this path. It must close when the box loses focus, on Escape, on a click elsewhere on the map, and when the map closes, and must not reappear on reopen until the box is focused again.

Fix both with minimal code, consistent with the KstyleUI style of the surrounding chrome (one consistent style). Add regressions in `Tools/regression/` (the world map env, as `test-worldmap-reopen.lua` does): the box is not over the canvas; focusing opens the list; losing focus, Escape, a canvas click and close/reopen each leave it closed; prove they fail before the fix. Evidence: renders of the map with the box at rest and with the list open, Orgrimmar and a continent, German and English, at the four sizes, before/after, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-map-search-placement/`, plus 2x crops of the box in the nav bar at 1920x1080 and 5120x1440.

**Files it may edit**: `KstyleUI_Skins/WorldMap*.lua`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md` if a row changes.

**PR**: `fix(worldmap): search sits in the map's nav bar and its list closes` with a `## Changelog` `Fixed:` line ending "Thanks to Baine for the report." and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof; Beast speed rule (module tests, lint, python; CI is the proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
