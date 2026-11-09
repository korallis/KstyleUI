# KstyleUI_Minimap

The square minimap: Blizzard's map inside a thin Lumen rim, 160 units square by default, the zone name along the map's top edge and the clock along its bottom edge, coordinates, a zoom slider, the tracking, calendar and addon-drawer buttons that show only while the pointer is over the map, and the mail and queue indicators that show whenever they apply.

| Field | Value |
| --- | --- |
| Module name | `Minimap`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Minimap.toc` lists `Minimap.xml`, which loads every Lua file in order, so adding a file never edits the TOC |
| Layout element | `minimap.main`: resizable from 100 to 320 units, square, 160 by 160 at the 1080 reference (`Core/Setup/Layouts.lua`). The map sits 2 units (`Format.INSET`) inside the element on every side; the rim is a socket chrome with no fill, shadow, grain or gilt, whose chamfer is the mask's cut at the map's size (`Format.Chamfer`). At the owner's 2383 by 1540 screen and 768/1080 UI scale, 1.426 px a unit, the element is 228 px: 81% of the width of Blizzard's own 198-unit round map with about the same visible area (the 156 square shows 24,336 units against the circle's 30,791) and half the 318 by 346 lens card it replaces |
| Tests | `Tools/regression/test-minimap.lua` (the module against stand-ins for Forever's minimap frames, built by `Tools/regression/minimap_env.lua`), `test-minimap-column.lua` (the button column and the secure overlay), `test-minimap-drawer.lua` (the addon drawer against a LibDBIcon stand-in), `test-minimap-format.lua` (the pure helpers) and `Tools/tests/test_make_media.py` (the glyph sheet, and the mask's three numbers against `Format.lua`) |
| Media | `Media/Glyphs.png`, drawn by `Tools/media/make_minimap_glyphs.py`; its row is in `Media/PROVENANCE.md`. The mask is the kit's `MinimapMask.png` |

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
| `Format.lua` | Pure helpers: coordinate and clock text, zone colour tokens, wheel zoom steps, the zoom slider's share and level, the map's inset, bands and edge, the mask's cut as a share of the side (`Format.MASK_SHARE`, from `make_media.py`'s three numbers) and the rim's chamfer from it (`Format.Chamfer`), the button column's slots (`Format.Column`), and the drawer's direction, grid and size |
| `Settings.lua` | Defaults, the settings page rows and `Settings.Get(key)`, which gives the default for a saved value the row does not allow |
| `Style.lua` | The accent (class or custom colour) and each text's font, size and outline |
| `Data.lua` | Reads from the game: zone and PvP type, local and realm time, coordinates, game rules, mail, calendar invites, the queue and tracking. Each read checks the API exists and that the value is not secret. |
| `Face.lua` | The visible face, shared by the live map and the preview: the rim, the map square and its mask, the zone and clock bands on their fades, the coordinates, the hover group (`face.reveal`) and the zoom slider in it |
| `SecureClick.lua` | One shared secure button that clicks Blizzard's own calendar, clock, world map and queue buttons for KstyleUI's buttons |
| `Column.lua` | The button column: tracking, mail, calendar, group finder status and the drawer button, built from `Widgets.IconButton` with the glyph sheet; tracking, the calendar and the drawer button live in the hover group |
| `Drawer.lua` | The addon drawer: LibDBIcon buttons in a glass flyout, and the addon compartment's list |
| `Map.lua` | The live minimap: hosting Blizzard's `Minimap`, hiding the cluster, wheel and slider zoom, the hover that reveals the controls, events and the clock ticker |
| `Preview.lua` | The settings window's preview, with a drawn map instead of Blizzard's and the controls shown |
| `Module.lua` | `Modules.Register` and `Options.Register` |

## What it does on Forever

Forever loads `Blizzard_Minimap` with its `Camelot/` overrides: `MinimapCluster` holds the header (`ZoneTextButton`), `Tracking`, `IndicatorFrame` (mail), `MinimapContainer` with `Minimap` and Camelot's day and night orb (`DielFrame`), and the cluster also parents `GameTimeFrame` (calendar), `TimeManagerClockButton` (clock) and `AddonCompartmentFrame`. `Minimap` holds `ZoomIn`, `ZoomOut`, `ZoomHitArea` and `MinimapBackdrop`, whose `MinimapCompassTexture` is the round border.

When the module starts it:

1. Builds `KstyleUI_Minimap` on `KstyleUI_Root` and registers it as `minimap.main`.
2. Moves `Minimap` into the map square: `SetParent`, then one `CENTER` point and the square's size, so later resizes never touch Blizzard's frame beyond that. It waits for Edit Mode to close, and for combat to end if the frame is ever protected.
3. Sets the chamfered square mask (`Tokens.Texture("minimapMask")`, `Media/Textures/MinimapMask.png`) and sets the arch, quest and task blob ring scalars to 0, since a round ring would cut across a square map's corners. A hook on `MinimapCluster.UpdateMinimapConfig`, which Camelot runs when `rotateMinimap` changes (`Blizzard_Minimap/Camelot/Minimap.lua`, `MinimapClusterMixin:UpdateMinimapConfig` calls `minimap:SetMaskTexture(data.mask)` with Blizzard's round `ui-hud-minimap-frame-generic-mask`), puts KstyleUI's mask back.
4. Hides `MinimapCluster`, `MinimapBackdrop`, `Minimap.ZoomIn`, `Minimap.ZoomOut` and `Minimap.ZoomHitArea` through `KstyleUI.Safe.HideBlizzard`. Hiding the cluster hides the header, tracking, mail indicator, calendar, clock, compartment, day and night orb and Blizzard's coordinates with it.
5. Sets the global `GetMinimapShape` to return `"SQUARE"`, which minimap button libraries read to place buttons on the edge.
6. Gives `HybridMinimap.CircleMask` the same square mask when `Blizzard_HybridMinimap` loads.
7. Hooks `OnEnter` and `OnLeave` on `Minimap` (a `HookScript`, never `SetScript`) for the hover group.

Turning it off puts `Minimap` back in its container with its saved points, size, level, Blizzard's mask and blob rings at 1, brings the hidden frames back, withdraws `GetMinimapShape` and asks for a reload.

### The square and its rim

`Minimap:SetMaskTexture` takes a file (`MinimapFrameAPIDocumentation.lua`: one `TextureAsset` argument), which the game stretches over the frame, so the chamfered mask cuts the same share of the side at any size. `make_media.py` draws it from three numbers, a 221 frame with a 12 chamfer and a 2 inset; `Format.lua` names the same three (`MASK_FRAME`, `MASK_CHAMFER`, `MASK_INSET`), and `test_make_media.py` checks they match, so the rim's chamfer meets the mask's cut at every size. The rim is a `socket` chrome on the element with its fill cleared and hidden, no shadow, no grain and no gilt, in the kit's `edgeInner` line: the thin, quiet rim and nothing else. The map sits `Format.INSET` (2 units) inside it. The preview's drawn terrain uses the same mask (`face.mask`, a `MaskTexture` over the map square).

The 198-in-217 size defect the owner met live (the map rendering at its `SetSize` size, not its anchors) is why `Fit` sizes `Minimap` as well as anchoring it.

### Zoom

A frame with only the mouse wheel enabled covers the map square, so clicks and pings still reach `Minimap`, and the wheel works right up to the map's corners, outside Blizzard's round hit area. It steps `Minimap:SetZoom` one level within `GetZoomLevels()`. With **Zoom back out** on, the map returns to zoom 0 after the delay; a newer zoom restarts the wait.

The zoom slider is a thin line inside the map's left edge: a 2 by 52 track, 11 units in, on the map's centre line, with an accent fill that grows from the bottom as the map zooms in. A 12-unit-wide frame of KstyleUI's own takes the mouse: a click or a drag on it reads the cursor's height on the track and sets the nearest level with `Minimap:SetZoom`, through the same path as the wheel, so **Zoom back out** applies. The fill follows every zoom: KstyleUI's own calls refresh it, a `hooksecurefunc` on `Minimap.SetZoom` catches Blizzard's zoom buttons, the gamepad stick and the zoom-back-out timer, and `MINIMAP_UPDATE_ZOOM` (which Forever's `MinimapMixin` registers for the engine's own zoom changes) refreshes it as well, so the slider never guesses. It hides when the map is too small for it, and it lives in the hover group. `Minimap` is not a protected frame and `SetZoom` is an ordinary method (`MinimapFrameAPIDocumentation.lua` flags it only as `SecretArguments = "AllowedWhenUntainted"`), so the slider works in combat and never touches Blizzard's `ZoomIn`, `ZoomOut` or `ZoomHitArea`, which stay hidden.

### The bands

The zone name sits along the map's top edge and the clock along its bottom edge, inside the square, each on a 26-unit band (`Format.BAND`) whose only ink is a soft dark fade from the edge (the kit's bar sheen in the `shadow` colour, upside down at the bottom), so the texts read over any terrain without a plate or a line. The zone name is centred in capitals in the heading face, at size 11, and takes the band's width less a gap at each end, so a long name truncates inside the map instead of spilling past it. The clock is centred in the number face at size 11; with the coordinates on, the coordinates take the band's left end and the clock its right end. A band hides when it has nothing to show. Hovering the zone lists the zone, subzone and PvP status; hovering the clock shows local and realm time, in the kit's tooltip.

| Clock format | Text |
| --- | --- |
| Game clock settings | Local or realm time and 12 or 24 hours, from the `timeMgrUseLocalTime` and `timeMgrUseMilitaryTime` CVars that Blizzard's clock options set |
| Local time, 24-hour or 12-hour | `date("*t")` |
| Realm time, 24-hour or 12-hour | `GetGameTime()` |

The clock ticks once a second through `C_Timer.NewTicker`, only while the module runs and the clock shows. A client without `NewTicker` counts with `OnUpdate` on the clock band and logs it. The clock shows in one place: the data strip's time slot is a DataBars choice that no default slot uses.

### Coordinates

Coordinates come from `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition`. They update on zone changes, and every 0.2 s only while the player moves (`PLAYER_STARTED_MOVING` to `PLAYER_STOPPED_MOVING`, and `PLAYER_CONTROL_LOST` to `PLAYER_CONTROL_GAINED` for flight paths). No position, as in instances, or a secret one hides them. There is no north mark: a square map that does not rotate is north-up, so the letter carried no information, and a rotating map has Blizzard's own pointer.

### Hidden until hover

The zoom slider and the tracking, calendar and drawer buttons sit in one frame over the map square, `face.reveal`, hidden at rest. `OnEnter` on `Minimap`, on the zone and clock hit areas and on every column button shows it (`Face:SetRevealed`, a kit fade). `OnLeave` on any of them, and on the secure overlay that takes a button's hover, starts a watch on the overlay's `OnUpdate` that stops as soon as the pointer is over the element again (`IsMouseOver`, which Forever's `SimpleScriptRegionAPIDocumentation.lua` documents) or over the open drawer, and otherwise fades the group out after 0.3 s. While the tracking menu or the compartment list is open (`Map.SetMenu` keeps the menu `MenuUtil.CreateContextMenu` returned, checked with `Menu.GetManager():IsMenuOpen`), the watch keeps the group shown, because `Blizzard_Menu` closes a menu whose owner is not visible; the group goes once the menu closes. The drawer's `Close` runs the same check, so the buttons go when the drawer closes with the pointer elsewhere. While a click-opened drawer stays open, its button stays with it. The mail and queue indicators carry information, so they stay on the always-shown host whenever they apply. The settings preview shows the group.

### The buttons

The buttons are small crystal discs (a dark disc with a light ring and a glyph), 18 units by default, in a column inside the map's right or left edge (`Format.EDGE`, 6 units in), from under the zone band down or from over the clock band up (`Format.Column`), one button and one gap apart. A column holds as many buttons as fit between the bands (`Format.PerColumn`; four on the default map), and the rest wrap into the next column inward, so no button reaches the clock band or leaves the map at any size. Only the buttons that apply show, and the rest close up.

| Button | Shows | Click |
| --- | --- | --- |
| Tracking | On hover, while `C_Minimap` tracking exists and the `IngameTrackingDisabled` game rule is off | A KstyleUI menu through `MenuUtil.CreateContextMenu`: a checkbox for each optional filter and tracking spell, as Blizzard's own menu lists them (`MinimapConstants.OPTIONAL_FILTERS`, or every type with the `minimapTrackingShowAll` CVar), and **Uncheck all**, which keeps the always-on and conditional filters on. Each checkbox calls `C_Minimap.SetTracking`. |
| Mail | Always, while `HasNewMail()` is true (`UPDATE_PENDING_MAIL`) | None. The tooltip lists `GetLatestThreeSenders()`. |
| Calendar | On hover, unless the `IngameCalendarDisabled` game rule is on. A badge and the accent tint mark pending invites (`CALENDAR_UPDATE_PENDING_INVITES`). | Left: `GameTimeFrame`, the calendar. Right: `TimeManagerClockButton`, the clock options. |
| Group finder | Always, while `QueueStatusButton` is shown, checked on Blizzard's `QueueStatusUpdate.QueuesUpdated` callback. While this button is on, Blizzard's eye stays shown but faded to alpha 0 with its mouse off; a `SetAlpha` hook keeps it faded. | Both buttons: `QueueStatusButton`, so its own menu and windows open. |
| Addon drawer | On hover, unless **Hide when empty** is on and no addon has a button | The drawer, below. |

The zone name and the clock on the bands work the same way: the zone clicks `MinimapCluster.ZoneTextButton` (the world map), and the clock clicks `TimeManagerClockButton`, or `GameTimeFrame` on a right click.

### The addon drawer

The last button in the column opens a glass flyout of other addons' minimap buttons.

- **Collecting.** It reads `LibDBIcon-1.0` through `LibStub` when the module starts, on `PLAYER_ENTERING_WORLD`, the frame after each `ADDON_LOADED`, and on the library's `LibDBIcon_IconCreated` callback, which it subscribes to the first time it finds the library. KstyleUI never loads or embeds the library. Each button moves into the drawer: its drag is turned off (`RegisterForDrag()`), its fixed strata released so the drawer cannot cover it, its ring and background stripped through `KstyleUI.Skin.Strip`, and a chamfered tile put behind it with `Skin.Backdrop`. Buttons sort by name.
- **Staying put.** A `hooksecurefunc` on each button's `SetPoint` puts it back in its slot when the library re-anchors it to `Minimap`. Hooks on its `SetAlpha` and its `fadeOut:Play` keep a show-on-mouseover button opaque while it is in the drawer. Hooks on `Show` and `Hide` re-lay the grid when an addon hides or shows its button, and a button the addon hid takes no place.
- **Opening.** A click toggles it, mouseover opens it and closes it half a second after the pointer leaves both the drawer and its button, or it stays open. It opens away from the screen's edge unless a direction is chosen, over the map like a menu, and fills a grid of icons, a set number per row. Clicking an addon button closes the drawer unless **Close after a click** is off.
- **The addon compartment.** Blizzard's compartment is part of the hidden cluster, so a right click on the drawer button, or a left click while the drawer is empty, lists `AddonCompartmentFrame.registeredAddons` in a KstyleUI menu, sorted by name. Each entry takes any mouse button, as Blizzard's does, and runs the addon's own function. KstyleUI reads Blizzard's list and never sorts or changes it.
- **Handing back.** Turning the drawer button or the module off clears each button's anchors, puts it back on its first parent, lets it drag again and calls the library's `Refresh(name)`, which places it on the map's edge (`GetMinimapShape` returns `"SQUARE"` while the module runs).

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
| `accent.source`, `accent.color` | `class`, the kit's accent | The zoom fill's and active buttons' colour: class or custom colour |
| `column.side`, `column.growth` | `right`, `down` | The buttons inside the map's right or left edge, and whether they start at the top or the bottom |
| `column.size`, `column.spacing` | 18, 4 | Button size and the gap between buttons |
| `column.tracking`, `column.mail`, `column.calendar`, `column.queue`, `column.drawer` | on | Each button |
| `drawer.behaviour`, `drawer.direction` | `click`, `auto` | Open on click, on mouseover or always; which way it opens |
| `drawer.size`, `drawer.spacing`, `drawer.columns` | 24, 4, 6 | The drawer's icon size, gap and icons per row |
| `drawer.autoClose`, `drawer.compartment`, `drawer.hideEmpty` | on | Close after a click, the compartment list, and hiding the button while there is nothing to show |
| `zoom.wheel`, `zoom.slider`, `zoom.reset`, `zoom.delay` | on, on, off, 10 s | Wheel zoom, the zoom slider and zooming back out |
| `zone.shown`, `zone.color` | on, `plain` | Zone name, coloured plainly, by PvP status or with the accent |
| `clock.shown`, `clock.mode` | on, `game` | The clock and its format |
| `coords.shown`, `coords.precision` | off, 1 | Coordinates, 0 to 2 decimals, at the left of the clock band |
| `zone.*`, `clock.*`, `coords.*` `font`, `size`, `outline` | interface font; 11, 11, 10; none | Each text's typeface, size (times the Appearance text size) and outline |

Saved data from the lens card migrates in `Core/Store.lua` (migration 6): the `compass` and `coords.position` settings go, and a saved size for `minimap.main` (the lens card's footprint) goes so the square builds at its default size; its position and any tuned button size stay.

## Why

- **Hosting `Minimap` instead of replacing it.** The spec has Layout Mode replace a Blizzard frame that needs a new place with a KstyleUI frame. The minimap renderer cannot be replaced: an addon cannot make a second `Minimap`. So the module hosts the one Blizzard gives it, which is not protected, and moves only that frame. The calls are listed with this reason in `Tools/regression/taint_allow/KstyleUI_Minimap.lua`. Everything else in the cluster is hidden through `Safe`, never moved.
- **One `CENTER` point and a size.** `Minimap` renders at its `SetSize` size, not at its anchors (seen live: a 198 map inside a 217 square), so `Fit` centres it on the map square and sizes it to the square on every resize, and nothing else about Blizzard's frame changes.
- **Hiding the whole cluster.** Forever's 1.60.1 reskinned the minimap header and moved its children, and Camelot and Edit Mode both re-anchor them (`SetHeaderUnderneath`). Hiding the cluster as one frame survives those changes; KstyleUI draws its own zone, clock and buttons instead of restyling Blizzard's.
- **A small square (owner pass 1, 2026-11-09).** The owner found the 318 by 346 lens card "way too big" and its artwork "too much", and prefers a square map as Leatrix Plus draws one. The square is built from Blizzard's API (`SetMaskTexture`, the blob ring scalars, `GetMinimapShape`), never from that addon's code. A square shows more of the world than a circle of the same width, so it can be smaller for the same view.
- **A wheel-only catcher.** Blizzard's `Minimap` takes the wheel only inside its round hit area. A frame with just `EnableMouseWheel` covers the whole square without stealing clicks, motion or pings.
- **The queue eye is faded, not hidden.** Forever anchors `QueueStatusButton` to `Minimap` by default (`GROUP_FINDER_RELATIVE_TO` in `Blizzard_EditMode/Camelot`), so it would sit on KstyleUI's map. Hiding it through `Safe` would break its right-click menu: `Blizzard_Menu` closes a menu whose owner is not visible. So the eye stays shown at alpha 0 with its mouse off, and the column's button clicks it through the secure overlay.
- **The drawer is part of the minimap element.** It is a flyout hung on its own button, like a menu, so it moves with the minimap and has no Layout key of its own; its icon size, spacing, columns and direction are its settings.
- **Third-party buttons are moved, Blizzard's are not.** The drawer reparents LibDBIcon buttons, which other addons own, and lists in the allow-list that `button:SetParent` touches only them.
- **A KstyleUI tracking menu.** Blizzard's menu sets settings-backed filters through `MinimapUtil` and the Settings system. Calling that from addon code would taint the Settings system, so KstyleUI's menu calls `C_Minimap.SetTracking` directly. The Options panel's trivial-quest checkbox may lag until its next refresh.
- **A secure overlay instead of calling Blizzard.** `ToggleCalendar`, `ToggleWorldMap` and the queue eye's handler load or show Blizzard windows. Called from addon code they run tainted; clicked through a secure button they run as Blizzard's own. The overlay is one module file, not a kit component, because it is input plumbing with no look of its own.
- **Controls on hover, indicators always.** Tracking, the calendar, the drawer and the zoom slider are things the player does, so they wait until the pointer is on the map and leave the map clear at rest. New mail and a queue are things the game tells the player, so they show whenever they apply.
- **Coordinates update only while moving.** The spec allows `OnUpdate` only while something moves. Movement events start and stop it, so a player standing still costs nothing.
