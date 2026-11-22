-- test-render-scenes-reference-sizes.lua: the reference's crest map and data bars land on their declared spots on each owner screen, the presets taking turns to stay inside the time budget.
local _, Placed = dofile("Tools/regression/render_reference_lib.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")

local screen = Reference.SCREEN
for _, case in ipairs({ { 1920, 1080, "DPS" }, { 2560, 1440, "Tank" }, { 5120, 1440, "Healer" }, { 3840, 2160, "DPS" } }) do
	Reference.SCREEN = { width = case[1], height = case[2], uiScale = 768 / 1080 }
	local built = Reference.Build({ layout = case[3], modules = { "minimap", "databars" } })
	Placed(case[3], built, case[1], case[2], { "minimap.main", "databars.xp", "databars.rep", "databars.honor" })
end
Reference.SCREEN = screen
print("ok test-render-scenes-reference-sizes")
