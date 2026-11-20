-- test-actionbars-medallions-jewels.lua: the Medallions hub's resource jewels: five gilt-set gems across the top of the rune ring for a rogue, a cat-form druid, a paladin and a warlock, none for other classes, a caster-form druid or under Frames; each gem is a one-point status bar fed the raw value, so a secret value lights them without Lua comparing it; the count follows UnitPowerMax and a zero max hides them.
local AB = dofile("Tools/regression/actionbars_env.lua")

local COMBO, HOLY, SHARDS, ENERGY, MANA = 4, 9, 7, 3, 0

local function New(class, power)
	local env, K, ns = AB.New({
		class = class,
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
	AB.Enable(env, K)
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(K.HudStyle.Current() == "medallions")
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

do
	local env, K, ns = New("ROGUE", ENERGY)
	local hub = ns.Slab.hub
	assert(hub:IsShown(), "the hub is up under Medallions")
	assert(Shown(ns) == 5 and Lit(ns) == 0, "a rogue shows five empty jewels")
	local cx, cy = hub:GetCenter()
	for i, jewel in ipairs(ns.SlabJewels.state.jewels) do
		local x, y = jewel.holder:GetCenter()
		assert(y > cy, "jewel " .. i .. " sits on the top arc of the ring")
		if i > 1 then
			local px = ns.SlabJewels.state.jewels[i - 1].holder:GetCenter()
			assert(x > px, "the jewels fill from left to right")
		end
	end
	local _, top = ns.SlabJewels.state.jewels[3].holder:GetCenter()
	assert(math.abs(ns.SlabJewels.state.jewels[3].holder:GetCenter() - cx) < 0.5 and top > cy, "the middle jewel crowns the ring")
	env._points = 3
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(Lit(ns) == 3, "a new target's three combo points light three jewels")
	env._points = 5
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	assert(Lit(ns) == 5, "a power update lights every jewel")
	env._points = env.Secret(2)
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	for _, jewel in ipairs(ns.SlabJewels.state.jewels) do
		assert(jewel.gem:GetValue() == env._points, "a secret value goes to the gem as it is, for the engine to compare")
	end
	local r, g, b = ns.SlabJewels.state.jewels[1].gem:GetStatusBarColor()
	local er, eg, eb = K.Tokens.Color("jewelCombo")
	assert(math.abs(r - er) < 1e-3 and math.abs(g - eg) < 1e-3 and math.abs(b - eb) < 1e-3, "combo jewels are embers")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(Shown(ns) == 0, "Frames has no hub and no jewels")
	assert(not ns.SlabJewels.state.listening, "the jewels stop listening without the hub")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("WARRIOR", 1)
	assert(Shown(ns) == 0, "a warrior has no jewel resource")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("DRUID", MANA)
	assert(Shown(ns) == 0, "a caster-form druid shows no jewels")
	env._powerType = ENERGY
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(Shown(ns) == 5, "cat form shows the combo jewels")
	env._powerType = MANA
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(Shown(ns) == 0, "leaving cat form hides them")
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
	env._max = 0
	env.FireEvent("UNIT_MAXPOWER", "player", "SOUL_SHARDS")
	assert(Shown(ns) == 0, "a client without a soul shard power hides the jewels")
	env._max = env.Secret(5)
	env.FireEvent("UNIT_MAXPOWER", "player", "SOUL_SHARDS")
	assert(Shown(ns) == 5, "a secret maximum keeps five jewels")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars medallions jewels ok")
