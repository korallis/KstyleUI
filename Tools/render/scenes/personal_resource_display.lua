-- personal_resource_display.lua: a level-five tauren caster druid's real Medallions HUD; the Blizzard PRD fixture illustrates nameplateShowSelf visibility rather than claiming live Blizzard geometry.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
return Common.Run(function()
	local U = dofile("Tools/regression/unitframes_env.lua")
	local CT = dofile("Tools/regression/combattext_env.lua")
	local Load = dofile("Tools/regression/load_files.lua")
	local N = dofile("Tools/regression/nameplates_env.lua")
	local env, K, ns = U.New(Common.ScreenOpts({
		login = false,
		saved = Gallery.Saved({ "UnitFrames", HudStyle = { style = "medallions" } }),
		setup = function(e)
			Common.ForceScreen(e, true)
			CT.CVars(e)
			e._cvars.nameplateShowSelf = "1"
			e._units.player = { name = "Tahoma", class = "DRUID", race = "Tauren", sex = 2, isPlayer = true, level = 5, health = 132, healthMax = 163, power = 197, powerMax = 251, powerType = 0, powerToken = "MANA", reaction = 5 }
			e.RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 } }
		end,
	}))
	Load(N.Files(), env)
	U.W.CoreEnv.Login(env)
	env.RunTimers()
	assert(K.Setup.Apply({ layout = "DPS", modules = { UnitFrames = true } }))
	env.RunTimers()
	assert(not ns.Resource.state.content:IsShown(), "the caster druid has no class-resource bars")
	local display = env.CreateFrame("Frame", nil, K.Scale.Root())
	display:SetSize(140, 22)
	display:SetPoint("CENTER", K.Scale.Root(), "CENTER", 0, -100)
	for i, data in ipairs({ { 132, 163, 0, 1, 0 }, { 197, 251, 0.1, 0.25, 1 } }) do
		local bar = env.CreateFrame("StatusBar", nil, display)
		bar:SetSize(140, 8)
		bar:SetPoint("TOPLEFT", display, "TOPLEFT", 0, -(i - 1) * 11)
		bar:SetStatusBarTexture(K.Tokens.Texture("barFlat"))
		bar:SetMinMaxValues(0, data[2])
		bar:SetValue(data[1])
		bar:SetStatusBarColor(data[3], data[4], data[5])
	end
	local icon = display:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("TOP", display, "BOTTOM", 0, -3)
	icon:SetTexture(136104)
	display:SetShown(env._cvars.nameplateShowSelf == "1")
	local scene = Gallery.Build(env)
	assert(not Common.Errors(env, K), Common.Errors(env, K))
	return scene
end)
