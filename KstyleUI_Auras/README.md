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
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Auras.xml` loads the files in this order. Tests: `Tools/regression/test-auras-model.lua` (the pure model), `test-auras.lua` (the module against a fake AuraContainer engine in `Tools/regression/auras_env.lua`), `test-auras-card.lua` (the card's shape), `test-auras-counts.lua` (0, 8, 24 and 40 buffs beside 12 debuffs: the card stays in its column and on screen, the `+N` count and the full list) and `test-auras-gamepad.lua` (the gamepad interface). The gallery scene `Tools/render/scenes/gallery_auras_counts.lua` renders those four counts.

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
| `auras.buffs` | `HELPFUL`, with the main-hand, off-hand and ranged weapon enchantments first | `TOPRIGHT`, -287, -16: beside the minimap, 12 units left of its 259-unit element and top-aligned with it | 2 rows of 8 icons of 38 units (the action button's size), 8-unit gaps (the mockup's 46-unit pitch), growing left from the minimap, then down, so the shortest time left sits next to the map: 360 by 102 units |
| `auras.debuffs` | `HARMFUL` | `TOPRIGHT`, -287, -126, 8 units under the buffs | 1 row of 8: 360 by 51 units |

The composition mockup draws one buff row under the minimap with the quest tracker under that. Forever's Edit Mode preset pins the objective tracker's top 275 units under the screen's top (`Blizzard_EditMode/Mainline/EditModePresetLayouts.lua`, the `ObjectiveTracker` entry: `TOPRIGHT` of `UIParent` at -110, -275, loaded for the camelot game type through the toc's `[Family]` line), 38 units under the minimap's 221-unit frame, and KstyleUI never moves Blizzard's tracker (no `SetPoint` on a Blizzard frame). One 51-unit row does not fit there, let alone two rows and the debuffs, so the rows stand beside the minimap, where no buff count reaches the tracker. A player who moves the tracker down in Edit Mode can drag the buffs back under the minimap in Layout Mode.

Each icon is the kit's chamfered tile with the icon masked inside it. The timer sits under the icon (or on its lower edge) and the stack count on its lower right corner. The engine fills in the icon, the timer, the stack count, the tooltip and the dispel colour, so secret aura data never reaches KstyleUI's Lua. The engine draws each aura's icon as a secret (`secretwrap`), so no addon code can swap it; the repainted icons reach the tiles anyway, because they ship as a loose-file pack the client loads for every icon ([`docs/icons.md`](../docs/icons.md)), in game and in the renders.

- **Timers** use the engine's duration text binding. `short` is the engine's default formatter (`24s`, `8m`, `2h`); `long` and `decimal` are `C_StringUtil` seconds formatters with two units, or tenths under 3 seconds. A step colour curve turns the timer `hostile` under the warning time.
- **Debuff type** colours a chamfered underlay behind each debuff icon through `AddDispelTypeTexture` with the `PreserveAsset` style, so the engine applies Blizzard's dispel colour and hides it on buffs. A debuff with no type gets the "None" colour.
- **Right-click cancel** is `SetCancelAuraButtons("RightButtonUp")` on buffs and weapon enchantments. The engine's secure `OnClick` cancels the aura, so it works in combat.
- **Sorting** maps to `AuraContainerSortMethod`: time left (`ExpirationOnly`), name (`NameOnly`), order applied (`AuraInstanceIDOnly`), Blizzard's (`Default`) or priority (`UnitFrameDebuff`: boss debuffs, then important ones, then yours first, as Blizzard's unit frames order them), each normal or reversed. Debuffs sort by priority by default.
- **Dispellable first.** The debuff container runs two engine groups: `dispel`, whose `candidateFilters.includeDispelTypes` admits Magic, Curse, Poison and Disease, then `debuffs`, which excludes them. The flow layout lays the groups out in order with one spacing, so dispellable debuffs lead the rows whatever the sort. Each group may show the debuff rows' worth, so with both kinds present the rows can run to twice `rows` before any debuff is left out: debuffs stay visible first. **Dispellable first** off stands the `dispel` group down (`SetAuraGroupEnabled`) and clears the rest group's filter (`SetAuraGroupCandidateFilters`), with no reload.
- **Weapon enchantments** share the buff rows. An active enchantment takes one buff's place (`WEAPON_ENCHANT_CHANGED`, `WEAPON_SLOT_CHANGED`), so the panel never grows past its rows.
- **Many auras.** The rows are the cap: two rows of six buffs and two rows of six debuffs by default (`rows` up to 8). The engine shows the first `rows x columns` of each group by the sort, and the card grows by whole rows as they fill, by anchors, never past the cap. Out of combat the card counts the player's auras through `C_UnitAuras.GetAuraSlots` (paged, 40 slots a call) and refits on `UNIT_AURA`: with no debuffs the hairline band goes, with no buffs over the debuffs it goes too, with no auras at all the card hides (the Layout element stays for the mover plate), and the buffs and debuffs the rows cannot show read as a `+N` count at the cap's right (a debuff past one group's rows counts even when the other group still shows it, so the count errs high rather than hide one). Hovering the count opens the full list: a glass flyout left of the card, toward the screen's centre and clamped to it, holding a second pair of engine containers at a 28-unit tile, eight to a row, up to 48 buffs and 24 debuffs, which closes half a second after the pointer leaves both. The flyout's containers are the engine's too, so the list is right in combat, and they take the card's settings (tile aside) whenever they change; the flyout relays out on each recount while it is open. While auras are secret the counts cannot be read: on `PLAYER_REGEN_DISABLED` the card shows at once (a buff gained in combat is never hidden) and keeps the shape and count it last knew; `PLAYER_REGEN_ENABLED` and `ADDON_RESTRICTION_STATE_CHANGED` count again.
- **Blizzard's `BuffFrame` and `DebuffFrame`** are hidden through `Safe.HideBlizzard` while the panel that replaces each one is built, and come back through `Safe.RestoreBlizzard` when the module turns off, the player turns **Hide Blizzard's buff frames** off, or the gamepad interface is on.
- **Gamepad interface.** While `InputUtil.IsGamepadUIEnabled()` is true, Blizzard's `BuffFrame` and `DebuffFrame` stay on screen and KstyleUI's two panels hide, so the player sees one set of buffs. `INPUT_DEVICE_INTERFACE_TRANSITION` swaps them back and forth through `KstyleUI.Combat.Queue`, so a switch in combat lands when combat ends.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `hideBlizzard` | `true` | toggle |
| `buffs.iconSize`, `debuffs.iconSize` | 38 | slider, 16 to 64 |
| `buffs.spacing`, `buffs.rowSpacing` (and debuffs) | 8, 0 | slider, 0 to 24 |
| `buffs.rows`, `debuffs.rows` | 2, 2 | slider, 1 to 8: the cap; the rest count as `+N` at the cap |
| `buffs.columns`, `debuffs.columns` | 6 | slider, 1 to 24 |
| `buffs.growth`, `debuffs.growth` | `LEFT_DOWN` | dropdown: left or right, then down or up. The container hangs from the element's corner the rows grow from, so a short row sits flush with the minimap's side |
| `buffs.sort`, `debuffs.sort` | `time`, `priority` | dropdown: time, name, applied, blizzard, priority |
| `buffs.reverse`, `debuffs.reverse` | `false` | toggle |
| `buffs.enchants` | `true` | toggle: weapon enchantments |
| `buffs.cancel` | `true` | toggle: right-click cancels |
| `debuffs.dispel` | `true` | toggle: colour by debuff type |
| `debuffs.dispelFirst` | `true` | toggle: dispellable debuffs before the rest |
| `timer.format` | `short` | dropdown: short, long, decimal, none |
| `timer.position` | `below` | dropdown: under the icon, on the icon |
| `timer.font`, `count.font` | the `number` font | font |
| `timer.size`, `count.size` | 12, 11 | slider, 6 to 24, times the Appearance text size |
| `timer.outline`, `count.outline` | `OUTLINE` | dropdown: soft shadow, thin, thick |
| `timer.expiring` | 5 | slider, 0 to 30 seconds; 0 is off |
| `accent.source`, `accent.color` | `class`, the kit accent | dropdown and colour: the buff border |

`Model.Group`, `Model.Timer` and `Model.Count` read these through limits and choice lists, so a damaged or hand-edited profile falls back to the defaults. Shown, position, scale, opacity and strata come from Layout's element rows.

## Why

- **The engine owns aura data.** Aura data turns secret during a boss pull before `InCombatLockdown()` does. `CustomAuraContainerTemplate` reads auras in Blizzard's secure environment and drives the widgets KstyleUI hands it, so the module never calls `C_UnitAuras` and never compares an aura value. It also renders private auras, which Blizzard's `DebuffFrame` shows and a hand-made panel could not.
- **Aura buttons are touched only when the gate is open.** The engine restricts each aura button from tainted code while `C_Secrets.ShouldAurasBeSecret()` is true (`DenyTaintedAccessWhenAurasAreSecret`). Styling happens in `initializeFrame`, before the restriction applies. Any later restyle (a setting, the accent, the scale) runs only out of combat while aura data is not secret; otherwise it waits for `ADDON_RESTRICTION_STATE_CHANGED` or `PLAYER_REGEN_ENABLED`, and the wait is logged. The kit chrome on each button has its `Restyle` wrapped by the same gate, so `Widgets.RestyleAll` never reaches a restricted button. Container-level changes (layout, sort, capacity) apply at once: the container has no access restriction.
- **The art lives on a child frame.** Display elements must be descendants of the aura button, and the button forbids untrusted scripts and reparenting. Every KstyleUI region sits on one plain child frame (`skin`), and none of them needs a script.
- **Layout places a holder, not the container.** The container resizes itself, and Layout's mouseover rule hooks `OnEnter` on an element's children four levels deep, which would reach aura buttons. So Layout places an empty `holder` sized to the full footprint, and the container lives on a sibling `host` that mirrors the holder's scale, alpha, strata and visibility through `hooksecurefunc`. The host sits two levels above the holder, so the aura buttons keep the mouse for tooltips and cancelling. With the mouseover rule the panel appears when the pointer reaches the panel's area between icons.
- **The card hugs its rows by anchors.** The engine sizes each container to the rows it holds from secure code (`OnLayoutComplete` writes a secret size), so the module never reads it. The buff rows' content frame hangs from the holder, a spacer frame spans from the content's top left to the container's bottom right, the hairline and the docked debuff row hang from that spacer, a second spacer ends at the debuff container, and the host's bottom right comes from an edge frame that takes the holder's right and the spacer's bottom plus the padding. So one row of buffs makes a one-row card, and a second row grows it with no Lua in between. A frame anchored to a container must carry Blizzard's `DisableUntrustedLayoutScriptsTemplate` (`Blizzard_SharedXMLBase/ForbiddenAspectTemplates.xml`), so the host, the debuff host, the dock and the three spacer frames are made from it; without it the engine would refuse the anchor, and the module falls back to a plain frame and logs once. The holder keeps the reserved footprint, so the Layout Mode plate stays put.
- **Sizes are elements, not frames.** The flow layout reads `elementWidth` and `elementHeight` from the group layout, so the container lays out correctly even while a button restyle waits behind the gate. Columns become the maximum line size, rows become `maxFrameCount`, and both are snapped to whole pixels in the host's scale.
- **The gamepad needs Blizzard's frames.** Forever's gamepad **View buffs** shortcut (`Blizzard_GamepadActionBars`, `ShortcutsActionBar.lua`) and radial segment (`Blizzard_Gamepad`, `GamepadRadial.lua`) call `BuffFrame:SetGamepadFocus()` and then `DebuffFrame:SetGamepadFocus()`. That check passes on a frame under `Safe`'s hidden parent, because `IsShown()` stays true, so the controller would walk invisible aura buttons. A gamepad layout of KstyleUI's own comes after the first release (design spec, Decisions). The module reads the style from `InputUtil.IsGamepadUIEnabled`, then `C_InputInterfaceStyle.GetCurrentStyle`; if neither answers, or the answer is secret, it takes the keyboard and mouse path and logs it once.
- **Fallbacks.** Without the AuraContainer engine, or if it refuses a group, that panel is not built, Blizzard's frame stays, and the devlog and `/kstyle test` say so. Missing formatters, colour curves or the dispel style enum fall back to the engine's defaults with one devlog line each.
