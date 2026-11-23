-- Modules.lua: module registration and the Enable and Disable lifecycle.
local _, ns = ...

local Modules = {}
ns.Modules = Modules

local L = ns.L
local entries, order = {}, {}
local loggedIn = false
local reloadNeeded = false

local function log(name, message)
	ns.DevTest.Log(name, message)
end

local function switchOn(name)
	local Store = ns.Store
	return Store.IsLoaded() and Store.Module(name).enabled == true
end

local function release(entry)
	entry.running = false
	ns.Events.UnregisterAll(entry.name)
	ns.Callbacks.UnregisterAll(entry.name)
end

local function start(entry)
	if entry.running then
		return
	end
	entry.running = true
	entry.failed = false
	if ns.Call(entry.def.Enable, entry.def) then
		log(entry.name, "enabled")
		ns.Callbacks.Fire("ModuleChanged", entry.name, true)
		return
	end
	entry.failed = true
	ns.Call(entry.def.Disable, entry.def)
	release(entry)
	log(entry.name, "Enable failed; Disable ran to clean up")
	ns.Callbacks.Fire("ModuleChanged", entry.name, false)
end

local function stop(entry)
	if not entry.running then
		return
	end
	ns.Call(entry.def.Disable, entry.def)
	release(entry)
	log(entry.name, "disabled")
	ns.Callbacks.Fire("ModuleChanged", entry.name, false)
	if entry.def.reskin then
		reloadNeeded = true
		ns.Print(string.format(L["%s keeps its changes to Blizzard's frames until you reload. Type /reload to finish turning it off."], entry.name))
		ns.Callbacks.Fire("ReloadNeeded", entry.name)
	end
end

local function reconcile(entry)
	if switchOn(entry.name) then
		start(entry)
	else
		stop(entry)
	end
end

local function apply(entry)
	if loggedIn then
		ns.Combat.Queue(function()
			reconcile(entry)
		end)
	end
end

function Modules.Register(def)
	if type(def) ~= "table" then
		error("KstyleUI.Modules.Register: def must be a table, got " .. type(def), 2)
	end
	local name = def.name
	ns.Features.Get("modules", name)
	if entries[name] then
		error("KstyleUI.Modules.Register: " .. name .. " is already registered", 2)
	end
	if type(def.Enable) ~= "function" then
		error("KstyleUI.Modules.Register: " .. name .. " needs an Enable function", 2)
	end
	if type(def.Disable) ~= "function" then
		error("KstyleUI.Modules.Register: " .. name .. " needs a Disable function", 2)
	end
	if def.defaults ~= nil and type(def.defaults) ~= "table" then
		error("KstyleUI.Modules.Register: " .. name .. " defaults must be a table", 2)
	end
	if def.reskin ~= nil and type(def.reskin) ~= "boolean" then
		error("KstyleUI.Modules.Register: " .. name .. " reskin must be true or false", 2)
	end
	ns.Store.RegisterDefaults(name, def.defaults or {})
	local entry = { name = name, def = def, running = false, failed = false }
	entries[name] = entry
	order[#order + 1] = name
	apply(entry)
end

function Modules.IsEnabled(name)
	ns.Features.Get("modules", name)
	return entries[name] ~= nil and switchOn(name)
end

function Modules.IsRunning(name)
	local entry = entries[name]
	return entry ~= nil and entry.running
end

function Modules.HasFailed(name)
	local entry = entries[name]
	return entry ~= nil and entry.failed
end

local function setSwitch(name, on)
	ns.Features.Get("modules", name)
	if not ns.Store.IsLoaded() then
		return false
	end
	ns.Store.Module(name).enabled = on
	local entry = entries[name]
	if entry then
		apply(entry)
	end
	return true
end

function Modules.Enable(name)
	return setSwitch(name, true)
end

function Modules.Disable(name)
	return setSwitch(name, false)
end

function Modules.List()
	local names = {}
	for i, name in ipairs(order) do
		names[i] = name
	end
	return names
end

function Modules.NeedsReload()
	return reloadNeeded
end

ns.Events.Register("Modules", "PLAYER_LOGIN", function()
	ns.Events.Unregister("Modules", "PLAYER_LOGIN")
	loggedIn = true
	for _, name in ipairs(order) do
		local entry = entries[name]
		if switchOn(name) then
			start(entry)
		end
	end
end)

ns.Callbacks.Register("ProfileChanged", "Modules", function()
	for _, name in ipairs(order) do
		apply(entries[name])
	end
end)
