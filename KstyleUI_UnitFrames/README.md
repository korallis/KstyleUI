# KstyleUI_UnitFrames

Player, target, target of target, focus, focus target, pet and boss 1 to 5. Portraits (switchable), cast bars, frame auras, class resources, threat glow, raid markers, leader and role icons.

| Field | Value |
| --- | --- |
| Module name | `UnitFrames`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_UnitFrames.toc` lists `UnitFrames.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Unit frames use `SecureUnitButtonTemplate` buttons with `RegisterUnitWatch`. Health goes straight to the bar with `SetMinMaxValues(0, UnitHealthMax(unit))` and `SetValue(UnitHealth(unit))`. Health text comes from `UnitHealthPercent` or `AbbreviateNumbers`, never from Lua arithmetic. Bar colours that depend on health come from `C_CurveUtil` colour curves. Incoming heals come from `CreateUnitHealPredictionCalculator`. Range fade uses `SetAlphaFromBoolean`.
- Combo points draw as one-point status bars, so the comparison happens in the engine.
- Cast bars use `StatusBar:SetTimerDuration` with the duration object from the cast APIs. Casts by units other than the player and pet can be secret, so the bar never reads the spell name except through widget setters.
- Auras use the AuraContainer engine (`CustomAuraContainerTemplate`, aura groups and filter strings). Never scan auras by index while `C_Secrets.ShouldAurasBeSecret()` returns true. Aura data turns secret during a boss pull before `InCombatLockdown()` returns true.
- Player and target frames are 220 by 46 units with 46-unit portraits at the 1080 reference, centred above the action bars on either side of the Cooldown Manager. Portraits are on by default, with a switch to turn them off.
- Blizzard frames this module replaces are hidden only through `KstyleUI.Safe.HideBlizzard`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `UnitFrames.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Frames

| Frame | Element key | Unit | Default size |
| --- | --- | --- | --- |
| Player | `unitframes.player` | `player` | 266 x 46: a 46-unit portrait and a 220 by 46 panel |
| Target | `unitframes.target` | `target` | 266 x 46, the portrait on the right |
| Target of target | `unitframes.targettarget` | `targettarget` | 120 x 24, compact |
| Focus | `unitframes.focus` | `focus` | 266 x 70 |
| Focus target | `unitframes.focustarget` | `focustarget` | 120 x 24, compact |
| Pet | `unitframes.pet` | `pet` | 120 x 24, compact |
| Boss | `unitframes.boss` | `boss1` to `boss5` | 266 x 330: five slots of 58 units, 10 apart |

Each frame is a plain holder frame registered with `KstyleUI.Layout.Register` under its key, with the setup's label, `module = "UnitFrames"` and `resizable = true`. The holder carries one `SecureUnitButtonTemplate` button per unit (five for the boss frame). The button has the attributes `unit`, `type1 = "target"` and `type2 = "togglemenu"`, registers for `AnyUp` clicks and is shown and hidden by `RegisterUnitWatch`. Layout moves and sizes the holder; the module anchors the buttons inside it and lays out their parts again whenever the holder's size changes. Hovering a button shows the unit tooltip through Blizzard's `UnitFrame_OnEnter` and `UnitFrame_OnLeave`.

A frame 36 units tall or more is a full frame: the name row on top, the health bar, then the power bar, with the health and power texts in columns to the right of their bars, and a level badge in the portrait's bottom outer corner. A shorter frame is compact: the name and the health text sit inside the health bar, and there is no badge.

## Files

`UnitFrames.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Settings.lua` | `ns.Settings`: the defaults, the choices each setting allows, `Value(kind, key)` (the stored value, or the default with one devlog line when it is not allowed), `Font(kind, element) -> path, size, flags` (the size times Appearance's text size), `Accent() -> r, g, b`, `Snapshot(kind)` (plain values for the geometry) and `Schema()` |
| `Format.lua` | `ns.Format`: `Health(text, unit, format)` and `Power(text, unit, format, powerType)` write the text with `SetFormattedText`, `AbbreviateNumbers` and `UnitHealthPercent` or `UnitPowerPercent` with a 0 to 100 curve, so no secret is ever read. `ColumnWidth(format, size)` is the room a format needs. `Sample` writes plain numbers for the preview. |
| `Geometry.lua` | `ns.Geometry`: `Frame(s, width, height, fontScale) -> parts`, each part `{ x, y, w, h }` from the frame's top left with y growing downward, and `Slots(count, gap, width, height)` for the boss frames. Pure maths, tested without frames. |
| `Style.lua` | `ns.Style`: `New(parent, kind) -> view` builds the parts on a button or the preview, `Layout(view, s, width, height)` places them in whole pixels, `Restyle(view, kind)` applies fonts, textures, fill directions and the accent |
| `Unit.lua` | `ns.Unit`: fills a view from the unit API. `All(view, unit, instant)`, `Health`, `Power`, `HealthColor`, `PowerColor`, `Prediction`, `Name`, `Level`, `Portrait`. |
| `Blizzard.lua` | `ns.Blizzard.Apply(active)`: hides or restores Blizzard's frames |
| `Frames.lua` | `ns.Frames`: the holders and secure buttons, unit watches, events, `Enable`, `Disable`, `Get(kind)` |
| `Preview.lua` | `ns.Preview.Build(parent)`: the settings window's live preview |
| `Module.lua` | Registers the module, the settings page and the `/kstyle test` check |

Tests: `Tools/regression/test-unitframes-settings.lua`, `test-unitframes-geometry.lua`, `test-unitframes-frames.lua` and `test-unitframes-preview.lua`, on the fake units in `Tools/regression/unitframes_env.lua`.

## Settings

The settings page starts with the module-wide settings, then a **Frame to customise** picker. Only the picked frame's rows show, so the page stays short. Every frame has the same settings, under its own key such as `player.healthText`:

| Key | Values | Default |
| --- | --- | --- |
| `hideBlizzard` | Hide Blizzard's frames that KstyleUI replaces | on |
| `accent`, `accentColor` | Portrait ring and badge colour: `class` (the KstyleUI accent) or `custom` | `class` |
| `edit` | The frame the page shows | `player` |
| `<frame>.enabled` | Show the frame | on |
| `<frame>.portrait`, `portraitStyle`, `portraitSide` | Round portrait: on or off; `portrait` (2D) or `class` (class icon); `LEFT` or `RIGHT` | on for player, target, focus and boss; target on the right |
| `<frame>.name`, `nameCaps`, `level` | Name, in capitals; level badge | on |
| `<frame>.healthTexture`, `powerTexture` | Bar texture: KstyleUI's and LibSharedMedia's | Glass |
| `<frame>.healthColor`, `powerColor` | Colour source: `class` (class colour for players, reaction for NPCs), `reaction`, `custom`, and for power `power` (the power type's colour) | `class`, `power` |
| `<frame>.healthCustom`, `powerCustom` | The custom colours | from the tokens |
| `<frame>.healthOrientation`, `powerOrientation` | Fill direction: `RIGHT`, `LEFT`, `UP`, `DOWN` | `RIGHT` |
| `<frame>.healthText`, `powerText` | `percent`, `current`, `currentMax`, `both`, `none` | `percent`; power `currentMax` on the player and target |
| `<frame>.healPrediction` | Incoming heals and absorbs on the health bar | on |
| `<frame>.power`, `powerHeight` | Power bar, 2 to 24 units | on for full frames, 5 units |
| `<frame>.fonts.<text>.font`, `.size`, `.outline` | For the `name`, `health`, `power` and `level` texts: `theme` (Appearance's font) or a font file; 6 to 32 units; `NONE`, `OUTLINE`, `THICKOUTLINE` | `theme`, 11 or 9, `NONE` |

Size, position, opacity, strata and the shown rule come from Layout's element rows under **Positions and sizes**.

## Blizzard frames

With `hideBlizzard` on, each Blizzard frame whose KstyleUI frame is on is hidden with `KstyleUI.Safe.HideBlizzard`, and restored with `Safe.RestoreBlizzard` when the module stops or the setting goes off:

| KstyleUI frame | Blizzard frames |
| --- | --- |
| Player | `PlayerFrame` |
| Target | `TargetFrame` (its target of target, `TargetFrameToT`, is a child) |
| Focus | `FocusFrame` (and its child `FocusFrameToT`) |
| Pet | `PetFrame` |
| Boss | `Boss1TargetFrame` to `Boss5TargetFrame` |

These names come from `Blizzard_UnitFrame/Mainline/TargetFrame.xml`, `PlayerFrame.xml` and `PetFrame.xml` on the `forever` branch, with the `Camelot/` overrides only changing their contents.

## Why

- **One holder per element, buttons inside.** `RegisterUnitWatch` shows and hides the secure button, and Layout's shown rules show and hide the holder, so the two never fight over one frame. The holder becomes protected through its secure children, so Layout queues its changes in combat; the module also re-anchors its buttons only out of combat.
- **The boss frames hide one by one.** `BossTargetFrameContainer` is a managed frame: Edit Mode and the right-side frame manager reparent it back to their container. Its five boss frames are not managed, so hiding each of them stays hidden.
- **Health never reaches Lua.** `UnitHealth` is always secret on Forever. The bar gets `SetMinMaxValues(0, UnitHealthMax(unit))` and `SetValue(UnitHealth(unit))`, the engine eases it, and the text comes from `SetFormattedText` with `AbbreviateNumbers` and `UnitHealthPercent` evaluated through a 0 to 100 curve. Without a curve API the percentage would be a 0 to 1 share, so the text falls back to current and max and the devlog says so.
- **Text columns come from the format, not the string.** A text's width would be secret when its text is, so the room each bar leaves for its text comes from the chosen format and font size. That is why the power bar is shorter than the health bar when it shows current and max, as in the v3 mockups.
- **Fonts belong to the module.** The kit's `Widgets.Text` restyles its texts to their role on every theme change, which would undo a player's font choice. The unit frame texts are the module's own font strings, styled from their settings and restyled on `ThemeChanged`.
- **Target of target and focus target poll.** Unit events never fire for `targettarget` and `focustarget`. Those two frames refresh on `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` and `UNIT_TARGET`, and poll health and power every 0.2 seconds only while their button is shown, as Blizzard's own frames do.
- **One picker, one frame's rows.** Seven frames with the same thirty settings would make a page of over two hundred rows. The page shows the picked frame's rows, and the preview draws that frame.
- **Focus target has its own key.** The element keys had no focus target. It sits under the focus frame, right-aligned, and `test-setup-layouts.lua` checks that it overlaps nothing in any layout.
