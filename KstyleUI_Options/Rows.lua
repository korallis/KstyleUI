-- Rows.lua: one settings row: a header, a note, or a label with wrapping help text and the kit control its kind needs, as tall as its text.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Model = ns.Model
local format, floor, max, min = string.format, math.floor, math.max, math.min

local Rows = {}
ns.Rows = Rows

Rows.HEIGHT = 48
Rows.CONTROL_WIDTH = 220
Rows.MIN_TEXT_WIDTH = 240
local MAX_BUTTONS = 2
local SWATCH_SIZE = 20
local MARK_WIDTH = 2
local MARK_HEIGHT = 12
local BYTE = 255
local DROPDOWNS = { dropdown = true, font = true, texture = true }
local DROPDOWN_CHEVRON = 8
local DROPDOWN_GAPS = 3
local DROPDOWN_SAFETY = 1
local DROPDOWN_RESERVE = DROPDOWN_GAPS * Tokens.Size("gapMedium") + DROPDOWN_CHEVRON + DROPDOWN_SAFETY
local PICTURE_COUNT, PICTURE_GAP, PICTURE_INSET, PICTURE_LABEL, PICTURE_MAX, PICTURE_MIN = 3, 12, 4, 24, 280, 200
local TASK_HEIGHT = 36
local SAMPLE_WIDTH, SAMPLE_HEIGHT = 180, 90

local function Snap(frame, units)
	return Widgets.Snap(frame, units)
end

local function Gap(frame, name)
	return Snap(frame, Tokens.Size(name or "gapMedium"))
end

local function Dragging(control)
	return control.GetScript ~= nil and control:GetScript("OnUpdate") ~= nil
end

local function Apply(row, value, control)
	local item = row.item
	if row.updating or not item or not item.set then
		return
	end
	if item.defer and control and Dragging(control) then
		row.pending = value
		return
	end
	row.pending = nil
	K.Call(item.set, value)
	ns.Changed()
end

local function Flush(row)
	local value = row.pending
	if value == nil then
		return
	end
	row.pending = nil
	local item = row.item
	if item and item.set then
		K.Call(item.set, value)
		ns.Changed()
	end
end

local function Hex(r, g, b)
	return format("#%02X%02X%02X", floor(r * BYTE + 0.5), floor(g * BYTE + 0.5), floor(b * BYTE + 0.5))
end

local function NumberOr(value, fallback)
	if Widgets.IsSecret(value) or type(value) ~= "number" or value ~= value then
		return fallback
	end
	return value
end

local MAKERS = {}

function MAKERS.task(row)
	return Widgets.Button(row, { height = TASK_HEIGHT, onClick = function()
		if row.item and row.item.onClick then K.Call(row.item.onClick) end
	end })
end

function MAKERS.toggle(row)
	return Widgets.Toggle(row, {
		onChange = function(value, control)
			Apply(row, value, control)
		end,
	})
end

function MAKERS.slider(row)
	local slider = Widgets.Slider(row, {
		width = Rows.CONTROL_WIDTH,
		format = function(value)
			local item = row.item
			if item and item.format then
				return item.format(value)
			end
			return nil
		end,
		onChange = function(value, control)
			Apply(row, value, control)
		end,
	})
	local restyle = slider.Restyle
	function slider:Restyle()
		local scale = Widgets.ScaleFactor(self)
		if self.fontScale ~= scale then
			Widgets.StyleText(self.readout)
			Widgets.StyleText(self.minText)
			Widgets.StyleText(self.maxText)
			self.fontScale = scale
		end
		restyle(self)
		local above = max(0, Widgets.LineHeight(self.readout) - Tokens.Size("body"))
		local below = max(0, max(Widgets.LineHeight(self.minText), Widgets.LineHeight(self.maxText)) - Tokens.Size("caption"))
		local point, relative, anchor, x, y = self.trackBox:GetPoint(1)
		self.trackBox:ClearAllPoints()
		Widgets.Point(self.trackBox, point, relative, anchor, x, y - Snap(self, above))
		Widgets.Size(self, Rows.CONTROL_WIDTH, self:GetHeight() + above + below + Widgets.Border(self))
	end
	slider:Restyle()
	slider:HookScript("OnMouseUp", function()
		Flush(row)
	end)
	slider:HookScript("OnHide", function()
		Flush(row)
		slider.edit:Hide()
	end)
	slider.edit = Widgets.EditBox(slider, { width = 56, onEnter = function(text, box)
		local value = tonumber(text)
		if value then slider:SetValue(value) end
		box:Hide()
	end, onEscape = function(box) box:Hide() end })
	Widgets.Point(slider.edit, "CENTER", slider.readout, "CENTER")
	slider.edit:Hide()
	slider.edit:HookScript("OnHide", function() slider.readout:Show() end)
	slider.valueButton = CreateFrame("Button", nil, slider)
	slider.valueButton:SetAllPoints(slider.readout)
	slider.valueButton:SetScript("OnClick", function()
		if slider:IsEnabled() then
			slider.edit:SetText(tostring(slider:GetValue()))
			slider.readout:Hide()
			slider.edit:Show()
			slider.edit:SetFocus()
			slider.edit:HighlightText()
		end
	end)
	return slider
end

local function Dropdown(row, maker)
	local control = maker(row, {
		width = Rows.CONTROL_WIDTH,
		unknownLabel = function(value)
			return tostring(value)
		end,
		onChange = function(value, control)
			Apply(row, value, control)
		end,
	})
	Rows.FullLabel(control, control.text, function(self)
		return self.text:GetText()
	end)
	return control
end

function MAKERS.dropdown(row)
	return Dropdown(row, Widgets.Dropdown)
end

function MAKERS.order(row)
	local holder = CreateFrame("Frame", nil, row)
	Widgets.Size(holder, Rows.CONTROL_WIDTH, Tokens.Size("rowHeight") + Tokens.Size("gapSmall"))
	holder.toggle = Widgets.Toggle(holder, { onChange = function(value)
		Apply(row, { shown = value })
	end })
	holder.zone = Widgets.Dropdown(holder, { width = 90, options = {
		{ value = "left", label = K.L["Left"] },
		{ value = "centre", label = K.L["Centre"] },
		{ value = "right", label = K.L["Right"] },
	}, onChange = function(value) Apply(row, { zone = value }) end })
	for _, direction in ipairs({ "up", "down" }) do
		local delta = direction == "up" and -1 or 1
		local button = Widgets.Button(holder, { width = 24, tooltip = direction == "up" and K.L["Move up"] or K.L["Move down"], onClick = function()
			if not row.updating and row.item and row.item.move then
				K.Call(row.item.move, delta)
				ns.Changed()
			end
		end })
		local glyph = button:CreateTexture(nil, "ARTWORK")
		glyph:SetTexture((Tokens.Texture("glyphChevron")))
		if delta == -1 then glyph:SetTexCoord(0, 1, 1, 0) end
		Widgets.Size(glyph, DROPDOWN_CHEVRON, DROPDOWN_CHEVRON)
		Widgets.Point(glyph, "CENTER", button, "CENTER")
		local paint = button.Paint
		function button:Paint()
			paint(self)
			glyph:SetVertexColor(self.label:GetTextColor())
		end
		button:Paint()
		holder[direction] = button
	end
	Widgets.Point(holder.down, "RIGHT", holder, "RIGHT")
	Widgets.Point(holder.up, "RIGHT", holder.down, "LEFT", -Gap(holder, "gapTiny"), 0)
	Widgets.Point(holder.zone, "RIGHT", holder.up, "LEFT", -Gap(holder, "gapSmall"), 0)
	Widgets.Point(holder.toggle, "RIGHT", holder.zone, "LEFT", -Gap(holder), 0)
	return holder
end

function MAKERS.segmented(row)
	return Widgets.Tabs(row, {
		width = Rows.CONTROL_WIDTH,
		height = Tokens.Size("rowHeight"),
		onSelect = function(value, control)
			Apply(row, value, control)
		end,
	})
end

function MAKERS.font(row)
	return Dropdown(row, Widgets.FontPicker)
end

function MAKERS.texture(row)
	return Dropdown(row, Widgets.TexturePicker)
end

function MAKERS.color(row)
	local holder = CreateFrame("Frame", nil, row)
	Widgets.Size(holder, Rows.CONTROL_WIDTH, SWATCH_SIZE)
	holder.swatch = Widgets.ColorSwatch(holder, {
		size = SWATCH_SIZE,
		onChange = function(r, g, b, a)
			holder.hex:SetText(Hex(r, g, b))
			local item = holder.bound
			if not item or not item.set then
				return
			end
			local value = { r = r, g = g, b = b }
			if item.hasAlpha then
				value.a = a
			end
			K.Call(item.set, value)
			ns.Changed()
		end,
	})
	local open = holder.swatch.onClick
	holder.swatch.onClick = function(self, ...)
		holder.bound = row.item
		return open(self, ...)
	end
	Widgets.Point(holder.swatch, "RIGHT", holder, "RIGHT")
	holder.hex = Widgets.Text(holder, "body", "textEmphasis")
	Widgets.Point(holder.hex, "RIGHT", holder.swatch, "LEFT", -Gap(holder), 0)
	return holder
end

function MAKERS.text(row)
	return Widgets.EditBox(row, {
		width = Rows.CONTROL_WIDTH,
		onEnter = function(text, box)
			Apply(row, text, box)
		end,
	})
end

function MAKERS.button(row)
	local holder = CreateFrame("Frame", nil, row)
	Widgets.Size(holder, Rows.CONTROL_WIDTH, Tokens.Size("rowHeight") + Tokens.Size("gapSmall"))
	holder.buttons = {}
	for i = 1, MAX_BUTTONS do
		local button = Widgets.Button(holder, {
			text = "",
			onClick = function(self)
				local spec = self.spec
				if spec and spec.onClick and not row.updating then
					K.Call(spec.onClick, row.item)
					ns.Changed()
				end
			end,
		})
		if i == 1 then
			Widgets.Point(button, "RIGHT", holder, "RIGHT")
		else
			Widgets.Point(button, "RIGHT", holder.buttons[i - 1], "LEFT", -Gap(holder, "gapSmall"), 0)
		end
		holder.buttons[i] = button
	end
	return holder
end

local function PictureCard(row, holder, i)
	local card = CreateFrame("Button", nil, holder)
	card.chrome = Widgets.Chrome(card, { shape = "tile", fill = "buttonFill", shadow = false })
	card.picture = card:CreateTexture(nil, "ARTWORK")
	card.label = Widgets.Text(card, "body", "text")
	card.label:SetJustifyH("CENTER")
	card.label:SetWordWrap(false)
	Widgets.Point(card.label, "TOPLEFT", card.picture, "BOTTOMLEFT", 0, 0)
	Widgets.Point(card.label, "BOTTOMRIGHT", card, "BOTTOMRIGHT", -Snap(card, PICTURE_INSET), 0)
	card:SetScript("OnClick", function(self)
		Apply(row, self.value, holder)
	end)
	return card
end

function MAKERS.pictures(row)
	local holder = CreateFrame("Frame", nil, row)
	holder.cards = {}
	for i = 1, PICTURE_COUNT do
		holder.cards[i] = PictureCard(row, holder, i)
	end
	function holder:Fit(width)
		local count = self.count or PICTURE_COUNT
		local columns = max(1, min(count, floor((width + PICTURE_GAP) / (PICTURE_MIN + PICTURE_GAP))))
		local rows = math.ceil(count / columns)
		local cardWidth = Snap(self, min(PICTURE_MAX, (width - (columns - 1) * PICTURE_GAP) / columns))
		local inset = Snap(self, PICTURE_INSET)
		local picture = Snap(self, (cardWidth - 2 * inset) / 2)
		local height = inset + picture + Snap(self, PICTURE_LABEL)
		for i, card in ipairs(self.cards) do
			Widgets.Size(card, cardWidth, height)
			card:ClearAllPoints()
			Widgets.Point(card, "TOPLEFT", self, "TOPLEFT", ((i - 1) % columns) * (cardWidth + Snap(self, PICTURE_GAP)), -floor((i - 1) / columns) * (height + Snap(self, PICTURE_GAP)))
			card.picture:ClearAllPoints()
			Widgets.Point(card.picture, "TOPLEFT", card, "TOPLEFT", inset, -inset)
			card.picture:SetSize(cardWidth - 2 * inset, picture)
		end
		Widgets.Size(self, columns * cardWidth + (columns - 1) * Snap(self, PICTURE_GAP), rows * height + (rows - 1) * Snap(self, PICTURE_GAP))
	end
	holder:Fit(Rows.CONTROL_WIDTH)
	function holder:SetEnabled(enabled)
		for _, card in ipairs(self.cards) do
			card:SetEnabled(enabled)
		end
	end
	return holder
end

local function OrnamentArt(parent, name, point, relative, anchor, x, y, width, mirror)
	local spec = Widgets.OrnamentAssets[name]
	local art = parent:CreateTexture(nil, "OVERLAY")
	art:SetTexture("Interface\\AddOns\\KstyleUI\\Media\\Textures\\ForgedOrnaments\\" .. name .. ".tga")
	local u = spec[1] / spec[3]
	art:SetTexCoord(mirror and u or 0, mirror and 0 or u, 0, spec[2] / spec[4])
	Widgets.Size(art, width or spec[1], spec[2])
	Widgets.Point(art, point, relative, anchor, x, y)
end

function MAKERS.ornaments(row)
	local holder = MAKERS.pictures(row)
	for i, card in ipairs(holder.cards) do
		card.picture:Hide()
		local sample = CreateFrame("Frame", nil, card)
		Widgets.Size(sample, SAMPLE_WIDTH, SAMPLE_HEIGHT)
		Widgets.Point(sample, "TOPLEFT", card, "TOPLEFT", PICTURE_INSET, -PICTURE_INSET)
		card.sample = sample
		local bar = CreateFrame("Frame", nil, sample)
		Widgets.Size(bar, 124, 12)
		Widgets.Point(bar, "CENTER", sample, "CENTER", 0, -12)
		bar.chrome = Widgets.Chrome(bar, { shape = "tile", fill = "buttonFill", shadow = false })
		local text = Widgets.Text(sample, "body", "text")
		Widgets.Point(text, "BOTTOM", bar, "TOP", 0, 26)
		Widgets.SetText(text, K.L["Sample panel"])
		if i > 1 then
			local full = i == 3
			OrnamentArt(sample, full and "EndClawed12" or "EndPointed12", "RIGHT", bar, "LEFT", 4, 0)
			OrnamentArt(sample, full and "EndClawed12" or "EndPointed12", "LEFT", bar, "RIGHT", -4, 0, nil, true)
			OrnamentArt(sample, full and "Rail3" or "Rail1", "BOTTOM", bar, "TOP", 0, 0, 120)
			OrnamentArt(sample, full and "Rail3" or "Rail1", "TOP", bar, "BOTTOM", 0, 0, 120)
			if full then OrnamentArt(sample, "Crest20", "BOTTOM", bar, "TOP", 0, 0) end
		end
	end
	function holder:Fit(width)
		local w = SAMPLE_WIDTH + 2 * PICTURE_INSET
		local h = SAMPLE_HEIGHT + PICTURE_INSET + max(PICTURE_LABEL, Widgets.LineHeight(self.cards[1].label))
		local columns = max(1, min(PICTURE_COUNT, floor((width + PICTURE_GAP) / (w + PICTURE_GAP))))
		for i, card in ipairs(self.cards) do
			Widgets.Size(card, w, h)
			card:ClearAllPoints()
			Widgets.Point(card, "TOPLEFT", self, "TOPLEFT", ((i - 1) % columns) * (w + PICTURE_GAP), -floor((i - 1) / columns) * (h + PICTURE_GAP))
			card.label:ClearAllPoints()
			Widgets.Point(card.label, "TOPLEFT", card.sample, "BOTTOMLEFT", 0, 0)
			Widgets.Size(card.label, SAMPLE_WIDTH, h - SAMPLE_HEIGHT - PICTURE_INSET)
		end
		Widgets.Size(self, columns * w + (columns - 1) * PICTURE_GAP, math.ceil(PICTURE_COUNT / columns) * (h + PICTURE_GAP) - PICTURE_GAP)
	end
	return holder
end

local function Control(row, kind)
	local control = row.controls[kind]
	if not control and MAKERS[kind] then
		control = MAKERS[kind](row)
		row.controls[kind] = control
	end
	return control
end

local function SetEnabled(control, enabled)
	if control.SetEnabled then
		control:SetEnabled(enabled)
	elseif enabled then
		control:Enable()
	else
		control:Disable()
	end
end

local function WithValue(base, value, label)
	return function()
		local options = base
		if type(options) == "function" then
			local ok, list = pcall(options)
			options = ok and type(list) == "table" and list or {}
		end
		options = options or {}
		if value == nil then
			return options
		end
		for _, option in ipairs(options) do
			if option.value == value then
				return options
			end
		end
		local out = {}
		for i, option in ipairs(options) do
			out[i] = option
		end
		local ok, text = pcall(label, value)
		out[#out + 1] = { value = value, label = ok and text ~= nil and tostring(text) or tostring(value) }
		return out
	end
end

local FILL = {}

function FILL.toggle(control, item, value)
	control:SetValue(value == true, true)
	SetEnabled(control, not Model.IsDisabled(item))
end

function FILL.order(control, item, value)
	value = value or {}
	local enabled = not Model.IsDisabled(item)
	control.toggle:SetValue(value.shown == true, true)
	control.zone:SetValue(value.zone, true)
	control.toggle:SetEnabled(enabled)
	control.zone:SetEnabled(enabled)
	local at, count = item.position()
	control.up:SetEnabled(enabled and at ~= nil and at > 1)
	control.down:SetEnabled(enabled and at ~= nil and at < count)
end

function FILL.slider(control, item, value)
	local low, high, step = item.min or 0, item.max or 1, item.step
	if item.module == "Appearance" and item.key == "uiScale" then
		high = K.Scale.MaxUserScale()
		value = K.Scale.AppliedUserScale()
		step = K.Scale.Step()
		low = math.ceil(low / step - 1e-9) * step
		high = math.floor(high / step + 1e-9) * step
	end
	if low < high then
		control:SetRange(low, high, step)
	end
	if item.shown then
		local ok, painted = K.Call(item.shown, value)
		value = ok and painted or low
	end
	control:SetValue(NumberOr(value, low), true)
	SetEnabled(control, not Model.IsDisabled(item))
end

local function FillDropdown(control, item, value)
	local base = item.options
	if base == nil and control.base == nil then
		control.base = control.opts.options
	end
	control:SetOptions(WithValue(base or control.base, value, control.opts.unknownLabel or tostring))
	if value ~= nil then
		control:SetValue(value, true)
	end
	SetEnabled(control, not Model.IsDisabled(item))
end
FILL.dropdown, FILL.font, FILL.texture = FillDropdown, FillDropdown, FillDropdown

function FILL.segmented(control, item, value)
	if control.options ~= item.options then
		control.options = item.options
		control:SetTabs(item.options, value)
	end
	for _, option in ipairs(item.options) do
		control:SetTabEnabled(option.value, true)
	end
	control:Select(value, true)
	local enabled = not Model.IsDisabled(item)
	for _, option in ipairs(item.options) do
		control:SetTabEnabled(option.value, enabled)
	end
	control:Paint()
end

function FILL.color(control, item, value)
	local c = type(value) == "table" and value or {}
	local r, g, b = NumberOr(c.r, 1), NumberOr(c.g, 1), NumberOr(c.b, 1)
	control.swatch.opts.hasAlpha = item.hasAlpha == true
	control.swatch:SetColor(r, g, b, NumberOr(c.a, 1), true)
	control.hex:SetText(Hex(control.swatch:GetColor()))
	SetEnabled(control.swatch, not Model.IsDisabled(item))
end

function FILL.text(control, item, value)
	control:SetMaxLetters(item.maxLetters or 0)
	if not control:HasFocus() then
		control:SetText(type(value) == "string" and value or "")
		control:Paint()
	end
	SetEnabled(control, not Model.IsDisabled(item))
end

function FILL.button(control, item)
	local enabled = not Model.IsDisabled(item)
	for i, button in ipairs(control.buttons) do
		local spec = item.buttons and item.buttons[i]
		button.spec = spec
		if spec then
			button:SetText(spec.label or "")
			SetEnabled(button, enabled)
			button:Show()
		else
			button:Hide()
		end
	end
end

function FILL.pictures(control, item, value)
	local disabled = Model.IsDisabled(item)
	local known = false
	for _, option in ipairs(item.options) do
		known = known or option.value == value
	end
	for i, card in ipairs(control.cards) do
		local option = item.options[i]
		card:SetShown(option ~= nil)
		if option then
			local selected = option.value == value or not known and i == 1
			card.value = option.value
			card.picture:SetTexture(option.picture)
			card.picture:SetDesaturated(disabled)
			Widgets.SetText(card.label, option.label)
			Widgets.TextColor(card.label, disabled and "textDisabled" or selected and "textEmphasis" or "text")
			card.chrome:SetEdge(selected and not disabled and "accent" or "edgeInner", 1)
		end
	end
	SetEnabled(control, not disabled)
end

FILL.ornaments = FILL.pictures

local function Value(item)
	if not item.get then
		return nil
	end
	local ok, value = K.Call(item.get)
	if ok then
		return value
	end
	return nil
end

local function ControlHeight(control)
	local height = control:GetHeight()
	if Widgets.IsSecret(height) or type(height) ~= "number" or height <= 0 then
		return Tokens.Size("rowHeight")
	end
	return height
end

local function Truncated(text)
	local cut = text.IsTruncated and text:IsTruncated()
	return cut == true and not Widgets.IsSecret(cut)
end

local function SelectedLabel(item)
	local value = Value(item)
	if value == nil or Widgets.IsSecret(value) then
		return nil
	end
	local options = item.options
	if type(options) == "function" then
		local ok, list = pcall(options)
		options = ok and type(list) == "table" and list or nil
	end
	for _, option in ipairs(type(options) == "table" and options or {}) do
		if option.value == value then
			return option.label
		end
	end
	return tostring(value)
end

local function ControlWidth(row, item, control, full)
	local width = Snap(row, Rows.CONTROL_WIDTH)
	if not control or not DROPDOWNS[item.kind] or not item.options then
		return width
	end
	Widgets.SetText(row.gauge, SelectedLabel(item) or "")
	local needed = Widgets.TextWidth(row.gauge, 0) + Snap(row, DROPDOWN_RESERVE)
	width = max(width, min(Snap(row, full), Snap(row, needed)))
	if control.opts.width ~= width then
		control.opts.width = width
		control:Restyle()
	end
	return width
end

local function PlaceText(row, item, control, width)
	local gap, tiny = Gap(row), Snap(row, Tokens.Size("gapTiny"))
	if Widgets.Readability("sectionHeadings") then tiny = Snap(row, 2) end
	local full = width - 2 * gap
	local reserve = control and ControlWidth(row, item, control, full) + gap or 0
	local column = full - reserve
	local stacked = control ~= nil and (item.kind == "pictures" or item.kind == "ornaments" or Widgets.TextWidth(row.label, 0) > column)
	if stacked and control.Fit then
		control.count = item.options and #item.options or nil
		control:Fit(full)
	end
	local banded = control ~= nil and not stacked and column < Rows.MIN_TEXT_WIDTH
	local labelWidth = stacked and full or column
	local helpWidth = (stacked or banded) and full or column
	local labelHeight = Widgets.LineHeight(row.label)
	local controlHeight = control and ControlHeight(control) or 0
	row.label:SetWidth(max(1, labelWidth))
	local helpHeight = Widgets.WrappedHeight(row.help, max(1, helpWidth))
	local helpBlock = helpHeight > 0 and tiny + helpHeight or 0
	local band = stacked and labelHeight + tiny + controlHeight or banded and max(labelHeight, controlHeight) or 0
	local blockHeight = (stacked or banded) and band + helpBlock or max(labelHeight + helpBlock, controlHeight)
	local height = Snap(row, max(Rows.HEIGHT, blockHeight + 2 * gap))
	local top = Snap(row, (height - ((stacked or banded) and blockHeight or labelHeight + helpBlock)) / 2)
	local labelTop = banded and top + Snap(row, (band - labelHeight) / 2) or top
	local helpTop = Snap(row, (stacked or banded) and top + band + tiny or top + labelHeight + tiny)
	row.label:ClearAllPoints()
	row.help:ClearAllPoints()
	Widgets.Point(row.label, "TOPLEFT", row, "TOPLEFT", gap, -labelTop)
	if item.module ~= "ProfileTools" then Widgets.Point(row.label, "RIGHT", row, "RIGHT", -(gap + (stacked and 0 or reserve)), 0) end
	Widgets.Point(row.help, "TOPLEFT", row, "TOPLEFT", gap, -helpTop)
	if item.module ~= "ProfileTools" then Widgets.Point(row.help, "RIGHT", row, "RIGHT", -(gap + ((stacked or banded) and 0 or reserve)), 0) end
	if control then
		control:ClearAllPoints()
		if stacked and control.Fit then
			Widgets.Point(control, "TOPLEFT", row, "TOPLEFT", gap, -Snap(row, top + labelHeight + tiny))
		elseif stacked then
			Widgets.Point(control, "TOPRIGHT", row, "TOPRIGHT", -gap, -(top + labelHeight + tiny))
		elseif banded then
			Widgets.Point(control, "TOPRIGHT", row, "TOPRIGHT", -gap, -(top + Snap(row, (band - controlHeight) / 2)))
		else
			Widgets.Point(control, "TOPRIGHT", row, "TOPRIGHT", -gap, -Snap(row, (height - controlHeight) / 2))
		end
	end
	row:EnableMouse(K.Store.Module("OptionControls").changedSettings or Truncated(row.label))
	return height
end

local function ShowHeader(row, item, width)
	local gap = Gap(row)
	if (item.level or 1) == 1 or Widgets.Readability("sectionHeadings") then
		row.caption:ClearAllPoints()
		Widgets.Point(row.caption, "BOTTOMLEFT", row, "BOTTOMLEFT", gap, gap)
		Widgets.Point(row.caption, "BOTTOMRIGHT", row, "BOTTOMRIGHT", -gap, gap)
		row.caption:SetText(item.label)
		local height = row.caption:SetWrapWidth(width - 2 * gap)
		row.caption:Show()
		return Snap(row, max(Rows.HEIGHT, height + 2 * gap))
	else
		Widgets.Size(row.mark, MARK_WIDTH, MARK_HEIGHT)
		row.mark:Show()
		Widgets.SetText(row.label, item.label)
		Widgets.TextColor(row.label, "textEmphasis")
		row.label:Show()
		row.mark:ClearAllPoints()
		row.label:ClearAllPoints()
		local room = max(1, width - 3 * gap - row.mark:GetWidth())
		if Widgets.TextWidth(row.label, 0) > room then
			local height = Widgets.WrappedHeight(row.label, room)
			row.label:SetWordWrap(true)
			Widgets.Size(row.label, room, height)
			Widgets.Point(row.mark, "TOPLEFT", row, "TOPLEFT", gap, -gap)
			Widgets.Point(row.label, "TOPLEFT", row.mark, "TOPRIGHT", gap, 0)
			return Snap(row, max(Rows.HEIGHT, height + 2 * gap))
		end
		Widgets.Point(row.mark, "BOTTOMLEFT", row, "BOTTOMLEFT", gap, gap)
		Widgets.Point(row.label, "LEFT", row.mark, "RIGHT", gap, 0)
		Widgets.Point(row.label, "RIGHT", row, "RIGHT", -gap, 0)
	end
	return Rows.HEIGHT
end

local function ShowNote(row, item, width)
	local gap = Gap(row)
	Widgets.SetText(row.note, item.label)
	local height = Snap(row, max(Rows.HEIGHT, Widgets.WrappedHeight(row.note, max(1, width - 2 * gap)) + 2 * gap))
	row.note:ClearAllPoints()
	Widgets.Point(row.note, "TOPLEFT", row, "TOPLEFT", gap, -gap)
	Widgets.Point(row.note, "BOTTOMRIGHT", row, "BOTTOMRIGHT", -gap, gap)
	row.note:Show()
	return height
end

local function SameSetting(a, b)
	return a ~= nil and b ~= nil and a.kind == b.kind and a.label == b.label
		and a.page == b.page and a.module == b.module and a.key == b.key and a.element == b.element and a.entry == b.entry
end

local function Layout(row, item, width)
	local kind = item.kind
	Widgets.StyleText(row.label, "body")
	Widgets.StyleText(row.help, "body")
	if Widgets.Readability("sectionHeadings") then
		local path, _, flags = Tokens.Font("body")
		Widgets.ApplyFont(row.label, path, 12 * K.Theme.FontScale(), flags)
		Widgets.ApplyFont(row.help, path, 11 * K.Theme.FontScale(), flags)
	end
	for controlKind, control in pairs(row.controls) do
		if controlKind ~= kind then
			control:Hide()
		end
	end
	for _, region in ipairs({ row.label, row.help, row.caption, row.note, row.mark }) do
		region:Hide()
	end
	row.label:SetWordWrap(false)
	row.label:SetHeight(0)
	if kind == "header" then
		return ShowHeader(row, item, width), nil
	elseif kind == "note" then
		return ShowNote(row, item, width), nil
	elseif kind == "task" then
		local control = Control(row, kind)
		control.opts.width = max(1, width - 2 * Gap(row))
		control:SetText(item.label)
		control:Restyle()
		control:ClearAllPoints()
		Widgets.Point(control, "TOPLEFT", row, "TOPLEFT", Gap(row), 0)
		return Snap(row, TASK_HEIGHT), control
	end
	local control = Control(row, kind)
	Widgets.SetText(row.label, item.label)
	Widgets.SetText(row.help, item.help or "")
	return PlaceText(row, item, control, width), control
end

local function RowWidth(list)
	local width = list and list.GetViewWidth and list:GetViewWidth() or 0
	if width <= 0 then
		width = Rows.CONTROL_WIDTH + Rows.MIN_TEXT_WIDTH + 3 * Tokens.Size("gapMedium")
	end
	return width
end

function Rows.Measure(item, _, list, width)
	local row = list.measureRow
	if not row then
		row = Rows.Create(list)
		row:Hide()
		list.measureRow = row
	end
	row.updating = true
	local height = Layout(row, item, width and width > 0 and width or RowWidth(list))
	row.updating = false
	return height
end

function Rows.Update(row, item, _, list)
	local kind = item.kind
	local keep = SameSetting(row.item, item)
	row.updating = true
	if not keep then row.pending = nil end
	row.item = item
	row.list = list or row.list
	local _, control = Layout(row, item, RowWidth(row.list))
	local slider = row.controls.slider
	if slider then
		local numeric = K.Store.Module("OptionControls").numericInput
		slider.valueButton:SetShown(numeric)
		if not keep or not numeric then slider.edit:Hide() end
	end
	row.changed:SetShown(K.Store.Module("OptionControls").changedSettings and item.key ~= nil and item.module ~= nil and K.Options.IsChanged(item.module, item.key))
	if kind == "task" then
		control:Show()
	elseif kind ~= "header" and kind ~= "note" then
		local disabled = Model.IsDisabled(item)
		Widgets.TextColor(row.label, disabled and "textDisabled" or "textEmphasis")
		Widgets.TextColor(row.help, disabled and "textDisabled" or Widgets.Readability("sectionHeadings") and "muted" or "text")
		row.label:Show()
		row.help:Show()
		if control then
			if not (keep and Dragging(control)) then
				K.Call(FILL[kind], control, item, Value(item))
			end
			control:Show()
		end
	end
	row.updating = false
end

function Rows.Restyle(row)
	Widgets.Tint(row.mark, "accent")
	Widgets.Tint(row.changed, "accent")
	if row.item then
		Rows.Update(row, row.item, nil, row.list)
	end
end

local function ShowFull(frame)
	local full = frame.fullText and frame.fullText(frame)
	if full == nil or Widgets.IsSecret(full) then
		return
	end
	local tip = Widgets.Tooltip()
	tip:SetOwner(frame, "ANCHOR_TOP")
	tip:AddLine(full, nil, nil, nil, true)
	tip:Show()
end

local function HideFull(frame)
	local tip = Widgets.Tooltip()
	if tip:IsOwned(frame) then
		tip:Hide()
	end
end

function Rows.FullLabel(frame, text, fullText)
	frame.fullText = function(self)
		if not Truncated(text) then
			return nil
		end
		return fullText(self)
	end
	frame:HookScript("OnEnter", ShowFull)
	frame:HookScript("OnLeave", HideFull)
end

function Rows.Create(list)
	local row = CreateFrame("Frame", nil, list.view)
	row.list = list
	row.controls = {}
	row.label = Widgets.Text(row, "body", "textEmphasis")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.gauge = Widgets.Text(row, "body", "text")
	row.gauge:Hide()
	Rows.FullLabel(row, row.label, function(self)
		return self.item and self.item.label
	end)
	row.help = Widgets.Text(row, "body", "text")
	row.help:SetJustifyH("LEFT")
	row.help:SetJustifyV("TOP")
	row.help:SetWordWrap(true)
	row.caption = Widgets.SectionCap(row)
	row.note = Widgets.Text(row, "body", "text")
	row.note:SetJustifyH("LEFT")
	row.note:SetJustifyV("TOP")
	row.note:SetWordWrap(true)
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetColorTexture(Tokens.Color("white"))
	row.changed = row:CreateTexture(nil, "OVERLAY")
	row.changed:SetTexture((Tokens.Texture("diamond")))
	Widgets.Size(row.changed, 4, 4)
	Widgets.Point(row.changed, "RIGHT", row.label, "LEFT", -2, 0)
	row.changed:Hide()
	row:SetScript("OnMouseUp", function(self, button)
		local item = self.item
		if K.Store.Module("OptionControls").changedSettings and button == "RightButton" and item and item.module and item.key and not Model.IsDisabled(item) then
			K.Options.Write(item.module, item.key, K.Options.Default(item.module, item.key))
			ns.Changed()
		end
	end)
	row.Restyle = Rows.Restyle
	Rows.Restyle(row)
	Widgets.Track(row)
	return row
end
