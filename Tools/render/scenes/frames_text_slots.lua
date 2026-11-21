-- frames_text_slots.lua: real default frames for base pixel comparisons, with optional extra text, unit-frame parity round 1, 2, 3a, 3b, 3c, 3d, 4a, 4b or 5 options through Options (RENDER_TOTEMS and RENDER_PORTRAIT set the totem and portrait sides, RENDER_POWER_DETACH the power bar's place), or (RENDER_AURA_BOTH=1) the target's Debuffs and buffs with timers under the icons, nudged by RENDER_AURA_TIMER_Y, with every row full and the target of target shown under RENDER_AURA_FULL=1.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
return Common.Run(function()
	local module = os.getenv("RENDER_PARITY_MODULE") or "UnitFrames"
	local names = { UnitFrames = "unitframes", GroupFrames = "groupframes", Nameplates = "nameplates" }
	local scene, ns = Hud.Module(assert(names[module]), { layout = "DPS", party = {
		{ "Thaldren", "WARRIOR", 75, "TANK" }, { "Sylaen", "PRIEST", 80, "HEALER" },
		{ "Brakka", "SHAMAN", 50, "DAMAGER" }, { "Lunara", "MAGE", 90, "DAMAGER" },
	} })
	local env = assert(Hud.envs[scene])
	local K = env.KstyleUI
	if os.getenv("RENDER_PARITY_R3C") == "1" and module == "UnitFrames" then
		local target, me = env._units.target, env._units.player
		target.absorb, target.overshield, me.absorb = math.floor(target.healthMax * 0.3), true, math.floor(me.healthMax * 0.1)
		me.class, me.powerType, me.powerToken, me.power, me.powerMax = "DRUID", 3, "ENERGY", 60, 100
		me.powers, me.powerMaxes, env._comboPoints = { [0] = 3800, [3] = 60 }, { [0] = 5000, [3] = 100 }, 3
		env.GetUnitTotalModifiedMaxHealthPercent = function(unit) return unit == "player" and 0.15 or 0 end
		env.C_Spell.GetSpellPowerCost = function() return { { type = 0, cost = 1250 } } end
		K.Options.Get(module)
		for _, pair in ipairs({
			{ "player.powerAbove", true }, { "player.powerTextAlign", "CENTER" }, { "player.powerTextColor", "power" },
			{ "player.maxHealthLoss", true }, { "player.powerCost", true }, { "player.absorbBar", "BOTTOM" }, { "player.fonts.level.y", 4 },
			{ "target.healthHeight", 28 }, { "target.absorbPlacement", "END" }, { "target.absorbGlow", true }, { "target.absorbBar", "TOP" },
			{ "target.fonts.name.x", 6 }, { "player.extra1.textFormat", "[c:ffb347][level][/c] [name]" }, { "player.extra1.position", "BOTTOMLEFT" },
			{ "player.extra1.y", -16 }, { "player.extra1.width", 60 }, { "pet.healthHeight", 9 },
			{ "player.powerMana", true }, { "player.manaSpark", true }, { "resource.manaText", "percent" },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		env.FireEvent("UNIT_DISPLAYPOWER", "player")
		env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-0", 116)
		env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
	end
	if os.getenv("RENDER_EXTRA_TEXT") == "1" then
		local prefixes = { UnitFrames = "player.", GroupFrames = "party.", Nameplates = "" }
		local prefix = prefixes[module]
		K.Options.Get(module)
		K.Options.Write(module, prefix .. "extra1.textFormat", "[pp:abr] / [pp:max]")
		K.Options.Write(module, prefix .. "extra1.position", "BOTTOM")
		K.Options.Write(module, prefix .. "extra1.y", -8)
		K.Options.Write(module, prefix .. "extra2.textFormat", "[hp:pct]")
		K.Options.Write(module, prefix .. "extra2.position", "CENTER")
		if module == "GroupFrames" then
			K.Options.Write(module, "party.healthText", "NONE")
			K.Options.Write(module, prefix .. "extra2.position", "TOPRIGHT")
		elseif module == "Nameplates" then
			K.Options.Write(module, "extra1.textFormat", "[hp:abr] / [hp:max]")
			K.Options.Write(module, "extra1.position", "TOP")
			K.Options.Write(module, "extra1.y", 32)
		end
	end
	if os.getenv("RENDER_PARITY_R1") == "1" and module == "UnitFrames" then
		local target = env._units.target
		target.classification, target.pvp, target.faction = "elite", true, "Horde"
		dofile("Tools/regression/unitframes_env.lua").SetUnit(env, "focus", target)
		env.FireEvent("PLAYER_FOCUS_CHANGED")
		env.C_PetInfo = { GetPetHappiness = function() return 3 end }
		env.HasPetUI = function() return true, true end
		K.Options.Get(module)
		for _, pair in ipairs({
			{ "healthDecimal", true }, { "castbarRaise", true },
			{ "target.healthAlpha", 0.75 }, { "target.healthGradient", "HORIZONTAL" }, { "target.elite", true },
			{ "target.portraitMirror", true }, { "target.portraitZoom", 0.15 }, { "target.castbarIcon", true },
			{ "target.castbarIconRight", true }, { "target.castbarAlpha", 0.75 }, { "target.auraZoom", 0.2 },
			{ "player.healthColor", "health" }, { "player.portraitMirror", true }, { "player.incomingAlpha", 0.8 },
			{ "focus.targetBorder", true }, { "focus.elite", true }, { "pet.happiness", true }, { "pet.hoverBorder", true },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		local pet = ns.Frames.Get("pet").views[1]
		if pet.button:IsShown() then dofile("Tools/regression/widget_env.lua").Enter(pet.button) end
	end
	if os.getenv("RENDER_PARITY_R2") == "1" and module == "UnitFrames" then
		local U = dofile("Tools/regression/unitframes_env.lua")
		if not env._units.pet then
			U.SetUnit(env, "pet", { name = "Wolf", level = 38, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 })
		end
		env._units.pet.auras = { { id = 1, icon = 136207, left = 9, harmful = true, mine = false, count = 2, dispel = "Magic" }, { id = 2, icon = 135813, left = 14, harmful = false, mine = true } }
		env._units.target.auras = { { id = 3, icon = 135813, left = 6, harmful = true, mine = true, count = 3, dispel = "Magic" }, { id = 4, icon = 136207, left = 12, harmful = true, mine = true },
			{ id = 5, icon = 136096, left = 30, harmful = false, dispel = "Magic", stealable = true }, { id = 6, icon = 135846, left = 40, harmful = false, dispel = "Magic" } }
		for i, name in ipairs({ "Magmatus", "Ignaxis" }) do
			U.SetUnit(env, "boss" .. i, { name = name, level = -1, classification = "worldboss", health = 72000 - i * 9000, healthMax = 100000, power = 0, powerMax = 100, reaction = 2 })
		end
		env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
		env.C_Spell.IsSpellImportant = function() return true end
		env.UnitShouldDisplaySpellTargetName = function() return true end
		env.UnitSpellTargetName = function() return env._units.player.name end
		K.Options.Get(module)
		for _, pair in ipairs({
			{ "pet.auras", true }, { "pet.auraFilter", "both" }, { "target.auraCountSize", 12 }, { "target.auraCountPoint", "TOPLEFT" },
			{ "target.auraFilter", "buffs" }, { "target.auraBuffDispel", true }, { "target.auraStealable", true }, { "target.auraTimerY", 1 }, { "player.powerAlpha", 0.6 }, { "player.powerGradient", "HORIZONTAL" },
			{ "target.castbarTarget", true }, { "target.castbarImportant", true }, { "player.castbarIconX", 2 }, { "boss.gap", 12 },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
	end
	if os.getenv("RENDER_PARITY_R3A") == "1" and module == "UnitFrames" then
		local U = dofile("Tools/regression/unitframes_env.lua")
		env._units.target.marker = 8
		U.SetUnit(env, "focus", env._units.target)
		U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 72000, healthMax = 100000, reaction = 2, canAttack = true })
		env.C_PetInfo = { GetPetHappiness = function() return 3 end }
		env.HasPetUI = function() return true, true end
		for _, event in ipairs({ "PLAYER_FOCUS_CHANGED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "RAID_TARGET_UPDATE" }) do env.FireEvent(event) end
		for _, pair in ipairs({
			{ "target.markerSize", 28 }, { "pet.happiness", true }, { "pet.happinessPosition", "LEFT" }, { "pet.castbar", true },
			{ "pet.castbarHideIdle", false }, { "focus.auraCopy", "target" }, { "target.auraBuffZoom", 0.25 },
			{ "boss.auraSimple", "LEFT" }, { "boss.castbarHideIdle", false }, { "focus.auraFilter", "both" },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		local function auras(harmful, helpful)
			local list = {}
			for i, icon in ipairs({ 135813, 136026, 136207, 136197 }) do
				if i <= harmful or i > 4 - helpful then list[#list + 1] = { id = i, icon = icon, left = i * 7, harmful = i <= harmful, mine = true } end
			end
			return list
		end
		env._units.boss1.auras, env._units.target.auras = auras(3, 0), auras(2, 2)
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
	end
	if os.getenv("RENDER_PARITY_R3D") == "1" and module == "UnitFrames" then
		env.GetNetStats = function() return 0, 0, 20, 42 end
		env.C_Spell.GetSpellSubtext = function() return "Rank 3" end
		env.C_TradeSkillUI = { GetRemainingRecasts = function() return 4 end }
		local info = env.UnitCastingInfo
		env.UnitCastingInfo = function(token)
			local r = { info(token) }
			if token == "player" and r[1] then r[6] = true end
			return unpack(r, 1, 11)
		end
		dofile("Tools/regression/cooldowns_env.lua").StringUtil(env)
		env.C_StringUtil.CreateSecondsFormatter = function()
			return setmetatable({ Format = function(_, s) return s < 60 and string.format("%ds", s) or string.format("%dm %ds", s / 60, s % 60) end }, { __index = function() return function() end end })
		end
		env._units.target.auras = { { id = 1, icon = 135813, left = 272, harmful = true, mine = true }, { id = 2, icon = 136207, left = 168, harmful = true, mine = true },
			{ id = 3, icon = 135846, left = 95, harmful = true, mine = true }, { id = 4, icon = 136096, left = 45, harmful = false }, { id = 5, icon = 136075, left = 230, harmful = false },
			{ id = 6, icon = 135932, left = 299, harmful = false } }
		K.Options.Get(module)
		for _, pair in ipairs({ { "player.castbarFit", true }, { "player.castbarRank", true }, { "player.castbarLagText", true }, { "player.castbarCraft", true },
			{ "target.castbarFit", true }, { "target.auras", true }, { "target.auraTimer", true }, { "target.auraFilter", "both" }, { "target.auraColumns", 3 },
			{ "target.auraRows", 2 }, { "target.auraRowGap", 6 }, { "target.auraPrecise", 5 } }) do
			K.Options.Write(module, pair[1], pair[2])
		end
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
		for token, name in pairs({ player = "Silk Bandage", target = "Shadow Bolt Volley of the Endless Abyss" }) do
			local cast = env._units[token] and env._units[token].cast
			if cast then
				cast.name, cast.text = name, name
				env.FireEvent("UNIT_SPELLCAST_START", token, "Cast-1", cast.spellID)
			end
		end
	end
	if os.getenv("RENDER_PARITY_R3B") == "1" and module == "UnitFrames" then
		local target, player = env._units.target, env._units.player
		target.classification, target.class, target.combat, target.detail = "elite", "MAGE", true, { false, 2, 86, 86, 900 }
		player.leader, player.role, player.pvp, player.faction = true, "TANK", true, "Alliance"
		env.UnitDetailedThreatSituation = function(_, mob) local u = env._units[mob]; if u and u.detail then return unpack(u.detail) end end
		env.IsPVPTimerRunning, env.GetPVPTimer = function() return true end, function() return 272000 end
		dofile("Tools/regression/unitframes_env.lua").SetUnit(env, "focus", target)
		dofile("Tools/regression/unitframes_env.lua").SetUnit(env, "focustarget", nil)
		env.FireEvent("PLAYER_FOCUS_CHANGED")
		K.Options.Get(module)
		for _, pair in ipairs({
			{ "reactionColors", true }, { "hostileColor", { r = 0.75, g = 0.2, b = 0.55 } }, { "target.healthColor", "reaction" },
			{ "target.threatPercent", true }, { "target.combat", true }, { "target.combatClassColor", true }, { "target.elite", true }, { "target.eliteSize", 16 },
			{ "focus.threatPercent", true }, { "focus.threatPercentColor", false }, { "focus.elite", true }, { "focus.eliteX", 6 },
			{ "player.leaderSize", 24 }, { "player.pvpSize", 16 }, { "player.pvpTimer", true }, { "player.pvpTimerSize", 12 },
			{ "player.powerText", "percent" }, { "player.powerPercentSign", false }, { "player.portraitStyle", "class" }, { "player.classZoom", 0.2 },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		env.FireEvent("PVP_TIMER_UPDATE", "player")
	end
	if os.getenv("RENDER_AURA_BOTH") == "1" and module == "UnitFrames" then
		K.Options.Write(module, "target.auraFilter", "both")
		K.Options.Write(module, "target.auraTimerY", tonumber(os.getenv("RENDER_AURA_TIMER_Y")) or 0)
		env._units.target.auras = { { id = 1, icon = 135813, left = 9, harmful = true, mine = true }, { id = 2, icon = 136026, left = 3, harmful = true, mine = true },
			{ id = 3, icon = 136207, left = 30, harmful = false }, { id = 4, icon = 136118, left = 12, harmful = false } }
		if os.getenv("RENDER_AURA_FULL") == "1" then
			for i = 5, 32 do env._units.target.auras[i] = { id = i, icon = i % 2 == 0 and 135813 or 136207, left = 30 + i, harmful = i % 2 == 0, mine = i % 2 == 0 } end
			dofile("Tools/regression/unitframes_env.lua").SetUnit(env, "targettarget", env._units.player)
			env.FireEvent("UNIT_TARGET", "target")
		end
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
	end
	if os.getenv("RENDER_PARITY_R4B") == "1" and module == "UnitFrames" then
		local totems = { [1] = 136026, [2] = 135813, [4] = 136207 }
		env.GetNumTotemSlots = function() return 4 end
		env.GetTotemInfo = function(slot)
			if not totems[slot] then return false, "", 0, 0, 0, 1, 0 end
			return true, "Totem", env._time - slot * 5, 60, totems[slot], 1, slot
		end
		env.C_Spell.IsSpellInRange = function() return false end
		env._units.player.auras = { { id = 9, icon = 136207, left = 12, harmful = true, mine = false, dispel = "Curse" } }
		env.C_DurationUtil = { CreateDuration = function() return { SetTimeSpan = function(d, start, finish) d.start, d.finish = start, finish end } end }
		env.Enum.StatusBarTimerDirection = env.Enum.StatusBarTimerDirection or { ElapsedTime = 0, RemainingTime = 1 }
		env._units.target.cast = nil
		env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-1", 0, 1)
		K.Options.Get(module)
		for _, pair in ipairs({ { "player.dispelOverlay", "health" }, { "player.dispelEdge", true }, { "player.dispelIcon", "TOPRIGHT" }, { "player.dispelIconSize", 16 },
			{ "player.totems", true }, { "player.totemPosition", os.getenv("RENDER_TOTEMS") or "RIGHT" }, { "player.castbarRangeGrey", true }, { "player.castbarIconSize", 14 }, { "target.castbarHideIdle", false } }) do
			K.Options.Write(module, pair[1], pair[2])
		end
		if os.getenv("RENDER_PORTRAIT") then
			K.Options.Write(module, "player.portrait", true)
			K.Options.Write(module, "player.portraitSide", os.getenv("RENDER_PORTRAIT"))
		end
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
		env.FireEvent("PLAYER_TOTEM_UPDATE", 1)
		local cast = env._units.player.cast
		if cast then env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", cast.spellID) end
	end
	if os.getenv("RENDER_PARITY_R4A") == "1" and module == "UnitFrames" then
		local U, target = dofile("Tools/regression/unitframes_env.lua"), env._units.target
		target.class = "MAGE"
		target.auras = { { id = 1, icon = 135813, left = 9, harmful = true, mine = true }, { id = 2, icon = 136026, left = 3, harmful = true, mine = true } }
		env.UnitCanAssist = function(_, token) return env._units[token] ~= nil and (env._units[token].reaction or 0) >= 5 end
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
		U.SetUnit(env, "focus", target)
		local now = env.GetTime() * 1000
		U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 41200, healthMax = 100000, reaction = 2, canAttack = true,
			cast = { name = "Fireball", text = "Fireball", texture = 135808, start = now - 900, finish = now + 1100, spellID = 1 } })
		for _, event in ipairs({ "PLAYER_FOCUS_CHANGED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }) do env.FireEvent(event) end
		K.Options.Get(module)
		for _, pair in ipairs({
			{ "healthDecimal", true }, { "healthDecimalTrim", true }, { "boss.style", "plate" }, { "boss.castbarHeight", 16 }, { "boss.castbarWidth", 150 },
			{ "player.textBar", true }, { "player.textBarIcon", "LEFT" }, { "player.textBarLeft.textFormat", "[name]" }, { "player.textBarRight.textFormat", "[hp:pct]" },
			{ "target.textBar", true }, { "target.textBarPlace", "TOP" }, { "target.textBarCenter.textFormat", "[level] [c:ff8800]>[/c] [target]" },
			{ "focus.textBar", true }, { "focus.textBarPlace", "BELOW" }, { "focus.textBarWidth", 170 }, { "focus.textBarIcon", "RIGHT" },
			{ "focus.textBarLeft.textFormat", "[name]" }, { "focus.textBarRight.textFormat", "[pp:abr]" }, { "target.auraTracked", "1" }, { "target.auraTrackedDebuffs", true },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		env.FireEvent("UNIT_AURA", "target")
		env.FireEvent("UNIT_SPELLCAST_START", "boss1", "Cast-1", 1)
	end
	if os.getenv("RENDER_PARITY_R5") == "1" and module == "UnitFrames" then
		env.UnitShouldDisplaySpellTargetName = function(token) return token == "target" end
		env.UnitSpellTargetName = function() return "Valerin" end
		env.C_Spell.GetSpellCooldown = function() return { isOnGCD = true } end
		env.C_Spell.GetSpellCooldownDuration = function() return { start = env._time - 0.9, finish = env._time + 0.6, GetRemainingDuration = function() return 0.6 end } end
		dofile("Tools/regression/unitframes_env.lua").SetUnit(env, "focus", { name = "Elunara", level = 60, health = 2530, healthMax = 4010, reaction = 2, auras = {
			{ id = 1, icon = 135813, left = 9, harmful = true, mine = true }, { id = 2, icon = 136026, left = 14, harmful = true, mine = true },
			{ id = 3, icon = 136207, left = 30, harmful = false }, { id = 4, icon = 136118, left = 12, harmful = false } } })
		env.FireEvent("PLAYER_FOCUS_CHANGED")
		K.Options.Get(module)
		for _, pair in ipairs({ { "target.castbarTarget", true }, { "target.castbarTargetPlace", "RIGHT" }, { "player.castbarGcd", true },
			{ "player.powerDetach", os.getenv("RENDER_POWER_DETACH") or "BELOW" }, { "player.powerDetachWidth", 300 }, { "focus.auraFilter", "both" }, { "focus.auraBuffPlace", "BELOW" } }) do
			K.Options.Write(module, pair[1], pair[2])
		end
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
		env._units.player.cast = nil
		ns.CastBars.Refresh("player")
		env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", env._units.target.cast.spellID)
	end
	env.RunTimers()
	if os.getenv("RENDER_PARITY_R5") == "1" and module == "UnitFrames" then
		env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 116)
		env.FireEvent("SPELL_UPDATE_COOLDOWN")
	end
	Gallery.Ticks(dofile("Tools/regression/widget_env.lua"), env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	if os.getenv("RENDER_PARITY_R3A") == "1" and module == "UnitFrames" then
		local W, zoomed = dofile("Tools/regression/widget_env.lua"), false
		for _, entry in ipairs(ns.Frames.Get("focus").views[1].auras.buttons) do
			zoomed = zoomed or entry.buff and entry.button:IsVisible() and W.LastCall(entry.icon, "SetTexCoord")[1] == 0.25
		end
		assert(zoomed, "the focus shows a buff at the target's buff zoom")
	end
	return Gallery.Build(env)
end)
