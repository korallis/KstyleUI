# Developing KstyleUI

The notes a contributor needs that the [README](../README.md) no longer carries: where things are, which checks to run, how to add a translation, and where the rules live.

## Rules and design

Read [`AGENTS.md`](../AGENTS.md) for the branch flow, the commands to run before every push and the repository rules.
The binding design is [`docs/superpowers/specs/2026-11-07-kstyleui-design.md`](superpowers/specs/2026-11-07-kstyleui-design.md).

## Status

The whole suite is built and passes its offline checks. It has not been released yet: the first
release follows the owner's in-game test of the `staging` branch. [`docs/TESTING.md`](TESTING.md)
is the test guide, and [`docs/RELEASE_NOTES.md`](RELEASE_NOTES.md) lists what the first release holds.

To run the current `staging` build from a clone at `~/KstyleUI`, follow [Install the addons](TESTING.md#install-the-addons) in the test guide.

## Repository

| Folder | What it holds |
| --- | --- |
| `Core/` | The core addon's services, the widget kit, Layout Mode and the first-run setup |
| `KstyleUI_<Module>/` | One addon per module, each with a README on how it works |
| `Media/` | Fonts, procedural textures and the logo, with their provenance |
| `docs/` | The design spec, the plans, the mockups, the test guide, the release notes and the README's images (`docs/media/readme/`, made by `make.py` in that folder from the render handoff) |
| `Tools/` | Checks, tests, the spike addon, the icon pipeline with the repainted icon art (`Tools/icons/setB/`) and developer scripts. They never ship in the addon; the icons ship as their own pack. |
| `research_notes/`, `reports/` | Research on Forever's API, its addon restrictions and existing UI suites |

## Checks

Run these from the repository root before every push. All of them must pass; `AGENTS.md` explains each one.

```bash
python3 Tools/dev/crlf.py
pre-commit run --all-files
bash Tools/regression/run-all.sh
python3 -m unittest discover -s Tools/tests
```

## Add or change a translation

KstyleUI ships English, German (`deDE`), French (`frFR`), Spanish (`esES`, also used on `esMX`) and
Simplified Chinese (`zhCN`). The translations use WoW's own terms for each language, taken from
Blizzard's localised interface strings for the Forever build. A string with no translation shows
in English.

Cinzel and Alegreya Sans have no Chinese or Korean glyphs. On `zhCN`, `zhTW` and `koKR` clients every
KstyleUI text uses the game's own font for that language, and on `ruRU` the game's Cyrillic font
replaces Cinzel. A font you pick from another addon stays your choice.

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
