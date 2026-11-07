-- CVars.lua: applies the nameplate CVars the player chose, only out of combat, and returns them to the game's defaults when turned off.
local _, ns = ...

local K = KstyleUI
local Settings, Logic = ns.Settings, ns.Logic
local LogOnce = ns.LogOnce

local CVars = {}
ns.CVars = CVars

local KEYS = { "maxDistance", "verticalDistance", "stacking", "selectedScale", "minScale", "clickSize" }
local applied = {}
local queued = false

local function Api(name)
	local api = C_CVar
	if api and type(api[name]) == "function" then
		return api[name]
	end
	local global = _G[name]
	if type(global) == "function" then
		return global
	end
	return nil
end

local function Exists(name)
	local get = Api("GetCVar")
	if not get then
		return false
	end
	local ok, value = pcall(get, name)
	return ok and value ~= nil
end

CVars.Exists = Exists

local function Set(name, value)
	local set = Api("SetCVar")
	if not set then
		LogOnce("cvar-set", "SetCVar is missing; nameplate CVars are left alone")
		return false
	end
	local ok, done = pcall(set, name, value)
	if not ok or done == false then
		LogOnce("cvar-fail:" .. name, "the game refused CVar " .. name)
		return false
	end
	return true
end

local function SetBit(name, index, value)
	local set = Api("SetCVarBitfield")
	if not set then
		return false
	end
	local ok, done = pcall(set, name, index, value)
	return ok and done ~= false
end

local function Apply()
	local values = {}
	for _, key in ipairs(KEYS) do
		values[key] = Settings.Get("cvars." .. key)
	end
	for _, entry in ipairs(Logic.CVarPlan(values)) do
		local name = entry.name
		if entry.fallback then
			if not Exists(entry.fallback) and Exists(name) and Set(name, entry.value) then
				applied[name] = true
			end
		elseif not Exists(name) then
			if name ~= Logic.STACKING_CVAR then
				LogOnce("cvar-missing:" .. name, "CVar " .. name .. " is missing on this client; skipped")
			end
		elseif entry.index then
			if SetBit(name, entry.index, entry.value) then
				applied[name] = true
			end
		elseif Set(name, entry.value) then
			applied[name] = true
		end
	end
	K.DevTest.Log(Settings.MODULE, "applied the nameplate CVars")
end

local function Restore()
	local default = Api("GetCVarDefault")
	for name in pairs(applied) do
		applied[name] = nil
		local value = default and default(name)
		if type(value) == "string" then
			Set(name, value)
		else
			LogOnce("cvar-default:" .. name, "no default for CVar " .. name .. "; left as it is")
		end
	end
	K.DevTest.Log(Settings.MODULE, "returned the nameplate CVars to the game's defaults")
end

function CVars.Sync()
	if ns.Plates.running and Settings.Get("cvars.enabled") then
		Apply()
	elseif next(applied) then
		Restore()
	end
end

function CVars.Schedule()
	if queued then
		return
	end
	queued = true
	K.Combat.Queue(function()
		queued = false
		CVars.Sync()
	end)
end
