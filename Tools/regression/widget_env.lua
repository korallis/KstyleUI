-- widget_env.lua: load the core with its widget kit into a stub environment and drive frames like a player.
--
--   local W = dofile("Tools/regression/widget_env.lua")
--   local env, K = W.New()          -- core loaded, saved data loaded and PLAYER_LOGIN fired
--   local button = K.Widgets.Button(K.Scale.Root(), { text = "OK" })
--   W.Enter(button); W.Settle(env)  -- hover, then run tweens to their end

local CoreEnv = dofile("Tools/regression/core_env.lua")

local W = {}
W.CoreEnv = CoreEnv

-- New(opts) -> env, KstyleUI. opts: the CoreEnv.New options, plus
--   layout   true to install a KstyleUI.Layout stand-in that records Register calls in env._layout
--   boot     false to skip ADDON_LOADED and PLAYER_LOGIN
function W.New(opts)
	opts = opts or {}
	local setup = opts.setup
	opts.setup = function(env)
		env.UnitClass = function()
			return "Hunter", "HUNTER", 3
		end
		env._errors = env._errors or {}
		if setup then
			setup(env)
		end
	end
	local env, K = CoreEnv.New(opts)
	if opts.layout then
		env._layout = {}
		K.Layout = K.Layout or {}
		K.Layout.Register = function(frame, key, position, layoutOpts)
			env._layout[#env._layout + 1] = { frame = frame, key = key, position = position, opts = layoutOpts }
		end
	end
	if opts.boot ~= false then
		CoreEnv.Boot(env)
	end
	return env, K
end

-- The frames whose OnUpdate is set, such as the tween driver while it runs.
local function updating(env)
	local out = {}
	for _, frame in ipairs(env._frames) do
		if frame:GetScript("OnUpdate") then
			out[#out + 1] = frame
		end
	end
	return out
end

function W.Tick(env, dt)
	for _, frame in ipairs(updating(env)) do
		frame:GetScript("OnUpdate")(frame, dt or 0.016)
	end
end

-- Settle(env) steps every OnUpdate in 16 ms frames until none is left, at most 1000 frames.
function W.Settle(env)
	for _ = 1, 1000 do
		if #updating(env) == 0 then
			return
		end
		W.Tick(env, 0.016)
	end
	error("Settle: an OnUpdate kept running for 1000 frames")
end

local function run(frame, script, ...)
	local fn = frame:GetScript(script)
	if fn then
		fn(frame, ...)
	end
end

function W.Enter(frame)
	run(frame, "OnEnter", false)
end

function W.Leave(frame)
	run(frame, "OnLeave", false)
end

function W.Down(frame, button)
	run(frame, "OnMouseDown", button or "LeftButton")
end

function W.Up(frame, button)
	run(frame, "OnMouseUp", button or "LeftButton")
end

-- Click(frame) presses and releases the left button over the frame, then runs OnClick.
function W.Click(frame, button)
	W.Down(frame, button)
	W.Up(frame, button)
	if frame:IsEnabled() ~= false then
		run(frame, "OnClick", button or "LeftButton", false)
	end
end

function W.Key(frame, key)
	run(frame, "OnKeyDown", key)
end

function W.Color(region)
	return region:GetVertexColor()
end

function W.Near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

-- SameColor(region, r, g, b, a) is true when the region's vertex colour is r, g, b and, if given, a.
function W.SameColor(region, r, g, b, a)
	local cr, cg, cb, ca = region:GetVertexColor()
	if not (W.Near(cr, r) and W.Near(cg, g) and W.Near(cb, b)) then
		return false
	end
	return a == nil or W.Near(ca or 1, a)
end

-- SameRGB(region, r, g, b) compares the colour only, for regions drawn at a token's colour with their own alpha.
function W.SameRGB(region, r, g, b)
	return W.SameColor(region, r, g, b)
end

-- Calls(object, method) -> the list of argument packs the object's method got, oldest first.
function W.Calls(object, method)
	local out = {}
	for _, call in ipairs(object._calls) do
		if call.method == method then
			out[#out + 1] = call.args
		end
	end
	return out
end

function W.LastCall(object, method)
	local calls = W.Calls(object, method)
	return calls[#calls]
end

-- Regions(frame, objectType) -> the regions made on the frame, of one type when given.
function W.Regions(frame, objectType)
	local out = {}
	for _, region in ipairs({ frame:GetRegions() }) do
		if not objectType or region:GetObjectType() == objectType then
			out[#out + 1] = region
		end
	end
	return out
end

-- Text(frame) -> the texts of the font strings made on the frame, in creation order.
function W.Texts(frame)
	local out = {}
	for _, region in ipairs(W.Regions(frame, "FontString")) do
		out[#out + 1] = region:GetText()
	end
	return out
end

W.Raises = CoreEnv.Raises

return W
