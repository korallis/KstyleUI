# KstyleUI_Icons

Icon set A: white light art on black for every ability, tinted in game by class colour, spell school colour or white.

| Field | Value |
| --- | --- |
| Module name | `Icons`: its switch in `Core/Features.lua` |
| Approach | Data addon |
| Loads | On demand: when the player turns on custom icons |
| Files | `KstyleUI_Icons.toc` lists `Icons.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- The addon holds data only: a table from icon file ID to texture path that `KstyleUI.Icons` reads. It creates no frames and registers no events.
- Icons are 128x128 PNG and keep luminance only.
- Every icon has a row in `Media/PROVENANCE.md`: model, prompt, seed if available, date and the file ID it replaces.
- Strings go through `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Icons.xml`.

## Why
