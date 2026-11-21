-- qol_parity.lua: the full HUD with every QoL parity round 1 option on, most away from its default (a larger alert size, class colours, a lower crosshair with set lengths and thicknesses, a larger class-coloured ring, a higher durability warning), after a combat round trip and then a party member's death, so the flash line shows the death alert over the talent line; RENDER_QOL_ROUND=2 adds round 2: the character stats (percent and rating, coloured, short labels), the bevelled ring with its centre dot and a trail mid-move, and the cast circle 40% into a cast; RENDER_QOL_ROUND=3 adds round 3a over round 2: a warrior's Charge and Intercept counting down as class-coloured bars, the target distance, the crosshair in its out-of-range colour and the potion ready flash; RENDER_QOL_ROUND=3b adds round 3b over round 2 instead: frame rate and latency (latency without labels) in the stats and the raid tools open in a party, in the RENDER_QOL_LAYOUT and RENDER_QOL_GROW given, and with RENDER_QOL_PASTE=1 the paste window and the guild chat cover over a stand-in chat area (the Communities window around it is not drawn); RENDER_QOL_ROUND=0 turns QoL on with every option at its default; with RENDER_QOL_OPTIONS=1 the QoL page and its live preview.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Q = dofile("Tools/regression/qol_env.lua")

local ON = {
	alertSize = 40, combatAlert = true, combatLeaveClass = true, talentAlert = true, talentClass = true, deathAlert = true, deathSound = "ready",
	durabilityAlert = true, durabilityPercent = 50, durabilityY = 290, durabilityThrown = false,
	crosshair = "normal", crosshairHLength = 60, crosshairVLength = 60, crosshairHWidth = 3, crosshairVWidth = 3, crosshairBorder = 1, crosshairY = -24,
	cursorRing = true, cursorScale = 125, cursorOpacity = 90, cursorClass = true,
	hideScreenshot = true, announceReset = true, autoLog = true, autoLogWhere = "all", skipCinematics = true, skipMode = "both",
}
local ROUND2 = {
	stats = true, statsValue = "both", statsColored = true, statsShort = true, cursorTexture = "ringBevel", cursorDot = true, cursorTrail = true, castRing = true,
}
local ROUND3 = {
	moveAlert = true, moveMode = "bar", moveClass = true, rangeText = true, crosshairRange = true, crosshairMelee = true, potionAlert = true,
}
local ROUND3B = { statsNetLabels = false, raidTools = "group", raidToolsLayout = os.getenv("RENDER_QOL_LAYOUT") or "row", raidToolsGrow = os.getenv("RENDER_QOL_GROW") or "downright" }
local round3 = os.getenv("RENDER_QOL_ROUND") == "3"
local round3b = os.getenv("RENDER_QOL_ROUND") == "3b"
local round2 = round3 or round3b or os.getenv("RENDER_QOL_ROUND") == "2"
local defaults, paste = os.getenv("RENDER_QOL_ROUND") == "0", round3b and os.getenv("RENDER_QOL_PASTE") == "1"

-- Round 3a: a warrior with Charge and Intercept cooling, a target 25 to 30 yards away (out of melee range) and a potion
-- whose cooldown has just ended. The engine draws a text binding's time and a timer bar's fill; the harness has no engine,
-- so the binding writes its format with a fixed time and the scene sets each bar to the time it shows.
local LEFT = { [11578] = { "Charge", 132337, 9, 15 }, [20617] = { "Intercept", 132307, 21, 30 } }
local function Round3(e)
	e.UnitClass = function() return "Warrior", "WARRIOR", 1 end
	local book = { { spellID = 11578, itemType = 1 }, { spellID = 20617, itemType = 1 }, { spellID = 2764, itemType = 1 } }
	e.Enum = e.Enum or {}
	e.Enum.SpellBookSpellBank = { Player = 0 }
	e.Enum.SpellBookItemType = { Spell = 1 }
	e.Enum.DurationTextBindingProperty = { RemainingDuration = 0 }
	e.Enum.SecondsFormatterAbbreviation = { OneLetter = 2 }
	e.Enum.SecondsFormatterInterval = { Seconds = 0 }
	e.Enum.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
	local formatter = setmetatable({}, { __index = function() return function() end end })
	e.C_StringUtil = e.C_StringUtil or {}
	e.C_StringUtil.CreateSecondsFormatter = e.C_StringUtil.CreateSecondsFormatter or function() return formatter end
	e.C_SpellBook = {
		IsSpellKnown = function(id) return LEFT[id] ~= nil end,
		GetNumSpellBookSkillLines = function() return 1 end,
		GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #book } end,
		GetSpellBookItemInfo = function(slot) return book[slot] end,
	}
	e.C_Spell = {
		GetSpellName = function(id) return LEFT[id] and LEFT[id][1] or ({ [100] = "Charge", [20252] = "Intercept" })[id] end,
		GetSpellTexture = function(id) return LEFT[id] and LEFT[id][2] end,
		GetSpellCooldown = function(id) return { isActive = LEFT[id] ~= nil, isOnGCD = false, duration = LEFT[id] and LEFT[id][4] or 0 } end,
		GetSpellCooldownDuration = function(id) return LEFT[id] and { id = id } end,
		GetSpellInfo = function(id) return { minRange = 0, maxRange = id == 2764 and 30 or 25 } end,
		IsSpellHarmful = function() return true end,
		IsSpellHelpful = function() return false end,
		IsSpellInRange = function(id) return id == 2764 end,
	}
	e.C_DurationUtil = { CreateDurationTextBinding = function()
		local b = {}
		function b:SetFontString(fs) self.fs = fs end
		function b:SetTextFormat(format) self.format = format end
		function b:SetDuration(d) self.fs:SetText((self.format:gsub("{}", LEFT[d.id][3] .. "s"))) end
		function b:SetEnabled() end
		return b
	end }
	e.UnitExists = function(unit) return unit == "target" end
	e.UnitCanAttack = function() return true end
	e.NUM_BAG_SLOTS = 0
	e.C_Container = {
		GetContainerNumSlots = function() return 1 end,
		GetContainerItemInfo = function() return { itemID = 858 } end,
		GetItemCooldown = function() return 100, 120, 1 end,
	}
	local instant = e.C_Item.GetItemInfoInstant
	e.C_Item.GetItemInfoInstant = function(id) if id == 858 then return id, "Consumable", "Potion", "", 134830, 0, 1 end return instant(id) end
end

local function Stats(e)
	e.UnitStat = function(_, i) return 120, 120 + 31 * i, 0, 0 end
	e.GetCritChance, e.GetSpellCritChance, e.GetMeleeHaste = function() return 18.42 end, function() return 14.07 end, function() return 6.25 end
	e.GetSpellBonusDamage, e.GetSpellBonusHealing, e.UnitArmor = function() return 412 end, function() return 455 end, function() return 2100, 2380 end
	e.GetCombatRating = function(i) return 40 + 13 * i end
	e.CR_CRIT_MELEE, e.CR_CRIT_SPELL, e.CR_HASTE_MELEE = 9, 11, 18
	e.UnitCastingInfo = function() return "Lightning Bolt", "Lightning Bolt", 136048, 99000, 101500 end
	e.GetFramerate, e.GetNetStats = function() return 143.6 end, function() return 1, 1, 38, 52 end
end

return Common.Run(function()
	local options = os.getenv("RENDER_QOL_OPTIONS") == "1"
	local env, K, ns = Q.New(Common.ScreenOpts({
		saved = Gallery.Saved({ QoL = {} }),
		setup = function(e)
			Gallery.Setup(e)
			if round2 then Stats(e) end
			if round3 then Round3(e) end
			if paste then
				e.CommunitiesFrame = e.CreateFrame("Frame", "CommunitiesFrame", e.UIParent)
				e.CommunitiesFrame:SetSize(380, 220)
				e.CommunitiesFrame:SetPoint("CENTER", e.UIParent, "CENTER", 560, 40)
				e.CommunitiesFrame.Chat = e.CreateFrame("Frame", nil, e.CommunitiesFrame)
				e.CommunitiesFrame.Chat:SetAllPoints()
				e.CommunitiesFrame.Chat.MessageFrame = e.CreateFrame("Frame", nil, e.CommunitiesFrame.Chat)
				e.CommunitiesFrame.Chat.MessageFrame:SetAllPoints()
				e.CommunitiesFrame.GetSelectedClubId = function() return 7 end
				e.C_Club = { GetClubInfo = function() return { clubType = 2 } end }
				e.Enum = e.Enum or {}
				e.Enum.ClubType = { Guild = 2 }
			end
			e.C_AddOns = e.C_AddOns or {}
			e.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons.KstyleUI_Options then Load(O.Files(), e) end
				return true
			end
		end,
	}))
	if not K.Modules.IsRunning("QoL") then assert(K.Modules.Enable("QoL")) end
	for key, value in pairs(defaults and {} or ON) do assert(K.Options.Write("QoL", key, value) ~= false, key) end
	for key, value in pairs(round2 and ROUND2 or {}) do assert(K.Options.Write("QoL", key, value) ~= false, key) end
	for key, value in pairs(round3 and ROUND3 or {}) do assert(K.Options.Write("QoL", key, value) ~= false, key) end
	for key, value in pairs(round3b and ROUND3B or {}) do assert(K.Options.Write("QoL", key, value) ~= false, key) end
	if round3b then
		local list = {}
		for _, entry in ipairs(K.Options.Read("QoL", "statsList")) do list[#list + 1] = { id = entry.id, shown = entry.shown or entry.id == "fps" or entry.id == "home" or entry.id == "world", zone = "left" } end
		assert(K.Options.Write("QoL", "statsList", list) ~= false)
	end
	if round2 then env.FireEvent("UNIT_SPELLCAST_START", "player") end
	env._unspent, env._durability[5] = true, { 21, 100 }
	env.FireEvent("TRAIT_CONFIG_UPDATED", 1)
	env.FireEvent("UPDATE_INVENTORY_DURABILITY")
	env.SetCombat(true)
	env.SetCombat(false)
	env._group, env._names.party1, env._dead.party1 = true, "Valerin", true
	env.FireEvent("UNIT_HEALTH", "party1")
	if round3 then
		env.FireEvent("PLAYER_TARGET_CHANGED")
		env.Release()
		local _, slots = ns.MoveFrame()
		for _, slot in ipairs(slots) do
			local id = slot.binding and slot.binding.fs and (slot.binding.format:find("Charge") and 11578 or 20617)
			if id then slot.bar:SetBarRange(0, LEFT[id][4]); slot.bar:SetBarValue(LEFT[id][3]) end
		end
	end
	if round3b then env.FireEvent("GROUP_ROSTER_UPDATE") end
	if paste then
		assert(K.Options.Write("QoL", "wayPaste", true) ~= false and K.Options.Write("QoL", "guildCover", true) ~= false)
		env.SlashCmdList.KSTYLEQOLPASTE("")
		ns.PasteWindow().area:SetText("/way 52.5 40 The inn\n/way #1430 20 20 Sentinel Hill")
	end
	local root = K.Scale.Root()
	env._cursor = { root:GetWidth() * (options and 0.85 or 0.35) * root:GetEffectiveScale(), root:GetHeight() * 0.68 * root:GetEffectiveScale() }
	local _, ring = ns.AidFrames()
	if round2 then
		local x, y = env._cursor[1], env._cursor[2]
		env._cursor = { x - 90, y - 50 }
		ring:GetScript("OnUpdate")(ring, 0)
		for i = 1, 3 do
			env._cursor = { x - 90 + 30 * i, y - 50 + 16 * i }
			ring:GetScript("OnUpdate")(ring, 0)
		end
	end
	if ring then
		ring:GetScript("OnUpdate")(ring, 0)
		ring:SetScript("OnUpdate", nil) -- the pointer stands still for the picture, and Settle waits for every OnUpdate to stop
	end
	env.RunTimers()
	O.W.Settle(env)
	if options then
		assert(K.Options.Open("QoL"))
		env.RunTimers()
		assert(K.Layout.Set("Options.Window", "height", 900))
		assert(K.Layout.Set("Options.Window", "width", 1240))
		assert(K.Layout.Set("Options.Window", "anchor", "TOPLEFT"))
		assert(K.Layout.Set("Options.Window", "x", 28))
		assert(K.Layout.Set("Options.Window", "y", -28))
		env._addons.KstyleUI_Options.Window.Jump({ page = "QoL", module = "QoL", key = os.getenv("RENDER_QOL_KEY") or "combatAlert" })
		env.RunTimers()
		if ns.StatsFrame() then ns.StatsFrame():Hide() end -- the window covers the top left, where the stats sit
		O.W.Settle(env)
	end
	local scene = Gallery.Build(env)
	local errors = Common.Errors(env, K)
	assert(not errors, errors)
	if not options then
		scene = Common.Scene.Merge({ Reference.Build({ layout = os.getenv("RENDER_LAYOUT") or "DPS" }), scene })
	end
	scene.log[#scene.log + 1] = "qol parity: round " .. (defaults and "none (defaults)" or round3 and "1, 2 and 3a" or round3b and "1, 2 and 3b" or round2 and "1 and 2" or "1") .. " options " .. (options and "page" or "on over the HUD")
	return scene
end)
