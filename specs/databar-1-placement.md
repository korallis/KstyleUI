# Task: data bar batch 1: the strip grows into a top bar with zones

**Goal**: build batch 1 of the approved XIV-style data bar. The design is `C:/Users/leeba/.cache/kstyleui-evidence/xiv-databar/design.md` (sections 4 to 7, PR 1), with mockups in the same folder (`mockup_frames_1080.png`, `closeup_frames_bar_2x.png`). Follow it except where the owner decisions below override it.

**Owner decisions**:
- **On for everyone**, existing players included. Add a Store migration: take the next free number when you rebase, since other PRs may also add one. Changelog line to match.
- **One clock.** While the bar shows a clock, the minimap foot hides its clock. When the bar is off or its clock is off, the minimap clock comes back.
- **Top first.**
  - Frames and Orbs get the full-width top bar.
  - Medallions keeps today's rail placement in this batch; the slab dock is batch 5.
  - Bottom placement is not in scope.

**Scope (PR 1 only)**:
- `strip.placement` (top / rail);
- left, centre and right zones;
- height (12-32, default 20) and background (0-100%, default 85%);
- the ForgedBrackets card chrome with only the bottom edge on screen;
- `MAX_WIDTH` raised to the root width;
- the Layout top inset in `Place` and the same inset in `Layouts.Rect` / `Fits` / `ScaleLimit`, so the guard sees what the game draws;
- the migration and the one-clock rule.

The existing five items keep their order in the right zone. New modules, the Options module list, the micro-menu dock and the Medallions dock are later batches; do not build them.

**Tests**:
- the inset is applied identically in Place and Fits, including players' saved top-anchored positions;
- the overlap guard passes in Frames, Orbs and Medallions, for DPS, Tank and Healer, at 1920x1080, 2560x1440, 5120x1440 (Centred and Spread) and 3840x2160;
- the migration turns the bar on for an existing profile;
- the minimap clock hides and returns.

Renders before and after at the four sizes in Frames and Orbs (`--strict`), plus Medallions unchanged.

**Constraints**: minimal code; AGENTS.md rules; evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/databar-1/`). Open a **draft** PR against `staging` titled `feat(databars): the data strip grows into a top bar` with `## Changelog` (`Added: A data bar along the top of the screen in Frames and Orbs, with your frame rate, latency, gold, durability and clock in three zones. Change it under Data bar in Options.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `KstyleUI_DataBars/**`, `KstyleUI_Minimap/**` (the clock hide only), `Core/Layout/Layout.lua`, `Core/Setup/Layouts.lua` (no new top-level local), `Core/Store.lua` (migration), `KstyleUI_Options/**` (the new rows only), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `docs/statecharts/**` if a charted flow changes, the module README.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.

**Owner addition**: the bar is a Layout Mode element the player can move anywhere. The top inset applies only while it sits at its default top placement; moved or off means an inset of 0.

**Owner addition 2**: a "Data bar artwork" choice: Forged (default; card chrome plus existing gilt edge, corner brackets and a small crest gem from repo art) or Plain (glass plate). Existing art only.
