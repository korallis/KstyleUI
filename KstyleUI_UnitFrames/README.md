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

## Why
