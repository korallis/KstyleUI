# KstyleUI_Skins

Character sheet, spellbook and talents, quest log and objective tracker, world map, game menu, group finder, mail, merchant, trainer, professions, social windows, Legacy, loot, popups and ready check.

| Field | Value |
| --- | --- |
| Module name | `Skins`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin, one window per task |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Skins.toc` lists `Skins.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- Windows handle Escape with their own key handler, not `UISpecialFrames`.
- Blizzard frames keep a reskin after `Disable`, so turning the module off asks the player to reload.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Skins.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Why
