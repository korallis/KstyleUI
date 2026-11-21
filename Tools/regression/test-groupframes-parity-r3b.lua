-- test-groupframes-parity-r3b.lua: EllesmereUI parity round 3b: v0.2.8 profiles keep every default and build nothing new; debuff offsets, text above icons, aura tooltips in combat, important debuffs, icon text outline, indicator Show on and party targets each apply when on, follow their events and combat, reach the preview and switch back exactly.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local MODULE = "GroupFrames"

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

local function setup(env)
	env._units = env._units or {}
	env.UnitIsPlayer = function(unit)
		local m = env._member(unit)
		return m ~= nil and m.player == true
	end
end

local function write(env, K, key, value)
	K.Options.Write(MODULE, key, value)
	env.RunTimers()
end

local function frame(ns, unit)
	local out
	ns.Unit.ForEach(function(f) if f.unit == unit then out = f end end)
	return assert(out, "no frame for " .. unit)
end

local function party(env)
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 50, maxHealth = 100 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 80, maxHealth = 100 },
	})
end

local function noErrors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function point(region)
	local p, rel, relPoint, x, y = region:GetPoint(1)
	return table.concat({ tostring(p), tostring(rel), tostring(relPoint), tostring(x), tostring(y) }, " ")
end

local function near(a, b)
	return math.abs(a - b) < 1e-3
end

local function plain(env, v)
	return env.issecretvalue(v) and env.Reveal(v) or v
end

local function barColor(env, bar)
	local c = bar.colorRGBA
	return plain(env, c[1]), plain(env, c[2]), plain(env, c[3])
end

-- A v0.2.8-shaped profile keeps every default and builds nothing new.
do
	local env, K, ns = G.New({ saved = saved({ party = { width = 259 }, auras = { enabled = true } }), setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local get = ns.Settings.Get
	assert(get("party.auraX") == 0 and get("party.auraY") == 0 and get("raid.auraX") == 0 and get("raid.auraY") == 0, "debuffs stay where they were")
	assert(get("text.above") == false and get("auras.tipCombat") == true and get("indicator1.show") == "BOTH", "text, tooltips and indicators keep today's behaviour")
	assert(get("auras.filter") == "ALL" and get("auras.textOutline") == "OUTLINE", "debuffs keep every kind and the thin icon text outline")
	assert(get("targets.enabled") == false and get("targets.self") == false and get("targets.nameColor") == "text", "party targets start off, with names in the text colour")
	local f = frame(ns, "party1")
	assert(f.partyTarget == nil and f.owner:GetAttribute("frameref-kstyle-target") == nil and f.owner._wrapped == nil, "no target button, frame ref or wrap is made")
	assert(f.text:GetFrameLevel() == f:GetFrameLevel() + 4, "names keep their level under the icons")
	assert(env.LiveTickers() == 0, "no timer runs")
	noErrors(env, K)
end
collectgarbage()

-- Debuff offsets move party and raid debuffs on their own; zero restores the same anchor.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	local before, chipBefore = point(f.auraClip), point(f.debuffChip.window)
	local _, _, _, x0, y0 = f.auraClip:GetPoint(1)
	local _, _, _, cx0, cy0 = f.debuffChip.window:GetPoint(1)
	write(env, K, "party.auraX", 12)
	write(env, K, "party.auraY", -6)
	local _, _, _, x1, y1 = f.auraClip:GetPoint(1)
	assert(near(x1 - x0, 12) and near(y1 - y0, -6), "the debuffs move 12 across and 6 down: " .. (x1 - x0) .. ", " .. (y1 - y0))
	local _, _, _, cx1, cy1 = f.debuffChip.window:GetPoint(1)
	assert(near(cx1 - cx0, 12) and near(cy1 - cy0, -6), "the +N chip moves with them")
	write(env, K, "party.auraX", 0)
	write(env, K, "party.auraY", 0)
	assert(point(f.auraClip) == before and point(f.debuffChip.window) == chipBefore, "zero restores both anchors exactly")
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	local r = frame(ns, "raid1")
	local raidBefore = point(r.auraClip)
	write(env, K, "party.auraX", 20)
	assert(point(r.auraClip) == raidBefore, "a party offset leaves raid debuffs alone")
	write(env, K, "raid.auraY", 4)
	local _, _, _, _, ry = r.auraClip:GetPoint(1)
	write(env, K, "raid.auraY", 0)
	local _, _, _, _, ry0 = r.auraClip:GetPoint(1)
	assert(near(ry - ry0, 4) and point(r.auraClip) == raidBefore, "the raid offset moves raid debuffs up, and zero restores them")
	noErrors(env, K)
end
collectgarbage()

-- Text above icons raises names over debuffs and indicators, after combat if switched in it, and off restores the level.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	local level = f.text:GetFrameLevel()
	write(env, K, "text.above", true)
	assert(f.text:GetFrameLevel() > f.auras:GetFrameLevel() + 16, "names sit over the debuff icons and their counts")
	assert(not f.indicators or f.text:GetFrameLevel() > f.indicators:GetFrameLevel() + 16, "and over the indicators")
	write(env, K, "text.above", false)
	assert(f.text:GetFrameLevel() == level, "off restores the level")
	env.SetCombat(true)
	write(env, K, "text.above", true)
	env.SetCombat(false)
	env.RunTimers()
	assert(f.text:GetFrameLevel() > level and #env._blocked == 0, "switched on in combat, it applies when combat ends")
	write(env, K, "text.above", false)
	noErrors(env, K)
end
collectgarbage()

-- Aura tooltips in combat reach debuff and heal icons through the engine's own switch.
do
	local env, K, ns = G.New({ setup = setup })
	G.SetRoster(env, "raid", G.Members(10))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "raid1")
	A.Assign(env, f.auras, "debuffs", 1)
	env.RunTimers()
	local debuff = f.auras._groups.debuffs.active[1]
	assert(debuff._aura.hideTooltipInCombat == nil, "no call by default")
	write(env, K, "auras.tipCombat", false)
	assert(debuff._aura.hideTooltipInCombat == true, "off hides debuff tooltips in combat")
	local heal = f.buffs and f.buffs._groups.buffs.frames[1]
	assert(heal and heal._aura.hideTooltipInCombat == true, "and heal icon tooltips")
	write(env, K, "auras.tooltips", false)
	assert(debuff._aura.hideTooltipInCombat == true, "it does not depend on Debuff tooltips")
	write(env, K, "auras.tooltips", true)
	write(env, K, "auras.tipCombat", true)
	assert(debuff._aura.hideTooltipInCombat == false and heal._aura.hideTooltipInCombat == false, "on restores the engine's default")
	noErrors(env, K)
end
collectgarbage()

-- Important debuffs narrow every debuff lane and the boss slot; Icon text outline restyles counts and timers.
do
	local env, K, ns = G.New({ setup = setup })
	G.SetRoster(env, "raid", G.Members(10))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "raid1")
	write(env, K, "auras.filter", "IMPORTANT")
	for _, key in ipairs({ "boss", "important", "dispels", "debuffs" }) do
		assert(f.auras._groups[key].candidateFilters.isPriorityAura == true, key .. " shows only important debuffs")
	end
	assert(f.highlights._slots.boss.candidateFilters.isPriorityAura == true, "so does the boss slot")
	write(env, K, "auras.filter", "ALL")
	assert(f.auras._groups.debuffs.candidateFilters.isPriorityAura == false and f.highlights._slots.boss.candidateFilters.isPriorityAura == nil, "All debuffs restores the lanes")
	write(env, K, "auras.timers", true)
	A.Assign(env, f.auras, "debuffs", 1)
	env.RunTimers()
	local p = ns.Auras.Parts(f.auras._groups.debuffs.active[1])
	local function flags(region) return select(3, region:GetFont()) end
	assert(flags(p.count) == "OUTLINE" and flags(p.timer) == "OUTLINE", "counts and timers keep the thin outline by default")
	write(env, K, "auras.textOutline", "THICKOUTLINE")
	assert(flags(p.count) == "THICKOUTLINE" and flags(p.timer) == "THICKOUTLINE", "a thick outline reaches both")
	write(env, K, "auras.textOutline", "NONE")
	assert(flags(p.count) == "" and flags(p.timer) == "", "a soft shadow drops the outline")
	write(env, K, "auras.textOutline", "OUTLINE")
	assert(flags(p.count) == "OUTLINE", "and back")
	noErrors(env, K)
end
collectgarbage()

-- Indicator Show on keeps a slot to party or raid frames; Both restores it everywhere.
do
	local env, K, ns = G.New({ setup = setup })
	G.SetRoster(env, "raid", G.Members(10))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local r = frame(ns, "raid1")
	local slot = r.indicators._slots.indicator1
	assert(slot.enabled, "indicator 1 shows on raid frames by default")
	write(env, K, "indicator1.show", "PARTY")
	assert(not slot.enabled and ns.Slots.Misfit("raid", 1) == false, "Party frames leaves it off raid frames, with no misfit note")
	write(env, K, "indicator1.show", "RAID")
	assert(slot.enabled, "Raid frames keeps it on raid frames")
	party(env)
	env.RunTimers()
	local p = frame(ns, "party1")
	assert(p.indicators == nil or not p.indicators._slots.indicator1.enabled, "and off party frames")
	write(env, K, "indicator1.show", "BOTH")
	assert(p.indicators._slots.indicator1.enabled, "Both restores it on party frames")
	noErrors(env, K)
end
collectgarbage()

-- Party targets: built out of combat, beside each member, following the target, combat and the switch.
do
	local env, K, ns = G.New({ setup = setup })
	env._units.party1target = { name = "Gorvak", class = "WARRIOR", reaction = 2, health = 30, maxHealth = 60 }
	env._units.party2target = { name = "Thaldren", class = "WARRIOR", player = true, health = 50, maxHealth = 100 }
	env._units.playertarget = { name = "Gorvak", class = "WARRIOR", reaction = 2, health = 30, maxHealth = 60 }
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local one, two, me = frame(ns, "party1"), frame(ns, "party2"), frame(ns, "player")
	env.SetCombat(true)
	write(env, K, "targets.enabled", true)
	assert(one.partyTarget == nil, "switched on in combat, nothing is built until combat ends")
	env.SetCombat(false)
	env.RunTimers()
	local t, t2, mine = one.partyTarget, two.partyTarget, me.partyTarget
	assert(t and t2 and mine, "combat's end builds a target button for each party frame")
	assert(t:GetParent() == one.owner and t._attributes["useparent-unit"] == true and t._attributes.unitsuffix == "target", "a secure child that acts on its member's target")
	env.RunStateDrivers()
	assert(t:IsShown() and t2:IsShown(), "a member with a target shows it")
	assert(not mine:IsShown() and mine._attributes["useparent-unit"] == false, "your own target stays off")
	assert(t.name:GetText() == "Gorvak" and t2.name:GetText() == "Thaldren", "names follow each target")
	local hr, hg, hb = K.ColorVision.ReactionColor(2)
	local r, g, b = barColor(env, t.health)
	assert(near(r, hr) and near(g, hg) and near(b, hb), "an enemy target takes the reaction colour")
	local cr, cg, cb = K.Theme.ClassColor("WARRIOR")
	r, g, b = barColor(env, t2.health)
	assert(near(r, cr) and near(g, cg) and near(b, cb), "a player target takes the class colour")
	local tr, tg, tb = t.name:GetTextColor()
	local er, eg, eb = K.Tokens.Color("textEmphasis")
	assert(near(tr, er) and near(tg, eg) and near(tb, eb), "names take the text colour by default")
	write(env, K, "targets.nameColor", "class")
	tr, tg, tb = t.name:GetTextColor()
	assert(near(tr, er) and near(tg, eg) and near(tb, eb), "an enemy's name keeps the text colour under Class colour")
	assert(env.Reveal(t.health:GetValue()) == 30, "the health bar reads the target's health")
	local _, rel, _, x, y = t:GetPoint(1)
	local geo = ns.Geometry.Party(ns.Settings.current.party)
	assert(rel == one.owner and x > geo.memberWidth and y == 0, "it sits beside the frame, past the debuffs")
	assert(near(t:GetWidth(), 96) and near(t:GetHeight(), 24), "at the default size")
	assert(env.LiveTickers() == 1, "one timer reads health while a target shows")

	env._units.party1target.health = 12
	env.RunTickers()
	assert(env.Reveal(t.health:GetValue()) == 12, "the timer follows health")
	env._units.party1target.reaction = 5
	env.RunTickers()
	r = barColor(env, t.health)
	local fr = K.ColorVision.ReactionColor(5)
	assert(near(r, fr), "a reaction change repaints the colour")
	env._units.party1target = { name = "Mira", class = "MAGE", player = true, health = 40, maxHealth = 40 }
	env.FireEvent("UNIT_TARGET", "party1")
	assert(t.name:GetText() == "Mira", "UNIT_TARGET repaints the name")
	tr, tg, tb = t.name:GetTextColor()
	local nr, ng, nb = ns.Unit.NameColor("MAGE")
	assert(near(tr, nr) and near(tg, ng) and near(tb, nb), "a player's name takes the class colour")

	write(env, K, "targets.nameColor", "custom")
	write(env, K, "targets.color", { r = 0.2, g = 0.4, b = 0.6 })
	tr, tg, tb = t.name:GetTextColor()
	assert(near(tr, 0.2) and near(tg, 0.4) and near(tb, 0.6), "a custom name colour applies")
	write(env, K, "targets.nameColor", "text")
	tr = t.name:GetTextColor()
	assert(near(tr, er), "the text colour applies")
	write(env, K, "targets.nameColor", "class")

	write(env, K, "targets.width", 120)
	write(env, K, "targets.height", 30)
	write(env, K, "targets.x", 10)
	write(env, K, "targets.y", -4)
	local _, _, _, x2, y2 = t:GetPoint(1)
	assert(near(t:GetWidth(), 120) and near(t:GetHeight(), 30) and near(x2 - x, 10) and near(y2, -4), "size and offsets apply")

	write(env, K, "targets.self", true)
	env.RunStateDrivers()
	assert(mine._attributes["useparent-unit"] == true and mine:IsShown(), "Include your own target shows yours")
	write(env, K, "targets.self", false)
	env.RunStateDrivers()
	assert(not mine:IsShown(), "and off hides it again")

	env.SetCombat(true)
	local function header(unit)
		env._secure = true
		one.owner:SetAttribute("unit", unit)
		env._secure = false
	end
	header("player")
	assert(t._attributes["useparent-unit"] == false, "in combat, a button the header passes to you drops its target through the secure snippet")
	header("party1")
	assert(t._attributes["useparent-unit"] == true, "and takes it back for a member")
	write(env, K, "targets.width", 80)
	assert(near(t:GetWidth(), 120), "a size change waits for combat's end")
	env.SetCombat(false)
	env.RunTimers()
	assert(near(t:GetWidth(), 80), "and then applies")
	assert(#env._blocked == 0, "nothing protected is touched in combat")

	write(env, K, "targets.enabled", false)
	assert(not t:IsShown() and not env._watched[t] and one.owner._wrapped == nil, "off hides the buttons, stops the unit watch and unwraps the frame")
	env.RunTickers()
	assert(env.LiveTickers() == 0, "and the timer stops")
	env._units.party1target.name = "Later"
	env.FireEvent("UNIT_TARGET", "party1")
	assert(t.name:GetText() == "Mira", "and no event repaints a hidden button")
	write(env, K, "targets.enabled", true)
	env.RunStateDrivers()
	assert(t:IsShown() and t.name:GetText() == "Later", "on again reuses the buttons")
	noErrors(env, K)
end
collectgarbage()

-- The preview follows every new option.
do
	local env, K = G.New({ setup = setup })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview(MODULE)(parent)
	local tank = preview.partyFrames[1]
	assert(tank.sampleTarget == nil, "no sample target is built while party targets are off")
	local width = preview.party:GetWidth()
	local holder = point(tank.sampleAuraHolder)
	K.Options.Write(MODULE, "targets.enabled", true)
	K.Options.Write(MODULE, "party.auraX", 8)
	K.Options.Write(MODULE, "text.above", true)
	K.Options.Write(MODULE, "indicator1.show", "RAID")
	K.Options.Write(MODULE, "auras.filter", "IMPORTANT")
	K.Options.Write(MODULE, "auras.textOutline", "THICKOUTLINE")
	preview:Refresh()
	assert(not tank.sampleAuras[1]:IsShown() and not tank.sampleBoss:IsShown(), "no sample debuff is important")
	assert(select(3, tank.sampleAuras[1].count:GetFont()) == "THICKOUTLINE", "the sample count takes the outline")
	assert(tank.sampleTarget:IsShown() and tank.sampleTarget.name:GetText() == "Gorvak", "a sample target shows beside the tank")
	assert(preview.partyFrames[2].sampleTarget.name:GetText() == "Thaldren", "and a player target beside the healer")
	assert(preview.partyFrames[2].sampleTarget:GetEffectiveAlpha() == 1, "an out-of-range member's target keeps full opacity, as in the game")
	assert(preview.party:GetWidth() > width, "the party preview makes room for the targets")
	assert(point(tank.sampleAuraHolder) ~= holder, "the sample debuffs move")
	assert(tank.text:GetFrameLevel() > tank.sampleAuraHolder:GetFrameLevel() + 16, "sample names rise over the icons")
	assert(not tank.sampleSlots[1]:IsShown(), "an indicator kept to raid frames leaves the party samples")
	K.Options.Write(MODULE, "targets.enabled", false)
	K.Options.Write(MODULE, "party.auraX", 0)
	K.Options.Write(MODULE, "text.above", false)
	K.Options.Write(MODULE, "indicator1.show", "BOTH")
	K.Options.Write(MODULE, "auras.filter", "ALL")
	K.Options.Write(MODULE, "auras.textOutline", "OUTLINE")
	preview:Refresh()
	assert(tank.sampleAuras[1]:IsShown(), "all debuffs return to the preview")
	assert(not tank.sampleTarget:IsShown() and preview.party:GetWidth() == width and point(tank.sampleAuraHolder) == holder, "switching back restores the preview")
	assert(tank.sampleSlots[1]:IsShown(), "the indicator returns")
	noErrors(env, K)
end
collectgarbage()

print("groupframes parity round 3b ok: defaults, debuff offsets, text above icons, aura tooltips in combat, important debuffs, icon text outline, indicator Show on, party targets and the preview")
