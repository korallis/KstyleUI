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

CVars.Exists = K.CVars.Exists

local function Set(name, value)
	if not K.CVars.Set(name, value) then
		LogOnce("cvar-fail:" .. name, "the game refused CVar " .. name)
		return false
	end
	return true
end

local function Apply()
	local values = {}
	for _, key in ipairs(KEYS) do
		values[key] = Settings.Get("cvars." .. key)
	end
	for _, entry in ipairs(Logic.CVarPlan(values)) do
		local name = entry.name
		if entry.fallback then
			if not K.CVars.Exists(entry.fallback) and K.CVars.Exists(name) and Set(name, entry.value) then
				applied[name] = true
			end
		elseif not K.CVars.Exists(name) then
			if name ~= Logic.STACKING_CVAR then
				LogOnce("cvar-missing:" .. name, "CVar " .. name .. " is missing on this client; skipped")
			end
		elseif entry.index then
			if K.CVars.SetBitfield(name, entry.index, entry.value) then
				applied[name] = true
			end
		elseif Set(name, entry.value) then
			applied[name] = true
		end
	end
	K.DevTest.Log(Settings.MODULE, "applied the nameplate CVars")
end

local function Restore()
	for name in pairs(applied) do
		applied[name] = nil
		local value = K.CVars.Default(name)
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
