-- test-groupframes-parity-r1-review.lua: the PR #595 review's probes as regressions: held tooltips, fail-closed tooltip modes, low-health fill opacity, one roster pass, preview fidelity, restored debuff filters, the raid card's hidden groups, Medallions and the defaults.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")

local MODULE = "GroupFrames"

local function setup(env)
	env.UnitAffectingCombat = function(unit)
		return unit == "player" and env._fighting == true
	end
	env.C_InstanceEncounter = { IsEncounterInProgress = function() return env._boss == true end }
	env.DifficultyUtil = { ID = { PrimaryRaidMythic = 16 } }
	env.GetInstanceInfo = function()
		env._instanceReads = (env._instanceReads or 0) + 1
		return "Raid", "raid", 0
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

local function noErrors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function preview(env, K)
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(320, 420)
	return K.Options.Preview(MODULE)(parent)
end

-- A raid of tanks at 20% health: tooltips, fill opacity, the roster pass, the preview and the dispel ghost.
do
	local env, K, ns = G.New({ setup = setup })
	G.SetRoster(env, "raid", G.Members(10, function(_, m) m.role = "TANK"; m.health = 20 end))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	for _, key in ipairs({ "auras.lasting", "groups.mythicBench", "health.statusGrey" }) do
		assert(ns.Settings.Get(key) == true, key .. " starts on and keeps today's look")
	end
	local f = frame(ns, "raid1")
	local tip, button = env.GameTooltip, f.owner
	function tip:SetUnit(unit) self.unit = unit end
	function tip:IsOwned(owner) return self._owner == owner end
	local function enter() button:GetScript("OnEnter")(button) end
	local function leave() button:GetScript("OnLeave")(button) end

	write(env, K, "tooltip.mode", "COMBAT")
	enter()
	assert(tip:IsShown(), "out of combat the member tooltip shows")
	env.SetCombat(true)
	assert(not tip:IsShown(), "combat starting under the pointer hides it")
	leave()
	env.SetCombat(false)
	write(env, K, "tooltip.mode", "BOSS")
	enter()
	env._boss = true
	env.FireEvent("ENCOUNTER_START")
	assert(not tip:IsShown(), "a boss pull under the pointer hides it")
	leave()
	env._boss = false
	write(env, K, "tooltip.mode", "COMBAT")
	local combat = env.UnitAffectingCombat
	env.UnitAffectingCombat = nil
	tip:Hide()
	enter()
	assert(not tip:IsShown(), "without the combat answer it stays hidden")
	leave()
	env.UnitAffectingCombat = function() return env.Secret(false) end
	enter()
	assert(not tip:IsShown(), "a secret combat answer keeps it hidden")
	leave()
	env.UnitAffectingCombat = combat
	write(env, K, "tooltip.mode", "ALWAYS")

	write(env, K, "health.alpha", 0.1)
	env.FireEvent("UNIT_HEALTH", "raid1")
	local low = f.health.lowFill:GetAlpha()
	if env.issecretvalue(low) then low = env.Reveal(low) end
	assert(low * f.health.fillClip:GetAlpha() <= 0.1 + 1e-6, "at low health the red fill takes the fill opacity too")
	write(env, K, "health.alpha", 1)
	assert(f.health.fillClip:GetAlpha() == 1, "full opacity restores the red fill")

	local roster, reads = env.GetRaidRosterInfo, 0
	env.GetRaidRosterInfo = function(...)
		reads = reads + 1
		return roster(...)
	end
	write(env, K, "groups.show2", false)
	reads, env._instanceReads = 0, 0
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(reads == 0, "a roster change reads no member at once: " .. reads)
	env.RunTimers()
	assert(reads == 10, "and one ten-member pass after: " .. reads)
	assert(env._instanceReads == 0, "with the Mythic switch at its default no difficulty is read")
	env.GetRaidRosterInfo = roster

	local pane = preview(env, K)
	for g = 1, 8 do K.Options.Write(MODULE, "groups.show" .. g, false) end
	env.RunTimers()
	pane:Refresh()
	local function tiles()
		local n = 0
		for _, tile in ipairs(pane.raidFrames) do n = n + (tile:IsShown() and 1 or 0) end
		return n
	end
	assert(tiles() == 0, "with every group hidden the preview shows no raid tile: " .. tiles())
	write(env, K, "groups.show1", true)
	pane:Refresh()
	assert(tiles() == 2, "one group shown previews one group: " .. tiles())
	for g = 2, 8 do K.Options.Write(MODULE, "groups.show" .. g, true) end
	env.RunTimers()
	pane:Refresh()
	assert(tiles() == 4, "every group restores the four tiles")

	local tank = pane.partyFrames[1]
	write(env, K, "auras.zoom", 0.2)
	pane:Refresh()
	assert(near((tank.sampleBoss.tile.icon:GetTexCoord()), 0.2), "the boss sample takes the icon zoom")
	write(env, K, "auras.zoom", 0.07)
	write(env, K, "auras.magic", false)
	pane:Refresh()
	assert(tank.sampleAuras[1]:IsShown() and tank.sampleAuras[1].art:GetTexture() == 135848 and not tank.sampleAuras[2]:IsShown(),
		"the Magic sample leaves and the Curse sample takes its place")
	write(env, K, "auras.magic", true)
	pane:Refresh()
	assert(tank.sampleAuras[1].art:GetTexture() == 136207 and tank.sampleAuras[2]:IsShown(), "Magic returns to the first place")

	local more = assert(f.dispelMore, "raid frames carry the dispel ghost")
	write(env, K, "raid.auraDispelCount", 1)
	write(env, K, "auras.magic", false)
	write(env, K, "raid.auraDispelCount", 0)
	write(env, K, "auras.magic", true)
	write(env, K, "raid.auraDispelCount", 1)
	for _, group in pairs(more.ghost._groups) do
		local c = group.candidateFilters
		assert(not (c and c.excludeDispelTypes and c.excludeDispelTypes.Magic), "a ghost re-enabled after Magic returned counts Magic again")
	end

	write(env, K, "auras.tooltips", false)
	local boss
	for _, value in pairs(f.highlights._slots.boss) do
		if type(value) == "table" and value._aura then boss = value end
	end
	local function motion() return W.LastCall(boss, "SetMouseMotionEnabled")[1] end
	assert(boss and motion() == false, "Debuff tooltips off reaches the boss debuff")
	write(env, K, "auras.tooltips", true)
	assert(motion() == true, "and on restores it")
	noErrors(env, K)
end
collectgarbage()

-- No aura processing policy: the type and duration filters still apply, and the cheap paths stay cheap.
do
	local env, K, ns = G.New({ setup = function(t)
		setup(t)
		t.CustomAuraContainerAuraProcessingPolicy = nil
	end })
	G.SetRoster(env, "party", { { name = "Tank", class = "WARRIOR", role = "TANK", health = 20, maxHealth = 100 } })
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	write(env, K, "auras.magic", false)
	write(env, K, "auras.lasting", false)
	local c = f.auras._groups.debuffs.candidateFilters
	assert(c and c.excludeDispelTypes and c.excludeDispelTypes.Magic and c.maxDuration == math.huge, "the type and duration filters apply without the policy")
	write(env, K, "auras.magic", true)
	write(env, K, "auras.lasting", true)
	c = f.auras._groups.debuffs.candidateFilters
	assert(not (c and (c.excludeDispelTypes or c.maxDuration)), "and switching back clears them")

	write(env, K, "accent.hover", false)
	local tween, tweens = K.Motion.Tween, 0
	K.Motion.Tween = function(obj, ...)
		if obj == f then tweens = tweens + 1 end
		return tween(obj, ...)
	end
	ns.Style.SetHovered(f, true)
	ns.Style.SetHovered(f, false)
	K.Motion.Tween = tween
	assert(tweens == 0, "with the hover highlight off pointing starts no tween: " .. tweens)
	write(env, K, "accent.hover", true)

	write(env, K, "health.colorSource", "gradient")
	local percent, evaluations = env.UnitHealthPercent, 0
	env.UnitHealthPercent = function(unit, scaled, curve)
		if unit == f.unit and curve and curve.points and #curve.points == 3 then evaluations = evaluations + 1 end
		return percent(unit, scaled, curve)
	end
	ns.Unit.Refresh(f)
	env.UnitHealthPercent = percent
	assert(evaluations == 3, "a refresh paints the by-health colour once: " .. evaluations)

	write(env, K, "icons.roleTank", false)
	local roles = env.UnitGroupRolesAssigned
	env.UnitGroupRolesAssigned = nil
	local ok, err = pcall(ns.Indicators.Role, f)
	env.UnitGroupRolesAssigned = roles
	assert(ok, "a missing role API keeps role filtering safe: " .. tostring(err))
	noErrors(env, K)
end
collectgarbage()

-- The Group-order raid card fits the members that show, not a hidden group's number.
do
	local env, K, ns = G.New({ setup = setup })
	local function roster(n)
		G.SetRoster(env, "raid", G.Members(n, function(i, m) m.group = i > 5 and 8 or 1 end))
		env.RunTimers()
	end
	roster(6)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "groups.show8", false)
	local card = ns.Headers.cards.raid
	local function width()
		ns.Unit.PartyCount()
		ns.Headers.FitRaid(card.members, card.groups, true)
		return card.frame:GetWidth()
	end
	local hidden = width()
	roster(5)
	assert(width() == hidden, "a member in hidden group 8 adds no empty groups to the card: " .. hidden .. " against " .. width())
	noErrors(env, K)
end
collectgarbage()

-- Medallions: raid tiles honour By health; the party preview keeps the badge's own crop.
do
	local env, K, ns = G.New({ setup = setup })
	G.SetRoster(env, "raid", G.Members(5))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	write(env, K, "health.colorSource", "gradient")
	assert(ns.Unit.ColorSources(frame(ns, "raid1")) == "gradient", "Medallions raid tiles take the By health colour")
	write(env, K, "party.portrait", true)
	write(env, K, "party.portraitZoom", 0.2)
	local pane = preview(env, K)
	assert((pane.partyFrames[1].portrait:GetTexCoord()) == 0, "the Medallions party preview keeps the badge's full crop, as live")
	local tile = pane.raidFrames[1]
	local cr = K.Theme.ClassColor(tile.sample.class)
	assert(not near(tile.health.colorRGBA[1], cr), "the Medallions raid preview paints By health too")
	noErrors(env, K)
end

print("groupframes parity review ok: held and fail-closed tooltips, low-health opacity, one roster pass, preview groups, zoom and types, restored ghost and fallback filters, boss tooltips, hover, one gradient paint, role API, raid card, Medallions and defaults")
