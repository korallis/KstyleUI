-- Frames.lua: the module's Enable and Disable: builds the headers once, applies the settings out of combat, places the holders with Layout, listens for group events and stands down for the gamepad interface.
local _, ns = ...

local K = KstyleUI
local Settings, Headers, Unit, Style, Blizzard = ns.Settings, ns.Headers, ns.Unit, ns.Style, ns.Blizzard

local Frames = { running = false, gamepad = false }
ns.Frames = Frames

local MODULE = Settings.MODULE
local KEYS = { party = "groupframes.party", raid = "groupframes.raid" }
local BLIZZARD_ADDON = "Blizzard_CompactRaidFrames"

local registered = false
local queued = false
local settling = false

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

function Frames.Active()
	return Frames.running and not Frames.gamepad
end

local function Register()
	if registered then
		return
	end
	registered = true
	local Layouts = K.Setup and K.Setup.Layouts
	for kind, key in pairs(KEYS) do
		local holder = Headers.holders[kind]
		local element = Layouts and Layouts.Element(key)
		local position = Layouts and Layouts.Default(key) or { anchor = "TOPLEFT", x = 0, y = 0 }
		K.Widgets.Place(holder, key, position, {
			label = element and element.label or key,
			module = MODULE,
			scalable = true,
		})
	end
end

local function Restore()
	if K.Layout and K.Layout.Restore then
		for _, key in pairs(KEYS) do
			K.Layout.Restore(key)
		end
	end
end

local function ApplySecure()
	local cfg = Settings.Refresh()
	Headers.ApplyParty(cfg.party)
	Headers.ApplyRaid(cfg.raid)
	Unit.ForEach(Style.Apply)
	Register()
	Restore()
	Unit.RefreshAll()
end

function Frames.Apply()
	if not Frames.Active() then
		return
	end
	if InCombatLockdown() then
		if not queued then
			queued = true
			K.Combat.Queue(function()
				queued = false
				if Frames.Active() then
					ApplySecure()
				end
			end)
		end
		return
	end
	ApplySecure()
end

local function Restyle()
	Settings.Refresh()
	Unit.ForEach(Style.Apply)
	Unit.RefreshAll()
end

local function OnSetting(_, module, key)
	if module ~= MODULE then
		return
	end
	Settings.Refresh()
	if type(key) == "string" and key:match("^blizzard%.") then
		Blizzard.Apply(Frames.Active())
		return
	end
	Frames.Apply()
end

local function OnProfile()
	Settings.Refresh()
	Blizzard.Apply(Frames.Active())
	Frames.Apply()
end

local function OnLayout(_, key)
	if key == KEYS.party or key == KEYS.raid then
		Restyle()
	end
end

local function Listen()
	local Events, Callbacks = K.Events, K.Callbacks
	Events.Register(MODULE, "GROUP_ROSTER_UPDATE", Unit.RefreshAll)
	Events.Register(MODULE, "PLAYER_ENTERING_WORLD", Unit.RefreshAll)
	Events.Register(MODULE, "PLAYER_TARGET_CHANGED", Unit.TargetAll)
	Events.Register(MODULE, "ADDON_LOADED", function(_, addon)
		if addon == BLIZZARD_ADDON then
			Blizzard.Apply(Frames.Active())
		end
	end)
	Events.Register(MODULE, "INPUT_DEVICE_INTERFACE_TRANSITION", Frames.OnTransition)
	for _, extra in ipairs(Frames.events) do
		Events.Register(MODULE, extra.event, extra.fn)
	end
	Callbacks.Register("SettingChanged", MODULE, OnSetting)
	Callbacks.Register("ProfileChanged", MODULE, OnProfile)
	Callbacks.Register("ThemeChanged", MODULE, function()
		Unit.ForEach(Style.Paint)
		Unit.RefreshAll()
	end)
	Callbacks.Register("ScaleChanged", MODULE, Restyle)
	Callbacks.Register("LayoutChanged", MODULE, OnLayout)
end

Frames.events = {}

local function Start()
	Headers.Show()
	ApplySecure()
end

local function FollowUnits(on)
	Unit.running = on
	Unit.ListenAll()
	local changed = Unit.changed
	Unit.ForEach(function(f)
		for i = 1, #changed do
			changed[i](f)
		end
	end)
end

local function Settle()
	settling = false
	if Frames.running then
		Headers.Build()
	end
	if Frames.Active() then
		FollowUnits(true)
		Start()
	else
		Headers.Stop()
		FollowUnits(false)
	end
end

local function Converge()
	if not InCombatLockdown() then
		Settle()
	elseif not settling then
		settling = true
		K.Combat.Queue(Settle)
	end
end

local function Follow()
	Blizzard.Apply(Frames.Active())
	Converge()
end

function Frames.OnTransition()
	local gamepad = Blizzard.GamepadStyle()
	if gamepad == Frames.gamepad then
		return
	end
	Frames.gamepad = gamepad
	if gamepad then
		Log("the gamepad interface is on: Blizzard's party and raid frames return for gamepad group targeting and KstyleUI's group frames hide")
	else
		Log("keyboard and mouse again: KstyleUI's group frames return and Blizzard's hide")
	end
	Follow()
end

function Frames.Enable()
	Frames.running = true
	Frames.gamepad = Blizzard.GamepadStyle()
	Settings.Refresh()
	if InCombatLockdown() then
		Log("enabled in combat; the frames are built when combat ends")
	end
	Follow()
	Listen()
	if Frames.gamepad then
		Log("the gamepad interface is on: KstyleUI's group frames wait and Blizzard's stay for gamepad group targeting")
	end
	Log("party and raid headers are on SecureGroupHeaderTemplate")
end

function Frames.Disable()
	Frames.running = false
	Follow()
end

K.DevTest.AddCheck("GroupFrames", function()
	if not Frames.running then
		return true, "off"
	end
	if Frames.gamepad then
		return true, "standing down for the gamepad interface"
	end
	if not Headers.built then
		return false, "the headers were not built"
	end
	local missing = {}
	for _, name in ipairs({ "UnitHealthPercent", "UnitInRange", "RegisterStateDriver", "AbbreviateNumbers" }) do
		if _G[name] == nil then
			missing[#missing + 1] = name
		end
	end
	if #missing > 0 then
		return false, "missing " .. table.concat(missing, ", ")
	end
	return true, "party and raid headers built"
end)
