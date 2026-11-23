# Task: KstyleUI is Medallions only — remove the Frames and Orbs HUD styles

The owner decided (2026-11-22): "to avoid confusion, let's remove the other layouts, Medallions is the one we want" — remove Frames and Orbs **entirely** (confirmed). Less code, one look.

**Do:**
1. Map every place the HUD style is chosen or branched on (`Core/` HudStyle service, `KstyleUI_UnitFrames/`, `KstyleUI_ActionBars/`, `KstyleUI_Options/`, `Core/Setup/` first-run setup and `Layouts.lua`, Layout Mode, `docs/statecharts/` HUD style switch). Delete the Frames and Orbs styles and their code paths, art and settings that only they use; keep anything Medallions still uses. Prefer deleting to adding; no compatibility shims beyond the migration.
2. **Migration**: a Store migration moves any profile on Frames or Orbs to Medallions, keeps their other settings, and prints one short chat line once ("KstyleUI is now Medallions only; your HUD moved to Medallions."). Drop saved keys only Frames/Orbs read.
3. **Options and setup**: remove the HUD style choice (or leave nothing to choose); setup goes straight to Medallions; previews and What's new stay correct.
4. **Tests and harness**: delete Frames/Orbs-only tests and render scenes/variables (`RENDER_HUD_STYLE` keeps working for Medallions or goes away; update `Tools/render/README.md`, `docs/feature-map.md`); keep coverage for everything Medallions uses. Update the HUD style statechart (or remove it if there is no switch left).
5. **Docs**: README, `docs/store/description.md` (+ `python3 Tools/media/marketing.py`), `docs/medallions.md`, module READMEs: no Frames/Orbs mentions; remove Frames/Orbs pictures from README/store.
6. Medallions must be pixel-identical to staging at 1920x1080, 2560x1440, 5120x1440, 3840x2160 (DPS/Tank/Healer, centred/spread) over real backdrops, `--strict`; show the diff summary.

Gate: lint, python, the full Lua suite on hosted CI (this touches many files), `test-taint-scan`, `test-perf-path-budgets`, reload budget (should drop). PR to `staging`: `refactor(hud): Medallions only — remove Frames and Orbs`, `Changed:` line telling players their HUD moves to Medallions. Report lines removed. Do not merge.

**Note**: other workers are building the shaman Spirit Poles, Lightning Shield and class crowns; they are told to skip Frames/Orbs. Rebase before your final push; flag conflicts.

**Files it may edit**: any addon file, `Media/**`, `Core/**`, `KstyleUI_*/**`, `Core/Locales/*`, `Tools/locale/*`, `Tools/regression/**`, `Tools/render/**`, `docs/**`, `README.md`, `.luacheckrc` (removing names only).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id, lines removed and evidence paths.
