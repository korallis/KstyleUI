# Task: the player frame's resting "Zz" is unreadable (shows as two dots)

Player report (Baine, Discord 2026-11-21, hunter, Frames style, v0.2.10): two tiny green dots above the player health numbers at the frame's top right. They are the resting indicator: `KstyleUI_UnitFrames/Indicators.lua` makes it a font string "Zz" (`L["Zz"]`), sized from the icon size at the `Widgets.ApplyFont(icon, path, size, "OUTLINE")` call in the icon layout, and `Style.lua` tints it the class colour. Resting is on by default in that style. At the player's screen it renders a few pixels high, so it reads as two dots.

Fix it minimally so "Zz" is legible by default in every style and at all four test sizes (1920x1080, 2560x1440, 5120x1440, 3840x2160): find why the glyphs end up so small (font size vs icon size, the level font, the snap, the OUTLINE eating the glyph) and size it like the neighbouring icons. Keep its place and colour unless they cause the problem. Defaults otherwise unchanged; other indicators pixel-identical.

Evidence: before/after renders of the player frame while resting (Frames, Orbs, Medallions if it shows there) at the four sizes over a real backdrop, `--strict`, in `C:/Users/leeba/.cache/kstyleui-evidence/resting-zz/`. A regression test that fails on today's size. Lint, python, UnitFrames tests under PUC Lua 5.1, hosted CI green. One PR to `staging`, `fix(unitframes): readable resting Zz`, `Fixed:` line. Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id.
