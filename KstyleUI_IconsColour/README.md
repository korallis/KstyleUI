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
- Icons are 128x128 RGB PNG in full colour. The game shows them as they are: set B is never tinted.
- Every icon has a row in `PROVENANCE.md` in this folder: the file ID it replaces, the spells that use it, model, prompt, Higgsfield job and date. The model exposes no seed.
- Strings go through `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `IconsColour.xml`.

## Art

`Tools/icons/iconset.py --set B` makes the set with the same pipeline as set A, described in [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#art). Run it with `~/.local/share/wow-dev/venv/bin/python`, which has Pillow. What differs for set B:

| Step | Set B |
| --- | --- |
| Generate | `iconset.py generate --set B`: one Higgsfield `gpt_image_2_5` image per icon group at `1:1 --resolution 1k --quality high`, with `docs/design/mockups/icons_B_fullcolour.jpg` as the style reference. Each prompt names the spell, its owner, its school and its tooltip, then a palette for the school, then the set B style block. Raw images and records stay in `~/.local/share/wow-dev/icons/B/raw`. The run stops before the credit balance would fall below `--floor`, 60 by default. |
| Check | `Tools/icons/check_icons.py --set B <png>...` runs `judge_colour`. It rejects a blank image, one with too little contrast to read at 32 pixels (`flat`), a black margin round the painting (`frame`), a black gutter across the middle as in a sheet of icons (`grid`), a centre much darker than the edges (`clipped`), and text that macOS Vision reads. A rejected icon is rerolled at most twice. |
| Package | `iconset.py package --set B` writes `Icons/<fileID>.png` as 128x128 RGB, `PROVENANCE.md` and `Data.lua`, and adds `Data.lua` to `IconsColour.xml`. `--no-data` writes the icons and `PROVENANCE.md` only. |
| Review and verify | `iconset.py sheets --set B` and `iconset.py verify --set B`, as for set A. |

An icon group with no accepted image has no entry in `Data.lua`, so the game's icon stays for it.

### Palettes

A palette per spell school keeps the set unified and lets schools tell apart at a glance. A mixed school mask takes its first magic school in the order holy, fire, nature, frost, shadow, arcane, as `KstyleUI.Icons.SchoolColor` does; physical counts only alone. Physical art asks for natural materials with a cool rim light and one accent colour, and no golden glow, so it does not look like holy art. `PALETTES` in `Tools/icons/iconset.py` holds the text.

## Why

- The data format and the core service that reads it are documented in [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#coreiconslua). This addon sets `set = "B"`.
- The `IconsColour` switch is not used: the `Icons` module's `set` setting picks set B, and the `Icons` switch turns custom icons on.
