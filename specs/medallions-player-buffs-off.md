# Task: Medallions — no duplicate buffs on the player frame

The owner (2026-11-22): "we have double buffs: the ones by the minimap and ones on the player frame; remove the player frame ones." In Medallions the player frame shows a buff row (`KstyleUI_UnitFrames/Settings.lua:232`, `medallionsAuras = true, medallionsAuraFilter = "buffs"`; aliasing at `:546`), while the Auras module's buff row by the minimap shows the same buffs (see `C:/Users/leeba/.cache/kstyleui-evidence/cooldowns-disabled/shot.jpg`, the icons with 10 m / 17 s / 9 m above the player portrait and the same at the top right).

Make the player frame's Medallions auras default to off, and move existing profiles that still hold the old default to off with a Store migration (follow the existing migrations' pattern; a player who changed the setting keeps their choice). The toggle stays (Unit Frames > Player > Auras in Medallions). Frames and Orbs unchanged. Check the first-run setup presets (`Core/Setup/Layouts.lua`) do not turn it back on. Minimal change.

Evidence: Medallions renders before/after at 1920x1080 and 3840x2160 over a real backdrop, `--strict`; Frames/Orbs pixel-identical. Tests: default off, migration for old default, a changed setting kept. Lint, python, UnitFrames tests, `test-taint-scan` under PUC Lua 5.1; hosted CI green. PR to `staging`: `fix(unitframes): no duplicate buffs on the Medallions player frame`, `Changed:` line. Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `Core/Store*.lua` / the migrations file (only for the migration), `Core/Setup/Layouts.lua` (only if a preset sets it; no new top-level locals), `docs/feature-map.md`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id.
