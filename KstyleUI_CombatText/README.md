# KstyleUI_CombatText

Animated damage and heal numbers on KstyleUI frames and plates, and the KstyleUI font for the game's own world numbers.

| Field | Value |
| --- | --- |
| Module name | `CombatText`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Mirror |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_CombatText.toc` lists `CombatText.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- World numbers: set `DAMAGE_TEXT_FONT` to the KstyleUI font while the module is on. The change takes effect at the next login, not after a reload, and the options say so.
- Frame numbers come from `UNIT_COMBAT`. Amounts pass straight to `FontString:SetText` through `AbbreviateNumbers`, so Lua never compares or adds them. A unit type whose events do not fire gets no frame numbers.
- No `COMBAT_LOG_EVENT_UNFILTERED` and no `CombatLogGetCurrentEventInfo`: the combat log is closed to addons.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `CombatText.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Why
