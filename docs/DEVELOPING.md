# Developing KstyleUI

The notes a contributor needs that the [README](../README.md) no longer carries: where things are, which checks to run, how to add a translation, and where the rules live.

## Rules and design

Read [`AGENTS.md`](../AGENTS.md) for the gate to run before every push and the repository rules.
The binding design is [`docs/superpowers/specs/2026-11-07-kstyleui-design.md`](superpowers/specs/2026-11-07-kstyleui-design.md).

## Releases and testing

Each release is a `vX.Y.Z` tag on `main`, cut after the owner's in-game pass on `staging`. [`CHANGELOG.md`](../CHANGELOG.md) and [`docs/RELEASE_NOTES.md`](RELEASE_NOTES.md) hold what each release changed, and [`docs/TESTING.md`](TESTING.md) is the test guide.

Before pushing a `v*` tag, run `bash scripts/gate.sh release` on the exact commit to be tagged and quote its last line, `gate passed (release) at <commit>`, in the release report. It runs lint, every Lua test file and the Python suite; a hotfix tag gets the same run. The release workflow runs none of them. Its `check` job verifies that the tag is on `main`, validates the tag's changelog section, builds the icon pack and packages without uploading. Uploads require `check` to succeed. After the upload, the release job sets the GitHub release text to that version's changelog section and the CurseForge and Wago links.

To run the current `staging` build from a clone at `~/KstyleUI`, follow [Install the addons](TESTING.md#install-the-addons) in the test guide.

The layout and render tests draw the HUD on 1280x720, 1366x768, 1920x1080, 2560x1440, 3440x1440, 3840x1080, 5120x1440, 3840x2160, 2383x1540 and 3456x2234. Every README picture except the Medallions section's in-game `game_*` captures is a test render from `Tools/render/`, retaken with `python3 Tools/render/readme.py` ([`Tools/render/README.md`](../Tools/render/README.md), README pictures); a render is not the game, so each release is also checked in game.

## Developer commands

| Command | What it does |
| --- | --- |
| `/kstyle test` | Runs the smoke checks and writes the results to the devlog. Type `/reload` afterwards to save them. |
| `/kstyle devlog on`, `/kstyle devlog off` | Arms or stops the [Edit Mode geometry recorder](EDIT_MODE_RECORDER.md) for this session; it is off after every reload. |
| `/kstyle perf`, `/kstyle perf <seconds>` | Records the frame rate and the Lua time this addon spends into the devlog for 20 seconds or the number given; run it again to stop early, then `/reload` to save. [PROFILING.md](PROFILING.md) explains how to read the report. |

## Repository

| Folder | What it holds |
| --- | --- |
| `Core/` | The core addon's services, the widget kit, Layout Mode and the first-run setup |
| `KstyleUI_<Module>/` | One addon per module, each with a README on how it works |
| `Media/` | Fonts, procedural textures and the logo, with their provenance |
| `docs/` | The design spec, the plans, the mockups, the test guide, the release notes and the README's images (`docs/media/readme/`, retaken from the render scenes by `python3 Tools/render/readme.py`, except the in-game `game_*` captures) |
| `Tools/` | Checks, tests, the spike addon, the icon pipeline with the repainted icon art (`Tools/icons/setB/`) and developer scripts. They never ship in the addon; the icons ship as their own pack. |
| `research_notes/`, `reports/` | Research on Forever's API, its addon restrictions and existing UI suites |

## Checks

Run the gate from the repository root before every push and read its exit code. `AGENTS.md` explains each step.

```bash
bash scripts/gate.sh
```

It checks that `luacheck` is 1.2.0 and `pre-commit` is 4.7.0, then runs `python3 Tools/dev/crlf.py --check`, `env -u SKIP pre-commit run --all-files` (including luacheck and the TOC/API hooks), `python3 Tools/locale/strings.py check`, `scripts/check-suppressions.sh` against `origin/staging`, `bash Tools/regression/run-all.sh --affected origin/staging` and the Python suite (`python3 -m unittest discover -s Tools/tests`, with the venv interpreter), then lists every step that failed. `scripts/gate.sh lint`, `lua` and `python` run one group. `scripts/gate.sh release` runs all three with every Lua test file, for the commit a release tag will point at.

The gate rejects tracked evidence images: put them in the PR body; published pictures and source assets must use the folders listed in `Tools/hooks/check_images.py`.

With no options the `lua` group runs only the Lua test files that load a file you changed, plus the source guards, and prints what it chose and why. `bash Tools/regression/run-all.sh` with no argument runs every file, as the release run does.

### Pull requests are checked locally

No workflow runs for a pull request or for a push to `staging`. The gate on the computer that made the change is the only check, so run it on the exact commit you push.

- **Wording.** Set `PR_TITLE`, `PR_BODY` or `PR_BODY_FILE`, and `PR_LABELS`, and the lint group also runs `Tools/hooks/check-pr.sh`: the title reads `type(scope): summary`, the changelog line and the release markers. Run `bash scripts/gate.sh lint` with them again after editing the title, the body or the labels.

  ```bash
  PR_TITLE="fix(chat): keep the edit box under the newest line" PR_BODY_FILE=body.md PR_LABELS="" bash scripts/gate.sh
  ```

- **The pass mark.** A pass on a clean working copy ends `gate passed (all) at <commit>`; with uncommitted changes the last line says so and names no commit. After the push, post a commit status on that commit with context `local gate`, state `success` and that last line as the description (`POST /repos/korallis/KstyleUI/statuses/<commit>`). A failing run, a one-group run or a run with uncommitted changes posts nothing, and a pull request whose newest commit lacks the mark is not ready to merge. `gh pr checks <number>` lists the mark.
- **A new commit needs a new mark.** The mark belongs to one commit, so a later push, including a merge of `staging` into the branch, needs a new run and a new mark.
- **A pull request from a fork** has no mark until someone with write access runs the gate on its commit and posts one.
- **Tools.** The gate needs Lua 5.1.5, `luacheck` 1.2.0, `pre-commit` 4.7.0 and Python 3; the lint group fails on any other `luacheck` or `pre-commit` version. Budgets: instruction-count, allocation, memory (4096 MB) and hang limits fail on every computer; a file over its CPU-time limit prints a warning, and no machine enforces CPU time.

### What Actions runs

Only the release. `release.yml` runs for a `v*` tag on `main` (and by hand to repost a release to Discord) on GitHub-hosted `ubuntu-latest`: its `check` job verifies the tag, the changelog, the icon pack and a dry package build, and the upload needs that job. It runs no lint and no test suite. Actions are pinned by commit hash, and the release jobs check the Lua 5.1.5 and Pillow 13.0.0 they install.

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
That manifest is loaded by `Core/Core.xml`. Generated files return before reading the namespace
unless `GetLocale()` matches (esMX shares esES); do not use TOC locale conditions for addon files.
A language whose script the bundled faces lack also needs a line in `GAME_FONTS` in
`Core/Locale.lua` and in `GAME_FONT_LOCALES` in the script.
