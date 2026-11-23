-- test-groupframes-parity-r1.lua: EllesmereUI parity round 1: v0.2.8 profiles keep every default; each new group frame option switched on applies, follows its events, reaches the preview and switches back. test-groupframes-parity-r1-frames.lua passes "frames" to check the same on Frames, with its portrait zoom, icon zoom and tooltip switches.
local isFrames = ... == "frames"
local G = dofile("Tools/regression/group_env.lua")
if isFrames then dofile("Tools/regression/groupframes_frames.lua")(G) end
local A = dofile("Tools/regression/auras_env.lua")

local MODULE = "GroupFrames"

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

local function setup(env)
	env.UnitAffectingCombat = function(unit)
		return unit == "player" and env._fighting == true
	end
	env.C_InstanceEncounter = { IsEncounterInProgress = function() return env._boss == true end }
	env.DifficultyUtil = { ID = { PrimaryRaidMythic = 16 } }
	env.GetInstanceInfo = function() return "Raid", "raid", env._difficulty or 0 end
	local setCombat = env.SetCombat
	env.SetCombat = function(on)
		env._fighting = on
		return setCombat(on)
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

local function near(a, b)
	return math.abs(a - b) < 1e-3
end

local function barColor(env, f)
	local c = f.health.colorRGBA
	local function plain(v)
		return env.issecretvalue(v) and env.Reveal(v) or v
	end
	return plain(c[1]), plain(c[2]), plain(c[3]), plain(c[4])
end

local function colorIs(env, f, want, what)
	local r, g, b = barColor(env, f)
	assert(near(r, want.r) and near(g, want.g) and near(b, want.b), what .. ": got " .. r .. ", " .. g .. ", " .. b)
end

local function motion(button)
	local call = A.W.LastCall(button, "SetMouseMotionEnabled")
	return call and call[1]
end

local function roleShown(f)
	return f.role:IsShown() or f.pipFill:IsShown()
end

local function party(env)
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", leader = true, health = 50, maxHealth = 100 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 80, maxHealth = 100 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 90, maxHealth = 100 },
	})
end

local function noErrors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A v0.2.8-shaped profile keeps every default and today's look.
do
	local env, K, ns = G.New({ saved = saved({ party = { width = 259 }, auras = { enabled = true } }), setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local get = ns.Settings.Get
	for _, key in ipairs({ "icons.roleTank", "icons.roleHealer", "icons.roleDamager", "icons.roleInCombat", "icons.leaderInCombat",
		"power.tanks", "power.healers", "power.damagers", "accent.hover", "accent.target", "auras.magic", "auras.curse",
		"auras.poison", "auras.disease", "auras.bleed", "groups.show1", "groups.show8", "auras.tooltips", "buffs.tooltips",
		"health.statusGrey", "auras.lasting", "groups.mythicBench" }) do
		assert(get(key) == true, key .. " starts on")
	end
	assert(get("health.colorSource") == "class" and get("health.alpha") == 1 and get("tooltip.mode") == "ALWAYS"
		and get("auras.dispelAlpha") == 0.16 and get("auras.dispelLines") == 2 and get("party.portraitZoom") == 0
		and get("auras.zoom") == 0.07 and get("prediction.shieldLines") == 2, "the other defaults hold")
	local tank = frame(ns, "party1")
	assert(roleShown(tank) and tank.showPower and tank.leader:IsShown(), "role, power and leader show as before")
	local debuffs = tank.auras._groups.debuffs.candidateFilters
	assert(debuffs.excludeDispelTypes == nil and debuffs.maxDuration == nil, "no debuff type is left out by default")
	local _, _, _, alpha = barColor(env, tank)
	assert(alpha == 1, "the fill stays solid")
	noErrors(env, K)
end
collectgarbage()

-- Status icons: role icons by role and in combat, leader icons in combat.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local tank, healer = frame(ns, "party1"), frame(ns, "party2")
	write(env, K, "icons.roleTank", false)
	assert(not roleShown(tank) and roleShown(healer), "tanks lose their role icon, healers keep theirs")
	env._roster.units.party1.role = "HEALER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(roleShown(tank), "a role change refreshes the icon")
	env._roster.units.party1.role = "TANK"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(not roleShown(tank), "and back")
	write(env, K, "icons.roleTank", true)
	assert(roleShown(tank), "turning it on restores the icon")
	write(env, K, "icons.roleInCombat", false)
	write(env, K, "icons.leaderInCombat", false)
	assert(roleShown(tank) and tank.leader:IsShown(), "out of combat both show")
	env.SetCombat(true)
	assert(not roleShown(tank) and not roleShown(healer) and not tank.leader:IsShown(), "combat start hides role and leader icons")
	env.SetCombat(false)
	assert(roleShown(tank) and tank.leader:IsShown(), "combat end shows them again")
	write(env, K, "icons.roleInCombat", true)
	env.SetCombat(true)
	assert(roleShown(tank) and not tank.leader:IsShown(), "each switch works alone")
	env.SetCombat(false)
	noErrors(env, K)
end
collectgarbage()

-- Health bar: by-health colour with thresholds, fill opacity, dead and offline colours.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	local h = ns.Settings.defaults.health
	write(env, K, "health.colorSource", "gradient")
	colorIs(env, f, h.gradientMid, "half health takes the half health colour")
	assert(f.health.lowFill:GetAlpha() == 0, "the low health overlay stays off under the by-health colour")
	env._roster.units.party1.health = 100
	env.FireEvent("UNIT_HEALTH", "party1")
	colorIs(env, f, h.gradientHigh, "full health takes the full health colour on UNIT_HEALTH")
	env._roster.units.party1.health = 25
	env.FireEvent("UNIT_HEALTH", "party1")
	local low, mid = h.gradientLow, h.gradientMid
	colorIs(env, f, { r = (low.r + mid.r) / 2, g = (low.g + mid.g) / 2, b = (low.b + mid.b) / 2 }, "a quarter blends low and half")
	write(env, K, "health.gradientLowAt", 20)
	env._roster.units.party1.health = 15
	env.FireEvent("UNIT_HEALTH", "party1")
	colorIs(env, f, low, "below the low threshold the low colour holds")
	write(env, K, "health.gradientHighAt", 80)
	env._roster.units.party1.health = 85
	env.FireEvent("UNIT_HEALTH", "party1")
	colorIs(env, f, h.gradientHigh, "above the high threshold the full colour holds")
	write(env, K, "health.gradientHigh", { r = 0, g = 0, b = 1 })
	colorIs(env, f, { r = 0, g = 0, b = 1 }, "a new colour rebuilds the curves")
	write(env, K, "health.alpha", 0.5)
	local _, _, _, alpha = barColor(env, f)
	assert(alpha == 0.5, "fill opacity reaches the bar")
	f.health:Restyle()
	_, _, _, alpha = barColor(env, f)
	assert(alpha == 0.5 and f.health.colorRGBA.n == 4, "a restyle keeps the opacity")
	write(env, K, "health.colorSource", "class")
	local cr, cg, cb = K.Theme.ClassColor("WARRIOR")
	colorIs(env, f, { r = cr, g = cg, b = cb }, "class colour returns")
	_, _, _, alpha = barColor(env, f)
	assert(alpha == 0.5, "opacity holds for every colour source")
	write(env, K, "health.alpha", 1)

	env._roster.units.party2.dead = true
	env.FireEvent("UNIT_HEALTH", "party2")
	local dead = frame(ns, "party2")
	local dr, dg, db = K.Tokens.Color("textDisabled")
	colorIs(env, dead, { r = dr, g = dg, b = db }, "dead members keep the disabled grey by default")
	write(env, K, "health.statusGrey", false)
	write(env, K, "health.deadColor", { r = 0.5, g = 0, b = 0 })
	colorIs(env, dead, { r = 0.5, g = 0, b = 0 }, "the dead colour applies")
	env._roster.units.party3.online = false
	env.FireEvent("UNIT_CONNECTION", "party3")
	write(env, K, "health.offlineColor", { r = 0, g = 0, b = 0.5 })
	colorIs(env, frame(ns, "party3"), { r = 0, g = 0, b = 0.5 }, "the offline colour applies")
	write(env, K, "health.statusGrey", true)
	colorIs(env, dead, { r = dr, g = dg, b = db }, "off restores the grey")
	noErrors(env, K)
end
collectgarbage()

-- Power bar by role, highlights, tooltips and portrait zoom.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local tank, healer = frame(ns, "party1"), frame(ns, "party2")
	local tall = tank.parts.health.height
	write(env, K, "power.tanks", false)
	if isFrames then
		assert(not tank.showPower and not tank.power:IsShown() and tank.parts.health.height > tall, "tanks lose the power bar and their health bar takes the room")
	else
		assert(not tank.showPower and not tank.power:IsShown() and tank.parts.health.height == tall, "tanks lose the power bar and the Medallions pill keeps its height")
	end
	assert(healer.showPower and healer.power:IsShown(), "healers keep it")
	env._roster.units.party1.role = "DAMAGER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(tank.showPower and tank.power:IsShown() and tank.parts.health.height == tall, "a role change brings it back")
	env._roster.units.party1.role = "TANK"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(not tank.showPower, "and takes it away again")
	write(env, K, "power.tanks", true)
	assert(tank.showPower and tank.parts.health.height == tall, "on restores the power bar")

	local lines = 0
	rawset(env.GameTooltip, "SetUnit", function() lines = lines + 1 end)
	local button = tank.owner
	local function hover()
		lines = 0
		button:GetScript("OnEnter")(button)
		button:GetScript("OnLeave")(button)
		return lines
	end
	assert(hover() == 1, "the member tooltip shows by default")
	write(env, K, "tooltip.mode", "NEVER")
	assert(hover() == 0, "never hides it")
	write(env, K, "tooltip.mode", "COMBAT")
	assert(hover() == 1, "out of combat it shows")
	env._fighting = true
	assert(hover() == 0, "in combat it hides")
	env._fighting = false
	write(env, K, "tooltip.mode", "BOSS")
	env._boss = true
	assert(hover() == 0, "during a boss fight it hides")
	env._boss = false
	assert(hover() == 1, "after the fight it shows")
	write(env, K, "tooltip.mode", "ALWAYS")

	button:GetScript("OnEnter")(button)
	assert(tank.hovered, "the hover highlight lights by default")
	write(env, K, "accent.hover", false)
	assert(not tank.hovered and (tank.hoverT or 0) == 0, "turning it off clears a lit edge at once")
	button:GetScript("OnEnter")(button)
	assert(not tank.hovered, "and pointing no longer lights it")
	button:GetScript("OnLeave")(button)
	write(env, K, "accent.hover", true)

	env._roster.units.target = env._roster.units.party1
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(tank.target:GetAlpha() == 1, "the target ring shows")
	write(env, K, "accent.target", false)
	assert(tank.target:GetAlpha() == 0, "off hides the target ring")
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(tank.target:GetAlpha() == 0, "and keeps it hidden on a target change")
	write(env, K, "accent.target", true)
	assert(tank.target:GetAlpha() == 1, "on restores it")

	if isFrames then
		write(env, K, "party.portrait", true)
		write(env, K, "party.portraitZoom", 0.2)
		local l, r, t, b = tank.portrait:GetTexCoord()
		assert(near(l, 0.2) and near(r, 0.8) and near(t, 0.2) and near(b, 0.8), "portrait zoom crops the portrait")
		write(env, K, "party.portraitZoom", 0)
		l, r = tank.portrait:GetTexCoord()
		assert(l == 0 and r == 1, "0 shows the whole portrait")
	end
	noErrors(env, K)
end
collectgarbage()

-- Debuffs: types and lasting debuffs leave every debuff lane; the dispel highlight's tint and outline.
do
	local env, K, ns = G.New({ setup = setup })
	G.SetRoster(env, "raid", G.Members(20))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "raid1")
	local function filters(key)
		return f.auras._groups[key].candidateFilters
	end
	write(env, K, "auras.magic", false)
	write(env, K, "auras.bleed", false)
	for _, key in ipairs({ "boss", "important", "dispels", "debuffs" }) do
		local c = filters(key)
		assert(c.excludeDispelTypes and c.excludeDispelTypes.Magic and c.excludeDispelTypes.Bleed and not c.excludeDispelTypes.Curse, key .. " leaves out Magic and Bleed")
	end
	assert(f.highlights._slots.boss.candidateFilters.excludeDispelTypes.Magic, "so does the boss slot")
	assert(f.highlights._slots.dispel.candidateFilters == nil, "the dispel highlight stays independent")
	write(env, K, "auras.lasting", false)
	assert(filters("debuffs").maxDuration == math.huge, "only debuffs that expire")
	write(env, K, "auras.magic", true)
	write(env, K, "auras.bleed", true)
	write(env, K, "auras.lasting", true)
	assert(filters("debuffs").excludeDispelTypes == nil and filters("debuffs").maxDuration == nil, "switching back clears the filters")

	local slot = f.dispelFrame
	local function registered(piece)
		for _, entry in ipairs(slot._aura.dispel) do
			if entry.texture == piece then return true end
		end
		return false
	end
	local function centres()
		return registered(f.dispelRing[1][5]) or registered(f.dispelRing[2][5])
	end
	local HOLLOW = "the engine shows every dispel texture it holds; give it only a ring line's eight edge pieces, never the transparent centre"
	assert(registered(f.dispelRing[2][1]) and f.dispelWash[1]:GetAlpha() == 0.16, "two outline lines and the usual tint")
	assert(registered(f.dispelWash[5]) and not centres(), HOLLOW)
	write(env, K, "auras.dispelAlpha", 0.3)
	assert(f.dispelWash[1]:GetAlpha() == 0.3, "the tint opacity applies")
	-- Blizzard_CustomAuraButton.lua's ApplyDispelTypeTexture ends on the option's colour map, else the game's colour, with alpha.
	for _, entry in ipairs(slot._aura.dispel) do
		local map = entry.options.customDispelColorMap
		entry.texture:SetVertexColor((map and map.Magic or env.DEBUFF_TYPE_MAGIC_COLOR):GetRGBA())
	end
	assert(near(f.dispelWash[1]:GetAlpha(), 0.3) and f.dispelRing[1][1]:GetAlpha() == 1, "the engine's dispel colour keeps the tint see-through and the outline solid")
	write(env, K, "auras.dispelLines", 1)
	assert(registered(f.dispelRing[1][1]) and not registered(f.dispelRing[2][1]) and not f.dispelRing[2][1]:IsShown(), "one line leaves the inner line out")
	write(env, K, "auras.dispelLines", 0)
	assert(not registered(f.dispelRing[1][1]), "none leaves the tint alone")
	write(env, K, "auras.dispelLines", 2)
	assert(registered(f.dispelRing[1][1]) and registered(f.dispelRing[2][1]), "two restores both lines")
	assert(not centres(), HOLLOW)
	A.Assign(env, f.auras, "debuffs", 1)
	env.RunTimers()
	local debuff = f.auras._groups.debuffs.active[1]
	local p = ns.Auras.Parts(debuff)
	local l = p.icon:GetTexCoord()
	assert(near(l, 0.07) and motion(debuff) == nil, "icons keep the 7% crop and their tooltips, with no new call")
	if isFrames then
		write(env, K, "auras.zoom", 0.15)
		l = p.icon:GetTexCoord()
		assert(near(l, 0.15), "icon zoom crops further")
		write(env, K, "auras.tooltips", false)
		assert(motion(debuff) == false, "debuff tooltips off stops the pointer reaching the icon")
	end
	local heal = f.buffs and f.buffs._groups.buffs.frames[1]
	assert(heal and motion(heal) == nil, "heal icons keep their tooltips")
	if isFrames then
		write(env, K, "buffs.tooltips", false)
		assert(motion(heal) == false, "heal icon tooltips switch alone")
		write(env, K, "auras.tooltips", true)
		write(env, K, "buffs.tooltips", true)
		write(env, K, "auras.zoom", 0.07)
		assert(motion(debuff) == true and motion(heal) == true and near(p.icon:GetTexCoord(), 0.07), "switching back restores both")
	end
	local line = f.shield.opts.height
	write(env, K, "prediction.shieldLines", 4)
	assert(near(f.shield.opts.height, line * 2), "the shield line doubles from two pixels to four")
	write(env, K, "prediction.shieldLines", 2)
	assert(near(f.shield.opts.height, line), "two restores it")

	env._aurasSecret = true
	K.Options.Write(MODULE, "auras.dispelAlpha", 0.1)
	assert(f.dispelWash[1]:GetAlpha() == 0.3, "while auras are secret the highlight waits")
	env._aurasSecret = false
	env.RunTimers()
	assert(f.dispelWash[1]:GetAlpha() == 0.1, "and applies when they are readable")
	noErrors(env, K)
end
collectgarbage()

-- Raid groups: groups shown close up; Mythic raids hide groups 5 to 8 on their events.
do
	local env, K, ns = G.New({ setup = setup })
	G.SetRoster(env, "raid", G.Members(30))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local headers = ns.Headers.raid
	local card = ns.Headers.cards.raid.frame
	local wide = card:GetWidth()
	write(env, K, "groups.show2", false)
	assert(headers[2]:GetAttribute("groupFilter") == "3" and G.Shown(headers[2])[1] == "raid11", "group 3 takes group 2's place")
	assert(not headers[8]:IsShown(), "the last header has no group left")
	local shown = 0
	for _, header in ipairs(headers) do shown = shown + (header:IsShown() and #G.Shown(header) or 0) end
	assert(shown == 25, "the other five groups show: " .. shown)
	assert(card:GetWidth() < wide, "the card hugs the groups that show")
	write(env, K, "raid.sortBy", "ROLE")
	assert(headers[1]:GetAttribute("groupFilter") == "1,3,4,5,6,7,8", "role order skips the hidden group")
	write(env, K, "raid.sortBy", "GROUP")
	write(env, K, "groups.show2", true)
	assert(headers[2]:GetAttribute("groupFilter") == "2" and #G.Shown(headers[6]) == 5, "showing it again restores every group")

	write(env, K, "groups.mythicBench", false)
	assert(ns.Settings.current.groups.show5 == true and #G.Shown(headers[5]) == 5, "outside Mythic group 5 shows")
	env._difficulty = 16
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	env.RunTimers()
	assert(ns.Settings.current.groups.show5 == false and not headers[5]:IsShown() and not headers[6]:IsShown(), "a Mythic raid hides groups 5 to 8")
	assert(#G.Shown(headers[1]) == 5, "groups 1 to 4 stay")
	env.SetCombat(true)
	env._difficulty = 15
	env.FireEvent("PLAYER_DIFFICULTY_CHANGED")
	assert(not headers[5]:IsShown(), "in combat the change waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(headers[5]:IsShown() and #G.Shown(headers[5]) == 5, "and applies when combat ends")
	noErrors(env, K)
end
collectgarbage()

-- The preview follows the new options.
do
	local env, K, ns = G.New({ setup = setup })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview(MODULE)(parent)
	local tank = preview.partyFrames[1]
	assert(tank.sample.role == "TANK" and roleShown(tank) and tank.showPower, "the sample tank shows its role and power")
	local debuffs = #tank.sampleAuras
	local function shownDebuffs()
		local n = 0
		for _, icon in ipairs(tank.sampleAuras) do if icon:IsShown() then n = n + 1 end end
		return n
	end
	local before = shownDebuffs()
	assert(debuffs > 0 and before == 2, "the sample tank carries two debuffs")
	write(env, K, "icons.roleTank", false)
	write(env, K, "power.tanks", false)
	write(env, K, "health.colorSource", "gradient")
	write(env, K, "auras.magic", false)
	write(env, K, "accent.target", false)
	write(env, K, "auras.dispelAlpha", 0.4)
	preview:Refresh()
	assert(not roleShown(tank) and not tank.showPower, "the preview drops the tank's role icon and power bar")
	assert(shownDebuffs() == before - 1, "and the Magic sample debuff")
	local h, t = ns.Settings.defaults.health, (tank.sample.health - 0.5) / 0.5
	local mid, high = h.gradientMid, h.gradientHigh
	colorIs(env, tank, { r = mid.r + (high.r - mid.r) * t, g = mid.g + (high.g - mid.g) * t, b = mid.b + (high.b - mid.b) * t },
		"the sample bar takes its by-health colour")
	local kragar = preview.partyFrames[3]
	assert(kragar.target:GetAlpha() == 0, "the sample target ring follows the switch")
	noErrors(env, K)
end

print("groupframes parity round 1 ok: defaults, role and leader icons, health colours, power by role, tooltips, highlights, portrait zoom, debuff types, dispel highlight, raid groups and the preview")
