# Task: action bar EllesmereUI parity, batch 1: text placement, cooldown look, item rarity borders, picker comfort

The owner wants action bar customisation that rivals EllesmereUI. Read the parity audit in `KstyleUI_ActionBars/README.md`, "EllesmereUI parity audit (2026-11-20)", on `origin/staging`. Build these **Missing** rows (public behaviour only; copy no code):

1. **Text corner and edge placement:**
   - per bar, choose where keybind, count, macro and cooldown text sit: one of the four corners, a centre edge or the centre, with small x and y nudges;
   - it must respect the consumables compact rules from PR #558 (count wins under 30 units);
   - defaults equal today's positions.
2. **Cooldown look:**
   - per bar, Desaturate on cooldown (defaults to today's behaviour);
   - Swipe opacity (defaults to today's value);
   - prove the cooldown APIs in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0` and guard each one.
3. **Equipped-item rarity border:**
   - buttons holding an equippable item show its quality colour on the button border;
   - an Options toggle, ON by default; it's a small visual addition players expect from EllesmereUI;
   - item state comes from events the client proves, with no per-frame work.
4. **Picker comfort** (the follow-ups from #559):
   - the bar picker stays visible while the page scrolls, if the Options kit can do it cheaply;
   - in Layout Mode, double-clicking a bar's mover (click selects, right-click resets) opens the Options page on that bar.

**Rules**:
- Everything per bar, using the existing schema and `BarRows`; minimal code; one consistent style.
- New options are toggleable, and their defaults keep today's look unless stated above.
- No per-frame work; stay within the reload budget (`test-perf-path-budgets`).
- Protected changes are queued in combat.

**Tests**:
- each option writes and applies for one bar only;
- defaults are unchanged;
- the rarity border follows equip, unequip and swap events;
- double-click opens the right bar page;
- the perf budget passes.

**Renders**: buttons with each text placement, desaturated cooldowns and rarity borders at 1920x1080 and 5120x1440, plus the Options page. Use `--strict` and real game backdrops. Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/ab-parity-1/`, never committed.

**PR**: open a PR (not a draft) against `staging` titled `feat(actionbars): text placement, cooldown look and item rarity borders per bar`. Include:
- `## Changelog`, with `Added:` lines;
- `## Options`, `## In-game checks` and `## Before and after`;
- an update to the README parity table (rows to Present).

Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_Options/**`, `Core/Layout/**` (the mover double-click only), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**Constraints**: CRLF/ASCII; locales synced with translations. Beast speed rule: no full local Lua suite, at most 2 renders at a time. If PR #558 (consumables compact text) hasn't merged when you start, build on `origin/staging` and rebase before opening.

**Gate**: lint, python, the actionbars and options tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
