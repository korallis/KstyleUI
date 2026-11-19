-- test-hud-reach-orbs-healer-screens-16-18.lua: the shared HUD reach matrix for orbs Healer, within the per-file CPU budget.
dofile("Tools/regression/hud_reach_lib.lua").Run("orbs", "Healer", {16,18})
