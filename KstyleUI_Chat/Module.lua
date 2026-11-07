-- Module.lua: registers the chat module with the core and runs its parts while it is on.
local _, ns = ...

local K = KstyleUI
local NAME = ns.NAME

local parts = { ns.Messages, ns.Panel, ns.Frames }

local function Refresh(key)
	local settings = ns.Settings()
	for _, part in ipairs(parts) do
		if part.Refresh then
			K.Call(part.Refresh, settings, key)
		end
	end
end

local def = { name = NAME, defaults = ns.defaults, reskin = true }
local checked = false

local function Check()
	if not K.Modules.IsRunning(NAME) then
		return true, "the chat module is off"
	end
	return ns.Panel.Status()
end

function def.Enable()
	local settings = ns.Settings()
	for _, part in ipairs(parts) do
		part.Start(settings)
	end
	if not checked then
		checked = true
		K.DevTest.AddCheck("chat panel", Check)
	end
	K.Callbacks.Register("SettingChanged", NAME, function(_, module, key)
		if module == NAME then
			Refresh(key)
		end
	end)
	K.Callbacks.Register("ProfileChanged", NAME, function()
		Refresh()
	end)
	K.Callbacks.Register("ThemeChanged", NAME, function()
		Refresh("theme")
	end)
	K.Callbacks.Register("ScaleChanged", NAME, function()
		Refresh("scale")
	end)
end

function def.Disable()
	for i = #parts, 1, -1 do
		K.Call(parts[i].Stop)
	end
end

K.Modules.Register(def)
K.Options.Register(NAME, ns.Schema())
