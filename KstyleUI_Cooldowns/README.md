# KstyleUI_Cooldowns

Blizzard's Cooldown Manager shown in KstyleUI's style: essential cooldowns (40 units), utility cooldowns (30 units), tracked buff icons and tracked buff bars (180 by 18 units), placed in the HUD band.

| Field | Value |
| --- | --- |
| Module name | `Cooldowns`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Mirror, or reskin in place if mirroring cannot work in combat |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Cooldowns.toc` lists `Cooldowns.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Essential cooldowns sit centred above the action bars, utility cooldowns beneath them, and tracked buff bars beside them.
- Build the mirror from `C_CooldownViewer` data and duration objects, check each value with `issecretvalue`, and fall back to restyling Blizzard's viewers in place when the data is unavailable in combat. Log the path taken.
- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Cooldowns.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Why
