-- combattext_env.lua: load the core and KstyleUI_CombatText into a stub environment, as the game does, and fire UNIT_COMBAT.
--
--   local CT = dofile("Tools/regression/combattext_env.lua")
--   local env, K, ns = CT.New()          -- core, saved data, the module's files, then PLAYER_LOGIN
--   CT.Enable(env, K)                    -- switch the module on
--   CT.Hit(env, "player", "WOUND", "", env.Secret(1234), 4)
--
-- The game functions the module calls and the shared stubs lack are faked here, so other modules'
-- tests never see them: GetTime (env._now), AbbreviateNumbers and BreakUpLargeNumbers (each returns
-- "short(<n>)" or "full(<n>)", and a secret for a secret, so a test sees which formatter ran and that
-- the amount reached it untouched), and C_NamePlate.GetNamePlateForUnit (env._plates[unit]).
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local CT = { W = W, CoreEnv = CoreEnv }

local files
function CT.Files()
	if not files then
		files = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_CombatText/") then
				files[#files + 1] = path
			end
		end
	end
	return files
end

local function formatter(env, label)
	return function(n)
		env._formatted[#env._formatted + 1] = label
		if env.issecretvalue(n) then
			return env.Secret(label .. "(" .. tostring(env.Reveal(n)) .. ")")
		end
		return label .. "(" .. tostring(n) .. ")"
	end
end

-- Fakes(env) adds each fake the environment lacks, so another module's test environment keeps its own.
function CT.Fakes(env)
	local function fill(name, value)
		if rawget(env, name) == nil then
			env[name] = value
		end
	end
	env._formatted = {}
	env._plates = {}
	fill("GetTime", function()
		return env._now
	end)
	fill("AbbreviateNumbers", formatter(env, "short"))
	fill("BreakUpLargeNumbers", formatter(env, "full"))
	fill("C_NamePlate", {
		GetNamePlateForUnit = function(unit)
			return env._plates[unit]
		end,
	})
	local words = {
		MISS = "Miss", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", ABSORB = "Absorb", RESIST = "Resist",
		IMMUNE = "Immune", EVADE = "Evade", DEFLECT = "Deflect", REFLECT = "Reflect", INTERRUPT = "Interrupt",
	}
	for name, word in pairs(words) do
		fill(name, word)
	end
	fill("DAMAGE_TEXT_FONT", "Fonts\\FRIZQT__.TTF")
end

-- New(opts) -> env, KstyleUI, ns (the module's addon table). opts: the widget_env options, plus
--   login   false to stop before PLAYER_LOGIN
--   before  function(env, K) that runs after the saved data loads and before the module's files run
function CT.New(opts)
	opts = opts or {}
	local setup = opts.setup
	local env, K = W.New({
		saved = opts.saved,
		width = opts.width,
		height = opts.height,
		boot = false,
		setup = function(e)
			CT.Fakes(e)
			if setup then
				setup(e)
			end
		end,
	})
	CoreEnv.LoadSaved(env)
	if opts.before then
		opts.before(env, K)
	end
	Load(CT.Files(), env)
	if opts.login ~= false then
		CoreEnv.Login(env)
		env.RunTimers()
	end
	return env, K, env._addons.KstyleUI_CombatText
end

-- Saved(settings) -> a KstyleUIDB whose Default profile holds the CombatText section given.
function CT.Saved(settings)
	return { version = 2, profiles = { Default = { CombatText = settings } }, characters = {} }
end

function CT.Enable(env, K)
	assert(K.Modules.Enable("CombatText"), "the switch could not change")
	env.RunTimers()
	assert(K.Modules.IsRunning("CombatText"), "CombatText did not start: " .. tostring(env._errors[1]))
end

function CT.Hit(env, unit, event, flag, amount, school)
	env.FireEvent("UNIT_COMBAT", unit, event, flag or "", amount, school or 1)
end

-- Shown(ns) -> the numbers on screen: the player's field first, then the frames', each oldest first.
function CT.Shown(ns)
	local out = {}
	for _, pool in ipairs({ ns.Module.pool, ns.Module.framePool }) do
		for _, number in ipairs(pool and pool.active or {}) do
			out[#out + 1] = number
		end
	end
	return out
end

-- On(ns, frame) -> the numbers anchored to frame, oldest first.
function CT.On(ns, frame)
	local out = {}
	for _, number in ipairs(CT.Shown(ns)) do
		local _, relative = number.frame:GetPoint(1)
		if relative == frame then
			out[#out + 1] = number
		end
	end
	return out
end

-- Running(env, K, name) registers a stand-in for another module, such as UnitFrames, and starts it.
function CT.Running(env, K, name)
	local registered = false
	for _, listed in ipairs(K.Modules.List()) do
		registered = registered or listed == name
	end
	if not registered then
		K.Modules.Register(CoreEnv.Module(name))
	end
	K.Modules.Enable(name)
	env.RunTimers()
	assert(K.Modules.IsRunning(name), name .. " did not start")
end

-- UnitHolder(env, K, key, module, units) -> holder, buttons: a Layout element like the ones KstyleUI_UnitFrames
-- and KstyleUI_GroupFrames build. units lists the unit attribute of each secure button. With group = true the
-- buttons sit in a header inside the holder, as SecureGroupHeaderTemplate makes them.
function CT.UnitHolder(env, K, key, module, units, group)
	local root = K.Scale.Root()
	local holder = env.CreateFrame("Frame", nil, root)
	local element = K.Setup.Layouts.Element(key)
	holder:SetSize(element.width, element.height)
	local parent = holder
	if group then
		parent = env.CreateFrame("Frame", nil, holder, "SecureGroupHeaderTemplate")
	end
	local buttons = {}
	for i, unit in ipairs(units) do
		local button = env.CreateFrame("Button", nil, parent, "SecureUnitButtonTemplate")
		button:SetSize(72, 40)
		button:SetAttribute("unit", unit)
		buttons[i] = button
	end
	K.Layout.Register(holder, key, K.Setup.Layouts.Default(key), { label = element.label, module = module })
	return holder, buttons
end

-- Plate(env, unit) -> a stand-in for Blizzard's nameplate base frame of a nameplate unit.
function CT.Plate(env, unit)
	local plate = env.CreateFrame("Frame", nil, env.UIParent)
	plate:SetSize(110, 45)
	env._plates[unit] = plate
	return plate
end

-- Text(number) -> what the number's font string shows: the text, or the format and its argument.
-- A secret is revealed, so a test can check that the amount arrived untouched.
function CT.Text(env, number)
	local reveal = function(v)
		if env.issecretvalue(v) then
			return "secret:" .. tostring(env.Reveal(v))
		end
		return v
	end
	local calls = number.text._calls
	for i = #calls, 1, -1 do
		local call = calls[i]
		if call.method == "SetText" then
			return reveal(call.args[1])
		elseif call.method == "SetFormattedText" then
			return string.format(call.args[1], reveal(call.args[2]))
		end
	end
end

-- Called(object, method) -> true when the object's method was called.
function CT.Called(object, method)
	for _, call in ipairs(object._calls) do
		if call.method == method then
			return true
		end
	end
	return false
end

-- LastCall(object, method) -> the arguments of the object's last call to method, or nil.
function CT.LastCall(object, method)
	local calls = object._calls
	for i = #calls, 1, -1 do
		if calls[i].method == method then
			return unpack(calls[i].args, 1, calls[i].args.n)
		end
	end
end

-- Finish(number) ends the number's animation, as the game does when the AnimationGroup completes.
function CT.Finish(number)
	local onFinished = number.group:GetScript("OnFinished")
	assert(onFinished, "the number's animation has no OnFinished handler")
	onFinished(number.group, false)
end

-- Anim(number, name) -> the stored settings of one of the number's animations.
function CT.Anim(number, name)
	local anim = assert(number[name], "the number has no animation " .. name)
	local s = anim._state
	local function get(field)
		local v = s[field]
		if v then
			return unpack(v, 1, v.n)
		end
	end
	return {
		offsetX = (select(1, get("Offset"))), offsetY = (select(2, get("Offset"))),
		duration = get("Duration"), delay = get("StartDelay") or 0, smoothing = get("Smoothing"),
		fromAlpha = get("FromAlpha"), toAlpha = get("ToAlpha"),
		scaleFrom = (select(1, get("ScaleFrom"))), scaleTo = (select(1, get("ScaleTo"))),
	}
end

return CT
