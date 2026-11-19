# KstyleUI_ActionBars

Main bar with stance, stealth, form and possess paging, extra bars, pet bar, stance bar, keybind text, cooldown sweeps, proc glows, usable and range shading, and mouseover fade.

## Hover keybindings

Type `/kb`, `/kstyle kb` or `/kstyle keybind`, hover a button, and press a key, middle or extra mouse button, or wheel with optional modifiers. Shift, Ctrl, Alt and Meta (Cmd on Mac) use Blizzard's chord order. Left and right clicks are ignored to preserve world selection and camera controls. Escape clears every binding for the hovered button. The panel highlights the button and shows its keys using the client's localized key names. **Save** applies the edits to account bindings, or character bindings with **Character bindings** selected. Switching from character to account bindings requires confirmation and loads the existing account set before applying edits. **Discard**, toggling the mode off, disabling Action Bars, switching input devices or entering combat drops unsaved edits. Binding mode cannot start in combat. `/kb` and `/bb` are registered only when another loaded addon has not claimed them; `/kstyle kb` always opens KstyleUI's mode.

Bindings use the game's commands (`ACTIONBUTTONn`, `MULTIACTIONBARnBUTTONn`, `BONUSACTIONBUTTONn`, `SHAPESHIFTBUTTONn`, and `VEHICLEEXIT`), appear in Blizzard's Key Bindings, and remain when KstyleUI is disabled. Stance buttons securely forward clicks to Blizzard's stance buttons, whose form selector toggles stealth off; directly casting the form spell cannot do that.

Blizzard's native possess buttons remain visible and can also be hovered in `/kb`. Forever has no `POSSESSBUTTONn` binding entry, so these use persistent `CLICK PossessButtonn:LeftButton` game bindings; the cancel slot retains Blizzard's taxi, vehicle and pet-possession behavior. Slot 1 keeps Blizzard's informational behavior. Forever also disables the extra-action button and omits its binding; on a client exposing that button, `/kb` supports `EXTRAACTIONBUTTON1`. No placeholder extra button is created.

| Field | Value |
| --- | --- |
| Module name | `ActionBars`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_ActionBars.toc` lists `ActionBars.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Action bars are KstyleUI's own secure buttons. Keybinds use `SetOverrideBindingClick`. Paging uses `RegisterStateDriver`. Cooldowns use `C_ActionBar.GetActionCooldownDuration` with `Cooldown:SetCooldownFromDurationObject`.
- KSTY-44 (the overhaul mock-ups Lee approved on 2026-11-12, which replace LEE-20's picture for the tray): bars 1 and 2 are enabled preset rows of twelve 45.125-unit buttons (38 px at 1080p), with 3.5625-unit gaps (3 px), inside the [Frames tray](#frames-tray) card. LEE-20's 36.7-unit tiles stay on the rail's bars 4 to 6. Absolute button origins are snapped instead of accumulating rounded gaps. Bars 4 to 6, the rail's columns of twelve on the same slots, do the same, so a column is as tall as the 491 units the layout reserves at any scale. Keybind, stack and cooldown text sit on the kit's square tiles; no name labels.
- Blizzard's bars are reparented to a hidden frame through `KstyleUI.Safe.HideBlizzard`. The module never touches `Blizzard_GamepadActionBars`, and switching to gamepad mode must not error or taint.
- Protected work in combat goes through `KstyleUI.Combat.Queue`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

### Crest travel

In Medallions, **Crest travel clicks** defaults on. Left click uses `item:6948`; with no carried Hearthstone its action type is cleared. Right click opens travel above the crest and both central cast bars. Right click again, Escape, or using a destination closes it. The crest tooltip uses the shared KstyleUI tooltip, showing the bind location, remaining Hearthstone cooldown (`--` when secret), missing-Hearthstone notice and both clicks. Turning the setting off hides the secure overlay and restores click-through artwork.

The flyout uses the action bars' own `Widgets.Slot`, `Socket.Decorate` and `Slab.Dress` builders. Empty Hearth and class, Portals and teleports, and Mounts groups hide; each group has twelve destinations per page, so a large mount collection cannot grow it off screen. Page changes, opening, closing and Escape bindings run in secure snippets, including in combat. Inventory, spell, mount, zone, layout and option updates run through `Combat.Queue` and coalesce while combat holds them.

`TravelData.Read()` returns three ordered lists of `{ kind, id, name, icon }` entries plus whether a Hearthstone is carried. `TravelData.Hearth()` returns bind location and cooldown text. `TravelData.lua` has no UI, events or dependency on the enabled Action Bars module; it attaches to its loader's private namespace, so a future Hearthstone data widget can load that same source with the generated item list. `Tools/data/travel-items.json` is the curated transport item source; run `python Tools/data/travel-items.py` after editing it. The behaviour test checks that the shipped generated IDs match it.

Forever's source proves **item mounts** (`ItemClass.Miscellaneous=15`, `ItemMiscellaneousSubclass.Mount=5`) and known Paladin/Warlock mount spells. Carried item mounts must pass `C_Item.IsUsableItem`; class mount spells must be known and usable. The code also reads the documented core `C_MountJournal` API if the client exposes it, filtering collected, usable and non-hidden mounts and casting their spell IDs. It never loads `Blizzard_Collections`, whose TOC excludes camelot, and never assumes the old companion API exists: this source has no `GetNumCompanions` or `GetCompanionInfo` declaration. API documentation does not prove a populated journal on a live camelot character, so the in-game checks must confirm which guarded route the client provides. Bag items and class spells work without a journal.

The matching UI source is build **1.60.1.70862**, commit **9dc84f0**, at `C:/Users/leeba/.cache/wow-ui-source/Interface/AddOns/`. New API and secure contracts are proved there:

| Contract | Proving file and line (relative to `Interface/AddOns/`) |
| --- | --- |
| `C_Container.GetContainerNumSlots`, `GetContainerItemInfo`, item names/IDs/icons | `Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua:313`, `:192`, `:766` |
| Bag slot constants (guarded; classic fallback is bags 0–4) | `Blizzard_APIDocumentationGenerated/ItemConstants_MainlineDocumentation.lua:59`, `:61` |
| `C_Item.GetItemCooldown`, `GetItemInfoInstant`, `IsUsableItem` | `Blizzard_APIDocumentationGenerated/ItemDocumentation.lua:434`, `:659`, `:1627` |
| Equipped transport trinkets stay available after the secure item action equips them: `IsEquippedItem`, `GetItemNameByID`, `GetItemIconByID` | `Blizzard_APIDocumentationGenerated/ItemDocumentation.lua:1339`, `:846`, `:611`; equipment-before-use behaviour is `Blizzard_FrameXML/SecureTemplates.lua:434` |
| Mount item class and subclass | `Blizzard_APIDocumentationGenerated/ItemConstantsDocumentation.lua:291`, `:465` |
| `C_SpellBook.IsSpellKnown`, `C_Spell.GetSpellInfo`, `C_Spell.IsSpellUsable` | `Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua:738`; `SpellDocumentation.lua:416`, `:980` |
| Optional `C_MountJournal.GetMountIDs`, `GetMountInfoByID` (spell, usable, hidden, collected) | `Blizzard_APIDocumentationGenerated/MountJournalDocumentation.lua:268`, `:278` |
| Collections does not load on camelot | `Blizzard_Collections/Blizzard_Collections.toc:13` |
| `GetBindLocation`, `GetTime`, `issecretvalue` | `Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua:266`; `SystemTimeDocumentation.lua:57`; `FrameScriptDocumentation.lua:287` |
| `SecureActionButtonTemplate`, `SecureHandlerBaseTemplate` | `Blizzard_FrameXML/SecureTemplates.xml:4`; `Blizzard_RestrictedAddOnEnvironment/SecureHandlerTemplates.xml:6` |
| Button suffixes `type1`, `item1`, action `type`, `item`, `spell` | `Blizzard_FrameXML/SecureTemplates.lua:6`, `:30`, `:396`, `:418` |
| Release-only `useOnKeyDown=false` plus `AnyUp`/`AnyDown` | `Blizzard_FrameXML/SecureTemplates.lua:792`; `Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua:271` |
| Secure pre/post click wrapping, suppressing the underlying click and returning a post message | `Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua:272`, `:602` |
| Secure hide wrapping and frame references | `Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua:406`, `:702`; `RestrictedFrames.lua:205` |
| Restricted `Show`, `Hide`, `GetAttribute`, `SetAttribute`, `SetBindingClick`, `ClearBindings` | `Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua:394`, `:402`, `:192`, `:522`, `:545`, `:537` |
| Blizzard flyout toggle, close after use and Escape precedents | `Blizzard_ActionBar/Shared/SpellFlyout.lua:278`, `:30`, `:11`; our combat path uses the restricted handlers above |
| Frame clamping, scale and top measurements | `Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1207`, `:381`; `SimpleScriptRegionAPIDocumentation.lua:308` |
| Frame creation precedent and ordinary frame methods (`SetFrameStrata`, `SetAttribute`, `GetAttribute`, `IsShown`, `Hide`, `Show`, `SetShown`) | `Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua:589`; `Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1293`, `:1169`, `:290`, `:915`, `:687`, `:1539`, `:1484` |
| `ClearAllPoints`, `SetAllPoints`, `SetPoint`, FontString `SetText` | `Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua:22`, `:111`, `:135`; `SimpleFontStringAPIDocumentation.lua:664` |
| Bag, spell, entering-world, mount and zone events | `Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua:677`; `SpellBookDocumentation.lua:968`; `SystemDocumentation.lua:136`; `MountJournalDocumentation.lua:656`; `MapDocumentation.lua:653`, `:659`, `:665` |

The travel IDs are confirmed against `Tools/data/abilities.json`, including Forever's `Teleport: Dalaran` (1297659) and `Portal of Summoning` (437169), and every spell is filtered through `IsSpellKnown`. Shared overlay placement is `Core/Widgets/Base.lua:659` (`Widgets.Cover`); deferred updates use `Core/Combat.lua:27`; bag record reads follow `KstyleUI_Bags/Data.lua:130`.

In game: check left/right click and Escape inside and outside combat, missing Hearthstone, secret cooldowns with forced restrictions, learned spells, carried mounts and transport trinkets, mount skill restrictions, changing bags during combat, and disabling the option. The harness proves protected-call discipline and geometry; it cannot prove client taint or protected-action permission.

`ActionBars.xml` loads them in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Data.lua` | The bar table and the pure parts: `GridSize`, `Cell`, `Slot`, `PagingDriver`, `PAGE_SNIPPET`, `ShortKey`, `FontFlags` |
| `Settings.lua` | The defaults and the settings schema |
| `Socket.lua` | The action bars' state on the kit's shared `Slot` (see [Lumen sockets](#lumen-sockets)) and the one table of tokens it reads |
| `Button.lua` | One button: the kit's `Slot` on `SecureActionButtonTemplate`, and every visual update |
| `Flyout.lua` | KstyleUI's own secure spell flyout |
| `Bar.lua` | One bar: a Layout holder, a secure state header, the button grid, paging and the mouseover fade |
| `Tray.lua` | The [Frames tray](#frames-tray): one card behind bars 1 and 2 while they stand stacked |
| `Slab.lua` | The [Medallions slab](#medallions-slab): the slab behind bars 1 and 2, the crest hub between them and its motion |
| `SlabEffects.lua` | The Medallions effects beside the slab: the slot ready flash, the hub's resource-cap ring and the hub's 3D models ([medallions-effects.md](../docs/medallions-effects.md)) |
| `Bindings.lua` | Keybind mirroring and the hotkey text |
| `Keybind.lua` | Hover overlays, the Save/Discard panel and staged game bindings |
| `Blizzard.lua` | Hiding and restoring Blizzard's bars, and the gamepad check |
| `Vehicle.lua` | The leave-vehicle button below the Medallions slab, beyond the power orb or beside bar 1 (beyond an active Frames stance bar) |
| `Preview.lua` | The settings window's live preview |
| `Ranks.lua` | One learned-spell dialog: update ranks or add new active spells to empty visible slots |
| `Module.lua` | `Modules.Register`, `Enable`, `Disable`, events and settings changes |

Tests: `Tools/regression/test-actionbars-data.lua` (the pure parts and the page snippet), `test-actionbars.lua` (bars, paging, bindings, Blizzard's bars, gamepad mode, combat, the settings page) and `test-actionbars-buttons.lua` (button states, flyouts, the leave-vehicle button, the pet and stance bars, the preview). `Tools/regression/actionbars_env.lua` is their fake game: action slots, bindings, a pet, forms, flyouts, secure frames that record protected calls in combat, and a restricted environment that runs the page snippet and wrapped clicks.

## Bars

| Bar | Element key | Blizzard page | Binding names | On by default |
| --- | --- | --- | --- | --- |
| Action bar 1 | `actionbars.bar1` | 1, paged | `ACTIONBUTTON1` to `12` | Yes |
| Action bar 2 | `actionbars.bar2` | 6 (bottom left) | `MULTIACTIONBAR1BUTTON1` to `12` | Yes |
| Action bar 3 | `actionbars.bar3` | 5 (bottom right) | `MULTIACTIONBAR2BUTTON1` to `12` | No |
| Action bar 4 | `actionbars.bar4` | 3 (right) | `MULTIACTIONBAR3BUTTON1` to `12` | Yes, in the right rail (the owner's picture, LEE-20) |
| Action bar 5 | `actionbars.bar5` | 4 (left) | `MULTIACTIONBAR4BUTTON1` to `12` | Yes, in the right rail (the owner's picture, LEE-20) |
| Action bar 6 | `actionbars.bar6` | 13 (Blizzard's bar 6) | `MULTIACTIONBAR5BUTTON1` to `12` | No |
| Pet bar | `actionbars.pet` | pet actions 1 to 10 | `BONUSACTIONBUTTON1` to `10` | Yes, shown while a pet exists |
| Stance bar | `actionbars.stance` | shapeshift forms 1 to 10 | `SHAPESHIFTBUTTON1` to `10` | Yes, shown when the class has forms. Folded into rows (the layouts write three rows of four), it keeps a full row's width and fills from its bottom left, so up to four forms make one row on the bar's foot, beside the tray card and on its bottom edge, and a fifth starts the row above |

A bar is built the first time it is switched on, so a bar that stays off costs nothing. Each bar is a plain holder frame registered with `KstyleUI.Layout.Register` as a scalable element, with the label and default position from `Setup.Layouts`. The holder's child is a `SecureHandlerStateTemplate` header, and the buttons are the header's children, so Layout owns the holder's position, scale, opacity and shown rule while the module owns the header's visibility, paging and fade.

When the module starts it reparents `MainActionBar`, `MultiBarBottomLeft`, `MultiBarBottomRight`, `MultiBarRight`, `MultiBarLeft`, `MultiBar5`, `MultiBar6`, `MultiBar7`, `StanceBar` and `PetActionBar` to a hidden frame through `KstyleUI.Safe.HideBlizzard`. Turning the module off restores them through `Safe.RestoreBlizzard`. The possess bar stays native, with shared icon chrome and a Layout Mode mover; the shaman totem bar (`MultiCastActionBarFrame`) is left alone. Blizzard's leave-vehicle button is a child of `MainActionBar` and hides with it, so `Vehicle.lua` puts a KstyleUI leave button beside bar 1 while `CanExitVehicle()` is true. Medallions places it below the left slab, aligned with its outermost slot, at the rendered slot size and clear of the experience strip; Frames places it beyond the stance bar when forms are active, and Orbs places it beyond the power orb rim. It is an action slot (`Widgets.Slot`, bar 1's fill and rim, the close glyph in its well; KSTY-60 item 26 found the old kit button a flat steel-blue tile): `VehicleExit` and `TaxiRequestEarlyLanding` are not protected, so it shows, hides and works immediately in combat. The plain leave button stays at full opacity in a vehicle, independent of bar 1's opacity, fade and hidden state.

## Buttons

Each button is `KstyleUI.Widgets.IconButton` built on `SecureActionButtonTemplate`, with the kit's `silent` option so a key press does not click.

| Kind | Attributes | Clicks |
| --- | --- | --- |
| Action | `type = "action"`, the button's ID 1 to 12, `useparent-actionpage`, `checkselfcast`, `checkfocuscast`, `checkmouseovercast` | `AnyUp` and `AnyDown`; mouse clicks act on release, bindings follow `ActionButtonUseKeyDown` |
| Pet | `type = "pet"`, `action` = the slot, `type2 = "click"`, `clickbutton` = `PetActionBar.actionButtons[slot]` | Right-click forwards to Blizzard's pet button through `SECURE_ACTIONS.click`, never by calling an autocast toggle |
| Stance | `type = "click"`, `clickbutton` = `StanceBar.actionButtons[slot]`; the spell ID is retained for change detection | Blizzard's secure stance click selects or cancels the form, including stealth |

| State | Source |
| --- | --- |
| Icon | `C_ActionBar.GetActionTexture`, passed to `SetIcon` untouched (a secret file ID included) |
| Cooldown sweep | `C_ActionBar.GetActionCooldownDuration` into `Cooldown:SetCooldownFromDurationObject`. Without it, `GetActionCooldown` when its values are not secret. |
| Charges | The kit's charge cooldown with `GetActionChargeDuration` while `GetActionCharges().isActive`, only for actions whose `maxCharges` is above 1 |
| Count | `C_ActionBar.GetActionDisplayCount`, passed to the text untouched |
| Macro name | `C_ActionBar.GetActionText` when `UsesActionText` |
| Proc glow | `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` and `HIDE` for spells and spell macros, and `C_SpellActivationOverlay.IsSpellOverlayed` on each update. The socket shows it as a gilt rim and a glow inside the icon (see [Lumen sockets](#lumen-sockets)). |
| Usable and power | `ACTION_USABLE_CHANGED`, and `IsUsableAction` on each update. Unusable greys the button; lacking power desaturates the icon, tints it with the power colour (the cool token by default) and dims it to 70%. |
| Range | `C_ActionBar.EnableActionRangeCheck` for each slot with an action on a shown button of a shown bar, released when the slot, the bar or the module goes, and `ACTION_RANGE_CHECK_UPDATE`. A target change also polls `IsActionInRange`. Out of range tints the icon and the keybind text with the range colour. |
| Selected | `IsCurrentAction` or `IsAutoRepeatAction` |
| Empty | A dark kit tile at full alpha, with its bold white key, including in combat. **Show empty buttons** still hides it when switched off; holding an action (`ACTIONBAR_SHOWGRID`) shows every drop target. Only alpha changes, so the secure button keeps its size and place in combat. LEE-20 supersedes the former 0.35/0.12 fade. Bars 4 and 5 are the exception (KSTY-34, the owner's ruling that the rail's 23 empty squares do not draw): their **Show empty buttons** defaults to off, so an empty slot there draws nothing at rest, and shows while an action is held (`ACTIONBAR_SHOWGRID`) and while Layout Mode is open (`Layout.Enter` and `Layout.Exit`); a filled slot always draws. |

A secret value is never compared: a secret flag counts as its safe default (usable, in range, not selected), and a secret count or text goes to the font string untouched. A slot the client does not have, such as page 13 on a client with fewer slots, is found once with `pcall(C_ActionBar.HasAction, slot)` and logged, and its button stays empty.

Drag and drop works out of combat only. With **Lock Action Bars** on (`lockActionBars`), dragging needs the pick-up modifier, as Blizzard's bars do. `PickupAction`, `PlaceAction` and `PickupPetAction` never run in combat.

Hover keybinds go through Blizzard's own Quick Keybind mode (`Blizzard_QuickKeybind`, which Edit Mode's and the keybinding settings' buttons open, and `/kstyle bind` shows out of combat). Each KstyleUI button carries `commandName`, its slot's binding command (`ACTIONBUTTON3`, `BONUSACTIONBUTTON2`), and Blizzard's `QuickKeybindButtonSetTooltip`; while the mode is on, entering a button calls `QuickKeybindFrame:SetSelected(commandName, button)` and leaving clears it, so the next key pressed binds that slot, as it does over Blizzard's buttons, and `UPDATE_BINDINGS` mirrors the new key onto the button.

## Frames tray

Action Bars > Use the tray releases bars 1 and 2 from the Frames sizing and removes the Frames or Orbs tray when turned off. Use the Medallions slab does the same for Medallions: off exposes every grid control on both bars while keeping their shared button skin. Both switches default on. With the slab on, each side holds up to twelve buttons in one row; either size slider scales both sides, and keybind, count, macro, cooldown and fade controls remain available. The page explains why socket spacing, rows, fill, growth, splitting, empty slots and backing are hidden until the slab is off.

Every free bar, including bar 3, pet and stance, uses the same Buttons, Rows, Fill order, Growth, Button size, Spacing, Backing and Fade controls. Twelve buttons in two rows means six buttons per row. Pet and stance default to Rows 0 and Spacing -1, which retain their current style's layout; choose positive rows or nonnegative spacing to override it. Combat queues geometry changes until combat ends; text visibility, empty slots and fade update immediately. Layout footprints and Auto-size cache entries include the configured geometry.

Possession actions inherit bar 1's configuration. The native two-button possess bar keeps its secure cancellation behavior, gets the shared icon skin, and can be moved as Possess in Layout Mode; it does not receive the free-bar grid controls.

The Frames HUD style's tray is one card behind bars 1 and 2, as the KSTY-44 mock-ups draw it (style-B-frames-*, detail-B-unit-frames-and-tray). `Tray.lua` owns it: a plain frame on bar 1's holder, below the headers, wearing the quest card's chrome (`Widgets.Chrome` with the `card` shape, so the selected card material and its corner brackets), anchored 10.6875 units (9 px at 1080p, `Layouts.TRAY_PAD`) outside bar 2's top left and bar 1's bottom right. The bars take the mock-up's 38 px tiles 3 px apart (45.125 and 3.5625 units); the card spans 602.06 by 115.19 units, its bottom 47.5 units over the screen's bottom edge. `Layouts.TRAY_TOP`, `TRAY_BOTTOM`, `TRAY_WIDTH` and `TRAY_PAD` publish its edges, so the player and target block stands over its top and the experience strip under its bottom.

The card shows while bars 1 and 2 stand stacked: both shown and steady (no fade, no mouseover rule, the same combat and idle opacity), their left and right edges within one physical pixel, bar 2 straight above bar 1 within two gaps. Any other arrangement hides it, and `Tray card` in the settings (on by default) turns it off. This original card-only setting keeps its saved meaning; the separate default-on `Use the tray` switch frees sizing and removes either style's tray. It follows the bars' holders, so it moves and scales with bar 1; it is re-placed only when the pair or a settings pass changes, never on a per-event update. The pet and stance bars stand beside it on its bottom edge, three rows of four, and the leave-vehicle button keeps the pad's distance from it. `Tray on the centre column` (on by default, the finish plan's G6) draws bars 1 and 2 with 37.6-unit buttons 3.6 apart, so the twelve span the 491-unit column the unit bars and the experience strip share. Each row keeps its 45.125-unit slot, bar 1's buttons at its top and bar 2's at its bottom, so the layout, the scale fit and the rows' one-gap spacing do not move, and the card wraps the buttons. Off draws the KSTY-44 tiles again. The forged row ornament (finials and keystone) that once framed the pair is gone: the bible allows ornament at card corners only (KSTY-44, section 3.3).

## Lumen sockets

Every action, pet, stance and flyout button is the kit's shared [`Slot`](../Core/Widgets/README.md#slot), the slot KSTY-46's Orbs tray places too. `Socket.Decorate` wraps each action button's `Paint` and `Restyle`, and the preview's buttons, to add only ability state; the body, rim, bevel, well, key, cooldown edge and number, and the hover, press, proc and ready motion are the slot's.

| State | Socket |
| --- | --- |
| Rest | With **Accent** on **Quiet rim** (the default), the rim is the `quietRim` token, the slot's lit `slotRim`. Hover lays the slot's lighter ring over it by an animation group. Gold is kept for the proc. The other accents keep the kit's accent rim. |
| Keybind and count | The keybind sits 3 units in from the top left, left-justified; the count stays at the bottom right. |
| Cooldown | The kit's radial swipe with the slot's lit edge, and the countdown centred on the icon. |
| Press | The slot's press flash, once per key or mouse press, on its way down. |
| Proc | A rim in the `gilt` token, the slot's gilt glow inside the icon and its gilt halo past the slot, breathing between 1 and 0.45 at 0.7 seconds a breath (a `BOUNCE` animation); with reduced motion it holds still. The KSTY-44 mock-ups draw the halo past the slot, and Lee approved them on 2026-11-12, so the earlier rule that nothing reaches past the socket is replaced. |
| Out of range | The range colour on the icon and on the keybind text. |
| No resource | Desaturated, the power colour (the `cool` token), dimmed to 70%. |
| Empty | 35% at rest, 12% in combat, full under the pointer and while an action is dragged. Only alpha changes. |

`Socket.TOKENS` names the three tokens the sockets read: `gilt` (`giltLit`), `quietRim` (`slotRim`) and `cool` (`rare`). They change in that one table.

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

- Every action, pet and stance button uses the wrap to distinguish the synthetic `Keybind` click from pointer clicks. With `Safe dragging` on (the default), pointer clicks set `useOnKeyDown` to false; binding clicks clear it so the game CVar still decides their timing, then forward as `LeftButton` for native delegates. The wrap reads action slots with restricted `GetActionInfo`; ordinary actions continue to the secure template.
- For a flyout, key down or mouse release lays out one button per spell beside the owner, in the bar's `flyoutDirection` (up from a bottom bar, down from a top one, inward from a side column), shows the frame and returns `false`, so the action never reaches Blizzard's code. The other half is swallowed. A second click on the owner closes it, and it closes itself once the pointer has been away for a second (`RegisterAutoHide`).
- Each flyout button casts its spell (`type = "spell"`) and closes the flyout on release.
- `Flyout.Refresh` stores each flyout's known spells on the frame as attributes, out of combat: the flyouts from `C_Flyout.GetNumFlyouts` and `GetFlyoutID`, and any flyout on an action slot. Like Blizzard's action-bar flyouts it keeps only the highest known rank of each spell. It runs at Enable, on `SPELLS_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE` and `SPELL_FLYOUT_UPDATE`, and when a slot gains a flyout it does not know. Slots cannot change in combat, so every flyout bar 1 can page to is known before combat starts.

A flyout action shows a small chevron on the edge it opens from.

## Keybinds

`Bindings.lua` reads `GetBindingKey` for each shown button's Blizzard binding name and points every key at the KstyleUI button with `SetOverrideBindingClick(owner, false, key, buttonName, "LeftButton")`. It clears and rebuilds them out of combat on `UPDATE_BINDINGS`, a settings change or a gamepad transition; in combat the old bindings keep working until the queued rebuild runs. The player's own bindings are never changed: the override bindings sit on top of them and vanish when the module or the bar turns off. The hotkey text is `ShortKey` of the first key, such as `S1` for Shift-1 and `M4` for mouse button 4, with `GetBindingText(key, true)` for a key it does not know.

## New spell ranks and new spells

`Ranks.lua` puts a newly learned rank on the bars. `LEARNED_SPELL_IN_SKILL_LINE` queues the spell, and half a second later the module checks the batch against action slots 1 to 180 with `GetActionInfo`. Those slots cover every page, so bar 1's stance, form and stealth pages count too: a warrior's stance bars are slots 73 to 108. A slot holds a lower rank when its spell has the same `C_Spell.GetSpellName` and a lower number in `C_Spell.GetSpellSubtext`, such as "Rank 2". The module skips a secret name, rank text or slot. When the player learns two ranks of one spell together, the higher rank wins. A spell whose text has not loaded yet, which `C_Spell.GetSpellSubtext` returns as an empty string, is not skipped: when `C_Spell.IsSpellDataCached` says the data is not cached (or the API is missing), the module calls `C_Spell.RequestLoadSpellData` and checks the spell again when `SPELL_DATA_LOAD_RESULT` reports it with `success`. A spell is requested once per learn, at most 20 spells load at once, a failed load drops the spell, and a result with a secret spell ID is ignored. Without `RequestLoadSpellData` the spell is skipped and logged once. Forever's own `SpellMixin:ContinueOnSpellLoad` is not used: its `SpellEventListener` comes from `AsyncCallbackSystem.lua`, which `Blizzard_ObjectAPI.toc` loads only for the mainline game type. `SPELLS_CHANGED` is not used, because it does not say which spell is new, and scanning the bars on it would offer ranks a player keeps low on purpose. The **New spell ranks** setting picks what happens. **Ask**, the default, shows a KstyleUI dialog that lists each new rank with its icon and has **Update bars** and **Not now** buttons. A rank learned while the dialog is open joins it. **Update automatically** swaps with no dialog, and **Off** does nothing. Tests: `Tools/regression/test-actionbars-ranks.lua`.

The swap runs out of combat only. For each slot that still holds the old rank, it calls `C_Spell.PickupSpell` with the new rank, then `PlaceAction(slot)`, then `ClearCursor()`. `PlaceAction` swaps the old rank onto the cursor and `ClearCursor` drops it, so the old rank never lands anywhere. The module then reads each slot again and logs once for a slot that did not take the new rank. **Update bars** in combat queues the swap through `Combat.Queue` and says so in a second dialog. While the cursor holds something, such as an item the player is moving, the swap waits and checks again every second. A waiting swap holds only the ranks the player approved, and choosing **Off** cancels it. Macros, flyouts, the pet bar and the stance bar's form buttons never change, because only slots whose action type is `spell` qualify.

The neighbouring **New spells** setting defaults to **Ask** and also offers **Always add** and **Never**. A newly learned active spell absent from every action page joins the same dialog, under **New spells**, with an **Add new to bars** button. Passives, professions, off-spec and future spells, flyouts, and higher ranks of spells already on the bars are excluded. Only buttons for the pending kinds appear; choosing one leaves the other kind available, while **Not now** dismisses both. Learning in combat collects the batch until combat ends before showing the dialog. Accepting a dialog just as combat starts also waits for combat to end.

Addition checks the spellbook and all action pages again, then fills bar 1 followed by bar 2 in visible row order, left to right. It uses each button's current page slot, including bar 2's page 6 (slots 61–72), and skips disabled or hidden bars and buttons beyond the configured count. Existing actions, including items and macros, are never replaced. A busy cursor waits; a full pair of bars reports no room and asks the player to make space and drag spells from the spellbook.

Forever already auto-pushes spells: KstyleUI leaves `AutoPushSpellToActionBar` untouched and never duplicates a spell the client places, including a push after the offer opens or while an approved addition waits. At UI-source commit `9dc84f0`, `Blizzard_NewPlayerExperience/Blizzard_TutorialWatchers.lua` toggles that CVar and `Blizzard_FrameXML/IconIntroAnimation.lua` receives `SPELL_PUSHED_TO_ACTIONBAR` with the native destination slot. `Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua` proves `LEARNED_SPELL_IN_SKILL_LINE` (the replacement for the deprecated `LEARNED_SPELL_IN_TAB`), `SPELLS_CHANGED`, `FindSpellBookSlotForSpell` and `GetSpellBookItemInfo`; `Blizzard_PlayerSpells/SpellBook/Blizzard_SpellBookFrame.lua` consumes the learn event. Profession spellbook ranges come from `GetProfessions` and the `numSpells`/`spellOffset` returns of `GetProfessionInfo`, as used by `Blizzard_ProfessionsBook/Camelot/Blizzard_ProfessionsBook.lua` and `Blizzard_ProfessionsBook/Blizzard_ProfessionsBook.lua`. `Blizzard_SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.lua` proves that the spell ID is the fourth `GetCursorInfo` return. Missing or secret eligibility data skips addition safely. Render: `bash Tools/render/shoot.sh actionbars_spells --ppu 1 --strict`; behaviour: `test-actionbars-ranks.lua`.

## Gamepad mode

`IsGamepad` compares `C_InputInterfaceStyle.GetCurrentStyle()` with `Enum.InputDeviceInterfaceType.Gamepad`. In gamepad mode every bar's visibility driver is `hide` and the override bindings are cleared, so Blizzard's gamepad bars own the screen and the pad's keys. `INPUT_DEVICE_INTERFACE_TRANSITION` reruns this, through `Combat.Queue` in combat. The module never names a frame or function of `Blizzard_GamepadActionBars`; `test-actionbars.lua` checks every name that addon defines against this folder's code.

## Settings

The page starts with **Bar to edit**, a picker that shows one bar's rows at a time. Each bar's rows carry `scope = { key = "editBar", value = <bar> }`, so the settings search finds every bar's rows, whichever bar is picked.

| Per bar | Values |
| --- | --- |
| Show this bar | On for bars 1, 2, 4 and 5, the pet bar and the stance bar |
| Buttons, Rows | 1 to 12 (10 for the pet and stance bars). The columns follow from the two. By default each bar takes the rows its layout element plans (`Setup.Layouts.Grid`): bar 1 one row, bars 2 and 3 one row each (their slots stack over bar 1), bars 4 to 6 one column of twelve (bars 4 and 5 stand as two columns in the right rail under the story slot, bar 6 a third column beside them: the owner's picture, LEE-20, replaced #208's columns left of the rail), the pet and stance bars three rows of four beside the tray card (two rows of five reached far enough out to close the chat-side column that Blizzard's tracked buff icons fall back to), and the stance bar grows up. |
| Fill order, Growth | Along rows or down columns first; right or left, then down or up |
| Button size, Spacing | 16 to 64 and 0 to 16 units. 45.125 and 3.5625 for bars 1/2 (the tray); 38 and 3 for bar 3; 36.7 and 4.6 for the rail's bars 4 to 6 as well (LEE-69: the picture's 64 px slots at a 72 px pitch, the same as the centre rows); 30 and 3 for pet/stance. |
| Show empty buttons, Backing strip, Fade until hovered, Faded opacity | On (off on bars 4 and 5), off, off, 0. Lumen's sockets float with no band behind them; the backing strip is the v3 mockup's band behind each bar row, measured in the theme spec: the opaque `buttonFill` body with the panel's light edge line, 10-unit chamfered ends, 3 units beyond the buttons on every side, a child of the bar's header so it fades with the bar |
| Keybind text, Count text, Macro names, Cooldown numbers | On, on, off, on; the keybind at 12 and the cooldown number at 19, the mock-ups' sizes in a 45-unit tile |
| Paging (bar 1) | Stances and forms, Stealth, Possess and vehicles, Page keys: all on |
| Custom paging (action bars) | Empty |

Shared rows: the font, size and outline of each of the four texts (the size is multiplied by the Appearance page's text size), the accent (the quiet rim, the default, or the interface accent, the class colour or a custom colour), the out-of-range and not-enough-power colours, and when tooltips show. Position, scale, opacity in and out of combat, strata and the shown rule come from Layout, on the same page under **Positions and sizes**.

## Why

- **Own secure buttons, not Blizzard's.** Writing to Blizzard's action buttons, or reusing them, taints Blizzard's action dispatch and its gamepad bars for the whole session. KstyleUI's buttons are its own `SecureActionButtonTemplate` buttons, so nothing KstyleUI writes ever reaches a Blizzard button.
- **Paging in the header, not in Lua.** The page has to change in combat, when Lua may not set attributes on a secure frame. The state driver and the restricted snippet change `actionpage` securely, and the buttons read it when they are clicked, so a key can never cast an action from a page the button does not show. Lua only follows along to redraw.
- **Possess and vehicles resolve like Blizzard.** The snippet asks the same questions in the same order as `ActionBarController_UpdateAll`, so bar 1 shows what Blizzard's main bar would have shown.
- **Override bindings, mirrored.** The player sets keys in Blizzard's keybinding settings as always. Override bindings leave those bindings untouched and disappear with the module, so turning KstyleUI off can never lose a keybind.
- **A holder and a header.** Layout shows, hides, fades and moves the holder; the module shows, hides and fades the header. Neither ever undoes the other.
- **Alpha for empty buttons.** A protected button cannot be shown or hidden in combat, but its alpha can change, so a page change in combat can still hide empty slots.
- **Fonts on the module, toggles on each bar.** One font change restyles every bar, which is what a player changing the keybind font wants; each bar still chooses which texts it shows.
- **Safe dragging is on by default.** Mouse clicks act on release so a drag starts before any action can cast. Keys retain `ActionButtonUseKeyDown`. Action Bars > Bars > Safe dragging restores the old mouse timing when switched off. Action and pet pickups retain the lock modifier and combat guards; stance buttons remain non-draggable and keep their native form selector.
- **A flyout of our own.** Blizzard's spell flyout expects Blizzard's button mixins and runs secure code on the button it opens from. A secure wrap and a small flyout frame of KstyleUI's own keep flyouts working in combat without KstyleUI code ever running inside Blizzard's flyout.
- **Bars 3 and 6 start off; bars 4 and 5 start on.** The owner's picture (2026-11-09, LEE-20: "let the picture win") draws bars 4 and 5 as two columns of twelve in the right rail with every slot shown. Bars 3 and 6 are one switch away, and their Blizzard keybinds keep working on Blizzard's hidden buttons until the player turns them on.

## Medallions slab

The Action Bars page has four independent, default-on finish choices. **Quiet empty sockets** draws empty Medallions action, pet and stance sockets at 0.4 alpha, restoring full opacity while dragging, binding or editing the layout. **Quieter cooldowns** removes the global cooldown edge, uses the softer three-quarter-size edge for real cooldowns and charges, and keeps cooling icons at 0.65 brightness. **Readable countdowns** centres an outlined number at 42% of the slot size, keeps the key label inside the top-left corner at the text floor, and dims it to 0.6 during a real cooldown; one engine rule formatter supplies bare seconds, minute labels and hour labels capped at 9h without reading timer text. **Seat the crest** uses a 123-unit canvas and a two-unit metal lip. Switching each choice off restores its earlier appearance.

Under the Medallions HUD style (KSTY-87 and KSTY-88, Lee's rulings of 2026-11-15, LEE-1543 and the KSTY-110 polish of 2026-11-16), bars 1 and 2 are the two groups of one action slab: one row of twelve each on every screen (Lee's v0.2.0 report: one row, as the mock-up). Every slot is a 42-unit recessed socket at a 5-unit gap at 21:9 and wider; at 16:9 the socket shrinks to 33.5 units with the gap and the icon inset scaled by the same share, the largest that keeps both groups, the hub and the pet and stance slabs clear of the chat, the micro menu and the data strip without lowering the game's automatic HUD size on any CREW screen (`Layouts.MEDALLIONS_SLOT`, with a 33-unit floor after pixel snapping; `Slab.Size` and `Slab.Spacing` scale them by the share a player gives the bar's own size). Keybinds are 11 units with Readable countdowns on (10 with it off) with an outline inside the slot's top-left corner (`Slab.TextSize`, `Slab.TextFlags`), and the count, macro and cooldown texts still scale with the slot down to the text floor. The pet and stance bars stand in two rows of five, 30-unit sockets at a 4-unit gap, each in its own small slab 12 units outboard of the action slab and on its lower edge (`Layouts.MEDALLIONS_SIDE`): the pet bar left and the stance bar right at 21:9 and wider; at 16:9 both stand right of the slab, the stance slab sitting on the pet slab, so nothing sits between the chat and the slab and the stance slab stays under the micro menu (`test-layout-medallions` holds it clear of the micro menu, the data strip, the bags and the damage meter). `Layouts.lua` places the groups on one baseline with `MEDALLIONS_HUB_GAP` (158) between them and the experience strip along the slab's lower edge (`Layouts.MEDALLIONS_SLAB`: a 9-unit pad above the sockets, then 3 units, the 3-unit strip and a 3-unit lip below them).

`Slab.lua` draws one connected piece: the slab (the `medActionSlab` slice, else a dark tile) encloses both groups and the strip, and the crest hub sits in the gap, its centre on the slots' top edge and its frame level 8 over the slab, so it draws over the strip and the slab passes behind it. The hub has no wings (Lee, 2026-11-16, KSTY-110 decision 1): from the back it is the class glow (peaking at 0.43), the dark socket (118 units), the crest (a 123-unit canvas with Seat the crest on, or up to 150 units with it off, capped with its pulse and bloom to the original 256 px bake, full colour and alpha at rest and in combat, clipped with its bloom to the circular 118-unit opening), the gunmetal ring (`medRingLarge`, 150 units with a 16-unit band), the rune line inside it in the class colour at 0.35 (`medEnamelLarge`), the turning runes at 0.25, and the round 18-unit level badge on the ring's foot. The strip's holder (DataBars) moves to strata `LOW` under Medallions so the hub draws over it. `test-actionbars-medallions-slab` holds the rows, the socket, gap and icon inset, no gap between the slab, the hub and the strip at rest and in combat, and the pet slab's place, at every CREW screen.

- **Slots draw above the hub.** The slab, the side slabs and the hub, with its ring, runes, glow, sheen, particles, burst and badge, draw at strata `LOW`; the slots and everything on them inherit the root's `MEDIUM`. The hub scales down to fit a gap narrower than its ring plus 4 units each side, so no part of it covers a slot. The level number draws one sublevel above the badge on the same frame (`OVERLAY` 4 over 3), so the badge never hides it. `test-actionbars-medallions-hub` holds all three at every CREW screen.
- **Sockets.** Under Medallions an action, pet or stance slot hides its own chrome and wears the socket: the opaque well (`medSlotSocket`, else the `medSocket` colour) behind the icon, the icon inset 3 units and cropped 8% each side, and the socket's frame (`medSlot`) over it with its rounded opening, plus the highlight, pushed and checked overlays. A slot with no action (`C_ActionBar.HasAction` plain false; a secret answer counts as an action) shows only the socket, with no keybind (`Slab.Keybind`).
- **The crest** comes from `KstyleUI.Medallions.Crest("player")` (its first return, with the second as the bloom), else a placeholder.
- **Motion** is AnimationGroups only: the runes turn (Rotation, 90 s a turn, 2.25 times faster in combat through `SetAnimationSpeedMultiplier`), the glow and bloom breathe (Alpha 0.28 to 0.43, 4.2 s), a sheen crosses the crest every 6 s, and 5 particles rise at rest, 10 in combat. `PLAYER_REGEN_DISABLED` fires the shockwave, crest flash and a light sweep along the slab both ways. `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` draws a 2-unit border in the class colour inside the socket (`medSlotChecked`), starts the class's flipbook clipped to the socket's opening, and pulses the crest and the rune line; `SPELL_ACTIVATION_OVERLAY_GLOW_HIDE` stops them, and the slot's own gilt halo stays off. `PLAYER_LEVEL_UP` writes the level, turns the badge gold and plays the burst. Each piece asks `KstyleUI.Effects.Allows(kind)` (ambient, flare, particle or pulse) and follows `EffectsLevelChanged` when the effects layer is loaded, else maps the motion setting the same way: Full plays everything, Calm keeps the rune turn, breathing and sheen and every one-shot flare but holds the slot loop still and shows no particles, Off keeps the hub still.
- **Textures** are M3's `med*` tokens; until they exist each falls back to an existing texture.
- **The effects layer** (`SlabEffects.lua`, [medallions-effects.md](../docs/medallions-effects.md)): a proc holds its slot and adds the class's 3D model at the hub; a level-up adds the level-up model over the 2D burst; while either holds the hub its sheen and particles pause. A slot's ready flash is a steel flash that yields to a proc, and the hub's rune glyphs light while the player's resource is capped.
