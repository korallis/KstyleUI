# KstyleUI_Cooldowns

Blizzard's Cooldown Manager shown in KstyleUI's style: essential cooldowns (44 units), utility cooldowns (38 units, the action button's size), tracked buff icons (30 units) and tracked buff bars (195 by 20 units), placed in the HUD band as the composition mockup lays them out, at the owner's in-game scale of 2026-11-08 (one notch up from the 38-unit action button for the essentials, the button itself for the utilities).

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
| `Data.lua` | The entries each group shows, read from `C_CooldownViewer` and the player's Blizzard layout |
| `Settings.lua` | The defaults, the settings page and clean reads of the saved values |
| `Style.lua` | Fonts, the accent (through `IconButton:SetAccent` and `Glow:SetColorRGB`), glows, tooltips, and `Style.Countdown(cooldown)`: one `C_StringUtil` seconds formatter (one letter, whitespace stripped, the last unit rounded up: `4s`, `2m`) set on a cooldown row's `Cooldown` through `SetCountdownFormatter`, so the numbers read as the mockup's; without the API the engine's plain numbers stay, and the devlog says so |
| `Row.lua` | A holder of `Widgets.IconButton` icons placed on the grid. The essential and utility rows centre the countdown on the icon, as the Lumen sockets do (`Style.Decorate(icon, true)`); the tracked buff icons keep the kit's countdown, centred low |
| `Bars.lua` | A holder of tracked buff bars: a glass tile with the icon on a dark button tile, the name, a subtle `Widgets.StatusBar` fill and a right-aligned countdown that reads "24s" through `Style.Countdown` |
| `Viewers.lua` | Blizzard's four viewers: faded while KstyleUI mirrors them, watched while they are restyled |
| `Auras.lua` | Finds the aura a tracked buff follows and reads its duration object and stack text, never secret data |
| `Path.lua` | Which path each group takes: the mirror, the reskin or off |
| `Reskin.lua` | The fallback: Blizzard's items restyled in place with `KstyleUI.Skin`. An icon item's backdrop is the shared icon chrome (`Skin.Backdrop` with `icon = true`, a `Widgets.IconChrome`) resting on `SetRimAccent` with the module's accent, the same rim every KstyleUI icon button wears. The item's icon texture is kept as Blizzard draws it; the icon pack replaces the file the client loads for it |
| `Mirror.lua` | Runs each group on its path: events, refreshes, Layout registration and the switch to the reskin |
| `Preview.lua` | The settings window's live preview. An icon row wider than the preview pane shows as many columns as fit, so the 376-unit essential row is not clipped; the setting itself keeps its columns. Sample buffs drive their Cooldown frame directly, as the live buff mirror does, so their timers never dim them as a real cooldown would |
| `Module.lua` | `Modules.Register`, `Options.Register` and the `/kstyle test` check |

Tests: `Tools/regression/test-cooldowns-overflow.lua` (many tracked buffs and bars stay in their footprints with their chips), `test-cooldowns-grid.lua`, `test-cooldowns-data.lua`, `test-cooldowns-mirror.lua`, `test-cooldowns-auras.lua`, `test-cooldowns-path.lua`, `test-cooldowns-reskin.lua` and `test-cooldowns-settings.lua`, on the fake Cooldown Manager in `Tools/regression/cooldowns_env.lua`.

## Elements

| Key | Element | Default | Layout |
| --- | --- | --- | --- |
| `cooldowns.essential` | Essential cooldowns | 6 icons of 44 units with 6-unit gaps, 294 by 44, between the player and target frames | Scalable |
| `cooldowns.utility` | Utility cooldowns | 4 icons of 38 units with 6-unit gaps, 170 by 38, under the essential row | Scalable |
| `cooldowns.buffs` | Tracked buff icons | 6 icons of 30 units, 195 by 30, under the target frame | Scalable |
| `cooldowns.bars` | Tracked buff bars | 2 bars of 195 by 20 with a 3-unit gap, 195 by 43, under the player frame, right-aligned with it | Scalable |

A tracked buff bar follows the composition mockup: a glass tile (`surface`) 195 by 20 units, the mockup's width at 1.348 px per unit and its 24-unit height at the owner's in-game scale (the pet frame moved beside the player frame to free the row; the bars sit 10 units higher than the mockup's so they clear the chat panel on the owner's 1671-unit-wide root), with the tile's neutral edge, the icon on a dark button tile (`buttonFill`) at its left end, the name 10 units right of the icon tile, the countdown right-aligned 10 units from the bar's right end, and the fill, the bar colour at 15 % alpha over the glass, so the text stays readable whatever the time left. `Settings.BarColor()` returns that alpha with the colour, so the reskin fills Blizzard's bars the same way.

A group registers with Layout the first time it takes the mirror path, so a group that only ever restyles Blizzard's viewer adds no mover plate. Each holder is sized to its grid (icons per row by rows, or the bar count), so its footprint does not change with the number of entries. Layout owns the holder; the module shows and hides a child, so the two never fight over one frame. Icon size, bar size, spacing and the grid are module settings rather than Layout sizes, because they decide how many entries fit.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `path` | `"auto"` | Automatic, KstyleUI icons (the mirror) or Blizzard's restyled |
| `accent`, `accentColor` | `"class"`, the kit accent | Class colour or a custom colour for glows and hairlines |
| `tooltips` | `true` | A spell's tooltip under the pointer; off lets the pointer through |
| `timerFont`, `timerOutline` | `"kit"`, `"none"` | The countdown numbers' font, and a soft shadow or an outline |
| `countFont`, `countOutline` | `"kit"`, `"none"` | The charge and stack counts' font and outline |
| `nameFont`, `nameOutline` | `"kit"`, `"none"` | The buff bars' name font and outline |
| `<icons>.size` | 44 for essential, 38 for utility, 30 for tracked buffs | Icon size, 16 to 64 |
| `<icons>.spacing` | 6 for essential and utility, 3 for tracked buffs | Gap between icons, 0 to 12 |
| `<icons>.columns`, `<icons>.rows` | 6 (utility 4), 1 | Icons per row and rows; icons past the grid are not shown, and on the tracked buff row the last socket reads `+N` for them (an opaque chip, the covered buff counted) |
| `<icons>.growth` | `"center"` | Where a short row starts: centred, left to right, right to left |
| `<icons>.wrap` | `"down"`, `"up"` for buffs | Extra rows below or above the first |
| `<icons>.timer`, `<icons>.timerSize`, `<icons>.countSize` | on; 15, 13 or 12; 12, 11 or 10 | The countdown numbers and the count: the action bars' 13-unit cooldown numbers on the 38-unit utility icons, scaled up on the essentials |
| `<cooldowns>.gcd` | `false` | Sweep every icon during the global cooldown |
| `<cooldowns>.desaturate` | `false` | Grey an icon while its spell is on a real cooldown. Off by default: the composition mockup keeps a cooling icon in colour under its swipe |
| `<cooldowns>.usable` | `true` | Dim an icon while its spell cannot be cast |
| `<cooldowns>.readyGlow` | on for essential, off for utility | A soft accent glow around a ready spell |
| `<cooldowns>.procGlow` | `true` | The proc pulse while the game highlights the spell, with the rim and the glow in the `gilt` token (`Style.TOKENS`, `neutral` until S1's gilt lands) whatever the accent: gold only on the active state |
| `buffs.inactive`, `bars.inactive` | `false` | Keep a tracked buff, dimmed, while it is not active |
| `bars.width`, `bars.height`, `bars.spacing`, `bars.count` | 195, 20, 3, 2 | Bar size, gap and how many fit; the mockup draws two bars, and a third would reach the experience bar. With more active, the last bar's slot reads `+N more` |
| `bars.growth` | `"down"` | New bars stack downward, the first bar at the top as the composition mockup lists them, or upward |
| `bars.texture` | the kit's Glass texture | The fill texture, from the texture picker |
| `bars.colorSource`, `bars.color` | `"class"` | Class colour, the friendly reaction colour, or a custom colour |
| `bars.orientation`, `bars.reverse` | horizontal, off | Fill direction |
| `bars.icon`, `bars.name`, `bars.timer` | on | The parts each bar shows |
| `bars.nameSize`, `bars.timerSize`, `bars.countSize` | 11, 11, 9 | Text sizes |

`<icons>` is `essential`, `utility` or `buffs`; `<cooldowns>` is `essential` or `utility`. `Settings.Read()` cleans every saved value: numbers clamp to their slider and round to its step, unknown choices and a font path `Theme.IsFontPath` refuses fall back to the default, a texture path that is empty, too long or holds a `|` or control character falls back to the default, and a colour channel outside 0 to 1 gives the default colour. Text sizes are multiplied by the Appearance page's text size. Changing `path` restarts the groups at once.

## Paths

`Path.Choose(group, setting)` picks one path per group when the module starts, and logs it:

| Setting | Essential and utility | Tracked buff icons and bars |
| --- | --- | --- |
| Automatic | The mirror when its APIs exist, else the reskin | The reskin while `C_Secrets.ShouldAurasBeSecret` exists, else the mirror when its APIs exist |
| KstyleUI icons | The mirror when its APIs exist, else the reskin | The same |
| Restyle Blizzard's | The reskin | The reskin |

The cooldown mirror needs `C_CooldownViewer` with its category functions, `Enum.CooldownViewerCategory` and `C_Spell.GetSpellCooldownDuration`. The buff mirror also needs `C_UnitAuras.GetPlayerAuraBySpellID` and `GetAuraDuration`. A group whose Blizzard viewer is missing too is `off`.

If a mirror call raises an error, in combat or out, or a category set cannot be read, the group switches to the reskin at once for the session: the KstyleUI row hides, Blizzard's viewer gets its alpha and mouse back and is restyled, and the devlog records the error. Nothing on either path is protected, so the switch is safe in combat. `/kstyle test` reports each group's path and entry count as the `cooldowns` check.

## How the mirror works

1. `Data.Collect` lists a group's entries. When Blizzard's settings provider has clean display data, it follows the player's own Cooldown Manager layout: its order and the categories the player moved cooldowns into. Otherwise it uses `GetCooldownViewerCategorySet(category, false)` minus the cooldowns Blizzard hides by default. A provider that is dirty is never read: a group that already follows the player's layout keeps it, a group that has nothing yet shows the defaults, and either retries once a second, up to ten times, until the data is clean.
2. Each icon shows the spell's file ID through `SetTexture`; the icon pack replaces the file the client loads for it. A cooldown icon's sweep is `C_Spell.GetSpellCooldownDuration(spell, ignoreGCD)` passed to `Cooldown:SetCooldownFromDurationObject`. A charge spell shows its charge count (secret or not, through `SetText`) and its recharge through `IconButton:SetChargeCooldownFromDuration` with `GetSpellChargeDuration`.
3. `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `SPELL_UPDATE_USABLE`, `SPELL_UPDATE_ICON`, the spell-activation glow events and `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` refresh the cooldown icons. `SPELLS_CHANGED`, `PLAYER_ENTERING_WORLD`, the Cooldown Manager's data events and EventRegistry's `CooldownViewerSettings.OnDataChanged` rebuild the lists on the next frame.
4. A spell is on a real cooldown when `C_Spell.GetSpellCooldown` says `isActive` and not `isOnGCD`, both fields Blizzard marks as never secret. The ready glow and the grey icon follow that, checked again when the Cooldown widget finishes.
5. A tracked buff follows the first aura found for its spell, its base spell or its linked spells. The player comes first, through `GetPlayerAuraBySpellID` for each of those spells, then a debuff the player put on the target, through `GetAuraDataBySpellName("target", name, "HARMFUL|PLAYER")`, as Blizzard's viewer scans the player before the target. A secret aura record or instance ID counts as not found. The icon sweeps backward and the bar drains (`SetTimerDuration` with `RemainingTime`) from `GetAuraDuration`, with a countdown from the same duration object and the stack text from `GetAuraApplicationDisplayCount`. While `C_Secrets.ShouldAurasBeSecret()` is true nothing is read and the last state stays; the duration objects keep counting down by themselves.
6. Aura refreshes run at most once a frame: `UNIT_AURA`, `PLAYER_TARGET_CHANGED`, `SPELL_UPDATE_ICON` and the override event queue one refresh with `C_Timer.After(0)`. A `UNIT_AURA` update queues it only when it is a full update, adds an aura whose `spellId` a tracked buff follows (its spell, base spell or a linked spell), or removes or updates an aura instance a tracked buff shows. An update that cannot be read, or one that arrives while aura data is secret, counts as touching a tracked buff, and the first update after aura data turns readable refreshes in full. `UNIT_AURA` listens to the target, and a target change refreshes, only while some tracked buff is not on the player or a refresh is owed, because a buff found on the player cannot change with the target.
7. Blizzard's viewers are faded to alpha 0, never hidden or moved, and their items stop taking the mouse, so their tooltips do not open over an invisible spot.

## How the reskin works

`Reskin.Start(group)` restyles every item of the group's Blizzard viewer and every item the viewer acquires later, through a `hooksecurefunc` on the viewer's `OnAcquireItemFrame`. Settings and theme changes restyle them again.

- Icon items: `Skin.Strip` hushes Blizzard's icon overlay and keeps the icon and the out-of-range shade; the icon is cropped; `Skin.Backdrop` puts the action buttons' dark body (`buttonFill`) two units outside the icon, with their rim: the accent lifted 15 % toward white, and a faint halo outside it; the countdown, charge and stack texts take the module's fonts, sizes and outlines.
- Bar items: the bar's background and pip are hushed, the fill takes the bar texture and colour settings at the bars' fill alpha, the bar gets a glass tile and its icon a dark button tile, and the name and duration texts take the module's fonts. Blizzard's template places the name and the duration, so the restyled bar keeps its text positions.
- Blizzard's Edit Mode keeps the viewers' positions, sizes, padding, visibility and timer switches. Move them with Edit Mode; Layout Mode moves only KstyleUI's own frames.
- Blizzard's viewer lays out every tracked buff itself, wrapping at Edit Mode's icon limit, so the `+N` chips are the mirror's: on this path the overflow is Edit Mode's to bound.
- When Blizzard's Cooldown Manager is switched off (`cooldownViewerEnabled`), the restyled viewers show nothing, so the module prints one line saying where to turn it on.

## Why

- **Tracked buffs restyle Blizzard's viewer by default.** Aura data turns secret during boss encounters, before `InCombatLockdown()` is true, and the aura lookups the mirror needs return nothing for a secret aura. Blizzard's own viewer runs untainted and keeps working, so on a client with `C_Secrets.ShouldAurasBeSecret` the automatic path restyles it rather than show buffs that vanish mid-fight. The mirror stays one setting away for testing.
- **Mirror first.** KstyleUI's own icons can sit anywhere Layout puts them, take the kit's look, and resize from the settings window. Blizzard's viewers are laid out by Edit Mode and the managed-frame container, which KstyleUI never moves.
- **Duration objects only.** Cooldown start times and durations can be secret in combat. `Cooldown:SetCooldown` refuses secret arguments from addon code, while a duration object carries them to the engine untouched, so the module never reads a cooldown's numbers. The one plain fact it reads is `isActive` and `isOnGCD` from `GetSpellCooldown`, which Blizzard marks as never secret.
- **Fade, do not hide.** The viewers inherit `BottomManagedFrameTemplate`. Blizzard's managed-frame container reparents a viewer that is in its default position whenever it lays it out, and calls `SetAlpha` on it, so reparenting through `Safe.HideBlizzard` would be undone. The module fades each viewer with alpha 0 and hooks its `SetAlpha` with `hooksecurefunc`, as the spec allows where Blizzard code lays a frame out. The hook and the faded state live in `Safe.Side`; no field is written on a Blizzard frame.
- **Never rebuild Blizzard's data.** `GetOrderedCooldownIDsForCategory` rebuilds the provider's display data when it is dirty. Run from addon code, that rebuild would taint the provider and every viewer that reads it, so the module reads the clean data directly and treats a dirty provider as unavailable.
- **The viewers keep running.** A faded viewer still refreshes, so Blizzard keeps its provider clean and the player's own layout reaches the mirror. The cost is Blizzard's, the same as without KstyleUI.
- **Potions and healthstones.** These entries have a spell category instead of a spell. They show the category's icon (the same file paths Blizzard's viewer uses) and the cooldown of the spell `C_Spell.GetLastCategoryCooldownSource` names, passed on untouched even when it is secret.
- **Equipped items show their icon only.** No API gives a duration object for an item cooldown, and `GetInventoryItemCooldown` can return secrets, so a trinket the player moves into a row shows its icon without a sweep.
- **Reskin only with the Skin helpers.** They hook, hush textures with alpha and draw on KstyleUI's own child frames, so no field is written on a Blizzard frame and nothing on a Blizzard frame is hidden, moved or scripted. The only calls on Blizzard objects are cosmetic setters (`SetTexCoord`, `SetFont`, `SetTextColor`, `SetStatusBarTexture`, `SetStatusBarColor`) on regions Blizzard's code sets once, in its XML.
- **Reload to turn off.** The module fades Blizzard's frames in place, so it is a `reskin` module: turning it off restores the alpha and asks for a reload, as every module that changes Blizzard frames does.
