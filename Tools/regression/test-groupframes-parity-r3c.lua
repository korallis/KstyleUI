-- test-groupframes-parity-r3c.lua: EllesmereUI parity round 3c: a v0.2.8 profile keeps every default and makes nothing new; each new bar, highlight and name option switched on applies, follows its events and switches back. Layout and the preview are in test-groupframes-parity-r3c-layout.lua.
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
	assert(tank.name:GetText() == "Thaldren", "a short name stays whole")
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
	local fitted = dps.name:GetText()
	write(env, K, "threat.edge", true)
	assert(tank.tileless and tank.threat:IsShown() and tank.threatEdge == nil, "a row without a tile keeps the threat border")
	write(env, K, "threat.edge", false)
	assert(tank.threatEdge == nil and tank.threat:IsShown(), "off keeps the border")

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
	assert(dps.name:GetText() == fitted, "the full name's fit again")
	noErrors(env, K)
end
collectgarbage()

print("groupframes parity round 3c ok: defaults, missing fill, stripes, glow, lost maximum health, line thickness, threat edge, hover lines and name format")
