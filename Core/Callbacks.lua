-- Callbacks.lua: the dispatcher for ThemeChanged, ClassChanged, ScaleChanged, ProfileChanged, SettingChanged, ReloadNeeded, LayoutChanged and ModuleChanged.
local _, ns = ...

local Callbacks = {}
ns.Callbacks = Callbacks

local EVENTS = {
	ThemeChanged = true,
	ClassChanged = true,
	ScaleChanged = true,
	ProfileChanged = true,
	SettingChanged = true,
	ReloadNeeded = true,
	LayoutChanged = true,
	ModuleChanged = true,
}

local lists = {}
local firing = 0
local dirty = false

local function checkEvent(fnName, event)
	if not EVENTS[event] then
		error("KstyleUI.Callbacks." .. fnName .. ": unknown callback " .. tostring(event), 3)
	end
end

local function compact()
	for _, list in pairs(lists) do
		local write = 0
		for read = 1, #list do
			local entry = list[read]
			list[read] = nil
			if not entry.dead then
				write = write + 1
				list[write] = entry
			end
		end
	end
	dirty = false
end

local function remove(list, entry)
	entry.dead, entry.fn = true, nil
	if firing > 0 then
		dirty = true
		return
	end
	for i = #list, 1, -1 do
		if list[i] == entry then
			table.remove(list, i)
		end
	end
end

function Callbacks.Register(event, owner, fn)
	checkEvent("Register", event)
	if owner == nil then
		error("KstyleUI.Callbacks.Register: an owner is required to unregister later", 2)
	end
	if type(fn) ~= "function" then
		error("KstyleUI.Callbacks.Register: fn must be a function, got " .. type(fn), 2)
	end
	local list = lists[event]
	if not list then
		list = {}
		lists[event] = list
	end
	for _, entry in ipairs(list) do
		if entry.owner == owner and not entry.dead then
			entry.fn = fn
			return
		end
	end
	list[#list + 1] = { owner = owner, fn = fn }
end

function Callbacks.Unregister(event, owner)
	checkEvent("Unregister", event)
	local list = lists[event]
	if not list then
		return
	end
	for _, entry in ipairs(list) do
		if entry.owner == owner and not entry.dead then
			remove(list, entry)
			return
		end
	end
end

function Callbacks.UnregisterAll(owner)
	for event in pairs(lists) do
		Callbacks.Unregister(event, owner)
	end
end

function Callbacks.Fire(event, ...)
	checkEvent("Fire", event)
	local list = lists[event]
	if not list then
		return
	end
	firing = firing + 1
	local n = #list
	for i = 1, n do
		local entry = list[i]
		if entry and not entry.dead then
			ns.Call(entry.fn, entry.owner, ...)
		end
	end
	firing = firing - 1
	if firing == 0 and dirty then
		compact()
	end
end
