# KstyleUI_Cooldowns

Blizzard's Cooldown Manager shown in KstyleUI's style: essential cooldowns (40 units), utility cooldowns (30 units), tracked buff icons and tracked buff bars (180 by 18 units), placed in the HUD band.

| Field | Value |
| --- | --- |
| Module name | `Cooldowns`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Mirror, or reskin in place if mirroring cannot work in combat |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Cooldowns.toc` lists `Cooldowns.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Essential cooldowns sit centred above the action bars, utility cooldowns beneath them, and tracked buff bars beside them.
- Build the mirror from `C_CooldownViewer` data and duration objects, check each value with `issecretvalue`, and fall back to restyling Blizzard's viewers in place when the data is unavailable in combat. Log the path taken.
- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Cooldowns.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Cooldowns.xml` loads these in order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table, the devlog helpers and the secret checks the other files share |
| `Grid.lua` | Pure maths: where each icon or bar sits by cell size, spacing, columns, rows, growth and wrap |
| `Data.lua` | The cooldowns each group shows, read from `C_CooldownViewer` and the player's Blizzard layout |
| `Settings.lua` | The defaults, the settings page and clean reads of the saved values |
| `Style.lua` | Fonts, the accent (through `IconButton:SetAccent` and `Glow:SetColorRGB`), glows and tooltips shared by every icon |
| `Row.lua` | A holder of `Widgets.IconButton` icons placed on the grid |
| `Viewers.lua` | Blizzard's four viewers: faded while KstyleUI mirrors them, given back on Disable |
| `Path.lua` | Which path each group takes, and the switch away from a mirror that fails |
| `Mirror.lua` | The essential and utility rows: events, refreshes and Layout registration |
| `Preview.lua` | The settings window's live preview |
| `Module.lua` | `Modules.Register`, `Options.Register` and the `/kstyle test` check |

Tests: `Tools/regression/test-cooldowns-grid.lua`, `test-cooldowns-data.lua`, `test-cooldowns-mirror.lua` and `test-cooldowns-settings.lua`, on the fake Cooldown Manager in `Tools/regression/cooldowns_env.lua`.

## Elements

| Key | Element | Default | Layout |
| --- | --- | --- | --- |
| `cooldowns.essential` | Essential cooldowns | 6 icons of 40 units with 3-unit gaps, 255 by 40, above the action bars | Scalable |
| `cooldowns.utility` | Utility cooldowns | 6 icons of 30 units, 195 by 30, under the essential row | Scalable |

Each row is a holder sized to its grid (icons per row by rows), so its footprint does not change with the number of cooldowns. Layout owns the holder; the module shows and hides a child, so the two never fight over one frame. The icon size, spacing and grid are module settings rather than Layout sizes, because they decide how many icons fit.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `accent`, `accentColor` | `"class"`, the kit accent | Class colour or a custom colour for glows and icon hairlines |
| `tooltips` | `true` | A spell's tooltip under the pointer; off lets the pointer through |
| `timerFont`, `timerOutline` | `"kit"`, `"none"` | The cooldown numbers' font, and a soft shadow or an outline |
| `countFont`, `countOutline` | `"kit"`, `"none"` | The charge count's font and outline |
| `<group>.size` | 40 or 30 | Icon size, 16 to 64 |
| `<group>.spacing` | 3 | Gap between icons, 0 to 12 |
| `<group>.columns`, `<group>.rows` | 6, 1 | Icons per row and rows; icons past the grid are not shown |
| `<group>.growth` | `"center"` | Where a short row starts: centred, left to right, right to left |
| `<group>.wrap` | `"down"` | Extra rows below or above the first |
| `<group>.timer`, `<group>.timerSize`, `<group>.countSize` | on, 16 or 12, 12 or 10 | The cooldown numbers and the charge count |
| `<group>.gcd` | `false` | Sweep every icon during the global cooldown |
| `<group>.desaturate` | `true` | Grey an icon while its spell is on a real cooldown |
| `<group>.usable` | `true` | Dim an icon while its spell cannot be cast |
| `<group>.readyGlow` | on for essential, off for utility | A soft accent glow around a ready spell |
| `<group>.procGlow` | `true` | The proc pulse while the game highlights the spell |

`<group>` is `essential` or `utility`. `Settings.Read()` cleans every saved value: numbers clamp to their slider and round to its step, unknown choices and a font path `Theme.IsFontPath` refuses fall back to the default, and a colour channel outside 0 to 1 gives the default colour. Text sizes are multiplied by the Appearance page's text size.

## How the mirror works

1. `Enable` reads the settings and asks `Path` which path each row takes. The mirror needs `C_CooldownViewer` with its category functions, `Enum.CooldownViewerCategory` and `C_Spell.GetSpellCooldownDuration`. Without them the row is `off`, Blizzard's viewer is left alone, and the devlog says why.
2. `Data.Collect` lists the row's cooldowns. When Blizzard's settings provider has clean display data, it follows the player's own Cooldown Manager layout: its order and the categories the player moved cooldowns into. Otherwise it uses `GetCooldownViewerCategorySet(category, false)` minus the cooldowns Blizzard hides by default. A provider that is dirty is never read: a row that already follows the player's layout keeps it, a row that has nothing yet shows the defaults, and either retries once a second, up to ten times, until the data is clean. A category set that cannot be read (an error or a secret table) fails the row's mirror instead of showing an empty row.
3. Each icon shows the spell's file ID through `KstyleUI.Icons.Apply`, so custom icon sets apply. Its cooldown is `C_Spell.GetSpellCooldownDuration(spell, ignoreGCD)` passed to `Cooldown:SetCooldownFromDurationObject`. A charge spell shows its charge count (secret or not, through `SetText`) and its recharge through `IconButton:SetChargeCooldownFromDuration` with `GetSpellChargeDuration`.
4. `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `SPELL_UPDATE_USABLE`, `SPELL_UPDATE_ICON`, the spell-activation glow events and `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` refresh the icons. `SPELLS_CHANGED`, `PLAYER_ENTERING_WORLD`, the Cooldown Manager's data events and EventRegistry's `CooldownViewerSettings.OnDataChanged` rebuild the lists on the next frame.
5. A spell is on a real cooldown when `C_Spell.GetSpellCooldown` says `isActive` and not `isOnGCD`, both fields Blizzard marks as never secret. The ready glow and the grey icon follow that, checked again when the Cooldown widget finishes.
6. Blizzard's viewers are faded to alpha 0, never hidden or moved, and their items stop taking the mouse, so their tooltips do not open over an invisible spot.

If `GetSpellCooldownDuration` or `SetCooldownFromDurationObject` raises an error, in combat or out, the row's mirror fails for the session: the row hides, Blizzard's viewer gets its alpha and mouse back, and the devlog records the error. `/kstyle test` reports each row's path and icon count as the `cooldowns` check.

## Why

- **Mirror first.** KstyleUI's own icons can sit anywhere Layout puts them, take the kit's look and custom icons, and resize from the settings window. Blizzard's viewers are laid out by Edit Mode and the managed-frame container, which KstyleUI never moves.
- **Duration objects only.** Cooldown start times and durations can be secret in combat. `Cooldown:SetCooldown` refuses secret arguments from addon code, while a duration object carries them to the engine untouched, so the module never reads a cooldown's numbers. The one plain fact it reads is `isActive` and `isOnGCD` from `GetSpellCooldown`, which Blizzard marks as never secret.
- **Fade, do not hide.** The viewers inherit `BottomManagedFrameTemplate`. Blizzard's managed-frame container reparents a viewer that is in its default position whenever it lays it out, and calls `SetAlpha` on it, so reparenting through `Safe.HideBlizzard` would be undone. The module fades each viewer with alpha 0 and hooks its `SetAlpha` with `hooksecurefunc`, as the spec allows where Blizzard code lays a frame out. The hook and the faded state live in `Safe.Side`; no field is written on a Blizzard frame.
- **Never rebuild Blizzard's data.** `GetOrderedCooldownIDsForCategory` rebuilds the provider's display data when it is dirty. Run from addon code, that rebuild would taint the provider and every viewer that reads it, so the module reads the clean data directly and treats a dirty provider as unavailable.
- **The viewers keep running.** A faded viewer still refreshes, so Blizzard keeps its provider clean and the player's own layout reaches the mirror. The cost is Blizzard's, the same as without KstyleUI.
- **Potions and healthstones.** These entries have a spell category instead of a spell. They show the category's icon (the same file paths Blizzard's viewer uses) and the cooldown of the spell `C_Spell.GetLastCategoryCooldownSource` names, passed on untouched even when it is secret.
- **Equipped items show their icon only.** No API gives a duration object for an item cooldown, and `GetInventoryItemCooldown` can return secrets, so a trinket the player moves into a row shows its icon without a sweep.
- **Reload to turn off.** The module fades Blizzard's frames in place, so it is a `reskin` module: turning it off restores the alpha and asks for a reload, as every module that changes Blizzard frames does.
