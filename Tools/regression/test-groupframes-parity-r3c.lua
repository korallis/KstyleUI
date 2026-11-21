-- test-groupframes-parity-r3c.lua: EllesmereUI parity round 3c: a v0.2.8 profile keeps every default and makes nothing new; each new bar, layout and highlight option switched on applies, follows its events, reaches the preview and switches back.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local W = A.W

local MODULE = "GroupFrames"

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
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

-- A v0.2.8-shaped profile keeps every default, today's look, and makes no new region.
do
	local env, K, ns = G.New({ saved = saved({ party = { width = 259 }, raid = { sortBy = "GROUP" } }) })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local get = ns.Settings.Get
	for key, want in pairs({ ["health.missing"] = false, ["prediction.absorbStyle"] = "SOLID", ["prediction.healAbsorbStyle"] = "SOLID",
		["prediction.backing"] = 1, ["prediction.glow"] = false, ["prediction.healAbsorbLines"] = 0, ["prediction.maxLoss"] = "OFF",
		["auto.icons"] = false, ["auto.heals"] = false, ["auto.smallWidth"] = 0, ["auto.largeHeight"] = 0, ["auto.smallX"] = 0, ["auto.largeY"] = 0,
		["accent.hoverLines"] = 1, ["threat.edge"] = false, ["party.nameFormat"] = "FULL", ["raid.nameFormat"] = "FULL",
		["party.centerSolo"] = false, ["party.smallRaid"] = false, ["raid.merge"] = false }) do
		assert(get(key) == want, key .. " keeps today's default")
	end
	ns.Unit.ForEach(function(f)
		for _, field in ipairs(NEW) do assert(not f[field], field .. " is not made by default") end
		assert(f.absorbs.stripes == nil and f.healAbsorbs.stripes == nil, "no stripes by default")
		assert(#W.Calls(f.health, "SetReverseFill") == 0, "the health bar keeps its fill direction")
	end)
	local tank = frame(ns, "party1")
	assert(tank.threat:IsShown(), "threat keeps its border")
	assert(tank.name:GetText() == "Thaldren" and frame(ns, "party3").name:GetText() == "Captain Garrick", "names stay whole")
	local _, _, _, x, y = ns.Headers.party:GetPoint(1)
	assert(x == 0 and y == 0, "the party header keeps its corner")
	noErrors(env, K)
end
collectgarbage()

-- The bar fills with missing health, prediction follows the missing fill's edge, and off restores both.
do
	local env, K, ns = G.New({})
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	local fill = f.health:GetStatusBarTexture()
	write(env, K, "health.missing", true)
	assert(f.missingFill and f.health:GetReverseFill() == true and f.health.lossOn == false, "the bar fills from its end, with no loss band")
	assert(value(env, f.health) == 50, "it carries the missing health: " .. tostring(value(env, f.health)))
	local point, relative, relativePoint = f.heals:GetPoint(1)
	assert(point == "TOPLEFT" and relative == fill and relativePoint == "TOPLEFT", "incoming heals start at the missing fill's edge")
	point, relative, relativePoint = f.healAbsorbs:GetPoint(1)
	assert(point == "TOPRIGHT" and relative == fill and relativePoint == "TOPLEFT", "heal absorbs eat back from that edge")
	env._roster.units.party1.health = 30
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(value(env, f.health) == 70, "UNIT_HEALTH follows the missing health")
	write(env, K, "prediction.overshield", true)
	assert(select(3, f.overClip:GetPoint(2)) == "BOTTOMLEFT", "the overshield clips to the current health")
	write(env, K, "prediction.overshield", false)
	write(env, K, "health.orientation", "VERTICAL")
	point, relative, relativePoint = f.heals:GetPoint(1)
	assert(point == "BOTTOMLEFT" and relative == f.health:GetStatusBarTexture() and relativePoint == "BOTTOMLEFT", "a vertical bar's heals start at the edge too")
	write(env, K, "health.orientation", "HORIZONTAL")
	write(env, K, "health.missing", false)
	assert(not f.missingFill and f.health:GetReverseFill() == false and f.health.lossOn == true, "off restores the fill and the loss band")
	assert(value(env, f.health) == 30, "and the bar carries the health again")
	assert(select(3, f.heals:GetPoint(1)) == "TOPRIGHT", "heals return after the health")
	noErrors(env, K)
end
collectgarbage()

-- A client without UnitHealthMissing keeps the plain fill.
do
	local env, K, ns = G.New({ setup = function(e) e.UnitHealthMissing = nil end })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "health.missing", true)
	local f = frame(ns, "party1")
	assert(not f.missingFill and #W.Calls(f.health, "SetReverseFill") == 0, "no API, no missing fill")
	noErrors(env, K)
end
collectgarbage()

-- Striped shields and heal absorbs with their backing, the shield glow, lost maximum health and the heal absorb line's thickness.
do
	local env, K, ns = G.New({})
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	local a = ns.Settings.current.prediction.absorbColor.a
	write(env, K, "prediction.absorbStyle", "STRIPES")
	local stripes = f.absorbs.stripes
	assert(stripes and stripes:IsShown() and stripes._state.Atlas[1] == "RaidFrame-Shield-Overlay", "shields take Blizzard's stripes")
	assert(select(2, stripes:GetPoint(1)) == f.absorbs:GetStatusBarTexture(), "laid on the shield's fill")
	write(env, K, "prediction.backing", 0.5)
	assert(near(f.absorbs.colorRGBA[4], a * 0.5), "the backing opacity thins the fill under them")
	write(env, K, "prediction.healAbsorbStyle", "STRIPES")
	assert(f.healAbsorbs.stripes:IsShown() and f.healAbsorbs.stripes._state.Atlas[1] == "RaidFrame-Absorb-Overlay", "heal absorbs too")
	write(env, K, "prediction.overshield", true)
	assert(f.overshield.stripes and f.overshield.stripes:IsShown(), "and the overshield follows the absorb style")
	write(env, K, "prediction.absorbStyle", "SOLID")
	assert(not stripes:IsShown() and near(f.absorbs.colorRGBA[4], a), "solid restores the fill's own opacity")
	write(env, K, "prediction.healAbsorbStyle", "SOLID")
	write(env, K, "prediction.overshield", false)
	assert(not f.healAbsorbs.stripes:IsShown(), "and hides the heal absorb stripes")

	write(env, K, "prediction.glow", true)
	assert(f.shieldGlow and f.shieldGlow:IsShown() and plain(env, f.shieldGlow:GetAlpha()) == 1, "a shield past the missing health lights the glow")
	env._roster.units.party1.absorb = 30
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "party1")
	assert(plain(env, f.shieldGlow:GetAlpha()) == 0, "a smaller shield puts it out")
	for _, key in ipairs({ "prediction.heals", "prediction.absorbs", "prediction.healAbsorbs" }) do write(env, K, key, false) end
	env._roster.units.party1.absorb = 90
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "party1")
	assert(plain(env, f.shieldGlow:GetAlpha()) == 1, "the glow does not need heals or absorbs on")
	for _, key in ipairs({ "prediction.heals", "prediction.absorbs", "prediction.healAbsorbs" }) do write(env, K, key, true) end
	write(env, K, "health.orientation", "VERTICAL")
	assert(not f.shieldGlow:IsShown(), "a vertical bar has no glow")
	write(env, K, "health.orientation", "HORIZONTAL")
	write(env, K, "prediction.glow", false)
	assert(not f.shieldGlow:IsShown(), "off hides it")

	write(env, K, "prediction.maxLoss", "STRIPES")
	assert(f.maxLoss and f.maxLoss:IsShown() and value(env, f.maxLoss) == 0.2 and f.maxLoss:GetReverseFill() == true, "lost maximum health fills back from the end")
	assert(f.maxLoss.stripes:IsShown(), "striped")
	env._roster.units.party1.maxLoss = 0.35
	env.FireEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "party1")
	assert(value(env, f.maxLoss) == 0.35, "and follows its event")
	write(env, K, "prediction.maxLoss", "SOLID")
	assert(not f.maxLoss.stripes:IsShown() and near(f.maxLoss.colorRGBA[4], 0.6), "solid takes its colour's opacity")
	write(env, K, "prediction.maxLoss", "OFF")
	assert(not f.maxLoss:IsShown(), "off hides it")

	write(env, K, "prediction.healAbsorbLine", true)
	write(env, K, "prediction.healAbsorbLines", 5)
	local px = K.Widgets.Border(f)
	assert(near(f.healAbsorbLine.opts.height, 5 * px) and near(f.shield.opts.height, 2 * px), "the heal absorb line has its own thickness")
	write(env, K, "prediction.shieldLines", 20)
	assert(near(f.shield.opts.height, 20 * px), "the shield line reaches 20 pixels")
	noErrors(env, K)
end
collectgarbage()

-- A client without the stripes or glow atlases keeps the plain bars.
do
	local env, K, ns = G.New({ setup = function(e) e.C_Texture.GetAtlasInfo = function() return nil end end })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "prediction.absorbStyle", "STRIPES")
	write(env, K, "prediction.glow", true)
	local f = frame(ns, "party1")
	assert(f.absorbs.stripes == nil and f.shieldGlow == nil, "no atlas, nothing made")
	noErrors(env, K)
end
collectgarbage()

-- The threat edge, the second hover line and the name format.
do
	local env, K, ns = G.New({})
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local tank, dps = frame(ns, "party1"), frame(ns, "party3")
	write(env, K, "threat.edge", true)
	assert(tank.tileless and tank.threat:IsShown() and tank.threatEdge == nil, "a row without a tile keeps the threat border")
	write(env, K, "party.portrait", true)
	local r, g, b = K.Theme.ThreatColor(3)
	local edge = tank.chrome.edge
	assert(not tank.threat:IsShown() and tank.threatEdge and near(edge[1], r) and near(edge[2], g) and near(edge[3], b), "the frame's own edge takes the threat colour")
	env._roster.units.party1.threat = 0
	env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "party1")
	assert(tank.threatEdge == nil and not tank.threat:IsShown(), "losing aggro restores the edge")
	env._roster.units.party1.threat = 3
	env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "party1")
	write(env, K, "threat.edge", false)
	assert(tank.threatEdge == nil and tank.threat:IsShown(), "off brings the border back")
	write(env, K, "party.portrait", false)

	write(env, K, "accent.hoverLines", 2)
	assert(tank.hoverLine and tank.hoverLine[1]:IsShown() ~= false, "two hover lines make the inner line")
	tank.hoverT = 1
	ns.Style.PaintEdge(tank)
	assert(near(select(4, tank.hoverLine[1]:GetVertexColor()), 0.6), "hovered, the inner line takes the highlight colour")
	tank.hoverT = 0
	ns.Style.PaintEdge(tank)
	assert(near(select(4, tank.hoverLine[1]:GetVertexColor()), 0), "and fades with the edge")
	write(env, K, "accent.hoverLines", 1)
	assert(tank.hoverLine[1]:IsShown() == false, "one line hides it")

	write(env, K, "party.nameFormat", "FIRST")
	assert(dps.name:GetText() == "Captain" and tank.name:GetText() == "Thaldren", "first word")
	write(env, K, "party.nameFormat", "LAST")
	assert(dps.name:GetText() == "Garrick", "last word")
	write(env, K, "party.nameFormat", "ABBR")
	assert(dps.name:GetText() == "C. Garrick", "initials and last word: " .. tostring(dps.name:GetText()))
	write(env, K, "party.nameFormat", "FULL")
	assert(dps.name:GetText() == "Captain Garrick", "whole name again")
	noErrors(env, K)
end
collectgarbage()

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
	assert(tank.threatEdge and not tank.threat:IsShown(), "the portrait tank's tile edge takes the threat colour")
	local raid = preview.raidFrames
	local _, _, _, x1 = raid[1]:GetPoint(1)
	local _, _, _, x3, y3 = raid[3]:GetPoint(1)
	assert(near(x1, x3) and y3 < 0, "merged, the four raid samples run on in one column")
	noErrors(env, K)
end

print("groupframes parity round 3c ok: defaults, missing fill, stripes, glow, lost maximum health, line thickness, threat edge, hover lines, name format, merged groups, raid sizes, small raids, centre when solo and the preview")
