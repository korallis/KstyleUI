-- test-actionbars-medallions-jewels.lua: the Medallions hub's resource jewels at 1920x1080, 2560x1440, 5120x1440 and 3840x2160: five gilt-set gems across the top of the rune ring for a rogue, a cat-form druid, a paladin and a warlock, none for other classes, a caster-form druid, under Frames or with Crest resource jewels off; each gem is a one-point status bar fed the raw value, so a secret value lights them without Lua comparing it; the count follows UnitPowerMax within the five-jewel arc, a zero max hides them, points moved to another target clear them, other powers leave them alone, and nothing listens for power without jewels to light.
local AB = dofile("Tools/regression/actionbars_env.lua")

local COMBO, HOLY, SHARDS, ENERGY, MANA = 4, 9, 7, 3, 0
local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }

local function New(class, power, size)
	size = size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._points, e._max, e._powerType = 0, nil, power or MANA
			e.GetComboPoints = function(unit, target)
				assert(unit == "player" and target == "target", "combo points are the player's on the target")
				return e._points
			end
			e.UnitPower = function(unit, kind)
				assert(unit == "player", "the jewels read the player's power")
				e._askedPower = kind
				return e._points
			end
			e.UnitPowerMax = function(unit, kind)
				e._askedMax = kind
				return e._max or 5
			end
			e.UnitPowerType = function()
				return e._powerType
			end
		end,
	})
	K.Options.Write("Rest", "enabled", false)
	AB.Enable(env, K)
	-- The jewels alone: a rogue's crown of blades listens too, and test-actionbars-medallions-crown covers it; the clean
	-- screen, off above, reads the main power, and test-layout-rest covers it.
	local profile = K.Store.Profile()
	profile.UnitFrames = profile.UnitFrames or {}
	profile.UnitFrames.resource = { classPips = false }
	env.RunTimers()
	return env, K, ns
end

local function Shown(ns)
	local n = 0
	for _, jewel in ipairs(ns.SlabJewels.state.jewels) do
		if jewel.holder:IsShown() then
			n = n + 1
		end
	end
	return n
end

local function Lit(ns)
	local n = 0
	for i, jewel in ipairs(ns.SlabJewels.state.jewels) do
		if jewel.holder:IsShown() then
			local low, high = jewel.gem:GetMinMaxValues()
			assert(low == i - 1 and high == i, "gem " .. i .. " is a one-point bar from " .. (i - 1) .. " to " .. i)
			local value = jewel.gem:GetValue()
			if value >= high then
				n = n + 1
			end
		end
	end
	return n
end

-- Only the jewels listen for frequent power in the action bars env.
local function Frequent(env)
	local n = 0
	for _, frame in ipairs(env._frames) do
		if frame._events.UNIT_POWER_FREQUENT then
			n = n + 1
		end
	end
	return n
end

local function Arc(ns, at)
	local _, cy = ns.Slab.hub:GetCenter()
	local jewels = ns.SlabJewels.state.jewels
	for i, jewel in ipairs(jewels) do
		local x, y = jewel.holder:GetCenter()
		assert(y > cy, at .. "jewel " .. i .. " of " .. #jewels .. " sits on the top arc of the ring")
		if i > 1 then
			assert(x > jewels[i - 1].holder:GetCenter(), at .. "the jewels fill from left to right")
		end
	end
end

local function Writes(ns)
	local count = { 0 }
	for _, jewel in ipairs(ns.SlabJewels.state.jewels) do
		for _, bar in ipairs({ jewel.gem, jewel.core, jewel.halo }) do
			local set = bar.SetValue
			bar.SetValue = function(...)
				count[1] = count[1] + 1
				return set(...)
			end
		end
	end
	return count
end

for _, size in ipairs(SIZES) do
	local at = size[1] .. "x" .. size[2] .. ": "
	local env, K, ns = New("ROGUE", ENERGY, size)
	local hub, jewels = ns.Slab.hub, ns.SlabJewels.state.jewels
	assert(hub:IsShown(), at .. "the hub is up under Medallions")
	assert(Shown(ns) == 5 and Lit(ns) == 0 and env._askedMax == COMBO, at .. "a rogue shows five empty combo jewels")
	Arc(ns, at)
	local cx, cy = hub:GetCenter()
	local mx, my = jewels[3].holder:GetCenter()
	assert(math.abs(mx - cx) < 0.5 and my > cy, at .. "the middle jewel crowns the ring")
	local fx, fy = jewels[1].holder:GetCenter()
	env._points = 3
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(Lit(ns) == 3, at .. "a new target's three combo points light three jewels")
	env._points = 0
	env.FireEvent("COMBO_TARGET_CHANGED")
	assert(Lit(ns) == 0, at .. "points moved off the target clear the jewels")
	env._points = 3
	env.FireEvent("PLAYER_TARGET_CHANGED")
	local writes = Writes(ns)
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "ENERGY")
	assert(writes[1] == 0 and Lit(ns) == 3, at .. "an energy tick leaves the combo jewels alone")
	env._points = 5
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	assert(Lit(ns) == 5 and writes[1] == 15, at .. "a combo point update lights every jewel")
	env._max = 10
	env.FireEvent("UNIT_MAXPOWER", "player", "COMBO_POINTS")
	assert(Shown(ns) == 10, at .. "a maximum of ten shows ten jewels")
	Arc(ns, at)
	local tx, ty = jewels[1].holder:GetCenter()
	assert(math.abs(tx - fx) < 0.01 and math.abs(ty - fy) < 0.01, at .. "ten jewels span the same arc as five")
	K.Options.Write("ActionBars", "crestJewels", false)
	env.RunTimers()
	assert(hub:IsShown() and Shown(ns) == 0 and Frequent(env) == 0, at .. "Crest resource jewels off leaves the crest as it was")
	K.Options.Write("ActionBars", "crestJewels", true)
	env.RunTimers()
	assert(Shown(ns) == 10 and Frequent(env) == 1, at .. "turning them back on restores the jewels")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(Shown(ns) == 0, at .. "Frames has no hub and no jewels")
	assert(Frequent(env) == 0, at .. "the jewels stop listening without the hub")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("ROGUE", ENERGY)
	env._points = env.Secret(2)
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	for _, jewel in ipairs(ns.SlabJewels.state.jewels) do
		assert(jewel.gem:GetValue() == env._points, "a secret value goes to the gem as it is, for the engine to compare")
	end
	local r, g, b = ns.SlabJewels.state.jewels[1].gem:GetStatusBarColor()
	local er, eg, eb = K.Tokens.Color("jewelCombo")
	assert(math.abs(r - er) < 1e-3 and math.abs(g - eg) < 1e-3 and math.abs(b - eb) < 1e-3, "combo jewels are embers")
	env.UnitClass = nil
	env.FireEvent("UNIT_MAXPOWER", "player", "COMBO_POINTS")
	assert(Shown(ns) == 0 and Frequent(env) == 0, "a client without UnitClass shows no jewels")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("WARRIOR", 1)
	assert(Shown(ns) == 0, "a warrior has no jewel resource")
	assert(Frequent(env) == 0, "a warrior's hub listens for no power")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("DRUID", MANA)
	assert(Shown(ns) == 0 and Frequent(env) == 0, "a caster-form druid shows no jewels and listens for no power")
	env._powerType = ENERGY
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(Shown(ns) == 5 and Frequent(env) == 1, "cat form shows the combo jewels")
	env._powerType = MANA
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(Shown(ns) == 0 and Frequent(env) == 0, "leaving cat form hides them")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("PALADIN", MANA)
	assert(Shown(ns) == 5 and env._askedMax == HOLY, "a paladin's jewels count holy power")
	env._points = 2
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "HOLY_POWER")
	assert(Lit(ns) == 2 and env._askedPower == HOLY, "holy power lights the jewels")
	env._max = 3
	env.FireEvent("UNIT_MAXPOWER", "player", "HOLY_POWER")
	assert(Shown(ns) == 3, "a smaller maximum shows fewer jewels")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("WARLOCK", MANA)
	assert(Shown(ns) == 5 and env._askedMax == SHARDS, "a warlock's jewels count soul shards")
	env._points = 4
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "SOUL_SHARDS")
	assert(Lit(ns) == 4, "soul shards light the jewels")
	env._max = 0
	env.FireEvent("UNIT_MAXPOWER", "player", "SOUL_SHARDS")
	assert(Shown(ns) == 0, "a client without a soul shard power hides the jewels")
	env._max = env.Secret(5)
	env.FireEvent("UNIT_MAXPOWER", "player", "SOUL_SHARDS")
	assert(Shown(ns) == 5, "a secret maximum keeps five jewels")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars medallions jewels ok")
