-- test-nameplates-types.lua: enemy plates colour quest mobs, rares, elites and casters by type, a class-coloured bar keeps the name white, and the classification marker crowns the level badge.
local N = dofile("Tools/regression/nameplates_env.lua")
local SameColor = N.SameColor

local function barColor(bar)
	local r, g, b = bar:GetStatusBarColor()
	return r, g, b
end

local function setting(ns, key)
	local c = ns.Settings.Get(key)
	return c.r, c.g, c.b
end

local function token(K, name)
	local r, g, b = K.Tokens.Color(name)
	return r, g, b
end

-- barIs(bar, r, g, b): the bar's colour is r, g, b. A call in the middle of an argument list keeps one
-- value, so the bar's colour is read into locals here.
local function barIs(bar, r, g, b)
	local br, bg, bb = barColor(bar)
	return SameColor(br, bg, bb, r, g, b)
end

-- The pure rule: which type colours a plate, in priority order -----------------------------------------

do
	local _, _, ns = N.New({ enable = false })
	local Logic = ns.Logic
	local on = { quest = true, rare = true, elite = true, caster = true }
	assert(Logic.UnitType(on, { quest = true, classification = "elite", caster = true }) == "quest", "a quest mob is a quest mob before anything else")
	assert(Logic.UnitType(on, { classification = "rareelite", caster = true }) == "rare", "a rare elite is rare before elite")
	assert(Logic.UnitType(on, { classification = "rare" }) == "rare", "a rare")
	assert(Logic.UnitType(on, { classification = "elite", caster = true }) == "elite", "an elite before a caster")
	assert(Logic.UnitType(on, { classification = "worldboss" }) == "elite", "a world boss counts as elite")
	assert(Logic.UnitType(on, { classification = "normal", caster = true }) == "caster", "a caster")
	assert(Logic.UnitType(on, { classification = "normal" }) == nil, "a plain mob has no type")
	assert(Logic.UnitType({ quest = false, rare = true, elite = true, caster = true }, { quest = true, caster = true }) == "caster", "a type switched off is skipped")
	assert(Logic.UnitType(on, { quest = true, isPlayer = true }) == nil, "players never take a type colour")
	assert(Logic.UnitType(on, { quest = true, tapped = true }) == nil, "a tapped mob stays grey")
end

-- Casters: mana as the power type with a readable, positive maximum --------------------------------

do
	local _, _, ns = N.New({ enable = false })
	local Logic = ns.Logic
	local MANA = 0
	assert(Logic.IsCaster(MANA, 1200, MANA) == true, "a mob with mana is a caster")
	assert(Logic.IsCaster(MANA, 0, MANA) == false, "a mob whose mana pool is empty is not one: most melee NPCs carry the mana type with no mana")
	assert(Logic.IsCaster(1, 100, MANA) == false, "rage is not mana")
	assert(Logic.IsCaster(nil, 100, MANA) == false, "no power type, no caster")
	assert(Logic.IsCaster(MANA, nil, MANA) == nil, "an unreadable maximum decides nothing, so a known state can stay")
end

-- Live plates: the bar and the level badge rim take the type colour; the game's events refresh it ------

do
	local env, K, ns = N.New()
	local hr, hg, hb = token(K, "hostile")

	N.Add(env, "nameplate1", { powerType = 0, powerMax = 2400 })
	local caster = ns.Plates.Get("nameplate1")
	assert(barIs(caster.health, setting(ns, "types.casterColor")), "a caster's bar takes the caster colour by default")
	local er, eg, eb = caster.level.chrome.rim[1]:GetVertexColor()
	assert(SameColor(er, eg, eb, setting(ns, "types.casterColor")), "and so does the level badge's rim")

	N.Add(env, "nameplate2", { powerType = 0, powerMax = 0 })
	assert(barIs(ns.Plates.Get("nameplate2").health, hr, hg, hb), "a melee mob with the mana type and no mana keeps the reaction colour")

	N.Add(env, "nameplate3", { quest = true, powerType = 0, powerMax = 500 })
	local quest = ns.Plates.Get("nameplate3")
	assert(barIs(quest.health, setting(ns, "types.questColor")), "a quest mob takes the quest colour over the caster colour")
	env._units.nameplate3.quest = false
	env.FireEvent("QUEST_LOG_UPDATE")
	assert(barIs(quest.health, setting(ns, "types.casterColor")), "QUEST_LOG_UPDATE rereads the quest state on every plate")
	env._units.nameplate3.quest = true
	env.FireEvent("UNIT_QUEST_LOG_CHANGED", "player")
	assert(barIs(quest.health, setting(ns, "types.questColor")), "UNIT_QUEST_LOG_CHANGED does too")

	N.Add(env, "nameplate4", { classification = "rare" })
	assert(barIs(ns.Plates.Get("nameplate4").health, setting(ns, "types.rareColor")), "a rare takes the rare colour")
	N.Add(env, "nameplate5", { classification = "elite" })
	local elite = ns.Plates.Get("nameplate5")
	assert(barIs(elite.health, hr, hg, hb), "elites keep the reaction colour by default: the gold diamond already marks them")
	K.Options.Write("Nameplates", "types.elite", true)
	assert(barIs(elite.health, setting(ns, "types.eliteColor")), "switched on, elites take the elite colour")

	N.Add(env, "nameplate6", { isPlayer = true, class = "MAGE", powerType = 0, powerMax = 5000, quest = true })
	local mage = N.CLASS.MAGE
	assert(barIs(ns.Plates.Get("nameplate6").health, mage[1], mage[2], mage[3]), "an enemy player keeps the class colour whatever the type")

	N.Add(env, "nameplate7", { tapped = true, powerType = 0, powerMax = 500 })
	assert(barIs(ns.Plates.Get("nameplate7").health, token(K, "textDisabled")), "a tapped mob stays grey")

	-- A unit that turns rare mid-fight (a scripted encounter) recolours with its marker.
	local scout = ns.Plates.Get("nameplate2")
	env._units.nameplate2.classification = "rare"
	env.FireEvent("UNIT_CLASSIFICATION_CHANGED", "nameplate2")
	assert(scout.marker:IsShown() and barIs(scout.health, setting(ns, "types.rareColor")), "UNIT_CLASSIFICATION_CHANGED recolours the bar with the marker")
	env._units.nameplate2.classification = "normal"
	env.FireEvent("UNIT_CLASSIFICATION_CHANGED", "nameplate2")
	assert(barIs(scout.health, hr, hg, hb), "and back")

	-- The power type changes (a druid-like NPC shifting form): UNIT_DISPLAYPOWER rereads it.
	env._units.nameplate2.powerMax = 900
	env.FireEvent("UNIT_DISPLAYPOWER", "nameplate2")
	assert(barIs(ns.Plates.Get("nameplate2").health, setting(ns, "types.casterColor")), "UNIT_DISPLAYPOWER rereads the power type")

	-- A secret maximum in combat never decides; the plate keeps the state it knew.
	env._units.nameplate1.powerMax = env.Secret(2400)
	env.FireEvent("UNIT_DISPLAYPOWER", "nameplate1")
	assert(barIs(caster.health, setting(ns, "types.casterColor")), "a secret power maximum keeps the known caster state")
	N.Add(env, "nameplate8", { powerType = 0, powerMax = env.Secret(2400) })
	assert(barIs(ns.Plates.Get("nameplate8").health, hr, hg, hb), "a plate that first meets its unit with a secret maximum shows no caster colour")

	-- Switching a type off gives the bar its own colour back; the threat colour still wins on the bar.
	K.Options.Write("Nameplates", "types.caster", false)
	assert(barIs(caster.health, hr, hg, hb), "casters off: the reaction colour")
	env._inGroup = true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env._units.nameplate3.threat = 3
	K.Options.Write("Nameplates", "threat.display", "health")
	env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "nameplate3")
	assert(barIs(quest.health, setting(ns, "threat.danger")), "the health threat display colours the bar over the type colour")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A class-coloured bar carries the class; the name stays white so it reads over the fill ----------------

do
	local env, K, ns = N.New()
	local pal = { 0.96, 0.55, 0.73 }
	N.CLASS.PALADIN = pal
	N.Add(env, "nameplate1", { canAttack = false, reaction = 5, isPlayer = true, class = "PALADIN", name = "Leduc" })
	local friend = ns.Plates.Get("nameplate1")
	assert(barIs(friend.health, pal[1], pal[2], pal[3]), "a friendly paladin's bar is pink")
	local nr, ng, nb = friend.name:GetTextColor()
	assert(SameColor(nr, ng, nb, token(K, "textEmphasis")), "the name over a class-coloured bar reads white, not pink on pink")

	K.Options.Write("Nameplates", "friendly.colorSource", "reaction")
	nr, ng, nb = friend.name:GetTextColor()
	assert(SameColor(nr, ng, nb, pal[1], pal[2], pal[3]), "with a reaction-coloured bar, the name carries the class colour")

	K.Options.Write("Nameplates", "friendly.colorSource", "class")
	K.Options.Write("Nameplates", "friendly.nameOnly", true)
	nr, ng, nb = friend.name:GetTextColor()
	assert(SameColor(nr, ng, nb, pal[1], pal[2], pal[3]), "a name-only plate has no bar, so the name carries the class colour")

	K.Options.Write("Nameplates", "friendly.nameOnly", false)
	K.Options.Write("Nameplates", "name.classColor", false)
	nr, ng, nb = friend.name:GetTextColor()
	assert(SameColor(nr, ng, nb, token(K, "textEmphasis")), "class-coloured names off: white")
	N.CLASS.PALADIN = nil
end

-- The elite diamond crowns the level badge, away from the raid marker at the bar's right end -----------

do
	local env, _, ns = N.New()
	N.Add(env, "nameplate1", { classification = "elite", raid = 8 })
	local plate = ns.Plates.Get("nameplate1")
	assert(plate.marker:IsShown() and plate.raid:IsShown(), "the elite shows its diamond and its raid marker")
	local point, relative, relativePoint = plate.marker:GetPoint(1)
	assert(relative == plate.level, "the diamond hangs from the level badge, not the health bar")
	assert(point == "BOTTOM" and relativePoint == "TOP", "centred above the badge")
	local _, raidRelative = plate.raid:GetPoint(1)
	assert(raidRelative == plate.health, "the raid marker keeps the bar's right end to itself")
	assert(N.Same(plate.name:GetWidth(), ns.state.width), "the name takes the bar's full width now that nothing sits above its right end")
end

print("nameplates types ok")
