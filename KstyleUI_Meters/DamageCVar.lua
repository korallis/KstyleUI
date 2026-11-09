-- DamageCVar.lua: the game draws Blizzard's damage meter only with damageMeterEnabled on, off on a fresh account, so the restyled window turns it on while KstyleUI shows it and gives the player's own value back when it stops.
local _, ns = ...

local K = KstyleUI
local IsSecret = ns.Logic.IsSecret

local DamageCVar = {}
ns.DamageCVar = DamageCVar

local CVAR, ON = "damageMeterEnabled", "1"
local MEMORY, SHARED = "damageMeterCVars", "*"

local state = { want = false, queued = false }

local function IsText(v)
	return not IsSecret(v) and type(v) == "string"
end

local function Api(name)
	local fn = C_CVar and C_CVar[name]
	return type(fn) == "function" and fn or nil
end

local function Get()
	local fn = Api("GetCVar")
	if not fn then
		return nil
	end
	local ok, value = pcall(fn, CVAR)
	return ok and IsText(value) and value or nil
end

local function Set(value)
	local fn = Api("SetCVar")
	if not fn then
		return false
	end
	local ok, done = pcall(fn, CVAR, value)
	return ok and done ~= false and Get() == value
end

local function Memory(create)
	local account = K.Store.Account()
	local all = account[MEMORY]
	if type(all) ~= "table" then
		if not create then
			return nil
		end
		all = {}
		account[MEMORY] = all
	end
	local shared = all[SHARED]
	if type(shared) ~= "table" then
		if not create then
			return nil
		end
		shared = {}
		all[SHARED] = shared
	end
	local record = shared[CVAR]
	if type(record) ~= "table" and create then
		record = {}
		shared[CVAR] = record
	end
	return type(record) == "table" and record or nil, shared
end

local function TurnOn()
	local current = Get()
	if current == nil then
		ns.LogOnce("damageCVarRead", CVAR .. " cannot be read; Blizzard's damage meter keeps the player's setting")
		return
	end
	if current == ON then
		return
	end
	local record = Memory(true)
	record.original = current
	if Set(ON) then
		record.written = ON
		ns.LogOnce("damageCVarOn", "Blizzard's damage meter is switched on through " .. CVAR .. " while KstyleUI restyles it")
	else
		record.written = nil
		ns.LogOnce("damageCVarRefused", "the game refused " .. CVAR .. "; Blizzard's damage meter keeps the player's setting")
	end
end

local function GiveBack()
	local record, shared = Memory(false)
	if not record then
		return
	end
	local held = record.written ~= nil and IsText(record.original) and Get() == record.written
	if not held or Set(record.original) then
		shared[CVAR] = nil
	end
end

local function Sync()
	state.queued = false
	if state.want then
		TurnOn()
	else
		GiveBack()
	end
end

function DamageCVar.Want(on)
	state.want = on == true
	if state.queued then
		return
	end
	state.queued = true
	K.Combat.Queue(Sync)
end
