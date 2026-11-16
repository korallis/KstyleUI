-- Vehicle.lua: the leave-vehicle slot beside bar 1, or below its outer end under Medallions.
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
	local button = Widgets.Slot(K.Scale.Root(), {
		name = "KstyleUI_LeaveVehicleButton",
		icon = (Tokens.Texture("glyphClose")),
		crop = false,
		onClick = Leave,
		tooltip = L["Leave vehicle"],
		primary = true,
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
	if InCombatLockdown() and not ns.enabling then
		ns.QueueApply()
		return
	end
	local bar = ns.bars.bar1
	button:SetScale(bar and bar.holder:GetScale() or 1)
	local size = bar and bar:Config().size or Tokens.Size("actionButton")
	if bar and K.HudStyle.Current() == "medallions" then
		size = ns.Slab.Size(bar.def, bar:Config())
	end
	if button.opts.size ~= size then
		button.opts.size = size
		button:Restyle()
	end
	button:ClearAllPoints()
	if bar and K.HudStyle.Current() == "medallions" then
		local slab = ns.Slab.Spec()
		button:SetPoint("TOPLEFT", bar.holder, "BOTTOMLEFT", 0, -Widgets.Snap(button, slab.stripGap + slab.strip + slab.bottom + Tokens.Size("gapSmall")))
	elseif bar and K.HudStyle.Current() == "orbs" then
		local width = bar.holder:GetWidth()
		local art = K.Setup.Layouts.OrbsTray(width)
		button:SetPoint("LEFT", bar.holder, "RIGHT", Widgets.Snap(button, art.ringX + art.ring / 2 - width / 2 + Tokens.Size("gapMedium")), 0)
	elseif bar then
		local pad = ns.Config("tray") == true and K.Setup.Layouts.TRAY_PAD or 0
		local stance = ns.bars.stance
		local anchor = K.HudStyle.Current() == "frames" and stance and stance:Shown() and stance.count > 0 and stance.holder or bar.holder
		button:SetPoint("LEFT", anchor, "RIGHT", Widgets.Snap(button, Tokens.Size("gapMedium") + pad), 0)
	else
		local root = K.Scale.Root()
		button:SetPoint("BOTTOM", root, "BOTTOM", 0, Tokens.Size("gapHuge"))
	end
	local shown = ns.running and not ns.gamepad and CanLeave()
	button:SetShown(shown)
end
