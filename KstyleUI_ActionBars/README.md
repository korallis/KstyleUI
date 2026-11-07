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
- Compact layout: two rows of 12 buttons of 34 units at the 1080 reference, 3-unit gaps, no name labels. Keybind, stack and cooldown text sit on the button.
- Blizzard's bars are reparented to a hidden frame through `KstyleUI.Safe.HideBlizzard`. The module never touches `Blizzard_GamepadActionBars`, and switching to gamepad mode must not error or taint.
- Protected work in combat goes through `KstyleUI.Combat.Queue`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `ActionBars.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Why
