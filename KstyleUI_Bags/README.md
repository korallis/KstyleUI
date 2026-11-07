# KstyleUI_Bags

Combined bags and bank, keyring, search, sort, quality borders and selling junk.

| Field | Value |
| --- | --- |
| Module name | `Bags`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Bags.toc` lists `Bags.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Protected container calls such as `C_Container.UseContainerItem` and `C_Container.PickupContainerItem` go through `KstyleUI.Combat.Queue` in combat.
- Windows handle Escape with their own key handler, not `UISpecialFrames`.
- Blizzard frames this module replaces are hidden only through `KstyleUI.Safe.HideBlizzard`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Bags.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Why
