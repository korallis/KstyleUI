-- Module.lua: registers KstyleUI_GroupFrames with the core: its settings, its schema and its Enable and Disable.
local _, ns = ...

local K = KstyleUI
local Settings = ns.Settings

K.Modules.Register({
	name = Settings.MODULE,
	defaults = Settings.defaults,
	Enable = function()
		ns.Frames.Enable()
	end,
	Disable = function()
		ns.Frames.Disable()
	end,
})
K.Options.Register(Settings.MODULE, Settings.schema)
