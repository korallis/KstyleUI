-- CVars.lua: whether the character's CVars have loaded (Loaded), and once per login, after the modules start and the character's CVars load, puts back the player's own value of each CVar a module hid and still holds KstyleUI's value, when that module is off on this character.
local _, ns = ...

local OWNER, SHARED = "CVars", "*"
local MEMORIES = {
	{ module = "CombatText", key = "combatTextCVars" },
	{ module = "Chat", key = "chatTimestamps", cvar = "showTimestamps" },
	{ module = "Meters", key = "damageMeterCVars" },
	{ module = "Nameplates", key = "nameplateScaleCVars" },
	{ module = "QoL", key = "qolCamera", cvar = "cameraDistanceMaxZoomFactor" },
}

local seen = {}
local logged = {}

ns.CVars = {}

function ns.CVars.Loaded()
	return seen.VARIABLES_LOADED == true
end

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		ns.DevTest.Log(OWNER, message)
	end
end

local function IsText(v)
	return not (issecretvalue and issecretvalue(v)) and type(v) == "string"
end

local function Api(name)
	local fn = C_CVar and C_CVar[name]
	return type(fn) == "function" and fn or nil
end

local function Info(name)
	if not IsText(name) then
		return nil
	end
	local fn = Api("GetCVarInfo")
	if not fn then
		return nil
	end
	local ok, value, default, _, _, locked, secure, readOnly = pcall(fn, name)
	if not ok or not IsText(value) or not IsText(default) then
		return nil
	end
	if (issecretvalue and (issecretvalue(locked) or issecretvalue(secure) or issecretvalue(readOnly)))
		or type(locked) ~= "boolean" or type(secure) ~= "boolean" or type(readOnly) ~= "boolean"
		or locked or secure or readOnly then
		return nil
	end
	return value, default
end

function ns.CVars.Exists(name)
	return Info(name) ~= nil
end

function ns.CVars.Get(name)
	if Info(name) == nil then
		return nil
	end
	local fn = Api("GetCVar")
	if not fn then
		return nil
	end
	local ok, value = pcall(fn, name)
	return ok and IsText(value) and value or nil
end

function ns.CVars.Default(name)
	local _, default = Info(name)
	return default
end

function ns.CVars.Set(name, value)
	if (issecretvalue and issecretvalue(value)) or (type(value) ~= "string" and type(value) ~= "number") or Info(name) == nil then
		return false
	end
	local fn = Api("SetCVar")
	if not fn then
		return false
	end
	local ok, done = pcall(fn, name, value)
	return ok and not (issecretvalue and issecretvalue(done)) and done == true
end

function ns.CVars.SetBitfield(name, index, value)
	if (issecretvalue and (issecretvalue(index) or issecretvalue(value))) or type(index) ~= "number" or type(value) ~= "boolean" or Info(name) == nil then
		return false
	end
	local fn = Api("SetCVarBitfield")
	if not fn then
		return false
	end
	local ok, done = pcall(fn, name, index, value)
	return ok and not (issecretvalue and issecretvalue(done)) and done == true
end

local function Restore(records, key, name)
	local record = records[key]
	local valid = IsText(name) and type(record) == "table" and IsText(record.original) and IsText(record.written)
		and record.original ~= record.written
	local current = valid and ns.CVars.Get(name)
	if valid and current == nil then
		return
	end
	local held = valid and current == record.written
	if held and (not ns.CVars.Set(name, record.original) or ns.CVars.Get(name) ~= record.original) then
		LogOnce("refused:" .. name, "the game refused " .. name .. " back; KstyleUI tries again at the next login")
		return
	end
	records[key] = nil
	if held then
		ns.DevTest.Log(OWNER, name .. ": the player's value is back, because its module is off on this character")
	end
end

local function RestoreAll(all, owner)
	local records = owner and all[owner]
	if type(records) == "table" then
		for name in pairs(records) do
			Restore(records, name, name)
		end
	end
end

local function Sweep()
	if not ns.Store.IsLoaded() then
		return
	end
	if not (Api("GetCVar") and Api("SetCVar")) then
		LogOnce("api", "C_CVar.GetCVar or C_CVar.SetCVar is missing; the CVars KstyleUI hid stay as they are")
		return
	end
	local account, character = ns.Store.Account(), ns.Store.CharacterKey()
	for _, memory in ipairs(MEMORIES) do
		local all = account[memory.key]
		if type(all) == "table" and not ns.Modules.IsRunning(memory.module) then
			if memory.cvar then
				if character then
					Restore(all, character, memory.cvar)
				end
			else
				RestoreAll(all, SHARED)
				RestoreAll(all, character)
			end
		end
	end
end

local function Seen(event)
	seen[event] = true
	if seen.PLAYER_LOGIN and seen.VARIABLES_LOADED then
		ns.Events.UnregisterAll(OWNER)
		C_Timer.After(0, function()
			ns.Combat.Queue(Sweep)
		end)
	end
end

ns.Events.Register(OWNER, "PLAYER_LOGIN", Seen)
ns.Events.Register(OWNER, "VARIABLES_LOADED", Seen)
