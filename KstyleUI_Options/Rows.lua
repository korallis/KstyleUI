-- Rows.lua: one settings row: a header, a note, or a label with wrapping help text and the kit control its kind needs, as tall as its text.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Model = ns.Model
local format, floor, max = string.format, math.floor, math.max

local Rows = {}
ns.Rows = Rows

Rows.HEIGHT = 48
Rows.CONTROL_WIDTH = 220
Rows.MIN_TEXT_WIDTH = 240
local MAX_BUTTONS = 2
local SWATCH_SIZE = 20
local MARK_WIDTH = 2
local MARK_HEIGHT = 12
local RULE_ALPHA = 1
local BYTE = 255

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
	slider:HookScript("OnMouseUp", function()
		Flush(row)
	end)
	slider:HookScript("OnHide", function()
		Flush(row)
	end)
	return slider
end

local function Dropdown(row, maker)
	return maker(row, {
		width = Rows.CONTROL_WIDTH,
		unknownLabel = function(value)
			return tostring(value)
		end,
		onChange = function(value, control)
			Apply(row, value, control)
		end,
	})
end

function MAKERS.dropdown(row)
	return Dropdown(row, Widgets.Dropdown)
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
	holder.swatch:SetPoint("RIGHT", holder, "RIGHT")
	holder.hex = Widgets.Text(holder, "body", "textEmphasis")
	holder.hex:SetPoint("RIGHT", holder.swatch, "LEFT", -Gap(holder), 0)
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
			button:SetPoint("RIGHT", holder, "RIGHT")
		else
			button:SetPoint("RIGHT", holder.buttons[i - 1], "LEFT", -Gap(holder, "gapSmall"), 0)
		end
		holder.buttons[i] = button
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

function FILL.slider(control, item, value)
	local low, high = item.min or 0, item.max or 1
	if low < high then
		control:SetRange(low, high, item.step)
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

local function PlaceText(row, control, width)
	local gap, tiny = Gap(row), Snap(row, Tokens.Size("gapTiny"))
	local reserve = control and Snap(row, Rows.CONTROL_WIDTH) + gap or 0
	local column = width - 2 * gap - reserve
	local stacked = control ~= nil and column < Rows.MIN_TEXT_WIDTH
	local helpWidth = stacked and width - 2 * gap or column
	local labelHeight = Widgets.LineHeight(row.label)
	row.label:SetWidth(max(1, column))
	local helpHeight = Widgets.WrappedHeight(row.help, max(1, helpWidth))
	local textHeight = labelHeight + (helpHeight > 0 and tiny + helpHeight or 0)
	local band = stacked and max(labelHeight, ControlHeight(control)) or 0
	local blockHeight = stacked and band + (helpHeight > 0 and tiny + helpHeight or 0) or max(textHeight, control and ControlHeight(control) or 0)
	local height = Snap(row, max(Rows.HEIGHT, blockHeight + 2 * gap))
	local top = Snap(row, (height - (stacked and blockHeight or textHeight)) / 2)
	local labelTop = stacked and top + Snap(row, (band - labelHeight) / 2) or top
	local helpTop = stacked and top + band + tiny or top + labelHeight + tiny
	row.label:ClearAllPoints()
	row.help:ClearAllPoints()
	row.label:SetPoint("TOPLEFT", row, "TOPLEFT", gap, -labelTop)
	row.label:SetPoint("RIGHT", row, "RIGHT", -(gap + reserve), 0)
	row.help:SetPoint("TOPLEFT", row, "TOPLEFT", gap, -helpTop)
	row.help:SetPoint("RIGHT", row, "RIGHT", stacked and -gap or -(gap + reserve), 0)
	if control then
		control:ClearAllPoints()
		if stacked then
			control:SetPoint("TOPRIGHT", row, "TOPRIGHT", -gap, -(top + Snap(row, (band - ControlHeight(control)) / 2)))
		else
			control:SetPoint("RIGHT", row, "TOPRIGHT", -gap, -height / 2)
		end
	end
	return height
end

local function ShowHeader(row, item)
	local gap = Gap(row)
	if (item.level or 1) == 1 then
		row.caption:ClearAllPoints()
		row.caption:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", gap, gap)
		row.caption:SetPoint("RIGHT", row, "RIGHT", -gap, 0)
		Widgets.SetText(row.caption, item.label)
		row.caption:Show()
		row.rule:ClearAllPoints()
		row.rule:SetPoint("TOPLEFT", row, "TOPLEFT", gap, -gap)
		row.rule:SetPoint("TOPRIGHT", row, "TOPRIGHT", -gap, -gap)
		row.rule:SetHeight(Widgets.Border(row))
		row.rule:Show()
	else
		row.mark:ClearAllPoints()
		row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", gap, gap)
		Widgets.Size(row.mark, MARK_WIDTH, MARK_HEIGHT)
		row.mark:Show()
		row.label:ClearAllPoints()
		row.label:SetPoint("LEFT", row.mark, "RIGHT", gap, 0)
		row.label:SetPoint("RIGHT", row, "RIGHT", -gap, 0)
		Widgets.SetText(row.label, item.label)
		Widgets.TextColor(row.label, "textEmphasis")
		row.label:Show()
	end
end

local function ShowNote(row, item, width)
	local gap = Gap(row)
	Widgets.SetText(row.note, item.label)
	local height = Snap(row, max(Rows.HEIGHT, Widgets.WrappedHeight(row.note, max(1, width - 2 * gap)) + 2 * gap))
	row.note:ClearAllPoints()
	row.note:SetPoint("TOPLEFT", row, "TOPLEFT", gap, -gap)
	row.note:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -gap, gap)
	row.note:Show()
	return height
end

local function SameSetting(a, b)
	return a ~= nil and b ~= nil and a.kind == b.kind and a.label == b.label
		and a.page == b.page and a.module == b.module and a.key == b.key and a.element == b.element
end

local function Layout(row, item, width)
	local kind = item.kind
	for controlKind, control in pairs(row.controls) do
		if controlKind ~= kind then
			control:Hide()
		end
	end
	for _, region in ipairs({ row.label, row.help, row.caption, row.note, row.rule, row.mark }) do
		region:Hide()
	end
	if kind == "header" then
		ShowHeader(row, item)
		return Rows.HEIGHT, nil
	elseif kind == "note" then
		return ShowNote(row, item, width), nil
	end
	local control = Control(row, kind)
	Widgets.SetText(row.label, item.label)
	Widgets.SetText(row.help, item.help or "")
	return PlaceText(row, control, width), control
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
	if not keep then
		row.pending = nil
	end
	row.item = item
	row.list = list or row.list
	local _, control = Layout(row, item, RowWidth(row.list))
	if kind ~= "header" and kind ~= "note" then
		local disabled = Model.IsDisabled(item)
		Widgets.TextColor(row.label, disabled and "textDisabled" or "textEmphasis")
		Widgets.TextColor(row.help, disabled and "textDisabled" or "text")
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
	Widgets.Tint(row.rule, "edgeFaint", RULE_ALPHA)
	Widgets.Tint(row.mark, "accent")
	if row.item then
		Rows.Update(row, row.item, nil, row.list)
	end
end

function Rows.Create(list)
	local row = CreateFrame("Frame", nil, list.view)
	row.list = list
	row.controls = {}
	row.label = Widgets.Text(row, "body", "textEmphasis")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.help = Widgets.Text(row, "body", "text")
	row.help:SetJustifyH("LEFT")
	row.help:SetJustifyV("TOP")
	row.help:SetWordWrap(true)
	row.caption = Widgets.Text(row, "title", "text")
	row.caption:SetJustifyH("LEFT")
	row.caption:SetWordWrap(false)
	row.note = Widgets.Text(row, "body", "text")
	row.note:SetJustifyH("LEFT")
	row.note:SetJustifyV("TOP")
	row.note:SetWordWrap(true)
	row.rule = row:CreateTexture(nil, "ARTWORK")
	row.rule:SetTexture((Tokens.Texture("divider")))
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetColorTexture(Tokens.Color("white"))
	row.Restyle = Rows.Restyle
	Rows.Restyle(row)
	Widgets.Track(row)
	return row
end
