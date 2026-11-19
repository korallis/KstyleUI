-- test-hud-reach-orbs-tank-cases.lua: the shared HUD reach check on existing layout cases, within the per-file CPU budget.
dofile("Tools/regression/hud_reach_lib.lua").Run("orbs", "Tank", "cases")
