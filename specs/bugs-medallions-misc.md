# Task: the remaining small Medallions bugs (nameplates, bags, RestedXP, chat, ranks, data bars)

Pre-existing Medallions defects (`C:/Users/leeba/.cache/kstyleui-evidence/medallions-defects/pr-695-possible-bugs.md`, `helper-B-report.md`, `helper-A-summary.txt`). Fix, skipping any you prove already fixed on staging:
- Nameplates ignore `level.font` (`KstyleUI_Nameplates/Medallions.lua` StyleType sets the number font unguarded); the Medallions 9-unit bar flips to 12 when the preset becomes Custom; the plate height changes on an outline round-trip.
- Bags: the Readable headings band never applies (`MeasureHeader` 35 overrides the Bags header 40); `MeasureHeader` also drops a caller's band when no cap is in reach (`LFGWhoListFrame`).
- RestedXP: the guide card runs 48 to 58 units below its story slot; the guide element is shorter than the step at Auto size.
- Chat: the Options preview draws a rule the live panel does not.
- Action bar ranks read `cfg.growth` while the slab lays out RIGHTDOWN.
- DataBars: switching the dock to Right rail leaves unchanged values in the dock's muted ink until each value changes.
- Render reference: the reputation and honor bars sit lower than declared (26.4 vs 39.8); the hub's level-up caption uses a fractional font size; the crest map is sub-pixel off.

PR: `fix: small Medallions fixes (nameplates, bags, RestedXP, chat, ranks, data bars)`, `Fixed:` line. If it grows past one coherent PR, split nameplates into its own.

**Rules**: minimal code; defaults pixel-identical to staging except where a fix intends (prove with --strict renders over real backdrops at 1920x1080, 2560x1440, 5120x1440, 3840x2160); a regression test per fix that fails on staging; lint, python, module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Max 2 renders at a time. Do not merge.

**Files it may edit**: `KstyleUI_Nameplates/**`, `KstyleUI_Bags/**`, `KstyleUI_Skins/**`, `KstyleUI_Chat/**`, `KstyleUI_ActionBars/**` (ranks only), `KstyleUI_DataBars/**`, `KstyleUI_Options/**` (chat preview only), `Core/Skin.lua` (MeasureHeader only), `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR(s), SHA, run id and evidence paths.
