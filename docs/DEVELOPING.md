# Developing KstyleUI

The notes a contributor needs that the [README](../README.md) no longer carries: where things are, which checks to run, how to add a translation, and where the rules live.

## Rules and design

Read [`AGENTS.md`](../AGENTS.md) for the gate to run before every push and the repository rules.
The binding design is [`docs/superpowers/specs/2026-11-07-kstyleui-design.md`](superpowers/specs/2026-11-07-kstyleui-design.md).

## Releases and testing

Each release is a `vX.Y.Z` tag on `main`, cut after the owner's in-game pass on `staging`. [`CHANGELOG.md`](../CHANGELOG.md) and [`docs/RELEASE_NOTES.md`](RELEASE_NOTES.md) hold what each release changed, and [`docs/TESTING.md`](TESTING.md) is the test guide.

Before pushing a `v*` tag, start the `nightly` workflow by hand on `main` while its newest commit is the one to tag, and quote the passing run's link in the release report; a hotfix tag gets the same run. It runs lint on every file, every Lua test file with its allocation, instruction and memory budgets enforced and every Python test file. Only when GitHub cannot run it, run `bash scripts/gate.sh release` on that commit and quote its last line instead. The release workflow runs none of them. Its `check` job verifies that the tag is on `main`, validates the tag's changelog section, builds the icon pack and packages without uploading. Uploads require `check` to succeed. Before packaging, both jobs write the tag's changelog section to `Tools/release/packager-changelog.md` (`python3 Tools/release/discord_post.py --section <tag>`), the file `.pkgmeta` gives the packager as the text it uploads with the zip: GitHub refuses release text over 125,000 characters, and the whole `CHANGELOG.md` is longer. The zip still carries the whole file. After the upload, the release job sets the GitHub release text to that version's changelog section and the CurseForge and Wago links.

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

Follow [Check and deliver](../AGENTS.md#check-and-deliver) for the review and push sequence. Run the gate from the repository root and read its exit code.

```bash
bash scripts/gate.sh
```

With no group it runs `fast`: it checks that `luacheck` is 1.2.0 and `pre-commit` is 4.7.0, then runs `python3 Tools/dev/crlf.py --check`, `pre-commit run --from-ref <merge base> --to-ref HEAD` (the hooks, luacheck and the TOC/API checks included, on the files committed since the merge base with `origin/staging`; luacheck reads only the changed Lua files, and only on GitHub does a change to `.luacheckrc` or `Tools/data/forever_globals.lua` re-check the whole tree), `python3 Tools/locale/strings.py check` and `scripts/check-suppressions.sh` against `origin/staging`, and no tests; then it lists every step that failed. Commit before you run it. `scripts/gate.sh lint` runs the same checks on every file. `lua` runs `bash Tools/regression/run-all.sh --affected origin/staging` and `python` the Python suite (`python3 Tools/tests/run_suite.py origin/staging`, with the venv interpreter: one process per test file, 4 at a time, leaving out a tool's own tests when the tool is unchanged). `all` runs lint, lua and python. `release` runs all three with every Lua and Python test file, for the commit a release tag will point at when GitHub cannot run `nightly`.

The gate rejects tracked evidence images: put them in the PR body; published pictures and source assets must use the folders listed in `Tools/hooks/check_images.py`.

With no options the `lua` group runs only the Lua test files that load a file you changed, plus the source guards, and prints what it chose and why. `bash Tools/regression/run-all.sh` with no argument runs every file, as the release run does.

### Set up the gate on macOS

Start with Git, the Xcode Command Line Tools, and Homebrew's `luajit`, `luarocks` and `uv` packages (`brew install luajit luarocks uv`). From the repository root, install the gate tools in your user directory:

```bash
gate_tools="$HOME/.local/share/wow-dev"
PREFIX="$gate_tools" bash Tools/dev/install-lua51.sh
luarocks --lua-version=5.1 --lua-dir="$(brew --prefix luajit)" --tree "$gate_tools/rocks" install luacheck 1.2.0
if [ ! -x "$gate_tools/venv/bin/python" ]; then
    uv venv --python 3.12 "$gate_tools/venv"
fi
uv pip install --python "$gate_tools/venv/bin/python" 'pre-commit==4.7.0' 'Pillow==13.0.0' 'numpy==2.5.5'
```

In each shell that runs the gate, put those tools first and leave `LUA` unset:

```bash
export PATH="$HOME/.local/share/wow-dev/bin:$HOME/.local/share/wow-dev/rocks/bin:$HOME/.local/share/wow-dev/venv/bin:$PATH"
unset LUA
lua5.1 -v
luacheck --version
pre-commit --version
bash scripts/gate.sh
```

LuaJIT runs `luacheck`; the regression runner uses Lua 5.1.5. The gate finds the Python environment at its default path unless `KSTYLEUI_PYTHON` selects another interpreter. Pillow lets the image tests run instead of skipping for lack of Pillow.

NumPy runs the crest tracker and Medallions regeneration tests. For additional coverage, install Node (`brew install node`) for the cooldown canvas and gallery texture-path tests.

The glyph-table comparison skips if Pillow was built without Raqm text layout. The gate shows the skip count for successful Python test files. To see the reason, run the comparison directly:

```bash
"$HOME/.local/share/wow-dev/venv/bin/python" -m unittest discover -s Tools/tests -p test_render_standins.py -k test_glyph_table_is_current -v
```

The default group is `fast`: lint on the files changed against the base, about 15 seconds, with no tests. `bash scripts/gate.sh lua` runs the Lua tests the change reaches and `bash scripts/gate.sh python` the Python tests; `lint` checks every file and `all` runs lint, lua and python. On a new setup the Lua runner may select every test to learn which files each test uses. If it refuses because another run holds worker slots, wait for that run or use `KSTYLEUI_FULL=1 bash scripts/gate.sh lua` to let the larger selection proceed.

### Pull requests are checked on GitHub

Run `bash scripts/gate.sh` once before you push. GitHub then runs the checks on the pull request; do not run the gate again after the push.

- **Wording.** Set `PR_TITLE`, `PR_BODY` or `PR_BODY_FILE`, and `PR_LABELS`, and the lint group also runs `Tools/hooks/check-pr.sh`: the title reads `type(scope): summary`, the changelog line and the release markers. Run `bash scripts/gate.sh lint` with them again after editing the title, the body or the labels.

  ```bash
  PR_TITLE="fix(chat): keep the edit box under the newest line" PR_BODY_FILE=body.md PR_LABELS="" bash scripts/gate.sh
  ```

- **What merges wait for.** `checks` passes only when lint, the Lua shards, the Python tests and the package build passed, and `pr-rules` checks the title, changelog line and release markers again whenever they change. A pull request is ready to merge when both passed on its newest commit. The `Require checks on staging` ruleset makes both required statuses on `staging`, so GitHub holds a merge into `staging` until they pass. `gh pr checks <number>` lists them. A pull request from a fork runs the same workflows with a read-only token.
- **The pass line.** A pass ends `gate passed (<group>) at <commit>` only when the working copy was clean and on that commit from the start of the run to its end; otherwise the last line says what changed and names no commit.
- **Tools.** The gate needs Lua 5.1.5, `luacheck` 1.2.0, `pre-commit` 4.7.0 and Python 3; the lint group fails on any other `luacheck` or `pre-commit` version. Budgets: instruction-count, allocation, memory (4096 MB) and hang limits fail on every computer; a file over its CPU-time limit prints a warning, and no machine enforces CPU time.

### What Actions runs

`checks.yml` runs for every pull request and every push to `staging` and `main`, and picks its work by what changed against the base: a pull request's target branch, or the commit before a push's first commit, so every commit of a push counts. `what the change reaches` decides which jobs run: `Tools/hooks/needs-lua.sh` says whether a changed file can reach a Lua test: only workflows, Python tests, `scripts/`, research and documents skip them. The few Lua tests that read a document (the changelog, a module's `README.md`, the feature map) run in the nightly suite, so a docs-only change runs no Lua test. The job fails rather than skipping when it cannot tell. `lua 1/8` to `lua 8/8` run `run-all.sh --shard I/8 --affected <base>` only then, so a docs-only change runs none. What each test loads comes from the last nightly run's record; `KSTYLEUI_DEPS_VERIFY=1` keeps a record only while every file, folder listing and tracked name it read is unchanged here, and every other test runs. On these Linux runners a timing or CPU-time overrun prints a warning; functional, allocation, instruction, memory and hang failures fail. `lint, python and package` runs `gate.sh fast`, the Python tests whose tool changed and every other Python test file except the render comparison, with Pillow 13.0.0 and NumPy 2.5.5 so the image tests run, and a dry package build. When `scripts/gate.sh`, `run-all.sh` or `run_all.py` changed, `windows lint` and `windows lua 1/8` to `8/8` run `bash scripts/gate.sh lint` and `bash scripts/gate.sh lua --affected <base> --shard I/8` on `windows-latest`, with `GATE_BASE` set to the same base, and print each native exit code; on a pull request the base is the tip of `staging` the change merges into. `checks` passes only when every job the change needs passed and the others were skipped because it did not need them. `pr-rules.yml` runs `Tools/hooks/check-pr.sh` on every pull request event.

`nightly.yml` runs on `staging` each night, by hand, and on a pull request when someone adds the `full suite` label, to see the whole suite pass on a change before it merges: lint on every file, every Lua test file, every Python test file including the render comparison with Pillow and NumPy, a dry package build, and on `staging` a new record of what each Lua test loads for `checks.yml`. None of these workflows reads a secret or writes anything.

`release.yml` runs for a `v*` tag on `main` (and by hand to repost a release to Discord) on GitHub-hosted `ubuntu-latest`: its `check` job verifies the tag, the changelog, the icon pack and a dry package build, and the upload needs that job. It runs no lint and no test suite. Actions are pinned by commit hash, and the release jobs check the Lua 5.1.5 and Pillow 13.0.0 they install.

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
