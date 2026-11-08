# KstyleUI_ActionBars

Main bar with stance, stealth, form and possess paging, extra bars, pet bar, stance bar, keybind text, cooldown sweeps, proc glows, usable and range shading, and mouseover fade.

| Field | Value |
| --- | --- |
| Module name | `ActionBars`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_ActionBars.toc` lists `ActionBars.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Action bars are KstyleUI's own secure buttons. Keybinds use `SetOverrideBindingClick`. Paging uses `RegisterStateDriver`. Cooldowns use `C_ActionBar.GetActionCooldownDuration` with `Cooldown:SetCooldownFromDurationObject`.
- Compact layout: two rows of 12 buttons of 38 units at the 1080 reference, 3-unit gaps and a 10-unit row gap, as the composition mockup measures; no name labels. Keybind, stack and cooldown text sit on the button.
- Blizzard's bars are reparented to a hidden frame through `KstyleUI.Safe.HideBlizzard`. The module never touches `Blizzard_GamepadActionBars`, and switching to gamepad mode must not error or taint.
- Protected work in combat goes through `KstyleUI.Combat.Queue`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `ActionBars.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`ActionBars.xml` loads them in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Data.lua` | The bar table and the pure parts: `GridSize`, `Cell`, `Slot`, `PagingDriver`, `PAGE_SNIPPET`, `ShortKey`, `FontFlags` |
| `Settings.lua` | The defaults and the settings schema |
| `Button.lua` | One button: the kit's `IconButton` on `SecureActionButtonTemplate`, and every visual update |
| `Flyout.lua` | KstyleUI's own secure spell flyout |
| `Bar.lua` | One bar: a Layout holder, a secure state header, the button grid, paging and the mouseover fade |
| `Bindings.lua` | Keybind mirroring and the hotkey text |
| `Blizzard.lua` | Hiding and restoring Blizzard's bars, and the gamepad check |
| `Vehicle.lua` | The leave-vehicle button beside bar 1 |
| `Preview.lua` | The settings window's live preview |
| `Ranks.lua` | New spell ranks: the dialog, and the swap that puts a learned rank on the bars |
| `Module.lua` | `Modules.Register`, `Enable`, `Disable`, events and settings changes |

Tests: `Tools/regression/test-actionbars-data.lua` (the pure parts and the page snippet), `test-actionbars.lua` (bars, paging, bindings, Blizzard's bars, gamepad mode, combat, the settings page) and `test-actionbars-buttons.lua` (button states, flyouts, the leave-vehicle button, the pet and stance bars, the preview). `Tools/regression/actionbars_env.lua` is their fake game: action slots, bindings, a pet, forms, flyouts, secure frames that record protected calls in combat, and a restricted environment that runs the page snippet and wrapped clicks.

## Bars

| Bar | Element key | Blizzard page | Binding names | On by default |
| --- | --- | --- | --- | --- |
| Action bar 1 | `actionbars.bar1` | 1, paged | `ACTIONBUTTON1` to `12` | Yes |
| Action bar 2 | `actionbars.bar2` | 6 (bottom left) | `MULTIACTIONBAR1BUTTON1` to `12` | Yes |
| Action bar 3 | `actionbars.bar3` | 5 (bottom right) | `MULTIACTIONBAR2BUTTON1` to `12` | No |
| Action bar 4 | `actionbars.bar4` | 3 (right) | `MULTIACTIONBAR3BUTTON1` to `12` | No |
| Action bar 5 | `actionbars.bar5` | 4 (left) | `MULTIACTIONBAR4BUTTON1` to `12` | No |
| Action bar 6 | `actionbars.bar6` | 13 (Blizzard's bar 6) | `MULTIACTIONBAR5BUTTON1` to `12` | No |
| Pet bar | `actionbars.pet` | pet actions 1 to 10 | `BONUSACTIONBUTTON1` to `10` | Yes, shown while a pet exists |
| Stance bar | `actionbars.stance` | shapeshift forms 1 to 10 | `SHAPESHIFTBUTTON1` to `10` | Yes, shown when the class has forms |

A bar is built the first time it is switched on, so a bar that stays off costs nothing. Each bar is a plain holder frame registered with `KstyleUI.Layout.Register` as a scalable element, with the label and default position from `Setup.Layouts`. The holder's child is a `SecureHandlerStateTemplate` header, and the buttons are the header's children, so Layout owns the holder's position, scale, opacity and shown rule while the module owns the header's visibility, paging and fade.

When the module starts it reparents `MainActionBar`, `MultiBarBottomLeft`, `MultiBarBottomRight`, `MultiBarRight`, `MultiBarLeft`, `MultiBar5`, `MultiBar6`, `MultiBar7`, `StanceBar` and `PetActionBar` to a hidden frame through `KstyleUI.Safe.HideBlizzard`. Turning the module off restores them through `Safe.RestoreBlizzard`. The possess bar's cancel button and the shaman totem bar (`MultiCastActionBarFrame`) are left alone. Blizzard's leave-vehicle button is a child of `MainActionBar` and hides with it, so `Vehicle.lua` puts a KstyleUI leave button beside bar 1 while `CanExitVehicle()` is true. It is a plain kit button: `VehicleExit` and `TaxiRequestEarlyLanding` are not protected, so it shows, hides and works in combat.

## Buttons

Each button is `KstyleUI.Widgets.IconButton` built on `SecureActionButtonTemplate`, with the kit's `silent` option so a key press does not click.

| Kind | Attributes | Clicks |
| --- | --- | --- |
| Action | `type = "action"`, the button's ID 1 to 12, `useparent-actionpage`, `checkselfcast`, `checkfocuscast`, `checkmouseovercast` | `AnyUp` and `AnyDown`, so `ActionButtonUseKeyDown` decides when a press acts |
| Pet | `type = "pet"`, `action` = the slot, `type2 = ""` | Right-click runs no secure action; an insecure `PostClick` toggles autocast with `C_Spell.ToggleSpellAutoCast` |
| Stance | `type = "spell"`, `spell` = the form's spell ID from `GetShapeshiftFormInfo` | Set out of combat when the forms change |

| State | Source |
| --- | --- |
| Icon | `C_ActionBar.GetActionTexture`, through `KstyleUI.Icons.Apply` with the file ID |
| Cooldown sweep | `C_ActionBar.GetActionCooldownDuration` into `Cooldown:SetCooldownFromDurationObject`. Without it, `GetActionCooldown` when its values are not secret. |
| Charges | The kit's charge cooldown with `GetActionChargeDuration` while `GetActionCharges().isActive`, only for actions whose `maxCharges` is above 1 |
| Count | `C_ActionBar.GetActionDisplayCount`, passed to the text untouched |
| Macro name | `C_ActionBar.GetActionText` when `UsesActionText` |
| Proc glow | `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` and `HIDE` for spells and spell macros, and `C_SpellActivationOverlay.IsSpellOverlayed` on each update |
| Usable and power | `ACTION_USABLE_CHANGED`, and `IsUsableAction` on each update. Unusable greys the button; lacking power tints it with the power colour. |
| Range | `C_ActionBar.EnableActionRangeCheck` for each slot with an action on a shown button of a shown bar, released when the slot, the bar or the module goes, and `ACTION_RANGE_CHECK_UPDATE`. A target change also polls `IsActionInRange`. Out of range tints with the range colour. |
| Selected | `IsCurrentAction` or `IsAutoRepeatAction` |
| Empty | An empty slot shows as an empty tile, or at alpha 0 when **Show empty buttons** is off, and at full alpha while the cursor holds an action (`ACTIONBAR_SHOWGRID`) |

A secret value is never compared: a secret flag counts as its safe default (usable, in range, not selected), and a secret count or text goes to the font string untouched. A slot the client does not have, such as page 13 on a client with fewer slots, is found once with `pcall(C_ActionBar.HasAction, slot)` and logged, and its button stays empty.

Drag and drop works out of combat only. With **Lock Action Bars** on (`lockActionBars`), dragging needs the pick-up modifier, as Blizzard's bars do. `PickupAction`, `PlaceAction` and `PickupPetAction` never run in combat.

## Paging

Bar 1's header runs a state driver on `page`. `PagingDriver` builds it from the bar's paging rules and the player's class:

1. **Possess and vehicles**: `[vehicleui] vehicle; [overridebar] override; [possessbar] possess; [shapeshift] shapeshift; [bonusbar:5] possess`
2. **Page keys**: `[bar:2] 2` to `[bar:6] 6`
3. **Stances, forms and stealth**: `[bonusbar:N] 6+N`. A rogue's bonus bars 1 and 2 and a druid's bonus bar 2 (prowl) follow the stealth rule; every other bonus bar follows the stances and forms rule.
4. `1`

`PAGE_SNIPPET` is the header's `_onstate-page`. A number is the page. A special state resolves the way Blizzard's `ActionBarController` does: the vehicle bar, then the override bar, then the temporary shapeshift bar, then the bonus bar, then Blizzard's own page. It sets the header's `actionpage`, which every button reads through `useparent-actionpage` when it is clicked, so a key always casts what its button shows, in combat too. A hook on the header's `OnAttributeChanged` then updates the buttons' icons and states, which needs no protected call.

**Custom paging** replaces the rules with the player's own macro conditions on any action bar. The conditions are checked with `SecureCmdOptionParse` first; ones that raise an error or resolve to something that is not a page or a special state are logged and the default rules are used.

## Flyouts

A flyout action (portals, teleports, pet calls) must not reach Blizzard's `SpellFlyout`: its `Toggle` calls `GetPopupDirection` and `TogglePopup` on the clicked button, which KstyleUI's buttons do not have, and giving them those methods would run KstyleUI's code inside Blizzard's secure flyout path. So every action button's `OnClick` is wrapped with `SecureHandlerWrapScript` on KstyleUI's own flyout frame, a `SecureHandlerBaseTemplate` frame with 12 secure spell buttons:

- The wrap reads the clicked slot with the restricted `GetActionInfo`. Anything but a flyout clicks as usual.
- For a flyout, the key-down (or mouse-down) half of the click lays out one button per spell beside the owner, in the bar's `flyoutDirection` (up from a bottom bar, down from a top one, inward from a side column), shows the frame and returns `false`, so the action never reaches Blizzard's code. The release half is swallowed. A second click on the owner closes it, and it closes itself once the pointer has been away for a second (`RegisterAutoHide`).
- Each flyout button casts its spell (`type = "spell"`) and closes the flyout on release.
- `Flyout.Refresh` stores each flyout's known spells on the frame as attributes, out of combat: the flyouts from `C_Flyout.GetNumFlyouts` and `GetFlyoutID`, and any flyout on an action slot. Like Blizzard's action-bar flyouts it keeps only the highest known rank of each spell. It runs at Enable, on `SPELLS_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE` and `SPELL_FLYOUT_UPDATE`, and when a slot gains a flyout it does not know. Slots cannot change in combat, so every flyout bar 1 can page to is known before combat starts.

A flyout action shows a small chevron on the edge it opens from.

## Keybinds

`Bindings.lua` reads `GetBindingKey` for each shown button's Blizzard binding name and points every key at the KstyleUI button with `SetOverrideBindingClick(owner, false, key, buttonName, "LeftButton")`. It clears and rebuilds them out of combat on `UPDATE_BINDINGS`, a settings change or a gamepad transition; in combat the old bindings keep working until the queued rebuild runs. The player's own bindings are never changed: the override bindings sit on top of them and vanish when the module or the bar turns off. The hotkey text is `ShortKey` of the first key, such as `S1` for Shift-1 and `M4` for mouse button 4, with `GetBindingText(key, true)` for a key it does not know.

## New spell ranks

`Ranks.lua` puts a newly learned rank on the bars. `LEARNED_SPELL_IN_SKILL_LINE` queues the spell, and half a second later the module checks the batch against action slots 1 to 180 with `GetActionInfo`. Those slots cover every page, so bar 1's stance, form and stealth pages count too: a warrior's stance bars are slots 73 to 108. A slot holds a lower rank when its spell has the same `C_Spell.GetSpellName` and a lower number in `C_Spell.GetSpellSubtext`, such as "Rank 2". The module skips a secret name, rank text or slot. When the player learns two ranks of one spell together, the higher rank wins. A spell whose text has not loaded yet, which `C_Spell.GetSpellSubtext` returns as an empty string, is not skipped: when `C_Spell.IsSpellDataCached` says the data is not cached (or the API is missing), the module calls `C_Spell.RequestLoadSpellData` and checks the spell again when `SPELL_DATA_LOAD_RESULT` reports it with `success`. A spell is requested once per learn, at most 20 spells load at once, a failed load drops the spell, and a result with a secret spell ID is ignored. Without `RequestLoadSpellData` the spell is skipped and logged once. Forever's own `SpellMixin:ContinueOnSpellLoad` is not used: its `SpellEventListener` comes from `AsyncCallbackSystem.lua`, which `Blizzard_ObjectAPI.toc` loads only for the mainline game type. `SPELLS_CHANGED` is not used, because it does not say which spell is new, and scanning the bars on it would offer ranks a player keeps low on purpose. The **New spell ranks** setting picks what happens. **Ask**, the default, shows a KstyleUI dialog that lists each new rank with its icon and has **Update bars** and **Not now** buttons. A rank learned while the dialog is open joins it. **Update automatically** swaps with no dialog, and **Off** does nothing. Tests: `Tools/regression/test-actionbars-ranks.lua`.

The swap runs out of combat only. For each slot that still holds the old rank, it calls `C_Spell.PickupSpell` with the new rank, then `PlaceAction(slot)`, then `ClearCursor()`. `PlaceAction` swaps the old rank onto the cursor and `ClearCursor` drops it, so the old rank never lands anywhere. The module then reads each slot again and logs once for a slot that did not take the new rank. **Update bars** in combat queues the swap through `Combat.Queue` and says so in a second dialog. While the cursor holds something, such as an item the player is moving, the swap waits and checks again every second. A waiting swap holds only the ranks the player approved, and choosing **Off** cancels it. Macros, flyouts, the pet bar and the stance bar's form buttons never change, because only slots whose action type is `spell` qualify.

## Gamepad mode

`IsGamepad` compares `C_InputInterfaceStyle.GetCurrentStyle()` with `Enum.InputDeviceInterfaceType.Gamepad`. In gamepad mode every bar's visibility driver is `hide` and the override bindings are cleared, so Blizzard's gamepad bars own the screen and the pad's keys. `INPUT_DEVICE_INTERFACE_TRANSITION` reruns this, through `Combat.Queue` in combat. The module never names a frame or function of `Blizzard_GamepadActionBars`; `test-actionbars.lua` checks every name that addon defines against this folder's code.

## Settings

The page starts with **Bar to edit**, a picker that shows one bar's rows at a time. Each bar's rows carry `scope = { key = "editBar", value = <bar> }`, so the settings search finds every bar's rows, whichever bar is picked.

| Per bar | Values |
| --- | --- |
| Show this bar | On for bars 1 and 2, the pet bar and the stance bar |
| Buttons, Rows | 1 to 12 (10 for the pet and stance bars). The columns follow from the two. |
| Fill order, Growth | Along rows or down columns first; right or left, then down or up |
| Button size, Spacing | 16 to 64 and 0 to 16 units. 38 and 3 for the action bars, 30 and 3 for the pet and stance bars. |
| Show empty buttons, Backing strip, Fade until hovered, Faded opacity | On, on for bars 1 and 2 (off for the other bars), off, 0. The backing strip is the composition mockup's smoked-glass band behind each bar row: `surface` glass with 6-unit chamfers, 4 units beyond the buttons on every side, a child of the bar's header so it fades with the bar |
| Keybind text, Count text, Macro names, Cooldown numbers | On, on, off, on |
| Paging (bar 1) | Stances and forms, Stealth, Possess and vehicles, Page keys: all on |
| Custom paging (action bars) | Empty |

Shared rows: the font, size and outline of each of the four texts (the size is multiplied by the Appearance page's text size), the accent (the interface accent, the class colour or a custom colour), the out-of-range and not-enough-power colours, and when tooltips show. Position, scale, opacity in and out of combat, strata and the shown rule come from Layout, on the same page under **Positions and sizes**.

## Why

- **Own secure buttons, not Blizzard's.** Writing to Blizzard's action buttons, or reusing them, taints Blizzard's action dispatch and its gamepad bars for the whole session. KstyleUI's buttons are its own `SecureActionButtonTemplate` buttons, so nothing KstyleUI writes ever reaches a Blizzard button.
- **Paging in the header, not in Lua.** The page has to change in combat, when Lua may not set attributes on a secure frame. The state driver and the restricted snippet change `actionpage` securely, and the buttons read it when they are clicked, so a key can never cast an action from a page the button does not show. Lua only follows along to redraw.
- **Possess and vehicles resolve like Blizzard.** The snippet asks the same questions in the same order as `ActionBarController_UpdateAll`, so bar 1 shows what Blizzard's main bar would have shown.
- **Override bindings, mirrored.** The player sets keys in Blizzard's keybinding settings as always. Override bindings leave those bindings untouched and disappear with the module, so turning KstyleUI off can never lose a keybind.
- **A holder and a header.** Layout shows, hides, fades and moves the holder; the module shows, hides and fades the header. Neither ever undoes the other.
- **Alpha for empty buttons.** A protected button cannot be shown or hidden in combat, but its alpha can change, so a page change in combat can still hide empty slots.
- **Fonts on the module, toggles on each bar.** One font change restyles every bar, which is what a player changing the keybind font wants; each bar still chooses which texts it shows.
- **Mouse clicks act on key down.** `SecureActionButtonTemplate` cannot tell an addon's mouse click from a key press, so both follow `ActionButtonUseKeyDown`, as other addon bars on this template do.
- **A flyout of our own.** Blizzard's spell flyout expects Blizzard's button mixins and runs secure code on the button it opens from. A secure wrap and a small flyout frame of KstyleUI's own keep flyouts working in combat without KstyleUI code ever running inside Blizzard's flyout.
- **Bars 3 to 6 start off.** The v3 HUD shows two rows of 12. The columns at the screen's edges are one switch away, and their Blizzard keybinds keep working on Blizzard's hidden buttons until the player turns them on.
