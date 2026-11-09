-- Module.lua: registers the Cooldowns module, its settings page, its smoke check and the tracked counts Apply's Edit Mode write sizes Blizzard's viewers by (the restyled buff row's grid and chip when that row is capped); nothing runs until Enable.
local _, ns = ...

local K = KstyleUI
local Settings, Mirror, Path, Cap, Data = ns.Settings, ns.Mirror, ns.Path, ns.Cap, ns.Data

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
local function Tracked(group)
	local count = Data.Count(group)
	if group == "buffs" and K.Modules.IsEnabled(ns.MODULE) and (Path.Get(group) == "reskin" or Path.Restyles(group, Settings.current.path)) then
		return Cap.Slots(count)
	end
	return count
end

if K.Setup and K.Setup.EditMode and K.Setup.EditMode.CountTracked then
	K.Setup.EditMode.CountTracked(Tracked)
end
Settings.schema.preview = ns.Preview.Build
K.Options.Register(ns.MODULE, Settings.schema)
