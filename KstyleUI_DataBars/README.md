# KstyleUI_DataBars

XP, reputation and honour bars, micro menu, bag bar, and a data strip with FPS, latency, gold and durability; its fifth slot can show the time, which by default the minimap card's foot shows, as the Lumen mockup does.

| Field | Value |
| --- | --- |
| Module name | `DataBars`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | KstyleUI's own bars, micro menu, bag bar and strip; Blizzard's status bars faded, and its micro menu and bag bar hidden through `Safe` |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_DataBars.toc` lists `DataBars.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- Values Lua may read, such as XP, animate with `KstyleUI.Motion.Tween`.
- Nothing the module does to Blizzard's frames outlasts `Disable`: the status bars get their alpha and mouse back, and `Safe.RestoreBlizzard` returns the micro menu and the bag bar. Turning the module off needs no reload.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`DataBars.xml` loads them in this order.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table: the log, the event hub (`ns.Listen`), the callback hub (`ns.Subscribe`), the parts list and the shared defaults and schema tables |
| `Format.lua` | `ns.Format`: grouped and short numbers, percentages, bar texts, money and clock times |
| `Sources.lua` | `ns.Sources`: experience, reputation and honour read from the game, guarded |
| `Font.lua` | `ns.Font`: the font, size and outline of a bar's text |
| `Bars.lua` | `ns.Bars`: the three bars, their values, ticks, text and tooltip |
| `Blizzard.lua` | `ns.Blizzard`: fades Blizzard's status tracking bars |
| `Strip.lua` | `ns.Strip`: the data strip, its items, ticker, clicks and tooltips |
| `Click.lua` | `ns.Click`: the secure proxy that carries a strip click to Blizzard's own button |
| `Menus.lua` | `ns.Menus`: KstyleUI's micro menu and bag bar, secure buttons that click Blizzard's hidden ones |
| `Settings.lua` | The defaults, the settings rows and the live preview |
| `Module.lua` | Registers the module and its settings, and runs each part's `Enable`, `Disable`, `Setting` and `Refresh` |

Each part file adds a part with `ns.AddPart({ Enable, Disable, Setting, Refresh })`. `Module.lua` runs `Enable` in load order and `Disable` in reverse. `Setting(key)` runs when the player changes a DataBars setting, and `Refresh()` runs on `ProfileChanged`, `ThemeChanged` and `ScaleChanged`. Tests: `Tools/regression/test-databars-format.lua`, `test-databars-sources.lua`, `test-databars-bars.lua`, `test-databars-strip.lua` and `test-databars-menus.lua`, which load the module through `Tools/regression/databars_env.lua`.

## Bars

| Element key | Bar | Shows | Source |
| --- | --- | --- | --- |
| `databars.xp` | Experience | Below the level cap, unless experience is turned off | `UnitXP`, `UnitXPMax`, `GetXPExhaustion`, `GetRestState`. `GameRulesUtil.CanShowExperienceBar` decides when the bar hides, then `GetMaxLevelForPlayerExpansion` or `GetMaxPlayerLevel`. |
| `databars.rep` | Reputation | While a faction is watched | `C_Reputation.GetWatchedFactionData`, with paragon, renown (`C_MajorFactions.GetMajorFactionData`) and friendship (`C_GossipInfo.GetFriendshipReputation`) progress |
| `databars.honor` | Honour | In battlegrounds and world PvP, or always | Forever's PvP rank points (`C_MajorFactions.GetMajorFactionProgressionInfo(2800)`), else `UnitHonor` and `UnitHonorMax` |

Each element is a holder frame registered with Layout as resizable, at its footprint from `Setup.Layouts`. The holder never hides itself: a bar with nothing to show hides its `content` child, so Layout Mode still shows its plate. A track draws the background and rested overlay, and a fill draws progress above it. A gain eases over `fade`; a new level, faction or range jumps at once. The hit area reaches 4 units past the bar.

LEE-20 (2026-11-09, "let the picture win") replaces the old four-unit segmented XP line: the default is 491 by 8 with rounded ends, no border or ticks, and an opaque `hudRested` blue rested reach. Its body-font caption is centred six units below: "Level 11 · 0% · rested 5%" (`levelRested`). This supersedes #204's omission of the level. Colour, border, segment and caption settings remain available; `percentRested` still omits the level. Earned progress retains the selectable gilt gradient. A label placed on a horizontal bar has a small glass plate; a label below it needs none.

### Settings

| Key | Default | Row |
| --- | --- | --- |
| `fadeBlizzard` | `true` | Fade Blizzard's status tracking bars |
| `<bar>.colorSource` | `gilt` for XP, `reaction` for reputation, `custom` for honour | Gilt filament (XP only), class colour, reaction colour (reputation only) or custom colour |
| `<bar>.color` | `accentDefault`, `friendly`, `epic` | The custom colour |
| `<bar>.texture` | Glass | Any status bar texture, LibSharedMedia's included |
| `<bar>.orientation` | `HORIZONTAL` | `HORIZONTAL` or `VERTICAL`. A change swaps the element's width and height through `Layout.Update`. |
| `<bar>.reverse` | `false` | Fill from the other end |
| `<bar>.segments` | 0 | 0 to 20 equal segments, drawn as ticks one border wide; the mockup's experience line is unbroken |
| `<bar>.border` | `true` | The chamfered frame around the bar |
| `xp.rested`, `xp.restedColor` | `true`, `rare` at 50% | The rested overlay and its colour |
| `honor.show` | `pvp` | `pvp` or `always` |
| `<bar>.text` | `levelRested` for XP, `labelPercent` for the others | `none`, `percent`, `value`, `valuePercent`, `short`, `remaining`, `label`, `labelPercent`, `labelValue`, `shortPercent`, `levelRested` (the level, the percent and the rested share, joined by middle dots; the rested part only while there is rested experience), `percentRested` (the same without the level) |
| `<bar>.textHover` | `false` for XP, `true` for the others | Show the text only under the pointer |
| `<bar>.textPosition` | `BOTTOM` for XP, `CENTER` for the others | On, above, below, left or right of the bar. On the line, the label keeps its glass plate. |
| `<bar>.font` | `default` | The interface font, or any bundled or LibSharedMedia font |
| `<bar>.fontSize` | 12 for experience (the mockup's "XP 32%"), 9 (the `caption` size) for the others | 6 to 24, times the Appearance page's text size |
| `<bar>.outline` | `NONE` for XP, `OUTLINE` for the others | `NONE` (a soft shadow), `OUTLINE` or `THICKOUTLINE` |

Layout gives each bar its shown rule, position, size, opacity and strata.

## Data strip

`databars.strip` is the readout, registered with Layout at 278 x 12 (`Strip.LINE` and `Strip.COMPACT`), at the right rail's foot, 6 units over the damage card. By default it is one line of plain text with no card, right-aligned on the element's right edge and centred in its 12 units, as the owner's picture draws it: "162 fps · 15 ms · 26s 16c". Each item is its value followed by its unit in the same face, size and `text` colour (the picture's #c3cbd4 measures as this grey-white, not `textEmphasis`; LEE-70), and the items are joined by a middle dot (U+00B7, written as the decimal escape `\194\183` in the source; every bundled face has the glyph). The line reads at 12 units in the body face, one unit above the font's own centring so the baseline lands on the picture's, with each dot centred in the gap between two items (the picture draws oldstyle proportional figures, where the kit's body face has tabular lining ones, so the first number starts about 9 pixels further left; see the PR for that limit). Each item is its own button covering just its text, so it keeps its KstyleUI tooltip and its click: the secure proxy covers the hovered item's text, not the line. A value that grows on a tick pushes the items left of it further left, and the right edge stays put.

**The picture wins over #211 (LEE-20, 2026-11-09).** The readout was a 318 x 42 glass card of five fixed cells (the frame rate in the accent, durability as "96% armour", the clock off), docked at the rail's foot under the damage card with the menu rows hung under its line. The owner's picture draws a plain line above the damage card with no durability, so the defaults changed and the old looks stayed as settings: `strip.line` (on), `strip.backdrop` (off), `strip.valueColor` (`plain`), `strip.slot4` (`none`, durability stays a choice), `strip.menus` (off) and `strip.fontSize` (11). With `strip.line` off, or the strip turned into a column, the strip is the cells layout described next, on glass again if `strip.backdrop` is on; turning the line off grows the element to 42 units tall so a caption and a value fit, turning it on returns it to 12. The checks in `test-databars-strip.lua` pin the line, then draw the cells on the composition mockup's 492 x 43 strip.

The cells layout holds up to five items, each in its own fixed cell: a caption in the text grey, 2 points smaller than the value (never below the `caption` size), over a value in white (or graded), on a button that lights under the pointer and shows a KstyleUI tooltip, so the values lead when the player scans it.

In the cells layout the cells share the width inside one content inset by weight (`CELL_WEIGHT` in `Strip.lua`): frame rate 0.8, latency 0.9, gold 1.4, durability 1.25, time 0.85. A cell depends only on the strip's size and the items shown, never on a value, so a frame rate that falls from 144 to 9, or gold that grows, moves nothing. A value wider than its cell is cut short, and its tooltip carries the whole value. The readable minimum is 4 ems of the value size per unit of weight, about 250 units for five items at 12; the settings preview scales its sample strip down below that. The captions step aside, and the values sit on the centre line, when the caption and value together are taller than the strip inside its edge lines (a large font) or when any caption is wider than its cell (a narrow strip). No separators by default; turned on, a separator is a hairline at a cell's left edge, 40% of the strip's height, in the text grey at 35%. In a column each row has its caption at the left and its value at the right.

| Item | Value | Colour when graded | Updates | Left click | Right click |
| --- | --- | --- | --- | --- | --- |
| `fps` | `GetFramerate`, rounded | 60 and up good, 30 and up fair | Every second | Opens the DataBars settings page | |
| `latency` | `GetNetStats` home or world latency | Under 150 ms good, under 300 ms fair | Every second | Switches between home and world | |
| `gold` | `GetMoney`, as gold, silver and copper, gold only or coin icons | | `PLAYER_MONEY` | Blizzard's backpack button, through the secure proxy | |
| `durability` | The most worn equipped item, from `GetInventoryItemDurability` | 50% and up good, 25% and up fair | `UPDATE_INVENTORY_DURABILITY`, `PLAYER_EQUIPMENT_CHANGED` | Blizzard's character button, through the secure proxy | |
| `time` | `date("*t")` or `GetGameTime` | | Every second | Blizzard's calendar button (`GameTimeFrame`, else `TimeManagerClockButton`), through the secure proxy | Switches between a 12 and a 24-hour clock |

The tooltips add detail: home and world latency and bandwidth, money earned or spent this session, each equipped slot's durability, and local and realm time. One `C_Timer.NewTicker` of 1 second runs while a timed item shows and stops with the module; a client without it counts seconds with an `OnUpdate` on the strip. A tick reads only the timed items (frame rate, latency and the clock) into preallocated tables and moves items only when a text's width changed. Gold and durability update on their own events. The clock reads `date("%H")` and `date("%M")`, so a tick builds no date table.

An XP, reputation or honour event repaints only a bar's values, colour and text. Textures, orientation, ticks and the font are restyled only when a setting, the layout, the profile, the theme or the scale changes.

### Settings

| Key | Default | Row |
| --- | --- | --- |
| `strip.slot1` to `strip.slot5` | `fps`, `latency`, `gold`, `none`, `none` | What each place shows, or `none`, counted from the left of the line. An item in two places shows once, at the first. The picture's line has no durability, so `durability` leaves the default but stays a choice (it reads "96% armour"); the clock (`time`) is off by default because the minimap card shows it. |
| `strip.line` | `true` | One right-aligned line joined by middle dots (the picture), or the cells. A column is always rows. In the line the `full` and `short` labels use the inline units. |
| `strip.labels` | `inline` | `inline` units after each value (179 fps, 34 ms, 96% armour, as the Lumen mockup's readout), `full` captions over the values (Frame rate, Latency, Gold, Durability, Time), `short` (FPS, MS, DUR, as in the dungeon mockup) or `none` |
| `strip.valueColor` | `plain` (was `highlight`) | `highlight` (the frame rate in the accent colour, the composition mockup's one highlighted value, with fair and poor grades in the neutral and hostile warning colours and every other value white), `threshold` (good, fair, poor in the friendly, neutral and hostile colours), `accent` or `plain` |
| `strip.accentEdge` | `false` | The panel's inner edge in the accent colour |
| `strip.backdrop`, `strip.separators` | `false` (was `true`), `false` | The glass panel (with the line, the text then keeps the card's inset from the edge) and the lines between cells |
| `strip.spacing` | 16 | 0 to 32 units of room inside each cell, split between its sides (at least 2) |
| `strip.menus` | `false` (was `true`) | Dock the micro menu and the bag bar under the readout when they are shown. Off, each stands at its own Layout slot, because the line has no room around it on the picture's rail. |
| `strip.orientation` | `HORIZONTAL` | A row, or a column. A change resizes the element through `Layout.Update`. |
| `strip.font`, `strip.fontSize`, `strip.outline` | interface font, 12 (was 11), `NONE` | As for the bars' text. 12 is the picture's readout, measured on its letters at the owner's screen (the f is 15 pixels tall, the m 14 wide, the s 10 tall) in LEE-70; a profile that saved 11 keeps it. 13 read oversized in game. |
| `strip.money` | `full` | `full`, `gold` or `icons` |
| `strip.latency` | `home` | `home` or `world` |
| `strip.timeSource`, `strip.clock24` | `local`, `true` | Local or realm time, and the clock format |
| `accentSource`, `accentColor` | `class`, `accentDefault` | The module's accent: the class colour or a custom colour |

## Micro menu and bag bar

`databars.micro` and `databars.bags` are KstyleUI's own bars, registered with Layout as scalable holders at their footprints from `Setup.Layouts`: the micro menu above the data strip and the bag bar above it, bottom right. While a bar is on, `Safe.HideBlizzard` hides Blizzard's: `MicroMenuContainer`, the Edit Mode frame that holds `MicroMenu`, and `BagsBar`.

Both bars are on by default and out of sight at rest, because the owner's picture shows neither (the Captain's ruling on #221, under "let the picture win its what i want", LEE-20; #197 had hidden them outright). At rest each bar's content frame has alpha 0; it fades in (`Tokens.Duration("fade")`) while the pointer is over one of its buttons or anywhere on its row, and back out 0.2 s after the pointer leaves the row (a hover hook on each button and on the row, which takes mouse motion but not clicks through `SetMouseMotionEnabled`, set out of combat because it is a protected call; then a `C_Timer.NewTicker` that reads `IsMouseOver` until the pointer is gone). A profile switch recomputes the fade. Both stay in sight while Blizzard's Edit Mode is on (`EventRegistry` `EditMode.Enter` and `EditMode.Exit`, `EditModeManagerFrame:IsEditModeActive`) or KstyleUI's Layout Mode is open; the bag bar while a bag is open (`IsAnyBagOpen`, `BAG_OPEN`, `BAG_CLOSED`, the bag toggles, or KstyleUI's bag window shown); the micro menu while the game points at one of its buttons (a micro button that `IsPulsing` or `HasNotification`, or a help tip in the `MicroButtons` system, `HelpTip:IsShowingAnyInSystem`). `menus.always` keeps both in sight. The fade only sets the alpha of KstyleUI's own content frame: `SetAlpha` carries no `IsProtectedFunction` flag in `SimpleFrameAPIDocumentation.lua` (70862), where `SetPoint` does (`SimpleScriptRegionResizingAPIDocumentation.lua`), so it runs in combat on a frame that holds secure buttons; at alpha 0 the buttons still take clicks and keybinds, as the chat card's buttons do. Nothing hides, reparents or fades a Blizzard frame. Switched off (`micro.shown`, `bags.shown`), a bar shows no buttons, is not live in Layout Mode, and Blizzard's bar stays hidden through `Safe`, so nothing returns to the bottom centre. The game's keybinds open every window as before (B, C, P, N, L, J, Escape and the rest call Blizzard's toggles, not the micro buttons), and the readout's gold and durability still open the bags and the character sheet through the secure proxy. Neither setting hides, moves or touches a Blizzard frame. Docked, the secure buttons make the strip's frame protected, so a row turned on or off in combat waits, with the element's height, for combat to end (`Combat.Queue`), as the buttons' own placing always has.

Each KstyleUI button is a `Widgets.IconButton` made from `SecureActionButtonTemplate`, with `type = "click"` and `clickbutton` set once, when the bar is built, to Blizzard's own button. A click runs Blizzard's handler from secure code, as a click on Blizzard's button would, so the buttons work in combat.

| | Micro menu | Bag bar |
| --- | --- | --- |
| Buttons | One per Blizzard micro button that `MicroMenu` holds and shows, in Blizzard's `layoutIndex` order. The compact set (the default) shows eight: character, professions, spellbook, talents (or Forever's combined spells and talents), quest log, guild, group finder and the game menu; the rest wait under the game menu and their keybinds. The full set shows every button. | Key ring, reagent bag, bags 4 to 1 and the backpack, left to right, each while Blizzard shows it |
| Icon | Blizzard's glyph atlas from the button's normal texture, on an upright tile 3 wide by 4 tall; the character button shows your portrait | The equipped bag's icon from `GetInventoryItemTexture`, else Blizzard's own icon: the backpack, the key ring or the empty slot |
| States | Disabled, selected while its window is open (`GetButtonState` is `PUSHED`), and the proc glow while Blizzard's button pulses or has a notification | The backpack counts the free slots in all bags |
| Tooltip | Blizzard's `tooltipText`, with the level a disabled button opens at | The bag's name and free slots, or how to equip one |
| Extras | The game menu button toggles `GameMenuFrame` with `ShowUIPanel` and `HideUIPanel` out of combat, because Blizzard's handler opens the menu only while the pointer is over Blizzard's own button; in combat its tooltip points to Escape | Dropping an item puts it in the bag (`PutItemInBag`, `PutItemInBackpack`) and a key in the key ring out of combat (`PutKeyInKeyRing`); dragging a bag lifts it off its slot out of combat (`PickupBagFromSlot`) |

The bars follow Blizzard's state through `hooksecurefunc` on `UpdateMicroButtons`, `MicroButtonPulse`, `MicroButtonPulseStop`, `LoadMicroButtonTextures` and `PaperDollItemSlotButton_Update`, through each micro button's own callback registry (`OnBeginPulse`, `OnEndPulse`, `OnEnable`, `OnDisable`, `OnNewNotification`, `OnDismissedNotification`, which Blizzard runs with `securecallfunction`), and on `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_ENTERING_WORLD` and the portrait events. A bar shows only while Blizzard's own `MicroMenu` or `BagsBar` is shown, so both hide with Blizzard's in the gamepad interface (hooks on `MainActionBar_InitializeGamepad`, `MainActionBar_InitializeMKB` and `MainActionBar_UnInitializeMKB`). While a vehicle bar or the pet battle frame holds `MicroMenu` (`OverrideMicroMenuPosition`), Blizzard shows its own micro menu there and KstyleUI's steps aside until `ResetMicroMenuPosition` puts it back. Showing, hiding, placing and sizing the secure buttons waits for `Combat.Queue` in combat; icons, colours and states change at once. A Blizzard update that changes nothing moves nothing.

| Key | Default | Row |
| --- | --- | --- |
| `micro.enabled`, `bags.enabled` | `true` | Show KstyleUI's bar in place of Blizzard's. Off, `Safe.RestoreBlizzard` gives Blizzard's back where Edit Mode puts it. |
| `micro.shown`, `bags.shown` | `true` (was `false`) | Show the bar's buttons (Show the micro menu, Show the bag bar). Off, the bar is hidden (and, docked, the readout shrinks back to its line); Blizzard's stays hidden while `enabled` is on. Saved data at version 3 or older (`Store.migrations[4]`) keeps a bar shown when its player had set it up: any size, spacing, rows, glass, shape, set, tint or free-slot setting changed from its default, or `strip.menus` off. A bar handed back to Blizzard keeps the new default. |
| `menus.always` | `false` | Always show the menu and bag bars. Off, both are out of sight until the pointer is over them, a bag is open, Edit Mode or Layout Mode is on, or the game points at a micro button. |
| `micro.size`, `bags.size` | 26, 26 | Button height, 12 to 48. A micro button is three quarters as wide. Both bars sit on a tile of glass with a 3-unit rim, so each button's cut corner nests inside the tray's cut and each tray is 32 units tall, inside the 36-unit pitch the layouts put between the two bars. |
| `micro.spacing`, `bags.spacing` | 4 | The gap between buttons, 0 to 12 |
| `micro.rows`, `bags.rows` | 1 | How many rows the buttons fill |
| `micro.backdrop`, `bags.backdrop` | `true` | The glass behind the buttons |
| `micro.set` | `compact` | `compact` (the eight above, at a size that reads) or `full` (every button Blizzard shows) |
| `micro.tint` | `none` | `none` keeps Blizzard's glyph colours; `accent` and `white` desaturate the glyphs and tint them |
| `bags.freeSlots` | `true` | The free-slot count on the backpack |

Layout gives each bar its shown rule, position, scale, opacity and strata.

By default (`strip.menus` off) the bars stand at their own Layout slots, one under the other beside the rail's spare room, because the line has no room around it (the picture's rail, LEE-20). With `strip.menus` on both bars dock under the readout's line, in the same element: the line is 12 units (`Strip.LINE`; 30 in the cells layout, which holds the card's top padding itself), so the first row starts a small gap under the text, both rows end on the element's right edge under the right-aligned text, the micro menu just left of the bags on the same line when all the buttons fit at their set size or at 22 units, else the bag row under the micro row, and a bar whose buttons do not fit a row at 22 units wraps into more rows rather than shrinking further (`Strip.MenuPlan`). A bare line (no glass) has no padding of its own, so the rows sit on the right edge. The element's height follows the rows, and `Layout.Update` writes it, so the Layout Mode plate hugs them. With both rows hidden the element is the line alone (`Strip.COMPACT`, 12 units; the cells layout adds its 12-unit padding). Free of the menus, the strip keeps the player's own height.

## Why

- **Our own bars, Blizzard's faded.** Blizzard's experience and reputation containers sit in Edit Mode's bottom bar stack, which Blizzard lays out together with the protected action bars. NaowhForever hid those containers and tainted the action bars. DataBars therefore never hides, reparents, moves or hooks them: it sets `StatusTrackingBarManager`'s alpha to 0 and turns off the mouse on each bar, so the invisible bars cannot show a tooltip or catch a click over KstyleUI's HUD. `Disable` restores both.
- **Readable values only.** Experience, reputation, rank points and honour are not secret on Forever. The bars still check `issecretvalue` before any comparison, and a secret value hides its bar and logs once, so a future client change cannot raise an error.
- **Honour is Forever's PvP rank.** Forever loads Blizzard's honour bar, but its PvP progression is the rank points of major faction 2800, which Blizzard's own PvP rank panel reads. The honour bar shows those points and the rank, and falls back to `UnitHonor` when the faction returns nothing. The bar has its own element key, `databars.honor`, under the reputation bar; the experience and reputation bars moved up 3 and 4 units to make room.
- **A holder and its content.** Layout owns the holder's visibility for the player's shown rule. The module shows and hides only the content, so the two never fight over one frame.
- **One event and one callback hub.** `KstyleUI.Events` and `KstyleUI.Callbacks` keep one handler per owner and event. Several bars listen for `UPDATE_FACTION` and `PLAYER_ENTERING_WORLD`, so `Init.lua` collects every handler and registers one dispatcher per event when the module starts. `Modules` removes them all when it stops.
- **The micro menu and bag bar are replaced, not moved.** Forever's Edit Mode puts Blizzard's micro menu at the bottom centre (`MICRO_MENU_ANCHOR_OFFSET_X = 116.5` in `Camelot/EditModePresetLayoutConstants.lua`) with `BagsBar` beside it, on top of KstyleUI's action bars and data bars, and the spec places frames with KstyleUI's Layout Mode. Layout never moves a Blizzard frame, so, as the spec says for a Blizzard frame that needs a new place, `Safe` hides Blizzard's and KstyleUI's own bars take their place. `MainActionBar` and `BagsBar` anchor to `MicroMenuContainer`; reparenting keeps every anchor, so nothing protected moves, and `Safe` waits for the end of combat and of Edit Mode. DataBars hides the container, not `MicroMenu`, because Blizzard puts `MicroMenu` back into its container after vehicles and pet battles (`ResetMicroMenuPosition`). It never moves, hides or hooks `OnShow` inside either tree, and it writes no field onto a Blizzard frame.
- **Each button clicks Blizzard's own.** Opening a window from addon code would call Blizzard functions that open Blizzard windows, which the reskin rules forbid and which can taint the panel code. A `SecureActionButtonTemplate` with `type = "click"` instead runs Blizzard's button's handler from secure code. Unlike the strip's single proxy, which moves to the hovered item and so cannot follow the pointer in combat, every micro and bag button is its own secure button, so bags open in combat.
- **Strip clicks reach Blizzard's buttons through a secure proxy.** Opening bags, the character sheet or the calendar from addon code calls Blizzard functions that open Blizzard windows, which the reskin rules forbid and which can taint the bag and panel code. Instead one `SecureActionButtonTemplate` button, parented to `UIParent` so no KstyleUI frame turns protected, covers the hovered strip item out of combat with `type1 = "click"` and `clickbutton1` set to Blizzard's own button. The click then runs Blizzard's handler untainted. `PLAYER_REGEN_DISABLED`, which fires before lockdown, puts the proxy away; in combat the items keep their tooltips and say the action waits for combat to end. A right click passes through the proxy's `PostClick` hook to the item's own action.
- **Fonts outside the kit's restyle list.** The kit restyles every text made with `Widgets.Text` to its role's font on `ThemeChanged`, which would undo a player's chosen font. Bar texts are plain font strings that `Font.Apply` styles, and the module applies them again on `ThemeChanged`, `ScaleChanged` and `ProfileChanged`.
