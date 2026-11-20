-- databars_parity.lua: the top data bar with the parity round's readouts and options switched on, through Options.Write, on fixture data.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local D = dofile("Tools/regression/databars_env.lua")
local Fixture = dofile("Tools/regression/databars_readouts_fixture.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

local SHOWN = { micro = "left", spec = "left", coords = "left", prof1 = "left", time = "centre", combat = "right", played = "right", audio = "right",
	broker = "right", spacer = "right", bags = "right", itemLevel = "right", fps = "right", latency = "right", gold = "right" }
local PREVIEW = { spec = "left", time = "centre", bags = "right", itemLevel = "right" }
local OPTIONS = {
	{ "strip.specUpper", true }, { "strip.specLoadout", true }, { "strip.clockMail", true }, { "strip.clockRest", true },
	{ "strip.coordsDecimals", 2 }, { "strip.professionText", "values" }, { "strip.bagsDisplay", "usedTotal" }, { "strip.bagsLow", 30 },
	{ "strip.itemLevelPrefix", "short" }, { "strip.brokerPlugin", "Bagnon" }, { "strip.audioChannel", "Music" }, { "strip.padding", 3 },
	{ "strip.labelCustom", true }, { "strip.labelColor", { r = 0.85, g = 0.72, b = 0.45, a = 1 } }, { "strip.playedTotal", true },
}

return Common.Run(function()
	local env, K = D.New(Common.ScreenOpts({
		saved = Gallery.Saved({ DataBars = {} }),
		setup = function(e)
			Gallery.Setup(e)
			Fixture(e)
			e.C_Map = { GetBestMapForUnit = function() return 1429 end, GetPlayerMapPosition = function() return { GetXY = function() return 0.4532, 0.6218 end } end }
			e.C_CVar = { GetCVar = function(name) return ({ Sound_EnableAllSound = "1", Sound_MusicVolume = "0.35" })[name] end }
			e.GetProfessions = function() return 1 end
			e.GetProfessionInfo = function() return "Mining", 136240, 225, 300 end
			e.HasNewMail, e.IsResting = function() return true end, function() return true end
			e.C_ClassTalents = { GetLastSelectedSavedConfigID = function() return 7 end }
			e.C_Traits = { GetConfigInfo = function() return { name = "Raid" } end }
			e.GetAverageItemLevel = function() return 62.8, 58.3 end
			e.C_Container = e.C_Container or {}
			e.C_Container.GetContainerNumFreeSlots = function(bag) return bag == 0 and 2 or 3 end
			e.C_Container.GetContainerNumSlots = function() return 16 end
			local ldb = { GetDataObjectByName = function() return { text = "42 items", label = "Bags" } end }
			e.LibStub = { GetLibrary = function() return ldb end }
			e.C_AddOns = e.C_AddOns or {}
			e.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons.KstyleUI_Options then Load(O.Files(), e) end
				return true
			end
		end,
	}))
	env.RunTimers()
	local key = os.getenv("RENDER_DATABARS_OPTIONS")
	local shown = key and PREVIEW or SHOWN
	if os.getenv("RENDER_DATABARS_DEFAULTS") ~= "1" then
		local list = K.Store.Module("DataBars").strip.modules
		for _, entry in ipairs(list) do
			entry.shown = shown[entry.id] ~= nil
			entry.zone = shown[entry.id] or entry.zone
		end
		assert(K.Options.Write("DataBars", "strip.modules", list) ~= false)
		for _, option in ipairs(OPTIONS) do assert(K.Options.Write("DataBars", option[1], option[2]) ~= false) end
		env.FireEvent("TIME_PLAYED_MSG", 1987200, 5400)
		env.RunTimers()
	end
	if key then
		assert(K.Options.Open("DataBars"))
		env.RunTimers()
		assert(K.Layout.Set("Options.Window", "height", 900))
		assert(K.Layout.Set("Options.Window", "width", 1120))
		assert(K.Layout.Set("Options.Window", "anchor", "TOPLEFT"))
		assert(K.Layout.Set("Options.Window", "x", 28))
		assert(K.Layout.Set("Options.Window", "y", -60))
		env._addons.KstyleUI_Options.Window.Jump({ page = "DataBars", module = "DataBars", key = key })
		env.RunTimers()
		O.W.Settle(env)
	end
	local scene = Gallery.Build(env)
	local errors = Common.Errors(env, K)
	assert(not errors, errors)
	scene.log[#scene.log + 1] = "databars parity: round 1 readouts and options applied"
	return scene
end)
