# Developing KstyleUI

The notes a contributor needs that the [README](../README.md) no longer carries: where things are, which checks to run, how to add a translation, and where the rules live.

## Rules and design

Read [`AGENTS.md`](../AGENTS.md) for the branch flow, the commands to run before every push and the repository rules.
The binding design is [`docs/superpowers/specs/2026-11-07-kstyleui-design.md`](superpowers/specs/2026-11-07-kstyleui-design.md).

## Releases and testing

Each release is a `vX.Y.Z` tag on `main`, cut after the owner's in-game pass on `staging` (`AGENTS.md`, Releases). [`CHANGELOG.md`](../CHANGELOG.md) and [`docs/RELEASE_NOTES.md`](RELEASE_NOTES.md) hold what each release changed, and [`docs/TESTING.md`](TESTING.md) is the test guide.

To run the current `staging` build from a clone at `~/KstyleUI`, follow [Install the addons](TESTING.md#install-the-addons) in the test guide.

The layout and render tests draw the HUD on 1280x720, 1366x768, 1920x1080, 2560x1440, 3440x1440, 3840x1080, 5120x1440, 3840x2160, 2383x1540 and 3456x2234. Every picture in the README is a test render from `Tools/render/`, retaken with `python3 Tools/render/readme.py` ([`Tools/render/README.md`](../Tools/render/README.md), README pictures); a render is not the game, so each release is also checked in game.

## Developer commands

| Command | What it does |
| --- | --- |
| `/kstyle test` | Runs the smoke checks and writes the results to the devlog. Type `/reload` afterwards to save them. |
| `/kstyle devlog on`, `/kstyle devlog off` | Arms or stops the [Edit Mode geometry recorder](EDIT_MODE_RECORDER.md) for this session; it is off after every reload. |

## Repository

| Folder | What it holds |
| --- | --- |
| `Core/` | The core addon's services, the widget kit, Layout Mode and the first-run setup |
| `KstyleUI_<Module>/` | One addon per module, each with a README on how it works |
| `Media/` | Fonts, procedural textures and the logo, with their provenance |
| `docs/` | The design spec, the plans, the mockups, the test guide, the release notes and the README's images (`docs/media/readme/`, retaken from the render scenes by `python3 Tools/render/readme.py`) |
| `Tools/` | Checks, tests, the spike addon, the icon pipeline with the repainted icon art (`Tools/icons/setB/`) and developer scripts. They never ship in the addon; the icons ship as their own pack. |
| `research_notes/`, `reports/` | Research on Forever's API, its addon restrictions and existing UI suites |

## Checks

Run these from the repository root before every push, one at a time, and read each exit code. All of them must pass; `AGENTS.md` explains each one.

```bash
python3 Tools/dev/crlf.py
pre-commit run --all-files
luacheck .
python3 Tools/hooks/check_toc.py
bash Tools/regression/run-all.sh --affected origin/staging
```

The last command runs only the Lua test files that load a file you changed, plus the source guards, and prints what it chose and why. CI runs everything, so the Mac does not repeat it. On 2026-11-10 the owner asked for the pipeline to stop duplicating tests (`AGENTS.md` quotes him), which replaced the earlier rule of a full local `run-all.sh` and Python suite before every push. Run the Python suite (`python3 -m unittest discover -s Tools/tests`) yourself only when your diff touches `Tools/`, `Media/`, `.github/` or a locale string.

### What CI runs

| Workflow | When | Checks |
| --- | --- | --- |
| `checks` | A pull request opens, gets a new commit or reopens; every push to `staging`; a manual run | `pre-commit`, `lua 1/2`, `lua 2/2`, `python`, `package`, and `verdict`, which succeeds only when the other five did |
| `pr-rules` | A pull request opens, gets a new commit or reopens, and when it is edited or a label changes | `pr-rules`: the changelog line and the release markers |
| `pr-title` | A pull request opens, gets a new commit or reopens, and when it is edited | `title`: the title reads `type(scope): summary` |

A pull request is green when `verdict`, `pr-rules` and `title` are green; `gh pr checks <number>` lists all eight checks.

Every job runs on the owner's self-hosted Mac runners (`runs-on: [self-hosted, mac-ci, KstyleUI]`), never on a hosted runner. A pull request from a fork does not run there: the repository requires the owner's approval before any outside contributor's workflows run, and each job's `if:` skips a fork's pull request even after approval. A fork can edit that `if:` in its own copy of the workflow, so each runner also has a job-started hook, outside the repository, that fails any job unless it is a push, a manual run, or a pull request whose head repository is this one. Never approve a fork's workflows all the same: the jobs run as the owner's account on the Mac. Its checks then show as skipped, and GitHub counts a skipped check as passing, so they prove nothing: push its commits to a branch here to test them. Each runner wipes its checkout, its temp files and its home after every job.

- **No rerun for edits.** A label change runs `pr-rules` only; a body or title edit runs `pr-rules` and `title` (about 10 s each), which check again every time so an edit never turns an earlier failure green. The suites in `checks` run for a commit, and a new push cancels the run still going for the old one.
- **Skipped work still reports.** Every job of `checks` ends with a success on every pull request. A job whose files did not change prints one line that says why and succeeds: a pull request that touches only `docs/`, `research_notes/`, `reports/` and Markdown outside the addon folders skips the Lua tests, the Python tests and the package build. `Tools/hooks/ci_scope.py` decides, and `Tools/tests/test_ci_scope.py` lists what counts. A change to the pipeline's own files, to a document a test reads, or to anything it does not know runs the job.
- **Shards.** The Lua test files split into two jobs by recorded time (`Tools/regression/weights.json`), one per Mac runner, with the same 80 s and 4096 MB budgets and the same Lua 5.1.5. On a self-hosted runner a shard takes the Mac's worker slots like a local run, so CI and the threads on that Mac share one limit.
- **After a retarget.** Changing a pull request\'s base branch (including GitHub retargeting a stacked pull request when its parent merges) does not rerun the suites, because `checks` ignores edits so that body and label edits cannot restart them or hide a failure. Close and reopen the pull request, or push, to test the new merge result.
- **Staging.** Every push to `staging` runs all of it, with nothing skipped, on the merged result: two green pull requests can still fail together, and this is where that shows. The run is titled `staging: <the merge commit's message>`; a red one is `gh run list --workflow checks --branch staging --event push`.
- **Tools pinned.** Actions are pinned by commit hash. The runners carry Lua 5.1.5, `luacheck` 1.2.0, `pre-commit` 4.7.0, a Python 3.12 without Pillow for the suite and a Python with Pillow 13.0.0 for the icon pack (`KSTYLEUI_PILLOW_PYTHON`); each job checks the versions it uses before it starts, and nothing is installed during a run. `pre-commit` keeps its hook environments in the runner's home, capped at 1 GB.

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
