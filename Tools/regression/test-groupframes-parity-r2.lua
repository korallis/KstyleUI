-- test-groupframes-parity-r2.lua: EllesmereUI parity round 2: a v0.2.8 profile keeps every default and makes nothing new; each new group frame option switched on applies, follows its events, reaches the preview and switches back.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local W = A.W

local MODULE = "GroupFrames"

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

local function setup(env)
	env.UnitAffectingCombat = function(unit)
		if unit == "player" then return env._fighting == true end
		return env._busy and env._busy[unit] == true
	end
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

local function party(env)
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 50, maxHealth = 100, absorb = 70, healAbsorb = 20 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 80, maxHealth = 100 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 90, maxHealth = 100 },
	})
end

local function noErrors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function value(env, bar)
	local call = W.LastCall(bar, "SetValue")
	return call and (env.issecretvalue(call[1]) and env.Reveal(call[1]) or call[1])
end

local function anchor(region)
	local point, relative, relativePoint = region:GetPoint(1)
	return point, relative, relativePoint
end

local NEW = { "combatIcon", "roleLetter", "overClip", "overshield", "healAbsorbLine", "powerLevel" }

-- A v0.2.8-shaped profile keeps every default, today's look, and makes no new region.
do
	local env, K, ns = G.New({ saved = saved({ party = { width = 259 }, auras = { enabled = true } }), setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local get = ns.Settings.Get
	for key, want in pairs({ ["auras.typeMode"] = "HIDE", ["auras.source"] = "ANY", ["auras.canApply"] = false, ["auras.timerSize"] = 0,
		["prediction.shieldPlace"] = "BOTTOM", ["prediction.shieldGrow"] = "UP", ["prediction.absorbPlace"] = "FILL",
		["prediction.overshield"] = false, ["prediction.healAbsorbLine"] = false, ["power.behind"] = false, ["power.keepRoom"] = false,
		["icons.roleText"] = false, ["icons.readyPlace"] = "AUTO", ["icons.readySize"] = 0, ["icons.markerPlace"] = "AUTO",
		["icons.combat"] = false, ["icons.combatClass"] = false, ["accent.targetLines"] = 2, ["party.portraitRingAlpha"] = 1,
		["auto.smallMost"] = 10, ["auto.largeLeast"] = 26, ["auto.shownOnly"] = false, ["groups.hideEmpty"] = false }) do
		assert(get(key) == want, key .. " keeps today's default")
	end
	ns.Unit.ForEach(function(f)
		for _, field in ipairs(NEW) do assert(f[field] == nil, field .. " is not made by default") end
		assert(#W.Calls(f.absorbs, "SetReverseFill") == 0 and #W.Calls(f.shield, "SetReverseFill") == 0, "no fill direction is set by default")
		assert(f.targetRing[2][1]:IsShown() ~= false, "the target ring keeps both lines")
	end)
	local tank = frame(ns, "party1")
	local debuffs = tank.auras._groups.debuffs
	assert(debuffs.filter == "HARMFUL" and debuffs.candidateFilters.isFromPlayerOrPlayerPet == nil and debuffs.candidateFilters.includeDispelTypes == nil,
		"debuffs keep today's filter")
	assert(anchor(tank.shield) == "BOTTOMLEFT" and select(3, anchor(tank.absorbs)) == "TOPRIGHT", "the shield line and absorbs keep their places")
	noErrors(env, K)
end
collectgarbage()

-- Debuffs: who they come from, debuffs you can apply, one kind, only the chosen types, the time left size.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	local groups = f.auras._groups
	local function every(fn)
		for _, key in ipairs({ "boss", "important", "dispels", "debuffs" }) do fn(groups[key].candidateFilters, key) end
	end
	write(env, K, "auras.source", "NPC")
	every(function(c, key) assert(c.isFromPlayerOrPlayerPet == false, key .. ": only enemies' debuffs") end)
	write(env, K, "auras.source", "PLAYERS")
	every(function(c, key) assert(c.isFromPlayerOrPlayerPet == true, key .. ": only players' debuffs") end)
	write(env, K, "auras.canApply", true)
	every(function(c, key) assert(c.canApplyAura == true and c.isFromPlayerOrPlayerPet == true, key .. ": both filters at once") end)
	write(env, K, "auras.filter", "BOSS")
	every(function(c, key) assert(c.isBossOrRoleAura == true and c.isRoleAura == false, key .. ": boss debuffs only") end)
	assert(groups.debuffs.filter == "HARMFUL", "the boss pick keeps the harmful filter string")
	write(env, K, "auras.filter", "ROLE")
	every(function(c, key) assert(c.isRoleAura == true and c.isBossOrRoleAura == nil, key .. ": role debuffs only") end)
	write(env, K, "auras.filter", "CROWD_CONTROL")
	every(function(c, key) assert(c.isRoleAura == nil, key .. ": no role filter left") end)
	assert(groups.debuffs.filter == "HARMFUL|CROWD_CONTROL", "crowd control uses the game's filter")
	write(env, K, "auras.magic", false)
	write(env, K, "auras.typeMode", "ONLY")
	every(function(c, key)
		local only = c.includeDispelTypes
		assert(only and only.Curse and only.Bleed and not only.Magic and c.excludeDispelTypes == nil, key .. ": only the types switched on")
	end)
	write(env, K, "auras.typeMode", "HIDE")
	every(function(c, key) assert(c.includeDispelTypes == nil and c.excludeDispelTypes.Magic, key .. ": back to leaving types out") end)
	for key, back in pairs({ ["auras.magic"] = true, ["auras.canApply"] = false, ["auras.source"] = "ANY", ["auras.filter"] = "ALL" }) do
		write(env, K, key, back)
	end
	every(function(c, key)
		assert(c.canApplyAura == nil and c.isFromPlayerOrPlayerPet == nil and c.excludeDispelTypes == nil and c.isRoleAura == nil, key .. ": switching back restores")
	end)
	assert(groups.debuffs.filter == "HARMFUL", "and the filter string")

	write(env, K, "auras.timers", true)
	A.Assign(env, f.auras, "debuffs", 1)
	env.RunTimers()
	local p = ns.Auras.Parts(groups.debuffs.active[1])
	local _, auto = p.timer:GetFont()
	write(env, K, "auras.timerSize", 15)
	local _, own = p.timer:GetFont()
	assert(own == 15 and auto ~= 15, "the time left takes its own size: " .. tostring(own))
	env._aurasSecret = true
	K.Options.Write(MODULE, "auras.timerSize", 9)
	assert(select(2, p.timer:GetFont()) == 15, "while auras are secret the size waits")
	env._aurasSecret = false
	env.RunTimers()
	assert(select(2, p.timer:GetFont()) == 9, "and applies when they are readable")
	write(env, K, "auras.timerSize", 0)
	assert(select(2, p.timer:GetFont()) == auto, "0 sizes it to the icon again")
	noErrors(env, K)
end
collectgarbage()

-- Heals and absorbs: absorbs from the bar's end, the overshield, the shield line's edge and growth, the heal absorb line.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	write(env, K, "prediction.absorbPlace", "END")
	local point, relative = anchor(f.absorbs)
	assert(point == "TOPRIGHT" and relative == f.health and f.absorbs:GetReverseFill() == true, "absorbs fill back from the bar's end")
	write(env, K, "health.orientation", "VERTICAL")
	point, relative = anchor(f.absorbs)
	assert(point == "TOPLEFT" and relative == f.health, "a vertical bar's absorbs hang from its top")
	write(env, K, "health.orientation", "HORIZONTAL")
	write(env, K, "prediction.absorbPlace", "FILL")
	assert(anchor(f.absorbs) == "TOPLEFT" and f.absorbs:GetReverseFill() == false, "after the health restores the fill direction")

	write(env, K, "prediction.overshield", true)
	assert(f.overshield and f.overClip:IsShown() and f.overshield:GetReverseFill() == true, "the overshield is made when switched on")
	assert(value(env, f.overshield) == 70, "it carries the whole shield")
	assert(select(2, f.overClip:GetPoint(2)) == f.health:GetStatusBarTexture(), "clipped to the health, so only the part past the missing health shows")
	env._roster.units.party1.absorb = 90
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "party1")
	assert(value(env, f.overshield) == 90, "a new shield moves it")
	write(env, K, "prediction.shield", false)
	env._roster.units.party1.absorb = 30
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "party1")
	assert(value(env, f.overshield) == 30, "the overshield does not need the shield line")
	write(env, K, "prediction.shield", true)
	write(env, K, "prediction.overshield", false)
	assert(not f.overClip:IsShown(), "off hides it")

	write(env, K, "prediction.shieldPlace", "TOP")
	assert(anchor(f.shield) == "TOPLEFT" and f.shield.opts.width > f.shield.opts.height, "the shield line runs along the top")
	write(env, K, "prediction.shieldPlace", "RIGHT")
	write(env, K, "prediction.shieldGrow", "DOWN")
	assert(anchor(f.shield) == "TOPRIGHT" and f.shield.opts.height > f.shield.opts.width and f.shield:GetReverseFill() == true, "an upright line on the right grows down")
	write(env, K, "prediction.healAbsorbLine", true)
	assert(f.healAbsorbLine:IsShown() and anchor(f.healAbsorbLine) == "TOPLEFT" and f.healAbsorbLine.opts.height > f.healAbsorbLine.opts.width,
		"the heal absorb line takes the edge across")
	assert(value(env, f.healAbsorbLine) == 20, "it carries the whole heal absorb")
	env._roster.units.party1.healAbsorb = 35
	env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "party1")
	assert(value(env, f.healAbsorbLine) == 35, "and follows its event")
	write(env, K, "prediction.shieldPlace", "BOTTOM")
	assert(anchor(f.shield) == "BOTTOMLEFT" and f.shield:GetReverseFill() == false and f.shield.opts.width > f.shield.opts.height, "bottom restores the line")
	assert(anchor(f.healAbsorbLine) == "TOPLEFT" and f.healAbsorbLine:GetReverseFill() == false, "the heal absorb line moves to the top")
	write(env, K, "prediction.healAbsorbLine", false)
	assert(not f.healAbsorbLine:IsShown(), "off hides it")
	noErrors(env, K)
end
collectgarbage()

-- Power: the health bar behind the power bar, and the power bar's room kept on frames without one.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local tank, dps = frame(ns, "party1"), frame(ns, "party3")
	local height, level = tank.health.opts.height, tank.power:GetFrameLevel()
	write(env, K, "power.behind", true)
	local p = tank.parts.power
	assert(tank.health.opts.height > height and near(tank.parts.health.top + tank.parts.health.height, p.top + p.height), "the health bar reaches the frame's foot")
	assert(tank.power:GetFrameLevel() > tank.predict:GetFrameLevel(), "the power bar lies over it")
	local _, over, overPoint = tank.shield:GetPoint(1)
	assert(over == tank.power and overPoint == "TOPLEFT", "the bottom shield line sits above the power bar, not under it")
	write(env, K, "power.behind", false)
	assert(tank.health.opts.height == height and tank.power:GetFrameLevel() == level, "off restores both")

	write(env, K, "power.damagers", false)
	assert(not dps.showPower and dps.health.opts.height > height, "a damage dealer without power takes the room")
	write(env, K, "power.keepRoom", true)
	assert(not dps.showPower and not dps.power:IsShown() and dps.health.opts.height == height, "keeping the room lines the bars up")
	env._roster.units.party3.role = "TANK"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(dps.showPower and dps.power:IsShown(), "a role change brings the power bar back")
	write(env, K, "power.keepRoom", false)
	write(env, K, "power.damagers", true)
	noErrors(env, K)
end
collectgarbage()

-- Status icons: role letters, raid marker and ready check places, the combat icon.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	env._roster.units.party3.marker = 8
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local tank, healer, dps = frame(ns, "party1"), frame(ns, "party2"), frame(ns, "party3")
	write(env, K, "icons.roleText", true)
	assert(tank.roleLetter:IsShown() and tank.roleLetter:GetText() == "T" and healer.roleLetter:GetText() == "H", "letters replace the role icons")
	assert(not tank.role:IsShown() and not tank.pipFill:IsShown(), "and the icon or pip hides")
	env._roster.units.party1.role = "HEALER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(tank.roleLetter:GetText() == "H", "a role change rewrites the letter")
	env._roster.units.party1.role = "TANK"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	write(env, K, "icons.roleTank", false)
	assert(not tank.roleLetter:IsShown() and healer.roleLetter:IsShown(), "the per-role switches still apply")
	write(env, K, "icons.roleTank", true)
	write(env, K, "icons.roleText", false)
	assert(not tank.roleLetter:IsShown() and (tank.role:IsShown() or tank.pipFill:IsShown()), "off restores the icon")

	write(env, K, "icons.markerPlace", "TOPRIGHT")
	local point, relative = anchor(dps.marker)
	assert(point == "TOPRIGHT" and relative == dps.health and dps.marker:IsShown(), "the marker moves to its place on the bar")
	write(env, K, "icons.readySize", 18)
	assert(anchor(dps.marker) == "TOPRIGHT" and near(W.LastCall(dps.marker, "SetSize")[1], W.Calls(dps.marker, "SetSize")[1][1]), "a re-layout keeps its size")
	write(env, K, "icons.readySize", 0)
	write(env, K, "icons.markerPlace", "AUTO")
	assert(anchor(dps.marker) == "TOPLEFT", "Automatic restores it")
	write(env, K, "icons.readyPlace", "BOTTOMLEFT")
	write(env, K, "icons.readySize", 20)
	local most = tank.parts.health.height
	assert(anchor(tank.ready) == "BOTTOMLEFT" and near(W.LastCall(tank.ready, "SetSize")[1], math.min(20, most)) and anchor(tank.statusIcons.afk) == "BOTTOMLEFT", "ready check and status icons move together")
	write(env, K, "icons.readyPlace", "AUTO")
	point, relative = anchor(tank.ready)
	assert(point == "CENTER" and relative == tank and near(W.LastCall(tank.ready, "SetSize")[1], math.min(20, most)), "Automatic with a size keeps today's place")
	write(env, K, "icons.readySize", 0)
	assert(select(3, anchor(tank.ready)) == "TOPLEFT", "0 restores today's place")

	env._busy = { party2 = true }
	write(env, K, "icons.combat", true)
	assert(healer.combatIcon:GetAlpha() == 1 and tank.combatIcon:GetAlpha() == 0, "the combat icon shows on members in combat")
	assert(anchor(healer.combatIcon) == "LEFT", "at its place")
	env._busy = { party1 = true }
	env.FireEvent("UNIT_FLAGS", "party1")
	env.FireEvent("UNIT_FLAGS", "party2")
	assert(tank.combatIcon:GetAlpha() == 1 and healer.combatIcon:GetAlpha() == 0, "UNIT_FLAGS follows combat")
	env._busy = {}
	env.SetCombat(true)
	assert(tank.combatIcon:GetAlpha() == 0, "combat start refreshes every member")
	env.SetCombat(false)
	write(env, K, "icons.combatClass", true)
	local function plain(v) return env.issecretvalue(v) and env.Reveal(v) or v end
	local r, g, b = tank.combatIcon:GetVertexColor()
	local cr, cg, cb = ns.Unit.ClassColor("WARRIOR")
	assert(near(plain(r), plain(cr)) and near(plain(g), plain(cg)) and near(plain(b), plain(cb)), "class colour tints it")
	write(env, K, "icons.combatSize", 24)
	write(env, K, "icons.combatPlace", "TOP")
	assert(anchor(tank.combatIcon) == "TOP" and near(W.LastCall(tank.combatIcon, "SetSize")[1], math.min(24, tank.parts.health.height)), "place and size apply, within the bar")
	write(env, K, "icons.combat", false)
	assert(not tank.combatIcon:IsShown(), "off hides it")
	noErrors(env, K)
end
collectgarbage()

-- A client without the combat swords atlas keeps the combat icon hidden.
do
	local env, K, ns = G.New({ setup = function(e)
		setup(e)
		e.C_Texture.GetAtlasInfo = function() return nil end
	end })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	env._busy = { party1 = true }
	write(env, K, "icons.combat", true)
	local f = frame(ns, "party1")
	assert(f.combatIcon and not f.combatIcon:IsShown() and #W.Calls(f.combatIcon, "SetAtlas") == 0, "no atlas, no icon")
	noErrors(env, K)
end
collectgarbage()

-- Highlights and portraits: one-line target ring, ring opacity.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	write(env, K, "accent.targetLines", 1)
	assert(f.targetRing[1][1]:IsShown() and not f.targetRing[2][1]:IsShown(), "one line leaves the inner line out")
	write(env, K, "accent.targetLines", 2)
	assert(f.targetRing[2][1]:IsShown(), "two restores it")
	write(env, K, "party.portrait", true)
	write(env, K, "party.portraitRingAlpha", 0.5)
	assert(near(select(4, f.ring:GetVertexColor()), 0.5), "the ring's opacity applies")
	env.FireEvent("UNIT_NAME_UPDATE", "party1")
	assert(near(select(4, f.ring:GetVertexColor()), 0.5), "and survives a recolour")
	write(env, K, "party.portraitRingAlpha", 1)
	assert(near(select(4, f.ring:GetVertexColor()), 1), "1 restores it")
	noErrors(env, K)
end
collectgarbage()

-- Raid size: the thresholds, counting only shown groups, and empty groups closed up, out of combat.
do
	local env, K, ns = G.New({ setup = setup })
	G.SetRoster(env, "raid", G.Members(12))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local width = ns.Settings.current.raid.width
	assert(ns.AutoLayout.state.bracket == "MEDIUM", "12 players use the standard frames")
	write(env, K, "auto.smallMost", 14)
	assert(ns.Settings.current.raid.width == width + 16, "covering up to 14 gives them the larger frames")
	write(env, K, "auto.smallMost", 10)
	G.SetRoster(env, "raid", G.Members(22))
	env.RunTimers()
	assert(ns.AutoLayout.state.bracket == "MEDIUM", "22 players stay standard")
	write(env, K, "auto.largeLeast", 21)
	assert(ns.AutoLayout.state.bracket == "LARGE" and not ns.Settings.current.raid.power, "compact from 21")
	write(env, K, "groups.show5", false)
	write(env, K, "auto.shownOnly", true)
	assert(ns.AutoLayout.state.bracket == "MEDIUM", "groups 1 to 4 hold 20 shown players")
	write(env, K, "auto.shownOnly", false)
	assert(ns.AutoLayout.state.bracket == "LARGE", "off counts everyone again")
	write(env, K, "groups.show5", true)
	write(env, K, "auto.largeLeast", 26)

	local groupsOf = { 1, 1, 2, 2, 3, 6, 6 }
	G.SetRoster(env, "raid", G.Members(7, function(i, m) m.group = groupsOf[i] end))
	env.RunTimers()
	local headers = ns.Headers.raid
	assert(headers[4]:GetAttribute("groupFilter") == "4", "empty groups keep their place by default")
	write(env, K, "groups.hideEmpty", true)
	assert(headers[4]:GetAttribute("groupFilter") == "6" and G.Shown(headers[4])[1] == "raid6", "group 6 closes up beside group 3")
	assert(headers[5]:GetAttribute("groupFilter") == "4", "the empty groups follow, still ready for members")
	env.SetCombat(true)
	env._roster.units.raid7.group = 4
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.UpdateHeaders()
	assert(headers[4]:GetAttribute("groupFilter") == "6" and G.Shown(headers[5])[1] == "raid7", "in combat a member in an empty group still shows")
	env.SetCombat(false)
	env.RunTimers()
	assert(headers[4]:GetAttribute("groupFilter") == "4" and headers[5]:GetAttribute("groupFilter") == "6", "after combat the groups close up again")
	write(env, K, "groups.hideEmpty", false)
	assert(headers[5]:GetAttribute("groupFilter") == "5", "off restores group order")
	noErrors(env, K)
end
collectgarbage()

-- The preview follows the new options.
do
	local env, K = G.New({ setup = setup })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview(MODULE)(parent)
	local tank = preview.partyFrames[1]
	for _, field in ipairs(NEW) do assert(tank[field] == nil, field .. " is not made in the default preview") end
	local function shownDebuffs()
		local n = 0
		for _, icon in ipairs(tank.sampleAuras) do if icon:IsShown() then n = n + 1 end end
		return n
	end
	assert(shownDebuffs() == 2, "the sample tank carries two debuffs")
	for key, on in pairs({ ["icons.roleText"] = true, ["icons.combat"] = true, ["prediction.overshield"] = true,
		["prediction.healAbsorbLine"] = true, ["accent.targetLines"] = 1, ["auras.source"] = "PLAYERS", ["power.behind"] = true }) do
		write(env, K, key, on)
	end
	preview:Refresh()
	assert(tank.roleLetter:IsShown() and tank.roleLetter:GetText() == "T", "the sample tank shows its letter")
	assert(tank.combatIcon:IsShown() and tank.combatIcon:GetAlpha() == 1, "and its combat icon")
	assert(value(env, tank.overshield) == 0.4 and value(env, tank.healAbsorbLine) == tank.sample.healAbsorb, "its overshield and heal absorb line")
	assert(not tank.targetRing[2][1]:IsShown(), "the ring has one line")
	assert(shownDebuffs() == 0 and not tank.sampleBoss:IsShown(), "players' debuffs leave the enemy samples out")
	assert(tank.power:GetFrameLevel() > tank.health:GetFrameLevel(), "the power bar lies over the health")
	write(env, K, "auras.source", "ANY")
	write(env, K, "auras.typeMode", "ONLY")
	write(env, K, "auras.curse", false)
	preview:Refresh()
	assert(shownDebuffs() == 1, "only the switched-on types show")
	noErrors(env, K)
end

print("groupframes parity round 2 ok: defaults, debuff filters and time left, absorbs, power, status icons, combat icon, highlights, raid size and the preview")
