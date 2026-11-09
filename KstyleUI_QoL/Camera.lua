-- Camera.lua: max camera distance, which writes Forever's own slider maximum to cameraDistanceMaxZoomFactor out of combat and only once the character's CVars have loaded, and keeps the player's value per character, so turning it off, or the core's login sweep with the module off, puts that value back.
local _, ns = ...

local K = ns.K

local CVAR = "cameraDistanceMaxZoomFactor"
local MAXIMUM = 2
local MEMORY = "qolCamera"

local function Get()
	local get = C_CVar and C_CVar.GetCVar
	if type(get) ~= "function" then
		return nil
	end
	local ok, value = pcall(get, CVAR)
	if ok and not ns.IsSecret(value) and type(value) == "string" then
		return value
	end
	return nil
end

local function Set(value)
	local set = C_CVar and C_CVar.SetCVar
	if type(set) ~= "function" then
		return false
	end
	local ok, done = pcall(set, CVAR, value)
	return ok and done ~= false
end

local function Records(create)
	local key = K.Store.CharacterKey()
	if type(key) ~= "string" then
		return nil
	end
	local account = K.Store.Account()
	local all = account[MEMORY]
	if type(all) ~= "table" then
		if not create then
			return nil
		end
		all = {}
		account[MEMORY] = all
	end
	return all, key
end

local function Apply()
	local current = Get()
	if not current then
		ns.LogOnce("camera-read", CVAR .. " cannot be read; the camera distance stays as it is")
		return
	end
	local all, key = Records(false)
	local record = all and all[key]
	if type(record) == "table" and record.written == current then
		return
	end
	local value = tonumber(current)
	if value and value >= MAXIMUM then
		if all then
			all[key] = nil
		end
		return
	end
	if not Set(tostring(MAXIMUM)) then
		ns.LogOnce("camera-refused", "the game refused " .. CVAR .. "; the camera distance stays as it is")
		return
	end
	local written = Get()
	if not written or written == current then
		return
	end
	all, key = Records(true)
	if all then
		all[key] = { original = current, written = written }
	end
end

local function Restore()
	local all, key = Records(false)
	local record = all and all[key]
	if type(record) ~= "table" then
		return
	end
	if type(record.original) == "string" and Get() == record.written then
		Set(record.original)
	end
	all[key] = nil
end

local variablesLoaded = false

local function Loaded()
	return variablesLoaded or (K.CVars ~= nil and K.CVars.Loaded())
end

local function Sync()
	K.Combat.Queue(function()
		if not Loaded() then
			return
		end
		if ns.running and ns.Get("maxCamera") then
			Apply()
		else
			Restore()
		end
	end)
end

ns.AddPart({
	name = "camera",
	events = {
		VARIABLES_LOADED = function()
			variablesLoaded = true
			Sync()
		end,
	},
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or key == "maxCamera" then
			Sync()
		end
	end,
})
