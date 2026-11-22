-- test-groupframes-parity-r2-review.lua: the PR #616 review's probes as regressions: saved raid sizing at login, on a profile switch and after a threshold change; the power bar over the shields and level bars; one deferred roster pass and secret counts; ready, status and combat icon size and place; options and preview; Medallions; role and class reads.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local C = dofile("Tools/regression/core_env.lua")
local W = A.W

local MODULE = "GroupFrames"

local function write(env, K, key, value)
	K.Options.Write(MODULE, key, value)
	env.RunTimers()
end

local function frame(ns, unit)
	local out
	ns.Unit.ForEach(function(f) if f.unit == unit then out = f end end)
	return assert(out, "no frame for " .. unit)
end

local function noErrors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function size(region)
	local call = W.LastCall(region, "SetSize")
	return call and call[1]
end

local function point(region)
	local p, relative, q, x, y = region:GetPoint(1)
	return table.concat({ p or "", tostring(relative), q or "", tostring(x), tostring(y) }, ",")
end

local function shownFive(i, m)
	m.group = i <= 5 and 1 or 6
end

-- Saved raid sizing: at login, on a profile switch both ways, and after a threshold change.
do
	local own = { enabled = true, groups = { show6 = false, hideEmpty = true }, auto = { shownOnly = true } }
	local saved = { version = 42, profiles = { Default = { [MODULE] = own }, Tight = { [MODULE] = { enabled = true } } }, characters = {}, layouts = {} }
	local env, K, ns = G.New({ saved = saved, boot = false })
	G.SetRoster(env, "raid", G.Members(12, shownFive), nil, true)
	C.Boot(env)
	env.RunTimers()
	local width = ns.Settings.Get("raid.width")
	local cfg = ns.Settings.current
	assert(ns.AutoLayout.state.bracket == "SMALL" and cfg.raid.width == width + 16, "login sizes the raid by its five shown players: " .. cfg.raid.width)
	ns.AutoLayout.Check()
	K.Store.SetProfile("Tight")
	env.RunTimers()
	assert(ns.AutoLayout.state.bracket == "MEDIUM" and cfg.raid.width == ns.Settings.Get("raid.width"), "a profile counting everyone sizes twelve players standard: " .. cfg.raid.width)
	K.Store.SetProfile("Default")
	env.RunTimers()
	assert(ns.AutoLayout.state.bracket == "SMALL" and cfg.raid.width == width + 16, "switching back counts the five shown again: " .. cfg.raid.width)
	noErrors(env, K)
end
collectgarbage()

do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(11))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	G.SetRoster(env, "raid", G.Members(14))
	env.RunTimers()
	local refresh, refreshes = ns.Settings.Refresh, 0
	ns.Settings.Refresh = function(...)
		refreshes = refreshes + 1
		return refresh(...)
	end
	write(env, K, "auto.smallMost", 12)
	ns.Settings.Refresh = refresh
	assert(ns.Settings.current.raid.width == ns.Settings.Get("raid.width"), "fourteen players stay standard when the larger frames stop at twelve: " .. ns.Settings.current.raid.width)
	assert(refreshes <= 2, "one threshold change reads the settings no more than any other setting: " .. refreshes)
	noErrors(env, K)
end
collectgarbage()

-- One deferred roster pass, shared, and a secret member count refused.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(30))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "groups.hideEmpty", true)
	local roster, reads = env.GetRaidRosterInfo, 0
	env.GetRaidRosterInfo = function(...)
		reads = reads + 1
		return roster(...)
	end
	for _ = 1, 3 do env.FireEvent("GROUP_ROSTER_UPDATE") end
	assert(reads == 0, "three roster events read no member at once: " .. reads)
	env.RunTimers()
	assert(reads == 30, "and one shared thirty-member pass after: " .. reads)
	env.GetRaidRosterInfo = roster
	local count = env.GetNumGroupMembers
	env.GetNumGroupMembers = function() return env.Secret(12) end
	local ok, err = pcall(ns.AutoLayout.Check)
	env.GetNumGroupMembers = count
	assert(ok, "a secret member count is refused, not counted: " .. tostring(err))
	noErrors(env, K)
end
collectgarbage()

-- Power: the bar lies over the shields when the health runs behind it, and both power switches keep the bars level.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "party", {
		{ name = "Tank", role = "TANK", health = 100, maxHealth = 100, power = 100, maxPower = 100, absorb = 100 },
		{ name = "Dps", role = "DAMAGER" },
	})
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local tank, dps = frame(ns, "party1"), frame(ns, "party2")
	write(env, K, "power.behind", true)
	write(env, K, "prediction.overshield", true)
	local call = W.LastCall(tank.predict, "SetPoint")
	assert(call and call[2] == tank.power and call[3] == "TOPLEFT", "heals, absorbs and the overshield stop at the power bar's top: " .. point(tank.predict))
	assert(tank.power:GetFrameLevel() > tank.health:GetFrameLevel(), "the power bar lies over the health")
	write(env, K, "power.damagers", false)
	write(env, K, "power.keepRoom", true)
	assert(tank.power:IsShown() and not dps.power:IsShown(), "the damage dealer shows no power bar")
	assert(tank.parts.health.height == dps.parts.health.height,
		"with the room kept and the health behind, every health bar is as tall: " .. tank.parts.health.height .. " and " .. dps.parts.health.height)
	write(env, K, "power.behind", false)
	call = W.LastCall(tank.predict, "SetPoint")
	assert(call and call[2] == tank.health and call[3] == "BOTTOMLEFT", "off restores the prediction to the whole health bar")
	noErrors(env, K)
end
collectgarbage()

-- Ready, status and combat icons: size and place apply on their own, and the art stays on the bar.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(12, function(_, m) m.role = "TANK" end))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "raid1")
	local p0, r0, q0, x0, y0 = f.ready:GetPoint(1)
	local floor = y0 - size(f.ready)
	write(env, K, "icons.readySize", 8)
	local p1, r1, q1, x1, y1 = f.ready:GetPoint(1)
	assert(p1 == p0 and r1 == r0 and q1 == q0 and x1 == x0 and y1 - 8 == floor and size(f.ready) == 8, "a size alone keeps the automatic place on the lane's floor: " .. point(f.ready))
	write(env, K, "icons.readySize", 40)
	assert(size(f.ready) <= f.parts.health.height and size(f.statusIcons.afk) <= f.parts.health.height, "and never outgrows the health bar")
	write(env, K, "icons.readySize", 0)
	write(env, K, "icons.readyPlace", "RIGHT")
	assert(size(f.statusIcons.afk) == 14, "a place alone keeps the status icons' size: " .. tostring(size(f.statusIcons.afk)))
	write(env, K, "icons.combat", true)
	write(env, K, "icons.combatSize", 40)
	assert(size(f.combatIcon) <= f.parts.health.height, "the combat icon fits the health bar: " .. size(f.combatIcon))

	write(env, K, "icons.readyPlace", "AUTO")
	f = frame(ns, "raid1")
	write(env, K, "icons.readySize", 18)
	local p, relative = f.ready:GetPoint(1)
	assert(relative == f and p ~= "CENTER", "a Medallions tile keeps its ready check lane with a size alone: " .. point(f.ready))
	assert(size(f.combatIcon) <= f.parts.health.height, "the combat icon fits the Medallions tile: " .. size(f.combatIcon))
	noErrors(env, K)
end
collectgarbage()

-- Frames: a ready check size alone keeps the automatic place, and a default raid frame reads its role once.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(12, function(_, m) m.role = "TANK" end))
	K.Modules.Enable(MODULE)
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	local f = frame(ns, "raid1")
	local at = point(f.ready)
	write(env, K, "icons.readySize", 8)
	assert(point(f.ready) == at and size(f.ready) == 8, "a Frames size alone keeps the automatic place: " .. point(f.ready))
	local roles, reads = env.UnitGroupRolesAssigned, 0
	env.UnitGroupRolesAssigned = function(unit)
		reads = reads + 1
		return roles(unit)
	end
	ns.Indicators.Role(f)
	assert(reads == 1, "a default Frames raid frame reads its role once: " .. reads)
	env.UnitGroupRolesAssigned = roles
	noErrors(env, K)
end
collectgarbage()

-- Options and preview follow the live behaviour.
do
	local env, K = G.New()
	G.SetRoster(env, "party", { { name = "Tank", role = "TANK" } })
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local settings = K.Store.Module(MODULE)
	write(env, K, "auras.enabled", false)
	for _, key in ipairs({ "auras.source", "auras.canApply", "auras.typeMode" }) do
		local row = K.Options.Row(MODULE, key)
		assert(row.disableWhen and row.disableWhen(settings), key .. " is disabled while debuff icons are off")
	end
	write(env, K, "auras.enabled", true)
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview(MODULE)(parent)
	write(env, K, "auras.typeMode", "ONLY")
	for _, kind in ipairs({ "magic", "curse", "poison", "disease", "bleed" }) do write(env, K, "auras." .. kind, false) end
	preview:Refresh()
	assert(not preview.partyFrames[1].sampleBoss:IsShown(), "with no type switched on, the preview shows no boss debuff either")
	write(env, K, "icons.readyPlace", "BOTTOMLEFT")
	write(env, K, "icons.readySize", 20)
	preview:Refresh()
	local shown = 0
	for _, frames in ipairs({ preview.partyFrames, preview.raidFrames }) do
		for _, sample in ipairs(frames) do shown = shown + (sample.ready:IsShown() and 1 or 0) end
	end
	assert(shown > 0, "a moved and resized ready check shows in the preview")
	noErrors(env, K)
end
collectgarbage()

-- Medallions: the ring opacity follows the badge portraits, and role letters reach the raid tiles.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "party", { { name = "Tank", role = "TANK" } })
	K.Modules.Enable(MODULE)
	env.RunTimers()
	assert(frame(ns, "party1").showPortrait, "Medallions shows party portraits")
	local row = K.Options.Row(MODULE, "party.portraitRingAlpha")
	assert(row.showWhen(K.Store.Module(MODULE)), "so the ring opacity row shows")
	G.SetRoster(env, "raid", G.Members(20, function(_, m) m.role = "TANK" end))
	write(env, K, "icons.roleText", true)
	local tile = frame(ns, "raid1")
	assert(tile.roleLetter and tile.roleLetter:IsShown() and not tile.role:IsShown(), "role letters show on Medallions raid tiles, still without the role icon")
	noErrors(env, K)
end
collectgarbage()

-- Role and class reads: no role read on a default raid tile, no paint-time geometry, no class read without the tint.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(12, function(_, m) m.role = "TANK" end))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "raid1")
	local roles, reads = env.UnitGroupRolesAssigned, 0
	env.UnitGroupRolesAssigned = function(unit)
		reads = reads + 1
		return roles(unit)
	end
	ns.Indicators.Role(f)
	assert(reads == 0, "a default Medallions raid tile, its role in the ring, reads no role: " .. reads)
	env.UnitGroupRolesAssigned = roles
	write(env, K, "icons.roleText", true)
	local placed, fonts = #W.Calls(f.roleLetter, "SetPoint"), #W.Calls(f.roleLetter, "SetFont")
	ns.Indicators.Role(f)
	assert(f.roleLetter:IsShown(), "role letters show")
	assert(#W.Calls(f.roleLetter, "SetPoint") == placed and #W.Calls(f.roleLetter, "SetFont") == fonts, "a role paint does not place or size the letter again")
	local class, classes = env.UnitClass, 0
	env.UnitClass = function(...)
		classes = classes + 1
		return class(...)
	end
	ns.Unit.Refresh(f)
	local plain = classes
	write(env, K, "icons.combat", true)
	classes = 0
	ns.Unit.Refresh(f)
	assert(classes == plain, "the combat icon reads no class without its tint: " .. classes .. " against " .. plain)
	env.UnitClass = class
	noErrors(env, K)
end
collectgarbage()

print("groupframes parity round 2 review ok: saved raid sizing, power layering and level bars, one roster pass, icon size and place, options and preview, Medallions, role and class reads")
