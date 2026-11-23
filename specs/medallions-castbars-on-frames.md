# Task: Medallions — move the player and target cast bars onto their frames (frees the lane above the crest)

The owner decided (2026-11-21) that the class crowns above the Medallions crest (PR #678, worker ctx_06ee5ccda572: rogue crown of blades, druid claws, paladin sun-spears, warlock shards, at the full approved size, about 44 units) keep their size, and the cast bars that sit in the lane above the crest move instead: "move the cast bar onto the player frame and target frame". Today in Medallions the player cast bar (and the bar above it, e.g. the target's cast / the GCD "SNAP" bar; confirm which) stack just above the crest (see `C:/Users/leeba/.cache/kstyleui-evidence/class-pips/crown-concepts-druid-paladin-warlock.png`).

- In Medallions, attach the player cast bar to the player frame and the target cast bar to the target frame (the side frames beside the crest), forged to match those frames (one consistent style; width of the frame, same chrome as the Frames style's on-frame cast bars where possible). Nothing stays in the lane above the crest's rune ring.
- Interrupts, channel ticks, latency, GCD fill, spark, icon, important-cast colours and every existing cast-bar setting keep working.
- Setting **Cast bars on unit frames** (Medallions), ON by default; off restores today's placement pixel-for-pixel. Frames and Orbs unchanged.
- Layout Mode and saved positions: a player who moved the cast bar keeps their position (test saved positions). Update `docs/statecharts/` if the HUD style switch chart covers cast bar placement, and the feature-map row.
- Evidence: Medallions (DPS, Tank, Healer; centred and spread) at 1920x1080, 2560x1440, 5120x1440, 3840x2160 over real backdrops, `--strict`, casting (player and target), in `C:/Users/leeba/.cache/kstyleui-evidence/castbars-on-frames/`; zero pixel diffs for Frames/Orbs and with the setting off.

Lint, python, UnitFrames and ActionBars tests, `test-perf*`, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. One PR to `staging`, `feat(medallions): cast bars on the player and target frames`, `Changed:` line. Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_ActionBars/**` (only where Medallions places cast bars), `Core/Setup/Layouts.lua` (only if the defaults live there), `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `docs/statecharts/**`, `docs/medallions.md`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and evidence paths.
