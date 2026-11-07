# KstyleUI_Meters

Damage Meter skin, our own threat meter and a swing timer.

| Field | Value |
| --- | --- |
| Module name | `Meters`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Mirror |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Meters.toc` lists `Meters.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- The swing timer uses Forever's `C_SwingTimer` and the `PLAYER_SWING` event. The combat log is closed to addons.
- Threat values are readable on Forever. `C_DamageMeter` values may turn secret in combat: check each with `issecretvalue` and pass secrets only to widget setters.
- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Meters.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Why
