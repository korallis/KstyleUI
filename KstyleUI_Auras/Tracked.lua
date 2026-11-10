-- Tracked.lua: the spells the Cooldown Manager's tracked-buff row shows, read from the player's effective viewer layout only when it is clean (base, override and linked spell ids, never a secret one), and only while that viewer is on and shown always; an unreadable layout leaves every buff in the aura row rather than assuming the default categories still match the player's choices.
local _, ns = ...

local Tracked = {}
ns.Tracked = Tracked

local CVAR = "cooldownViewerEnabled"
local CATEGORY = "TrackedBuff"
local EVENTS = { "COOLDOWN_VIEWER_DATA_LOADED", "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", "COOLDOWN_VIEWER_TABLE_HOTFIXED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }
local CALLBACKS = { "CooldownViewerSettings.OnDataChanged", "EditMode.Exit" }

local owner = {}

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Plain(value)
	if IsSecret(value) then
		return nil
	end
	return value
end

local function Id(value)
	if type(value) == "number" and not IsSecret(value) and value == value and value > 0 then
		return value
	end
	return nil
end

local function Enabled()
	local cvars = C_CVar
	if type(cvars) ~= "table" or type(cvars.GetCVarBool) ~= "function" then
		return false
	end
	local ok, on = pcall(cvars.GetCVarBool, CVAR)
	if not ok or IsSecret(on) then
		return false
	end
	return on == true
end

local function ShownAlways()
	local viewer = BuffIconCooldownViewer
	local setting = type(viewer) == "table" and Plain(rawget(viewer, "visibleSetting"))
	if setting == nil then
		return false
	end
	local always = type(Enum) == "table" and type(Enum.CooldownViewerVisibleSetting) == "table" and Plain(Enum.CooldownViewerVisibleSetting.Always)
	if always == nil then
		return false
	end
	return setting == always
end

local function Available()
	local api = C_CooldownViewer
	if type(api) ~= "table" then
		return false, "C_CooldownViewer is missing"
	end
	local category = type(Enum) == "table" and type(Enum.CooldownViewerCategory) == "table" and Enum.CooldownViewerCategory[CATEGORY]
	if type(category) ~= "number" or IsSecret(category) then
		return false, "Enum.CooldownViewerCategory." .. CATEGORY .. " is missing"
	end
	if type(api.IsCooldownViewerAvailable) == "function" then
		local ok, available = pcall(api.IsCooldownViewerAvailable)
		if not ok or IsSecret(available) or available ~= true then
			return false, "the Cooldown Manager is not available"
		end
	end
	if not Enabled() then
		return false, "the Cooldown Manager is off"
	end
	if not ShownAlways() then
		return false, "the tracked-buff viewer is hidden or shown in combat only"
	end
	return true, category
end

local function Add(set, value)
	local id = Id(value)
	if id then
		set[id] = true
		return 1
	end
	return 0
end

local function AddInfo(set, info)
	local n = Add(set, info.spellID) + Add(set, info.overrideSpellID)
	local linked = info.linkedSpellIDs
	if type(linked) == "table" and not IsSecret(linked) then
		for _, spell in ipairs(linked) do
			n = n + Add(set, spell)
		end
	end
	return n
end

local function Layout()
	local settings = CooldownViewerSettings
	if type(settings) ~= "table" or type(settings.GetDataProvider) ~= "function" then
		return nil
	end
	local ok, provider = pcall(settings.GetDataProvider, settings)
	if not ok or type(provider) ~= "table" or type(provider.IsDirty) ~= "function" or type(provider.GetDisplayData) ~= "function" then
		return nil
	end
	local okDirty, dirty = pcall(provider.IsDirty, provider)
	if not okDirty or IsSecret(dirty) or dirty then
		return nil
	end
	local okData, data = pcall(provider.GetDisplayData, provider)
	if not okData or type(data) ~= "table" or IsSecret(data) or type(data.orderedCooldownIDs) ~= "table" or type(data.cooldownInfoByID) ~= "table" then
		return nil
	end
	return data
end

local function FromLayout(data, category, set)
	local n = 0
	for _, id in ipairs(data.orderedCooldownIDs) do
		local info = Id(id) and data.cooldownInfoByID[id]
		if type(info) == "table" and not IsSecret(info) and info.category == category and info.isKnown ~= false then
			n = n + AddInfo(set, info)
		end
	end
	return n
end

function Tracked.Set()
	local ok, category = Available()
	if not ok then
		return nil, category
	end
	local data = Layout()
	if not data then
		return nil, "the effective tracked-buff layout cannot be read"
	end
	local set = {}
	local n = FromLayout(data, category, set)
	if n == 0 then
		return nil, "no tracked buffs"
	end
	return set, n
end

function Tracked.Listen(fn, listen)
	local function refresh(event, name)
		if event == "CVAR_UPDATE" and name ~= CVAR then
			return
		end
		fn()
	end
	for _, event in ipairs(EVENTS) do
		listen(event, refresh)
	end
	listen("CVAR_UPDATE", refresh)
	local registry = EventRegistry
	if type(registry) == "table" and type(registry.RegisterCallback) == "function" then
		for _, name in ipairs(CALLBACKS) do
			pcall(registry.RegisterCallback, registry, name, fn, owner)
		end
	end
end
