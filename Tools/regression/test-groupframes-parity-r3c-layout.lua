-- test-groupframes-parity-r3c-layout.lua: EllesmereUI parity round 3c's layout options switched on apply, follow the roster and combat, and switch back: merged groups, raid sizes, small raids and centre when solo; and the preview follows the new options.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local W = A.W

local MODULE = "GroupFrames"

local function write(env, K, key, value)
	K.Options.Write(MODULE, key, value)
	env.RunTimers()
end

local function near(a, b)
	return math.abs(a - b) < 1e-3
end

local function plain(env, v)
	return env.issecretvalue(v) and env.Reveal(v) or v
end

local function value(env, bar)
	local call = W.LastCall(bar, "SetValue")
	return call and plain(env, call[1])
end

local function party(env)
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 50, maxHealth = 100, absorb = 70, healAbsorb = 20, maxLoss = 0.2, threat = 3 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 80, maxHealth = 100 },
		{ name = "Captain Garrick", class = "PALADIN", role = "DAMAGER", health = 90, maxHealth = 100 },
	})
end

local function noErrors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local NEW = { "missingFill", "shieldGlow", "maxLoss", "hoverLine", "threatEdge" }

-- Merged raid groups run on in one block in group order; off restores a header per group.
do
	local env, K, ns = G.New({})
	local groupsOf = { 1, 1, 2, 2, 3, 6, 6 }
	G.SetRoster(env, "raid", G.Members(7, function(i, m) m.group = groupsOf[i] end))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local headers = ns.Headers.raid
	write(env, K, "raid.merge", true)
	assert(headers[1]:GetAttribute("groupBy") == "GROUP" and headers[1]:GetAttribute("groupingOrder") == "1,2,3,4,5,6,7,8", "one header in group order")
	assert(env.Driver(headers[2], "visibility") == "hide" and #G.Shown(headers[1]) == 7, "everyone in the first header")
	write(env, K, "raid.merge", false)
	assert(headers[1]:GetAttribute("groupBy") == nil and headers[1]:GetAttribute("groupFilter") == "1" and env.Driver(headers[2], "visibility") ~= "hide", "off restores a header per group")
	noErrors(env, K)
end
collectgarbage()

-- Raid sizes: custom width and height, icons resized with them, and each size's offset; out of combat.
do
	local env, K, ns = G.New({})
	G.SetRoster(env, "raid", G.Members(8))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local cfg = ns.Settings.current
	local aura, indicator, buff = cfg.raid.auraSize, cfg.indicator1.size, cfg.raid.buffSize
	assert(ns.AutoLayout.state.bracket == "SMALL", "8 players use the larger frames")
	write(env, K, "auto.smallWidth", 200)
	write(env, K, "auto.smallHeight", 54)
	assert(cfg.raid.width == 200 and cfg.raid.height == 54, "the larger frames take their own size")
	assert(cfg.raid.auraSize == aura and cfg.indicator1.size == indicator, "icons keep their size by default")
	write(env, K, "auto.icons", true)
	assert(cfg.raid.auraSize == math.floor(aura * 54 / 36 + 0.5) and cfg.indicator1.size == math.floor(indicator * 54 / 36 + 0.5) and cfg.raid.buffSize == buff,
		"debuffs and indicators grow with the frames")
	write(env, K, "auto.heals", true)
	assert(cfg.raid.buffSize == math.floor(buff * 54 / 36 + 0.5), "and heal icons when asked")
	local _, _, _, x0, y0 = ns.Headers.raid[1]:GetPoint(1)
	local _, _, _, cx0, cy0 = ns.Headers.cards.raid.frame:GetPoint(1)
	write(env, K, "auto.smallX", 30)
	write(env, K, "auto.smallY", -20)
	local _, _, _, x1, y1 = ns.Headers.raid[1]:GetPoint(1)
	local _, _, _, cx1, cy1 = ns.Headers.cards.raid.frame:GetPoint(1)
	assert(near(x1 - x0, 30) and near(y1 - y0, -20) and near(cx1 - cx0, 30) and near(cy1 - cy0, -20), "the frames and their card move together")
	env.SetCombat(true)
	G.SetRoster(env, "raid", G.Members(16))
	assert(near(select(4, ns.Headers.raid[1]:GetPoint(1)), x1), "in combat nothing moves")
	env.SetCombat(false)
	env.RunTimers()
	assert(ns.AutoLayout.state.bracket == "MEDIUM" and near(select(4, ns.Headers.raid[1]:GetPoint(1)), x0) and cfg.raid.width == ns.Settings.Get("raid.width"), "after combat a standard raid is back in place")
	for _, key in ipairs({ "auto.smallWidth", "auto.smallHeight", "auto.smallX", "auto.smallY" }) do write(env, K, key, 0) end
	write(env, K, "auto.largeX", -15)
	G.SetRoster(env, "raid", G.Members(30))
	env.RunTimers()
	assert(ns.AutoLayout.state.bracket == "LARGE" and near(select(4, ns.Headers.raid[1]:GetPoint(1)) - x0, -15), "the compact frames take their own offset")
	noErrors(env, K)
end
collectgarbage()

-- Party frames in a small raid: group 1 as party frames, raid frames hidden; not in battlegrounds or larger raids.
do
	local env, K, ns = G.New({})
	G.SetRoster(env, "raid", G.Members(6))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local partyHeader, raid1 = ns.Headers.party, ns.Headers.raid[1]
	assert(env.Driver(raid1, "visibility") ~= "hide" and not partyHeader:GetAttribute("showRaid"), "a raid shows raid frames by default")
	write(env, K, "party.smallRaid", true)
	assert(ns.AutoLayout.state.smallRaid and partyHeader:GetAttribute("showRaid") == true and partyHeader:GetAttribute("groupFilter") == "1", "group 1 shows as party frames")
	assert(env.Driver(raid1, "visibility") == "hide" and partyHeader:IsShown(), "and the raid frames hide")
	assert(#G.Shown(partyHeader) == 5, "group 1's five members")
	env.SetCombat(true)
	G.SetRoster(env, "raid", G.Members(12))
	assert(partyHeader:GetAttribute("showRaid") == true, "in combat the frames wait")
	env.SetCombat(false)
	env.RunTimers()
	assert(not ns.AutoLayout.state.smallRaid and env.Driver(raid1, "visibility") ~= "hide" and partyHeader:GetAttribute("showRaid") == false, "a 12-player raid gets raid frames after combat")
	G.SetRoster(env, "raid", G.Members(6))
	env.RunTimers()
	assert(ns.AutoLayout.state.smallRaid, "back to six")
	env._instance = "pvp"
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	env.RunTimers()
	assert(not ns.AutoLayout.state.smallRaid and env.Driver(raid1, "visibility") ~= "hide", "battlegrounds keep raid frames")
	env._instance = nil
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	write(env, K, "party.smallRaid", false)
	assert(partyHeader:GetAttribute("showRaid") == false and partyHeader:GetAttribute("groupFilter") == nil, "off restores the party header")
	noErrors(env, K)
end
collectgarbage()

-- Centre when solo: alone, the one frame sits in the middle of the party's space; in a group it returns.
do
	local env, K, ns = G.New({})
	G.SetRoster(env, nil, {})
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "party.showSolo", true)
	local header = ns.Headers.party
	local _, _, _, x0, y0 = header:GetPoint(1)
	write(env, K, "party.centerSolo", true)
	local s = ns.Settings.current.party
	local _, _, _, x1, y1 = header:GetPoint(1)
	local step = s.height + s.spacing
	assert(near(x1, x0) and near(y1 - y0, -(4 * step) / 2), "solo, the frame moves down half the empty space: " .. tostring(y1 - y0))
	local _, _, _, _, cy = ns.Headers.cards.party.frame:GetPoint(1)
	assert(near(cy, y1 - y0), "its card moves with it")
	party(env)
	env.RunTimers()
	assert(near(select(5, header:GetPoint(1)), y0), "in a group the frames start at the corner again")
	write(env, K, "party.centerSolo", false)
	noErrors(env, K)
end
collectgarbage()

-- The preview follows the new options.
do
	local env, K = G.New({})
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview(MODULE)(parent)
	local tank, kragar = preview.partyFrames[1], preview.partyFrames[3]
	for _, field in ipairs(NEW) do assert(not tank[field], field .. " is not made in the default preview") end
	for key, on in pairs({ ["health.missing"] = true, ["prediction.absorbStyle"] = "STRIPES", ["prediction.glow"] = true,
		["prediction.maxLoss"] = "STRIPES", ["threat.edge"] = true, ["party.portrait"] = true, ["raid.merge"] = true }) do
		write(env, K, key, on)
	end
	preview:Refresh()
	assert(tank.missingFill and near(value(env, tank.health), 1 - tank.sample.health), "the sample fills with missing health")
	assert(tank.absorbs.stripes:IsShown(), "striped shields")
	assert(tank.shieldGlow:IsShown() and plain(env, tank.shieldGlow:GetAlpha()) == 1, "the overshielded tank glows")
	assert(kragar.maxLoss:IsShown() and value(env, kragar.maxLoss) == 0.15, "Kragar shows lost maximum health")
	assert(not tank.threatEdge and tank.threat:IsShown(), "the tileless Medallions portrait tank keeps the threat border")
	local raid = preview.raidFrames
	local _, _, _, x1 = raid[1]:GetPoint(1)
	local _, _, _, x3, y3 = raid[3]:GetPoint(1)
	assert(near(x1, x3) and y3 < 0, "merged, the four raid samples run on in one column")
	noErrors(env, K)
end

print("groupframes parity round 3c layout ok: merged groups, raid sizes, small raids, centre when solo and the preview")
