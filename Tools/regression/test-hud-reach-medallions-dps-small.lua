-- test-hud-reach-medallions-dps-small.lua: the shared HUD reach check on existing layout small, within the per-file CPU budget.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "DPS", "small")
