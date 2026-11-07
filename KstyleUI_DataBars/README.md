# KstyleUI_DataBars

XP, reputation and honour bars, micro menu, bag bar, and a data strip with FPS, latency, gold, durability and time.

| Field | Value |
| --- | --- |
| Module name | `DataBars`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin, plus our own strip |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_DataBars.toc` lists `DataBars.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- Values Lua may read, such as XP, animate with `KstyleUI.Motion.Tween`.
- Blizzard frames keep a reskin after `Disable`, so turning the module off asks the player to reload.
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
| `Menus.lua` | `ns.Menus`: the micro menu and the bag bar, restyled in place |
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
| `<bar>.segments` | 10 | 0 to 20 equal segments, drawn as ticks one border wide |
| `<bar>.border` | `true` | The chamfered frame around the bar |
| `xp.rested`, `xp.restedColor` | `true`, `rare` at 50% | The rested overlay and its colour |
| `honor.show` | `pvp` | `pvp` or `always` |
| `<bar>.text` | `valuePercent` for XP, `labelPercent` for the others | `none`, `percent`, `value`, `valuePercent`, `short`, `remaining`, `label`, `labelPercent`, `labelValue` |
| `<bar>.textHover` | `true` | Show the text only under the pointer |
| `<bar>.textPosition` | `CENTER` | On, above, below, left or right of the bar |
| `<bar>.font` | `default` | The interface font, or any bundled or LibSharedMedia font |
| `<bar>.fontSize` | 10 | 6 to 24, times the Appearance page's text size |
| `<bar>.outline` | `OUTLINE` | `NONE` (a soft shadow), `OUTLINE` or `THICKOUTLINE` |

Layout gives each bar its shown rule, position, size, opacity and strata.

## Data strip

`databars.strip` is one resizable glass panel registered with Layout at its footprint, 430 x 36, bottom right. It holds up to five items, each a label and a value on a button that lights under the pointer and shows a KstyleUI tooltip.

| Item | Value | Colour when graded | Updates | Left click | Right click |
| --- | --- | --- | --- | --- | --- |
| `fps` | `GetFramerate`, rounded | 60 and up good, 30 and up fair | Every second | Opens the DataBars settings page | |
| `latency` | `GetNetStats` home or world latency | Under 150 ms good, under 300 ms fair | Every second | Switches between home and world | |
| `gold` | `GetMoney`, as gold, silver and copper, gold only or coin icons | | `PLAYER_MONEY` | Blizzard's backpack button, through the secure proxy | |
| `durability` | The most worn equipped item, from `GetInventoryItemDurability` | 50% and up good, 25% and up fair | `UPDATE_INVENTORY_DURABILITY`, `PLAYER_EQUIPMENT_CHANGED` | Blizzard's character button, through the secure proxy | |
| `time` | `date("*t")` or `GetGameTime` | | Every second | Blizzard's calendar button (`GameTimeFrame`, else `TimeManagerClockButton`), through the secure proxy | Switches between a 12 and a 24-hour clock |

The tooltips add detail: home and world latency and bandwidth, money earned or spent this session, each equipped slot's durability, and local and realm time. One `C_Timer.NewTicker` of 1 second runs while a timed item shows and stops with the module; a client without it counts seconds with an `OnUpdate` on the strip. A tick reads values into preallocated tables and moves items only when a text's width changed.

### Settings

| Key | Default | Row |
| --- | --- | --- |
| `strip.slot1` to `strip.slot5` | `fps`, `latency`, `gold`, `durability`, `time` | What each place shows, or `none`. An item in two places shows once, at the first. |
| `strip.labels` | `full` | `full` (FPS:, Durability:), `short` (FPS:, MS:, DUR:, as in the dungeon mockup) or `none` |
| `strip.valueColor` | `threshold` | `threshold` (good, fair, poor in the friendly, neutral and hostile colours), `accent` or `plain` |
| `strip.accentEdge` | `false` | The panel's inner edge in the accent colour |
| `strip.backdrop`, `strip.separators` | `true`, `true` | The glass panel and the lines between items |
| `strip.spacing` | 8 | 0 to 32 units each side of a separator |
| `strip.orientation` | `HORIZONTAL` | A row, or a column. A change resizes the element through `Layout.Update`. |
| `strip.font`, `strip.fontSize`, `strip.outline` | interface font, 11, `NONE` | As for the bars' text |
| `strip.money` | `full` | `full`, `gold` or `icons` |
| `strip.latency` | `home` | `home` or `world` |
| `strip.timeSource`, `strip.clock24` | `local`, `true` | Local or realm time, and the clock format |
| `accentSource`, `accentColor` | `class`, `accentDefault` | The module's accent: the class colour or a custom colour |

## Micro menu and bag bar

Blizzard's `MicroMenu` and `BagsBar` stay Blizzard's frames, where Edit Mode puts them. DataBars restyles them in place with `KstyleUI.Skin` when the module starts:

| Part | Micro menu | Bag bar |
| --- | --- | --- |
| Faded with alpha (`Skin.Strip`, `watch = false`) | Forever's `BorderArt` and `BackgroundArt`, and each button's bronze `Background` and `PushedBackground` | Forever's `BorderArt`, and each slot's `NormalTexture` and `PushedTexture` frame art |
| Kept | The icons, the portrait, the highlight, alerts and the performance bar | The bag icons, quality borders, counts and the highlight |
| Glass (`Skin.Backdrop`) | Behind the menu, 4 units out | Behind the bar, 4 units out |
| Tiles (`Skin.Backdrop`, raised) | Off by default: the menu flattens its render layers, so a tile can sort under the glass | On: each slot sits on a tile 2 units out |

A hovered button's tile edge eases to the accent colour. `micro.tint` keeps Blizzard's icon colours or desaturates the normal, pushed and highlight icons and tints them in the accent colour or white; switching back restores each icon's own colour and desaturation. Disabled icons keep Blizzard's own desaturated look.

| Key | Default | Row |
| --- | --- | --- |
| `micro.skin`, `bags.skin` | `true` | Restyle. Turning one off hides KstyleUI's parts at once and offers a reload, because Blizzard's faded art comes back only after one. |
| `micro.backdrop`, `bags.backdrop` | `true` | The glass |
| `micro.tiles`, `bags.tiles` | `false`, `true` | The tiles |
| `micro.tint` | `none` | `none`, `accent` or `white` |

The module registers with `reskin = true`, so turning DataBars off asks for a reload. The micro menu and bag bar have no Layout element: their place, size, orientation and rows stay in Edit Mode.

## Why

- **Our own bars, Blizzard's faded.** Blizzard's experience and reputation containers sit in Edit Mode's bottom bar stack, which Blizzard lays out together with the protected action bars. NaowhForever hid those containers and tainted the action bars. DataBars therefore never hides, reparents, moves or hooks them: it sets `StatusTrackingBarManager`'s alpha to 0 and turns off the mouse on each bar, so the invisible bars cannot show a tooltip or catch a click over KstyleUI's HUD. `Disable` restores both.
- **Readable values only.** Experience, reputation, rank points and honour are not secret on Forever. The bars still check `issecretvalue` before any comparison, and a secret value hides its bar and logs once, so a future client change cannot raise an error.
- **Honour is Forever's PvP rank.** Forever loads Blizzard's honour bar, but its PvP progression is the rank points of major faction 2800, which Blizzard's own PvP rank panel reads. The honour bar shows those points and the rank, and falls back to `UnitHonor` when the faction returns nothing. The bar has its own element key, `databars.honor`, under the reputation bar; the experience and reputation bars moved up 3 and 4 units to make room.
- **A holder and its content.** Layout owns the holder's visibility for the player's shown rule. The module shows and hides only the content, so the two never fight over one frame.
- **One event and one callback hub.** `KstyleUI.Events` and `KstyleUI.Callbacks` keep one handler per owner and event. Several bars listen for `UPDATE_FACTION` and `PLAYER_ENTERING_WORLD`, so `Init.lua` collects every handler and registers one dispatcher per event when the module starts. `Modules` removes them all when it stops.
- **The micro menu and bag bar are restyled in place, not moved.** On Forever, `MainActionBar` anchors to `MicroMenuContainer`, and `BagsBar` anchors to it too, so moving either from addon code would move protected frames and taint Edit Mode's bottom bar layout. Blizzard also shows and hides the `BagsBar` tree on the way to protected calls. DataBars therefore never hides, reparents, moves or hooks `OnShow` inside these trees: it fades Blizzard's art with alpha and draws its glass and tiles on its own child frames. The element keys `databars.micro` and `databars.bags` stay unregistered, because Layout never moves a Blizzard frame; Edit Mode places these two.
- **Clicks reach Blizzard's buttons through a secure proxy.** Opening bags, the character sheet or the calendar from addon code calls Blizzard functions that open Blizzard windows, which the reskin rules forbid and which can taint the bag and panel code. Instead one `SecureActionButtonTemplate` button, parented to `UIParent` so no KstyleUI frame turns protected, covers the hovered strip item out of combat with `type1 = "click"` and `clickbutton1` set to Blizzard's own button. The click then runs Blizzard's handler untainted. `PLAYER_REGEN_DISABLED`, which fires before lockdown, puts the proxy away; in combat the items keep their tooltips and say the action waits for combat to end. A right click passes through the proxy's `PostClick` hook to the item's own action.
- **Fonts outside the kit's restyle list.** The kit restyles every text made with `Widgets.Text` to its role's font on `ThemeChanged`, which would undo a player's chosen font. Bar texts are plain font strings that `Font.Apply` styles, and the module applies them again on `ThemeChanged`, `ScaleChanged` and `ProfileChanged`.
