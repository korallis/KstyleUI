-- Registry.lua: the window skins, each switched on in the settings and applied once its Blizzard addon has loaded and its window first shows.
local _, ns = ...

local K = KstyleUI
local L = K.L

local Skins = {}
ns.Skins = Skins

local MODULE = "Skins"
local MAX_HELP = 100

local order, byKey = {}, {}
local applied, waiting, hooked = {}, {}, {}
local closed, running = false, false

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Fail(message)
	error("KstyleUI_Skins Skins.Add: " .. message, 3)
end

function Skins.Add(def)
	if closed then
		Fail("add skins from a file Skins.xml loads before Module.lua; the module has registered")
	end
	if type(def) ~= "table" then
		Fail("the definition must be a table, got " .. type(def))
	end
	local key = def.key
	if type(key) ~= "string" or not key:match("^%l[%w]*$") or #key > 32 then
		Fail("key must be a lower-camel name such as questLog, got " .. tostring(key))
	end
	if ns.Style.GROUPS[key] or key == "enabled" then
		Fail(key .. " is reserved for the module's shared settings")
	end
	if byKey[key] then
		Fail(key .. " is already added")
	end
	if type(def.label) ~= "string" or def.label == "" then
		Fail(key .. ": needs a label, the window's name in the settings")
	end
	if type(def.help) ~= "string" or def.help == "" or #def.help >= MAX_HELP then
		Fail(key .. ": needs help, one sentence under 100 characters")
	end
	if def.addon ~= nil and (type(def.addon) ~= "string" or def.addon == "") then
		Fail(key .. ": addon must be the name of the Blizzard addon that makes the window")
	end
	if def.frame ~= nil and (type(def.frame) ~= "string" or def.frame == "") then
		Fail(key .. ": frame must be the global name of the window")
	end
	if type(def.Apply) ~= "function" then
		Fail(key .. ": needs an Apply function")
	end
	if def.defaults ~= nil and type(def.defaults) ~= "table" then
		Fail(key .. ": defaults must be a table")
	end
	if def.defaults and def.defaults.enabled ~= nil then
		Fail(key .. ": enabled is the window's switch, which the registry adds; leave it out of defaults")
	end
	if def.rows ~= nil and (type(def.rows) ~= "table" or type(def.defaults) ~= "table") then
		Fail(key .. ": rows must be a list of settings rows, with defaults for their keys")
	end
	order[#order + 1] = def
	byKey[key] = def
	return def
end

function Skins.List()
	local out = {}
	for i, def in ipairs(order) do
		out[i] = def
	end
	return out
end

function Skins.Get(key)
	return byKey[key]
end

function Skins.Close()
	closed = true
end

function Skins.Setting(key, field)
	local Store = K.Store
	local values = Store.IsLoaded() and Store.Module(MODULE)[key]
	local value
	if type(values) == "table" then
		value = values[field]
	end
	local def = byKey[key]
	local default = def and def.defaults and def.defaults[field]
	if field == "enabled" then
		default = true
	end
	if value == nil or type(value) ~= type(default) then
		return default
	end
	return value
end

function Skins.IsOn(key)
	return Skins.Setting(key, "enabled") == true
end

function Skins.IsApplied(key)
	return applied[key] == true
end

local function Run(def)
	if applied[def.key] or not running or not Skins.IsOn(def.key) then
		return
	end
	applied[def.key] = true
	if K.Call(def.Apply, def) then
		Log(def.key .. ": applied")
	else
		Log(def.key .. ": Apply failed; the window keeps the parts that were skinned")
	end
end

local function Apply(def)
	if InCombatLockdown() then
		Log(def.key .. ": waits for combat to end")
		K.Combat.Queue(function()
			Run(def)
		end)
		return
	end
	Run(def)
end

local function Shown(frame)
	local shown = frame:IsShown()
	return not IsSecret(shown) and shown == true
end

local function Watch(def)
	if not def.frame then
		Apply(def)
		return
	end
	local frame = _G[def.frame]
	if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then
		Log(def.key .. ": " .. def.frame .. " is missing on this client; the window keeps Blizzard's look")
		return
	end
	if not hooked[def.key] then
		hooked[def.key] = true
		frame:HookScript("OnShow", function()
			Apply(def)
		end)
	end
	if Shown(frame) then
		Apply(def)
	end
end

local function IsLoaded(def)
	if not def.addon then
		return true
	end
	local AddOns = C_AddOns
	if AddOns and type(AddOns.IsAddOnLoaded) == "function" then
		local ok, loaded = pcall(AddOns.IsAddOnLoaded, def.addon)
		if ok and not IsSecret(loaded) and loaded then
			return true
		end
	end
	return def.frame ~= nil and type(_G[def.frame]) == "table"
end

local function Arm(def)
	if applied[def.key] or not running or not Skins.IsOn(def.key) then
		return
	end
	if IsLoaded(def) then
		waiting[def.key] = nil
		Watch(def)
	elseif not waiting[def.key] then
		waiting[def.key] = true
		Log(def.key .. ": waits for " .. def.addon .. " to load")
	end
end

local function OnAddonLoaded(_, name)
	for _, def in ipairs(order) do
		if waiting[def.key] and def.addon == name then
			waiting[def.key] = nil
			Watch(def)
		end
	end
end

local function OnSetting(_, module, key, value)
	if module ~= MODULE or type(key) ~= "string" then
		return
	end
	local group = key:match("^(%w+)%.")
	if ns.Style.GROUPS[group] then
		ns.Style.RestyleAll()
		return
	end
	local def = group and byKey[group]
	if not def or key ~= group .. ".enabled" then
		return
	end
	if value == true then
		Arm(def)
	elseif applied[def.key] then
		K.Widgets.ReloadPrompt(string.format(L["%s keeps its KstyleUI look until you reload."], def.label))
	end
end

local function PromptSwitchedOff()
	local labels = {}
	for _, def in ipairs(order) do
		if applied[def.key] and not Skins.IsOn(def.key) then
			labels[#labels + 1] = def.label
		end
	end
	if #labels > 0 then
		K.Widgets.ReloadPrompt(string.format(L["%s keeps its KstyleUI look until you reload."], table.concat(labels, ", ")))
	end
end

local function ArmAll()
	for _, def in ipairs(order) do
		Arm(def)
	end
end

function Skins.Start()
	running = true
	K.Events.Register(MODULE, "ADDON_LOADED", OnAddonLoaded)
	K.Callbacks.Register("SettingChanged", MODULE, OnSetting)
	K.Callbacks.Register("ProfileChanged", MODULE, function()
		if not running then
			return
		end
		ns.Style.RestyleAll()
		ArmAll()
		PromptSwitchedOff()
	end)
	K.Callbacks.Register("ThemeChanged", MODULE, ns.Style.RestyleAll)
	ArmAll()
end

function Skins.Stop()
	running = false
	waiting = {}
end
