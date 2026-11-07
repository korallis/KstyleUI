-- Init.lua: the KstyleUI_DataBars addon table, which the module's files share, with its log, event and callback hubs.
local addonName, ns = ...

local K = KstyleUI

ns.addonName = addonName
ns.MODULE = "DataBars"
ns.K = K
ns.L = K.L
ns.parts = {}
ns.defaults = {}
ns.schema = {}

local MODULE = ns.MODULE
local logged = {}
local events, callbacks = {}, {}
local eventOrder, callbackOrder = {}, {}

function ns.Log(message)
	K.DevTest.Log(MODULE, message)
end

function ns.LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		ns.Log(message)
	end
end

function ns.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function ns.IsNumber(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function ns.Settings()
	return K.Store.Module(MODULE)
end

function ns.Accent()
	local s = ns.Settings()
	local c = s.accentColor
	if s.accentSource == "custom" and type(c) == "table" and ns.IsNumber(c.r) and ns.IsNumber(c.g) and ns.IsNumber(c.b) then
		return c.r, c.g, c.b
	end
	return K.Theme.Accent()
end

function ns.AddPart(part)
	ns.parts[#ns.parts + 1] = part
end

function ns.AddRows(rows)
	for _, row in ipairs(rows) do
		ns.schema[#ns.schema + 1] = row
	end
end

local function add(store, order, name, fn)
	local list = store[name]
	if not list then
		list = {}
		store[name] = list
		order[#order + 1] = name
	end
	list[#list + 1] = fn
end

function ns.Listen(event, fn)
	add(events, eventOrder, event, fn)
end

function ns.Subscribe(callback, fn)
	add(callbacks, callbackOrder, callback, fn)
end

local function dispatch(list)
	return function(...)
		for i = 1, #list do
			K.Call(list[i], ...)
		end
	end
end

function ns.StartListening()
	for _, event in ipairs(eventOrder) do
		K.Events.Register(MODULE, event, dispatch(events[event]))
	end
	for _, callback in ipairs(callbackOrder) do
		local run = dispatch(callbacks[callback])
		K.Callbacks.Register(callback, MODULE, function(_, ...)
			run(...)
		end)
	end
end
