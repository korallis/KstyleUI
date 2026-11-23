# Task: player bug — "NamePlate1:GetCenter(): Can't measure restricted regions" after combat

A player's BugSack (Forever client, KstyleUI v0.2.8.2 with the Onward guide addon 0.6.34):

```
1x NamePlate1:GetCenter(): Action[FrameMeasurement] failed because[Can't measure restricted regions]: attempted from: NamePlate1:GetCenter().
Lua Taint: Onward
[Onward/Core.lua]:106: in function 'Fire'
[Onward/Core.lua]:110: in function <Onward/Core.lua:110>
Locals: event="PLAYER_REGEN_ENABLED", ok=false
```

Onward's PLAYER_REGEN_ENABLED handler measures Blizzard's nameplate base frame and the game refuses. We cannot change Onward. **Find out whether KstyleUI makes that measurement fail**, and fix it if so.

**Leads to check, with proof against the `forever` branch of Gethe/wow-ui-source at `9dc84f0` (clone `C:\Users\leeba\.cache\wow-ui-source`)**:
- KstyleUI_Nameplates runs queued work on `PLAYER_REGEN_ENABLED` (`Combat.Queue`): `C_NamePlate.SetNamePlateSize` from `Stacking.lua`, the nameplate scale CVars, aura restyles. Does addon-called `SetNamePlateSize`, a CVar write or anything else we do leave nameplate base frames restricted (or their rects invalid) for the rest of that frame? What makes a region "restricted" for measurement on this client (search the API docs and `Blizzard_NamePlates`)?
- Anything that anchors, scales or parents a Blizzard nameplate base (`NamePlateN`) or makes its rect depend on secret values.
- Whether Blizzard's own code guards measurement of nameplates (e.g. `IsRectValid`, `CanAccessObject`, restricted checks) and when plates stop being restricted after combat.

**If KstyleUI contributes**: fix it with the smallest change (for example, defer our post-combat nameplate work so it never runs in the same handler pass as other addons' `PLAYER_REGEN_ENABLED`, or avoid the call that restricts the base), keep today's look pixel-identical, and add a stub regression that fails on the old code (extend the stubs to raise the client's "Can't measure restricted regions" for the case you prove, as `test-stub-refusals.lua` describes). Open a PR to `staging`: `fix(nameplates): ...`, a `Fixed:` changelog line in player words, Forever proof file:line in the body.

**If KstyleUI does not contribute**: no code change. Write the proof (what restricts the plate, why our code cannot) in your report, plus a short, friendly player-facing reply naming Onward as the source and the one-line guard Onward's author needs.

**Checks**: lint, python, the nameplate tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Beast speed rule. Do not merge.

**Files it may edit**: `KstyleUI_Nameplates/**`, `Core/Combat.lua` (only if the fix belongs there), `Tools/regression/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the verdict, PR/SHA/run id if any.
