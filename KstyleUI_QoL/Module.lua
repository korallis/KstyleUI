-- Module.lua: registers QoL with the core, off by default, routes each part's events while it runs, and passes setting and profile changes to the parts.
local _, ns = ...

local K = ns.K
local MODULE = ns.MODULE

local function Each(hook, ...)
	for _, part in ipairs(ns.parts) do
		local fn = part[hook]
		if fn then
			K.Call(fn, ...)
		end
	end
end

local function Enable()
	ns.running = true
	for _, part in ipairs(ns.parts) do
		for event, fn in pairs(part.events or {}) do
			K.Events.Register(MODULE, event, fn)
		end
	end
	K.Callbacks.Register("SettingChanged", MODULE, function(_, module, key)
		if module == MODULE and type(key) == "string" then
			Each("Setting", key)
		end
	end)
	K.Callbacks.Register("ProfileChanged", MODULE, function()
		Each("Setting", nil)
	end)
	Each("Start")
end

local function Disable()
	ns.running = false
	Each("Stop")
end

K.Modules.Register({ name = MODULE, defaults = ns.defaults, Enable = Enable, Disable = Disable })
K.Options.Register(MODULE, ns.schema)

K.DevTest.AddCheck("QoL", function()
	if not K.Modules.IsRunning(MODULE) then
		return true, "off"
	end
	local on = {}
	for _, key in ipairs({ "fastLoot", "lootFeed", "autoRepair", "guildRepair", "autoQuests", "maxCamera", "quietErrors" }) do
		if ns.Get(key) then
			on[#on + 1] = key
		end
	end
	return true, #on > 0 and ("on: " .. table.concat(on, ", ")) or "every helper is off"
end)
