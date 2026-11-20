-- worldmap_routes.lua: client destination search and a straight route in the real world map skin, over a game plate.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local M = dofile("Tools/regression/worldmap_env.lua")

return Common.Run(function()
	local map
	local env, K, ns = M.S.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Skins" }),
		setup = Gallery.Setup,
		before = function(e)
			map = M.Windows.Build("worldmap", e, M.S.Blizzard(e))
			M.Setup(e, map)
			map:ClearAllPoints()
			map:SetPoint("CENTER", e.UIParent, "CENTER", -165, 0)
		end,
	}))
	K.Modules.Enable("Skins")
	M.S.LoadAddOn(env, "Blizzard_WorldMap")
	M.S.Show(map)
	M.S.Show(env.QuestMapFrame)
	env.RunTimers()
	M.S.W.Settle(env)
	local R = ns.WorldMapRoutes
	if os.getenv("RENDER_MAP_BEFORE") == "1" then
		for _, key in ipairs({ "routes", "dungeonLevels", "zoneLevels", "entrances" }) do K.Options.Write("Skins", "worldMap." .. key, false) end
	else
		R.Pick(R.Search("Chasm")[1])
		R.search:SetText("Ragefire")
		R.search:GetScript("OnTextChanged")(R.search, true)
	end
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = "Blizzard map canvas is a stand-in; game backdrop is the real forest/town plate. Destination data is a client-shaped fixture."
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return scene
end)
