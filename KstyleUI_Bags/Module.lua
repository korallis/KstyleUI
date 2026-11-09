-- Module.lua: registers KstyleUI_Bags with the core: its switch, settings page, preview, events and callbacks.
local _, ns = ...

local K = KstyleUI
local Settings, Inventory, Bank, Blizzard, Junk, Alts = ns.Settings, ns.Inventory, ns.Bank, ns.Blizzard, ns.Junk, ns.Alts
local MODULE = Settings.MODULE

local function Dispatch(event, ...)
	local list = ns.handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		K.Call(list[i], event, ...)
	end
end

local function Restyle()
	for _, window in ipairs({ Inventory.window or false, Bank.window or false }) do
		if window then
			window:Paint(true)
		end
	end
end

local function SettingsChanged(_, key)
	Inventory.SettingsChanged(key)
	Bank.SettingsChanged(key)
end

local engaged = false

local function Engage()
	if engaged or not Blizzard.Start() then
		return
	end
	engaged = true
	for event in pairs(ns.handlers) do
		K.Events.Register(MODULE, event, Dispatch)
	end
	Inventory.Enable()
	Bank.Enable()
	Junk.Enable()
	Alts.Enable()
end

local function Disengage()
	if engaged then
		engaged = false
		Alts.Disable()
		Junk.Disable()
		Bank.Disable()
		Inventory.Disable()
		for event in pairs(ns.handlers) do
			K.Events.Unregister(MODULE, event)
		end
	end
	Blizzard.Stop()
end

local function FollowStyle()
	if not K.Modules.IsRunning(MODULE) then
		return
	end
	if Blizzard.GamepadStyle() then
		if engaged then
			ns.Log("the gamepad interface style came on; Blizzard's bags and bank return, because its D-pad navigates them")
			Disengage()
		end
	elseif not engaged then
		ns.Log("the keyboard and mouse interface style came on; KstyleUI's bags and bank take over again")
		Engage()
	end
end

local function StyleChanged()
	K.Combat.Queue(FollowStyle)
end

local function Enable()
	K.Events.Register(MODULE, "INPUT_DEVICE_INTERFACE_TRANSITION", StyleChanged)
	K.Callbacks.Register("SettingChanged", MODULE, function(_, module, key)
		if module == MODULE then
			SettingsChanged(nil, key)
		end
	end)
	K.Callbacks.Register("ProfileChanged", MODULE, SettingsChanged)
	K.Callbacks.Register("ThemeChanged", MODULE, Restyle)
	K.Callbacks.Register("LayoutChanged", MODULE, function(_, key)
		local window = (key == Inventory.KEY and Inventory.window) or (key == Bank.KEY and Bank.window)
		if window then
			window:ScaleChanged()
		end
	end)
	Engage()
end

local function Disable()
	Disengage()
end

local function Check()
	if not K.Modules.IsRunning(MODULE) then
		return true, "off"
	end
	if not Blizzard.IsActive() then
		return true, "standing down for the gamepad interface style"
	end
	local window = Inventory.window
	if not window then
		return false, "the bag window was not built"
	end
	if not K.Safe.IsHidden(ContainerFrameCombinedBags) then
		return false, "Blizzard's combined bags are not hidden"
	end
	local bank = "Blizzard's bank kept"
	if Bank.IsReplaced() then
		if not K.Safe.IsHidden(BankFrame) and not Bank.WaitingForVisit() then
			return false, "Blizzard's bank is not hidden"
		end
		bank = "Blizzard's bank hidden"
	end
	local slots = 0
	for _, section in ipairs(window.sections) do
		slots = slots + #section.order
	end
	return true, "bag window built with " .. slots .. " slots; Blizzard's bags hidden; " .. bank
end

K.Modules.Register({ name = MODULE, defaults = Settings.defaults, Enable = Enable, Disable = Disable })
K.DevTest.AddCheck("bags", Check)
Settings.schema.preview = ns.Preview.Build
K.Options.Register(MODULE, Settings.schema)
