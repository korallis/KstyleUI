local Hud = dofile("Tools/render/scenes/hud.lua")
for _, mode in ipairs({ "hide", "keep" }) do
	local scene = Hud.Module("nameplates", { settings = { CombatText = { blizzardTargets = mode } } })
	local found = false
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and item.text == "142" then
			found = true
		end
	end
	assert(found == (mode == "keep"), "rendered native damage numbers follow " .. mode .. " CVar ownership")
end
print("render combat text ownership passed")
