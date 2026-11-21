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
		name = L["Dark Iron Summoner"], level = 51, classification = "elite", health = 0.64, absorb = 0.2,
		enemy = true, reaction = 2, isPlayer = false, target = true, focus = true, raid = 8, caster = true, threatPct = 87,
		cast = { text = L["Molten Pulse"], texture = 135812, time = "2.8", progress = 0.45, notInterruptible = false, target = L["Thaldrin"], important = true, atMe = true },
	},
	{
		name = L["Elunara"], level = 60, classification = "normal", health = 0.81, afk = true, dnd = true,
		enemy = true, reaction = 2, isPlayer = true, class = "PRIEST", threat = "warning", threatPct = 87, pvp = true, faction = "Horde", hovered = true, outOfRange = true,
		cast = { text = L["Greater Heal"], texture = 135913, time = "1.2", progress = 0.7, notInterruptible = true },
	},
	{
		name = L["Thaldrin"], level = 60, classification = "normal", health = 0.92,
		enemy = false, reaction = 5, isPlayer = true, class = "PALADIN", focus = true, pvpName = L["Sergeant Thaldrin"], guild = L["Ashen Vanguard"],
	},
	{ name = L["Innkeeper Hale"], level = 30, classification = "normal", health = 1, enemy = false, reaction = 5, isPlayer = false, title = L["Innkeeper"] },
	{ name = L["Ember"], level = 60, classification = "normal", health = 1, enemy = false, reaction = 5, isPlayer = false, pet = true, owner = L["Thaldrin"] },
}
local PLAYER_ROWS = { "name.afk", "name.dnd", "markers.pvp", "enemy.playersUseEnemy", "threat.name", "threat.percentColor", "target.hover", "range.fade" }
local FRIENDLY_ROWS = { { 3, "friendly.nameMode", "friendly.playerFormat", "friendly.title", "friendly.guild" },
	{ 4, "friendly.npcFormat", "friendly.npcSize", "friendly.npcNameMode", "friendly.npcTitle" }, { 5, "friendly.petSize", "friendly.owner" } }
local THREAT_SAMPLE = { healthEdge = true, name = true }
local ENEMY_ROWS = { "buffs.enabled", "ccs.enabled", "cast.targetGlow", "target.distance" }

local function Span(plate)
	local w, above, h, below = ns.Stacking.Extent(plate)
	if not w then
		return nil
	end
	local side = w - ns.state.width
	return ns.state.width + side * 2, above + h + below, side, above
end

local function Grow(frame, count)
	for i = #frame.plates + 1, count do
		local holder = CreateFrame("Frame", nil, frame)
		holder:SetSize(1, 1)
		frame.plates[i] = ns.NewPlate(holder, Preview.SAMPLES[i])
		Plates.AddSample(frame.plates[i])
	end
end

local function Stack(frame)
	local width, height = frame:GetWidth(), frame:GetHeight()
	local known = type(width) == "number" and width > 0 and type(height) == "number" and height > 0
	for _, plate in ipairs(frame.plates) do
		plate:GetParent():SetScale(1)
	end
	local chosen, smallest
	local first, last = 1, 3
	for _, key in ipairs(PLAYER_ROWS) do
		if Settings.Get(key) then first = 2 end
	end
	if THREAT_SAMPLE[Settings.Get("threat.display")] and not (Settings.Get("target.glow") or Settings.Get("target.fill")
		or Settings.Get("resource.show") or Settings.Get("target.scale") ~= 1) then first = 2 end
	for _, key in ipairs(ENEMY_ROWS) do
		if Settings.Get(key) then last = first end
	end
	for _, rows in ipairs(FRIENDLY_ROWS) do
		for i = 2, #rows do
			local value = Settings.Get(rows[i])
			if value and value ~= "" and value ~= 0 then first, last = rows[1], rows[1] end
		end
	end
	Grow(frame, last)
	for i = first, last do
		local w, h = Span(frame.plates[i])
		if not known or (w and w <= width and h <= height) then
			chosen = i
			break
		end
		local share = w and math.min(width / w, height / h)
		if share and (not smallest or share > smallest) then
			chosen, smallest = i, share
		end
	end
	chosen = chosen or first
	for i, plate in ipairs(frame.plates) do
		local holder = plate:GetParent()
		holder:ClearAllPoints()
		if i == chosen then
			local w, h, side, above = Span(plate)
			local boost = plate.boost or 1
			local scale = 1
			if known and w then
				scale = math.min(1, width / (w * boost), height / (h * boost))
			end
			holder:SetScale(scale)
			if w then
				K.Widgets.Size(holder, w * boost, h * boost)
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
