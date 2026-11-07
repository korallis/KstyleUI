-- Vehicle.lua: the leave-vehicle button beside bar 1, which stands in for Blizzard's button that hides with the main bar.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L

local Vehicle = {}
ns.Vehicle = Vehicle

local function Flag(value)
	if ns.IsSecret(value) then
		return true
	end
	return value == true
end

local function CanLeave()
	if type(CanExitVehicle) ~= "function" then
		return false
	end
	return Flag(CanExitVehicle())
end

local function Leave()
	if type(UnitOnTaxi) == "function" and type(TaxiRequestEarlyLanding) == "function" and not ns.IsSecret(UnitOnTaxi("player")) and UnitOnTaxi("player") == true then
		TaxiRequestEarlyLanding()
	elseif type(VehicleExit) == "function" then
		VehicleExit()
	end
end

function Vehicle.Build()
	if ns.leaveButton then
		return ns.leaveButton
	end
	local button = Widgets.IconButton(K.Scale.Root(), {
		name = "KstyleUI_LeaveVehicleButton",
		icon = (Tokens.Texture("glyphClose")),
		crop = false,
		onClick = Leave,
		tooltip = L["Leave vehicle"],
	})
	button:Hide()
	ns.leaveButton = button
	return button
end

function Vehicle.Update()
	local button = ns.leaveButton
	if not button then
		return
	end
	local bar = ns.bars.bar1
	local size = bar and bar:Config().size or Tokens.Size("actionButton")
	if button.opts.size ~= size then
		button.opts.size = size
		button:Restyle()
	end
	button:ClearAllPoints()
	if bar then
		button:SetPoint("LEFT", bar.holder, "RIGHT", Widgets.Snap(button, Tokens.Size("gapMedium")), 0)
	else
		local root = K.Scale.Root()
		button:SetPoint("BOTTOM", root, "BOTTOM", 0, Tokens.Size("gapHuge"))
	end
	button:SetShown(ns.running and not ns.gamepad and CanLeave())
end
