-- test-hud-material-alt.lua: the raw DPS reference HUD draws every card in Slate (grain only) and ForgedTicks (grain and frame, no brackets).
local Lib = dofile("Tools/regression/hud_material_lib.lua")

for _, material in ipairs({ "Slate", "ForgedTicks" }) do
	local cards = Lib.Audit(Lib.Build("DPS", material), material, Lib.ROLES.DPS)
	assert(#cards == #Lib.ROLES.DPS, "DPS draws " .. #Lib.ROLES.DPS .. " cards in " .. material .. ", got " .. #cards)
end
print("ok test-hud-material-alt")
