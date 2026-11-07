-- Blizzard.lua: Blizzard's own combat text, which the game's CVars turn off while the module runs; the player's values come back when it stops.
local _, ns = ...

local K = KstyleUI
local IsSecret = ns.Format.IsSecret

local Blizzard = {}
ns.Blizzard = Blizzard

local MODULE, MEMORY, SHARED, HIDDEN = "CombatText", "combatTextCVars", "*", "0"
local CVARS = {
	{ name = "enableFloatingCombatText", key = "blizzardSelf", character = true },
	{ name = "floatingCombatTextCombatDamage_v2", key = "blizzardTargets" },
	{ name = "floatingCombatTextCombatHealing_v2", key = "blizzardTargets" },
	{ name = "floatingCombatTextPetMeleeDamage_v2", key = "blizzardTargets" },
	{ name = "floatingCombatTextPetSpellDamage_v2", key = "blizzardTargets" },
}
local BY_NAME = {}
for _, cvar in ipairs(CVARS) do
	BY_NAME[cvar.name:lower()] = cvar
end

local state = { active = false, cfg = nil, writing = false, queued = false }
local logged = {}

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(MODULE, message)
	end
end

local function IsText(v)
	return not IsSecret(v) and type(v) == "string"
end

local function Api(name)
	local fn = C_CVar and C_CVar[name]
	return type(fn) == "function" and fn or nil
end

local function Call(name, ...)
	local fn = Api(name)
	if fn then
		return pcall(fn, ...)
	end
	return false
end

local function Get(name)
	local ok, value = Call("GetCVar", name)
	return ok and IsText(value) and value or nil
end

local function Set(name, value)
	state.writing = true
	local ok, done = Call("SetCVar", name, value)
	state.writing = false
	return ok and done ~= false and Get(name) == value
end

local function PerCharacter(cvar)
	local ok, _, _, _, character = Call("GetCVarInfo", cvar.name)
	if ok and not IsSecret(character) and type(character) == "boolean" then
		return character
	end
	return cvar.character == true
end

local function Child(parent, key, create)
	local child = parent and parent[key]
	if type(child) ~= "table" and create and parent then
		child = {}
		parent[key] = child
	end
	return type(child) == "table" and child or nil
end

local function Memory(cvar, create)
	local owner = SHARED
	if PerCharacter(cvar) then
		owner = K.Store.CharacterKey()
	end
	if type(owner) ~= "string" then
		return nil
	end
	local saved = Child(Child(K.Store.Account(), MEMORY, create), owner, create)
	return Child(saved, cvar.name, create), saved
end

local function Apply(cvar)
	if not Api("SetCVar") then
		LogOnce("set", "C_CVar.SetCVar is missing; Blizzard's combat text stays as the player has it")
		return
	end
	local current = Get(cvar.name)
	local memory = current and Memory(cvar, true)
	if not memory then
		LogOnce("get:" .. cvar.name, cvar.name .. " cannot be read or remembered; KstyleUI leaves it alone")
		return
	end
	if current ~= memory.written then
		memory.original = current
	end
	if current ~= HIDDEN and not Set(cvar.name, HIDDEN) then
		LogOnce("refused:" .. cvar.name, "the game refused " .. cvar.name .. "; it keeps the player's value")
		if Get(cvar.name) ~= memory.original then
			Set(cvar.name, memory.original)
		end
		memory.written = nil
		return
	end
	memory.written = HIDDEN
	LogOnce("hidden", "Blizzard's combat text: hidden through its CVars")
end

local function Restore(cvar)
	local memory, saved = Memory(cvar, false)
	if not memory then
		return
	end
	local held = memory.written ~= nil and IsText(memory.original) and memory.original ~= memory.written and Get(cvar.name) == memory.written
	if not held or Set(cvar.name, memory.original) then
		saved[cvar.name] = nil
	else
		LogOnce("restore:" .. cvar.name, "the game refused " .. cvar.name .. " back; KstyleUI tries again next time")
	end
end

local function Hides(cvar)
	return state.active and state.cfg ~= nil and state.cfg[cvar.key] == "hide"
end

function Blizzard.Schedule()
	if state.queued then
		return
	end
	state.queued = true
	K.Combat.Queue(function()
		state.queued = false
		for _, cvar in ipairs(CVARS) do
			if Hides(cvar) then
				Apply(cvar)
			else
				Restore(cvar)
			end
		end
	end)
end

local function Later()
	C_Timer.After(0, Blizzard.Schedule)
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
	local cvar = IsText(name) and BY_NAME[name:lower()]
	if not cvar or state.writing or not Hides(cvar) or not IsText(value) or value == HIDDEN or not Api("SetCVar") then
		return
	end
	if not PanelShown() then
		Later()
		return
	end
	C_Timer.After(0, function()
		if state.active then
			K.Options.Write(MODULE, cvar.key, "keep")
		end
	end)
end

local function OnVariables()
	if state.active then
		Later()
	end
end

function Blizzard.Start(cfg)
	state.active = true
	state.cfg = cfg
	K.Events.Register(MODULE, "CVAR_UPDATE", OnCVar)
	K.Events.Register(MODULE, "VARIABLES_LOADED", OnVariables)
	Blizzard.Schedule()
end

function Blizzard.Stop()
	state.active = false
	Blizzard.Schedule()
end
