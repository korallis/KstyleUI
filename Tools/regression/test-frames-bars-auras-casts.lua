-- test-frames-bars-auras-casts.lua: parity batch 3 options keep v0.2.8 defaults and regions, then write and apply heal absorbs, level difficulty colour, group aura stacks and timers, name letters and casting-enemy colour.
local U = dofile("Tools/regression/unitframes_env.lua")
local G = dofile("Tools/regression/group_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local function saved(module, own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [module] = own } }, characters = {}, layouts = {} }
end

local function write(env, K, module, key, value)
	K.Options.Write(module, key, value)
	env.RunTimers()
	local got = K.Options.Read(module, key)
	if type(value) == "table" then assert(got.r == value.r and got.g == value.g and got.b == value.b, key)
	else assert(got == value, key) end
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function sameColor(r, g, b, wr, wg, wb, what)
	assert(near(r, wr) and near(g, wg) and near(b, wb), what .. ": got " .. tostring(r) .. ", " .. tostring(g) .. ", " .. tostring(b))
end

local function textIs(text, wr, wg, wb, what)
	local r, g, b = text:GetTextColor()
	sameColor(r, g, b, wr, wg, wb, what)
end

-- Unit frames: heal absorbs and level difficulty colour.
do
	local env, K, ns = U.New({ saved = saved("UnitFrames", { target = { healPrediction = true } }) })
	U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, power = 30, powerMax = 100, canAttack = true, healAbsorb = 500 })
	local view = ns.Frames.Get("target").views[1]
	for _, kind in ipairs(U.KINDS) do
		assert(K.Options.Read("UnitFrames", kind .. ".healAbsorbs") == false and K.Options.Read("UnitFrames", kind .. ".levelDifficulty") == false,
			"v0.2.8 profiles keep heal absorbs and level difficulty colour off")
		assert(ns.Frames.Get(kind).views[1].healAbsorb == nil, "an old profile creates no heal-absorb bar")
	end
	local er, eg, eb = K.Tokens.Color("textEmphasis")
	local sr, sg, sb = K.Tokens.Color("steelLit")
	local plaque = view.medallion.levelText
	textIs(plaque, sr, sg, sb, "the level keeps its colour by default")

	write(env, K, "UnitFrames", "target.healAbsorbs", true)
	local eaten = assert(view.healAbsorb, "turning heal absorbs on creates the bar")
	assert(eaten:IsShown() and env.Reveal(eaten:GetValue()) == 500, "the bar shows the unit's heal absorbs")
	assert(eaten:GetReverseFill() == true and eaten:GetParent() == view.health, "heal absorbs eat back from the fill's end, inside the health bar")
	env._units.target.healAbsorb = 900
	env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "target")
	assert(env.Reveal(eaten:GetValue()) == 900, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED refreshes the bar")
	env._units.target.healAbsorb = 5000
	env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "target")
	assert(env.Reveal(eaten:GetValue()) == 3000, "heal absorbs are clamped to current health")
	local calc, sets, hides = view.calculator, 0, 0
	local set, hide = calc.SetHealAbsorbClampMode, eaten.Hide
	calc.SetHealAbsorbClampMode = function(self, mode) sets = sets + 1; return set(self, mode) end
	eaten.Hide = function(self) hides = hides + 1; return hide(self) end
	for _ = 1, 20 do env.FireEvent("UNIT_HEALTH", "target") end
	assert(sets == 0, "health updates do not reconfigure the calculator: " .. sets)
	write(env, K, "UnitFrames", "target.healPrediction", false)
	assert(not eaten:IsShown(), "the incoming heals master hides heal absorbs")
	write(env, K, "UnitFrames", "target.healPrediction", true)
	assert(eaten:IsShown(), "heal absorbs return with incoming heals")
	write(env, K, "UnitFrames", "target.healAbsorbs", false)
	assert(not eaten:IsShown(), "turning heal absorbs off hides the bar")
	hides = 0
	for _ = 1, 20 do env.FireEvent("UNIT_HEALTH", "target") end
	assert(hides == 0, "health updates do not hide a hidden bar again: " .. hides)
	calc.SetHealAbsorbClampMode, eaten.Hide = set, hide

	env.GetCreatureDifficultyColor = function() return { r = 1, g = 0.1, b = 0.1 } end
	write(env, K, "UnitFrames", "target.levelDifficulty", true)
	local wr, wg, wb = K.Theme.Brighten(1, 0.1, 0.1)
	textIs(plaque, wr, wg, wb, "an enemy's level takes its difficulty colour")
	env._units.target.canAttack = false
	env.FireEvent("UNIT_LEVEL", "target")
	textIs(plaque, sr, sg, sb, "a friendly level keeps the normal colour")
	env._units.target.canAttack = true
	env.FireEvent("UNIT_FACTION", "target")
	textIs(plaque, wr, wg, wb, "UNIT_FACTION colours a unit that turns hostile")
	env._units.target.canAttack = false
	env.FireEvent("UNIT_FACTION", "target")
	textIs(plaque, sr, sg, sb, "UNIT_FACTION restores the colour of a unit that turns friendly")
	env._units.target.canAttack = true
	write(env, K, "UnitFrames", "target.levelDifficulty", false)
	textIs(plaque, sr, sg, sb, "turning the colour off restores the level's colour")

	write(env, K, "UnitFrames", "edit", "target")
	local pane = ns.Preview.Build(env.UIParent)
	local sample = pane.views.target
	textIs(sample.levelText, er, eg, eb, "the preview level keeps its colour by default")
	write(env, K, "UnitFrames", "target.levelDifficulty", true)
	pane:Refresh()
	textIs(sample.levelText, wr, wg, wb, "the preview shows the hostile sample's difficulty colour")
	write(env, K, "UnitFrames", "target.levelDifficulty", false)
	pane:Refresh()
	textIs(sample.levelText, er, eg, eb, "the preview level returns to its colour")

	env.RunTimers()
	view = ns.Frames.Get("target").views[1]
	assert(plaque:IsVisible() and not view.slabLevel:IsShown(), "Medallions shows the level on the plaque")
	local mr, mg, mb = K.Tokens.Color("labelMuted")
	textIs(plaque, sr, sg, sb, "the plaque level keeps its colour by default")
	write(env, K, "UnitFrames", "target.levelDifficulty", true)
	textIs(plaque, wr, wg, wb, "the plaque level takes the difficulty colour")
	textIs(view.slabLevel, wr, wg, wb, "so does the slab level when a layout shows it")
	write(env, K, "UnitFrames", "target.levelDifficulty", false)
	textIs(plaque, sr, sg, sb, "turning it off restores the plaque level")
	textIs(view.slabLevel, mr, mg, mb, "and the muted slab level")

	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Group frames: debuff stacks, time left and name letters.
do
	local env, K, ns = G.New({ saved = saved("GroupFrames", { auras = { enabled = true, swipe = false }, party = { width = 259 } }) })
	G.SetRoster(env, "party", { { name = "Thaldrenor", class = "WARRIOR" }, { name = "Sylaen", class = "DRUID" } })
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	assert(ns.Settings.Get("auras.stacks") == true and ns.Settings.Get("auras.timers") == false
		and ns.Settings.Get("party.nameChars") == 0 and ns.Settings.Get("raid.nameChars") == 0,
		"v0.2.8 profiles keep stacks on, timers off and whole names")
	local f
	ns.Unit.ForEach(function(frame) if frame.unit == "party1" then f = frame end end)
	assert(f and f.name:GetText() == "Thaldrenor", "the whole name shows by default")
	local group = f.auras._groups.debuffs
	A.Assign(env, f.auras, "debuffs", 1)
	env.RunTimers()
	local aura = group.active[1]._aura
	assert(aura.count and aura.count:GetAlpha() == 1 and aura.timer == nil, "stacks show and no timer region exists by default")

	write(env, K, "GroupFrames", "auras.stacks", false)
	assert(aura.count:GetAlpha() == 0, "turning stacks off hides the count")
	write(env, K, "GroupFrames", "auras.stacks", true)
	assert(aura.count:GetAlpha() == 1, "turning stacks on shows the count")
	assert(ns.Auras.Block(f, ns.Settings.current.party).rows == 2, "party debuffs fill two rows by default")
	write(env, K, "GroupFrames", "auras.timers", true)
	local timer = assert(aura.timer, "turning timers on binds a duration text")
	assert(timer:IsVisible(), "the time left shows")
	local point, _, toPoint = timer:GetPoint()
	assert(ns.Auras.Block(f, ns.Settings.current.party).rows == 1 and point == "TOP" and toPoint == "BOTTOM",
		"time left puts the party debuffs in one row, each time under its icon")
	local _, countSize = aura.count:GetFont()
	local _, timerSize = timer:GetFont()
	assert(timerSize == countSize, "time left and stacks share one size")
	write(env, K, "GroupFrames", "auras.timers", false)
	assert(not timer:IsVisible() and aura.timer == nil, "turning timers off hides the text and releases its binding")
	write(env, K, "GroupFrames", "auras.timers", true)
	assert(timer:IsVisible() and aura.timer == timer, "turning timers on again binds the same text")
	write(env, K, "GroupFrames", "auras.timers", false)

	write(env, K, "GroupFrames", "party.nameChars", 4)
	assert(f.name:GetText() == "Thal", "the name keeps its first four letters: " .. tostring(f.name:GetText()))
	local names, splits = 0, 0
	ns.Unit.ForEach(function(frame) if frame.kind == "party" and frame.unit and frame.rawName then names = names + 1 end end)
	debug.sethook(function()
		local info = debug.getinfo(2, "Sn")
		if info.name == "Chars" and info.source:find("Names.lua", 1, true) then splits = splits + 1 end
	end, "c")
	ns.Names.Apply(f)
	debug.sethook()
	assert(names > 1 and splits == names, "one party fit splits each name once: " .. splits .. " splits for " .. names .. " names")
	write(env, K, "GroupFrames", "party.nameChars", 0)
	assert(f.name:GetText() == "Thaldrenor", "0 restores the whole name")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Group frames: a raid tile keeps its dispel letter and stack count inside it (Medallions' 8-unit tiles bind no time left, as on staging); the preview shows both.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(10))
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	write(env, K, "GroupFrames", "auras.timers", true)
	local f
	ns.Unit.ForEach(function(frame) if frame.unit == "raid1" then f = frame end end)
	A.Assign(env, f.auras, "debuffs", 1)
	env.RunTimers()
	local button = f.auras._groups.debuffs.active[1]
	A.Dispel(button, "Magic")
	local aura, p = button._aura, ns.Auras.Parts(button)
	local size = button:GetWidth()
	local cPoint, cTo, cToPoint = aura.count:GetPoint()
	assert(cPoint == "BOTTOMRIGHT" and cTo == p.skin and cToPoint == "BOTTOMRIGHT", "the stack count stays inside the tile")
	for _, entry in ipairs(aura.dispel) do
		if entry.options.customDispelAssetMap then
			local lPoint, lTo = entry.texture:GetPoint()
			assert(entry.texture:IsShown() and lPoint == "TOPRIGHT" and lTo == p.skin and entry.texture:GetHeight() <= size, "the dispel letter stays inside the tile")
		end
	end

	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview("GroupFrames")(parent)
	local first = preview.partyFrames[1].sampleAuras[1]
	assert(first.count and first.count:IsShown() and first.count:GetText() == "3" and first.timer and first.timer:IsShown() and first.timer:GetText() == "12s",
		"the preview shows a stack count and the time left")
	write(env, K, "GroupFrames", "auras.stacks", false)
	write(env, K, "GroupFrames", "auras.timers", false)
	preview:Refresh()
	assert(not first.count:IsShown() and not first.timer:IsShown(), "the preview follows both switches")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Nameplates: casting enemies take their own colour while they cast.
do
	local env, K, ns = N.New({ saved = saved("Nameplates") })
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local function bar()
		local source = plate.health.fillSource
		if source then return source[1], source[2], source[3] end
		return plate.health:GetStatusBarColor()
	end
	local function barIs(wr, wg, wb, what)
		local r, g, b = bar()
		sameColor(r, g, b, wr, wg, wb, what)
	end
	assert(K.Options.Read("Nameplates", "types.casting") == false, "v0.2.8 profiles keep casting enemies uncoloured")
	local r0, g0, b0 = bar()
	N.Cast(env, "nameplate1", { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false })
	barIs(r0, g0, b0, "a cast keeps the bar colour by default")
	write(env, K, "Nameplates", "types.casting", true)
	local cr, cg, cb = K.Tokens.Color("gilt")
	barIs(cr, cg, cb, "a casting enemy takes the casting colour")
	write(env, K, "Nameplates", "types.castingColor", { r = 0.2, g = 0.4, b = 0.6 })
	barIs(0.2, 0.4, 0.6, "the casting colour applies")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1")
	barIs(r0, g0, b0, "the bar colour returns when the cast ends")
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183, channel = true })
	barIs(0.2, 0.4, 0.6, "channels colour too")
	write(env, K, "Nameplates", "types.casting", false)
	barIs(r0, g0, b0, "turning it off restores the bar colour mid-cast")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "nameplate1")
	write(env, K, "Nameplates", "cast.enabled", false)
	write(env, K, "Nameplates", "types.casting", true)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(not plate.cast:IsShown(), "cast bars stay hidden")
	barIs(0.2, 0.4, 0.6, "a casting enemy is coloured with cast bars hidden")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1")
	barIs(r0, g0, b0, "and loses the colour when the cast ends")
	N.Cast(env, "nameplate1", { name = "Drain", text = "Drain", texture = 136183, channel = true })
	barIs(0.2, 0.4, 0.6, "channels too")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "nameplate1")
	barIs(r0, g0, b0, "until the channel ends")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("frames bars, auras and casts ok: old profiles, heal absorbs, level colour, stacks, timers, name letters and casting colour")
