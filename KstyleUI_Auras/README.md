# KstyleUI_Auras

The player's buffs and debuffs as plain icon rows beside the minimap.

| Field | Value |
| --- | --- |
| Module name | `Auras`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Auras.toc` lists `Auras.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Auras use the AuraContainer engine (`CustomAuraContainerTemplate`, aura groups and filter strings). Never scan auras by index while `C_Secrets.ShouldAurasBeSecret()` returns true. Aura data turns secret during a boss pull before `InCombatLockdown()` returns true.
- Blizzard frames this module replaces are hidden only through `KstyleUI.Safe.HideBlizzard`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.
- Never read state back from a region inside an engine aura button: visibility, text and size there are secrets on Forever. Keep the wanted state yourself.

## Files

`Auras.xml` loads the files in this order. Tests: `Tools/regression/test-auras-model.lua` (the pure model), `test-auras.lua` (the module against a fake AuraContainer engine in `Tools/regression/auras_env.lua`), `test-auras-rows.lua` (the rows' shape: bare tiles, the `+N` cell, the tracked-buff filter), `test-auras-counts.lua` (0, 2, 8, 24 and 40 buffs beside 12 debuffs at the owner's screen: nothing overlaps, the count reads right, in a pull too) and `test-auras-gamepad.lua` (the gamepad interface). The gallery scenes `Tools/render/scenes/gallery_auras.lua` and `gallery_auras_counts.lua` render the tiles and the five counts.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Model.lua` | Defaults, limits and dropdown choices; the pure maths that turn settings into engine options, element sizes, footprints and capacity; the preview's timer text |
| `Button.lua` | Dresses one engine aura button: the square icon in a one-pixel dark rim plate, the timer under it, a unit right of the icon's middle (the picture's ink stands 2 px right of the tabular figures' centre), in the picture's grey-white (`timerText`), the stack count on its badge, the square dispel plate, and the engine bindings; a plain frame gets the same tile without the bindings |
| `Tracked.lua` | The spells the Cooldown Manager's clean effective layout puts in its tracked-buff row, as an `excludeSpellIDs` set; an unreadable layout excludes nothing |
| `Panel.lua` | The two containers, their Layout elements, weapon enchantments, the `+N` cell, the restyle gate, Blizzard's frames and the gamepad interface switch |
| `Preview.lua` | The settings window's live preview, drawn with the module's own tiles |
| `Module.lua` | `Modules.Register`, the settings schema, the preview builder and the `/kstyle test` check |

## What it shows

Two rows, each a `CustomAuraContainerTemplate` container on the player and its own Layout element:

| Element key | Filter | Default place | Default shape |
| --- | --- | --- | --- |
| `auras.buffs` | `HELPFUL`, with the main-hand, off-hand and ranged weapon enchantments first | `TOPRIGHT`, 10.9 left of the minimap element, 1.4 units under the top screen margin (`screenMargin`, 17 units): the picture's 20 px and 32 px on its 2234 px screen | One row of up to 10 square icons of 27.5 units, 3.5 apart, the first aura at the left, the row ending at the element's right edge, a 12-unit timer under each: 306.5 by 41.5 units (27.5 for the icon and 14 for the timer: 2 of gap and the 12-unit line) |
| `auras.debuffs` | `HARMFUL` | `TOPRIGHT`, the same column, 8 under the buffs | the same: 307 by 42 units, its row ending at the same x as the buffs' |

**The picture wins over #209.** #209 shipped "two rows of eight 30-unit icons each, growing left then down". The owner's picture (2026-11-09) draws one row of ten 48 px icons (27.56 units) at a 54 px pitch (31) in listed order, first at the left, with white timers under them, and on 2026-11-09 he ruled "let the picture win its what i want" (LEE-20). So the defaults are now `rows` 1, `columns` 10, `iconSize` 27.5, `spacing` 3.5 and `growth` `RIGHT_DOWN`, the timer 12 units, and every one of them stays a setting (`rows` up to 8, `columns` up to 24): a player who wants two rows, or the row growing left, sets it. A profile that holds its own values keeps them. 27.5 and 3.5 are the picture's 48 px and 6 px on its 2234 px screen (LEE-69; 28 and 3 drew 49 px tiles); migration 16 clears a saved 28 and 3, so a profile left at the old defaults takes the new ones and a size the player chose stays.

The rows stand beside the minimap's left edge, as the owner asked (2026-11-09) and as Blizzard's and Leatrix's setups do. `Core/Setup/Layouts.lua` computes their place from the minimap element's width, so a different map keeps them beside it. The boss column and the spare bar columns stand lower on the screen's right side (#208), so the corner is free at every aspect.

Each tile is a square icon one border inside a one-pixel dark square plate (`black`), as the picture draws it: a plain texture on the tile, so there is no mask, no chamfer and no corner to round. A debuff's dispel plate is the same square under the icon, so the engine's colour shows as a one-pixel ring. No body, no bezel, no shadow. The tile's corners are the module's own; the "+N" cell is the kit's `IconChrome` socket, whose corners and rim the kit draws (it keeps the `edgeInner` and `hostile` accents). The timer sits under the icon in the `timerText` grey-white (#e3e7ec, every stroke of the picture's timers is that one colour) in the body face, 11 units (LEE-70: the picture's timer glyphs are 12 pixels tall and 23 wide on the owner's screen, which this face draws at 11; its soft dark halo is wider than the client's one-pixel shadow can draw), its box 3 units under the icon so the glyphs start 5.5 units below it (or on its lower edge), and the stack count on a dark corner badge at the top right. The engine fills in the icon, the timer, the stack count, the badge, the tooltip and the dispel colour, so secret aura data never reaches KstyleUI's Lua. The engine draws each aura's icon as a secret (`secretwrap`), so no addon code can swap it; the repainted icons reach the tiles anyway, because they ship as a loose-file pack the client loads for every icon ([`docs/icons.md`](../docs/icons.md)), in game and in the renders.

- **Text** goes through `Widgets.ApplyFont`, so the timer and count sizes and their one-pixel shadow land on whole physical pixels in the tile's scale (#210).
- **Timers** use the engine's duration text binding. `short` is the engine's default formatter (`24s`, `8m`, `2h`); `long` and `decimal` are `C_StringUtil` seconds formatters with two units, or tenths under 3 seconds. The timer is `timerText`; a step colour curve turns it `hostile` under the warning time.
- **Stack badge.** The badge is a `StatusBar` handed to the engine through `SetApplicationBar` with `minApplications = 2` (`Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua`, `ApplyApplicationBar`: `statusBar:SetShown(applications >= minApplications)`), so the engine shows the plate only when the count text it writes through `SetApplicationCount` is not empty. The count font string is the badge's child, so it hides with it. The bar's own texture is transparent; the plate is a black texture on it.
- **Debuff type** colours a square plate behind each debuff icon through `AddDispelTypeTexture` with the `PreserveAsset` style, so the engine applies Blizzard's dispel colour and hides it on buffs. A debuff with no type gets the "None" colour. The rim plate sits under it.
- **Right-click cancel** is `SetCancelAuraButtons("RightButtonUp")` on buffs and weapon enchantments. The engine's secure `OnClick` cancels the aura, so it works in combat.
- **Sorting** maps to `AuraContainerSortMethod`: time left (`ExpirationOnly`), name (`NameOnly`), order applied (`AuraInstanceIDOnly`), Blizzard's (`Default`) or priority (`UnitFrameDebuff`: boss debuffs, then important ones, then yours first, as Blizzard's unit frames order them), each normal or reversed. Debuffs sort by priority by default.
- **Weapon enchantments** share the buff rows. An active enchantment takes one buff's place (`WEAPON_ENCHANT_CHANGED`, `WEAPON_SLOT_CHANGED`), so the rows never grow past their cap.
- **Many auras.** The rows are the cap: one row of ten buffs and one row of ten debuffs by default (`rows` up to 8, `columns` up to 24). The engine shows the first `rows x columns` of each group by the sort, and the rest read as `+N` on the last cell (the bottom right for a row listed left to right: the engine's flow runs from the container's top left, and the container hangs from the element's right edge): a counting container on `Core/Widgets/Overflow.lua` (`Overflow.New` in `Panel.lua`, one 1-unit element per aura, the labels hung from its foot) that the engine lays out from secure code, so no Lua reads the number and it stays true in a pull. The cell covers the last tile and its timer lane, and reads the covered aura in its count: 24 buffs over 10 cells read `+15`, and 12 debuffs read `+3`.
- **Tracked buffs.** `Tracked.lua` reads the effective layout through `CooldownViewerSettings:GetDataProvider()` only when `IsDirty` is false. `GetDisplayData` contains the player's category overrides, unlike the API's default category set (`Blizzard_CooldownViewer/CooldownViewerSettingsDataProvider.lua`). Base, override and linked spell IDs become the row and count containers' `candidateFilters.excludeSpellIDs`; `AuraContainerUtil.DoesAuraPassCandidateFilters` applies these inside the secure engine. A dirty or unavailable layout, unknown visibility, or a disabled viewer excludes nothing, so uncertainty can duplicate a buff but cannot remove its only display. Data, spell, CVar, `CooldownViewerSettings.OnDataChanged` and `EditMode.Exit` notifications rebuild the filter. **Buffs the Cooldown Manager tracks: Here as well** always keeps every buff. Secret IDs are skipped, never used as table keys.
- **Blizzard's `BuffFrame` and `DebuffFrame`** are hidden through `Safe.HideBlizzard` while the row that replaces each one is built, and come back through `Safe.RestoreBlizzard` when the module turns off, the player turns **Hide Blizzard's buff frames** off, or the gamepad interface is on.
- **Gamepad interface.** While `InputUtil.IsGamepadUIEnabled()` is true, Blizzard's `BuffFrame` and `DebuffFrame` stay on screen and KstyleUI's two rows hide, so the player sees one set of buffs. `INPUT_DEVICE_INTERFACE_TRANSITION` swaps them back and forth through `KstyleUI.Combat.Queue`, so a switch in combat lands when combat ends.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `hideBlizzard` | `true` | toggle |
| `buffs.iconSize`, `debuffs.iconSize` | 27.5 | slider, 16 to 64 |
| `buffs.spacing`, `buffs.rowSpacing` (and debuffs) | 3.5, 4 | slider, 0 to 24 |
| `buffs.rows`, `debuffs.rows` | 1, 1 | slider, 1 to 8: the cap; the rest count as `+N` on the last cell |
| `buffs.columns`, `debuffs.columns` | 10 | slider, 1 to 24 |
| `buffs.growth`, `debuffs.growth` | `RIGHT_DOWN` | dropdown: right (the first aura at the left) or left (the first at the right), then down or up. The flow starts at the container's corner for that growth; the container always hangs from the element's right edge (top for down, bottom for up), so a short row ends where a full one does |
| `buffs.sort`, `debuffs.sort` | `time`, `priority` | dropdown: time, name, applied, blizzard, priority |
| `buffs.reverse`, `debuffs.reverse` | `false` | toggle |
| `buffs.tracked` | `cdm` | dropdown: Cooldown Manager only, or here as well |
| `buffs.enchants` | `true` | toggle: weapon enchantments |
| `buffs.cancel` | `true` | toggle: right-click cancels |
| `debuffs.dispel` | `true` | toggle: colour by debuff type |
| `timer.format` | `short` | dropdown: short, long, decimal, none |
| `timer.position` | `below` | dropdown: under the icon, on the icon |
| `timer.font`, `count.font` | the `body` face, the `number` face | font |
| `timer.size`, `count.size` | 11, 10 | slider, 6 to 24, times the Appearance text size |
| `timer.outline`, `count.outline` | `NONE` (a soft shadow) | dropdown: soft shadow, thin, thick |
| `timer.expiring` | 5 | slider, 0 to 30 seconds; 0 is off |
| `accent.source`, `accent.color` | `class`, the kit accent | dropdown and colour: kept for a custom rim |

`Model.Group`, `Model.Timer` and `Model.Count` read these through limits and choice lists, so a damaged or hand-edited profile falls back to the defaults. Shown, position, scale, opacity and strata come from Layout's element rows. The saved-data migration 8 in `Core/Store.lua` drops the retired `card` section, the one buff row the Lumen setup wrote for the card and the retired `debuffs.dispelFirst` switch.

## Why

- **The engine owns aura data.** Aura data turns secret during a boss pull before `InCombatLockdown()` does. `CustomAuraContainerTemplate` reads auras in Blizzard's secure environment and drives the widgets KstyleUI hands it, so the module never calls `C_UnitAuras` and never compares an aura value. It also renders private auras, which Blizzard's `DebuffFrame` shows and a hand-made panel could not.
- **Aura buttons are touched only when the gate is open.** The engine restricts each aura button from tainted code while `C_Secrets.ShouldAurasBeSecret()` is true (`DenyTaintedAccessWhenAurasAreSecret`). Styling happens in `initializeFrame`, before the restriction applies. Any later restyle (a setting, the accent, the scale) runs only out of combat while aura data is not secret; otherwise it waits for `ADDON_RESTRICTION_STATE_CHANGED` or `PLAYER_REGEN_ENABLED`, and the wait is logged. Container-level changes (layout, sort, capacity, filters) apply at once: the container has no access restriction.
- **The art lives on a child frame.** Display elements must be descendants of the aura button, and the button forbids untrusted scripts and reparenting. Every KstyleUI region sits on one plain child frame (`skin`) or the badge bar on it, and none of them needs a script.
- **Layout places a holder, not the container.** The container resizes itself, and Layout's mouseover rule hooks `OnEnter` on an element's children four levels deep, which would reach aura buttons. So Layout places an empty `holder` sized to the full footprint, and the container lives on a sibling `host` that covers the holder and mirrors its scale, alpha, strata and visibility through `hooksecurefunc`. The host sits two levels above the holder, so the aura buttons keep the mouse for tooltips and cancelling. The host carries Blizzard's `DisableUntrustedLayoutScriptsTemplate` (`Blizzard_SharedXMLBase/ForbiddenAspectTemplates.xml`), which the engine requires of any frame its containers anchor to; without it the module falls back to a plain frame and logs once.
- **Sizes are elements, not frames.** The flow layout reads `elementWidth` and `elementHeight` from the group layout, so the container lays out correctly even while a button restyle waits behind the gate. Columns become the maximum line size, rows become `maxFrameCount`, and both are snapped to whole pixels in the host's scale.
- **The gamepad needs Blizzard's frames.** Forever's gamepad **View buffs** shortcut (`Blizzard_GamepadActionBars`, `ShortcutsActionBar.lua`) and radial segment (`Blizzard_Gamepad`, `GamepadRadial.lua`) call `BuffFrame:SetGamepadFocus()` and then `DebuffFrame:SetGamepadFocus()`. That check passes on a frame under `Safe`'s hidden parent, because `IsShown()` stays true, so the controller would walk invisible aura buttons. The module reads the style from `InputUtil.IsGamepadUIEnabled`, then `C_InputInterfaceStyle.GetCurrentStyle`; if neither answers, or the answer is secret, it takes the keyboard and mouse path and logs it once.
- **Fallbacks.** Without the AuraContainer engine, or if it refuses a group, that row is not built, Blizzard's frame stays, and the devlog and `/kstyle test` say so. Missing formatters, colour curves, the dispel style enum, `SetApplicationBar` or the Cooldown Manager API fall back to the engine's defaults, a hidden badge or an unfiltered row, with one devlog line each.
