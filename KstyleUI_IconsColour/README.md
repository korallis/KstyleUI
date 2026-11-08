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

An icon group with no accepted image has no entry in `Data.lua`, so the game's icon stays for it. Today all 654 spell groups have art, and so do 2617 item groups (see [Items](#items)).

### Repainted from Blizzard's icon

The free paintings above were not recognisable as the abilities they stand for. Every icon group is repainted from Blizzard's own icon with `--mode subject_reference`, the method the owner approved in a pilot on the 116 groups an orc warrior sees and then applied to every class, pet, racial, profession and general group and to the item groups. A group whose repaint failed the check three times keeps its free painting; `iconset.py status --set B --mode subject_reference` lists them as missing. Set A derives its art for every repainted group from the repaint (see [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#derived-from-set-b)).

| Step | Command | What it does |
| --- | --- | --- |
| Extract | `iconset.py extract [--categories item]` | Reads each icon's BLP2 texture from the installed WoW Forever client by file ID with TACTTool (`~/.local/share/wow-dev/casc/TACTTool`, read-only, product `wowf`), decodes it (Pillow for palette and DXT BLPs, `iconset.py` itself for the raw BGRA encoding some item icons use), composites it over black and upscales it to 512 pixels in `~/.local/share/wow-dev/icons/blizzard/<fileID>.png`. Nothing from the client enters the repository; `PROVENANCE.md` records the BLP's sha256. |
| Generate | `iconset.py generate --set B --mode subject_reference [--owner WARRIOR --race Orc] [--categories item] --floor N` | Extracts any icon the cache lacks, then one `gpt_image_2_5` image per group at `1:1 --resolution 1k --quality high` with two image references: the Blizzard icon first (image 1, the subject) and `docs/design/mockups/icons_B_buttons.png` second (image 2, the action-button strip from the design sheet, finish only). The prompt asks for image 1 repainted with the same subject, silhouette, composition, viewing angle, scale and colours, the bevelled frame removed and the art extended to every edge, and nothing added. A group accepted in `style` mode is repainted; its style image stays in the package until a repaint is accepted. |
| Subjects | `Tools/data/icon_subjects.json` | A hand-checked sentence per file ID, added to the prompt only where the reference alone was not enough. |
| Check | `check_icons.py --set faithful` inside `generate` | `judge_faithful`: blank, flat, frame, grid and text as for set B, no off-centre check (Blizzard's composition decides where the subject sits), plus `drift` when the 8x8 light-and-dark layout of the repaint correlates below 0.6 with the Blizzard icon. The pilot's eight repaints scored 0.79 to 0.95; the free paintings scored -0.24 to 0.48. Every result was also compared by eye against its original at 128 and 32 pixels. |
| Package | `iconset.py package --set B` | As above. The provenance row carries the method (`style` or `subject_reference`) and the Blizzard BLP sha256. |

`--owner WARRIOR` keeps the groups a character of that class sees: the class's spells, general spells for `ALL`, every group with a profession skill and every item group; `--race Orc` adds that race's racials. `--categories racial,profession,general` narrows the run further. `--dry-run` lists every group the run would paint, the credit cost before rerolls and the first prompts. The run stops before the balance would fall below `--floor`.

### Items

Items share icons with each other and with spells, so the sets map item icons the same way, by file ID. `Tools/icons/items.py --build 1.60.1.70840` builds `Tools/data/items.json` from the client's `Item`, `ItemSparse`, `ItemClass` and `ItemSubClass` tables (wago.tools, or the folder `--from-dir` names): one group per icon file ID for every item the client has a name for that is not a placeholder (`Monster -`, `OLD`, `Deprecated`, `[PH]`, test items, the deprecated flag). Each group has the category `item`, the most common item name, the item's kind (class and subclass, such as `Consumable (Potions)`), up to six items by ID, the count of all of them, and a rank: the order the generator draws them in, from what a player sees most to least.

| Rank | Items | Groups |
| --- | --- | --- |
| 1 | consumables: potions, food, scrolls, bandages | 681 |
| 2 | trade goods, reagents and recipes | 309 |
| 3 | gear: weapons and armour of every quality | 946 |
| 4 | containers: bags, quivers, ammunition and keys | 70 |
| 5 | quest items | 625 |
| 6 | everything else: junk, mounts, pets, gems, tokens | 243 |

`iconset.py` reads both data files; an icon a spell uses keeps the spell's group (250 item icons are spell icons too), so 2626 item groups need their own art. Within a rank an icon more items share comes first. `generate --categories item` repaints them in that order with the same `subject_reference` method; the prompt says `item icon`, names the item and its kind, and asks for the same object so a player recognises the item instantly. A group that is not repainted yet has no entry in `Data.lua`, so the game's icon stays for it.

On 2026-11-08 every item group was repainted except nine whose texture in the client is a zero-filled placeholder (store mounts and pets such as Crimson Rooster and Verdant Sea Turtle): TACTTool returns an empty file for them, so there is no Blizzard icon to repaint and the game's icon stays. 37 item repaints and nine spell repaints were accepted by eye with `iconset.py accept` after the automatic check rejected them (a dark backdrop read as drift, a gap read as a grid, runic script read as text); their provenance rows say so.

In game, item icons show through `KstyleUI.Icons` wherever a file ID reaches it: the bag and bank slots, KstyleUI's action buttons and tooltips through `Apply`, and Blizzard's item buttons (the character sheet, merchant, trade, mail, quest rewards and Blizzard's own bags) and the loot window through `Core/IconHooks.lua` (see [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#blizzards-icons)).

`Data.lua` defines `KstyleUIIconData` with `set = "B"`, and `IconsColour.xml` loads it after `Init.lua`. Tests: `Tools/regression/test-icons-set-b.lua` loads the real addon through the `Icons` service at login, checks that every path has its PNG, and checks that set B is shown untinted and that a file ID with no art keeps the game's icon.

### Palettes

A palette per spell school keeps the set unified and lets schools tell apart at a glance. A mixed school mask takes its first magic school in the order holy, fire, nature, frost, shadow, arcane, as `KstyleUI.Icons.SchoolColor` does; physical counts only alone. Physical art asks for natural materials with a cool rim light and one accent colour, and no golden glow, so it does not look like holy art. `PALETTES` in `Tools/icons/iconset.py` holds the text.

## Why

- The data format and the core service that reads it are documented in [`KstyleUI_Icons/README.md`](../KstyleUI_Icons/README.md#coreiconslua). This addon sets `set = "B"`.
- The `IconsColour` switch is not used: the `Icons` module's `set` setting picks set B, and the `Icons` switch turns custom icons on.
