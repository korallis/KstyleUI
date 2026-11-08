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
- Every icon has a row in [`PROVENANCE.md`](PROVENANCE.md): the file ID it replaces, the spells that use it, model, prompt, Higgsfield job and date. The model exposes no seed.
- Strings go through `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `IconsColour.xml`.

## Art

`Tools/icons/iconset.py --set B` makes the set with the same pipeline as set A, described in [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#art). Run it with `~/.local/share/wow-dev/venv/bin/python`, which has Pillow. What differs for set B:

| Step | Set B |
| --- | --- |
| Generate | `iconset.py generate --set B`: one Higgsfield `gpt_image_2_5` image per icon group at `1:1 --resolution 1k --quality high`, with `docs/design/mockups/icons_B_fullcolour.jpg` as the style reference. Each prompt names the spell, its owner, its school and its tooltip, then a palette for the school, then the set B style block. Raw images and records stay in `~/.local/share/wow-dev/icons/B/raw`. The run stops before the credit balance would fall below `--floor`, 60 by default. |
| Check | `Tools/icons/check_icons.py --set B <png>...` runs `judge_colour`. It rejects a blank image, one with too little contrast to read at 32 pixels (`flat`), a black margin round the painting (`frame`), a black gutter across the middle as in a sheet of icons (`grid`), a centre much darker than the edges (`clipped`), and text that macOS Vision reads. A rejected icon is rerolled at most twice. |
| Package | `iconset.py package --set B` writes `Icons/<fileID>.png` as 128x128 RGB, `PROVENANCE.md` and `Data.lua`, and adds `Data.lua` to `IconsColour.xml`. `--no-data` writes the icons and `PROVENANCE.md` only. |
| Review and verify | `iconset.py sheets --set B` and `iconset.py verify --set B`, as for set A. |

An icon group with no accepted image has no entry in `Data.lua`, so the game's icon stays for it. Today all 654 icon groups have art.

### Repainted from Blizzard's icon

The free paintings above were not recognisable as the abilities they stand for. The 116 icon groups an orc warrior sees were repainted from Blizzard's own icon with `--mode subject_reference`, the method the owner approved in a pilot: the 79 warrior groups (every spec, stances, shared talents and the general Throw), the orc racials Hardiness, Blood Fury and Shatter Curse (Command shares Demoralizing Shout's icon), every profession skill, including the ones that share another class's icon such as First Aid, and the general spells every class has. The other icon groups still have the free paintings until their class or race is repainted the same way. Set A derives its art for these groups from the repaints (see [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#derived-from-set-b)).

| Step | Command | What it does |
| --- | --- | --- |
| Extract | `iconset.py extract --owner WARRIOR --race Orc` | Reads each icon's BLP2 texture from the installed WoW Forever client by file ID with TACTTool (`~/.local/share/wow-dev/casc/TACTTool`, read-only, product `wowf`), decodes it with Pillow, composites it over black and upscales it to 512 pixels in `~/.local/share/wow-dev/icons/blizzard/<fileID>.png`. Nothing from the client enters the repository; `PROVENANCE.md` records the BLP's sha256. |
| Generate | `iconset.py generate --set B --mode subject_reference --owner WARRIOR --race Orc` | Extracts any icon the cache lacks, then one `gpt_image_2_5` image per group at `1:1 --resolution 1k --quality high` with two image references: the Blizzard icon first (image 1, the subject) and `docs/design/mockups/icons_B_buttons.png` second (image 2, the action-button strip from the design sheet, finish only). The prompt asks for image 1 repainted with the same subject, silhouette, composition, viewing angle, scale and colours, the bevelled frame removed and the art extended to every edge, and nothing added. A group accepted in `style` mode is repainted; its style image stays in the package until a repaint is accepted. |
| Subjects | `Tools/data/icon_subjects.json` | A hand-checked sentence per file ID, added to the prompt only where the reference alone was not enough. |
| Check | `check_icons.py --set faithful` inside `generate` | `judge_faithful`: blank, flat, frame, grid and text as for set B, no off-centre check (Blizzard's composition decides where the subject sits), plus `drift` when the 8x8 light-and-dark layout of the repaint correlates below 0.6 with the Blizzard icon. The pilot's eight repaints scored 0.79 to 0.95; the free paintings scored -0.24 to 0.48. Every result was also compared by eye against its original at 128 and 32 pixels. |
| Package | `iconset.py package --set B` | As above. The provenance row carries the method (`style` or `subject_reference`) and the Blizzard BLP sha256. |

`--owner WARRIOR` keeps the groups a character of that class sees: the class's spells, general spells for `ALL` and every group with a profession skill; `--race Orc` adds that race's racials. `--categories racial,profession,general` narrows the run further. `--dry-run` lists every group the run would paint, the credit cost before rerolls and the first prompts. The run stops before the balance would fall below `--floor`.

`Data.lua` defines `KstyleUIIconData` with `set = "B"`, and `IconsColour.xml` loads it after `Init.lua`. Tests: `Tools/regression/test-icons-set-b.lua` loads the real addon through the `Icons` service at login, checks that every path has its PNG, and checks that set B is shown untinted and that a file ID with no art keeps the game's icon.

### Palettes

A palette per spell school keeps the set unified and lets schools tell apart at a glance. A mixed school mask takes its first magic school in the order holy, fire, nature, frost, shadow, arcane, as `KstyleUI.Icons.SchoolColor` does; physical counts only alone. Physical art asks for natural materials with a cool rim light and one accent colour, and no golden glow, so it does not look like holy art. `PALETTES` in `Tools/icons/iconset.py` holds the text.

## Why

- The data format and the core service that reads it are documented in [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#coreiconslua). This addon sets `set = "B"`.
- The `IconsColour` switch is not used: the `Icons` module's `set` setting picks set B, and the `Icons` switch turns custom icons on.
