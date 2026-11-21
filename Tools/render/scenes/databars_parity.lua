-- databars_parity.lua: the top data bar with a parity round's readouts and options switched on, through Options.Write, on fixture data.
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
local ROUND2 = { micro = "left", spec = "left", hearth = "left", time = "centre", reagents = "right", currencies = "right", guild = "right", friends = "right",
	coords = "right", bags = "right", fps = "right", latency = "right", gold = "right" }
local ROUND2_DOCK = { time = "centre", coords = "left", combat = "left", played = "right", audio = "right", reagents = "right", prof1 = "right", prof2 = "right", broker = "right" }
local ROUND2_OPTIONS = {
	{ "strip.icons", "beside" }, { "strip.currencyIcons", true }, { "strip.reagentsLabel", true }, { "strip.hearthText", "smart" },
	{ "strip.brokerPlugin", "Bagnon" }, { "xp.questXP", true }, { "micro.align", "CENTER" },
}
local ROUND3 = { micro = "left", spec = "left", hearth = "left", time = "centre", durability = "right", bags = "right", fps = "right", latency = "right", gold = "right" }
local ROUND3_SECOND = { coords = "right", location = "right", itemLevel = "right", guild = "right", friends = "right" }
local ROUND3_OPTIONS = {
	{ "strip.blocks.latency.show", "both" }, { "strip.blocks.gold.show", "both" }, { "strip.blocks.durability.show", "icon" },
	{ "strip.blocks.latency.iconColor", "accent" }, { "strip.blocks.gold.iconColor", "custom" }, { "strip.blocks.gold.iconCustom", { r = 0.85, g = 0.72, b = 0.45, a = 1 } },
	{ "strip.hearthRight", "spell:556" }, { "strip.hearthRightText", "location" }, { "strip.second", true },
}

return Common.Run(function()
	local env, K = D.New(Common.ScreenOpts({
		saved = Gallery.Saved({ DataBars = {} }),
		setup = function(e)
			Gallery.Setup(e)
			Fixture(e)
			e.C_Map = { GetBestMapForUnit = function() return 1429 end, GetPlayerMapPosition = function() return { GetXY = function() return 0.4532, 0.6218 end } end }
			e.C_CVar = { GetCVar = function(name) return ({ Sound_EnableAllSound = "1", Sound_MusicVolume = "0.35" })[name] end }
			e.GetProfessions = function() return 1, 2 end
			e.GetProfessionInfo = function(i) return i == 2 and "Tailoring" or "Mining", 136240, 225, 300 end
			e.HasNewMail, e.IsResting = function() return true end, function() return true end
			e.C_ClassTalents = { GetLastSelectedSavedConfigID = function() return 7 end }
			e.C_Traits = { GetConfigInfo = function() return { name = "Raid" } end }
			e.GetAverageItemLevel = function() return 62.8, 58.3 end
			e.GetZoneText = function() return "Elwynn Forest" end
			e.C_Spell = { GetSpellInfo = function(id) return id == 556 and { name = "Astral Recall" } or nil end, GetSpellCooldown = function() return { startTime = 0, duration = 0 } end }
			e.C_Container = e.C_Container or {}
			e.C_Container.GetContainerNumFreeSlots = function(bag) return bag == 0 and 2 or 3 end
			e.C_Container.GetContainerNumSlots = function() return 16 end
			e.C_Container.GetContainerItemInfo = function(bag, slot) if bag == 0 and slot == 1 then return { itemID = 17020, stackCount = 20, itemName = "Arcane Powder", iconFileID = 133848 } end end
			e.C_Item.GetItemInfoInstant = function(id) return id, "", "", "", 0, 5, 0 end
			e.C_QuestLog = { GetNumQuestLogEntries = function() return 1, 1 end, GetInfo = function() return { questID = 7, isHeader = false } end, ReadyForTurnIn = function() return true end }
			e.GetQuestLogRewardXP = function() return 6000 end
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
	K.Safe.Side(K).travelData = K.Safe.Side(K).travelData or { Hearth = function() return "Stormwind", "ready" end, Read = function() return { {}, {}, {} } end }
	local key = os.getenv("RENDER_DATABARS_OPTIONS")
	local round = os.getenv("RENDER_DATABARS_ROUND")
	local round2, round3 = round == "2", round == "3"
	local dock = (round2 or round3) and K.Widgets.Medallions()
	local shown = key and not round3 and PREVIEW or dock and ROUND2_DOCK or round2 and ROUND2 or round3 and ROUND3 or SHOWN
	if os.getenv("RENDER_DATABARS_DEFAULTS") ~= "1" then
		local list = K.Store.Module("DataBars").strip[dock and "dockModules" or "modules"]
		for _, entry in ipairs(list) do
			entry.shown = shown[entry.id] ~= nil
			entry.zone = shown[entry.id] or entry.zone
		end
		assert(K.Options.Write("DataBars", dock and "strip.dockModules" or "strip.modules", list) ~= false)
		for _, option in ipairs(round2 and ROUND2_OPTIONS or round3 and ROUND3_OPTIONS or OPTIONS) do assert(K.Options.Write("DataBars", option[1], option[2]) ~= false) end
		if round3 then
			local second = K.Store.Module("DataBars").strip.secondModules
			for _, entry in ipairs(second) do entry.shown = ROUND3_SECOND[entry.id] ~= nil end
			assert(K.Options.Write("DataBars", "strip.secondModules", second) ~= false)
		end
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
	scene.log[#scene.log + 1] = "databars parity: round " .. (round or 1) .. " readouts and options applied"
	return scene
end)
