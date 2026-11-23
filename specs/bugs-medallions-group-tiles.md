# Task: Medallions raid tiles and party rows honour their settings

Pre-existing Medallions defects (`C:/Users/leeba/.cache/kstyleui-evidence/medallions-defects/pr-695-possible-bugs.md` and `helper-B-report.md` beside it). Fix:
- Raid tiles: debuff pips not pixel-snapped (8 vs 8.1 at fractional scales); `auras.timers` binds no time-left text; `auras.zoom`, `auras.tooltips` and `buffs.tooltips` do not reach the tile icons; saved `text.nameFont` overridden by Inter; no role icon (role in ring with no ring); leader/marker sit over heals; short names cut (MEMBER7 to MEM7 at 116x36); tile collisions and stale restyles from helper B's report.
- Party: `party.portraitZoom` does nothing on the painted badges; twelve-letter names cut in the lane; at 40x16 the pip, marker and percent collide (raid: leader, marker and percent); party rows and raid tiles lay out no boss debuff slot.

PR: `fix(groupframes): Medallions raid tiles and party rows honour their settings`, `Fixed:` line.

**Rules**: minimal code; defaults pixel-identical to staging except where a fix intends (prove with --strict renders over real backdrops at 1920x1080, 2560x1440, 5120x1440, 3840x2160); a regression test per fix that fails on staging; lint, python, module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Max 2 renders at a time. Do not merge. Skip any item you can prove is already fixed on staging (say so).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and evidence paths.

**Files it may edit**: `KstyleUI_GroupFrames/**`, `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `Tools/regression/**`, `Tools/render/**`.
