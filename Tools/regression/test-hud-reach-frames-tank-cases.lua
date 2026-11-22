-- test-hud-reach-frames-tank-cases.lua: the shared HUD reach check on existing layout cases, within the per-file CPU budget.
dofile("Tools/regression/hud_reach_lib.lua").Run("frames", "Tank", "cases")
