-- Preview.lua: the settings window's live preview: sample buffs and debuffs drawn with the kit's icon buttons, laid out as the settings say.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Model, Button = ns.Model, ns.Button
local floor, min, max, ceil = math.floor, math.min, math.max, math.ceil

local Preview = {}
ns.Preview = Preview

local BUFFS = {
	{ icon = 135987, seconds = 24 },
	{ icon = 136078, seconds = 17, stacks = "3" },
	{ icon = 135932, seconds = 12 },
	{ icon = 135906, seconds = 480 },
	{ icon = 132333, seconds = 180 },
	{ icon = 135953, seconds = 2.4 },
}
local DEBUFFS = {
	{ icon = 136207, seconds = 18, kind = "MAGIC" },
	{ icon = 136118, seconds = 9, kind = "CURSE", stacks = "2" },
	{ icon = 135846, seconds = 4, kind = "NONE" },
}
local REST_EDGE_ALPHA = 0.5
local DISPEL_SUBLEVEL = 7
local TIMER_GAP = 1
local TEXT_INSET = 2
local ICON_INSET_LINES = 2

local function DispelColor(kind)
	local colors = {
		MAGIC = DEBUFF_TYPE_MAGIC_COLOR,
		CURSE = DEBUFF_TYPE_CURSE_COLOR,
		NONE = DEBUFF_TYPE_NONE_COLOR,
	}
	local color = colors[kind]
	if type(color) == "table" and type(color.GetRGB) == "function" then
		local ok, r, g, b = pcall(color.GetRGB, color)
		if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
			return r, g, b
		end
	end
	return Tokens.Color("hostile")
end

local function Settings()
	local Store = K.Store
	if Store.IsLoaded and Store.IsLoaded() then
		return Store.Module(Model.MODULE)
	end
	return Model.defaults
end

local function Sample(canvas, spec, hasDispel)
	local button = Widgets.IconButton(canvas, { icon = spec.icon, size = Model.defaults.buffs.iconSize })
	button:EnableMouse(false)
	local entry = { button = button, spec = spec }
	entry.timer = Widgets.FontString(button.overlay, "OVERLAY")
	entry.count = Widgets.FontString(button.overlay, "OVERLAY")
	if hasDispel then
		entry.dispel = Widgets.NineSlice(button, "chamferTile", "BORDER", DISPEL_SUBLEVEL)
	end
	return entry
end

local function StyleSample(entry, group, timer, count, edge)
	local button = entry.button
	button.opts.size = group.iconSize
	button:Restyle()
	local inset = Widgets.Border(button) * ICON_INSET_LINES + Widgets.Snap(button, TEXT_INSET)
	Button.StyleText(entry.timer, timer)
	Button.StyleText(entry.count, count)
	entry.timer:ClearAllPoints()
	entry.count:ClearAllPoints()
	if timer.position == "inside" then
		entry.timer:SetPoint("BOTTOM", button, "BOTTOM", 0, inset)
		entry.count:SetPoint("TOPRIGHT", button, "TOPRIGHT", -inset, -inset)
	else
		entry.timer:SetPoint("TOP", button, "BOTTOM", 0, -Widgets.Snap(button, TIMER_GAP))
		entry.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
	end
	entry.timer:SetText(Model.FormatTime(entry.spec.seconds, timer.format))
	entry.timer:SetShown(timer.format ~= "none")
	entry.count:SetText(entry.spec.stacks or "")
	if type(button.SetAccent) == "function" then
		button:SetAccent(edge[1], edge[2], edge[3])
	else
		button.chrome:SetEdgeRGBA(edge[1], edge[2], edge[3], edge[4])
	end
	if entry.dispel then
		Widgets.LayoutSlice(entry.dispel, button, button.chrome:Chamfer(), 0)
		Widgets.ColorSlice(entry.dispel, DispelColor(entry.spec.kind))
		Widgets.ShowSlice(entry.dispel, group.dispel == true)
	end
end

local function PlaceGroup(box, entries, group, timer)
	local w, h = Model.ElementSize(group, timer)
	local shown = min(#entries, group.rows * group.columns)
	local columns = max(1, min(group.columns, shown))
	local rows = max(1, ceil(shown / group.columns))
	local boxWidth = columns * w + (columns - 1) * group.spacing
	local boxHeight = rows * h + (rows - 1) * group.rowSpacing
	box:SetSize(max(1, boxWidth), max(1, boxHeight))
	local _, horizontal, vertical = Model.Growth(group.growth)
	for i, entry in ipairs(entries) do
		local button = entry.button
		if i > shown then
			button:Hide()
		else
			button:Show()
			local col, row = (i - 1) % group.columns, floor((i - 1) / group.columns)
			local x = col * (w + group.spacing)
			if horizontal == "Left" then
				x = boxWidth - w - x
			end
			local top = row * (h + group.rowSpacing)
			if vertical == "Up" then
				top = boxHeight - h - top
			end
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", box, "TOPLEFT", x, -top)
		end
	end
	return boxWidth, boxHeight, horizontal
end

local function Fit(group, timer, available)
	if not available then
		return group
	end
	local w = Model.ElementSize(group, timer)
	local columns = max(1, floor((available + group.spacing) / (w + group.spacing)))
	if columns >= group.columns then
		return group
	end
	local fitted = {}
	for key, value in pairs(group) do
		fitted[key] = value
	end
	fitted.columns = columns
	return fitted
end

local function Refresh(frame)
	local settings = Settings()
	local timer, count = Model.Timer(settings), Model.Count(settings)
	local textScale = Model.TextScale()
	timer.size, count.size = timer.size * textScale, count.size * textScale
	local gap = Tokens.Size("gapLarge")
	local widest = 0
	local boxes = { { frame.buffBox, frame.buffs, "buffs" }, { frame.debuffBox, frame.debuffs, "debuffs" } }
	local top = 0
	local available = frame:GetWidth()
	if type(available) ~= "number" or Widgets.IsSecret(available) or available <= 0 then
		available = nil
	end
	for _, item in ipairs(boxes) do
		local box, entries, name = item[1], item[2], item[3]
		local group = Fit(Model.Group(settings, name), timer, available)
		local edge = { Tokens.Color("hostile") }
		if name == "buffs" then
			edge = { Tokens.Color("edgeInner") }
		end
		edge[4] = REST_EDGE_ALPHA
		for _, entry in ipairs(entries) do
			StyleSample(entry, group, timer, count, edge)
		end
		local w, h, horizontal = PlaceGroup(box, entries, group, timer)
		box:ClearAllPoints()
		if horizontal == "Left" then
			box:SetPoint("TOPRIGHT", frame.canvas, "TOPRIGHT", 0, -top)
		else
			box:SetPoint("TOPLEFT", frame.canvas, "TOPLEFT", 0, -top)
		end
		top = top + h + gap
		widest = max(widest, w)
	end
	local scale = 1
	if available and widest > available then
		scale = available / widest
	end
	frame.canvas:SetScale(scale)
	frame.canvas:SetSize(max(widest, 1), max(top, 1))
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	local canvas = CreateFrame("Frame", nil, frame)
	canvas:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	frame.canvas = canvas
	frame.buffBox = CreateFrame("Frame", nil, canvas)
	frame.debuffBox = CreateFrame("Frame", nil, canvas)
	frame.buffs, frame.debuffs = {}, {}
	for i, spec in ipairs(BUFFS) do
		frame.buffs[i] = Sample(frame.buffBox, spec, false)
	end
	for i, spec in ipairs(DEBUFFS) do
		frame.debuffs[i] = Sample(frame.debuffBox, spec, true)
	end
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end
