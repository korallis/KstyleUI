# KstyleUI_Meters

Damage Meter skin, our own threat meter and a swing timer.

| Field | Value |
| --- | --- |
| Module name | `Meters`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Mirror |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Meters.toc` lists `Meters.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- The swing timer uses Forever's `C_SwingTimer` and the `PLAYER_SWING` event. The combat log is closed to addons.
- Threat values are readable on Forever. `C_DamageMeter` values may turn secret in combat: check each with `issecretvalue` and pass secrets only to widget setters.
- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Meters.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Meters.xml` loads them in this order.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table and `ns.Place`, which registers a meter with Layout under its element key |
| `Logic.lua` | Pure rules with no frames: readable numbers, percentages, swing progress, threat sorting and threat warnings |
| `Settings.lua` | The defaults, the settings schema, checked setting reads (`ns.Get`), and the colour and font rules every meter shares |
| `BarList.lua` | The glass panel the damage and threat meters share: title, accent mark, column heading, rows of bars, a note line and the warning edge and glow |
| `Swing.lua` | The swing timer |
| `Threat.lua` | The threat meter |
| `DamageSkin.lua` | The restyle of Blizzard's Damage Meter windows |
| `Damage.lua` | The damage meter window, and the choice between it and the restyle |
| `Preview.lua` | The settings window's live preview |
| `Meters.lua` | The module's registration, `Enable` and `Disable`, and one event dispatcher the three parts share |

Tests: `Tools/regression/test-meters-logic.lua`, `test-meters-module.lua`, `test-meters-swing.lua`, `test-meters-threat.lua`, `test-meters-damage.lua`, `test-meters-skin.lua` and `test-meters-preview.lua`. `Tools/regression/meters_env.lua` loads the core and the module with stand-ins for the swing, threat and Damage Meter APIs.

## Elements

| Key | Element | Footprint | Size limits |
| --- | --- | --- | --- |
| `meters.damage` | Damage meter | 208 x 130 | 120 to 600 wide, 40 to 800 tall |
| `meters.threat` | Threat meter | 208 x 104 | 120 to 600 wide, 40 to 800 tall |
| `meters.swing` | Swing timer | 260 x 8 | 40 to 800 wide, 2 to 64 tall |

Each element is a holder frame that Layout places, sizes and shows. The meter draws inside it on a child frame, so Layout and the module never show or hide the same frame. A meter switched off in the settings hides its holder too. The rows that fit follow the holder's height: a taller meter shows more rows. The title, the rows and the values sit one content inset (`chrome:Inset()`, the rule every text panel follows: half the corner cut, the edge lines and a `gapSmall`, about 12 units) inside the glass, so nothing sits under a corner cut or on the light line; at that padding the default damage footprint fits four 18-unit rows, 2 units apart, under its title and the threat footprint three. The rows share out whatever the last whole row leaves (`Logic.FillRows`), so no dead band sits under them at any height. The glass hangs from the holder's top and ends one inset under the last row shown, so one source leaves no empty slab under it, and the title and the rows never move as sources come and go; a full list fills the holder, an empty one keeps one row of room for its note, and the glass never runs past the holder. A row is never shorter than its text needs: the text size, the class edge above and below it and 2 units of air. A large font on a short row set in the settings makes the rows taller, and the rows counted and the rows drawn use that same snapped height.

Each row is one bar across the content width that carries its name at the left and its value and share at the right, in the unit frames' 12-point bar text. The fill is the source's colour at half strength (`ns.FILL_ALPHA`), so white text reads on every class colour, and a 2-unit edge in the full colour runs along the row's foot as far as the fill. The title sits on a faint rule that fades at both ends, with the accent mark on the rule under the title, as the chat's selected tab is underlined. Blizzard's restyled window takes the same half-strength fill.

## Damage meter

- **KstyleUI window** (the default). The window reads `C_DamageMeter.GetCombatSessionFromType(session, type)` on `DAMAGE_METER_COMBAT_SESSION_UPDATED`, `DAMAGE_METER_CURRENT_SESSION_UPDATED` and `DAMAGE_METER_RESET`, at most once every 0.3 seconds. Each source becomes a row: the name, a bar of its total against the session's top amount, the amount (the rate for the per-second types) through `AbbreviateNumbers`, and its share of the total. Deaths show the time of death. While the window shows, `Safe.HideBlizzard` hides Blizzard's `DamageMeter` frame, which holds every `DamageMeterSessionWindow<n>`. Switching the meter off, choosing the restyle or turning the module off gives it back with `Safe.RestoreBlizzard`.
- Click the title for the next meter type and right-click it for the current fight or overall. Both write the settings, so the choice is kept.
- **Restyle Blizzard's window.** `DamageSkin.lua` strips the header and background art of each session window with `Skin.Strip`, puts KstyleUI glass behind it with `Skin.Backdrop`, restyles its scroll bar with `Skin.ScrollBar`, and draws every row as `BarList` draws the own meter's: Blizzard's full-height fill and its shadow art are hushed, and a KstyleUI holder one level above the row's bar carries a 4-unit `Widgets.StatusBar` pill on the `buttonFill` track along the row's foot, with the additive `pill` glow around its fill, in the meter's texture, fill direction and colour source at full alpha (the glow at 0.35). The pill mirrors Blizzard's bar through hooks on its `SetMinMaxValues` and `SetValue`, so a secret value passes straight to the setters. Blizzard's name and value texts keep their places (the skin never anchors Blizzard's text) and take the meter's font in `textEmphasis`. The header reads as the own meter's cap in type: the type name in the tracked `caption` face in `giltLit`, the session name and the timer in the meter's font, `muted`; the dropdowns stay where Blizzard puts them, so they still open on click. Edit Mode keeps placing the window. Hooks: `DamageMeter.SetupSessionWindow` for windows opened later, each window's `Refresh` for its rows, and each row's `UpdateStatusBarColor`, so the colour source wins over Blizzard's colour.

## Threat meter

- The group is the player, the pet, and the party or raid members and their pets. The pets switch leaves pets out. In a raid the player and the player's pet appear once.
- The mob is the target when the player can attack it, or else the target's target, so a healer who targets the tank sees the tank's target.
- `UnitDetailedThreatSituation(unit, mob)` gives each row. Rows sort by the scaled percentage, highest first. The bar runs from 0 to 100% of pulling aggro. The value column shows threat points: Blizzard's raw threat divided by 100. Updates run at most once every 0.2 seconds.
- Warnings: a player who is not tanking is warned at `warnAt` and in danger at `dangerAt` of their own threat. A tank is warned when another member reaches those percentages. A warning turns the panel's hairline `neutral`; danger turns it `hostile` and pulses a `hostile` proc glow.

## Swing timer

- One bar per hand: main hand, off hand and ranged. A bar shows when its switch is on and the weapon is there (`UnitAttackSpeed` gives an off-hand or ranged speed), or while a swing runs.
- `PLAYER_SWING(duration, type)` starts a bar. One `OnUpdate` on a parentless driver frame fills the bars while a swing runs and stops when none does.
- With **Hide when idle** on, the bars show only in combat or while a swing runs.
- **Dim out of range** follows `PLAYER_SWING_RANGE_UPDATE` (after `C_SwingTimer.EnableRangeCheck`) and `C_SwingTimer.IsTargetWithinSwingRange` on target changes. As in Blizzard's timer, a running swing never dims, and no answer is not out of range.
- While the swing timer runs, `SwingTimerMainHandFrame`, `SwingTimerOffHandFrame` and `SwingTimerRangedFrame` are held at alpha 0: a `hooksecurefunc` on each frame's `SetAlpha` sets it back to 0. The hook records the alpha Blizzard asks for, so switching the swing timer or the module off restores it.

## Settings

The page has an accent section and one section per meter. Every meter has its text font (the interface font or any KstyleUI or LibSharedMedia font), text size and outline (a soft shadow, thin or thick). Bars have a texture, a colour source (class, reaction or a custom colour) and a direction: the damage and threat bars grow from the left or the right, and the swing bars are horizontal or vertical and may fill in reverse. The damage and threat meters set their row height, row spacing, title and title size. The damage meter adds its style, meter type, fight, a group-only switch and percentages. The threat meter adds a group-only switch, pets, the numbers to show and the warning thresholds. The swing timer adds a switch per hand, hide when idle, range dimming, bar spacing and the time.

## Logs

The module logs to the devlog, once each: a missing Blizzard frame or API and the path taken instead, a secret swing duration or type, secret threat values, Damage Meter data that is hidden, and the switch to the restyle.

## Why

- **A holder per element.** Layout shows, hides and fades the frame it places. The meters also show and hide their content (group only, hide when idle), so each draws on a child of the holder and the two never fight over one frame.
- **The window first, the restyle as a fallback.** Layout Mode never moves a Blizzard frame, so only KstyleUI's own window can sit at `meters.damage` and follow the setup's layouts. The window passes secret values straight to `SetMinMaxValues`, `SetValue`, `SetText` and `AbbreviateNumbers`, which take them, so it keeps working if the numbers turn secret in combat. If the game hides the session table itself (`canaccesstable` is false), the window cannot list anything, so at the end of that combat the meter switches to restyling Blizzard's window, whose secure code can still read the data, and says so once. A client without `C_DamageMeter` restyles from the start.
- **Restyling needs a reload to undo.** Hushed textures and hooks stay on Blizzard's frames, so leaving the restyle prints a `/reload` request and fires `ReloadNeeded`. The module is not marked `reskin`, because its default style changes no Blizzard frame.
- **Blizzard's swing timers are faded, not hidden.** They are bottom managed frames: `ManagedFrameContainerMixin:UpdateFrame` reparents them to its container on every layout pass, which would undo `Safe.HideBlizzard`, and Edit Mode sets their alpha from its opacity setting. Holding the alpha at 0 survives both. They take no mouse input, so an invisible timer blocks nothing.
- **No CVar changes.** Turning `showSwingTimer` off would hide Blizzard's timers too, but it changes the player's own setting and it is not known whether `PLAYER_SWING` still fires without it.
- **Secret swing durations.** `PLAYER_SWING` does not mark its duration secret. If it ever is, the bar is handed to the engine through a `C_DurationUtil` duration object and `SetTimerDuration`. `SetTimeFromStart` refuses secret arguments from addon code, so the call is guarded and a refusal is logged.
- **Threat is read every 0.2 seconds at most.** `UNIT_THREAT_LIST_UPDATE` fires for every mob in combat. A scheduled update with one prepared function keeps the cost flat and allocates no closure per event.
- **Threat points are raw threat divided by 100.** Blizzard's raw threat is a hundred times the threat points players compare. A secret raw value cannot be divided, so it is shown through `AbbreviateNumbers` as the game gives it.
- **Warnings only on readable values.** A warning compares percentages, which a secret value forbids, so a secret percentage or tanking flag never warns and a secret value leaves the group's order unsorted.
- **No tables in combat paths.** Setting reads cache each key's path, rows and their tables are reused, and a bar's colour changes only when it differs. `test-meters-logic.lua` measures the helpers with the garbage collector stopped.
- **Weak-keyed tables for Blizzard frames.** The restyle and the alpha hold keep their state about Blizzard's frames in the module's own weak-keyed tables, as `Safe.Side` does, because the restyle also walks every window and row it has touched when a setting changes. No field is written onto a Blizzard frame.
- **One event frame.** The core gives each module one event frame with one handler per event. The three parts share it through `ns.Watch` and `ns.Unwatch`, so an event is registered only while a part that is on needs it.
