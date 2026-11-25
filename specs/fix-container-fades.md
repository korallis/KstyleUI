# Task: no whole-window or whole-page alpha fades anywhere

Three live-client bugs today had the same cause: an alpha animation on a whole window or page left its content half drawn or invisible in the Forever client (the world map open fade, #789; setup pages and cards, #794; earlier the setup blank page, #764). Motion Off fixed each one in game. The owner wants this class of bug gone everywhere, consistently.

Remove alpha fades that run on a whole window, panel, page or large container, everywhere they remain, the same way #794 did for setup (show at once; keep any non-alpha motion such as a rise, and keep fades on small single elements such as a line of text, a glow, a cast bar, a notice line). Known sites (grep for more): `Core/Widgets/Panel.lua` open fade (fadeIn/fadeInAlpha, used by every KstyleUI window, then remove the setup-only `SetFromAlpha(1)` workaround in `Core/Setup/Window.lua` if it becomes redundant), `KstyleUI_Options/Window.lua:157` page fade, `KstyleUI_Options/Preview.lua:581`, `KstyleUI_Minimap/Drawer.lua:715`, `KstyleUI_Minimap/Micro.lua:108`, `Core/Widgets/Dropdown.lua:294` (dropdown menus), `KstyleUI_UnitFrames/Frames.lua:789/794` if they fade a whole frame body, `KstyleUI_QoL/Feed.lua:133` backdrop. For each, decide container vs single element and say which in the PR. If `Motion.PageIn` has no callers left, delete it.

Regression: use the stub's stalled-animation mode from #794 (`env._stalled`) to open each affected window/page/menu with Motion on and assert it is fully visible (effective alpha 1) before any animation steps; prove it fails before the fix. Evidence: renders of Options, the minimap drawer, the micro menu and a dropdown open, Motion on, before/after at 1920x1080 and 5120x1440 (settled pixels should match) in `C:/Users/leeba/.cache/kstyleui-evidence/fix-container-fades/`.

**Files it may edit**: the files above and any other Lua file with a container fade, `Core/Motion*.lua`, `Tools/regression/**`, `Tools/render/**`, READMEs that describe the fades.

**PR**: `fix(ui): windows and pages show at once instead of fading in` with a `## Changelog` `Fixed:` line and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests, lint, python; CI is the proof; at most 2 renders at once).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
