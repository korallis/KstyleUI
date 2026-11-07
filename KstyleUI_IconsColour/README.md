# KstyleUI_IconsColour

Icon set B: full-colour painted art for every ability.

| Field | Value |
| --- | --- |
| Module name | `IconsColour`: its switch in `Core/Features.lua` |
| Approach | Data addon |
| Loads | On demand: when the player turns on custom icons |
| Files | `KstyleUI_IconsColour.toc` lists `IconsColour.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- The addon holds data only: a table from icon file ID to texture path that `KstyleUI.Icons` reads. It creates no frames and registers no events.
- Icons are 128x128 PNG.
- Every icon has a row in `Media/PROVENANCE.md`: model, prompt, seed if available, date and the file ID it replaces.
- Strings go through `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `IconsColour.xml`.

## Why

- The data format and the core service that reads it are documented in [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#coreiconslua). This addon sets `set = "B"`.
- The `IconsColour` switch is not used: the `Icons` module's `set` setting picks set B, and the `Icons` switch turns custom icons on.
