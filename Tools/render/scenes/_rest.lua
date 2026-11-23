-- _rest.lua: RENDER_REST draws the clean screen through the addon in each module's environment that holds a resting panel: rest (the panels RENDER_REST_T seconds into their fall, or settled), target (at rest, then a target, RENDER_REST_T seconds into the return), hover (at rest, then the pointer on bar 1, RENDER_REST_T seconds in) or off (the switch off, which must draw as staging does); unset, every scene draws the panels awake.
local Rest = {}

local MODES = { rest = true, target = true, hover = true, off = true }

function Rest.Mode()
	local mode = os.getenv("RENDER_REST")
	if not mode or mode == "" then
		return nil
	end
	assert(MODES[mode], "RENDER_REST must be rest, target, hover or off")
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

-- Apply(env, tick) -> a log line, or nil when RENDER_REST is unset or the environment holds no resting panel.
function Rest.Apply(env, tick)
	local mode = Rest.Mode()
	local K = env.KstyleUI
	if not mode or not (K and K.Layout and K.Layout.Rest) or not Holds(K) then
		return nil
	end
	if mode == "off" then
		return "rest: the clean screen is off"
	end
	local t = tonumber(os.getenv("RENDER_REST_T") or "")
	local exists, casting = env.UnitExists, env.UnitCastingInfo
	env.UnitExists = function(unit)
		return unit ~= "target" and exists(unit)
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
	local hovered
	for _, frame in ipairs(el and { el.frame:GetChildren() } or {}) do
		for _, child in ipairs({ frame:GetChildren() }) do
			if not hovered and child:GetScript("OnEnter") then
				hovered = child
			end
		end
	end
	if hovered then
		hovered:GetScript("OnEnter")(hovered, false)
		Run(env, K, tick, t)
	end
	return hovered and ("rest: the pointer on bar 1 brings the action bars back" .. (t and (", " .. t .. " s in") or "")) or nil
end

-- Awake(env): unless RENDER_REST asks for rest, target or hover, Scene.Build switches the clean screen off and lights
-- any resting panel at once, so a scene's own timers never draw a rest it did not ask for.
function Rest.Awake(env)
	local mode = Rest.Mode()
	local K = env.KstyleUI
	local rest = K and K.Layout and K.Layout.Rest
	if (mode and mode ~= "off") or not (rest and rest.Listen and K.Store.IsLoaded()) then
		return
	end
	local wake = rest.WAKE
	rest.WAKE = 0
	K.Store.Module("Rest").enabled = false
	rest.Listen()
	rest.WAKE = wake
	for _, keys in pairs(rest.PANELS) do
		for _, key in ipairs(keys) do
			K.Layout.RefreshAlpha(key, 0)
		end
	end
end

return Rest
