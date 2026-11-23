# Task: Medallions unit frames honour their settings, plus previews

Pre-existing Medallions defects (`C:/Users/leeba/.cache/kstyleui-evidence/medallions-defects/pr-695-possible-bugs.md`, `helper-B-report.md`). Fix:
- The slab ignores `healthHeight`, `powerAbove` and `healthTexture` (make them apply, or hide the rows if Medallions cannot honour them; say which).
- A plate relayout that brings the power bar in repaints its text only on the next power event.
- Focus and boss aura tiles put the stack count over the timer.
- The boss scrim (88 for a 72 frame) runs past the 6-unit gap.
- The focus slab cuts long names (ELUNARA FROSTWEAVER in the gallery scene); drop its guard_allow line when fixed.
- A TOP text bar on the target moves its side auras (y 22 to 18).
- Options preview: no target cast sample (`castbarImportant`, `castbarTarget`); target and boss markers and a 220-unit boss name run past the pane; the party badge ring bleeds 1 unit past it.
- Dead under Medallions: `castbarTexture` and the XP bar's texture, segments, text and font size (make them work or remove the rows).
Do NOT touch the per-mode aura defaults (ROW_DEFAULTS/SLAB_DEFAULTS); that is a separate follow-up.

PR: `fix(unitframes): Medallions frames honour their settings`, `Fixed:` line.

**Rules**: minimal code; defaults pixel-identical to staging except where a fix intends (prove with --strict renders over real backdrops at 1920x1080, 2560x1440, 5120x1440, 3840x2160); a regression test per fix that fails on staging; lint, python, module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Max 2 renders at a time. Do not merge. Skip any item you can prove is already fixed on staging (say so).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and evidence paths.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_Options/**` (previews only), `KstyleUI_DataBars/**` (XP bar settings only), `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `Tools/regression/**`, `Tools/render/**`.
