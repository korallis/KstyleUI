# KstyleUI_Nameplates

A KstyleUI plate on each nameplate: health, cast bar, threat colour and debuffs.

| Field | Value |
| --- | --- |
| Module name | `Nameplates`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace the visible plate |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Nameplates.toc` lists `Nameplates.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Attach a KstyleUI frame to each plate on `NAME_PLATE_UNIT_ADDED` and fade Blizzard's plate with alpha. Names of non-player units can be secret in combat, so they pass through whole.
- Cast bars use `StatusBar:SetTimerDuration` with the duration object from the cast APIs. Casts by units other than the player and pet can be secret, so the bar never reads the spell name except through widget setters.
- Auras use the AuraContainer engine (`CustomAuraContainerTemplate`, aura groups and filter strings). Never scan auras by index while `C_Secrets.ShouldAurasBeSecret()` returns true. Aura data turns secret during a boss pull before `InCombatLockdown()` returns true.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Nameplates.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Why
