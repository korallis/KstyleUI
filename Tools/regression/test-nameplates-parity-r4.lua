-- test-nameplates-parity-r4.lua: EllesmereUI parity round 4 keeps v0.2.8 plates and regions, then switches each new nameplate option on, checks it on its events, and switches it off again.
local N = dofile("Tools/regression/nameplates_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { Nameplates = own } }, characters = {}, layouts = {} }
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- Hit-test insets, NPC tooltips, the spell-target answer and a spellbook of three ranged spells, as the client gives them.
local function client(env)
	N.Curves(env)
	env.Enum.NamePlateType = { Friendly = 0, Enemy = 1 }
	env._insets, env._insetWrites = { [0] = { 0, 0, 0, 0 }, [1] = { 0, 0, 0, 0 } }, {}
	env.C_NamePlateManager = {
		GetNamePlateHitTestInsets = function(kind) return unpack(env._insets[kind]) end,
		SetNamePlateHitTestInsets = function(kind, l, r, t, b)
			assert(not env._combat, "SetNamePlateHitTestInsets in combat")
			env._insets[kind] = { l, r, t, b }
			env._insetWrites[#env._insetWrites + 1] = { kind, l, r, t, b }
		end,
	}
	env.Enum.TooltipDataLineType = { None = 0, UnitName = 2, UnitLevel = 47 }
	env.C_TooltipInfo = { GetUnit = function(token)
		local u = N.ResolveUnit(token)
		local lines = { { type = 2, leftText = u and u.name } }
		if u and u.title then lines[2] = { type = 0, leftText = u.secretTitle and env.Secret(u.title) or u.title } end
		lines[#lines + 1] = { type = 47, leftText = "Level 30" }
		return { lines = lines }
	end }
	function env.PlayerIsSpellTarget(token)
		local u = N.ResolveUnit(token)
		return env.Secret(u ~= nil and u.atMe == true)
	end
	env._spells = { { 101, 5 }, { 102, 20 }, { 103, 30 } }
	env.C_SpellBook.GetNumSpellBookSkillLines = function() return 1 end
	env.C_SpellBook.GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #env._spells } end
	env.C_SpellBook.GetSpellBookItemInfo = function(slot) return { spellID = env._spells[slot][1], isPassive = false } end
	env.C_Spell.GetSpellInfo = function(id)
		for _, s in ipairs(env._spells) do if s[1] == id then return { spellID = id, minRange = s[3] or 0, maxRange = s[2] } end end
	end
	env.C_Spell.IsSpellInRange = function(id, token)
		local u = N.ResolveUnit(token)
		if not u then return nil end
		if id < 100 then return not u.outOfRange end
		for _, s in ipairs(env._spells) do if s[1] == id then return (u.distance or 0) <= s[2] and (u.distance or 0) >= (s[3] or 0) end end
	end
end

local function boot(units, opts)
	opts = opts or {}
	opts.saved = opts.saved or saved()
	local setup = opts.setup
	opts.setup = function(env)
		client(env)
		if setup then setup(env) end
	end
	local env, K, ns = N.New(opts)
	env._units.player = env._units.player or { level = 15 }
	for token, data in pairs(units) do
		N.Add(env, token, data)
	end
	local function set(key, value)
		K.Options.Write("Nameplates", key, value)
		env.RunTimers()
		local got = K.Options.Read("Nameplates", key)
		assert(type(value) == "table" or got == value, key)
	end
	return env, K, ns, set
end

-- shown(env, region) -> the text a font string last received, formatted, with any secret revealed.
local function shown(env, region)
	for i = #region._calls, 1, -1 do
		local call = region._calls[i]
		if call.method == "SetText" then return env.issecretvalue(call.args[1]) and env.Reveal(call.args[1]) or call.args[1] end
		if call.method == "SetFormattedText" then
			local args = {}
			for j = 2, call.args.n do args[#args + 1] = env.issecretvalue(call.args[j]) and env.Reveal(call.args[j]) or call.args[j] end
			return string.format(call.args[1], unpack(args))
		end
	end
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local NEW = {
	["buffs.enabled"] = false, ["buffs.filter"] = "important", ["buffs.place"] = "RIGHT", ["buffs.count"] = 3, ["buffs.showTime"] = true, ["buffs.dispelGlow"] = false,
	["ccs.enabled"] = false, ["ccs.place"] = "LEFT", ["ccs.count"] = 2, ["ccs.showTime"] = true, ["debuffs.sunder"] = false,
	["cast.targetPlace"] = "", ["cast.targetGlow"] = false, ["friendly.npcTitle"] = false, ["friendly.npcTitleSize"] = 12, ["friendly.npcTitleMatch"] = true,
	["stacking.spacing"] = 1, ["stacking.clickWidth"] = 1, ["stacking.clickHeight"] = 1, ["stacking.friendlyClicks"] = true,
	["target.distance"] = false, ["target.distanceSize"] = 12, ["target.distanceX"] = 0, ["target.distanceY"] = 0,
}

local function filters(container)
	local out = {}
	for key, group in pairs(container._groups) do out[key] = group.enabled ~= false and group.filter or nil end
	return out
end

-- v0.2.8 profiles keep every default, build no new region or group, write no click area and run no distance ticker.
do
	local env, K, ns = boot({ nameplate1 = { title = "Innkeeper", atMe = true }, nameplate2 = { canAttack = false, reaction = 5, title = "Innkeeper" } },
		{ playerClass = "WARRIOR", stackingBounds = true })
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", texture = 1 })
	local plate, friend = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	for key, value in pairs(NEW) do
		assert(K.Options.Read("Nameplates", key) == value, "v0.2.8 profiles keep " .. key)
	end
	for _, p in ipairs({ plate, friend }) do
		for _, key in ipairs({ "kinds", "sunderGroup", "castTarget", "castTargetGlow", "distanceText", "subtitle" }) do
			assert(p[key] == nil, "no " .. key .. " until its option is on")
		end
	end
	assert(not filters(plate.auras).debuffs:find("CROWD_CONTROL", 1, true) and plate.auras._groups.debuffs.maxFrameCount == 5, "the debuff row is today's")
	assert(#env._insetWrites == 0, "the click area is the game's")
	assert(not plate.castName:GetText():find(">", 1, true), "the spell name stands alone")
	clean(env, K)
end
collectgarbage()

-- Enemy buffs: each filter, place, count, timer and the dispel glow, on enemies only, following faction changes, then off.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = { canAttack = false, reaction = 5 } }, { stackingBounds = true })
	local plate, friend = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	local _, above0, _, below0 = ns.Stacking.Extent(plate)
	local width0 = ns.Stacking.Extent(plate)
	set("buffs.enabled", true)
	local buffs = assert(plate.kinds and plate.kinds.buffs, "an enemy gets a buff row")
	assert(friend.kinds == nil, "friends get none")
	assert(buffs._unit == "nameplate1" and buffs:IsShown(), "bound to the unit")
	assert(filters(buffs).buffs == "HELPFUL|IMPORTANT|INCLUDE_NAME_PLATE_ONLY" and buffs._groups.buffs.maxFrameCount == 3, "important buffs, three icons")
	local p, rel, relPoint, x = buffs:GetPoint(1)
	assert(p == "LEFT" and rel == plate.health and relPoint == "RIGHT" and x > 0, "right of the bar, past the raid marker")
	assert(ns.Stacking.Extent(plate) > width0, "the footprint reaches the icons")
	set("buffs.filter", "dispellable")
	assert(filters(buffs).buffs == "HELPFUL|DISPELLABLE|INCLUDE_NAME_PLATE_ONLY", "dispellable buffs")
	set("buffs.filter", "all")
	assert(filters(buffs).buffs == "HELPFUL|INCLUDE_NAME_PLATE_ONLY", "every buff")
	set("buffs.count", 5)
	assert(buffs._groups.buffs.maxFrameCount == 5, "five icons")
	A.Assign(env, buffs, "buffs", 2)
	local button = buffs:GetAuraGroupFrame("buffs", 1)
	assert(button._aura.timer and button._aura.timer:GetParent():IsShown(), "time left shows")
	set("buffs.showTime", false)
	assert(not button._aura.timer:GetParent():IsShown(), "and hides")
	set("buffs.dispelGlow", true)
	local glow = button._aura.dispel[1]
	assert(glow and glow.options.showWhenHelpful == true and glow.options.showWhenHarmful == false, "the engine colours dispellable buffs")
	local _, _, _, ox = glow.texture:GetPoint(1)
	assert(ox < 0, "the glow rings the tile from outside, border or not")
	set("buffs.dispelGlow", false)
	assert(#button._aura.dispel == 0, "the glow goes")
	for place, want in pairs({ LEFT = { "RIGHT", "LEFT" }, TOP = { "BOTTOM", "TOP" }, TOPLEFT = { "BOTTOMLEFT", "TOPLEFT" },
		TOPRIGHT = { "BOTTOMRIGHT", "TOPRIGHT" }, BOTTOM = { "TOP", "BOTTOM" } }) do
		set("buffs.place", place)
		local point, _, rp = buffs:GetPoint(1)
		assert(point == want[1] and rp == want[2], "place " .. place)
	end
	set("buffs.place", "TOP")
	local _, above1 = ns.Stacking.Extent(plate)
	assert(above1 > above0, "a row on top makes room above")
	set("buffs.place", "BOTTOM")
	local _, above2, _, below2 = ns.Stacking.Extent(plate)
	assert(near(above2, above0) and below2 > below0, "a row underneath makes room below")
	env._units.nameplate1.canAttack = false
	env.FireEvent("UNIT_FACTION", "nameplate1")
	assert(buffs._unit == "none" and not buffs:IsShown(), "a unit turning friendly drops its buffs")
	env._units.nameplate1.canAttack = true
	env.FireEvent("UNIT_FACTION", "nameplate1")
	assert(buffs._unit == "nameplate1" and buffs:IsShown(), "and hostile again shows them")
	set("debuffs.enabled", false)
	assert(buffs._unit == "nameplate1" and buffs:IsShown(), "buffs do not need the debuff row")
	set("debuffs.enabled", true)
	set("buffs.enabled", false)
	assert(buffs._unit == "none" and not buffs:IsShown(), "off hides the row")
	local _, above3, _, below3 = ns.Stacking.Extent(plate)
	assert(near(above3, above0) and near(below3, below0), "and gives its room back")
	clean(env, K)
end
collectgarbage()

-- Crowd control: anyone's, its own row; yours leaves the debuff row while it shows; two rows in one place step apart.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	set("ccs.enabled", true)
	local ccs = assert(plate.kinds.ccs, "an enemy gets a crowd control row")
	assert(filters(ccs).ccs == "HARMFUL|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY" and ccs._groups.ccs.maxFrameCount == 2, "crowd control from anyone")
	assert(filters(plate.auras).debuffs:find("|!CROWD_CONTROL", 1, true), "your crowd control leaves the debuff row")
	local p, _, rp, x = ccs:GetPoint(1)
	assert(p == "RIGHT" and rp == "LEFT" and x < -ns.Plate.DiamondReach(plate), "left of the bar, past the level diamond")
	set("buffs.enabled", true)
	set("buffs.place", "LEFT")
	local _, _, _, bx = plate.kinds.buffs:GetPoint(1)
	local _, _, _, cx = ccs:GetPoint(1)
	assert(cx < bx, "the second row in a place steps past the first")
	set("ccs.enabled", false)
	assert(not filters(plate.auras).debuffs:find("CROWD_CONTROL", 1, true) and ccs._unit == "none", "off restores the debuff row")
	local _, _, _, bx2 = plate.kinds.buffs:GetPoint(1)
	assert(near(bx2, bx), "buffs keep their place")
	clean(env, K)
end
collectgarbage()

-- Sunder Armor: a warrior sees every warrior's sunder in its own slot, inside the row; off, or every debuff shown, drops it.
do
	local env, K, ns, set = boot({ nameplate1 = {} }, { playerClass = "WARRIOR" })
	local plate = ns.Plates.Get("nameplate1")
	set("debuffs.sunder", true)
	local group = assert(plate.auras._groups.sunder, "a sunder slot")
	assert(group.filter == "HARMFUL|!PLAYER" and group.candidateFilters.includeSpellIDs[7386] and group.candidateFilters.includeSpellIDs[11597] and group.maxFrameCount == 1,
		"other warriors' Sunder Armor, every rank")
	assert(plate.auras._groups.debuffs.maxFrameCount == 4, "the row keeps its length")
	set("debuffs.onlyMine", false)
	assert(plate.auras._groups.sunder.enabled == false and plate.auras._groups.debuffs.maxFrameCount == 5, "every debuff already shows it")
	set("debuffs.onlyMine", true)
	set("debuffs.sunder", false)
	assert(plate.auras._groups.sunder.enabled == false and plate.auras._groups.debuffs.maxFrameCount == 5, "off drops it")
	clean(env, K)
	local env2, K2, ns2, set2 = boot({ nameplate1 = {} })
	set2("debuffs.sunder", true)
	assert(ns2.Plates.Get("nameplate1").sunderGroup == nil, "other classes get no slot")
	clean(env2, K2)
	local env3, K3, ns3, set3 = boot({}, { playerClass = "WARRIOR" })
	local frame = ns3.Preview.Build(env3.UIParent)
	local icons = frame.plates[1].sampleAuras
	set3("debuffs.sunder", true)
	frame.Refresh()
	assert(N.Last(icons[#icons].icon, "SetTexture")[1] == 132363, "the preview's last debuff turns into Sunder Armor")
	set3("debuffs.sunder", false)
	frame.Refresh()
	assert(N.Last(icons[#icons].icon, "SetTexture")[1] ~= 132363, "and back")
	clean(env3, K3)
end
collectgarbage()

-- Cast bar: the glow while a cast targets you, from the engine's secret answer, and the spell target in its own place.
do
	local env, K, ns, set = boot({ nameplate1 = { atMe = true, spellTarget = "Thaldrin" } })
	local plate = ns.Plates.Get("nameplate1")
	set("cast.targetGlow", true)
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", texture = 1 })
	local glow = assert(plate.castTargetGlow, "a glow")
	assert(glow[1]:IsShown() and #N.Calls(glow[1], "SetAlphaFromBoolean") > 0, "the engine shows it from the secret answer")
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
	assert(not glow[1]:IsShown(), "an interrupted cast drops it")
	env._units.nameplate1.atMe = nil
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", texture = 1 })
	assert(glow[1]:IsShown() and env.Reveal(N.Last(glow[1], "SetAlphaFromBoolean")[1]) == false, "a cast at someone else stays dark")
	set("cast.targetGlow", false)
	assert(not glow[1]:IsShown(), "off hides it")
	set("cast.showTarget", true)
	set("cast.targetPlace", "RIGHT")
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", texture = 1 })
	assert(plate.castTarget:IsShown() and env.Reveal(plate.castTarget:GetText()) == "Thaldrin", "the target on its own")
	assert(not tostring(plate.castName:GetText()):find(">", 1, true), "not after the name")
	assert(N.Last(plate.castTarget, "SetJustifyH")[1] == "RIGHT", "at the right of the bar")
	set("cast.showTime", true)
	local _, rel = plate.castTarget:GetPoint(2)
	assert(rel == plate.castTime, "clear of the time left")
	N.Target(env, "nameplate1")
	set("cast.nameBelow", false)
	assert(not plate.castTarget:IsShown(), "a name shown inside the bar takes the target after it")
	set("cast.nameBelow", true)
	set("cast.targetPlace", "")
	assert(not plate.castTarget:IsShown(), "after the name again")
	env.PlayerIsSpellTarget = nil
	set("cast.targetGlow", true)
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", texture = 1 })
	assert(not plate.castTargetGlow[1]:IsShown(), "without the API nothing glows")
	clean(env, K)
end
collectgarbage()

-- Stacking and clicks: the spacing scales the stacking bounds; click widths and friendly click-through reach the game out of combat and hand back.
do
	local env, K, ns, set = boot({ nameplate1 = {} }, { stackingBounds = true })
	local plate = ns.Plates.Get("nameplate1")
	set("preset", "custom")
	local _, h0 = plate.stackBounds:GetSize()
	set("stacking.spacing", 1.5)
	local _, h1 = plate.stackBounds:GetSize()
	assert(near(h1, h0 * 1.5), "spacing scales the box the game stacks by")
	set("stacking.spacing", 1)
	set("stacking.clickWidth", 0.5)
	local w, h = env.C_NamePlate.GetNamePlateSize()
	local e = env._insets[1]
	assert(near(e[1], w / 4) and near(e[2], w / 4) and e[3] == 0, "enemy plates take clicks on their middle half")
	env._combat = true
	set("stacking.clickHeight", 0.5)
	assert(env._insets[1][3] == 0, "never in combat")
	env._combat = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(near(env._insets[1][3], h / 4), "but after it")
	set("stacking.friendlyClicks", false)
	assert(near(env._insets[0][1], w / 2) and near(env._insets[0][3], h / 2), "clicks pass through friendly plates")
	env._driverSize = { 220, 90 }
	env.NamePlateDriverFrame.UpdateNamePlateSize()
	env.RunTimers()
	assert(near(env._insets[1][1], 220 / 4) and near(env._insets[0][1], 110), "a new game plate size moves the insets with it")
	K.Modules.Disable("Nameplates")
	env.RunTimers()
	for kind = 0, 1 do
		local i = env._insets[kind]
		assert(i[1] == 0 and i[2] == 0 and i[3] == 0 and i[4] == 0, "turning the module off hands the click area back")
	end
	clean(env, K)
end
collectgarbage()

-- NPC titles: the tooltip's line under the name, on friendly NPCs only, with its size and colours; a secret title passes whole.
do
	local env, K, ns, set = boot({ nameplate1 = { canAttack = false, reaction = 5, title = "Innkeeper" },
		nameplate2 = { canAttack = false, reaction = 5 }, nameplate3 = { canAttack = false, reaction = 5, isPlayer = true, title = "Guildless" },
		nameplate4 = { canAttack = false, reaction = 5, title = "Banker", secretTitle = true } })
	local npc, plain, player, hidden = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3"), ns.Plates.Get("nameplate4")
	set("friendly.npcTitle", true)
	assert(npc.subtitle and npc.subtitle:IsShown() and shown(env, npc.subtitle) == "Innkeeper", "the title under the name")
	assert(npc.subtitleRoom and npc.subtitleRoom > 0, "the name rises over it")
	assert(not (plain.subtitle and plain.subtitle:IsShown()), "an NPC without a title shows none")
	assert(not (player.subtitle and player.subtitle:IsShown()), "players keep their own lines")
	assert(hidden.subtitle and env.issecretvalue(N.Last(hidden.subtitle, "SetFormattedText")[2]), "a secret title passes through whole")
	set("friendly.npcTitleSize", 15)
	assert(select(2, npc.subtitle:GetFont()) == 15, "its size")
	local r, g, b = npc.name:GetTextColor()
	local sr, sg, sb = npc.subtitle:GetTextColor()
	assert(near(r, sr) and near(g, sg) and near(b, sb), "in the name colour")
	set("friendly.npcTitleMatch", false)
	set("friendly.npcTitleColor", { r = 1, g = 0, b = 0 })
	sr, sg, sb = npc.subtitle:GetTextColor()
	assert(sr == 1 and sg == 0 and sb == 0, "or its own")
	set("friendly.npcTitle", false)
	assert(not npc.subtitle:IsShown() and (npc.subtitleRoom or 0) == 0, "off gives the room back")
	clean(env, K)
end
collectgarbage()

-- Distance: a range from the player's spells on the target only, refreshed on its ticker and at once on a new target, then off.
do
	local env, K, ns, set = boot({ nameplate1 = { distance = 12 }, nameplate2 = { distance = 40 } })
	local one, two = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	N.Target(env, "nameplate1")
	set("target.distance", true)
	env.RunTickers()
	assert(one.distanceText:IsShown() and one.distanceText:GetText() == "5-20", "between two spell ranges")
	assert(not two.distanceText:IsShown(), "on the target only")
	env._units.nameplate1.distance = 3
	env.RunTickers()
	assert(one.distanceText:GetText() == "0-5", "it follows the target")
	N.Target(env, "nameplate2")
	assert(two.distanceText:IsShown() and two.distanceText:GetText() == "30+" and not one.distanceText:IsShown(), "a new target updates at once")
	set("target.distanceSize", 16)
	set("target.distanceX", 10)
	local _, _, _, x = two.distanceText:GetPoint(1)
	assert(select(2, two.distanceText:GetFont()) >= 16 and x > 0, "its size and place")
	set("target.distance", false)
	assert(not two.distanceText:IsShown(), "off hides it")
	local text = two.distanceText:GetText()
	env._units.nameplate2.distance = 10
	env.RunTickers()
	assert(two.distanceText:GetText() == text, "and stops the ticker")
	clean(env, K)
end
collectgarbage()

-- The Options preview draws each new option on a sample that has it.
do
	local env, K, ns, set = boot({})
	local frame = ns.Preview.Build(env.UIParent)
	local plates = frame.plates
	set("buffs.enabled", true)
	set("ccs.enabled", true)
	set("buffs.dispelGlow", true)
	frame.Refresh()
	local target = plates[1]
	assert(frame.chosen == 1 and target.sampleKinds.buffs:IsShown() and target.sampleKinds.ccs:IsShown(), "buffs and crowd control on the target sample")
	assert(target.sampleKinds.buffs.icons[1].tile.dispel:IsShown(), "the dispel glow on a buff")
	set("cast.targetGlow", true)
	frame.Refresh()
	assert(target.castTargetGlow[1]:IsShown(), "the cast glows for targeting you")
	set("target.distance", true)
	frame.Refresh()
	assert(target.distanceText:IsShown() and target.distanceText:GetText() == "8-20", "the distance on the target")
	set("friendly.npcTitle", true)
	frame.Refresh()
	assert(frame.chosen == 4 and shown(env, plates[4].subtitle) == "Innkeeper", "the NPC sample shows its title")
	clean(env, K)
end
collectgarbage()

-- Review of f55b1491, finding 1: a spell with a minimum range, or one invalid for this target, never brackets the distance.
do
	local env, K, ns, set = boot({ nameplate1 = { distance = 3 } })
	local plate = ns.Plates.Get("nameplate1")
	env._spells = { { 101, 35, 8 } }
	N.Target(env, "nameplate1")
	set("target.distance", true)
	env.RunTickers()
	assert(plate.distanceText:GetText() == "", "too close for an 8-35 yard spell is not 35+")
	env._spells = { { 101, 30 }, { 102, 30 } }
	env.C_Spell.IsSpellInRange = function(id) if id == 102 then return true end end
	env.FireEvent("SPELLS_CHANGED")
	env.RunTickers()
	assert(plate.distanceText:GetText() == "0-30", "a heal invalid on an enemy gives way to an attack of the same range")
	clean(env, K)
end
collectgarbage()

-- Finding 2: the click area keeps the axis it does not change, and is never written when the game's is unreadable.
do
	local env, K, _, set = boot({ nameplate1 = {} })
	env._insets[1] = { 3, 4, 5, 6 }
	set("stacking.clickWidth", 0.5)
	local w = env.C_NamePlate.GetNamePlateSize()
	local e = env._insets[1]
	assert(near(e[1], w / 4) and near(e[2], w / 4) and e[3] == 5 and e[4] == 6, "width alone keeps the game's top and bottom")
	set("stacking.clickWidth", 1)
	assert(table.concat(env._insets[1], ",") == "3,4,5,6", "and off writes the game's insets back")
	env.C_NamePlateManager.GetNamePlateHitTestInsets = function() error("unreadable") end
	local writes = #env._insetWrites
	set("stacking.clickWidth", 0.5)
	set("stacking.clickWidth", 1)
	assert(#env._insetWrites == writes and table.concat(env._insets[1], ",") == "3,4,5,6", "an unreadable click area is left alone")
	clean(env, K)
end
collectgarbage()

-- Finding 3, at each test screen: the stacking box holds a long row on one side, and rows above the name never share a line where they overlap.
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns, set = boot({ nameplate1 = {} }, { stackingBounds = true, width = screen[1], height = screen[2] })
	local plate, at = ns.Plates.Get("nameplate1"), screen[1] .. "x" .. screen[2] .. ": "
	set("buffs.enabled", true)
	set("buffs.count", 8)
	local _, right = ns.Auras.Reach(plate)
	local box = plate.stackBounds
	local half = box:GetWidth() * box:GetEffectiveScale() / plate:GetEffectiveScale() / 2
	assert(half >= ns.state.width / 2 + right - 1e-6, at .. "the stacking box reaches the eighth buff")
	set("ccs.enabled", true)
	set("ccs.place", "TOPLEFT")
	set("buffs.place", "TOP")
	set("buffs.count", 3)
	local size = ns.Auras.Grid(plate)
	local _, _, _, _, by = plate.kinds.buffs:GetPoint(1)
	local _, _, _, _, cy = plate.kinds.ccs:GetPoint(1)
	assert(cy >= by + size, at .. "crowd control at the top left steps over buffs above the name")
	set("buffs.place", "TOPRIGHT")
	set("buffs.count", 1)
	set("ccs.count", 1)
	_, _, _, _, by = plate.kinds.buffs:GetPoint(1)
	_, _, _, _, cy = plate.kinds.ccs:GetPoint(1)
	assert(near(by, cy), at .. "one icon at each top corner shares a line")
	clean(env, K)
	collectgarbage()
end

-- Finding 4: crowd control leaves the debuff row only on plates that have a crowd control row, following faction changes.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = { canAttack = false, reaction = 5 } })
	local enemy, friend = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	set("debuffs.onlyMine", false)
	set("ccs.enabled", true)
	assert(not filters(friend.auras).debuffs:find("CROWD_CONTROL", 1, true), "a friendly plate keeps crowd control among its debuffs")
	assert(filters(enemy.auras).debuffs:find("|!CROWD_CONTROL", 1, true), "an enemy's moves to its own row")
	env._units.nameplate2.canAttack, env._units.nameplate2.reaction = true, 2
	env.FireEvent("UNIT_FACTION", "nameplate2")
	assert(filters(friend.auras).debuffs:find("|!CROWD_CONTROL", 1, true), "turning hostile moves it")
	env._units.nameplate2.canAttack, env._units.nameplate2.reaction = false, 5
	env.FireEvent("UNIT_FACTION", "nameplate2")
	assert(not filters(friend.auras).debuffs:find("CROWD_CONTROL", 1, true), "and friendly again brings it back")
	clean(env, K)
end
collectgarbage()

-- Finding 5: Sunder Armor fits a one-tile row, and a missing UnitClass hides it without an error.
do
	local env, K, ns, set = boot({ nameplate1 = {} }, { playerClass = "WARRIOR" })
	local groups = ns.Plates.Get("nameplate1").auras._groups
	set("debuffs.columns", 1)
	set("debuffs.rows", 1)
	set("debuffs.sunder", true)
	assert(groups.debuffs.maxFrameCount + groups.sunder.maxFrameCount == 1, "one tile holds Sunder Armor alone")
	set("debuffs.sunder", false)
	env.UnitClass = nil
	set("debuffs.sunder", true)
	assert(not ns.Settings.Row("debuffs.sunder").showWhen(), "without UnitClass the switch hides")
	clean(env, K)
end
collectgarbage()

-- Findings 6 and 7: Debuffs in front off drops both rows back; a refused aura group is not rebuilt on every refresh.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	set("buffs.enabled", true)
	set("ccs.enabled", true)
	set("debuffs.raise", true)
	set("debuffs.raise", false)
	local level = plate:GetFrameLevel() + 1
	assert(plate.kinds.buffs:GetFrameLevel() == level and plate.kinds.ccs:GetFrameLevel() == level, "both rows back behind")
	clean(env, K)
	local env2, K2, ns2, set2 = boot({ nameplate1 = {} })
	local plate2, create, made = ns2.Plates.Get("nameplate1"), env2.CreateFrame, 0
	env2.CreateFrame = function(kind, ...)
		local frame = create(kind, ...)
		if kind == "AuraContainer" then
			made = made + 1
			frame.AddAuraGroup = function() error("refused group") end
		end
		return frame
	end
	set2("buffs.enabled", true)
	local before = made
	for _ = 1, 5 do plate2:Refresh() end
	assert(made == before, "no new container per refresh")
	env2.CreateFrame = create
	clean(env2, K2)
end
collectgarbage()

-- Finding 8: a spell target on its own shows wherever the spell name is hidden, and stops short of the time left.
do
	local env, K, ns, set = boot({ nameplate1 = { spellTarget = "Thaldrin" } })
	local plate = ns.Plates.Get("nameplate1")
	set("cast.showTarget", true)
	set("cast.targetPlace", "RIGHT")
	set("cast.nameBelow", false)
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", texture = 1 })
	assert(not plate.castName:IsShown() and plate.castTarget:IsShown() and env.Reveal(plate.castTarget:GetText()) == "Thaldrin",
		"an unselected caster's hidden name leaves the target on its own")
	N.Target(env, "nameplate1")
	assert(plate.castName:IsShown() and not plate.castTarget:IsShown() and shown(env, plate.castName):find("Thaldrin", 1, true), "selected, the name carries it")
	local row = ns.Settings.Row("cast.showTarget")
	assert(not (row.disableWhen and row.disableWhen({ cast = { showName = false, enabled = true } })), "the target switch works without the spell name")
	set("cast.nameBelow", true)
	set("cast.showTime", true)
	for _, place in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
		set("cast.targetPlace", place)
		local text, clear = plate.castTarget, false
		for i = 1, text:GetNumPoints() do
			local p, rel = text:GetPoint(i)
			clear = clear or p == "RIGHT" and rel == plate.castTime
		end
		assert(text:GetNumPoints() == 2 and clear, place .. ": the target stops short of the time left")
	end
	clean(env, K)
end
collectgarbage()

-- Finding 9: the preview shows the distance on the sample it picks, every buff icon asked for, and each buff filter's own buffs.
do
	local env, K, ns, set = boot({})
	local frame = ns.Preview.Build(env.UIParent)
	set("name.afk", true)
	set("target.distance", true)
	frame.Refresh()
	assert(frame.plates[frame.chosen].distanceText:IsShown(), "AFK tags and the distance together")
	set("name.afk", false)
	set("target.distance", false)
	set("buffs.enabled", true)
	set("buffs.count", 8)
	frame.Refresh()
	local icons = frame.plates[frame.chosen].sampleKinds.buffs.icons
	local n = 0
	for _, icon in ipairs(icons) do if icon:IsShown() then n = n + 1 end end
	assert(n == 8, "eight buff icons preview eight")
	local seen = {}
	for _, filter in ipairs({ "important", "dispellable", "all" }) do
		set("buffs.filter", filter)
		frame.Refresh()
		local textures = {}
		for i = 1, 8 do textures[i] = N.Last(icons[i].tile.icon, "SetTexture")[1] end
		local key = table.concat(textures, ",")
		assert(not seen[key], filter .. " previews its own buffs")
		seen[key] = true
	end
	clean(env, K)
end
collectgarbage()

-- Finding 10: a tooltip line not followed by the level line is no NPC title.
do
	local env, K, ns, set = boot({ nameplate1 = { canAttack = false, reaction = 5 } })
	local npc = ns.Plates.Get("nameplate1")
	env.C_TooltipInfo.GetUnit = function() return { lines = { { type = 2, leftText = "Hale" }, { type = 0, leftText = "Unrelated note" } } } end
	set("friendly.npcTitle", true)
	assert(not (npc.subtitle and npc.subtitle:IsShown()), "an unrelated note stays off the plate")
	clean(env, K)
end
collectgarbage()

print("test-nameplates-parity-r4: ok")
