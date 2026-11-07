-- CVars.lua: once per login, after the modules start and the character's CVars load, puts back the player's own value of each CVar a module hid and still holds KstyleUI's value, when that module is off on this character.
local _, ns = ...

local OWNER, SHARED = "CVars", "*"
local MEMORIES = {
	{ module = "CombatText", key = "combatTextCVars" },
	{ module = "Chat", key = "chatTimestamps", cvar = "showTimestamps" },
}

local seen = {}
local logged = {}

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

local function Get(name)
	local ok, value = pcall(Api("GetCVar"), name)
	return ok and IsText(value) and value or nil
end

local function Set(name, value)
	local ok, done = pcall(Api("SetCVar"), name, value)
	return ok and done ~= false and Get(name) == value
end

local function Restore(records, key, name)
	local record = records[key]
	local held = IsText(name) and type(record) == "table" and IsText(record.original) and IsText(record.written)
		and record.original ~= record.written and Get(name) == record.written
	if held and not Set(name, record.original) then
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
