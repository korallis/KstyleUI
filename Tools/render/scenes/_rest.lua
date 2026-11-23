-- _rest.lua: RENDER_REST draws the clean screen through the addon in each module's environment that holds a resting panel: rest (the panels RENDER_REST_T seconds into their fall, or settled), target (at rest, then a target, RENDER_REST_T seconds into the return) or hover (at rest, then the pointer on a bar 1 button, RENDER_REST_T seconds in). Unset, Common.ForceScreen boots every scene with the clean screen off.
local Rest = {}

local MODES = { rest = true, target = true, hover = true }

function Rest.Mode()
	local mode = os.getenv("RENDER_REST")
	if not mode or mode == "" then
		return nil
	end
	assert(MODES[mode], "RENDER_REST must be rest, target or hover")
	return mode
end

local function Holds(K)
	for _, keys in pairs(K.Layout.Rest.PANELS) do
		for _, key in ipairs(keys) do
			if K.Layout.Element(key) then
				return true
			end
		end
	end
	return false
end

local function Run(env, K, tick, seconds)
	if seconds then
		tick(env, seconds)
	else
		K.Motion.Settle()
	end
end

-- Target(frame, depth) -> the first hooked, mouse-enabled descendant within depth levels: a frame the pointer hits.
local function Target(frame, depth)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:GetScript("OnEnter") and child:IsMouseEnabled() then
			return child
		end
		local found = depth > 1 and Target(child, depth - 1)
		if found then
			return found
		end
	end
end

-- Apply(env, tick) -> a log line, or nil when RENDER_REST is unset or the environment holds no resting panel.
function Rest.Apply(env, tick)
	local mode = Rest.Mode()
	local K = env.KstyleUI
	if not mode or not (K and K.Layout and K.Layout.Rest) or not Holds(K) then
		return nil
	end
	local t = tonumber(os.getenv("RENDER_REST_T") or "")
	local exists, casting, power = env.UnitExists, env.UnitCastingInfo, env.UnitPower
	env.UnitExists = function(unit)
		return unit ~= "target" and exists(unit)
	end
	if power and env.UnitPowerMax then
		env.UnitPower = function(unit, kind)
			if unit == "player" and kind == nil then
				return env.UnitPowerMax(unit)
			end
			return power(unit, kind)
		end
	end
	env.UnitCastingInfo = nil
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.RunTimers()
	assert(K.Layout.Rest.Quiet(), "RENDER_REST: the panels did not come to rest")
	if mode == "rest" then
		Run(env, K, tick, t)
		return "rest: the panels at rest" .. (t and (", " .. t .. " s into the fall") or "")
	end
	K.Motion.Settle()
	if mode == "target" then
		env.UnitExists = function(unit)
			return unit == "target" or exists(unit)
		end
		env.UnitCastingInfo = casting
		env.FireEvent("PLAYER_TARGET_CHANGED")
		Run(env, K, tick, t)
		return "rest: a target brings the panels back" .. (t and (", " .. t .. " s in") or "")
	end
	local el = K.Layout.Element("actionbars.bar1")
	local button = el and Target(el.frame, 3)
	if not button then
		return nil
	end
	button:GetScript("OnEnter")(button, false)
	Run(env, K, tick, t)
	return "rest: the pointer on " .. (button:GetName() or "a bar 1 button") .. " brings the action bars back" .. (t and (", " .. t .. " s in") or "")
end

return Rest
