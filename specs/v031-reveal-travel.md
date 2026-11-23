# Task: v0.3.1 explorer, reveal unexplored areas and more travel stops

Two roadmap highlights for the world map travel companion (`docs/ROADMAP.md`, v0.3.1):
1. "Optionally reveal unexplored areas of the map."
2. "More travel stops: every boat, zeppelin, portal and your own hearth and class teleports on the route."

Read `KstyleUI_Routes/README.md`, the world map and route code in `KstyleUI_Skins/`, `Tools/nav/` and `C:/Users/leeba/.cache/kstyleui-evidence/world-map-nav/design.md` first.

**Data rule (binding)**: data comes only from the Forever client files (DB2 extracts such as the world map overlay, map link, taxi and transport tables, extracted with the existing `Tools/nav` tooling) or the live game API. Never copy Wowhead, wclbox or another addon's data. Record the client build and the extraction tool commit in the README.

1. Reveal: an Options toggle (off by default: it changes what the map shows) that draws unexplored overlays dimmed, from the client's overlay table, on the KstyleUI map skin. Load the overlay data on demand only when the toggle is on and the map is open.
2. Travel stops: add every boat, zeppelin, portal and tram the client data proves to the route graph as timed travel edges; add the player's hearthstone (bound location from `GetBindLocation` where it maps) and class teleports and portals the player knows (`IsSpellKnown`, cooldown-aware) as route options; the route picks them only when faster, and shows each leg plainly.

**Files you own**: `Tools/nav/**`, `KstyleUI_Routes/**` (regenerated data, still load-on-demand and out of login), the map overlay and route option code in `KstyleUI_Skins/**` (map files only), `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**` (keep `test-perf-worldmap-roads` within budget), `Tools/render/**`, `docs/feature-map.md`. Another worker is adding nearest services and quest routing in parallel: keep to reveal and travel stops, and rebase before opening.

**PR title**: `feat(worldmap): reveal unexplored areas and more travel stops`.

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
