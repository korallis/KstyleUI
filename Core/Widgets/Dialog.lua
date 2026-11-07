-- Dialog.lua: KstyleUI's own popup and confirm dialogs, shown one at a time in a glass panel, never through StaticPopupDialogs.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion, L = ns.Tokens, ns.Scale, ns.Motion, ns.L
local max = math.max

local WIDTH = 360
local LAYOUT_KEY = "Widgets.Dialog"
local DEFAULT_POSITION = { anchor = "CENTER", x = 0, y = 120 }
local BODY_LINES = 2

local host
local queue = {}
local current

local Handle = {}
Handle.__index = Handle

local ShowNext

local function Finish(handle)
	handle.closed = true
	if handle == current then
		current = nil
		if #queue > 0 then
			ShowNext()
		else
			Motion.FadeOut(host, Tokens.Duration("panelClose"))
			Widgets.Sound("IG_MAINMENU_CLOSE")
		end
		return
	end
	for i = #queue, 1, -1 do
		if queue[i] == handle then
			table.remove(queue, i)
		end
	end
end

function Handle:Close()
	if not self.closed then
		Finish(self)
	end
end

function Handle:IsShown()
	return current == self
end

function Handle:GetText()
	if self.editBox then
		return self.editBox:GetText()
	end
	return nil
end

local function Run(handle, fn)
	if fn then
		ns.Call(fn, handle)
	end
end

local function Cancel()
	local handle = current
	if handle then
		Run(handle, handle.opts.onCancel)
		handle:Close()
	end
end

local function ButtonClick(button)
	local handle, spec = current, button.spec
	if not handle or not spec then
		return
	end
	Run(handle, spec.onClick)
	handle:Close()
end

local function PressPrimary()
	local handle = current
	if not handle then
		return
	end
	host.editBox:ClearFocus()
	for _, button in ipairs(host.visibleButtons) do
		if button.spec and button.spec.primary then
			ButtonClick(button)
			return
		end
	end
end

local function TakeButton(i, spec)
	if spec.reload then
		if not host.reloadButton then
			host.reloadButton = Widgets.ReloadButton(host, {})
		end
		local button = host.reloadButton
		button:SetText(spec.label or L["Reload"])
		button.beforeReload = spec.onClick and function()
			Run(current, spec.onClick)
		end
		return button
	end
	local button = host.pool[i]
	if not button then
		button = Widgets.Button(host, { onClick = ButtonClick })
		host.pool[i] = button
	end
	button.primary = spec.primary == true
	button:SetText(spec.label or L["OK"])
	button:Paint()
	return button
end

local function Layout()
	local pad = Widgets.Snap(host, Tokens.Size("panelPadding"))
	local gap = Widgets.Snap(host, Tokens.Size("gapMedium"))
	local inner = Widgets.Snap(host, WIDTH) - 2 * pad
	local body = host.body
	body:SetWidth(inner)
	local _, bodySize = Tokens.Font("body")
	local bodyHeight = Widgets.TextHeight(body, bodySize * BODY_LINES)
	local y = Widgets.Snap(host, Tokens.Size("panelPadding") + Tokens.Size("heading") + Tokens.Size("gapMedium")) + gap
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", host, "TOPLEFT", pad, -y)
	y = y + bodyHeight + gap
	if host.editBox:IsShown() then
		host.editBox:ClearAllPoints()
		host.editBox:SetPoint("TOPLEFT", host, "TOPLEFT", pad, -y)
		host.editBox.opts.width = inner
		host.editBox:Restyle()
		y = y + (host.editBox:GetHeight() or 0) + gap
	end
	local x = pad
	local tallest = 0
	for i = #host.visibleButtons, 1, -1 do
		local button = host.visibleButtons[i]
		button:ClearAllPoints()
		button:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -x, pad)
		x = x + (button:GetWidth() or 0) + gap
		tallest = max(tallest, button:GetHeight() or 0)
	end
	host.opts.height = y + tallest + pad
	Widgets.Size(host, WIDTH, host.opts.height)
end

local function Render(handle)
	local opts = handle.opts
	host:SetTitle(opts.title or L["KstyleUI"])
	Widgets.SetText(host.body, opts.text or "")
	for _, button in ipairs(host.visibleButtons) do
		button:Hide()
	end
	host.visibleButtons = {}
	local buttons = opts.buttons or { { label = L["OK"], primary = true } }
	for i, spec in ipairs(buttons) do
		local button = TakeButton(i, spec)
		button.spec = spec
		button:Show()
		host.visibleButtons[#host.visibleButtons + 1] = button
	end
	local box = host.editBox
	if opts.editBox then
		local spec = opts.editBox
		box:SetText(spec.text or "")
		Widgets.SetText(box.placeholder, spec.placeholder or "")
		box:SetMaxLetters(spec.maxLetters or 0)
		box:Show()
		box:Paint()
		handle.editBox = box
	else
		box:Hide()
	end
	Layout()
end

function ShowNext()
	local handle = table.remove(queue, 1)
	if not handle then
		return
	end
	current = handle
	Render(handle)
	host:Open()
	if handle.editBox then
		C_Timer.After(0, function()
			if current == handle then
				handle.editBox:SetFocus()
			end
		end)
	end
end

function Widgets.DialogHost()
	if host then
		return host
	end
	host = Widgets.Panel(Scale.Root(), { width = WIDTH, height = WIDTH / 2, title = L["KstyleUI"], strata = "DIALOG", hidden = true })
	host.body = Widgets.Text(host, "body", "text")
	host.body:SetJustifyH("LEFT")
	host.body:SetWordWrap(true)
	host.editBox = Widgets.EditBox(host, { onEnter = PressPrimary })
	host.editBox:Hide()
	host.pool = {}
	host.visibleButtons = {}
	local restyle = host.Restyle
	host.Restyle = function(self)
		restyle(self)
		if current then
			Layout()
		end
	end
	Widgets.EscapeCloses(host, Cancel)
	Widgets.Place(host, LAYOUT_KEY, DEFAULT_POSITION, { scalable = true, window = true, label = L["Dialogs"] })
	return host
end

function Widgets.Popup(opts)
	opts = opts or {}
	if opts.key then
		if current and current.opts.key == opts.key then
			return current
		end
		for _, handle in ipairs(queue) do
			if handle.opts.key == opts.key then
				return handle
			end
		end
	end
	Widgets.DialogHost()
	local handle = setmetatable({ opts = opts, closed = false }, Handle)
	queue[#queue + 1] = handle
	if not current then
		ShowNext()
	end
	return handle
end

function Widgets.Confirm(opts)
	opts = opts or {}
	return Widgets.Popup({
		key = opts.key,
		title = opts.title,
		text = opts.text,
		onCancel = opts.onCancel,
		buttons = {
			{ label = opts.cancelLabel or L["Cancel"], onClick = opts.onCancel },
			{ label = opts.acceptLabel or L["Accept"], primary = true, reload = opts.reload, onClick = opts.onAccept },
		},
	})
end

function Widgets.ReloadPrompt(text)
	return Widgets.Confirm({
		key = "Widgets.ReloadPrompt",
		title = L["Reload needed"],
		text = text,
		reload = true,
		acceptLabel = L["Reload now"],
		cancelLabel = L["Later"],
	})
end
