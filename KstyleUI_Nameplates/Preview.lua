-- Preview.lua: sample plates for the settings window's live preview and for Layout Mode, where resizing the sample sizes every plate.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Settings, Plates = ns.Settings, ns.Plates

local Preview = {}
ns.Preview = Preview

local ROW_GAP = 30
local SAMPLE_Y = 160
local SIZE_LIMITS = { minWidth = 40, maxWidth = 320, minHeight = 4, maxHeight = 40 }

Preview.SAMPLES = {
	{
		name = L["Dark Iron Summoner"], level = 51, classification = "elite", health = 0.64,
		enemy = true, reaction = 2, isPlayer = false, target = true, raid = 8,
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

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame.plates = {}
	local count = #Preview.SAMPLES
	for i, sample in ipairs(Preview.SAMPLES) do
		local holder = CreateFrame("Frame", nil, frame)
		holder:SetSize(1, 1)
		holder:SetPoint("CENTER", frame, "CENTER", 0, ((count + 1) / 2 - i) * ROW_GAP * 2)
		local plate = ns.NewPlate(holder, sample)
		Plates.AddSample(plate)
		frame.plates[i] = plate
	end
	function frame.Refresh()
		Settings.Invalidate()
		if not Plates.running then
			Plates.ReadSize()
		end
		for _, plate in ipairs(frame.plates) do
			plate:Restyle()
		end
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
