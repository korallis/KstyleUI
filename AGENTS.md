# AGENTS.md

KstyleUI is a World of Warcraft addon suite for the Forever client, written in Lua 5.1. This file holds the repository's facts: layout, commands, encoding, the Forever API rule and the mistakes that still need a person to remember them. Read the [design spec](docs/superpowers/specs/2026-11-07-kstyleui-design.md) and the [roadmap](docs/superpowers/plans/2026-11-07-kstyleui-roadmap.md) before you change code; the roadmap's Global Constraints and Core public API are binding. [`docs/DEVELOPING.md`](docs/DEVELOPING.md) has the contributor guide and [`docs/TESTING.md`](docs/TESTING.md) the test guide.

Gate: bash scripts/gate.sh
Known failing: none
Evidence: see verify/SKILL.md
Budget rule: Mac CI is the CPU budget of record: default PUC Lua 5.1.5 files use 20 CPU s or measured LEE-5827 allowances for files at or above 16 CPU s. Hosted Ubuntu pull-request shards warn on per-file CPU overruns and machine-dependent per-path CPU headroom; Windows and non-CI per-file CPU overruns also warn. Functional and instruction-count checks stay fatal everywhere; memory (4096 MB) and hang limits fail everywhere. The wall-clock hang guard is max(120 s, five times the adjusted CPU limit), or 120 s when CPU is not budgeted. LuaJIT and every `LUA` override print "not budgeted" for CPU. `test-perf` budgets remain at least five times measured Lua 5.1 CPU time; Windows skips headroom because MSVC `os.clock` measures wall time. See `Tools/regression/README.md` for calibration.

## Layout

| Path | What it holds |
| --- | --- |
| `Core/` | The core addon: services, the widget kit, Layout Mode, the first-run setup (`Core/Setup/Layouts.lua`) |
| `KstyleUI_<Module>/` | One addon per module, each with a README |
| `Media/` | Fonts, textures and the logo, with their provenance |
| `Tools/regression/` | Lua tests (`test-*.lua`), the stubs (`stubs/wow.lua`) and `run-all.sh` |
| `Tools/tests/` | The Python suite for the tools and the CI workflows |
| `Tools/hooks/` | Checks CI and the gate call, such as `check_toc.py` and `ci_scope.py` |
| `scripts/` | `gate.sh` and `check-suppressions.sh` |
| `docs/` | The spec, the plans, the guides and the README's images |

## The gate

Run `bash scripts/gate.sh` from the repository root before every push. It runs, in order: `Tools/dev/crlf.py --check`, `env -u SKIP pre-commit run --all-files` (including luacheck and `Tools/hooks/check_toc.py`), `Tools/locale/strings.py check`, `scripts/check-suppressions.sh` against `origin/staging`, `Tools/regression/run-all.sh --affected origin/staging` and the Python suite with the venv interpreter (`~/.local/share/wow-dev/venv/bin/python`, or `KSTYLEUI_PYTHON`). It runs every step, then lists the ones that failed and exits 1.

- `scripts/gate.sh lint`, `lua` and `python` run one group. CI runs eight Lua shards (`lua --shard I/8`) on hosted Ubuntu for pull requests and two (`lua --shard I/2`) on the self-hosted Macs for staging pushes and manual runs, alongside `lint, python and package` on `ubuntu-latest`, which runs `lint`, `python` and the package checks in order. Each job decides its own scope; Python and package checks still run after a lint failure unless cancelled or out of scope. Each in-scope pull request area first uploads a seven-day `start-<merge-tree>-<area>` marker and runs only after that upload succeeds; it ends with an `always()` upload of a seven-day `<green|red>-<merge-tree>-<area>` marker (Lua includes its shard index and total): failures and cancellations write red. A staging push always runs the full Lua suite on Macs, including cumulative instruction budgets; Lua never reuses PR markers. For other areas it considers start markers and both result colours and skips an area only when the uniquely newest marker is green and belongs to a completed, successful `checks.yml` pull request run from this repository, including its latest attempt. Missing proof, a changed tree or an API error runs that area, including areas the pull request scope skipped. A pull request is green when every `checks` job and `pr-rules` are green. `GATE_BASE` changes the base ref.
- A PR touching `Tools/regression/run_all.py`, `scripts/gate.sh` or `Tools/regression/run-all.sh` shows native Windows exit codes for `bash scripts/gate.sh lint` and `bash scripts/gate.sh lua --affected origin/staging`.
- `pre-commit run --all-files` checks tracked files only, so `git add` new files first. Do not run `pre-commit install`: worktrees share `.git/hooks`.
- `check-suppressions.sh` fails on a new `-- luacheck: ignore`, workaround marker or lint suppression whose line carries no ticket id such as `LEE-1234`.
- `run-all.sh --affected` runs the test files that load a file you changed plus the source guards, and prints why. A file that half the tests load, a stub, an env file or the runner runs every file. The first run on a machine runs everything once to record what each file loads. `bash Tools/regression/run-all.sh` with no argument is the full suite; use it to reproduce a CI failure. It runs under Lua 5.1 (`bash Tools/dev/install-lua51.sh` installs it) or `luajit -joff`. Mac CI enforces 20 CPU s per file or its measured allowance; CPU overruns elsewhere warn. Memory stays within 4096 MB and the hang guard is max(120 s, five times the adjusted CPU limit). [`Tools/regression/README.md`](Tools/regression/README.md) explains modes, budgets and worker slots.
- `luacheck .` reads `.luacheckrc`. Addon code may read only the globals Forever gives it. `Tools/build/gen_globals.py` writes `Tools/data/forever_globals.lua` from the matching UI source and the client's FrameXML GlobalStrings names; regenerate when the build changes. A global your module creates (a named frame, a `BINDING_*` string, a `SLASH_*` command) goes on your module's line in `.luacheckrc`. "Accessing undefined variable" on a Blizzard name means the source does not prove it: never add a Blizzard name to your module's line.
- `check_toc.py` reports files a TOC or XML include lists that are missing or differ in letter case from the file on disk. macOS loads such a file and a case-sensitive file system does not, so this check is the only guard.
- A change to a player-facing string needs `python3 Tools/locale/strings.py sync`; the gate's `check` names the fix.

## Pull requests

Every change merges into `staging` by squash; `main` follows `staging` at a release. Pull requests target `staging`. The title is `type(scope): summary` (Conventional Commits). The body has a `## Changelog` section whose line starts with `Added:`, `Changed:` or `Fixed:`, and an `## In-game checks` list. A pull request that changes only tooling or docs gets the `no changelog` label instead. `Tools/hooks/check-pr.sh` and CI enforce this. There is no line limit; keep each pull request to one coherent piece of work.

Change these only when the task needs it, and say why in the body: `.github/workflows/`, `.pkgmeta`, `Core/Tokens.lua`.

## App driver

The render harness is the app driver. It runs the addon's real Lua in the stub environments on fixture data, puts a module into a state, and screenshots it with headless Chrome, so no game client is needed. One command renders a feature and captures it:

```bash
RENDER_SCREEN=1920x1080 RENDER_SIZE=auto RENDER_HUD_STYLE=Orbs RENDER_LAYOUT=DPS \
  bash Tools/render/shoot.sh hud_reference --ppu 1 --backdrop --strict --out ~/.capy/work/<code>/orbs_1080.png
```

- [`docs/feature-map.md`](docs/feature-map.md) names the scene (a file in `Tools/render/scenes/`) and the `RENDER_*` variables for each feature. `RENDER_HUD_STYLE` is `Frames`, `Orbs` or `Medallions`, `RENDER_LAYOUT` is `DPS`, `Tank` or `Healer`, and `RENDER_ARRANGEMENT` is `centred` or `spread`.
- `--ppu` is pixels per unit. Set it to the screen's height over 1080 so the PNG has the screen's own pixels: `--ppu 1` at 1920x1080, `--ppu 1.3333333333` with `RENDER_SCREEN=5120x1440`.
- `--strict` fails the run (exit 3, after the PNG is written) on text the page truncated, content that spills past its card, a grey-box texture log, or a stale `Tools/render/guard_allow.tsv` line for the scene. Read the printed log before you trust a picture.
- It needs `luajit` and Google Chrome (`CHROME` overrides the binary). Without `--out`, the scene's JSON, page and PNG land in `Tools/render/out/`, which git ignores.
- [`Tools/render/README.md`](Tools/render/README.md) lists every scene and variable. `python3 Tools/render/readme.py` retakes the rendered README pictures; the `game_*` in-game captures are kept.

The regression harness drives behaviour the same way without pixels. A behaviour test in `Tools/regression/` boots a module's `*_env.lua` stub environment on fixtures, sends it events such as combat, a target or a setting change, and asserts on the frames; the source guards, such as `test-comments.lua` and `test-syntax.lua`, scan the tree instead. Run one alone with `lua5.1 Tools/regression/test-<name>.lua`, or `luajit -joff` where Lua 5.1 is missing.

[`docs/statecharts/`](docs/statecharts/) charts the HUD style switch, the first-run setup and the arrangement and layout-class switch. A PR that changes one of those flows updates its chart in the same PR, and a PR that adds, renames or removes a player-facing feature updates its row in the feature map.

## Line endings and encoding

- Every `.lua`, `.toc` and `.xml` file outside `Tools/` and `docs/` is an addon file: ASCII only, CRLF line endings. `.gitattributes` sets `* -text`, so git never rewrites line endings.
- Write LF, then run `python3 Tools/dev/crlf.py` to convert every changed or untracked addon file (pass paths to convert only those). `--check` changes nothing and exits 1 for any addon file with LF endings. Never rewrite an addon file with Python's `read_text` and `write_text`; that turns CRLF into LF.
- Files in `Tools/` and `docs/` use LF and may contain non-ASCII text. `python3 Tools/dev/crlf.py --check` checks tracked and changed text there; Python writers open with `newline="\n"`. CSV fields may retain embedded CRLF, but record endings use LF.

## The game and its test copy

The addons load from a checkout through `bash Tools/dev/link-addons.sh` (`--dry-run` changes nothing; `KSTYLEUI_LIVE` and `WOW_ADDONS` override the folders). The repainted icons are a loose-file texture pack, not an addon: `python3 Tools/icons/iconset.py` builds and installs it, and [`docs/icons.md`](docs/icons.md) has the details. `install --dry-run` lists what it would copy into the game folder.

## Forever API

- Blizzard's UI source for the live build (1.60.1.70862, commit `9dc84f0`) is the `forever` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever). Grep it before you use any API, event, template, mixin, CVar or Blizzard frame name, and name the proving file in the pull request. `Blizzard_APIDocumentationGenerated/` lists every C API with its `SecretReturns` and `SecretArguments` flags.
- Forever does not load the `Blizzard_Deprecated*` folders. Forever overrides live in `Camelot/` subfolders.
- Code defensively, as the spec's "Build mode" section says: check that an API exists before you call it, check `issecretvalue` before any comparison, and fall back to a safer path when the preferred one is unavailable.

## Conventions the tests enforce

Each is a test; its failure message names the fix.

- A TOC-loaded Lua file has one comment, its first line (`test-comments.lua`). Contracts go in `docs/` or the module's README.
- Make font strings with `K.Widgets.FontString(parent, layer)`, never a raw `CreateFontString` (`test-fontstrings.lua`).
- Place a secure overlay with `K.Widgets.Cover(overlay, visual)`, never by anchoring to the region it covers (the stub raises the game's error).
- Insert tracking thin spaces only where `KstyleUI.Locale.TrackMode(fontPath)` answers `"space"`; headings use the `caps` role (`test-thin-space.lua`).
- Never read state back from regions inside engine aura buttons; keep the wanted state yourself (`test-unitframes-auras.lua`).
- Register one event handler per owner and event in `Core/Events.lua`; give each piece of work its own owner (`Tools/regression/event_guard.lua`).
- Add no top-level local to `Core/Setup/Layouts.lua` (`test-layouts-locals.lua` keeps a margin under Lua's 200-local limit).
- The stubs raise what the client raises: nil rects, nil and NaN scales, and methods a Font object lacks (`test-stub-refusals.lua`); restricted measurements and secret values too (`test-stubs.lua`).
- In any Lua file, list folders and files and make temp folders only through `Tools/regression/fs.lua`, never `io.popen`, `os.execute` or `os.tmpname`, and open files only with a literal binary mode such as `"rb"` or `"wb"`, never `io.lines` or `io.input` (`test-shell-guard.lua`).

## Learned mistakes

- Piping `run-all.sh` or a test into `tail` hid two failures. Read the exit code of every check. Ends: judgment.
- A `test-perf` budget set from LuaJIT times failed on CI, and a new test took 53 s and 10 GB under Lua 5.1 against 0.5 s under LuaJIT. Decide a push from `run-all.sh` with no `LUA` set, never from `LUA=luajit`. Ends: judgment.

## How we work
- Minimal code: if it can be done in a few lines, do it in a few lines. Add dependencies, frameworks or abstractions only when the task truly needs them; prefer deleting to adding.
- Coordinator (no Task and Dispatch IDs in your prompt): answer questions and make trivial edits directly; for substantive work read and follow `C:\Users\leeba\.claude\skills\orca-jev-routing\SKILL.md`.
- Worker (your prompt has Task and Dispatch IDs): read and follow `C:\Users\leeba\orca-jev-router\WORKER.md` (Gate, comments, processes, clean-up, report).
