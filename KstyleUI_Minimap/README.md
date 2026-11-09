# KstyleUI_Minimap

The Lumen minimap: a round lens under a glass dome over a frost foot card, the card being the lens plus its foot, the zone and clock in the foot, the north mark on the lens's top edge, a zoom slider, rim buttons round the lens, an addon-button drawer and coordinates.

| Field | Value |
| --- | --- |
| Module name | `Minimap`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Minimap.toc` lists `Minimap.xml`, which loads every Lua file in order, so adding a file never edits the TOC |
| Layout element | `minimap.main`: resizable, 318 by 346 units at the 1080 reference (`Core/Setup/Layouts.lua`), the Lumen mockup's minimap card: a round lens 6 units (`Format.RIM`) inside the card's top and sides, as large as the width or the room over the 34-unit foot (`Format.FOOT`) allows, so the default card holds a 306 lens with the zone and clock in the foot under it. Over the lens's centre line the glass is a dome, the top half of a disc one rim wider than the lens; under it the frost card is the foot. The card has no head band and no square corners of glass: the glass round the lens is a rim, not a slab |
| Tests | `Tools/regression/test-minimap.lua` (the module against stand-ins for Forever's minimap frames, built by `Tools/regression/minimap_env.lua`), `test-minimap-column.lua` (the button column and the secure overlay), `test-minimap-drawer.lua` (the addon drawer against a LibDBIcon stand-in), `test-minimap-format.lua` (the pure helpers) and `Tools/tests/test_make_minimap_glyphs.py` (the glyph sheet) |
| Media | `Media/Glyphs.png`, drawn by `Tools/media/make_minimap_glyphs.py`; its row is in `Media/PROVENANCE.md` |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- Blizzard frames keep a reskin after `Disable`, so turning the module off asks the player to reload.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Minimap.xml` loads them in this order.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Format.lua` | Pure helpers: coordinate and clock text, zone colour tokens, wheel zoom steps, the zoom slider's share and level, the lens's place in its card (`Format.Lens`), the rim buttons' arc, and the drawer's direction, grid and size |
| `Settings.lua` | Defaults, the settings page rows and `Settings.Get(key)`, which gives the default for a saved value the row does not allow |
| `Style.lua` | The accent (class or custom colour) and each text's font, size and outline |
| `Data.lua` | Reads from the game: zone and PvP type, local and realm time, coordinates, map rotation, game rules, mail, calendar invites, the queue and tracking. Each read checks the API exists and that the value is not secret. |
| `Face.lua` | The visible card, shared by the live map and the preview: the frost card, the round lens and its mask, the foot, the north mark on its crystal disc, the zoom slider and the coordinates |
| `SecureClick.lua` | One shared secure button that clicks Blizzard's own calendar, clock, world map and queue buttons for KstyleUI's buttons |
| `Column.lua` | The button column: tracking, mail, calendar, group finder status and the drawer button, built from `Widgets.IconButton` with the glyph sheet |
| `Drawer.lua` | The addon drawer: LibDBIcon buttons in a glass flyout, and the addon compartment's list |
| `Map.lua` | The live minimap: hosting Blizzard's `Minimap`, hiding the cluster, wheel and slider zoom, events and the clock ticker |
| `Preview.lua` | The settings window's preview, with a drawn map instead of Blizzard's |
| `Module.lua` | `Modules.Register` and `Options.Register` |

## What it does on Forever

Forever loads `Blizzard_Minimap` with its `Camelot/` overrides: `MinimapCluster` holds the header (`ZoneTextButton`), `Tracking`, `IndicatorFrame` (mail), `MinimapContainer` with `Minimap` and Camelot's day and night orb (`DielFrame`), and the cluster also parents `GameTimeFrame` (calendar), `TimeManagerClockButton` (clock) and `AddonCompartmentFrame`. `Minimap` holds `ZoomIn`, `ZoomOut`, `ZoomHitArea` and `MinimapBackdrop`, whose `MinimapCompassTexture` is the round border.

When the module starts it:

1. Builds `KstyleUI_Minimap` on `KstyleUI_Root` and registers it as `minimap.main`.
2. Moves `Minimap` into the card's lens square: `SetParent`, then one `CENTER` point and the lens's size, so later resizes never touch Blizzard's frame beyond that. It waits for Edit Mode to close, and for combat to end if the frame is ever protected.
3. Sets the round lens mask (`Widgets.LumenTexture("lensMask")`, `Media/Textures/LensMask.png`) and leaves the arch, quest and task blob rings at their full scale, since the lens is round. A hook on `MinimapCluster.UpdateMinimapConfig`, which Camelot runs when `rotateMinimap` changes (`Blizzard_Minimap/Camelot/Minimap.lua`, `MinimapClusterMixin:UpdateMinimapConfig` calls `minimap:SetMaskTexture(data.mask)` with Blizzard's round `ui-hud-minimap-frame-generic-mask`), puts KstyleUI's mask back.
4. Hides `MinimapCluster`, `MinimapBackdrop`, `Minimap.ZoomIn`, `Minimap.ZoomOut` and `Minimap.ZoomHitArea` through `KstyleUI.Safe.HideBlizzard`. Hiding the cluster hides the header, tracking, mail indicator, calendar, clock, compartment, day and night orb and Blizzard's coordinates with it.
5. Sets the global `GetMinimapShape` to return `"ROUND"`, which minimap button libraries read to place buttons on the edge.
6. Gives `HybridMinimap.CircleMask` the same lens mask when `Blizzard_HybridMinimap` loads.

Turning it off puts `Minimap` back in its container with its saved points, size, level and Blizzard's mask, brings the hidden frames back, withdraws `GetMinimapShape` and asks for a reload.

### The card and the lens

`Minimap:SetMaskTexture` takes a file (`MinimapFrameAPIDocumentation.lua`: one `TextureAsset` argument), which the game stretches over the frame, so the round lens mask makes a circle of any size. `Format.Lens(width, height, rim, foot)` places the lens in the card: the largest circle that fits inside the rim at the sides and between the rim at the top and the foot at the bottom, centred across the card and, when the width limits it, in the middle of the room over the foot. On the 318 by 346 card that is a 306 lens 6 units in from each side and 6 under the top. The glass follows the lens: `Face:Layout` sets a dome (`face.dome`: the lens mask's top half in the panel's fill, the glass tint and, one border wider, the rim colour) a rim round the lens's top half, and the frost card (`face.foot`, the panel chrome) from one corner cut over the lens's centre line, so its cut corners sit inside the dome, to the card's bottom, as wide as the dome. The card's top corners show the world. The foot keeps its height whatever the card's size; with the zone and the clock both off, the foot is a rim too. The preview's drawn terrain uses the same mask (`face.mask`, a `MaskTexture` over the lens square).

The 198-in-217 size defect the owner met live (the map rendering at its `SetSize` size, not its anchors) is why `Fit` sizes `Minimap` as well as anchoring it.

### Zoom

A frame with only the mouse wheel enabled covers the lens square, so clicks and pings still reach `Minimap`, and the wheel works right up to the lens's edge, outside Blizzard's round hit area. It steps `Minimap:SetZoom` one level within `GetZoomLevels()`. With **Zoom back out** on, the map returns to zoom 0 after the delay; a newer zoom restarts the wait.

The zoom slider is the mockup's thin line inside the lens's left edge: a 2 by 52 track, 11 units in from the lens's edge, on its centre line, with an accent fill that grows from the bottom as the map zooms in. A 12-unit-wide frame of KstyleUI's own takes the mouse: a click or a drag on it reads the cursor's height on the track and sets the nearest level with `Minimap:SetZoom`, through the same path as the wheel, so **Zoom back out** applies. The fill follows every zoom: KstyleUI's own calls refresh it, a `hooksecurefunc` on `Minimap.SetZoom` catches Blizzard's zoom buttons, the gamepad stick and the zoom-back-out timer, and `MINIMAP_UPDATE_ZOOM` (which Forever's `MinimapMixin` registers for the engine's own zoom changes) refreshes it as well, so the slider never guesses. It hides when the lens is too small for it. `Minimap` is not a protected frame and `SetZoom` is an ordinary method (`MinimapFrameAPIDocumentation.lua` flags it only as `SecretArguments = "AllowedWhenUntainted"`), so the slider works in combat and never touches Blizzard's `ZoomIn`, `ZoomOut` or `ZoomHitArea`, which stay hidden.

### The foot

The foot is the card's bottom 34 units, under the lens, inside the card's inset: the zone name on the left in capitals in the heading face, the clock on the right in the number face, on the card's own glass with no plate or divider of their own. It hides when neither shows, and the lens takes the room. Hovering the zone lists the zone, subzone and PvP status; hovering the clock shows local and realm time, in the kit's tooltip.

| Clock format | Text |
| --- | --- |
| Game clock settings | Local or realm time and 12 or 24 hours, from the `timeMgrUseLocalTime` and `timeMgrUseMilitaryTime` CVars that Blizzard's clock options set |
| Local time, 24-hour or 12-hour | `date("*t")` |
| Realm time, 24-hour or 12-hour | `GetGameTime()` |

The clock ticks once a second through `C_Timer.NewTicker`, only while the module runs and the clock shows. A client without `NewTicker` counts with `OnUpdate` and logs it.

### Coordinates and the north mark

Coordinates come from `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition`. They update on zone changes, and every 0.2 s only while the player moves (`PLAYER_STARTED_MOVING` to `PLAYER_STOPPED_MOVING`, and `PLAYER_CONTROL_LOST` to `PLAYER_CONTROL_GAINED` for flight paths). No position, as in instances, or a secret one hides them.

The north mark is a gilt heading-size N on a 22-unit crystal disc (`Format.COMPASS_PLATE`, the rim buttons' dark disc and light ring) centred on the lens's top edge, half over the glass and half over the map, so it reads over any terrain. It shows while `rotateMinimap` is off. A secret rotation hides it rather than guess. Coordinates at the top of the lens drop below the disc.

### The rim buttons

The buttons sit on the lens's rim, as the mockup draws them: round 22-unit crystal discs (a dark disc with a light ring and a glyph) along an arc that starts 52 degrees up from the lens's horizontal (`Format.ARC_START`) on the chosen side and steps one button and one spacing round the circle (`Format.Arc`), from the top down or from the bottom up. Only the buttons that apply show, and the rest close up.

| Button | Shows | Click |
| --- | --- | --- |
| Tracking | While `C_Minimap` tracking exists and the `IngameTrackingDisabled` game rule is off | A KstyleUI menu through `MenuUtil.CreateContextMenu`: a checkbox for each optional filter and tracking spell, as Blizzard's own menu lists them (`MinimapConstants.OPTIONAL_FILTERS`, or every type with the `minimapTrackingShowAll` CVar), and **Uncheck all**, which keeps the always-on and conditional filters on. Each checkbox calls `C_Minimap.SetTracking`. |
| Mail | While `HasNewMail()` is true (`UPDATE_PENDING_MAIL`) | None. The tooltip lists `GetLatestThreeSenders()`. |
| Calendar | Unless the `IngameCalendarDisabled` game rule is on. A badge and the accent tint mark pending invites (`CALENDAR_UPDATE_PENDING_INVITES`). | Left: `GameTimeFrame`, the calendar. Right: `TimeManagerClockButton`, the clock options. |
| Group finder | While `QueueStatusButton` is shown, checked on Blizzard's `QueueStatusUpdate.QueuesUpdated` callback. While this button is on, Blizzard's eye stays shown but faded to alpha 0 with its mouse off; a `SetAlpha` hook keeps it faded. | Both buttons: `QueueStatusButton`, so its own menu and windows open. |

The zone name and the clock on the strip work the same way: the zone clicks `MinimapCluster.ZoneTextButton` (the world map), and the clock clicks `TimeManagerClockButton`, or `GameTimeFrame` on a right click.

### The addon drawer

The last button in the column opens a glass flyout of other addons' minimap buttons.

- **Collecting.** It reads `LibDBIcon-1.0` through `LibStub` when the module starts, on `PLAYER_ENTERING_WORLD`, the frame after each `ADDON_LOADED`, and on the library's `LibDBIcon_IconCreated` callback, which it subscribes to the first time it finds the library. KstyleUI never loads or embeds the library. Each button moves into the drawer: its drag is turned off (`RegisterForDrag()`), its fixed strata released so the drawer cannot cover it, its ring and background stripped through `KstyleUI.Skin.Strip`, and a chamfered tile put behind it with `Skin.Backdrop`. Buttons sort by name.
- **Staying put.** A `hooksecurefunc` on each button's `SetPoint` puts it back in its slot when the library re-anchors it to `Minimap`. Hooks on its `SetAlpha` and its `fadeOut:Play` keep a show-on-mouseover button opaque while it is in the drawer. Hooks on `Show` and `Hide` re-lay the grid when an addon hides or shows its button, and a button the addon hid takes no place.
- **Opening.** A click toggles it, mouseover opens it and closes it half a second after the pointer leaves both the drawer and its button, or it stays open. It opens away from the map unless a direction is chosen, and fills a grid of icons, a set number per row. Clicking an addon button closes the drawer unless **Close after a click** is off.
- **The addon compartment.** Blizzard's compartment is part of the hidden cluster, so a right click on the drawer button, or a left click while the drawer is empty, lists `AddonCompartmentFrame.registeredAddons` in a KstyleUI menu, sorted by name. Each entry takes any mouse button, as Blizzard's does, and runs the addon's own function. KstyleUI reads Blizzard's list and never sorts or changes it.
- **Handing back.** Turning the drawer button or the module off clears each button's anchors, puts it back on its first parent, lets it drag again and calls the library's `Refresh(name)`, which places it on the lens's round edge (`GetMinimapShape` returns `"ROUND"` while the module runs).

### Secure clicks

KstyleUI never opens a Blizzard window from its own code, so the click reaches Blizzard's own button through one `SecureActionButtonTemplate` button with `type = "click"` and `clickbutton1` and `clickbutton2`. Blizzard's handler then runs untainted. The button follows the reload button's pattern in the widget kit:

- It is made on the first hover out of combat, parented to `UIParent`, so no KstyleUI frame becomes protected.
- On hover it covers the hovered button, five levels above it, takes the button's hover, press and tooltip, and detaches when the pointer leaves or the button hides.
- `PLAYER_REGEN_DISABLED` fires before lockdown and detaches it. In combat it never moves, and a click on a KstyleUI button prints that it works after combat.
- `Button:Click()` runs on hidden buttons, so Blizzard's buttons work inside the hidden cluster.

## Settings

Layout gives the element its position, size, shown rule, opacity and strata on the module's page. The module adds:

| Key | Default | Row |
| --- | --- | --- |
| `accent.source`, `accent.color` | `class`, the kit's accent | Hairline colour: class or custom colour |
| `column.side`, `column.growth` | `right`, `down` | The rim buttons on the lens's right or left side, and whether they start at the top or the bottom |
| `column.size`, `column.spacing` | 22, 7 | Button size and the gap between buttons |
| `column.tracking`, `column.mail`, `column.calendar`, `column.queue`, `column.drawer` | on | Each button |
| `drawer.behaviour`, `drawer.direction` | `click`, `auto` | Open on click, on mouseover or always; which way it opens |
| `drawer.size`, `drawer.spacing`, `drawer.columns` | 24, 4, 6 | The drawer's icon size, gap and icons per row |
| `drawer.autoClose`, `drawer.compartment`, `drawer.hideEmpty` | on | Close after a click, the compartment list, and hiding the button while there is nothing to show |
| `zoom.wheel`, `zoom.slider`, `zoom.reset`, `zoom.delay` | on, on, off, 10 s | Wheel zoom, the zoom slider and zooming back out |
| `compass` | on | The north mark |
| `zone.shown`, `zone.color` | on, `plain` | Zone name, coloured plainly, by PvP status or with the accent |
| `clock.shown`, `clock.mode` | on, `game` | The clock and its format |
| `coords.shown`, `coords.precision`, `coords.position` | off, 1, `top` | Coordinates, 0 to 2 decimals, at the top or above the strip |
| `zone.*`, `clock.*`, `coords.*` `font`, `size`, `outline` | interface font; 14, 14, 10; none | Each text's typeface, size (times the Appearance text size) and outline |

## Why

- **Hosting `Minimap` instead of replacing it.** The spec has Layout Mode replace a Blizzard frame that needs a new place with a KstyleUI frame. The minimap renderer cannot be replaced: an addon cannot make a second `Minimap`. So the module hosts the one Blizzard gives it, which is not protected, and moves only that frame. The calls are listed with this reason in `Tools/regression/taint_allow/KstyleUI_Minimap.lua`. Everything else in the cluster is hidden through `Safe`, never moved.
- **One `CENTER` point and a size.** `Minimap` renders at its `SetSize` size, not at its anchors (seen live: a 198 map inside a 217 lens), so `Fit` centres it on the lens square and sizes it to the lens on every resize, and nothing else about Blizzard's frame changes.
- **Hiding the whole cluster.** Forever's 1.60.1 reskinned the minimap header and moved its children, and Camelot and Edit Mode both re-anchor them (`SetHeaderUnderneath`). Hiding the cluster as one frame survives those changes; KstyleUI draws its own zone, clock and buttons instead of restyling Blizzard's.
- **The panel's centre is clear.** The map covers the fill's centre, the shadow's centre and the grain, and `HybridMinimap` draws in the `BACKGROUND` strata, under KstyleUI's `LOW` frame, so any of them would darken it. The chrome's `Paint` is wrapped on this one panel so a restyle never brings them back.
- **A wheel-only catcher.** Blizzard's `Minimap` takes the wheel only inside its round hit area. A frame with just `EnableMouseWheel` covers the whole square without stealing clicks, motion or pings.
- **The queue eye is faded, not hidden.** Forever anchors `QueueStatusButton` to `Minimap` by default (`GROUP_FINDER_RELATIVE_TO` in `Blizzard_EditMode/Camelot`), so it would sit on KstyleUI's map. Hiding it through `Safe` would break its right-click menu: `Blizzard_Menu` closes a menu whose owner is not visible. So the eye stays shown at alpha 0 with its mouse off, and the column's button clicks it through the secure overlay.
- **The drawer is part of the minimap element.** It is a flyout hung on its own button, like a menu, so it moves with the minimap and has no Layout key of its own; its icon size, spacing, columns and direction are its settings.
- **Third-party buttons are moved, Blizzard's are not.** The drawer reparents LibDBIcon buttons, which other addons own, and lists in the allow-list that `button:SetParent` touches only them.
- **A KstyleUI tracking menu.** Blizzard's menu sets settings-backed filters through `MinimapUtil` and the Settings system. Calling that from addon code would taint the Settings system, so KstyleUI's menu calls `C_Minimap.SetTracking` directly. The Options panel's trivial-quest checkbox may lag until its next refresh.
- **A secure overlay instead of calling Blizzard.** `ToggleCalendar`, `ToggleWorldMap` and the queue eye's handler load or show Blizzard windows. Called from addon code they run tainted; clicked through a secure button they run as Blizzard's own. The overlay is one module file, not a kit component, because it is input plumbing with no look of its own.
- **The rim buttons are an arc, not a column.** They hold at most four status buttons, so they have a side, an order, a size and a spacing but no rows or columns; the addon drawer is the icon grid.
- **The card is the lens plus its foot.** The judges read the first Lumen card as a round lens in a square slab: a 24-unit head band and a 20-unit inset left dark glass round the circle. The card then hugged the lens at a 6-unit rim and kept only the foot, and the north mark rides the lens's edge instead of a head. Round 3 (Muse #3) still read the square card's corners round the circle as slab: the glass over the lens's centre line is now a dome that follows the lens, as the mockup's arched card does, and the lens fills the card's width.
- **Coordinates update only while moving.** The spec allows `OnUpdate` only while something moves. Movement events start and stop it, so a player standing still costs nothing.
