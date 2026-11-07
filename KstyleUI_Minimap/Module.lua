-- Module.lua: registers the Minimap module and its settings page with the core.
local _, ns = ...

local K = KstyleUI
local Settings = ns.Settings

K.Modules.Register({
	name = Settings.MODULE,
	defaults = Settings.defaults,
	reskin = true,
	Enable = function()
		ns.Map.Enable()
	end,
	Disable = function()
		ns.Map.Disable()
	end,
})

local schema = Settings.schema
schema.preview = ns.Preview.Build
K.Options.Register(Settings.MODULE, schema)
