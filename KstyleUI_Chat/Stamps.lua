-- Stamps.lua: chat timestamps through the game's showTimestamps CVar. The game stamps each chat line in KstyleUI's format as it builds the line, so Messages rewrites only lines whose channel name it shortens. The player's own value comes back when the module turns off.
local _, ns = ...

local K = KstyleUI
local Format = ns.Format

local Stamps = {}
ns.Stamps = Stamps

local CVAR = "showTimestamps"
local NONE = "none"
local MEMORY = "chatTimestamps"

local state = {
	active = false,
	settings = nil,
	draws = nil,
	writing = false,
	written = nil,
	queued = false,
	registered = false,
}
local logged = {}

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(ns.NAME, message)
	end
end

local function IsText(v)
	return not Format.IsSecret(v) and type(v) == "string"
end

local function Get()
	local get = C_CVar and C_CVar.GetCVar
	if type(get) ~= "function" then
		return nil
	end
	local ok, value = pcall(get, CVAR)
	if ok and IsText(value) then
		return value
	end
	return nil
end

local function Set(value)
	local set = C_CVar and C_CVar.SetCVar
	if type(set) ~= "function" then
		LogOnce("set-missing", "C_CVar.SetCVar is missing; KstyleUI adds chat timestamps itself")
		return false
	end
	state.writing = true
	local ok, done = pcall(set, CVAR, value)
	state.writing = false
	return ok and done ~= false and Get() == value
end

function Stamps.Value(fmt, colour)
	if fmt == NONE or not Format.IsTimestamp(fmt) then
		return NONE
	end
	local r, g, b
	if type(colour) == "table" then
		r, g, b = colour.r, colour.g, colour.b
	end
	return Format.Wrap("[" .. fmt .. "]", r, g, b) .. " "
end

local function Plain(fmt)
	return Stamps.Value(fmt, nil)
end

local function Adopt(value)
	if not IsText(value) then
		return nil
	end
	if value == NONE then
		return NONE
	end
	local fmt = value:match("^(.-)%s*$")
	if Format.IsTimestamp(fmt) then
		return fmt
	end
	return nil
end

local function Memory(create)
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
	local memory = all[key]
	if type(memory) ~= "table" then
		if not create then
			return nil
		end
		memory = {}
		all[key] = memory
	end
	return memory, all, key
end

local function Draws(value)
	return value ~= nil and value ~= "" and value ~= NONE
end

local function Apply()
	local current = Get()
	if current == nil then
		LogOnce("get-missing", "the showTimestamps CVar cannot be read; KstyleUI adds chat timestamps itself")
		state.draws = false
		return
	end
	local memory = Memory(true)
	if memory and current ~= memory.written then
		memory.original = current
	end
	local settings = state.settings or ns.Settings()
	local want = Stamps.Value(settings.timestamp, settings.timestampColor)
	if current ~= want and not Set(want) then
		local plain = Plain(settings.timestamp)
		if plain ~= want and Set(plain) then
			LogOnce("plain", "the game took KstyleUI's timestamp format without its colour")
			want = plain
		else
			LogOnce("refused", "the game refused KstyleUI's timestamp format; KstyleUI adds chat timestamps itself")
			local original = memory and memory.original or current
			if Get() ~= original then
				Set(original)
			end
			if memory then
				memory.written = nil
			end
			state.written = nil
			state.draws = Draws(Get())
			return
		end
	end
	if memory then
		memory.written = want
	end
	state.written = want
	state.draws = Draws(want)
	LogOnce("game", "chat timestamps: the game's showTimestamps CVar")
end

local function Restore()
	local memory, all, key = Memory(false)
	if memory then
		if memory.written ~= nil and IsText(memory.original) and Get() == memory.written then
			Set(memory.original)
		end
		all[key] = nil
	end
	state.written = nil
	state.draws = nil
end

local function Sync()
	if state.active then
		Apply()
	else
		Restore()
	end
end

function Stamps.Schedule()
	if state.queued then
		return
	end
	state.queued = true
	K.Combat.Queue(function()
		state.queued = false
		Sync()
	end)
end

local function Later()
	C_Timer.After(0, Stamps.Schedule)
end

local function PanelShown()
	local panel = SettingsPanel
	if type(panel) ~= "table" or type(panel.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(panel.IsShown, panel)
	return ok and shown == true
end

local function OnCVar(_, name, value)
	if IsText(name) and name:lower() ~= CVAR:lower() then
		return
	end
	state.draws = nil
	if state.writing or not state.active or not IsText(value) or value == state.written then
		return
	end
	if type(C_CVar and C_CVar.SetCVar) ~= "function" then
		return
	end
	local fmt = PanelShown() and Adopt(value)
	if fmt then
		C_Timer.After(0, function()
			if state.active then
				K.Options.Write(ns.NAME, "timestamp", fmt)
			end
		end)
		return
	end
	Later()
end

local function OnVariables()
	if state.active then
		Later()
	end
end

function Stamps.GameDraws()
	local draws = state.draws
	if draws == nil then
		draws = Draws(Get())
		state.draws = draws
	end
	return draws
end

function Stamps.Start(settings)
	state.active = true
	state.settings = settings
	state.draws = nil
	K.Events.Register(ns.NAME, "CVAR_UPDATE", OnCVar)
	K.Events.Register(ns.NAME, "VARIABLES_LOADED", OnVariables)
	Stamps.Schedule()
end

function Stamps.Refresh(settings, key)
	state.settings = settings
	if state.active and (key == nil or key == "timestamp" or key == "timestampColor") then
		Stamps.Schedule()
	end
end

function Stamps.Stop()
	state.active = false
	Stamps.Schedule()
end
