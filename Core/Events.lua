-- Events.lua: one event frame per module, with events registered only while the module is on.
local _, ns = ...

local Events = {}
ns.Events = Events

local owners = {}

local function checkOwner(fnName, owner)
	if type(owner) ~= "string" or owner == "" then
		error("KstyleUI.Events." .. fnName .. ": owner must be a module or service name, got " .. tostring(owner), 3)
	end
	local Features = ns.Features
	if Features and Features.modules[owner] ~= nil and not ns.Modules.IsRunning(owner) then
		error("KstyleUI.Events." .. fnName .. ": module " .. owner .. " is off; register events in its Enable", 3)
	end
end

local function slot(owner)
	local entry = owners[owner]
	if not entry then
		local handlers = {}
		local frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, event, ...)
			local fn = handlers[event]
			if fn then
				ns.Call(fn, event, ...)
			end
		end)
		entry = { frame = frame, handlers = handlers }
		owners[owner] = entry
	end
	return entry
end

local function checkHandler(fnName, event, fn)
	if type(event) ~= "string" or event == "" then
		error("KstyleUI.Events." .. fnName .. ": event must be an event name, got " .. tostring(event), 3)
	end
	if type(fn) ~= "function" then
		error("KstyleUI.Events." .. fnName .. ": fn must be a function, got " .. type(fn), 3)
	end
end

function Events.Register(owner, event, fn)
	checkOwner("Register", owner)
	checkHandler("Register", event, fn)
	local entry = slot(owner)
	entry.handlers[event] = fn
	entry.frame:RegisterEvent(event)
end

function Events.RegisterUnit(owner, event, fn, unit1, unit2)
	checkOwner("RegisterUnit", owner)
	checkHandler("RegisterUnit", event, fn)
	if type(unit1) ~= "string" then
		error("KstyleUI.Events.RegisterUnit: at least one unit is required", 2)
	end
	local entry = slot(owner)
	entry.handlers[event] = fn
	if unit2 then
		entry.frame:RegisterUnitEvent(event, unit1, unit2)
	else
		entry.frame:RegisterUnitEvent(event, unit1)
	end
end

function Events.Unregister(owner, event)
	local entry = owners[owner]
	if entry and entry.handlers[event] then
		entry.handlers[event] = nil
		entry.frame:UnregisterEvent(event)
	end
end

function Events.UnregisterAll(owner)
	local entry = owners[owner]
	if entry then
		for event in pairs(entry.handlers) do
			entry.handlers[event] = nil
		end
		entry.frame:UnregisterAllEvents()
	end
end
