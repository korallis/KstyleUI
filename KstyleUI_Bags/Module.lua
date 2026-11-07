-- Module.lua: registers KstyleUI_Bags with the core: its switch, settings page, preview, events and callbacks.
local _, ns = ...

local K = KstyleUI
local Settings, Inventory, Bank, Blizzard, Junk = ns.Settings, ns.Inventory, ns.Bank, ns.Blizzard, ns.Junk
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

local function Enable()
	if not Blizzard.Start() then
		return
	end
	for event in pairs(ns.handlers) do
		K.Events.Register(MODULE, event, Dispatch)
	end
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
	Inventory.Enable()
	Bank.Enable()
	Junk.Enable()
end

local function Disable()
	Junk.Disable()
	Bank.Disable()
	Inventory.Disable()
	Blizzard.Stop()
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
