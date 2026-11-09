-- Module.lua: registers the Nameplates module, its settings page and preview, and starts and stops the plates.
local _, ns = ...

local K = KstyleUI
local Settings, Plates, CVars, Stacking, Preview = ns.Settings, ns.Plates, ns.CVars, ns.Stacking, ns.Preview
local MODULE = Settings.MODULE

local checkAdded = false

local SIGIL_KEY = {}
for _, key in ipairs(ns.Cast.SIGIL_KEYS) do
	SIGIL_KEY[key] = true
end

local function Rehighlight()
	if Plates.running then
		Plates.Each(function(plate)
			plate:UpdateHighlight()
		end)
	end
end

local function OnModule(_, name)
	if name == ns.Cast.SIGIL_MODULE then
		Rehighlight()
	end
end

local function OnSetting(_, module, key)
	if module == ns.Cast.SIGIL_MODULE and SIGIL_KEY[key] then
		Rehighlight()
		return
	end
	if module ~= MODULE then
		return
	end
	Settings.Invalidate()
	if type(key) == "string" and key:find("^cvars%.") then
		CVars.Schedule()
		return
	end
	if key == "threat.role" then
		Plates.GLOBAL_EVENTS.PLAYER_ROLES_ASSIGNED()
	elseif key == "cast.interruptSpell" and Plates.running then
		ns.Interrupt.Resolve()
	end
	Plates.RestyleAll()
	Stacking.Schedule()
end

local function OnProfile()
	Settings.Invalidate()
	Plates.GLOBAL_EVENTS.PLAYER_ROLES_ASSIGNED()
	if Plates.running then
		ns.Interrupt.Resolve()
	end
	Plates.ReadSize()
	Plates.RestyleAll()
	CVars.Schedule()
	Stacking.Schedule()
end

local function OnLayout(_, key)
	if key == Plates.LAYOUT_KEY then
		Plates.ReadSize()
		Plates.RestyleAll()
		Stacking.Schedule()
	end
end

local function AddCheck()
	if checkAdded then
		return
	end
	checkAdded = true
	K.DevTest.AddCheck("Nameplates", function()
		if not Plates.running then
			return true, "the module is off"
		end
		local api = C_NamePlate and C_NamePlate.GetNamePlateForUnit
		if not api then
			return false, "C_NamePlate.GetNamePlateForUnit is missing"
		end
		return true, Plates.Count() .. " plates attached"
	end)
end

local function Enable()
	Plates.Start()
	K.Callbacks.Register("SettingChanged", MODULE, OnSetting)
	K.Callbacks.Register("ProfileChanged", MODULE, OnProfile)
	K.Callbacks.Register("LayoutChanged", MODULE, OnLayout)
	K.Callbacks.Register("ScaleChanged", MODULE, Stacking.Schedule)
	K.Callbacks.Register("ModuleChanged", MODULE, OnModule)
	Preview.Register()
	Plates.ReadSize()
	Plates.RestyleAll()
	CVars.Schedule()
	Stacking.Schedule()
	AddCheck()
end

local function Disable()
	Plates.Stop()
	Preview.Hide()
	CVars.Schedule()
	Stacking.Schedule()
end

K.Modules.Register({
	name = MODULE,
	defaults = Settings.defaults,
	Enable = Enable,
	Disable = Disable,
})

Settings.schema.preview = Preview.Build
K.Options.Register(MODULE, Settings.schema)
