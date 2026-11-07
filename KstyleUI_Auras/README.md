# KstyleUI_Auras

The player's buff and debuff panel under the minimap.

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
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Auras.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Auras.xml` loads the files in this order. Tests: `Tools/regression/test-auras-model.lua` (the pure model), `test-auras.lua` (the module against a fake AuraContainer engine in `Tools/regression/auras_env.lua`) and `test-auras-gamepad.lua` (the gamepad interface).

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Model.lua` | Defaults, limits and dropdown choices; the pure maths that turn settings into engine options, element sizes, footprints and capacity; the preview's timer text |
| `Button.lua` | Dresses one engine aura button: a kit chamfered tile, the masked icon, the timer and stack texts, the nine-piece dispel border, and the engine bindings |
| `Panel.lua` | The two containers, their Layout elements, weapon enchantments, the restyle gate, Blizzard's frames and the gamepad interface switch |
| `Preview.lua` | The settings window's live preview, drawn with `Widgets.IconButton` |
| `Module.lua` | `Modules.Register`, the settings schema, the preview builder and the `/kstyle test` check |

## What it shows

Two panels, each a `CustomAuraContainerTemplate` container on the player:

| Element key | Filter | Default place | Default shape |
| --- | --- | --- | --- |
| `auras.buffs` | `HELPFUL`, with the main-hand, off-hand and ranged weapon enchantments first | `TOPRIGHT`, -16, -222, under the minimap | 2 rows of 12 icons of 28 units, 6-unit gaps, growing left, then down: 402 by 76 units |
| `auras.debuffs` | `HARMFUL` | `TOPRIGHT`, -16, -306, under the buffs | 1 row of 12: 402 by 38 units |

Each icon is the kit's chamfered tile with the icon masked inside it. The timer sits under the icon (or on its lower edge) and the stack count on its lower right corner. The engine fills in the icon, the timer, the stack count, the tooltip and the dispel colour, so secret aura data never reaches KstyleUI's Lua.

- **Timers** use the engine's duration text binding. `short` is the engine's default formatter (`24s`, `8m`, `2h`); `long` and `decimal` are `C_StringUtil` seconds formatters with two units, or tenths under 3 seconds. A step colour curve turns the timer `hostile` under the warning time.
- **Debuff type** colours a chamfered underlay behind each debuff icon through `AddDispelTypeTexture` with the `PreserveAsset` style, so the engine applies Blizzard's dispel colour and hides it on buffs. A debuff with no type gets the "None" colour.
- **Right-click cancel** is `SetCancelAuraButtons("RightButtonUp")` on buffs and weapon enchantments. The engine's secure `OnClick` cancels the aura, so it works in combat.
- **Sorting** maps to `AuraContainerSortMethod`: time left (`ExpirationOnly`), name (`NameOnly`), order applied (`AuraInstanceIDOnly`) or Blizzard's (`Default`), each normal or reversed.
- **Weapon enchantments** share the buff rows. An active enchantment takes one buff's place (`WEAPON_ENCHANT_CHANGED`, `WEAPON_SLOT_CHANGED`), so the panel never grows past its rows.
- **Blizzard's `BuffFrame` and `DebuffFrame`** are hidden through `Safe.HideBlizzard` while the panel that replaces each one is built, and come back through `Safe.RestoreBlizzard` when the module turns off, the player turns **Hide Blizzard's buff frames** off, or the gamepad interface is on.
- **Gamepad interface.** While `InputUtil.IsGamepadUIEnabled()` is true, Blizzard's `BuffFrame` and `DebuffFrame` stay on screen and KstyleUI's two panels hide, so the player sees one set of buffs. `INPUT_DEVICE_INTERFACE_TRANSITION` swaps them back and forth through `KstyleUI.Combat.Queue`, so a switch in combat lands when combat ends.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `hideBlizzard` | `true` | toggle |
| `buffs.iconSize`, `debuffs.iconSize` | 28 | slider, 16 to 64 |
| `buffs.spacing`, `buffs.rowSpacing` (and debuffs) | 6, 0 | slider, 0 to 24 |
| `buffs.rows`, `debuffs.rows` | 2, 1 | slider, 1 to 8 |
| `buffs.columns`, `debuffs.columns` | 12 | slider, 1 to 24 |
| `buffs.growth`, `debuffs.growth` | `LEFT_DOWN` | dropdown: left or right, then down or up |
| `buffs.sort`, `debuffs.sort` | `time` | dropdown: time, name, applied, blizzard |
| `buffs.reverse`, `debuffs.reverse` | `false` | toggle |
| `buffs.enchants` | `true` | toggle: weapon enchantments |
| `buffs.cancel` | `true` | toggle: right-click cancels |
| `debuffs.dispel` | `true` | toggle: colour by debuff type |
| `timer.format` | `short` | dropdown: short, long, decimal, none |
| `timer.position` | `below` | dropdown: under the icon, on the icon |
| `timer.font`, `count.font` | the `number` font | font |
| `timer.size`, `count.size` | 9, 11 | slider, 6 to 24, times the Appearance text size |
| `timer.outline`, `count.outline` | `OUTLINE` | dropdown: soft shadow, thin, thick |
| `timer.expiring` | 5 | slider, 0 to 30 seconds; 0 is off |
| `accent.source`, `accent.color` | `class`, the kit accent | dropdown and colour: the buff border |

`Model.Group`, `Model.Timer` and `Model.Count` read these through limits and choice lists, so a damaged or hand-edited profile falls back to the defaults. Shown, position, scale, opacity and strata come from Layout's element rows.

## Why

- **The engine owns aura data.** Aura data turns secret during a boss pull before `InCombatLockdown()` does. `CustomAuraContainerTemplate` reads auras in Blizzard's secure environment and drives the widgets KstyleUI hands it, so the module never calls `C_UnitAuras` and never compares an aura value. It also renders private auras, which Blizzard's `DebuffFrame` shows and a hand-made panel could not.
- **Aura buttons are touched only when the gate is open.** The engine restricts each aura button from tainted code while `C_Secrets.ShouldAurasBeSecret()` is true (`DenyTaintedAccessWhenAurasAreSecret`). Styling happens in `initializeFrame`, before the restriction applies. Any later restyle (a setting, the accent, the scale) runs only out of combat while aura data is not secret; otherwise it waits for `ADDON_RESTRICTION_STATE_CHANGED` or `PLAYER_REGEN_ENABLED`, and the wait is logged. The kit chrome on each button has its `Restyle` wrapped by the same gate, so `Widgets.RestyleAll` never reaches a restricted button. Container-level changes (layout, sort, capacity) apply at once: the container has no access restriction.
- **The art lives on a child frame.** Display elements must be descendants of the aura button, and the button forbids untrusted scripts and reparenting. Every KstyleUI region sits on one plain child frame (`skin`), and none of them needs a script.
- **Layout places a holder, not the container.** The container resizes itself, and Layout's mouseover rule hooks `OnEnter` on an element's children four levels deep, which would reach aura buttons. So Layout places an empty `holder` sized to the full footprint, and the container lives on a sibling `host` that mirrors the holder's scale, alpha, strata and visibility through `hooksecurefunc`. The host sits two levels above the holder, so the aura buttons keep the mouse for tooltips and cancelling. With the mouseover rule the panel appears when the pointer reaches the panel's area between icons.
- **Sizes are elements, not frames.** The flow layout reads `elementWidth` and `elementHeight` from the group layout, so the container lays out correctly even while a button restyle waits behind the gate. Columns become the maximum line size, rows become `maxFrameCount`, and both are snapped to whole pixels in the host's scale.
- **The gamepad needs Blizzard's frames.** Forever's gamepad **View buffs** shortcut (`Blizzard_GamepadActionBars`, `ShortcutsActionBar.lua`) and radial segment (`Blizzard_Gamepad`, `GamepadRadial.lua`) call `BuffFrame:SetGamepadFocus()` and then `DebuffFrame:SetGamepadFocus()`. That check passes on a frame under `Safe`'s hidden parent, because `IsShown()` stays true, so the controller would walk invisible aura buttons. A gamepad layout of KstyleUI's own comes after the first release (design spec, Decisions). The module reads the style from `InputUtil.IsGamepadUIEnabled`, then `C_InputInterfaceStyle.GetCurrentStyle`; if neither answers, or the answer is secret, it takes the keyboard and mouse path and logs it once.
- **Fallbacks.** Without the AuraContainer engine, or if it refuses a group, that panel is not built, Blizzard's frame stays, and the devlog and `/kstyle test` say so. Missing formatters, colour curves or the dispel style enum fall back to the engine's defaults with one devlog line each.
