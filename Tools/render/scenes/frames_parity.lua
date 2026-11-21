-- frames_parity.lua: the real scoped module frames with optional parity controls, selected with RENDER_PARITY_MODULE.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
return Common.Run(function()
	local module = os.getenv("RENDER_PARITY_MODULE") or "UnitFrames"
	local names = { UnitFrames = "unitframes", GroupFrames = "groupframes", Nameplates = "nameplates" }
	local scene, ns = Hud.Module(assert(names[module]), { layout = "DPS", boss = {
		name = "Magmatus", level = 40, health = 72000, healthMax = 100000, reaction = 2, canAttack = true,
		cast = { name = "Whirlwind", texture = 132369, start = 8500, finish = 12000, spellID = 1680, notInterruptible = true },
	}, party = {
		{ "Thaldren", "WARRIOR", 75, "TANK" }, { "Sylaen", "PRIEST", 80, "HEALER" },
		{ "Brakka", "SHAMAN", 50, "DAMAGER" }, { "Lunara", "MAGE", 90, "DAMAGER" },
	} })
	local env = assert(Hud.envs[scene])
	local K = env.KstyleUI
	if module == "UnitFrames" then
		local U = dofile("Tools/regression/unitframes_env.lua")
		U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 2500, healthMax = 4000, reaction = 2, canAttack = true,
			cast = { name = "Frostbolt", texture = 135846, start = 8500, finish = 12000, spellID = 116 } })
		env.FireEvent("PLAYER_FOCUS_CHANGED")
		env.GetNetStats = function() return 0, 0, 30, 180 end
		K.Options.Write(module, "player.castbarLatency", true)
	elseif module == "GroupFrames" then
		env.UnitHasIncomingResurrection = function(unit) return unit == "party1" end
		env.C_IncomingSummon = { HasIncomingSummon = function(unit) return unit == "party2" end }
		env.UnitIsAFK = function(unit) return unit == "party3" end
		ns.Unit.ForEach(ns.Indicators.Status)
	else
		K.Options.Write(module, "target.dimOthers", 0.4)
		K.Options.Write(module, "cast.spark", true)
		K.Options.Write(module, "cast.hideUnitName", true)
		K.Options.Write(module, "cast.fullOpacity", true)
		K.Options.Write(module, "focus.fullOpacity", true)
		local N = dofile("Tools/regression/nameplates_env.lua")
		if os.getenv("RENDER_PARITY_ROUND") == "1" then
			-- Round 1 switched on: threat percent (at the right, beside the health text) and name colour, the health line and
			-- name marker on the target, the focus letter, a PvP badge, the spell target and a level difficulty colour.
			env.GetCreatureDifficultyColor = function(level) return level > 40 and { r = 1, g = 0.5, b = 0.25 } or { r = 1, g = 0.82, b = 0 } end
			local target, add = env._units.nameplate1, env._units.nameplate2
			target.threat, target.threatPct, target.raid = 1, 72, 8
			add.pvp, add.faction, add.spellTarget = true, "Horde", "Thaldren"
			for key, value in pairs({ ["threat.groupOnly"] = false, ["threat.name"] = true, ["threat.percent"] = true, ["threat.percentColor"] = true,
				["threat.percentPlace"] = "RIGHT", ["healthText.show"] = true,
				["target.hashLine"] = true, ["markers.nameRaid"] = true, ["focus.letter"] = "CENTER", ["markers.pvp"] = true,
				["markers.pvpPlayersOnly"] = false, ["cast.showTarget"] = true, ["cast.hideUnitName"] = false, ["level.colorMode"] = "difficulty" }) do
				K.Options.Write(module, key, value)
			end
			N.Cast(env, "nameplate2", { name = "Mirefin Hex", text = "Mirefin Hex", texture = 136071, notInterruptible = false })
			Hud.FillCast(ns.Plates.Get("nameplate2"), 0.4)
		elseif os.getenv("RENDER_PARITY_ROUND") == "2" then
			-- Round 2 switched on: the target's glow, bar highlight and size, a rogue's combo points and energy on the target, an
			-- important cast with its glow and a larger spell icon on the add, the target's protected important cast keeping its colour
			-- while the interrupt is ready, and threat as the bar colour and its edge.
			local unitClass = env.UnitClass
			env.UnitClass = function(unit)
				if unit == "player" then return "Rogue", "ROGUE", 4 end
				return unitClass(unit)
			end
			env._units.player = env._units.player or {}
			env._units.player.power, env._units.player.powerMax = 70, 100
			env.GetComboPoints = function() return 3 end
			env.C_Spell.IsSpellImportant = function(id) return id ~= nil end
			env._units.nameplate2.threat = 1
			for key, value in pairs({ ["target.glow"] = true, ["target.fill"] = true, ["target.scale"] = 1.15, ["resource.show"] = true,
				["resource.energy"] = true, ["cast.important"] = true, ["cast.importantGlow"] = true, ["cast.showIcon"] = true,
				["cast.iconScale"] = 1.4, ["threat.groupOnly"] = false, ["threat.display"] = "healthEdge", ["cast.hideUnitName"] = false,
				["cast.importantKick"] = true }) do
				K.Options.Write(module, key, value)
			end
			ns.Interrupt.spell, ns.Interrupt.ready = 1766, true
			N.Cast(env, "nameplate1", { name = "Snap", text = "Snap", texture = 132200, notInterruptible = true })
			Hud.FillCast(ns.Plates.Get("nameplate1"), 0.55)
			N.Cast(env, "nameplate2", { name = "Mirefin Hex", text = "Mirefin Hex", texture = 136071, notInterruptible = false })
			Hud.FillCast(ns.Plates.Get("nameplate2"), 0.4)
		elseif os.getenv("RENDER_PARITY_ROUND") == "3" then
			-- Round 3 switched on: absorbs, the execute glow and the bar highlight on the target, a larger
			-- diamond, a lighter cast track, the add as a taller-cast, highlighted focus fading out of range, and friendly plates:
			-- a titled player with a guild line under the mouse, an NPC in its own colour and size, and a pet with its owner.
			local k = 768 / 1080
			for token, unit in pairs({
				nameplate3 = { { name = "Thaldrin", pvpName = "Sergeant Thaldrin", guild = "Ashen Vanguard", isPlayer = true, class = "PALADIN", canAttack = false, reaction = 5, level = 40, health = 1800, maxHealth = 2000 }, 1180, 300 },
				nameplate4 = { { name = "Innkeeper Hale", canAttack = false, reaction = 5, level = 30, health = 900, maxHealth = 900 }, 330, 330 },
				nameplate5 = { { name = "Ember", pet = true, ownerGUID = "Player-1", canAttack = false, reaction = 5, level = 40, health = 700, maxHealth = 800 }, 560, 400 },
			}) do
				local base = N.Add(env, token, unit[1])
				base:ClearAllPoints()
				base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", unit[2] * k, (1080 - unit[3]) * k)
			end
			env._players["Player-1"] = "Thaldrin"
			N.Curves(env)
			local target, add = env._units.nameplate1, env._units.nameplate2
			target.health, target.absorb, add.outOfRange = 380, 260, true
			env.FireEvent("UNIT_HEALTH", "nameplate1")
			for key, value in pairs({ ["health.absorbs"] = true, ["health.execute"] = true, ["level.diamond"] = 1.2, ["cast.bgAlpha"] = 0.35,
				["target.fill"] = true, ["focus.fill"] = true, ["focus.fillColor"] = { r = 0.31, g = 0.76, b = 1 },
				["focus.castHeight"] = 1.5, ["range.fade"] = true, ["range.alpha"] = 0.6, ["target.hover"] = true, ["target.smoothOpacity"] = false,
				["friendly.title"] = true, ["friendly.guild"] = "brackets", ["friendly.nameMode"] = "class", ["friendly.npcNameMode"] = "custom",
				["friendly.npcColor"] = { r = 0.9, g = 0.8, b = 0.45 }, ["friendly.npcSize"] = 13, ["friendly.owner"] = true, ["friendly.petSize"] = 13,
				["cast.hideUnitName"] = false }) do
				K.Options.Write(module, key, value)
			end
			env.RunTickers()
			env._mouseUnit = "nameplate3"
			env.FireEvent("UPDATE_MOUSEOVER_UNIT")
		elseif os.getenv("RENDER_PARITY_ROUND") == "4" then
			-- Round 4 switched on: enemy buffs right of the bar with a dispel glow, crowd control on the left, a warrior's view of
			-- another warrior's Sunder Armor, the target's cast glowing because it targets you, the distance to the target, the
			-- add's spell target on its own at the right of its cast bar, and a friendly NPC with its title.
			local k = 768 / 1080
			local base = N.Add(env, "nameplate4", { name = "Innkeeper Hale", title = "Innkeeper", canAttack = false, reaction = 5, level = 30, health = 900, maxHealth = 900 })
			base:ClearAllPoints()
			base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", 1180 * k, (1080 - 300) * k)
			env.Enum.TooltipDataLineType = { None = 0, UnitLevel = 47 }
			env.C_TooltipInfo = { GetUnit = function(unit)
				local u = env._units[unit]
				return { lines = { { type = 2, leftText = u and u.name }, { type = u and u.title and 0 or 47, leftText = u and u.title }, { type = 47, leftText = "Level 30" } } }
			end }
			env.PlayerIsSpellTarget = function(unit) return env.Secret(unit == "nameplate1") end
			local unitClass = env.UnitClass
			env.UnitClass = function(unit)
				if unit == "player" then return "Warrior", "WARRIOR", 1 end
				return unitClass(unit)
			end
			local spells = { { 101, 5 }, { 102, 20 }, { 103, 30 } }
			env.C_SpellBook.GetNumSpellBookSkillLines = function() return 1 end
			env.C_SpellBook.GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #spells } end
			env.C_SpellBook.GetSpellBookItemInfo = function(slot) return { spellID = spells[slot][1], isPassive = false } end
			env.C_Spell.GetSpellInfo = function(id) return { spellID = id, minRange = 0, maxRange = spells[id - 100][2] } end
			env.C_Spell.IsSpellInRange = function(id) return spells[id - 100][2] >= 20 end
			env._units.nameplate2.spellTarget = "Thaldren"
			for key, value in pairs({ ["buffs.enabled"] = true, ["buffs.dispelGlow"] = true, ["buffs.count"] = 2, ["ccs.enabled"] = true,
				["debuffs.sunder"] = true, ["cast.targetGlow"] = true, ["cast.showTarget"] = true, ["cast.targetPlace"] = "RIGHT",
				["target.distance"] = true, ["friendly.npcTitle"] = true, ["cast.hideUnitName"] = false }) do
				K.Options.Write(module, key, value)
			end
			N.Cast(env, "nameplate1", { name = "Snap", text = "Snap", texture = 132200, notInterruptible = false })
			Hud.FillCast(ns.Plates.Get("nameplate1"), 0.55)
			N.Cast(env, "nameplate2", { name = "Mirefin Hex", text = "Mirefin Hex", texture = 136071, notInterruptible = false })
			Hud.FillCast(ns.Plates.Get("nameplate2"), 0.4)
			local A = dofile("Tools/regression/auras_env.lua")
			local function fill(container, key, icons)
				local group = container._groups[key]
				A.Assign(env, container, key, #icons)
				for i, icon in ipairs(icons) do
					local aura = group.active[i]._aura
					aura.icon:SetTexture(env.Secret(icon[1]))
					if aura.timer then aura.timer:SetText(icon[2]) end
					local ring = aura.dispel[1] and aura.dispel[1].texture
					if ring then ring:SetVertexColor(0.2, 0.6, 1); ring:SetShown(icon[3] ~= nil) end
				end
				Hud.PlaceAuras(container, group, group.active, #icons)
			end
			for _, token in ipairs({ "nameplate1", "nameplate2" }) do
				local plate = ns.Plates.Get(token)
				fill(plate.kinds.buffs, "buffs", { { 135940, "24", "Magic" }, { 135932, "9m" } })
				fill(plate.kinds.ccs, "ccs", { { 135963, "4" } })
			end
			fill(ns.Plates.Get("nameplate1").auras, "sunder", { { 132363, "27" } })
			env.RunTickers()
		elseif os.getenv("RENDER_PARITY_ROUND") == "5" then
			-- Round 5 switched on: full-height spell icons beside both casts, crowd control first where it shares the right of
			-- the bar with enemy buffs, and the add's quest progress with the client's kill-objective crosshair.
			local goal = "Mirefin Oracle slain: 3/8"
			env.Enum.TooltipDataLineType = { None = 0, UnitName = 2, QuestObjective = 8, UnitLevel = 47 }
			env.C_Texture = env.C_Texture or {}
			env.C_Texture.GetAtlasInfo = Common.Scene.AtlasInfo
			env.C_TooltipInfo = { GetUnit = function(unit) return { lines = { { type = 8, leftText = unit == "nameplate2" and goal or nil } } } end }
			env.C_QuestLog.GetNumQuestLogEntries = function() return 1 end
			env.C_QuestLog.GetInfo = function() return { questID = 1 } end
			env.C_QuestLog.GetQuestObjectives = function() return { { text = goal, type = "monster" } } end
			env._units.nameplate2.quest = true
			env.FireEvent("QUEST_LOG_UPDATE")
			for key, value in pairs({ ["cast.showIcon"] = true, ["cast.iconFull"] = true, ["buffs.enabled"] = true, ["buffs.count"] = 2,
				["ccs.enabled"] = true, ["ccs.place"] = "RIGHT", ["ccs.first"] = true, ["markers.questText"] = true, ["markers.questIcon"] = true,
				["cast.hideUnitName"] = false }) do
				K.Options.Write(module, key, value)
			end
			N.Cast(env, "nameplate1", { name = "Snap", text = "Snap", texture = 132200, notInterruptible = false })
			Hud.FillCast(ns.Plates.Get("nameplate1"), 0.55)
			N.Cast(env, "nameplate2", { name = "Mirefin Hex", text = "Mirefin Hex", texture = 136071, notInterruptible = false })
			Hud.FillCast(ns.Plates.Get("nameplate2"), 0.4)
			local A = dofile("Tools/regression/auras_env.lua")
			for _, token in ipairs({ "nameplate1", "nameplate2" }) do
				local plate = ns.Plates.Get(token)
				for key, icons in pairs({ buffs = { { 135940, "24" }, { 135932, "9m" } }, ccs = { { 135963, "4" } } }) do
					local container = plate.kinds[key]
					local group = container._groups[key]
					A.Assign(env, container, key, #icons)
					for i, icon in ipairs(icons) do
						local aura = group.active[i]._aura
						aura.icon:SetTexture(env.Secret(icon[1]))
						if aura.timer then aura.timer:SetText(icon[2]) end
						local ring = aura.dispel[1] and aura.dispel[1].texture
						if ring then ring:SetShown(false) end
					end
					Hud.PlaceAuras(container, group, group.active, #icons)
				end
			end
		end

		N.Focus(env, "nameplate2")
	end
	env.RunTimers(); Gallery.Ticks(dofile("Tools/regression/widget_env.lua"), env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
