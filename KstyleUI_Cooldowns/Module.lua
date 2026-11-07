-- Module.lua: registers the Cooldowns module, its settings page and its smoke check; nothing runs until Enable.
local _, ns = ...

local K = KstyleUI
local Settings, Mirror = ns.Settings, ns.Mirror

local checkAdded = false

local function Check()
	if not K.Modules.IsRunning(ns.MODULE) then
		return true, "off"
	end
	return true, Mirror.Report()
end

local function Enable()
	if not checkAdded and K.DevTest and K.DevTest.AddCheck then
		checkAdded = true
		K.DevTest.AddCheck("cooldowns", Check)
	end
	Mirror.Start()
end

local function Disable()
	Mirror.Stop()
end

ns.definition = { name = ns.MODULE, defaults = Settings.defaults, Enable = Enable, Disable = Disable, reskin = true }
K.Modules.Register(ns.definition)
Settings.schema.preview = ns.Preview.Build
K.Options.Register(ns.MODULE, Settings.schema)
