# Task (v0.3.5): energy tick spark for rogues and cat druids

Energy users regenerate energy in ticks (every 2 seconds on this client family). Add a small spark that sweeps across the player's energy bar between ticks so rogues and cat druids can time their next tick, on both HUD styles' player power bar (`KstyleUI_UnitFrames`). Derive the tick from observed energy gains (UNIT_POWER_FREQUENT / UNIT_POWER_UPDATE on player energy, resync on each natural gain, ignore gains from abilities when the amount does not match a natural tick), proven from the Forever source; mind secret values (check `issecretvalue` before any comparison; if energy is secret in combat, keep the last known cadence and keep sweeping). Hide at full energy and when not on an energy power type. Its own setting, on by default, in the Unit Frames Options; matches the bar's existing spark/edge style.

Regression: gains at 2 s cadence move the spark; an ability refund does not resync it; full energy hides it; switching out of cat form hides it; secret values never compared. Evidence: player bar crops mid-sweep in both HUD styles at 1920x1080 and 5120x1440 (2x), in `C:/Users/leeba/.cache/kstyleui-evidence/v035-energy-tick/`.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `Core/Locales/*`, `Tools/locale/*`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**PR**: `feat(unitframes): an energy tick spark for rogues and cats` with a `## Changelog` `Added:` line and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof; performance: one cheap OnUpdate only while energy is below max (respect the repo's perf budgets); Beast speed rule (at most 2 renders at once).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
