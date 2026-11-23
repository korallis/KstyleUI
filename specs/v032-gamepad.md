# Task: v0.3.2, a gamepad-friendly layout

Roadmap (`docs/ROADMAP.md`): "v0.3.2 — gamepad: a gamepad-friendly layout."

Research first what Forever supports for controllers at `9dc84f0`: the `GamePad*` CVars, `C_GamePad`, `GAME_PAD_ACTIVE_CHANGED` / `GAME_PAD_CONNECTED`, the binding names in `Tools/data/gamepad_actionbar_names.txt`, and how Blizzard's own UI shows gamepad button glyphs. Then build the smallest complete version:
1. When a gamepad is active (and an Options switch is on), action bar keybind text shows controller button glyphs instead of keyboard keys, using the game's own glyph atlas, in both HUD styles.
2. A "Gamepad" choice in first-run setup and on the General page that applies a controller-friendly arrangement (bars grouped as left and right clusters around the crest or frames, bigger targets) by setting existing layout settings only; a Look-style one-click, with a way back.
3. Anything Forever can't support safely is left out and named in the PR.

Default: the glyph swap is on only while a gamepad is active (so keyboard players see no change); the Gamepad arrangement is opt-in.

**Files you own**: `KstyleUI_ActionBars/**` (keybind text only), `Core/Setup/**` (the Gamepad choice, no new top-level locals in `Layouts.lua`), `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `docs/statecharts/` (setup chart).

**PR title**: `feat(gamepad): controller glyphs and a gamepad layout`.

The shared rules below were written for the v0.3.0 workers; they apply to you too (evidence folder `v032-<your-slug>`).

## Shared rules for every v0.3.0 polish worker

**Context**: v0.3.0 is "the polish release" in `docs/ROADMAP.md` on `origin/staging`. v0.3.1 has shipped; this is v0.3.2 work. The benchmark is the latest CaithUI: match it first, then clearly beat it (premium, hand-made, never generic or AI-looking).

**First step, always**: audit what already exists on `origin/staging` for your highlight (grep the code, the module READMEs, `docs/feature-map.md`, the spec in `docs/superpowers/specs/`). Build only the gaps. If something is already done, say so in the PR body with the proving file.

**Rules**:
- Minimal code. Reuse `K.Widgets`, `Core/Motion.lua`, `Core/Tokens.lua` values and the shared builders; add no framework.
- Everything toggleable: each change gets an Options setting, ON by default, and switching it off restores today's look and behaviour exactly. First-run setup stays one click.
- Both HUD styles: Medallions (the default) and Frames. Build a Frames form wherever it makes sense; one consistent style within each look. Never build or render Orbs.
- Never fight other addons: no per-frame work, no repeated hooks, nothing loaded or animated when the feature is off or not in view; secure changes wait for combat to end. `Tools/regression/test-perf-fights.lua` and `test-perf-path-budgets` must stay green with no new ceiling.
- Every Forever API, event, template or CVar is proven at wow-ui-source `forever` commit `9dc84f0` (name the file in the PR), guarded with an existence check and `issecretvalue`.
- Player-facing strings: `python3 Tools/locale/strings.py sync` with translations. CRLF/ASCII addon files (`python3 Tools/dev/crlf.py`).
- If your highlight changes a flow charted in `docs/statecharts/` or a feature row in `docs/feature-map.md`, update it in the same PR.

**Evidence** (in `C:/Users/leeba/.cache/kstyleui-evidence/v032-<your-slug>/`, never committed): `--strict` renders over a real game backdrop (`game_*` in `~/.cache/kstyleui-backdrops`) at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, for Medallions and Frames, with the feature on; a base-against-PR pixel diff with the feature off that must be zero; an animated GIF or frame strip for anything that moves. At most 2 renders at a time on this machine.

**Gate**: lint, python, the tests that load your files (`run-all.sh --affected origin/staging`, no full local suite) under PUC Lua 5.1, `test-perf-fights` and `test-perf-path-budgets`, then hosted GitHub CI as the proof (no Mac runs).

**PR**: not a draft, against `staging`, Conventional Commits title, `## Changelog` (`Added:`/`Changed:` lines in plain player words, no AI tells), `## Options`, `## In-game checks`, `## Forever API`, and the evidence folder path. Several workers touch `Core/Locales/**` and `Tools/locale/*.json`: rebase onto `origin/staging` right before opening and keep both sides' strings. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, what you built, what already existed and anything you left out with why.
