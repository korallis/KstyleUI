# KstyleUI_Options

The settings window: category rail, search, option cards, live preview and the Layout Mode button. It is registered as a canvas category in Blizzard's Settings panel and opened by `/kstyle`.

| Field | Value |
| --- | --- |
| Module name | `Options`: its switch in `Core/Features.lua` |
| Approach | Our own window |
| Loads | On demand: the settings window when the player opens it |
| Files | `KstyleUI_Options.toc` lists `Options.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Every page is built from the schemas modules declare through `KstyleUI.Options.Register` and from the elements registered with `KstyleUI.Layout.Register`, so search covers every setting.
- The window follows `docs/design/mockups/04_settings_druid.jpg` and is built entirely from `KstyleUI.Widgets`.
- Option help text is one short sentence, under 100 characters.
- Windows handle Escape with their own key handler, not `UISpecialFrames`.
- The addon is load-on-demand: the core loads it the first time the player opens the settings window, so it costs nothing before then.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Options.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Why
