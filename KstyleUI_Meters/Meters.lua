-- Meters.lua: registers the Meters module, runs its three parts and shares one event frame between them.
local _, ns = ...

local K = KstyleUI
local MODULE = ns.MODULE

local parts = { ns.Damage, ns.Threat, ns.Swing }
local watchers = {}
local running = false

local scratch, depth = {}, 0

local function Dispatch(event, ...)
	local list = watchers[event]
	if not list then
		return
	end
	depth = depth + 1
	local copy = scratch[depth]
	if not copy then
		copy = {}
		scratch[depth] = copy
	end
	local n = #list
	for i = 1, n do
		copy[i] = list[i]
	end
	for i = 1, n do
		local part = copy[i]
		copy[i] = nil
		K.Call(part.OnEvent, part, event, ...)
	end
	depth = depth - 1
end

function ns.Watch(part, event)
	if not running then
		return
	end
	local list = watchers[event]
	if not list then
		list = {}
		watchers[event] = list
	end
	for i = 1, #list do
		if list[i] == part then
			return
		end
	end
	list[#list + 1] = part
	if #list == 1 then
		K.Events.Register(MODULE, event, Dispatch)
	end
end

function ns.Unwatch(part, event)
	local list = watchers[event]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if list[i] == part then
			table.remove(list, i)
		end
	end
	if #list == 0 then
		watchers[event] = nil
		if running then
			K.Events.Unregister(MODULE, event)
		end
	end
end

function ns.UnwatchAll(part)
	local events = {}
	for event in pairs(watchers) do
		events[#events + 1] = event
	end
	for _, event in ipairs(events) do
		ns.Unwatch(part, event)
	end
end

function ns.IsRunning()
	return running
end

local function ApplyAll()
	for _, part in ipairs(parts) do
		K.Call(part.Apply, part)
	end
end

local function OnSetting(_, module, key)
	if module ~= MODULE or not running then
		return
	end
	local section = type(key) == "string" and key:match("^(%w+)%.") or nil
	for _, part in ipairs(parts) do
		if section == nil or section == part.section then
			K.Call(part.Apply, part)
		end
	end
end

local function OnLayout(_, key)
	for _, part in ipairs(parts) do
		if part.key == key and part.Resized then
			K.Call(part.Resized, part)
		end
	end
end

local function Enable()
	running = true
	for _, part in ipairs(parts) do
		K.Call(part.Start, part)
	end
	K.Callbacks.Register("SettingChanged", MODULE, OnSetting)
	K.Callbacks.Register("ThemeChanged", MODULE, ApplyAll)
	K.Callbacks.Register("ProfileChanged", MODULE, ApplyAll)
	K.Callbacks.Register("LayoutChanged", MODULE, OnLayout)
end

local function Disable()
	for _, part in ipairs(parts) do
		K.Call(part.Stop, part)
		ns.UnwatchAll(part)
	end
	running = false
	for event in pairs(watchers) do
		watchers[event] = nil
	end
end

K.Modules.Register({ name = MODULE, defaults = ns.defaults, Enable = Enable, Disable = Disable })
K.Options.Register(MODULE, ns.schema)
