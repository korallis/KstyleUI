# Developing KstyleUI

The notes a contributor needs that the [README](../README.md) no longer carries: where things are, which checks to run, how to add a translation, and where the rules live.

## Rules and design

Read [`AGENTS.md`](../AGENTS.md) for the gate to run before every push and the repository rules.
The binding design is [`docs/superpowers/specs/2026-11-07-kstyleui-design.md`](superpowers/specs/2026-11-07-kstyleui-design.md).

## Releases and testing

Each release is a `vX.Y.Z` tag on `main`, cut after the owner's in-game pass on `staging`. [`CHANGELOG.md`](../CHANGELOG.md) and [`docs/RELEASE_NOTES.md`](RELEASE_NOTES.md) hold what each release changed, and [`docs/TESTING.md`](TESTING.md) is the test guide.

The release's `check` job validates the tag's changelog section and packages without uploading. Each of its two Lua shards first runs `ci_scope.py proven-sha`: the newest `checks.yml` push run for the tagged SHA in this repository must complete successfully to prove the suite, including a staging push that reused pull request results. If that run is queued or in progress, the proof polls every 15 seconds for up to 15 minutes and prints the run it waits for. A missing, failed or cancelled run, a timeout or an API error runs the shards. Each Lua job has 35 minutes to allow the proof wait and the existing 20-minute suite budget. The proof is a step decision, so both Lua jobs report a result; uploads require `check` and both shards to succeed.

To run the current `staging` build from a clone at `~/KstyleUI`, follow [Install the addons](TESTING.md#install-the-addons) in the test guide.

The layout and render tests draw the HUD on 1280x720, 1366x768, 1920x1080, 2560x1440, 3440x1440, 3840x1080, 5120x1440, 3840x2160, 2383x1540 and 3456x2234. Every README picture except the Medallions section's in-game `game_*` captures is a test render from `Tools/render/`, retaken with `python3 Tools/render/readme.py` ([`Tools/render/README.md`](../Tools/render/README.md), README pictures); a render is not the game, so each release is also checked in game.

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
| `docs/` | The design spec, the plans, the mockups, the test guide, the release notes and the README's images (`docs/media/readme/`, retaken from the render scenes by `python3 Tools/render/readme.py`, except the in-game `game_*` captures) |
| `Tools/` | Checks, tests, the spike addon, the icon pipeline with the repainted icon art (`Tools/icons/setB/`) and developer scripts. They never ship in the addon; the icons ship as their own pack. |
| `research_notes/`, `reports/` | Research on Forever's API, its addon restrictions and existing UI suites |

## Checks

Run the gate from the repository root before every push and read its exit code. `AGENTS.md` explains each step.

```bash
bash scripts/gate.sh
```

It runs `python3 Tools/dev/crlf.py --check`, `env -u SKIP pre-commit run --all-files` (including luacheck and the TOC/API hooks), `python3 Tools/locale/strings.py check`, `scripts/check-suppressions.sh` against `origin/staging`, `bash Tools/regression/run-all.sh --affected origin/staging` and the Python suite (`python3 -m unittest discover -s Tools/tests`, with the venv interpreter), then lists every step that failed. `scripts/gate.sh lint`, `lua` and `python` run one group; CI calls those.

With no options the `lua` group runs only the Lua test files that load a file you changed, plus the source guards, and prints what it chose and why; CI passes `--shard I/2` and runs every file. `bash Tools/regression/run-all.sh` with no argument reproduces a CI failure.

### What CI runs

| Workflow | When | Checks |
| --- | --- | --- |
| `checks` | A pull request opens, gets a new commit or reopens; every push to `staging`; a manual run | `lua 1/2`, `lua 2/2` and `lint, python and package` run in parallel; each job decides which suites have work |
| `pr-rules` | A pull request opens, gets a new commit or reopens, and when it is edited or a label changes | `pr-rules`: the title reads `type(scope): summary`, the changelog line and the release markers |

A pull request is green when every `checks` job and `pr-rules` are green; `gh pr checks <number>` lists the checks. `checks` starts three jobs without dependencies; `pr-rules` can also take a runner on a pull request. A job with no suite work succeeds after its scope check; the combined job always runs lint on pull requests.

Every job runs on the owner's self-hosted Mac runners (`runs-on: [self-hosted, mac-ci, KstyleUI]`), never on a hosted runner. A pull request from a fork does not run there: the repository requires the owner's approval before any outside contributor's workflows run, and each job's `if:` skips a fork's pull request even after approval. A fork can edit that `if:` in its own copy of the workflow, so each runner also has a job-started hook, outside the repository, that fails any job unless it is a push, a manual run, or a pull request whose head repository is this one. Never approve a fork's workflows all the same: the jobs run as the owner's account on the Mac. Its checks then show as skipped, and GitHub counts a skipped check as passing, so they prove nothing: push its commits to a branch here to test them. Each runner wipes its checkout, its temp files and its home after every job.

- **No rerun for edits.** A label, body or title change runs `pr-rules` only (about 20 s), which checks again every time so an edit never turns an earlier failure green. The suites in `checks` run for a commit, and a new push cancels the run still going for the old one, in every workflow.
- **Parallel suites, scoped work.** Each Lua shard runs `Tools/hooks/ci_scope.py lua`; `lint, python and package` runs `ci_scope.py all`, lint, Python tests and the package checks. Python and package steps run even after lint fails, unless cancelled or out of scope. The scope check says per suite whether the pull request changes a file the suite can read: a pull request that touches only `docs/`, `research_notes/`, `reports/` and Markdown outside the addon folders skips the Lua tests, the Python tests and the package build. `Tools/tests/test_ci_scope.py` lists what counts. A change to the pipeline's own files, to a document a test reads, to `Media/` (the Lua tests read its textures and fonts), or to anything the script does not know runs the suite, and so does any mixed pull request. A scope script failure fails its job.
- **Shards.** The Lua test files split into two jobs by recorded time (`Tools/regression/weights.json`), one per Mac runner, with PUC Lua 5.1.5, a default 20 CPU second limit (or a measured LEE-5827 allowance), and a 4096 MB peak-memory limit. CPU limits fail on Mac CI; Windows and local CPU overruns warn. Memory and hang limits still fail everywhere. On a self-hosted runner a shard takes the Mac's worker slots like a local run, so CI and the threads on that Mac share one limit. Each shard has a 15-minute job timeout.
- **After a retarget.** Changing a pull request\'s base branch (including GitHub retargeting a stacked pull request when its parent merges) does not rerun the suites, because `checks` ignores edits so that body and label edits cannot restart them or hide a failure. Close and reopen the pull request, or push, to test the new merge result.
- **Staging.** Each in-scope pull request area first uploads a seven-day `start-<merge-tree>-<area>` marker and runs only after that upload succeeds; it ends with an `always()` upload of a seven-day `<green|red>-<merge-tree>-<area>` artifact: success writes green, while failure or cancellation writes red. Lua names include the shard index and total. A push to `staging` compares start markers and both result colours for its exact tree and area and skips only when the uniquely newest marker is green and belongs to a completed, successful `checks.yml` pull request run from this repository, including its latest attempt. A newer start or red marker, or an ambiguous timestamp runs the area. An area the pull request scope skipped has no marker, so the push runs it. A changed tree, a failed rerun, missing proof or an API error also runs the area. These decisions happen in steps, so every job reports a result. The run is titled `staging: <the merge commit's message>`; each failed job emits a "staging is red" annotation. Find these runs with `gh run list --workflow checks --branch staging --event push`.
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
That manifest is loaded by `Core/Core.xml`. Generated files return before reading the namespace
unless `GetLocale()` matches (esMX shares esES); do not use TOC locale conditions for addon files.
A language whose script the bundled faces lack also needs a line in `GAME_FONTS` in
`Core/Locale.lua` and in `GAME_FONT_LOCALES` in the script.
