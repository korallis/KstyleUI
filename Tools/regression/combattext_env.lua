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

function CT.Fakes(env)
	env._formatted = {}
	env.GetTime = function()
		return env._now
	end
	env.AbbreviateNumbers = formatter(env, "short")
	env.BreakUpLargeNumbers = formatter(env, "full")
	env._plates = {}
	env.C_NamePlate = {
		GetNamePlateForUnit = function(unit)
			return env._plates[unit]
		end,
	}
	env.MISS, env.DODGE, env.PARRY, env.BLOCK, env.ABSORB = "Miss", "Dodge", "Parry", "Block", "Absorb"
	env.RESIST, env.IMMUNE, env.EVADE, env.DEFLECT, env.REFLECT = "Resist", "Immune", "Evade", "Deflect", "Reflect"
	env.INTERRUPT = "Interrupt"
	env.DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
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

-- Shown(ns) -> the numbers on screen, oldest first.
function CT.Shown(ns)
	local out = {}
	for _, number in ipairs(ns.Module.pool.active) do
		out[#out + 1] = number
	end
	return out
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
