-- Preview.lua: the settings window's live preview of the meters: a sample damage meter, threat meter and swing bar drawn with the current settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local L = K.L
local Logic = ns.Logic

local FALLBACK_WIDTH, FALLBACK_HEIGHT = 420, 220
local SWING_HEIGHT = 8
local SWING_FILL = 0.6
local PERCENT_MAX = 100
local SAMPLE = {
	{ class = "WARRIOR", damage = 28400, threat = 100, raw = 3240000 },
	{ class = "MAGE", damage = 24700, threat = 88, raw = 2851000, player = true },
	{ class = "PRIEST", damage = 20100, threat = 61, raw = 1977000 },
	{ class = "ROGUE", damage = 17600, threat = 42, raw = 1361000 },
	{ class = "HUNTER", damage = 14200, threat = 23, raw = 745000 },
}

local Preview = {}
ns.Preview = Preview

local function Name(classFile)
	local names = LOCALIZED_CLASS_NAMES_MALE
	return type(names) == "table" and names[classFile] or classFile
end

local function Columns(section)
	return function()
		if section == "threat" then
			local value = ns.Get("threat.value")
			return { value = value ~= "percent", percent = value ~= "threat" }
		end
		return { value = true, percent = ns.Get("damage.percent") }
	end
end

local function Total()
	local total = 0
	for _, sample in ipairs(SAMPLE) do
		total = total + sample.damage
	end
	return total
end

local function FillDamage(list)
	local total, top = Total(), SAMPLE[1].damage
	local count = math.min(#SAMPLE, list.capacity or 0)
	local percent = ns.Get("damage.percent")
	for i = 1, count do
		local sample = SAMPLE[i]
		list:SetRow(i, Name(sample.class), sample.class, "friendly", sample.damage, top,
			Logic.Abbreviate(sample.damage), percent and Logic.FormatPercent(Logic.Percent(sample.damage, total)) or "")
	end
	list:Finish(count)
	local info = ns.METER_TYPES[1]
	for _, entry in ipairs(ns.METER_TYPES) do
		if entry.value == ns.Get("damage.meter") then
			info = entry
		end
	end
	list:SetTitle(info.label)
	local session = ns.Get("damage.session")
	list:SetColumn(session == "Overall" and L["All"] or session == "Previous" and L["Last"] or L["Now"])
end

local function FillThreat(list)
	local count = math.min(#SAMPLE, list.capacity or 0)
	local rows = {}
	for i = 1, count do
		local sample = SAMPLE[i]
		list:SetRow(i, Name(sample.class), sample.class, "friendly", sample.threat, PERCENT_MAX,
			Logic.Abbreviate(Logic.ThreatAmount(sample.raw)), Logic.FormatPercent(sample.threat))
		rows[i] = { isPlayer = sample.player == true, tanking = i == 1, scaled = sample.threat }
	end
	list:Finish(count)
	list:SetTitle(L["Threat"])
	list:SetColumn(ns.Get("threat.value") == "threat" and "" or "%")
	local level = Logic.NO_WARNING
	if ns.Get("threat.warnings") then
		level = Logic.ThreatWarning(rows, count, ns.Get("threat.warnAt"), ns.Get("threat.dangerAt"))
	end
	list:SetWarning(level)
end

local function Arrange(frame)
	local parent = frame:GetParent()
	local width = Logic.Plain(parent:GetWidth()) or 0
	local height = Logic.Plain(parent:GetHeight()) or 0
	if width <= 0 then
		width = FALLBACK_WIDTH
	end
	if height <= 0 then
		height = FALLBACK_HEIGHT
	end
	local gap = Widgets.Snap(frame, Tokens.Size("gapMedium"))
	local listWidth = math.floor((width - gap) / 2)
	local listHeight = height - SWING_HEIGHT - gap
	for _, list in ipairs({ frame.damage, frame.threat }) do
		list.width, list.height = listWidth, listHeight
		list.holder:SetSize(listWidth, listHeight)
	end
	frame.damage.holder:ClearAllPoints()
	frame.damage.holder:SetPoint("TOPLEFT", frame, "TOPLEFT")
	frame.threat.holder:ClearAllPoints()
	frame.threat.holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
	local swing = frame.swing
	swing.opts.width, swing.opts.height = width, SWING_HEIGHT
	swing:Restyle()
	swing:ClearAllPoints()
	swing:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
end

local function StyleSwing(swing)
	swing:SetBarTexture(ns.Get("swing.texture"))
	swing:SetReverseFill(ns.Get("swing.reverse"))
	swing:SetBarColor(ns.BarColor("swing", Theme.Class(), "friendly"))
	swing:SetShown(ns.Get("swing.shown"))
end

local function Refresh(frame)
	Arrange(frame)
	frame.damage:Restyle()
	frame.threat:Restyle()
	frame.damage.holder:SetShown(ns.Get("damage.shown"))
	frame.threat.holder:SetShown(ns.Get("threat.shown"))
	FillDamage(frame.damage)
	FillThreat(frame.threat)
	StyleSwing(frame.swing)
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.damage = ns.BarList.New(frame, "damage", { width = FALLBACK_WIDTH / 2, height = FALLBACK_HEIGHT, columns = Columns("damage") })
	frame.threat = ns.BarList.New(frame, "threat", { width = FALLBACK_WIDTH / 2, height = FALLBACK_HEIGHT, columns = Columns("threat") })
	frame.swing = Widgets.StatusBar(frame, {
		texture = ns.Get("swing.texture"), background = "track", border = true, min = 0, max = 1, value = SWING_FILL,
		width = FALLBACK_WIDTH, height = SWING_HEIGHT,
	})
	frame.Refresh = Refresh
	frame:HookScript("OnSizeChanged", Refresh)
	Refresh(frame)
	return frame
end

ns.schema.preview = Preview.Build
