-- test-nameplates-parity-r5.lua: EllesmereUI parity round 5 keeps v0.2.8 plates, then switches each new option on (the full-height cast icon, crowd control first, quest progress with its objective icon), checks it on its events and switches it off again.
local N = dofile("Tools/regression/nameplates_env.lua")

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { Nameplates = own } }, characters = {}, layouts = {} }
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function width(env, region)
	local v = region:GetWidth()
	return env.issecretvalue(v) and env.Reveal(v) or v
end

local function close(a, b)
	return math.abs(a - b) < 0.51
end

-- Quest objective lines in the unit tooltip (type 8), a quest log whose objectives name their type, and the crosshair
-- atlases, as the client gives them.
local function client(env)
	env.Enum.TooltipDataLineType = { None = 0, UnitName = 2, QuestObjective = 8, UnitLevel = 47 }
	local atlases = { crosshair_attack_48 = true, crosshair_lootall_48 = true, crosshair_quest_48 = true }
	env.C_Texture = { GetAtlasInfo = function(name) return atlases[name] and { width = 48, height = 48 } or nil end }
	env.C_TooltipInfo = { GetUnit = function(token)
		local u = N.ResolveUnit(token)
		local lines = { { type = 2, leftText = u and u.name } }
		for _, goal in ipairs(u and u.goals or {}) do
			lines[#lines + 1] = { type = 8, leftText = u.secretGoal and env.Secret(goal[1]) or goal[1], completed = goal[2] == true }
		end
		lines[#lines + 1] = { type = 47, leftText = "Level 10" }
		return { lines = lines }
	end }
	env._log = { { 1, { { text = "Kobold Vermin slain: 3/8", type = "monster" }, { text = "Candles: 2/5", type = "item" }, { text = "Ward placed: 0/1", type = "object" } } } }
	env._logReads = 0
	env.C_QuestLog.GetNumQuestLogEntries = function() env._logReads = env._logReads + 1; return #env._log, #env._log end
	env.C_QuestLog.GetInfo = function(i) return env._log[i] and { questID = env._log[i][1], isHeader = false } end
	env.C_QuestLog.GetQuestObjectives = function(id)
		for _, entry in ipairs(env._log) do if entry[1] == id then return entry[2] end end
	end
end

local function boot(units, opts)
	opts = opts or {}
	opts.saved = opts.saved or saved()
	opts.setup = function(env) client(env) end
	local env, K, ns = N.New(opts)
	for token, data in pairs(units) do
		N.Add(env, token, data)
	end
	local function set(key, value)
		K.Options.Write("Nameplates", key, value)
		env.RunTimers()
		assert(type(value) == "table" or K.Options.Read("Nameplates", key) == value, key)
	end
	return env, K, ns, set
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local NEW = { ["cast.iconFull"] = false, ["ccs.first"] = false, ["markers.questText"] = false, ["markers.questSize"] = 12,
	["markers.questIcon"] = false, ["markers.questIconScale"] = 1 }

-- v0.2.8 profiles keep every default, build no quest region and keep the spell icon and aura rows where they were.
do
	local env, K, ns, set = boot({ nameplate1 = { quest = true, goals = { { "Kobold Vermin slain: 3/8" } } } })
	local plate = ns.Plates.Get("nameplate1")
	for key, value in pairs(NEW) do
		assert(K.Options.Read("Nameplates", key) == value, "v0.2.8 profiles keep " .. key)
	end
	assert(plate.questText == nil and plate.questIcon == nil, "no quest progress until its option is on")
	assert(env._logReads == 0, "the quest log is never read")
	set("cast.showIcon", true)
	local _, rel = plate.castIcon:GetPoint(1)
	assert(rel == plate.cast, "the spell icon stays on the cast bar")
	clean(env, K)
end
collectgarbage()

-- Full-height icon: a square from the health bar's top to the cast bar's bottom, beside both past the level diamond or the
-- raid marker; the cast bar keeps its width, rows on that side step past it, the stacking box holds it, and off restores the icon.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	set("cast.showIcon", true)
	local barW0, room0 = width(env, plate.castBar), ns.Cast.Room(plate)
	local width0 = ns.Stacking.Extent(plate)
	set("cast.iconScale", 2)
	assert(ns.Cast.Room(plate) > room0, "a larger icon needs room under the cast bar")
	set("cast.iconFull", true)
	local icon = plate.castIcon
	local side = plate.barH + ns.Cast.Gap(plate) + ns.Cast.Height(plate)
	assert(near(width(env, icon), side), "as tall as both bars")
	local p, rel, rp, x, y = icon:GetPoint(1)
	assert(p == "TOPRIGHT" and rel == plate.health and rp == "TOPLEFT" and y == 0, "flush with the health bar's top")
	assert(-x > ns.Plate.DiamondReach(plate), "past the level diamond and the target bracket")
	assert(width(env, plate.castBar) > barW0 and close(width(env, plate.castBar), ns.state.width), "the cast bar takes the whole width")
	assert(ns.Stacking.Extent(plate) > width0, "the stacking box holds the icon")
	assert(near(ns.Cast.Room(plate), room0), "the icon scale is set aside and nothing grows under the cast bar")
	set("ccs.enabled", true)
	local _, _, _, cx = plate.kinds.ccs:GetPoint(1)
	assert(-cx > -x + side, "crowd control on the left steps past the icon")
	set("cast.offsetY", 4)
	assert(near(width(env, icon), side + 4), "a lower cast bar makes it taller")
	set("cast.offsetY", 0)
	set("focus.castHeight", 2)
	N.Focus(env, "nameplate1")
	assert(near(width(env, icon), plate.barH + ns.Cast.Gap(plate) + ns.Cast.Height(plate)) and ns.Cast.Height(plate) > 6, "a taller focus cast makes it taller")
	N.Focus(env, nil)
	set("cast.iconRight", true)
	p, rel, rp, x = icon:GetPoint(1)
	assert(p == "TOPLEFT" and rel == plate.health and rp == "TOPRIGHT" and x > ns.Plate.MarkerReach() + 16, "on the right past the raid marker")
	set("cast.iconRight", false)
	set("cast.iconScale", 1)
	set("cast.iconFull", false)
	_, rel = icon:GetPoint(1)
	assert(rel == plate.cast and near(width(env, icon), ns.Cast.Height(plate)), "off puts the icon back on the cast bar")
	assert(near(width(env, plate.castBar), barW0), "and the bar makes room again")
	local _, _, _, cx2 = plate.kinds.ccs:GetPoint(1)
	assert(cx2 > cx, "crowd control steps back to the diamond")
	clean(env, K)
end
collectgarbage()

-- With no level diamond and no target brackets, the full-height icon still stands clear of the uninterruptible shield badge.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	for key, value in pairs({ ["level.show"] = false, ["markers.classification"] = false, ["target.highlight"] = false, ["cast.showIcon"] = true, ["cast.iconFull"] = true }) do
		set(key, value)
	end
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183, notInterruptible = true })
	local _, _, _, x = plate.castIcon:GetPoint(1)
	local _, _, _, bx = plate.castBadge:GetPoint(1)
	assert(plate.castBadge:GetAlpha() == 1 and x <= bx, "the icon's right edge is left of the shield badge")
	clean(env, K)
end
collectgarbage()

-- Crowd control first: where both rows share a place, crowd control sits nearest the plate; off puts the buffs first again.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	set("buffs.enabled", true)
	set("ccs.enabled", true)
	set("ccs.place", "RIGHT")
	local _, _, _, bx = plate.kinds.buffs:GetPoint(1)
	local _, _, _, cx = plate.kinds.ccs:GetPoint(1)
	assert(cx > bx, "buffs first by default")
	set("ccs.first", true)
	local _, _, _, bx2 = plate.kinds.buffs:GetPoint(1)
	local _, _, _, cx2 = plate.kinds.ccs:GetPoint(1)
	assert(near(cx2, bx) and bx2 > cx2, "crowd control first")
	set("ccs.place", "TOP")
	set("buffs.place", "TOP")
	local _, _, _, _, by = plate.kinds.buffs:GetPoint(1)
	local _, _, _, _, cy = plate.kinds.ccs:GetPoint(1)
	assert(by > cy, "above the name too")
	set("ccs.first", false)
	_, _, _, _, by = plate.kinds.buffs:GetPoint(1)
	_, _, _, _, cy = plate.kinds.ccs:GetPoint(1)
	assert(cy > by, "off restores the order")
	clean(env, K)
end
collectgarbage()

-- Quest progress: the tooltip's first open objective after the name, in quest gold, on quest mobs only; it follows quest log
-- updates, skips finished and secret objectives, steps past a PvP badge, hides with the name and in instances, and turns off.
do
	local env, K, ns, set = boot({
		nameplate1 = { quest = true, goals = { { "Kobold Vermin slain: 8/8", true }, { "Kobold Vermin slain: 3/8" } } },
		nameplate2 = {},
		nameplate3 = { quest = true, secretGoal = true, goals = { { "Candles: 2/5" } } },
	})
	local mob, plain, hidden = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3")
	set("markers.questText", true)
	local text = assert(mob.questText, "a quest mob gets its progress")
	assert(text:IsShown() and text:GetText() == "3/8", "the first open objective")
	local r, g, b = text:GetTextColor()
	local qr, qg, qb = K.Tokens.Color("quest")
	assert(N.SameColor(r, g, b, qr, qg, qb), "in quest gold")
	local p, rel, rp = text:GetPoint(1)
	assert(p == "BOTTOMLEFT" and rel == mob.name and rp == "BOTTOMRIGHT", "after the name")
	assert(not mob.questIcon:IsShown(), "no icon until asked")
	assert(plain.questText == nil, "other mobs show none")
	assert(not (hidden.questText and hidden.questText:IsShown()), "a secret objective shows nothing")
	env._units.nameplate1.goals = { { "Kobold Vermin slain: 4/8" } }
	env.FireEvent("QUEST_LOG_UPDATE")
	assert(text:GetText() == "4/8", "quest log updates repaint it")
	env._units.nameplate1.goals = {}
	env.FireEvent("UNIT_QUEST_LOG_CHANGED", "player")
	assert(not text:IsShown(), "a finished quest hides it")
	env._units.nameplate1.goals = { { "Kobold Vermin slain: 5/8" } }
	env.FireEvent("QUEST_LOG_UPDATE")
	set("markers.questSize", 16)
	assert(select(2, text:GetFont()) == 16, "its size")
	set("markers.pvp", true)
	set("markers.pvpPlayersOnly", false)
	env._units.nameplate1.pvp = true
	env.FireEvent("UNIT_FACTION", "nameplate1")
	rel = select(2, text:GetPoint(1))
	assert(mob.pvpBadge:IsShown() and rel == mob.pvpBadge, "it steps past a PvP badge")
	env._units.nameplate1.pvp = false
	env.FireEvent("UNIT_FACTION", "nameplate1")
	rel = select(2, text:GetPoint(1))
	assert(rel == mob.name, "and back")
	set("cast.hideUnitName", true)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(text:GetAlpha() == 0, "it hides with the name while casting")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1")
	assert(text:GetAlpha() == 1, "and returns with it")
	set("markers.instances", false)
	env._instance = true
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(not text:IsShown(), "off in instances, it hides inside one")
	env._instance = false
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(text:IsShown(), "and returns outside")
	env._units.nameplate1.secretGoal = true
	env.FireEvent("PLAYER_REGEN_DISABLED")
	env._units.nameplate1.goals = { { "Kobold Vermin slain: 6/8" } }
	env.FireEvent("QUEST_LOG_UPDATE")
	assert(text:IsShown() and text:GetText() == "5/8", "a secret objective in combat keeps the last progress")
	env._units.nameplate1.secretGoal = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(text:GetText() == "6/8", "and combat's end catches up")
	set("name.show", false)

	assert(not text:IsShown(), "no name, no progress")
	set("name.show", true)
	assert(text:IsShown(), "names back, progress back")
	set("markers.questText", false)
	assert(not text:IsShown() and not mob.questIcon:IsShown(), "off hides it")
	clean(env, K)
end
collectgarbage()

-- Objective type icon: a sword for kill objectives and a bag for item objectives, matched in the quest log, else the quest
-- icon; its scale, the debuffs above the name rising over a tall line, and off.
do
	local env, K, ns, set = boot({
		nameplate1 = { quest = true, goals = { { "Kobold Vermin slain: 3/8" } } },
		nameplate2 = { quest = true, goals = { { "Candles: 2/5" } } },
		nameplate3 = { quest = true, goals = { { "Ward placed: 0/1" } } },
		nameplate4 = { quest = true, goals = { { "Escort the Caravan: 50%" } } },
	})
	local one, two, three, four = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3"), ns.Plates.Get("nameplate4")
	set("markers.questText", true)
	assert(env._logReads == 0, "text alone never reads the quest log")
	set("markers.questIcon", true)
	assert(N.Last(one.questIcon, "SetAtlas")[1] == "crosshair_attack_48" and one.questIcon:IsShown(), "a sword for a kill objective")
	assert(N.Last(two.questIcon, "SetAtlas")[1] == "crosshair_lootall_48", "a bag for an item")
	assert(N.Last(three.questIcon, "SetAtlas")[1] == "crosshair_quest_48", "the quest icon for the rest")
	assert(four.questText:GetText() == "50%" and N.Last(four.questIcon, "SetAtlas")[1] == "crosshair_quest_48", "a percent objective, unmatched")
	local reads = env._logReads
	env.FireEvent("UNIT_LEVEL", "nameplate1")
	assert(env._logReads == reads, "the quest log is read once per quest log change")
	env.FireEvent("QUEST_LOG_UPDATE")
	assert(env._logReads == reads + 1, "and again after one")
	local _, rel = one.questText:GetPoint(1)
	assert(rel == one.questIcon, "the text follows its icon")
	assert(close(width(env, one.questIcon), 12), "the icon matches the text")
	local _, above0 = ns.Stacking.Extent(one)
	local _, _, _, _, y0 = one.auras:GetPoint(1)
	set("markers.questIconScale", 2)
	assert(close(width(env, one.questIcon), 24), "its scale")
	local _, _, _, _, y1 = one.auras:GetPoint(1)
	local _, above1 = ns.Stacking.Extent(one)
	assert(close(y1 - y0, 24 - 16) and close(above1 - above0, 8), "debuffs above the name rise over the taller line")
	set("markers.questIcon", false)
	assert(not one.questIcon:IsShown(), "off drops the icon")
	_, rel = one.questText:GetPoint(1)
	assert(rel == one.name, "and the text returns to the name")
	set("markers.questText", false)
	local _, _, _, _, y2 = one.auras:GetPoint(1)
	assert(close(y2, y0), "off gives the room back")

	clean(env, K)
end
collectgarbage()

-- Without the atlas API the progress stays and the icon hides.
do
	local env, K, ns, set = boot({ nameplate1 = { quest = true, goals = { { "Kobold Vermin slain: 3/8" } } } })
	local plate = ns.Plates.Get("nameplate1")
	set("markers.questText", true)
	env.C_Texture = nil
	set("markers.questIcon", true)
	assert(plate.questText:IsShown() and not plate.questIcon:IsShown(), "text without an icon")
	clean(env, K)
end
collectgarbage()

-- The Options preview draws each new option on the sample it shows.

do
	local env, K, ns, set = boot({})
	local frame = ns.Preview.Build(env.UIParent)
	local target = frame.plates[1]
	set("markers.questText", true)
	set("markers.questIcon", true)
	frame.Refresh()
	assert(frame.chosen == 1 and target.questText:IsShown() and target.questText:GetText() == "3/8", "quest progress on the target sample")
	assert(target.questIcon:IsShown() and N.Last(target.questIcon, "SetAtlas")[1] == "crosshair_attack_48", "with its sword")
	set("cast.showIcon", true)
	set("cast.iconFull", true)
	frame.Refresh()
	local _, rel = target.castIcon:GetPoint(1)
	assert(rel == target.health and close(width(env, target.castIcon), target.barH + ns.Cast.Gap(target) + ns.Cast.Height(target)), "the full-height icon")
	set("buffs.enabled", true)
	set("ccs.enabled", true)
	set("ccs.place", "RIGHT")
	set("ccs.first", true)
	frame.Refresh()
	local _, _, _, bx = target.sampleKinds.buffs:GetPoint(1)
	local _, _, _, cx = target.sampleKinds.ccs:GetPoint(1)
	assert(bx > cx, "crowd control first")
	clean(env, K)
end
collectgarbage()

print("nameplates parity round 5 ok")
