# Task: Medallions unit frames don't fit and aren't polished in game

The owner (2026-11-23, v0.3.1, Medallions, 5120x1440): "the unit frames in medallion don't properly fit. they're not polished at all." In-game screenshots (5120x1440): `C:/Users/leeba/.cache/kstyleui-evidence/party-ingame-full.jpg` (2x zoom of the player frame: `uf-ingame-zoom.png`), `setup-ingame-full.jpg`, `fix-totem-fan/ingame-full.jpg`. What the zoom shows:
- The slab doesn't sit with the crest: a gap of open world between the slab's right end and the crest ring, with the totem sockets floating in it; nothing reads as one forged piece.
- The health fill's insets are uneven (wide gap from the portrait, different top and bottom margins) and the bar doesn't line up with the slab's edges.
- The power bar is pale grey/white for a shaman's mana, and a thin purple line runs past its end to the slab edge.
- The combat and status icons (crossed swords, a dagger) perch on the slab's top border, half over the edge.
- The portrait ring, the level badge and the slab meet without a clean joint.
Compare with the harness renders of the same state (`Tools/render/scenes/hud_reference.lua`, `RENDER_SCREEN=5120x1440 RENDER_LAYOUT=DPS`); where they differ, believe the game and make the stubs model it.

Do a real polish pass on the Medallions player, target and focus frames so they look premium and hand-made (benchmark: the latest CaithUI, then beat it), at every screen size:
1. Fit: each slab meets the crest ring cleanly (tucked under or capped against it, matching #743's forged ends), with no stray gap, at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, centred and spread, DPS, Tank and Healer.
2. Bars: even insets, health and power aligned to the slab, power bar in the power type's colour, no overrun line.
3. Icons: combat, leader, role, raid target and status icons sit in deliberate places inside or on a socket of the slab, never half over an edge.
4. Joints: portrait ring, level badge and slab meet cleanly.
Keep one consistent style with the party frames and the crest. Every visible change gets a setting where it makes sense, on by default.

Show the owner before merge: in `C:/Users/leeba/.cache/kstyleui-evidence/medallions-uf-polish/`, before/after crops at 5120x1440 and 1920x1080 (player and target with a cast and a combat icon), plus full HUD renders at all four sizes over a real backdrop (`game_*`), `--strict`.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `Core/Setup/Layouts.lua` (no new top-level locals), `Core/Medallions*.lua`, `Core/Widgets/UnitBar.lua` and `StatusBar.lua` (only fixes every caller benefits from), new art under `Media/` with provenance, `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**` (stubs too), `Tools/render/**`, `docs/feature-map.md`.

**PR**: `fix(unitframes): Medallions frames that fit the crest and look finished` with `## Changelog`, `## Options`, `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; no per-frame work; `test-perf-fights` and `test-perf-path-budgets` with no new ceiling; Beast speed rule (module tests locally, hosted CI as proof); another worker is changing party frame readability and a third the consumables default, so rebase before opening.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the evidence paths.
