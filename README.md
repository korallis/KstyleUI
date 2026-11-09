# KstyleUI

A complete UI overhaul for **World of Warcraft: Forever** (TOC `16001`, game type `camelot`).
It aims for the polish of Narcissus, WaypointUI and DialogueUI: modern, elegant and animated,
with one art direction across every window: frosted Lumen glass, rounded corners, a live
class-colour accent, crisp type and eased motion.

KstyleUI targets the Forever client only.

## Status

The whole suite is built and passes its offline checks. It has not been released yet: the first
release follows the owner's in-game test of the `staging` branch. [`docs/TESTING.md`](docs/TESTING.md)
is the test guide, and [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md) lists what the first release holds.

## Features

KstyleUI is one core addon and one addon per module. Every module is off until you switch it on,
and a module that is off costs nothing: no frames, no events and no hooks.

| Module | What it does |
| --- | --- |
| Core | The design system, the settings window (with its General page's panel opacity, panel shadows, interface sounds and tooltip size), Layout Mode, profiles, the first-run setup and `/kstyle` |
| Unit Frames | Player, target, target of target, focus, focus target, pet and boss 1 to 5, with portraits, cast bars, frame auras, the class resource, threat glow and status icons |
| Group Frames | Party and raid frames up to 40, with class colours, roles, range fade, incoming heals, absorbs, debuffs and the dispel highlight |
| Action Bars | Secure action bars with stance, stealth, form and possess paging, pet and stance bars, keybind text, cooldowns, proc glows, range and usability shading, fade on mouseover, and a dialog that puts a newly learned spell rank on the bars |
| Cooldowns | Blizzard's Cooldown Manager in KstyleUI's style: essential and utility rows in the HUD band, tracked buff icons and bars |
| Auras | Your buffs and debuffs under the minimap |
| Nameplates | A KstyleUI plate on each nameplate, with health, cast bar, threat colour and your debuffs |
| Combat Text | Damage and heal numbers on KstyleUI's frames and plates, and KstyleUI's font for the game's own numbers |
| Minimap | A round lens on a frost card with the zone and clock in its foot, rim buttons and an addon-button drawer |
| Chat | Glass chat panels, tabs with an accent underline, timestamps, short channel names, clickable links, class-coloured names, a copy window, and a plus glyph in the tab row that opens the chat settings |
| Bags | Combined bags and bank with the keyring, search, sorting, quality borders and junk selling |
| Tooltips | Glass tooltips with quality and class colours, a health bar, optional IDs and cursor anchoring |
| Data Bars | XP, reputation and honour bars, the micro menu, the bag bar and a data strip with frame rate, latency, gold, durability and time |
| Meters | A damage meter, a threat meter and a swing timer |
| Skins | Blizzard's windows in KstyleUI's style: the character sheet, spellbook, talents, world map, quest log, objective tracker, game menu, group finder, mail, merchant, trainers, professions, social windows, Legacy, loot, popups, ready check and the AddOns list, and the RestedXP Guides addon's windows |

Every element KstyleUI shows can be moved, resized or scaled in Layout Mode and from the settings
window, and every module has its own fonts, textures, colours and sizes. No module compares or does
arithmetic on Forever's secret values, every protected change made in combat waits for combat to end,
and the action bars, group frames, bags, auras, and the data bars' micro menu and bag bar hand back to
Blizzard's in the gamepad interface.

## Icon pack

KstyleUI's repainted icons are a separate download, `KstyleUI-Icons-<version>.zip` on the [release](https://github.com/korallis/KstyleUI/releases), not part of the addon. Quit the game, unzip it, and copy its `Interface` folder into `World of Warcraft/_forever_/` so the files land in `_forever_/Interface/Icons/`; then start the game (a full restart, not `/reload`). The client loads the files itself, so every icon the pack covers changes everywhere, buff and debuff tiles included. To go back to Blizzard's icons, delete those files and restart. Encrypted store and event icons stay Blizzard's. [`docs/icons.md`](docs/icons.md) has the details, the install script and how the pack is made.

## Install

1. Download the latest zip from the [Releases page](https://github.com/korallis/KstyleUI/releases).
2. Unzip it into `World of Warcraft/_forever_/Interface/AddOns`. Each folder in the zip becomes one addon folder there.
3. Restart the game, then enable the KstyleUI addons in the AddOns list.
4. Log in. The first-run setup opens: pick a layout (DPS, Tank or Healer) and the modules you want, then click **Apply** and **Reload**.

To run the current `staging` build from a clone at `~/KstyleUI` instead, follow [Install the addons](docs/TESTING.md#install-the-addons) in the test guide.

## Commands

| Command | What it does |
| --- | --- |
| `/kstyle` | Opens or closes the settings window. Esc > Options > AddOns > KstyleUI and the minimap's addon compartment open it too. |
| `/kstyle layout` | Enters or leaves Layout Mode. |
| `/kstyle setup` | Runs the first-run setup again. |
| `/kstyle test` | Runs the smoke checks and writes the results to the devlog. Type `/reload` afterwards to save them. |
| `/kstyle profile` | Lists the profiles and marks the one this character uses. |
| `/kstyle profile use <name>` | Switches this character to a profile, creating it if needed. |
| `/kstyle profile new <name>` | Creates a profile with the default settings. |
| `/kstyle profile copy <name>` | Copies a profile into the active one. |
| `/kstyle profile rename <name>` | Renames the active profile. |
| `/kstyle profile delete <name>` | Deletes a profile. |
| `/kstyle profile reset` | Resets the active profile to the defaults. |

The settings window's Profiles page also exports a profile as one string and imports one back.

## Repository

| Folder | What it holds |
| --- | --- |
| `Core/` | The core addon's services, the widget kit, Layout Mode and the first-run setup |
| `KstyleUI_<Module>/` | One addon per module, each with a README on how it works |
| `Media/` | Fonts, procedural textures and the logo, with their provenance |
| `docs/` | The design spec, the plans, the mockups, the test guide and the release notes |
| `Tools/` | Checks, tests, the spike addon, the icon pipeline with the repainted icon art (`Tools/icons/setB/`) and developer scripts. They never ship in the addon; the icons ship as their own pack. |
| `research_notes/`, `reports/` | Research on Forever's API, its addon restrictions and existing UI suites |

## Languages

KstyleUI ships English, German (`deDE`), French (`frFR`), Spanish (`esES`, also used on `esMX`) and
Simplified Chinese (`zhCN`). The translations use WoW's own terms for each language, taken from
Blizzard's localised interface strings for the Forever build. A string with no translation shows
in English.

Cinzel and Alegreya Sans have no Chinese or Korean glyphs. On `zhCN`, `zhTW` and `koKR` clients every
KstyleUI text uses the game's own font for that language, and on `ruRU` the game's Cyrillic font
replaces Cinzel. A font you pick from another addon stays your choice.

### Add or change a translation

1. Code reads every string as `L["English text"]`. After you add or change one, run
   `python3 Tools/locale/strings.py sync`. It rewrites the English base `Tools/locale/enUS.json`,
   drops translations whose English text is gone, and regenerates `Core/Locales/*.lua`.
2. Translate in `Tools/locale/<locale>.json`, a UTF-8 table from English text to translated text.
   `python3 Tools/locale/strings.py missing <locale>` lists what is left. Keep every format
   specifier (`%s`, `%d`) in the same order, keep `|c...|r` codes and line breaks, and keep any space
   at either end of the English text.
3. Run `sync` again. Addon files are ASCII, so the script writes each non-ASCII byte as a Lua
   decimal escape (`\195\164`). Never edit `Core/Locales/*.lua` by hand.
4. `python3 Tools/locale/strings.py check` and `Tools/tests/test_locale_strings.py` fail when a
   code key is missing from the base, a specifier or edge space changes, a generated file is stale,
   or a German, French or Spanish string uses a character a bundled face lacks.
5. Check that your text fits: `RENDER_LOCALE=deDE bash Tools/render/shoot.sh gallery_setup`
   renders any scene as that client sees it, and the render guard reports truncated text.

To add a new language, add its code and name to `LOCALES` and `NAMES` in `Tools/locale/strings.py`,
create `Tools/locale/<locale>.json` and run `sync`; it adds the file to `Core/Locales/Locales.xml`.
A language whose script the bundled faces lack also needs a line in `GAME_FONTS` in
`Core/Locale.lua` and in `GAME_FONT_LOCALES` in the script.

## Develop

Read [`AGENTS.md`](AGENTS.md) for the branch flow, the commands to run before every push and the repository rules.
The binding design is [`docs/superpowers/specs/2026-11-07-kstyleui-design.md`](docs/superpowers/specs/2026-11-07-kstyleui-design.md).

## Licence

All rights reserved. See [`LICENSE.md`](LICENSE.md).
