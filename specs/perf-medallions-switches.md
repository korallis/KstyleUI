# Task: two Medallions effect switches (perf levers, defaults unchanged)

From the draw-cost research (`C:/Users/leeba/.cache/kstyleui-evidence/perf-gpu/REPORT.md`, items 3 and 4): the Medallions low-health vignette keeps 16 border textures (about 0.7 screens) shown at alpha 0 above 40% health with an endless breath, and the hub runs 11 ambient loops at idle (16 in combat). Health is secret, so the vignette cannot be culled by Lua without changing the look. Give players a lever:

1. **Low-health vignette** (Medallions page, ON by default): off hides the vignette textures (Hide, not alpha 0) and stops its breath; the portrait ring warning and other low-health cues stay.
2. **Ambient hub effects** (Medallions page, ON by default): off stops and hides the hub's ambient loops (runes, breaths, particles), leaving the static hub art; event flashes (casts, procs) stay unless Motion is Off.

Defaults: pixel-identical to staging (both on). Off states: renders at four sizes showing the static look; draw census (`probes/gpu.lua` from the report folder) showing shown-region and loop counts drop; no OnUpdate/AnimationGroup running for the disabled effect. Regressions for both switches (on = today, off = hidden and idle, toggling back restores). Translations via `strings.py sync`. Feature map rows. Lint, python, unit frame/action bar/Medallions tests, `test-perf-idle-draw` (from PR #673 if merged; otherwise add the equivalent check), `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. One PR to `staging`, `feat(medallions): ...`, `Added:` line. Do not merge.

**Files it may edit**: Medallions effect code (`KstyleUI_UnitFrames/**`, `KstyleUI_ActionBars/**` where the hub/vignette live), their Settings, `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `docs/medallions-effects.md`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and the before/after counts.
