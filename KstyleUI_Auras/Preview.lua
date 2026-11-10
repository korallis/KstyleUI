-- Preview.lua: the settings window's live preview: sample buffs and debuffs on the module's own plain tiles, laid out as the settings say.
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
	local button = CreateFrame("Frame", nil, canvas)
	local entry = Button.Create(button, hasDispel)
	entry.spec = spec
	entry.icon:SetTexture(spec.icon)
	return entry
end

local function Context(canvas, group, timer, count, edge)
	local function snap(units)
		return Widgets.Snap(canvas, units)
	end
	local ctx = { group = group, timer = timer, count = count, icon = snap(group.iconSize), edge = edge }
	ctx.width, ctx.height = Model.ElementSize(group, timer, snap)
	return ctx
end

local function StyleSample(entry, ctx)
	Button.Style(entry, ctx)
	entry.timer:SetText(Model.FormatTime(entry.spec.seconds, ctx.timer.format))
	entry.timer:SetShown(ctx.timer.format ~= "none")
	entry.count:SetText(entry.spec.stacks or "")
	entry.badge:SetShown(entry.spec.stacks ~= nil)
	if entry.dispel then
		Widgets.ColorSlice(entry.dispel, DispelColor(entry.spec.kind))
		Widgets.ShowSlice(entry.dispel, ctx.group.dispel == true)
	end
end

local function PlaceGroup(box, entries, group, ctx)
	local w, h = ctx.width, ctx.height
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
	return boxWidth, boxHeight
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
		local r, g, b = Tokens.Color("black")
		local ctx = Context(frame.canvas, group, timer, count, { r, g, b, 1 })
		for _, entry in ipairs(entries) do
			StyleSample(entry, ctx)
		end
		local w, h = PlaceGroup(box, entries, group, ctx)
		box:ClearAllPoints()
		box:SetPoint("TOPRIGHT", frame.canvas, "TOPRIGHT", 0, -top)
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
