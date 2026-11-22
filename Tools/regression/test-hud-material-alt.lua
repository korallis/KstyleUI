-- test-hud-material-alt.lua: the raw Frames DPS reference HUD draws every card in Slate (grain only) and ForgedTicks (grain and frame, no brackets).
local Lib = dofile("Tools/regression/hud_material_lib.lua")

for _, material in ipairs({ "Slate", "ForgedTicks" }) do
	local cards = Lib.Audit(Lib.Build("DPS", material), Lib.FRAMES_ROLES.DPS, material)
	assert(#cards == #Lib.FRAMES_ROLES.DPS, "Frames DPS draws " .. #Lib.FRAMES_ROLES.DPS .. " cards in " .. material .. ", got " .. #cards)
end
print("ok test-hud-material-alt")
