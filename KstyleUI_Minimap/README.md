# KstyleUI_Minimap

The square minimap as the overhaul's mock-up draws it (KSTY-44, `renders/KSTY-44/detail-B-minimap-quests-guide.jpg` in the Captain's drive): Blizzard's map as a plain 188-unit square seated in a forged card with gilt brackets on its corners, a small gilt N diamond on its top edge, the zone name in capitals above the card, the coordinates and the clock under it, a zoom slider and the tracking, calendar and addon-drawer buttons that show on hover (a setting brings the buttons back at rest), and the mail and queue indicators that show whenever they apply.

**The overhaul wins over the picture (KSTY-50).** Lee approved the KSTY-44 mock-ups on 2026-11-12, and the Captain's COMMON.md makes them binding. They move the zone above the map, put the map in a card with brackets, draw no buttons at rest and place no forged ornament pieces on the map: the design bible allows ornament only on card corners. The defaults changed with them and the settings stayed, and Store migration 22 moves a profile that kept the old defaults.

**Before the overhaul, the picture won over #207.** On 2026-11-09 the owner ruled "let the picture win its what i want" (LEE-20), and his picture contradicts #207 in five places: the map is 188 units, not 160; its corners are square, not chamfered; the N mark is back; the zone, clock and coordinates sit under the map, not on fades inside it; coordinates are on; and the three buttons show at rest. Where the picture reversed a default that has a setting (coordinates, the buttons' hover-only look), the default changed and the setting stayed. The overhaul has since moved the zone above the card, the clock and coordinates under it, and the buttons back to hover; the measures below are the overhaul's.

| Field | Value |
| --- | --- |
| Module name | `Minimap`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Minimap.toc` lists `Minimap.xml`, which loads every Lua file in order, so adding a file never edits the TOC |
| Layout element | `minimap.main`: resizable from 100 to 320 units, square, 188 by 188 at the 1080 reference, with a reserve of 188 by 202 for the 14-unit coordinate row under the map. The layout leaves a 22-unit heading above it for the zone, so the map stands 38 units under the screen's top (`Core/Setup/Layouts.lua`). The map is the element itself, with no inset; its card is 3 units wider on every side |
| Tests | `Tools/regression/test-minimap.lua` (the module against stand-ins for Forever's minimap frames, built by `Tools/regression/minimap_env.lua`), `test-minimap-column.lua` (the button column and the secure overlay), `test-minimap-drawer.lua` (the addon drawer against a LibDBIcon stand-in), `test-minimap-drawer-addons.lua` (the drawer with the buttons Blackthornes and 0xgle Bugs draw themselves), `test-minimap-format.lua` (the pure helpers and the picture's measures) and `Tools/tests/test_make_media.py` (the glyph sheet, and the plain square mask) |
| Media | `Media/Glyphs.png`, drawn by `Tools/media/make_minimap_glyphs.py`; its row is in `Media/PROVENANCE.md`. The mask is the kit's `MinimapMask.png`, a plain opaque square drawn by `Tools/media/make_media.py` (its row is in `Media/PROVENANCE.md` too) |

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
| `Format.lua` | Pure helpers: coordinate and clock text, zone colour tokens, wheel zoom steps, the zoom slider's share and level, the picture's measures (the N plate's size, the caption's depth and its texts' places under the map, the first button's top and edge distance), the button column's slots (`Format.Column`), and the drawer's direction, grid and size |
| `Settings.lua` | Defaults, the settings page rows and `Settings.Get(key)`, which gives the default for a saved value the row does not allow |
| `Style.lua` | The accent (class or custom colour) and each text's font, size and outline |
| `Data.lua` | Reads from the game: zone and PvP type, local and realm time, coordinates, game rules, mail, calendar invites, the queue and tracking. Each read checks the API exists and that the value is not secret. |
| `Face.lua` | The visible face, shared by the live map and the preview: the gilt rim, the map square and its mask, the N plate, the caption (zone, coordinates and clock under the map), the hover group (`face.reveal`) and the zoom slider in it |
| `SecureClick.lua` | One shared secure button that clicks Blizzard's own calendar, clock, world map and queue buttons for KstyleUI's buttons |
| `Column.lua` | The button column: tracking, mail, calendar, group finder status and the drawer button, built from `Widgets.IconButton` with the glyph sheet; all shown at rest, and with **Buttons only on hover** on, tracking, the calendar and the drawer button live in the hover group |
| `Drawer.lua` | The addon drawer: LibDBIcon buttons in a glass flyout, and the addon compartment's list |
| `Map.lua` | The live minimap: hosting Blizzard's `Minimap`, hiding the cluster, wheel and slider zoom, the hover that reveals the controls, events and the clock ticker |
| `Preview.lua` | The settings window's preview, with a drawn map instead of Blizzard's and the controls shown |
| `Module.lua` | `Modules.Register` and `Options.Register` |

## What it does on Forever

Forever loads `Blizzard_Minimap` with its `Camelot/` overrides: `MinimapCluster` holds the header (`ZoneTextButton`), `Tracking`, `IndicatorFrame` (mail), `MinimapContainer` with `Minimap` and Camelot's day and night orb (`DielFrame`), and the cluster also parents `GameTimeFrame` (calendar), `TimeManagerClockButton` (clock) and `AddonCompartmentFrame`. `Minimap` holds `ZoomIn`, `ZoomOut`, `ZoomHitArea` and `MinimapBackdrop`, whose `MinimapCompassTexture` is the round border.

When the module starts it:

1. Builds `KstyleUI_Minimap` on `KstyleUI_Root` and registers it as `minimap.main`.
2. Moves `Minimap` into the map square: `SetParent`, then one `CENTER` point and the square's size, so later resizes never touch Blizzard's frame beyond that. It waits for Edit Mode to close, and for combat to end if the frame is ever protected.
3. Sets the plain square mask (`Tokens.Texture("minimapMask")`, `Media/Textures/MinimapMask.png`) and sets the arch, quest and task blob ring scalars to 0, since a round ring would cut across a square map's corners. A hook on `MinimapCluster.UpdateMinimapConfig`, which Camelot runs when `rotateMinimap` changes (`Blizzard_Minimap/Camelot/Minimap.lua`, `MinimapClusterMixin:UpdateMinimapConfig` calls `minimap:SetMaskTexture(data.mask)` with Blizzard's round `ui-hud-minimap-frame-generic-mask`), puts KstyleUI's mask back.
4. Hides `MinimapCluster`, `MinimapBackdrop`, `Minimap.ZoomIn`, `Minimap.ZoomOut` and `Minimap.ZoomHitArea` through `KstyleUI.Safe.HideBlizzard`. Hiding the cluster hides the header, tracking, mail indicator, calendar, clock, compartment, day and night orb and Blizzard's coordinates with it.
5. Sets the global `GetMinimapShape` to return `"SQUARE"`, which minimap button libraries read to place buttons on the edge. LibDBIcon read the shape when it made each button, which may be before the module ran, so the module then asks the library to place every button the drawer does not hold again (`Drawer:Reposition`, which calls `Refresh(name)`); turning the module off does the same once the shape is withdrawn.
6. Gives `HybridMinimap.CircleMask` the same square mask when `Blizzard_HybridMinimap` loads.
7. Hooks `OnEnter` and `OnLeave` on `Minimap` (a `HookScript`, never `SetScript`) for the hover group.

Turning it off puts `Minimap` back in its container with its saved points, size, level, Blizzard's mask and blob rings at 1, brings the hidden frames back, withdraws `GetMinimapShape` and asks for a reload.

### The card

`Minimap:SetMaskTexture` takes a file (`MinimapFrameAPIDocumentation.lua`: one `TextureAsset` argument), which the game stretches over the frame. The map has square corners, so the mask is a plain square: `make_media.py` draws `MinimapMask.png` as 64 texels of opaque white. The map is the element, with no inset.

The card (`face.card`) lies under the map, 3 units wider on every side (`Format.FRAME`), as the mock-up's 3-pixel inset: a forged iron fill (the `materialForged` token) and the kit's forged frame nine-slice (`forgedFrame1` to `forgedFrame3`, picked by how many physical pixels a border is, as the card material picks it). Its corners are the mock-up's gilt brackets: on each corner an arm across and an arm down, 8 units long and two physical pixels thick, in the kit's `gilt`, drawn on the face's overlay so they read whole over the map's corners. The kit's forged bracket pieces, which the quest card wears, are 8 physical pixels of dark bronze and vanished on the map at every size, so the minimap draws the mock-up's brighter bracket. The map's own edge is a dark pixel line (`black` at 0.85) with a soft dark fall-off 14 units deep inside it (`SetGradient`), the mock-up's inset shadow. The card draws forged whatever card material the player picks.

The card is drawn from the kit's own pieces rather than `Widgets.Chrome`, so the render guard does not count the zone above it and the row under it as content spilling out of a card: they stand on the world by design.

The 198-in-217 size defect the owner met live (the map rendering at its `SetSize` size, not its anchors) is why `Fit` sizes `Minimap` as well as anchoring it.

### The N diamond

A diamond 12 units across (`Format.NORTH`) centred on the middle of the map's top edge: black, gilt and forged iron copies of the kit's `diamond` texture nested from the outside in, with a lit gilt `L["N"]` in the number face at size 7. It is decoration, not a compass: the map does not rotate, so it always means north-up, and a rotating map has Blizzard's own pointer. It takes no mouse.

### Zoom

A frame with only the mouse wheel enabled covers the map square, so clicks and pings still reach `Minimap`, and the wheel works right up to the map's corners, outside Blizzard's round hit area. It steps `Minimap:SetZoom` one level within `GetZoomLevels()`. With **Zoom back out** on, the map returns to zoom 0 after the delay; a newer zoom restarts the wait.

The zoom slider is a thin line inside the map's left edge: a 2 by 52 track, 11 units in, on the map's centre line, with an accent fill that grows from the bottom as the map zooms in. A 12-unit-wide frame of KstyleUI's own takes the mouse: a click or a drag on it reads the cursor's height on the track and sets the nearest level with `Minimap:SetZoom`, through the same path as the wheel, so **Zoom back out** applies. The fill follows every zoom: KstyleUI's own calls refresh it, a `hooksecurefunc` on `Minimap.SetZoom` catches Blizzard's zoom buttons, the gamepad stick and the zoom-back-out timer, and `MINIMAP_UPDATE_ZOOM` (which Forever's `MinimapMixin` registers for the engine's own zoom changes) refreshes it as well, so the slider never guesses. It hides when the map is too small for it, and it lives in the hover group. `Minimap` is not a protected frame and `SetZoom` is an ordinary method (`MinimapFrameAPIDocumentation.lua` flags it only as `SecretArguments = "AllowedWhenUntainted"`), so the slider works in combat and never touches Blizzard's `ZoomIn`, `ZoomOut` or `ZoomHitArea`, which stay hidden.

### The zone, the coordinates and the clock

Nothing draws inside the map. The zone name stands above the card and the coordinates and the clock under it, all on the world, so they take the world layer's treatment: a one-pixel outline and the kit's soft shadow (the **Outline with a soft shadow** choice, `world`, the default for all three). Measured from the card's edges, in units:

| Text | Anchor | Face | Size | Colour |
| --- | --- | --- | --- | --- |
| Zone name in capitals | the card's left edge, centred 12 above its top (`Format.ZONE_CENTER`), as wide as the card so a long name truncates | the kit's `caps` role (Folio Caps, tracked by its font file) | 12 | `giltLit`, as the mock-up draws it; the PvP and accent choices stay |
| Coordinates | the card's left edge, centred 9 under its bottom (`Format.ROW_CENTER`) | number | 11.5 | the `text` token |
| Clock | the card's right edge, on the coordinates' line; a 12-hour clock's AM or PM stands after it at 0.8 of its size (`Format.MERIDIEM`), on its baseline | time | 12.5 | `textEmphasis`, white |

The zone's heading is 22 units (`Format.HEADING`) and the row under the card 14 (`Format.CAPTION`), the 36 the old caption took, so the story cards under the map keep their place. The zone keeps clear of the N diamond. Hovering the zone lists the zone, subzone and PvP status, and clicking it opens the world map; hovering the clock shows local and realm time, and clicking it opens the clock options, through the same secure overlay as before (`face.zoneHit`, `face.clockHit`).

| Clock format | Text |
| --- | --- |
| Game clock settings | Local or realm time and 12 or 24 hours, from the `timeMgrUseLocalTime` and `timeMgrUseMilitaryTime` CVars that Blizzard's clock options set |
| Local time, 24-hour or 12-hour | `date("*t")` |
| Realm time, 24-hour or 12-hour | `GetGameTime()` |

The clock ticks once a second through `C_Timer.NewTicker`, only while the module runs and the clock shows. A client without `NewTicker` counts with `OnUpdate` on the caption frame and logs it. The clock shows in one place: the data strip's time slot is a DataBars choice that no default slot uses.

### Coordinates

Coordinates come from `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition`. They are on by default, at one decimal, and update on zone changes, and on a 0.2 s `C_Timer.NewTicker` (`UITimerDocumentation.lua`) only while the player moves out of combat (`PLAYER_STARTED_MOVING` to `PLAYER_STOPPED_MOVING`, and `PLAYER_CONTROL_LOST` to `PLAYER_CONTROL_GAINED` for flight paths). Combat pauses the ticker (`PLAYER_REGEN_DISABLED`) and the coordinates keep their last value; leaving combat (`PLAYER_REGEN_ENABLED`) reads them at once and starts the ticker again if the player is still moving. No per-frame script runs: a client without `NewTicker` counts with `OnUpdate` and logs it. No position, as in instances, or a secret one hides them.

### Hidden until hover

The zoom slider sits in one frame over the map square, `face.reveal`, hidden at rest; with **Buttons only on hover** on (the default since the overhaul), so do the tracking, calendar and drawer buttons (they are reparented into it, and back to the always-shown host when the setting goes off again). `OnEnter` on `Minimap`, on the zone and clock hit areas and on every column button shows the group (`Face:SetRevealed`, a kit fade). `OnLeave` on any of them, and on the secure overlay that takes a button's hover, starts a watch on the overlay's `OnUpdate` that stops as soon as the pointer is over the element again (`IsMouseOver`, which Forever's `SimpleScriptRegionAPIDocumentation.lua` documents) or over the open drawer, and otherwise fades the group out after 0.3 s. While the tracking menu or the compartment list is open (`Map.SetMenu` keeps the menu `MenuUtil.CreateContextMenu` returned, checked with `Menu.GetManager():IsMenuOpen`), the watch keeps the group shown, because `Blizzard_Menu` closes a menu whose owner is not visible; the group goes once the menu closes. The drawer's `Close` runs the same check. While a click-opened drawer stays open, its button stays with it. The mail and queue indicators carry information, so they stay on the always-shown host whenever they apply. The settings preview shows the group.

### The buttons

The buttons are crystal discs (a dark disc with a light ring and a glyph), 19.5 units across by default, in a column inside the map's right or left edge. On the right, a disc's centre is 17.5 units in from the map's edge (`Format.EDGE`, 7.75 to the disc's edge) and the first disc's top is 7 units under the map's top edge (`Format.TOP`); the pitch is 25 (19.5 and a 5.5 gap, snapped as one pitch so the gaps never grow by rounding). The column starts at the top and goes down, or starts at the bottom and goes up (`Format.Column`). A column holds as many buttons as fit between the top and bottom margins (`Format.PerColumn`; seven on the default map), and the rest wrap into the next column inward, so no button leaves the map at any size. Only the buttons that apply show, and the rest close up. Tracking, the calendar and the drawer show on hover by default, as the overhaul's mock-up draws no buttons at rest; turning **Buttons only on hover** (`column.hover`) off shows them at rest.

| Button | Shows | Click |
| --- | --- | --- |
| Tracking | At rest (on hover with **Buttons only on hover**), while `C_Minimap` tracking exists and the `IngameTrackingDisabled` game rule is off | A KstyleUI menu through `MenuUtil.CreateContextMenu`: a checkbox for each optional filter and tracking spell, as Blizzard's own menu lists them (`MinimapConstants.OPTIONAL_FILTERS`, or every type with the `minimapTrackingShowAll` CVar), and **Uncheck all**, which keeps the always-on and conditional filters on. Each checkbox calls `C_Minimap.SetTracking`. |
| Mail | Always, while `HasNewMail()` is true (`UPDATE_PENDING_MAIL`) | None. The tooltip lists `GetLatestThreeSenders()`. |
| Calendar | At rest (on hover with **Buttons only on hover**), unless the `IngameCalendarDisabled` game rule is on. A badge and the accent tint mark pending invites (`CALENDAR_UPDATE_PENDING_INVITES`). | Left: `GameTimeFrame`, the calendar. Right: `TimeManagerClockButton`, the clock options. |
| Group finder | Always, while `QueueStatusButton` is shown, checked on Blizzard's `QueueStatusUpdate.QueuesUpdated` callback. While this button is on, Blizzard's eye stays shown but faded to alpha 0 with its mouse off; a `SetAlpha` hook keeps it faded. | Both buttons: `QueueStatusButton`, so its own menu and windows open. |
| Addon drawer | At rest (on hover with **Buttons only on hover**), unless **Hide when empty** is on and no addon has a button | The drawer, below. |

The zone name and the clock in the caption work the same way: the zone clicks `MinimapCluster.ZoneTextButton` (the world map), and the clock clicks `TimeManagerClockButton`, or `GameTimeFrame` on a right click.

### The addon drawer

The last button in the column opens a glass flyout of other addons' minimap buttons.

- **Collecting.** It reads `LibDBIcon-1.0` through `LibStub` when the module starts, on `PLAYER_ENTERING_WORLD`, the frame after each `ADDON_LOADED`, and on the library's `LibDBIcon_IconCreated` callback, which it subscribes to the first time it finds the library. KstyleUI never loads or embeds the library. Each button moves into the drawer: its drag is turned off (`RegisterForDrag()`), its fixed strata released so the drawer cannot cover it, its ring and background stripped through `KstyleUI.Skin.Strip`, and a chamfered tile put behind it with `Skin.Backdrop`. Buttons sort by name.
- **Addons that draw their own button.** Blackthornes and 0xgle Bugs draw their minimap buttons themselves rather than through LibDBIcon, and place them on a circle: each Blackthornes addon at `cos(angle) * (w / 2 + 5)` from the map's centre (`UI/Minimap.lua`, and `UI/SharedMinimap.lua` for the shared button it draws when the buttons are combined), 0xgle Bugs at its saved offset, 52 by -52 by default (`0xgleBugs/Launcher.lua`). On the square map they sit inside its corners, and pushed out to the square's edge they would cover the zone heading, the N diamond and the row under the card. So the drawer collects them by name (`BlackthornesMinimapButton`, `BlackthornesButlerMinimapButton`, `BlackthornesEquipmentMinimapButton`, `BlackthornesFarmerMinimapButton`, `BlackthornesPathfinderMinimapButton`, `BlackthornesPetsMinimapButton`, `BlackthornesTSMinimapButton`, `OxgleBugsMinimapButton`) whenever it looks for LibDBIcon buttons, and once more the frame after `PLAYER_ENTERING_WORLD`, because Blackthornes makes its shared button from `C_Timer.After(0, ...)`. It takes only a button that still sits on `Minimap`. Each keeps its `ARTWORK` texture as the icon and is treated as a LibDBIcon button from then on; the anchor its addon last asked for and its size are kept for handing back. With the drawer button off they stay where their addons put them. Ported from Baine's #344, which pushed them to the square's edge instead.
- **Staying put.** A `hooksecurefunc` on each button's `SetPoint` puts it back in its slot when the library re-anchors it to `Minimap`. Hooks on its `SetAlpha` and its `fadeOut:Play` keep a show-on-mouseover button opaque while it is in the drawer. Hooks on `Show` and `Hide` re-lay the grid when an addon hides or shows its button, and a button the addon hid takes no place.
- **Opening.** A click toggles it, mouseover opens it and closes it half a second after the pointer leaves both the drawer and its button, or it stays open. It opens away from the screen's edge unless a direction is chosen, over the map like a menu, and fills a grid of icons, a set number per row. Clicking an addon button closes the drawer unless **Close after a click** is off.
- **The addon compartment.** Blizzard's compartment is part of the hidden cluster, so a right click on the drawer button, or a left click while the drawer is empty, lists `AddonCompartmentFrame.registeredAddons` in a KstyleUI menu, sorted by name. Each entry takes any mouse button, as Blizzard's does, and runs the addon's own function. KstyleUI reads Blizzard's list and never sorts or changes it.
- **Handing back.** Turning the drawer button or the module off clears each button's anchors, puts it back on its first parent, lets it drag again and calls the library's `Refresh(name)`, which places it on the map's edge (`GetMinimapShape` returns `"SQUARE"` while the module runs). A button whose addon draws it itself gets back its own size, the anchor its addon last asked for, and its icon's anchors and size. The textures the drawer stripped stay hidden until a reload, as a LibDBIcon button's ring does, because `Skin.Strip` cannot be undone.

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
| `column.hover` | on | Show the tracking, calendar and drawer buttons only while the pointer is over the map; the overhaul's mock-up shows none at rest |
| `column.size`, `column.spacing` | 19.5, 5.5 | Button size and the gap between buttons (a pitch of 25) |
| `column.tracking`, `column.mail`, `column.calendar`, `column.queue`, `column.drawer` | on | Each button |
| `drawer.behaviour`, `drawer.direction` | `click`, `auto` | Open on click, on mouseover or always; which way it opens |
| `drawer.size`, `drawer.spacing`, `drawer.columns` | 24, 4, 6 | The drawer's icon size, gap and icons per row |
| `drawer.autoClose`, `drawer.compartment` | on | Close after a click, and the compartment list |
| `drawer.hideEmpty` | off | Hide the drawer button while there is nothing to show; the picture shows the button at rest, so it stays when the drawer is empty |
| `zoom.wheel`, `zoom.slider`, `zoom.reset`, `zoom.delay` | on, on, off, 10 s | Wheel zoom, the zoom slider and zooming back out |
| `zone.shown`, `zone.color` | on, `plain` | Zone name above the card's left edge, in lit gilt, by PvP status or with the accent |
| `clock.shown`, `clock.mode` | on, `game` | The clock under the card's right edge and its format |
| `coords.shown`, `coords.precision` | on, 1 | Coordinates, 0 to 2 decimals, under the card's left edge |
| `zone.*`, `clock.*`, `coords.*` `font`, `size`, `outline` | role font; 12, 12.5, 11.5; `world` | Each text's typeface, size (times the Appearance text size) and outline: outline with a soft shadow, none with a soft shadow, thin or thick |

Store migration 22 moves a map saved at the old default (16 units from the top) under the zone heading, turns a saved `column.hover` off into on, and turns a text outline saved as none into the world layer's outline; any other saved choice stays. Saved data from the lens card migrates in `Core/Store.lua` (migration 6): the `compass` and `coords.position` settings go, and a saved size for `minimap.main` (the lens card's footprint) goes so the square builds at its default size; its position and any tuned button size stay.

## Why

- **Hosting `Minimap` instead of replacing it.** The spec has Layout Mode replace a Blizzard frame that needs a new place with a KstyleUI frame. The minimap renderer cannot be replaced: an addon cannot make a second `Minimap`. So the module hosts the one Blizzard gives it, which is not protected, and moves only that frame. The calls are listed with this reason in `Tools/regression/taint_allow/KstyleUI_Minimap.lua`. Everything else in the cluster is hidden through `Safe`, never moved.
- **One `CENTER` point and a size.** `Minimap` renders at its `SetSize` size, not at its anchors (seen live: a 198 map inside a 217 square), so `Fit` centres it on the map square and sizes it to the square on every resize, and nothing else about Blizzard's frame changes.
- **Hiding the whole cluster.** Forever's 1.60.1 reskinned the minimap header and moved its children, and Camelot and Edit Mode both re-anchor them (`SetHeaderUnderneath`). Hiding the cluster as one frame survives those changes; KstyleUI draws its own zone, clock and buttons instead of restyling Blizzard's.
- **A square (owner pass 1, 2026-11-09).** The owner found the 318 by 346 lens card "way too big" and its artwork "too much", and prefers a square map as Leatrix Plus draws one. The square is built from Blizzard's API (`SetMaskTexture`, the blob ring scalars, `GetMinimapShape`), never from that addon's code.
- **The picture wins (LEE-20, 2026-11-09).** #207 made the map 160 units with a chamfered rim, took the N mark away, put the zone and clock on dark fades inside the map, left coordinates off and showed the buttons only on hover. The owner's picture draws 188 units, square corners, the N plate, a caption under the map, coordinates and three buttons at rest, and his ruling was "let the picture win its what i want". The module built the picture until the overhaul; the hover-only look, which the overhaul makes the default again, stayed a setting throughout (`column.hover`).
- **A wheel-only catcher.** Blizzard's `Minimap` takes the wheel only inside its round hit area. A frame with just `EnableMouseWheel` covers the whole square without stealing clicks, motion or pings.
- **The queue eye is faded, not hidden.** Forever anchors `QueueStatusButton` to `Minimap` by default (`GROUP_FINDER_RELATIVE_TO` in `Blizzard_EditMode/Camelot`), so it would sit on KstyleUI's map. Hiding it through `Safe` would break its right-click menu: `Blizzard_Menu` closes a menu whose owner is not visible. So the eye stays shown at alpha 0 with its mouse off, and the column's button clicks it through the secure overlay.
- **The drawer is part of the minimap element.** It is a flyout hung on its own button, like a menu, so it moves with the minimap and has no Layout key of its own; its icon size, spacing, columns and direction are its settings.
- **Third-party buttons are moved, Blizzard's are not.** The drawer reparents LibDBIcon buttons, which other addons own, and lists in the allow-list that `button:SetParent` touches only them.
- **A KstyleUI tracking menu.** KstyleUI calls `C_Minimap.SetTracking` directly, not `MinimapUtil`, so addon code does not enter Blizzard's Settings callbacks. Forever's trivial-quest Options proxy reads `C_Minimap.IsFilteredOut` live (`Blizzard_SettingsDefinitions_Frame/Camelot/InterfaceOverrides.lua`); an already-open checkbox can wait for its next refresh. Verify tracking and taint behavior in game.
- **A secure overlay instead of calling Blizzard.** `ToggleCalendar`, `ToggleWorldMap` and the queue eye's handler load or show Blizzard windows. Called from addon code they run tainted; clicked through a secure button they run as Blizzard's own. The overlay is one module file, not a kit component, because it is input plumbing with no look of its own.
- **Buttons and the slider on hover.** The overhaul's mock-up shows no buttons on the map, so the tracking, calendar and drawer buttons and the zoom slider show on hover. New mail and a queue are things the game tells the player, so they show whenever they apply.
- **No ornament pieces.** The design bible (KSTY-44, section 3.3) allows ornament only on card corners, so the map's forged corner pieces and the plaque behind the N, which #287 added, are gone; the card's brackets are its corners.
- **Coordinates on a ticker, only while moving, never in combat.** The overhaul's smoothness rule allows no per-frame script for visuals. Movement events start and stop a 0.2 s ticker, so a player standing still costs nothing, and combat pauses it; the only minimap timer left in a fight is the clock's once-a-second tick.
