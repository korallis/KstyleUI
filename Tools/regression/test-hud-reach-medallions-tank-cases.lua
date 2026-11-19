-- test-hud-reach-medallions-tank-cases.lua: the shared HUD reach check on existing layout cases, within the per-file CPU budget.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "Tank", "cases")
