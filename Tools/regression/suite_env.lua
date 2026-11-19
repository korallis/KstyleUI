-- suite_env.lua: the audit fixture boots every addon, saves setup choices, then reloads the saved suite.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Auras = dofile("Tools/regression/auras_env.lua")

local Suite = {}
local CORE = "KstyleUI"

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local order, files, onDemand = { CORE }, { [CORE] = {} }, {}
for _, path in ipairs(TocFiles("%.lua$")) do
	local addon = path:match("^(KstyleUI_[%w_]+)/") or CORE
	if not files[addon] then
		files[addon] = {}
		order[#order + 1] = addon
		onDemand[addon] = ("\n" .. read(addon .. "/" .. addon .. ".toc")):match("\n##%s*LoadOnDemand%s*:%s*1") ~= nil
	end
	files[addon][#files[addon] + 1] = path
end

local function Fill(env, name, value)
	if env[name] == nil then
		env[name] = value
	end
end

local function Game(env)
	Auras.Engine(env)
	Fill(env, "UnitClass", function(unit) if unit == "player" then return "Rogue", "ROGUE", 4 end end)
	Fill(env, "UnitIsPlayer", function(unit) return unit == "player" end)
	Fill(env, "UnitLevel", function(unit) return env.UnitExists(unit) and 60 or 0 end)
	Fill(env, "UnitHealth", function() return env.Secret(3000) end)
	Fill(env, "UnitHealthMax", function() return 4000 end)
	Fill(env, "UnitPower", function() return 2000 end)
	Fill(env, "UnitPowerMax", function() return 4000 end)
	Fill(env, "UnitPowerType", function() return 3, "ENERGY" end)
	Fill(env, "UnitIsConnected", function(unit) return env.UnitExists(unit) end)
	Fill(env, "UnitIsDeadOrGhost", function() return false end)
	Fill(env, "UnitCastingInfo", function() end)
	Fill(env, "UnitChannelInfo", function() end)
	Fill(env, "IsInGroup", function() return false end)
	Fill(env, "IsInRaid", function() return false end)
	Fill(env, "RegisterUnitWatch", function() end)
	Fill(env, "UnregisterUnitWatch", function() end)
	Fill(env, "C_ActionBar", {
		HasAction = function() return false end,
		GetActionTexture = function() end,
		GetActionText = function() end,
		GetActionDisplayCount = function() end,
		GetActionCooldownDuration = function() end,
		IsUsableAction = function() return false, false end,
		EnableActionRangeCheck = function() end,
	})
	env.Condition = function(part) return part:sub(1, 2) == "no" end
	env.C_AddOns = {
		LoadAddOn = function(name)
			if not files[name] then return false, "MISSING" end
			if not env._addons[name] then
				Load(files[name], env)
				env.FireEvent("ADDON_LOADED", name, false)
			end
			return true
		end,
		IsAddOnLoaded = function(name)
			local loaded = env._addons[name] ~= nil
			return loaded, loaded
		end,
		DoesAddOnExist = function(name) return files[name] ~= nil end,
	}
	env.print = function() end
end

local function Start(saved, W, H, setup)
	local env = Stubs.NewEnv({ width = W, height = H, uiScale = 768 / 1080, size = "auto", fit = true })
	env.KstyleUIDB = saved
	Game(env)
	if setup then setup(env) end
	env._auditTickers = {}
	local newTicker = env.C_Timer.NewTicker
	env.C_Timer.NewTicker = function(interval, fn, ...)
		local t = newTicker(interval, fn, ...)
		env._auditTickers[#env._auditTickers + 1] = { ticker = t, interval = interval, fn = fn }
		return t
	end
	for _, addon in ipairs(order) do
		if not onDemand[addon] then
			Load(files[addon], env)
			env.FireEvent("ADDON_LOADED", addon, false)
		end
	end
	env.FireEvent("PLAYER_LOGIN")
	env.RunTimers()
	return env, env.KstyleUI
end

Suite.New = Start

-- Prepare(style, W, H) returns a saved-suite reload function and the initial environment.
function Suite.Prepare(style, W, H)
	local env, K = Start(nil, W, H)
	local choice = K.Setup.NewChoice()
	choice.hudStyle = style
	assert(K.Setup.Apply(choice), "Setup.Apply refused the choice")
	env.RunTimers()
	env.FireEvent("PLAYER_LOGOUT")
	local saved = CoreEnv.DeepCopy(env.KstyleUIDB)
	local initial = env
	return function()
		local reloaded, kit = Start(CoreEnv.DeepCopy(saved), W, H)
		reloaded.FireEvent("PLAYER_ENTERING_WORLD", false, true)
		reloaded.RunTimers()
		assert(kit.HudStyle.Current() == style, "the reload runs " .. tostring(kit.HudStyle.Current()))
		assert(#reloaded._errors == 0 and kit.ErrorCount() == 0, "the reload raised: " .. tostring(reloaded._errors[1]))
		return reloaded, kit
	end, initial
end


return Suite
