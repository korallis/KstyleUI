# KstyleUI_DataBars

XP, reputation and honour bars, micro menu, bag bar, and a data strip with FPS, latency, gold, durability and time.

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
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `DataBars.xml`.
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

Each element is a holder frame registered with Layout as resizable, at its footprint from `Setup.Layouts`. The holder never hides itself: a bar with nothing to show hides its `content` child, so Layout Mode still shows its plate. Inside the content a track bar draws the background, the frame and the rested overlay, and a fill bar draws progress above it. A gain eases the fill over `fade` with `Motion.Tween`; a new level, a new faction or a new range jumps at once. The text and the KstyleUI tooltip show on hover; the holder's hit area reaches 4 units past the thin bar.

### Settings

| Key | Default | Row |
| --- | --- | --- |
| `fadeBlizzard` | `true` | Fade Blizzard's status tracking bars |
| `<bar>.colorSource` | `class` for XP, `reaction` for reputation, `custom` for honour | Class colour, reaction colour (reputation only) or custom colour |
| `<bar>.color` | `accentDefault`, `friendly`, `epic` | The custom colour |
| `<bar>.texture` | Glass | Any status bar texture, LibSharedMedia's included |
| `<bar>.orientation` | `HORIZONTAL` | `HORIZONTAL` or `VERTICAL`. A change swaps the element's width and height through `Layout.Update`. |
| `<bar>.reverse` | `false` | Fill from the other end |
| `<bar>.segments` | 0 | 0 to 20 equal segments, drawn as ticks one border wide; the mockup's experience line is unbroken |
| `<bar>.border` | `true` | The chamfered frame around the bar |
| `xp.rested`, `xp.restedColor` | `true`, `rare` at 50% | The rested overlay and its colour |
| `honor.show` | `pvp` | `pvp` or `always` |
| `<bar>.text` | `shortPercent` for XP, `labelPercent` for the others | `none`, `percent`, `value`, `valuePercent`, `short`, `remaining`, `label`, `labelPercent`, `labelValue`, `shortPercent` |
| `<bar>.textHover` | `false` for XP, `true` for the others | Show the text only under the pointer |
| `<bar>.textPosition` | `CENTER` | On, above, below, left or right of the bar |
| `<bar>.font` | `default` | The interface font, or any bundled or LibSharedMedia font |
| `<bar>.fontSize` | 12 for experience (the mockup's "XP 32%"), 9 (the `caption` size) for the others | 6 to 24, times the Appearance page's text size |
| `<bar>.outline` | `OUTLINE` | `NONE` (a soft shadow), `OUTLINE` or `THICKOUTLINE` |

Layout gives each bar its shown rule, position, size, opacity and strata.

## Data strip

`databars.strip` is one resizable glass panel registered with Layout at its footprint, 492 x 43 with 10.5-unit chamfers (the composition mockup's strip at 1.348 px per unit), bottom right. It holds up to five items, each a white label and a value on a button that lights under the pointer and shows a KstyleUI tooltip. The separators between items are one border wide, a quarter of the strip tall, in the full text grey.

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
| `strip.slot1` to `strip.slot5` | `fps`, `latency`, `gold`, `durability`, `time` | What each place shows, or `none`. An item in two places shows once, at the first. |
| `strip.labels` | `full` | `full` (FPS:, Durability:), `short` (FPS:, MS:, DUR:, as in the dungeon mockup) or `none` |
| `strip.valueColor` | `highlight` | `highlight` (the frame rate in the accent colour, the composition mockup's one highlighted value, with fair and poor grades in the neutral and hostile warning colours and every other value white), `threshold` (good, fair, poor in the friendly, neutral and hostile colours), `accent` or `plain` |
| `strip.accentEdge` | `false` | The panel's inner edge in the accent colour |
| `strip.backdrop`, `strip.separators` | `true`, `true` | The glass panel and the lines between items |
| `strip.spacing` | 21 | 0 to 32 units each side of a separator |
| `strip.orientation` | `HORIZONTAL` | A row, or a column. A change resizes the element through `Layout.Update`. |
| `strip.font`, `strip.fontSize`, `strip.outline` | interface font, 13, `NONE` | As for the bars' text. At 13 the five default items span the mockup's 444 units inside the 492 strip. |
| `strip.money` | `full` | `full`, `gold` or `icons` |
| `strip.latency` | `home` | `home` or `world` |
| `strip.timeSource`, `strip.clock24` | `local`, `true` | Local or realm time, and the clock format |
| `accentSource`, `accentColor` | `class`, `accentDefault` | The module's accent: the class colour or a custom colour |

## Micro menu and bag bar

`databars.micro` and `databars.bags` are KstyleUI's own bars, registered with Layout as scalable holders at their footprints from `Setup.Layouts`: the micro menu above the data strip and the bag bar above it, bottom right. While a bar is on, `Safe.HideBlizzard` hides Blizzard's: `MicroMenuContainer`, the Edit Mode frame that holds `MicroMenu`, and `BagsBar`.

Each KstyleUI button is a `Widgets.IconButton` made from `SecureActionButtonTemplate`, with `type = "click"` and `clickbutton` set once, when the bar is built, to Blizzard's own button. A click runs Blizzard's handler from secure code, as a click on Blizzard's button would, so the buttons work in combat.

| | Micro menu | Bag bar |
| --- | --- | --- |
| Buttons | One per Blizzard micro button that `MicroMenu` holds and shows, in Blizzard's `layoutIndex` order | Key ring, reagent bag, bags 4 to 1 and the backpack, left to right, each while Blizzard shows it |
| Icon | Blizzard's glyph atlas from the button's normal texture, on an upright tile 3 wide by 4 tall; the character button shows your portrait | The equipped bag's icon from `GetInventoryItemTexture`, else Blizzard's own icon: the backpack, the key ring or the empty slot |
| States | Disabled, selected while its window is open (`GetButtonState` is `PUSHED`), and the proc glow while Blizzard's button pulses or has a notification | The backpack counts the free slots in all bags |
| Tooltip | Blizzard's `tooltipText`, with the level a disabled button opens at | The bag's name and free slots, or how to equip one |
| Extras | The game menu button toggles `GameMenuFrame` with `ShowUIPanel` and `HideUIPanel` out of combat, because Blizzard's handler opens the menu only while the pointer is over Blizzard's own button; in combat its tooltip points to Escape | Dropping an item puts it in the bag (`PutItemInBag`, `PutItemInBackpack`) and a key in the key ring out of combat (`PutKeyInKeyRing`); dragging a bag lifts it off its slot out of combat (`PickupBagFromSlot`) |

The bars follow Blizzard's state through `hooksecurefunc` on `UpdateMicroButtons`, `MicroButtonPulse`, `MicroButtonPulseStop`, `LoadMicroButtonTextures` and `PaperDollItemSlotButton_Update`, through each micro button's own callback registry (`OnBeginPulse`, `OnEndPulse`, `OnEnable`, `OnDisable`, `OnNewNotification`, `OnDismissedNotification`, which Blizzard runs with `securecallfunction`), and on `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_ENTERING_WORLD` and the portrait events. A bar shows only while Blizzard's own `MicroMenu` or `BagsBar` is shown, so both hide with Blizzard's in the gamepad interface (hooks on `MainActionBar_InitializeGamepad`, `MainActionBar_InitializeMKB` and `MainActionBar_UnInitializeMKB`). While a vehicle bar or the pet battle frame holds `MicroMenu` (`OverrideMicroMenuPosition`), Blizzard shows its own micro menu there and KstyleUI's steps aside until `ResetMicroMenuPosition` puts it back. Showing, hiding, placing and sizing the secure buttons waits for `Combat.Queue` in combat; icons, colours and states change at once. A Blizzard update that changes nothing moves nothing.

| Key | Default | Row |
| --- | --- | --- |
| `micro.enabled`, `bags.enabled` | `true` | Show KstyleUI's bar in place of Blizzard's. Off, `Safe.RestoreBlizzard` gives Blizzard's back where Edit Mode puts it. |
| `micro.size`, `bags.size` | 24, 22 | Button height, 12 to 48. A micro button is three quarters as wide. |
| `micro.spacing`, `bags.spacing` | 2 | The gap between buttons, 0 to 12 |
| `micro.rows`, `bags.rows` | 1 | How many rows the buttons fill |
| `micro.backdrop`, `bags.backdrop` | `true` | The glass behind the buttons |
| `micro.tint` | `none` | `none` keeps Blizzard's glyph colours; `accent` and `white` desaturate the glyphs and tint them |
| `bags.freeSlots` | `true` | The free-slot count on the backpack |

Layout gives each bar its shown rule, position, scale, opacity and strata.

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
