# Task: v0.3.1 explorer, nearest services and click a quest to route

Two roadmap highlights for the world map travel companion (`docs/ROADMAP.md`, v0.3.1):
1. "Find the nearest innkeeper, trainer, bank, auction house, repair or reagent vendor, and route there."
2. "Click a quest on the quest card to route straight to it."

Read `KstyleUI_Routes/README.md`, the world map and route code in `KstyleUI_Skins/` and `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/design.md` first.

**Data rule (binding)**: map data comes only from the Forever client files or the live game API. Never copy Wowhead, wclbox or another addon's data. NPC positions are not in the client files, so build services from what the game tells us safely: an in-game recorder that saves a service NPC's position (from the player's map position) when the player opens its merchant, trainer, bank, auction or inn window, shared across characters in saved variables, plus any service positions the client files or live API give (city map POIs, `C_Map` and `C_AreaPoiInfo` data, guards' directions where provable). Show recorded and known services on the map with a "nearest" picker that routes with the existing road graph. Unknown services say so plainly instead of guessing.

Quest routing: clicking a quest on the quest card (the story rail quest list) routes to its objective using `C_QuestLog` waypoint and POI data where the API gives it; with no position, it says so.

**Files you own**: the world map and route code in `KstyleUI_Skins/**` (map and route files only), `KstyleUI_Routes/**` (no graph regeneration needed), the quest card click handler, `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`. Another worker is adding map reveal and travel stops in parallel: keep to services and quest routing, and rebase before opening.

**PR title**: `feat(worldmap): nearest services and click a quest to route`.

The shared rules below were written for the v0.3.0 workers; they apply to you too (evidence folder `v031-<your-slug>`; ten workers run in parallel).

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

**Evidence** (in `C:/Users/leeba/.cache/kstyleui-evidence/v031-<your-slug>/`, never committed): `--strict` renders over a real game backdrop (`game_*` in `~/.cache/kstyleui-backdrops`) at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, for Medallions and Frames, with the feature on; a base-against-PR pixel diff with the feature off that must be zero; an animated GIF or frame strip for anything that moves. At most 2 renders at a time on this machine.

**Gate**: lint, python, the tests that load your files (`run-all.sh --affected origin/staging`, no full local suite) under PUC Lua 5.1, `test-perf-fights` and `test-perf-path-budgets`, then hosted GitHub CI as the proof (no Mac runs).

**PR**: not a draft, against `staging`, Conventional Commits title, `## Changelog` (`Added:`/`Changed:` lines in plain player words, no AI tells), `## Options`, `## In-game checks`, `## Forever API`, and the evidence folder path. Several workers touch `Core/Locales/**` and `Tools/locale/*.json`: rebase onto `origin/staging` right before opening and keep both sides' strings. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, what you built, what already existed and anything you left out with why.
