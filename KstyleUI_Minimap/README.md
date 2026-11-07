# KstyleUI_Minimap

Square minimap, chamfered frame, zone and clock strip inside its bottom edge, side button column, addon-button drawer and coordinates.

| Field | Value |
| --- | --- |
| Module name | `Minimap`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Minimap.toc` lists `Minimap.xml`, which loads every Lua file in order, so adding a file never edits the TOC |
| Layout element | `minimap.main`: resizable, keeps its proportions, 226 by 196 units at the 1080 reference |
| Tests | `Tools/regression/test-minimap.lua` (the module against stand-ins for Forever's minimap frames, built by `Tools/regression/minimap_env.lua`) and `test-minimap-format.lua` (the pure helpers) |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- Blizzard frames keep a reskin after `Disable`, so turning the module off asks the player to reload.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Minimap.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Minimap.xml` loads them in this order.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Format.lua` | Pure helpers: coordinate and clock text, zone colour tokens, wheel zoom steps, the map square's place in the element |
| `Settings.lua` | Defaults, the settings page rows and `Settings.Get(key)`, which gives the default for a saved value the row does not allow |
| `Style.lua` | The accent (class or custom colour) and each text's font, size and outline |
| `Data.lua` | Reads from the game: zone and PvP type, local and realm time, coordinates, map rotation. Each read checks the API exists and that the value is not secret. |
| `Face.lua` | The visible frame, shared by the live map and the preview: the chamfered square, the strip, the north mark and the coordinates |
| `Map.lua` | The live minimap: hosting Blizzard's `Minimap`, hiding the cluster, wheel zoom, events and the clock ticker |
| `Preview.lua` | The settings window's preview, with a drawn map instead of Blizzard's |
| `Module.lua` | `Modules.Register` and `Options.Register` |

## What it does on Forever

Forever loads `Blizzard_Minimap` with its `Camelot/` overrides: `MinimapCluster` holds the header (`ZoneTextButton`), `Tracking`, `IndicatorFrame` (mail), `MinimapContainer` with `Minimap` and Camelot's day and night orb (`DielFrame`), and the cluster also parents `GameTimeFrame` (calendar), `TimeManagerClockButton` (clock) and `AddonCompartmentFrame`. `Minimap` holds `ZoomIn`, `ZoomOut`, `ZoomHitArea` and `MinimapBackdrop`, whose `MinimapCompassTexture` is the round border.

When the module starts it:

1. Builds `KstyleUI_Minimap` on `KstyleUI_Root` and registers it as `minimap.main`.
2. Moves `Minimap` into the frame's map square: `SetParent`, then `SetAllPoints` on the square, so later resizes never touch Blizzard's frame. It waits for Edit Mode to close, and for combat to end if the frame is ever protected.
3. Sets the square mask (`Tokens.Texture("minimapMask")`) and sets the arch, quest and task blob rings to 0, since their round rings do not fit a square map. A hook on `MinimapCluster.UpdateMinimapConfig`, which Camelot runs when `rotateMinimap` changes, puts the square mask back.
4. Hides `MinimapCluster`, `MinimapBackdrop`, `Minimap.ZoomIn`, `Minimap.ZoomOut` and `Minimap.ZoomHitArea` through `KstyleUI.Safe.HideBlizzard`. Hiding the cluster hides the header, tracking, mail indicator, calendar, clock, compartment, day and night orb and Blizzard's coordinates with it.
5. Sets the global `GetMinimapShape` to return `"SQUARE"`, which minimap button libraries read to place buttons on the edge.
6. Masks `HybridMinimap.CircleMask` square when `Blizzard_HybridMinimap` loads.

Turning it off puts `Minimap` back in its container with its saved points, size, level and Blizzard's mask, brings the hidden frames back, withdraws `GetMinimapShape` and asks for a reload.

### Wheel zoom

A frame with only the mouse wheel enabled covers the map square, so clicks and pings still reach `Minimap`, and the wheel works in the square's corners, outside Blizzard's round hit area. It steps `Minimap:SetZoom` one level within `GetZoomLevels()`. With **Zoom back out** on, the map returns to zoom 0 after the delay; a newer zoom restarts the wait.

### The strip

The strip sits inside the map's bottom edge: the zone name on the left in capitals, the clock on the right. It hides when neither shows. Hovering the zone lists the zone, subzone and PvP status; hovering the clock shows local and realm time, in the kit's tooltip.

| Clock format | Text |
| --- | --- |
| Game clock settings | Local or realm time and 12 or 24 hours, from the `timeMgrUseLocalTime` and `timeMgrUseMilitaryTime` CVars that Blizzard's clock options set |
| Local time, 24-hour or 12-hour | `date("*t")` |
| Realm time, 24-hour or 12-hour | `GetGameTime()` |

The clock ticks once a second through `C_Timer.NewTicker`, only while the module runs and the clock shows. A client without `NewTicker` counts with `OnUpdate` and logs it.

### Coordinates and the north mark

Coordinates come from `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition`. They update on zone changes, and every 0.2 s only while the player moves (`PLAYER_STARTED_MOVING` to `PLAYER_STOPPED_MOVING`, and `PLAYER_CONTROL_LOST` to `PLAYER_CONTROL_GAINED` for flight paths). No position, as in instances, or a secret one hides them.

The north mark shows while `rotateMinimap` is off. A secret rotation hides it rather than guess.

## Settings

Layout gives the element its position, size, shown rule, opacity and strata on the module's page. The module adds:

| Key | Default | Row |
| --- | --- | --- |
| `accent.source`, `accent.color` | `class`, the kit's accent | Hairline colour: class or custom colour |
| `column.side` | `left` | Which side of the map the button column uses |
| `zoom.wheel`, `zoom.reset`, `zoom.delay` | on, off, 10 s | Wheel zoom and zooming back out |
| `compass` | on | The north mark |
| `strip.opacity` | 0.8 | The band behind the zone and clock |
| `zone.shown`, `zone.color` | on, `plain` | Zone name, coloured plainly, by PvP status or with the accent |
| `clock.shown`, `clock.mode` | on, `game` | The clock and its format |
| `coords.shown`, `coords.precision`, `coords.position` | on, 1, `top` | Coordinates, 0 to 2 decimals, at the top or above the strip |
| `zone.*`, `clock.*`, `coords.*` `font`, `size`, `outline` | interface font; 9, 11, 10; none | Each text's typeface, size (times the Appearance text size) and outline |

## Why

- **Hosting `Minimap` instead of replacing it.** The spec has Layout Mode replace a Blizzard frame that needs a new place with a KstyleUI frame. The minimap renderer cannot be replaced: an addon cannot make a second `Minimap`. So the module hosts the one Blizzard gives it, which is not protected, and moves only that frame. The calls are listed with this reason in `Tools/regression/taint_allow/KstyleUI_Minimap.lua`. Everything else in the cluster is hidden through `Safe`, never moved.
- **`SetAllPoints` rather than `SetSize`.** Anchoring `Minimap` to the map square once means Layout Mode's resizing, a profile change or a rescale never calls a method on Blizzard's frame again.
- **Hiding the whole cluster.** Forever's 1.60.1 reskinned the minimap header and moved its children, and Camelot and Edit Mode both re-anchor them (`SetHeaderUnderneath`). Hiding the cluster as one frame survives those changes; KstyleUI draws its own zone, clock and buttons instead of restyling Blizzard's.
- **The panel's centre is clear.** The map covers the fill's centre, the shadow's centre and the grain, and `HybridMinimap` draws in the `BACKGROUND` strata, under KstyleUI's `LOW` frame, so any of them would darken it. The chrome's `Paint` is wrapped on this one panel so a restyle never brings them back.
- **A wheel-only catcher.** Blizzard's `Minimap` takes the wheel only inside its round hit area. A frame with just `EnableMouseWheel` covers the whole square without stealing clicks, motion or pings.
- **Coordinates update only while moving.** The spec allows `OnUpdate` only while something moves. Movement events start and stop it, so a player standing still costs nothing.
