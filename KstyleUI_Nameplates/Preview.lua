-- Preview.lua: sample plates for the settings window's live preview and for Layout Mode, where resizing the sample sizes every plate.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Settings, Plates = ns.Settings, ns.Plates

local Preview = {}
ns.Preview = Preview

local SAMPLE_Y = 160
local SIZE_LIMITS = { minWidth = 40, maxWidth = 320, minHeight = 4, maxHeight = 40 }

Preview.SAMPLES = {
	{
		name = L["Dark Iron Summoner"], level = 51, classification = "elite", health = 0.64,
		enemy = true, reaction = 2, isPlayer = false, target = true, raid = 8, caster = true,
		cast = { text = L["Molten Pulse"], texture = 135812, time = "2.8", progress = 0.45, notInterruptible = false },
	},
	{
		name = L["Elunara"], level = 60, classification = "normal", health = 0.81,
		enemy = true, reaction = 2, isPlayer = true, class = "PRIEST", threat = "warning",
		cast = { text = L["Greater Heal"], texture = 135913, time = "1.2", progress = 0.7, notInterruptible = true },
	},
	{
		name = L["Thaldrin"], level = 60, classification = "normal", health = 0.92,
		enemy = false, reaction = 5, isPlayer = true, class = "PALADIN", focus = true,
	},
}

local function Span(plate)
	local w, above, h, below = ns.Stacking.Extent(plate)
	if not w then
		return nil
	end
	local side = w - ns.state.width
	return ns.state.width + side * 2, above + h + below, side, above
end

local function Stack(frame)
	local width, height = frame:GetWidth(), frame:GetHeight()
	local known = type(width) == "number" and width > 0 and type(height) == "number" and height > 0
	local chosen, smallest
	for i, plate in ipairs(frame.plates) do
		local w, h = Span(plate)
		if not known or (w and w <= width and h <= height) then
			chosen = i
			break
		end
		local share = w and math.min(width / w, height / h)
		if share and (not smallest or share > smallest) then
			chosen, smallest = i, share
		end
	end
	chosen = chosen or 1
	for i, plate in ipairs(frame.plates) do
		local holder = plate:GetParent()
		holder:ClearAllPoints()
		if i == chosen then
			local w, h, side, above = Span(plate)
			local scale = 1
			if known and w then
				scale = math.min(1, width / w, height / h)
			end
			holder:SetScale(scale)
			if w then
				K.Widgets.Size(holder, w, h)
				K.Widgets.Point(holder, "CENTER", frame, "CENTER")
				plate:ClearAllPoints()
				plate:SetPoint("TOPLEFT", holder, "TOPLEFT", K.Widgets.Snap(plate, side), -K.Widgets.Snap(plate, above))
			else
				holder:SetPoint("CENTER", frame, "CENTER")
			end
		end
		holder:SetShown(i == chosen)
	end
	frame.chosen = chosen
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame.plates = {}
	for i, sample in ipairs(Preview.SAMPLES) do
		local holder = CreateFrame("Frame", nil, frame)
		holder:SetSize(1, 1)
		local plate = ns.NewPlate(holder, sample)
		Plates.AddSample(plate)
		frame.plates[i] = plate
	end
	Stack(frame)
	frame:SetScript("OnSizeChanged", Stack)
	function frame.Refresh()
		Settings.Invalidate()
		if not Plates.running then
			Plates.ReadSize()
		end
		for _, plate in ipairs(frame.plates) do
			plate:Restyle()
		end
		Stack(frame)
	end
	return frame
end

local layoutHooked = false

local function ShowSample(shown)
	local sample = Preview.sample
	if sample then
		sample:SetShown(shown and Plates.running and K.Layout.IsActive() == true)
	end
end

local function HookLayout()
	if layoutHooked or type(hooksecurefunc) ~= "function" then
		return
	end
	local Layout = K.Layout
	if type(Layout.Enter) ~= "function" or type(Layout.Exit) ~= "function" then
		K.DevTest.Log(Settings.MODULE, "Layout.Enter or Layout.Exit is missing; the sample plate shows only as a mover")
		return
	end
	layoutHooked = true
	hooksecurefunc(Layout, "Enter", function()
		ShowSample(true)
		local Mode = Layout.Mode
		local overlay = Mode and Mode.Overlay and Mode.Overlay()
		if overlay and not Preview.overlayHooked then
			Preview.overlayHooked = true
			overlay:HookScript("OnHide", function()
				ShowSample(false)
			end)
		end
	end)
	hooksecurefunc(Layout, "Exit", function()
		ShowSample(false)
	end)
end

function Preview.Register()
	local Layout = K.Layout
	if not (Layout and Layout.Register) then
		K.DevTest.Log(Settings.MODULE, "Layout is missing; plates keep their default size")
		return
	end
	if not Preview.sample then
		local holder = CreateFrame("Frame", nil, K.Scale.Root())
		holder:SetSize(ns.Plate.DEFAULT_WIDTH, ns.Plate.DEFAULT_HEIGHT)
		holder:Hide()
		local plate = ns.NewPlate(holder, Preview.SAMPLES[1])
		Plates.AddSample(plate)
		Preview.sample, Preview.samplePlate = holder, plate
		ns.Sample = holder
		Layout.Register(holder, Plates.LAYOUT_KEY, { anchor = "CENTER", x = 0, y = SAMPLE_Y }, {
			label = L["Nameplate size"],
			module = Settings.MODULE,
			resizable = true,
			minWidth = SIZE_LIMITS.minWidth,
			maxWidth = SIZE_LIMITS.maxWidth,
			minHeight = SIZE_LIMITS.minHeight,
			maxHeight = SIZE_LIMITS.maxHeight,
			fields = { "width", "height" },
		})
	end
	HookLayout()
	ShowSample(true)
end

function Preview.Hide()
	if Preview.sample then
		Preview.sample:Hide()
	end
end
