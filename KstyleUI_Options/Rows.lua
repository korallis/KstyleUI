-- Rows.lua: one settings row: a header, a note, or a label with help text and the kit control its kind needs.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Model = ns.Model
local format, floor = string.format, math.floor

local Rows = {}
ns.Rows = Rows

Rows.HEIGHT = 48
Rows.CONTROL_WIDTH = 220
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
		control:ClearAllPoints()
		control:SetPoint("RIGHT", row, "RIGHT", -Gap(row), 0)
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

local function PlaceText(row, hasControl)
	local gap = Gap(row)
	local right = hasControl and -(Snap(row, Rows.CONTROL_WIDTH) + 2 * gap) or -gap
	row.label:ClearAllPoints()
	row.help:ClearAllPoints()
	row.label:SetPoint("BOTTOMLEFT", row, "LEFT", gap, Snap(row, Tokens.Size("gapTiny")))
	row.label:SetPoint("RIGHT", row, "RIGHT", right, 0)
	row.help:SetPoint("TOPLEFT", row, "LEFT", gap, -Snap(row, Tokens.Size("gapTiny")))
	row.help:SetPoint("RIGHT", row, "RIGHT", right, 0)
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

local function ShowNote(row, item)
	local gap = Gap(row)
	row.note:ClearAllPoints()
	row.note:SetPoint("LEFT", row, "LEFT", gap, 0)
	row.note:SetPoint("RIGHT", row, "RIGHT", -gap, 0)
	Widgets.SetText(row.note, item.label)
	row.note:Show()
end

local function SameSetting(a, b)
	return a ~= nil and b ~= nil and a.kind == b.kind and a.label == b.label
		and a.page == b.page and a.module == b.module and a.key == b.key and a.element == b.element
end

function Rows.Update(row, item)
	local kind = item.kind
	local keep = SameSetting(row.item, item)
	row.updating = true
	if not keep then
		row.pending = nil
	end
	row.item = item
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
	elseif kind == "note" then
		ShowNote(row, item)
	else
		local control = Control(row, kind)
		PlaceText(row, control ~= nil)
		local disabled = Model.IsDisabled(item)
		Widgets.SetText(row.label, item.label)
		Widgets.TextColor(row.label, disabled and "textDisabled" or "textEmphasis")
		Widgets.SetText(row.help, item.help or "")
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
		Rows.Update(row, row.item)
	end
end

function Rows.Create(list)
	local row = CreateFrame("Frame", nil, list.view)
	row.controls = {}
	row.label = Widgets.Text(row, "body", "textEmphasis")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.help = Widgets.Text(row, "body", "text")
	row.help:SetJustifyH("LEFT")
	row.help:SetWordWrap(false)
	row.caption = Widgets.Text(row, "caption", "text")
	row.caption:SetJustifyH("LEFT")
	row.caption:SetWordWrap(false)
	row.note = Widgets.Text(row, "body", "text")
	row.note:SetJustifyH("LEFT")
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
