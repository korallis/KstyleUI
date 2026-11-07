-- Module.lua: registers DataBars with the core, off by default, and runs each part's Enable, Disable and setting changes.
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
		if part.Enable then
			part.Enable()
		end
	end
	ns.StartListening()
end

local function Disable()
	ns.running = false
	for i = #ns.parts, 1, -1 do
		local part = ns.parts[i]
		if part.Disable then
			K.Call(part.Disable)
		end
	end
end

ns.Subscribe("SettingChanged", function(module, key)
	if module == MODULE and ns.running and type(key) == "string" then
		Each("Setting", key)
	end
end)

for _, callback in ipairs({ "ProfileChanged", "ThemeChanged", "ScaleChanged" }) do
	ns.Subscribe(callback, function()
		if ns.running then
			Each("Refresh")
		end
	end)
end

ns.schema.preview = ns.Preview

K.Modules.Register({ name = MODULE, defaults = ns.defaults, Enable = Enable, Disable = Disable })
K.Options.Register(MODULE, ns.schema)

K.DevTest.AddCheck("DataBars", function()
	if not K.Modules.IsRunning(MODULE) then
		return true, "off"
	end
	local shown = {}
	for _, def in ipairs(ns.Bars.DEFS) do
		local view = ns.Bars.views[def.id]
		shown[#shown + 1] = def.id .. "=" .. (view and view.content:IsShown() and "shown" or tostring(view and view.why or "unbuilt"))
	end
	local menus = {}
	for _, id in ipairs({ "micro", "bags" }) do
		local blizzard = _G[ns.Menus.GROUPS[id].hide]
		menus[#menus + 1] = id .. " " .. #ns.Menus.Shown(id) .. " buttons, Blizzard's " .. (blizzard and K.Safe.IsHidden(blizzard) and "hidden" or "shown")
	end
	return true, table.concat(shown, ", ") .. (ns.Blizzard.IsFaded() and "; Blizzard bars faded" or "; Blizzard bars shown") .. "; " .. table.concat(menus, "; ")
end)
