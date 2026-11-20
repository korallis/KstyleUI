-- shell_parity.lua: one shell module's real Options page or affected frames, with parity switches applied through Options.Write; batch 4 shows a unit tooltip, its buffs on the RENDER_BUFF_SIDE side if set.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local module = os.getenv("RENDER_SHELL_MODULE") or "Minimap"
local loaders = { Minimap = "minimap", DataBars = "databars", Chat = "chat", Bags = "bags", Tooltips = "tooltips", QoL = "qol" }
local keys = { Minimap = "zone.subzone", DataBars = "strip.modules", Bags = "desaturateJunk", Tooltips = "maxStack", QoL = "autoGossip" }
local batch = os.getenv("RENDER_SHELL_FOLLOWUP")
local followup = batch == "1" or batch == "3" or batch == "4"
local unitTip = module == "Tooltips" and batch == "4"
local followups = batch == "4" and {
	Tooltips = { { "buffs.shown", true }, { "itemLevel", true }, { "levelColor", true }, { "classLine", true }, { "compactLevel", true }, { "factionColor", true } },
} or batch == "3" and {
	DataBars = { { "strip.money", "short" } },
	Bags = { { "characterBags", true } },
	Tooltips = { { "show", "outOfCombat" }, { "awayTag", true }, { "mountLine", true } },
	QoL = { { "autoDelete", true }, { "autoResurrect", true } },
} or {
	Minimap = { { "coords.hover", true } },
	DataBars = { { "strip.itemLevelSource", "overall" }, { "strip.itemLevelDecimals", 2 } },
	Chat = { { "inputOnTop", true }, { "editBox", "always" } },
	Bags = { { "slotCount", "usedTotal" }, { "iconZoom", 12 } },
	Tooltips = { { "playerTitles", false } },
	QoL = { { "coinIcons", true }, { "skipCinematics", true }, { "skipDelay", 5 } },
}
if unitTip and os.getenv("RENDER_BUFF_SIDE") then table.insert(followups.Tooltips, { "buffs.position", os.getenv("RENDER_BUFF_SIDE") }) end
-- RENDER_MINIMAP_R1 (a or b) switches on the minimap's first EllesmereUI parity round: a moves and adds caption readouts, b restyles the column and drawer.
local r1 = os.getenv("RENDER_MINIMAP_R1")
local rounds = {
	a = { { "column.hover", false }, { "difficulty.shown", true }, { "perf.shown", true }, { "clock.mode", "local12" }, { "clock.accent", true },
		{ "mail.position", "TOPLEFT" }, { "coords.position", "BOTTOMRIGHT" }, { "perf.hover", "lockouts" } },
	b = { { "column.hover", false }, { "column.backgrounds", false }, { "column.offset", 4 }, { "drawer.list", true }, { "drawer.behaviour", "open" },
		{ "rotate", true }, { "zone.position", "BOTTOM" }, { "column.tooltip", "up" } },
}
local driver = assert(loaders[module], "RENDER_SHELL_MODULE must name a shell module")
local D = dofile("Tools/regression/" .. driver .. "_env.lua")

return Common.Run(function()
	local opts = Common.ScreenOpts({
		saved = Gallery.Saved({ [module] = {} }),
		setup = function(env)
			Gallery.Setup(env)
			env.GetZoneText = function() return "Elwynn Forest" end
			env.CHAT_FLAG_AFK = "<AFK>"
			env.GetAverageItemLevel = function() return 62.8, 58.3 end
			if env.C_Item then env.C_Item.GetItemMaxStackSizeByID = function() return 20 end end
			if r1 then
				env.GetInstanceInfo = function() return "Karazhan", "raid", 6, "25 Heroic", 25 end
				env.GetDifficultyInfo = function(id) return "Heroic", "raid", id == 6, false, id == 6, false end
				env.GetFramerate = function() return 60 end
				env.GetNetStats = function() return 0, 0, 42, 48 end
				env._mail.new = true
				env._position = { 0.4532, 0.6218 }
				env.C_CVar = { GetCVarInfo = function(name) if name == "rotateMinimap" then return "0", "0", false, false, false, false, false end end,
					GetCVar = function() return env._cvars.rotateMinimap and "1" or "0" end,
					SetCVar = function(_, value) env._cvars.rotateMinimap = value == "1"; return true end }
				local Hud, Scene = dofile("Tools/render/scenes/hud.lua"), dofile("Tools/render/scene.lua")
				env._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
				local lib = D.FakeLibDBIcon(env)
				lib:Add("BugSack").icon:SetTexture(Hud.ICONS.sunderArmor)
				lib:Add("Details").icon:SetTexture(Hud.ICONS.whirlwind)
			end
			if unitTip then
				local buffs = { 136076, 132212, 132328, 135987, 135906 }
				local hunter = dofile("Tools/render/scenes/_classes.lua").HUNTER.colour
				env.RAID_CLASS_COLORS.HUNTER = { r = hunter[1], g = hunter[2], b = hunter[3] }
				env.UnitTokenFromGUID = function() return "mouseover" end
				env.UnitIsPlayer = function(unit) return unit == "mouseover" end
				env.UnitIsUnit = function(a, b) return a == b or (a == "mouseover" and b == "player") end
				env.UnitClass = function() return "Hunter", "HUNTER", 3 end
				env.UnitLevel = function() return 60 end
				env.UnitReaction = function() return 5 end
				env.UnitFactionGroup = function() return "Horde", "Horde" end
				env.GetFactionColor = function() return { GetRGB = function() return 0.9, 0.05, 0.07 end } end
				env.GetCreatureDifficultyColor = function() return { r = 1, g = 0.82, b = 0 } end
				env.TOOLTIP_UNIT_LEVEL, env.PLAYER = "Level %s", "Player"
				env.C_Secrets = { ShouldAurasBeSecret = function() return false end }
				env.C_UnitAuras = { GetAuraDataByIndex = function(_, i) return buffs[i] and { icon = buffs[i] } or nil end }
			end
			env.C_AddOns = env.C_AddOns or {}
			env.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not env._addons.KstyleUI_Options then Load(O.Files(), env) end
				return true
			end
		end,
	})
	if module == "Bags" then
		opts.bags = { [0] = { size = 20, items = { D.Item("potion"), D.Item("sword"), D.Item("junk"), D.Item("helm"), D.Item("cloth") } } }
	end
	local env, K, ns = D.New(opts)
	if not K.Modules.IsRunning(module) then assert(K.Modules.Enable(module)) end
	env.RunTimers()
	local defaults = os.getenv("RENDER_SHELL_DEFAULTS") == "1"
	if not defaults then
		if keys[module] and module ~= "DataBars" then assert(K.Options.Write(module, keys[module], module ~= "Minimap") ~= false) end
		if module == "DataBars" then
			local s = K.Store.Module(module).strip
			for _, key in ipairs({ "modules", "dockModules", "railModules" }) do
				for _, entry in ipairs(s[key]) do
					if followup then entry.shown = entry.id == (batch == "3" and "gold" or "itemLevel")
					elseif entry.id == "location" or entry.id == "itemLevel" then entry.shown = true end
				end
				assert(K.Options.Write(module, "strip." .. key, s[key]) ~= false)
			end
		elseif module == "QoL" then
			assert(K.Options.Write(module, "skipCinematics", true) ~= false)
		end
	end
	if followup and not defaults then
		for _, entry in ipairs(followups[module]) do assert(K.Options.Write(module, entry[1], entry[2]) ~= false) end
	end
	for _, entry in ipairs(r1 and not defaults and rounds[r1] or {}) do assert(K.Options.Write(module, entry[1], entry[2]) ~= false) end
	if module == "Chat" then Common.ChatSettings(env, K) end
	if module == "QoL" and os.getenv("RENDER_SHELL_OPTIONS") == "0" then
		env.FireEvent("CHAT_MSG_MONEY", "You loot 1 Gold, 4 Silver, 14 Copper")
	end
	if module == "Bags" then env.ToggleAllBags() end
	if unitTip then
		local tip = env.GameTooltip
		tip:SetOwner(env.UIParent, "ANCHOR_NONE")
		for _, text in ipairs({ "Valerin", "<Kstyle>", "Level 60 Hunter (Player)", "Horde" }) do tip:AddLine(text, 1, 1, 1) end
		D.BlizzardShow(tip, true)
		D.PostCall(env, tip, { type = env.Enum.TooltipDataType.Unit, guid = "Player-1-0001" })
		D.BlizzardShow(tip.StatusBar, true)
		tip.StatusBar:SetValue(0.72)
		dofile("Tools/render/scenes/tooltip.lua").Layout(env, tip)
		tip:ClearAllPoints()
		tip:SetPoint("TOPRIGHT", K.Scale.Root(), "TOPRIGHT", -80, -180)
	elseif module == "Tooltips" then
		local tip = env.GameTooltip
		env._items[2447] = { quality = 1, icon = 133939 }
		tip:SetOwner(env.UIParent, "ANCHOR_NONE")
		tip:AddLine("Peacebloom")
		tip:AddLine("Crafting Reagent")
		D.BlizzardShow(tip, true)
		D.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 2447 })
		dofile("Tools/render/scenes/tooltip.lua").Layout(env, tip)
		tip:ClearAllPoints()
		tip:SetPoint("TOPRIGHT", K.Scale.Root(), "TOPRIGHT", -80, -180)
	end
	env.RunTimers()
	O.W.Settle(env)
	if os.getenv("RENDER_SHELL_OPTIONS") ~= "0" then
		assert(K.Options.Open(module))
		if module == "DataBars" then
			if not defaults then K.Options.Write(module, "strip.labels", "short") end
			ns.Strip.view.frame:Hide()
		end
		env.RunTimers()
		assert(K.Layout.Set("Options.Window", "height", 900))
		if module == "DataBars" then assert(K.Layout.Set("Options.Window", "width", 1120)) end
		assert(K.Layout.Set("Options.Window", "anchor", "TOPLEFT"))
		assert(K.Layout.Set("Options.Window", "x", 28))
		assert(K.Layout.Set("Options.Window", "y", -28))
		local options = env._addons.KstyleUI_Options
		options.Window.Jump({ page = module, module = module,
			key = os.getenv("RENDER_SHELL_KEY") or (followup and followups[module][1][1]) or (module ~= "DataBars" and keys[module] or nil),
			labelTarget = not followup and module == "DataBars" and K.L["Location"] or nil })
		env.RunTimers()
		O.W.Settle(env)
	end
	if r1 and os.getenv("RENDER_SHELL_OPTIONS") == "0" then
		local _, note = dofile("Tools/render/scenes/hud.lua").Terrain(env)
		env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
		env.RunTimers()
		O.W.Settle(env)
		env._r1Note = note
	end
	local scene = Gallery.Build(env)
	local errors = Common.Errors(env, K)
	assert(not errors, errors)
	scene.log[#scene.log + 1] = "shell parity: " .. module .. (defaults and " defaults" or " options applied") .. (r1 and " (round 1 " .. r1 .. ")" or "")
	if env._r1Note then scene.log[#scene.log + 1] = env._r1Note end
	return scene
end)
