# KstyleUI Icons: the loose-file icon pack

KstyleUI's repainted ability and item icons ship as a texture pack the game client loads itself, not as part of the addon. Every icon the pack covers is replaced everywhere the game draws it: action buttons, the spellbook, talents, bags, the character sheet, merchants, tooltips, and the buff and debuff tiles, which no addon can change on WoW: Forever because the secure aura engine draws them. The owner chose this on 2026-11-08; the research behind it is at the end.

## Install

1. Download `KstyleUI-Icons-<version>.zip` from the [GitHub release](https://github.com/korallis/KstyleUI/releases). It is a separate download from the addon zip: CurseForge and Wago install addons only, and this pack does not go into `AddOns`.
2. Quit World of Warcraft completely. Loose textures load only at a full start, never after `/reload`.
3. Unzip it. You get one folder, `Interface`, with an `Icons` folder inside it.
4. Copy that `Interface` folder into your Forever flavour folder, so the files land in `World of Warcraft/_forever_/Interface/Icons/`. On a Mac the flavour folder is `/Applications/World of Warcraft/_forever_`. Your `Interface/AddOns` folder is untouched: `Icons` sits beside it.
5. Start the game.

A file in `Interface/Icons` is a loose texture. When the client needs `Interface/Icons/<Name>`, it uses the file on disk instead of the texture inside its own data. The pack's files are named exactly like Blizzard's icons (`Ability_Warrior_Charge.tga`), so the client picks them up for every spell, item, buff and debuff that uses that icon, in every window.

The install script does the same copy and keeps a manifest, so it can remove exactly what it put there:

```bash
python3 Tools/icons/iconset.py pack                                               # Tools/icons/setB/Icons -> ~/.local/share/wow-dev/icons/pack/Interface/Icons (needs Pillow: use ~/.local/share/wow-dev/venv/bin/python)
python3 Tools/icons/iconset.py install --wow "/Applications/World of Warcraft/_forever_" --dry-run   # say what would change
python3 Tools/icons/iconset.py install --wow "/Applications/World of Warcraft/_forever_"             # copy the pack into Interface/Icons
python3 Tools/icons/iconset.py install --wow "/Applications/World of Warcraft/_forever_" --uninstall # remove the files it installed
```

`install` refuses a folder without `.flavor.info`, copies only files that differ (a rerun copies nothing), replaces a file of another icon pack with the same name and says how many, and writes `Interface/Icons/KstyleUI-Icons.manifest.json` with the sha256 of every file it placed. `--uninstall` removes the manifest's files whose content still matches, keeps one you changed, and touches nothing else.

## Uninstall by hand

Delete the pack's files from `World of Warcraft/_forever_/Interface/Icons/` (or the whole `Icons` folder if nothing else is in it) and start the game again. Blizzard's icons come back.

## What stays Blizzard's

- **Encrypted icons.** The client encrypts fewer than a hundred icons for store and event items; a loose file cannot replace one. The pack skips them (`iconset.py pack` reports each, and `Tools/data/icon_names.csv` marks them `encrypted`), so those icons stay Blizzard's.
- **Icons not yet repainted.** An icon the pack has no file for shows Blizzard's art. The pack covers every player ability and item (see the counts below) and grows as more icons are repainted.
- **A client that stops loading loose files.** Blizzard can turn the mechanism off: retail 12.1.0 did so briefly in August 2026. Nothing breaks when that happens; the game shows its own icons until a new pack is made.

## Switching

There is no in-game toggle. Install the pack for the repaints, remove it for Blizzard's icons, with a full restart either way.

## How the pack is made

The source art is set B, the full-colour repaints of Blizzard's own icons in [`Tools/icons/setB/`](../Tools/icons/setB/): `Icons/<fileID>.png` (128 by 128, 8-bit RGB) and [`PROVENANCE.md`](../Tools/icons/setB/PROVENANCE.md), one row per icon with the model, prompt, Higgsfield job, the Blizzard BLP's sha256 and the date. `Tools/` never ships in the addon zip, so the addon carries no icons.

| Step | Command | What it does |
| --- | --- | --- |
| Generate | `iconset.py generate --mode subject_reference` | Repaints each icon group of `Tools/data/abilities.json`, `items.json` and `icons_more.json` from Blizzard's icon with Higgsfield, judged by `Tools/icons/check_icons.py` and by eye on contact sheets. [`Tools/icons/iconset.py`](../Tools/icons/iconset.py) documents the pipeline. |
| Package | `iconset.py package` | Writes `Tools/icons/setB/Icons/<fileID>.png` and `PROVENANCE.md` from the accepted images. |
| Names | `iconset.py names` | Writes `Tools/data/icon_names.csv`: the community listfile's row for every icon group's file ID, with Blizzard's mixed-case file name, and `encrypted` on a zero-filled texture. The committed file keeps the pack build offline. |
| Pack | `iconset.py pack --out DIR` | Writes `DIR/Interface/Icons/<Name>.tga` for every packaged icon with a name that is not encrypted, and reports the ones it skips. |
| Verify | `iconset.py verify` | Checks the PNGs, the provenance rows and that every packaged icon has a name. `Tools/tests/test_iconset.py` and `test_iconpack.py` run it. |

The release workflow runs `verify` and `pack` in its check job, and the release job packs again, zips the `Interface` tree as `KstyleUI-Icons-<version>.zip` and uploads it to the GitHub release beside the addon zip.

### File format

The pack matches what AcidWeb's Clean Icons ships, which the Forever client is known to load: TGA, 128 by 128 pixels, 32 bits per pixel with an 8-bit alpha channel (opaque), uncompressed true colour, bottom-left origin, with the TGA 2.0 footer. One flat `Interface/Icons` folder; the file names are Blizzard's own mixed-case icon names from the community listfile with capitals (`community-listfile-withcapitals.csv` from wowdev/wow-listfile). The client matches names without regard to case.

### The renders

`Tools/render/` draws every icon as a player with the pack installed sees it: a numeric file ID resolves to `Tools/icons/setB/Icons/<fileID>.png` when the pack has it, else to Blizzard's icon from the extract cache (`Common.IconDirs` in `Tools/render/scenes/_common.lua`). The aura tiles show the repaints too, because the client swaps the file under the engine's secret file ID.

## Coverage

Counts from the Forever client 1.60.1.70862 on 2026-11-08 (`iconset.py names`, `Tools/icons/more_icons.py`):

| What | Icons |
| --- | --- |
| Icons in the client's `Interface/Icons` | 30,509 |
| Encrypted (zero-filled), never replaceable | 55 |
| Repainted before this change: every player ability and item | 3,271 |
| Left to repaint, by what a player sees: other spells 787 (778 of them named, such as creature spells and buffs), currencies 2, mounts 18, achievements 75, items the item list dropped 346, icons no table references 26,001 | 27,183 |

`Tools/icons/more_icons.py` lists the client's other icons from its data tables (`SpellMisc`, `SpellName`, `Talent`, `CurrencyTypes`, `Achievement`, `Mount`, `BattlePetSpecies`, `Item`, `ItemSparse`), ranked by what a player sees, into `Tools/data/icons_more.json`; `iconset.py generate --categories spell,currency,mount,companion,achievement,unlisted,misc` repaints them in that order and resumes where it stopped. At 1.5 credits per image and about 10% rerolls, the rest costs about 1.65 credits per icon.

## Research: how Clean Icons does it

Checked on 2026-11-08 against the [WoWInterface page](https://www.wowinterface.com/downloads/info25064-CleanIcons-MechagnomeEdition) and the [GitHub releases](https://github.com/AcidWeb/Clean-Icons-Mechagnome-Edition/releases) of Clean Icons - Mechagnome Edition, and against its latest release archive, `CleanIcons-MechagnomeEdition-12.1.5.70688-V5-1.zip` (5 November 2026, 1.18 GB), opened read-only:

- **Install.** "Contents of the archive should be placed directly in `World of Warcraft\_retail_\Interface`", and "A full restart of the game is required." The archive holds one folder, `ICONS`, and nothing else.
- **Format.** 33,412 files, all `.tga`, each 65,580 bytes: 128 by 128, 32 bits per pixel, 8 alpha bits, uncompressed true colour (type 2), bottom-left origin, TRUEVISION-XFILE footer. The pages state no format; the archive does.
- **Names.** Blizzard's mixed-case icon names (`Ability_Ambush.tga`, `Spell_Holy_Stoicism.tga`, `INV_Misc_QuestionMark.tga`).
- **Forever.** The 12.1.5.70688-V5-1 release note reads "Added Forever icons - 1.60.1." The Forever icons are in the same zip; there is no separate Forever pack. The page says the pack "is intended mainly for Retail version but other client flavors are supported too."
- **Limits.** "There are currently less than a hundred encrypted icons for event and store items. Due to technical reasons, they cannot be replaced." Release 12.1.0.69273-V5-1 (12 August 2026): "Not all of the new icons added in 12.1.0 are included in this package because Blizzard decided to disable the mechanism for replacing them"; the next release four days later added them back.
- **Compatibility.** "This type of texture replacement is simple and effective, but other addons are unable to recognize that they are using unofficial icons."
- **Licence.** None is stated on either page or in the repository.
