# Building KstyleUI for Forever

These rules apply to every module. Edit `AGENTS.md` and copy it to `CLAUDE.md`; both entry points must contain the complete guide, byte for byte.

## Runtime rules

**Cheap while on.** Be event-driven, not polling. Use `OnUpdate` only while something is actually animating or counting down, and stop it when it is done. No table churn in hot paths: reuse frames and buffers rather than allocating them per event. Code defaults leave modules off. Create frames and register handlers on enable, not on file load. Give each owner one handler per event and stop work when disabled.

**No taint, no Lua errors.** A feature that can throw in combat or taint Blizzard's UI will not be merged.

- Never drive Blizzard's own UI functions from addon code to open or refresh their frames. Calling `QuestMapFrame_OpenToQuestDetails` tainted the whole world map. Observe Blizzard opening the window instead.
- Never `SetScript` on Blizzard frames. Use `hooksecurefunc` for a function or `HookScript` for a frame script. Keep addon state in `KstyleUI.Safe.Side(frame)`, not in fields on the frame.
- Do not `Hide()` Blizzard frames that other Blizzard code lays out. Fade them with `SetAlpha` instead: hiding the XP bar containers tainted the action bars. Defer protected changes through `KstyleUI.Combat.Queue`.
- Aura data goes secret during boss pulls, before `InCombatLockdown()` turns true. Guard aura reads with `C_Secrets.ShouldAurasBeSecret()` and freeze addon aura updates while it is true. Resume from a restriction-change event after checking again. Do not read state back from regions inside engine aura buttons.
- Check `issecretvalue` before inspecting potentially secret data. Never compare, branch on, index by, take the length of, or do arithmetic on a secret. Pass it unchanged only to an API documented to accept it.
- The combat log is closed to addons on Forever. Do not register `COMBAT_LOG_EVENT_UNFILTERED` or call `CombatLogGetCurrentEventInfo`.

**Forever only.** Do not add retail branches. Forever uses classic-era spell IDs; retail IDs do not match. Look IDs up on Wowhead Forever. The client does not load Blizzard's deprecated shims: use `C_SpellBook.IsSpellKnown`, not `IsPlayerSpell`.

Before using an API, event, template, mixin, CVar or Blizzard frame name, find it in the matching [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever). Use the source revision recorded in `Tools/data/forever_api_contracts.json`. Check `Camelot/` overrides and the secret argument/return flags in `Blizzard_APIDocumentationGenerated/`. If the source does not name an engine CVar, use the catalog's [build-matched client proof](docs/API_CONFORMANCE.md#cvar-proof) and check `GetCVarInfo` before writing. Cite the source file or native proof in the pull request. Check availability at runtime; if safety is uncertain, skip the operation. Do not silence an unknown Blizzard global in `.luacheckrc`.

## Design and implementation

1. Read the [design spec](docs/superpowers/specs/2026-11-07-kstyleui-design.md) and the [roadmap](docs/superpowers/plans/2026-11-07-kstyleui-roadmap.md) before changing code. The roadmap's Global Constraints and Core public API are binding. Start with the affected module's README and its row in the [feature map](docs/feature-map.md).
2. Match the surrounding code. Before building an options row, slider or popup, find the nearest existing example in the same module and copy its shape. Use the shared widget kit, theme tokens and pixel snapping. Create text with `K.Widgets.FontString`; place secure overlays with `K.Widgets.Cover`. Modules use the core public API, not each other's internals.
3. Write your own code. Matching another addon's behavior is fine; lifting its source is not. Record generated assets in `Media/PROVENANCE.md`. Prefer the smallest change that solves the problem; do not introduce a library for a widget the kit already has.
4. Use Lua 5.1 only. No `goto`, no `::labels::`, no integer division (`//`). A TOC-loaded Lua file has one comment, its first line: `-- <File>.lua: <what it is>.` Put the reasoning in the module README. If a player-facing string changes, run `python3 Tools/locale/strings.py sync`, not a hand edit of generated locales.

**File format.** Addon `.lua`, `.toc` and `.xml` files are ASCII only in code, comments and strings. No em dashes or curly quotes. Use CRLF line endings: `.gitattributes` sets `* -text`, so Git never converts them. Keep your editor on CRLF and never use `sed -i` from Git Bash; it strips the line endings. `python3 Tools/dev/crlf.py` repairs changed addon files. The two root instruction files are also ASCII/CRLF; text in `Tools/` and `docs/` uses UTF-8/LF.

## App driver

Iterate on the affected feature without launching the game. From the repository root:

- **Behavior:** run the feature map's regression file with `lua5.1 Tools/regression/test-<name>.lua`. Exercise the event or setting a player uses. For restricted paths, include the transition into and out of the restriction, not just steady combat.
- **Appearance:** choose the feature map's scene and settings. For example, `RENDER_SCREEN=1920x1080 RENDER_SIZE=auto RENDER_LAYOUT=DPS bash Tools/render/shoot.sh hud_reference --ppu 1 --strict` draws the real addon Lua on fixtures with LuaJIT and headless Chrome. Inspect the picture and the guard output. A render shows layout, not freedom from taint in the client.
- **Evidence:** use [the verification guide](verify/SKILL.md) for captures and [the in-game checklist](docs/TESTING.md) for checks only Forever can settle. Update the feature map when adding, removing or renaming a feature, and the [statecharts](docs/statecharts/) when changing a charted flow.

## Check and deliver

Gate: bash scripts/gate.sh

1. Branch from `origin/staging` in a separate worktree. Keep one coherent change per pull request. Before opening the pull request, have the latest GPT Sol model independently review the diff against `origin/staging`. Explain changes to `.github/workflows/`, `.pkgmeta` or `Core/Tokens.lua` in its body.
2. Run `bash scripts/gate.sh` from the root before every push, with `PR_TITLE`, `PR_BODY` or `PR_BODY_FILE`, and `PR_LABELS` set. Stage new files so pre-commit sees them. Do not install shared Git hooks. Leave `LUA` unset: the gate runs lint (including encoding and locale checks), the affected Lua tests and the Python suite. Focused tests speed up iteration; they do not replace the gate. Read its exit code, not the last line of a pipe.
3. Target `staging` for squash merge. Use `type(scope): summary`, a `## Changelog` line starting `Added:`, `Changed:` or `Fixed:` (the `no changelog` label instead for docs or tooling only), and `## In-game checks`. Recheck edited pull request wording with `bash scripts/gate.sh lint` and the same variables.
4. After each push, run the full default gate with the actual wording on the exact pushed commit. Post the `local gate` success status only for a clean `gate passed (all) at <commit>` on that commit. No pull request workflow runs the tests. See [Developing KstyleUI](docs/DEVELOPING.md) for pinned tools and how to post the mark; see [regression modes and budgets](Tools/regression/README.md) for test selection and worker limits.
5. Releases are separate: `main` follows the owner's in-game pass on `staging`. Before pushing any release tag, including a hotfix, run `bash scripts/gate.sh release` on its exact commit and quote the passing final line. This runs every Lua and Python test file, not just affected files.

The default gate runs up to six Lua files or four Python files at once; leave shared worker limits in place. `KSTYLEUI_FULL=1` admits a large selection without raising those limits. For a release on a computer with at least 30 processors, allow ten processors and 17 GB of memory.

If changing `scripts/gate.sh`, `Tools/regression/run-all.sh` or `Tools/regression/run_all.py`, include native Windows exit codes for `bash scripts/gate.sh lint` and `bash scripts/gate.sh lua --affected origin/staging`.
