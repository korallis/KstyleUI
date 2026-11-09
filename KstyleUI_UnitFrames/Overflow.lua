-- Overflow.lua: the "+N" chip over an aura row's last socket, shown and counted by a hidden AuraContainer's own flow layout through anchors alone, so no aura count is ever read or compared.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens

local Overflow = {}
ns.Overflow = Overflow

Overflow.LABELS = 24
Overflow.PITCH = 2
local TEMPLATE = "CustomAuraContainerTemplate"
local LAYOUT_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"
local GROUP = "count"
local TEXT_SHARE = 0.42
local TEXT_MIN = 8

local function Mute(button)
	if type(button.EnableMouse) == "function" then
		pcall(button.EnableMouse, button, false)
	end
end

local function LayoutFrame(parent)
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent, LAYOUT_TEMPLATE)
	if ok and type(frame) == "table" then
		return frame
	end
	return nil
end

local function Layout(cell)
	return { elementWidth = 1, elementHeight = cell * Overflow.PITCH, elementSpacing = 0, lineSpacing = 0 }
end

function Overflow.New(host, unit, filter, cap)
	local ghostHost = CreateFrame("Frame", nil, host)
	ghostHost:SetAlpha(0)
	local ok, ghost = pcall(CreateFrame, "AuraContainer", nil, ghostHost, TEMPLATE)
	if not ok or type(ghost) ~= "table" or type(ghost.AddAuraGroup) ~= "function" then
		ghostHost:Hide()
		return nil, tostring(ok and "no " .. TEMPLATE or ghost)
	end
	ghost:SetUnit(unit)
	local added, err = pcall(ghost.AddAuraGroup, ghost, GROUP, filter, {
		maxFrameCount = cap + Overflow.LABELS,
		layout = Layout(1),
		initializeFrame = Mute,
	})
	if not added then
		ghostHost:Hide()
		return nil, tostring(err)
	end
	ghost:SetFlowLayoutAnchorPoint("TOPLEFT")
	local directions = AnchorUtil and AnchorUtil.FlowDirection
	if directions then
		ghost:SetFlowLayoutGrowthDirection(directions.Right, directions.Down)
	end
	ghost:SetFlowLayoutMaximumLineSize(1)
	local window = LayoutFrame(host)
	if not window then
		ghostHost:Hide()
		return nil, LAYOUT_TEMPLATE .. " is missing, and only a frame with it may anchor to the engine's containers"
	end
	window:SetClipsChildren(true)
	local strip = LayoutFrame(window)
	strip:SetClipsChildren(true)
	local face = LayoutFrame(strip)
	local chip = {
		ghostHost = ghostHost, ghost = ghost, window = window, strip = strip, face = face,
		chrome = Widgets.IconChrome(face), labels = {}, texts = {},
	}
	for i = 1, Overflow.LABELS do
		local frame = LayoutFrame(strip)
		local text = Widgets.FontString(frame, "OVERLAY")
		text:SetAllPoints(frame)
		chip.labels[i], chip.texts[i] = frame, text
	end
	return chip
end

local function StyleLabel(label, size)
	label:SetFont(Tokens.Font("number"), size, "")
	label:SetShadowColor(Tokens.Color("textShadow"))
	local offset = Tokens.Size("textShadowOffset")
	label:SetShadowOffset(offset, -offset)
	pcall(label.SetTextColor, label, Tokens.Color("textEmphasis"))
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
end

function Overflow.Apply(chip, o)
	local ghost, window, strip = chip.ghost, chip.window, chip.strip
	local on = o.enabled == true
	ghost:SetAuraGroupEnabled(GROUP, on)
	if on then
		ghost:SetAuraGroupFilterString(GROUP, o.filter)
	end
	ghost:SetAuraGroupMaxFrameCount(GROUP, o.cap + Overflow.LABELS)
	local cell = o.cell
	local pitch = cell * Overflow.PITCH
	ghost:SetAuraGroupLayout(GROUP, Layout(cell))
	ghost:SetEnabled(on)
	window:SetShown(on)
	if not on then
		return
	end
	window:ClearAllPoints()
	window:SetPoint("TOPLEFT", o.rel, o.relPoint, o.x, o.y)
	window:SetSize(cell, cell)
	window:SetFrameLevel(o.level)
	ghost:ClearAllPoints()
	ghost:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
	strip:ClearAllPoints()
	strip:SetPoint("BOTTOMLEFT", ghost, "BOTTOMLEFT", 0, o.cap * pitch + cell / 2)
	strip:SetPoint("TOPRIGHT", ghost, "BOTTOMLEFT", cell, (o.cap + Overflow.LABELS) * pitch + cell)
	local face = chip.face
	face:ClearAllPoints()
	face:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
	face:SetSize(cell, cell)
	chip.chrome:Restyle()
	local r, g, b = Tokens.Color("buttonFill")
	chip.chrome:SetFillRGBA(r, g, b, 1)
	chip.chrome:SetRimAccent(o.accent())
	local size = math.max(TEXT_MIN, math.floor(cell * TEXT_SHARE + 0.5))
	local level = face:GetFrameLevel() + 2
	for i, label in ipairs(chip.labels) do
		local top = (o.cap + i) * pitch
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", ghost, "BOTTOMLEFT", 0, top)
		label:SetPoint("BOTTOMRIGHT", ghost, "BOTTOMLEFT", cell, top - cell)
		label:SetFrameLevel(level)
		local text = chip.texts[i]
		StyleLabel(text, size)
		Widgets.SetText(text, "+" .. (i + 1))
	end
end

function Overflow.Enable(chip, on)
	chip.ghost:SetEnabled(on and true or false)
end
