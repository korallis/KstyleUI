# Task: world map batch 1: smooth zoom, remembered zoom, wheel between maps

**Goal**: the owner wants the world map to zoom like Google Maps. Read the design first: `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/design.md` ("Zoom and pan" and "Batches", item 1). This is batch 1 only: no routes, no POIs and no data files.

**Change** (beside the existing world map skin, `KstyleUI_Skins/WorldMap.lua`, or one new file next to it if that is clearly smaller):
- **Smooth wheel zoom:**
  - put the world map's scroll container in the canvas's smooth wheel mode;
  - turn instant zoom off so the canvas's own `FrameDeltaLerp` eases scale and pan (`MapCanvas_ScrollContainerMixin.lua:3-18`, `:208-216`, `:326-361`; the world map turns it on at `Blizzard_WorldMap.lua:144-147`);
  - keep left click to change map and right click to go to the parent.
- **Wheel between maps:**
  - wheel out at minimum scale goes to the parent map, framed on the child with `C_Map.GetMapRectOnMap` and the existing lerp;
  - wheel in at maximum scale over a child zone opens that child;
  - call `C_Map.RequestPreloadMap` for the map under the cursor only, never for every zone.
- **Remember zoom:** save scale and pan per map id, and re-apply them after the canvas's `ResetZoom` when that map opens again. Keep it to a few numbers in SavedVariables.
- **Options:**
  - Smooth zoom (ON);
  - Remember zoom (ON);
  - Wheel between maps (ON).

  All three go under the existing world map skin settings.
- **Fade while moving:** follow the `mapFade` CVar and don't force it. If an Options toggle for that CVar is a few lines, add it, showing the CVar's current value.

**Rules**:
- Hook, never replace `WorldMapMixin:OnLoad` or the pin providers. No secure frames.
- Works in combat: the map isn't secure, and zoom and lines are allowed. Prove that every API, field and CVar is in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`, and guard each one with an existence check.
- Turning a toggle off restores Blizzard's behaviour exactly: instant zoom, full steps, and no saved zoom applied.
- Minimal code. No inertia or coasting unless it is a few lines and doesn't fight the drag.

**Tests**: behaviour tests in `Tools/regression/` against the stubs:
- smooth mode and the instant-zoom flag are set when ON and restored when OFF;
- wheel out at min scale goes to the parent and wheel in at max scale over a child goes to the child;
- preload is called once for the map under the cursor;
- remember zoom saves and re-applies per map id and survives a reload;
- missing APIs fall back silently;
- `test-perf-path-budgets` still passes.

Extend the stubs only as far as the tests need, and make them raise what the client raises.

**Constraints**:
- One consistent style; everything toggleable and ON by default.
- CRLF/ASCII; locales synced with translations.
- Evidence is never committed. Put it in `C:/Users/leeba/.cache/kstyleui-evidence/worldmap-1/`.
- Update `docs/feature-map.md` and the Skins README.

**PR**: open a PR (not a draft) against `staging` titled `feat(worldmap): smooth zoom that remembers where you were`. Include:
- `## Changelog`: `Added: The world map zooms smoothly with the mouse wheel, remembers your zoom for each map, and wheels out to the continent and in to a zone.`
- `## Options`
- `## In-game checks`: wheel in and out on a zone, the continent and the world; zooming in combat; each toggle off.
- `## Forever API`, citing each proving file.

Do not merge.

**Files it may edit**: `KstyleUI_Skins/**`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `docs/feature-map.md`, `.luacheckrc` (only your module's line, if needed).

**Gate**: lint, python and the world map and skins tests under PUC Lua 5.1, then hosted CI. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
