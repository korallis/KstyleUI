# Task: v0.3.0 polish, Medallions finish: slab end caps and a calmer resting crest

Roadmap highlight: "Medallions finish: slab end caps and a calmer resting crest." Medallions HUD only.

1. Slab end caps: the Medallions unit slabs (player, target, focus and their bars) get hand-finished end caps so each slab ends in a forged, deliberate shape instead of a plain cut. Match the crest's metal and light; pixel-snapped at every scale.
2. Calmer resting crest: out of combat and idle, the crest's ambient motion (glows, shimmer, pulses) settles to a slow, quiet breath; it wakes to full on combat, a target or a proc. No extra cost at rest: fewer animations, not more.

Keep every existing crest feature (class crowns, hawk perch, spirit poles, storm orbs) correct with the new caps and the calm state.

**Files you own**: `Core/Medallions.lua`, `Core/MedallionAssets.lua`, `Core/Effects*.lua` (crest motion only), Medallions slab code in `KstyleUI_UnitFrames/**` (slab shape only), new Medallions art under `Media/` (with provenance), `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**`. Another worker is adding a glass finish to bar fills; keep to the caps and crest motion.

**Evidence extra**: a GIF of the crest settling and waking. Frames renders only to prove zero change there.

**PR title**: `feat(medallions): slab end caps and a calmer resting crest`.

## Shared rules for every v0.3.0 polish worker

**Context**: v0.3.0 is "the polish release" in `docs/ROADMAP.md` on `origin/staging`. Eight workers run in parallel, one per highlight, each owning separate files. The benchmark is the latest CaithUI: match it first, then clearly beat it (premium, hand-made, never generic or AI-looking).

**First step, always**: audit what already exists on `origin/staging` for your highlight (grep the code, the module READMEs, `docs/feature-map.md`, the spec in `docs/superpowers/specs/`). Build only the gaps. If something is already done, say so in the PR body with the proving file.

**Rules**:
- Minimal code. Reuse `K.Widgets`, `Core/Motion.lua`, `Core/Tokens.lua` values and the shared builders; add no framework.
- Everything toggleable: each change gets an Options setting, ON by default, and switching it off restores today's look and behaviour exactly. First-run setup stays one click.
- Both HUD styles: Medallions (the default) and Frames. Build a Frames form wherever it makes sense; one consistent style within each look. Never build or render Orbs.
- Never fight other addons: no per-frame work, no repeated hooks, nothing loaded or animated when the feature is off or not in view; secure changes wait for combat to end. `Tools/regression/test-perf-fights.lua` and `test-perf-path-budgets` must stay green with no new ceiling.
- Every Forever API, event, template or CVar is proven at wow-ui-source `forever` commit `9dc84f0` (name the file in the PR), guarded with an existence check and `issecretvalue`.
- Player-facing strings: `python3 Tools/locale/strings.py sync` with translations. CRLF/ASCII addon files (`python3 Tools/dev/crlf.py`).
- If your highlight changes a flow charted in `docs/statecharts/` or a feature row in `docs/feature-map.md`, update it in the same PR.

**Evidence** (in `C:/Users/leeba/.cache/kstyleui-evidence/v030-<your-slug>/`, never committed): `--strict` renders over a real game backdrop (`game_*` in `~/.cache/kstyleui-backdrops`) at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, for Medallions and Frames, with the feature on; a base-against-PR pixel diff with the feature off that must be zero; an animated GIF or frame strip for anything that moves. At most 2 renders at a time on this machine.

**Gate**: lint, python, the tests that load your files (`run-all.sh --affected origin/staging`, no full local suite) under PUC Lua 5.1, `test-perf-fights` and `test-perf-path-budgets`, then hosted GitHub CI as the proof (no Mac runs).

**PR**: not a draft, against `staging`, Conventional Commits title, `## Changelog` (`Added:`/`Changed:` lines in plain player words, no AI tells), `## Options`, `## In-game checks`, `## Forever API`, and the evidence folder path. Several workers touch `Core/Locales/**` and `Tools/locale/*.json`: rebase onto `origin/staging` right before opening and keep both sides' strings. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, what you built, what already existed and anything you left out with why.
