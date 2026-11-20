-- CVars.lua: applies the chosen nameplate CVars out of combat, keeps the player's values across reloads, and gives them back when management or the module stops, leaving the scale hold to Stacking.lua.
local _, ns = ...

local K = KstyleUI
local Settings, Logic = ns.Settings, ns.Logic
local LogOnce = ns.LogOnce

local CVars = {}
ns.CVars = CVars

local KEYS = { "maxDistance", "verticalDistance", "stacking", "selectedScale", "minScale", "clickSize",
	"showEnemies", "showFriends", "enemyMinions", "friendlyMinions", "friendlyNpcs", "friendlyNameOnly" }
local queued = false

CVars.Exists = K.CVars.Exists

local function Records(create)
	local key = K.Store.CharacterKey()
	if type(key) ~= "string" then return nil end
	local account = K.Store.Account()
	if type(account.nameplateCVars) ~= "table" then
		if not create then return nil end
		account.nameplateCVars = {}
	end
	local all = account.nameplateCVars
	if type(all[key]) ~= "table" and create then all[key] = {} end
	return type(all[key]) == "table" and all[key] or nil
end

function CVars.Original(name)
	local records = Records()
	local record = records and records[name]
	if type(record) == "table" and record.written ~= K.CVars.Get(name) then
		records[name] = nil
		return nil
	end
	return type(record) == "table" and type(record.original) == "string" and record.original or nil
end

local function Set(name, value, index)
	local records, current = Records(true), K.CVars.Get(name)
	if not records or not current then return false end
	local record = records[name]
	local original = type(record) == "table" and record.written == current and record.original or current
	local done = index and K.CVars.SetBitfield(name, index, value) or not index and K.CVars.Set(name, value)
	if not done then
		LogOnce("cvar-fail:" .. name, "the game refused CVar " .. name)
		return false
	end
	local written = K.CVars.Get(name)
	if written then records[name] = { original = original, written = written } end
	return true
end

local function Back(records, name)
	local record = records[name]
	local valid = type(record) == "table" and type(record.original) == "string" and type(record.written) == "string"
	local current = valid and K.CVars.Get(name)
	if valid and ns.Stacking.Holds(name) then
		ns.Stacking.HandBack(name, record.original)
		records[name] = nil
	elseif valid and (current == nil or (current == record.written
		and (not K.CVars.Set(name, record.original) or K.CVars.Get(name) ~= record.original))) then
		LogOnce("cvar-back:" .. name, "the game refused " .. name .. " back; KstyleUI tries again later")
	else
		records[name] = nil
	end
end

local function Apply()
	local values = {}
	for _, key in ipairs(KEYS) do
		values[key] = Settings.Get("cvars." .. key)
	end
	for _, entry in ipairs(Logic.CVarPlan(values)) do
		local name = entry.name
		if entry.value == nil then
			local records = Records()
			if records and records[name] then Back(records, name) end
		elseif ns.Stacking.Holds(name) then
			LogOnce("cvar-held:" .. name, name .. " stays at 1 while plates ignore the game's plate scale; turn on Shrink distant plates to use this setting")
		elseif not K.CVars.Exists(name) then
			if name ~= Logic.STACKING_CVAR then
				LogOnce("cvar-missing:" .. name, "CVar " .. name .. " is missing on this client; skipped")
			end
		else
			Set(name, entry.value, entry.index)
		end
	end
	K.DevTest.Log(Settings.MODULE, "applied the nameplate CVars")
end

local function Restore()
	local records = Records() or {}
	for name in pairs(records) do
		if name ~= "nameplateShowSelf" or not ns.Plates.running then
			Back(records, name)
		end
	end
	K.DevTest.Log(Settings.MODULE, "returned the nameplate CVars to the player's values")
end

function CVars.Sync()
	if ns.Plates.running and Settings.Get("cvars.enabled") then
		Apply()
	else
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

function CVars.PersonalResource(value)
	K.Combat.Queue(function()
		Set("nameplateShowSelf", value and "1" or "0")
	end)
end

K.Callbacks.Register("SettingChanged", "Nameplates:personalResource", function(_, module, key, value)
	if module == Settings.MODULE and key == "personalResource" then
		CVars.PersonalResource(value)
	end
end)
