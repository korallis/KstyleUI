-- Preview.lua: the settings window's live preview: plain kit icon buttons that show the bar being edited with its current settings.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local floor, max, min = math.floor, math.max, math.min

local SAMPLE_ICON = 134400
local FALLBACK_COUNT = 6
local SAMPLE_COOLDOWN = 8
local SAMPLE_ELAPSED = 2
local FADED_PREVIEW_ALPHA = 0.5

local Preview = {}

local function Sample(i)
	local bar = C_ActionBar
	if bar and type(bar.GetActionTexture) == "function" and ns.SlotValid(i) then
		local texture = bar.GetActionTexture(i)
		if ns.IsSecret(texture) or texture ~= nil then
			return texture
		end
	end
	return SAMPLE_ICON
end

local function Fits(parent, size, gap, wanted)
	local width = parent:GetWidth()
	if ns.IsSecret(width) or type(width) ~= "number" or width <= 0 then
		return min(wanted, FALLBACK_COUNT)
	end
	return max(1, min(wanted, floor((width + gap) / (size + gap))))
end

function Preview:Refresh()
	local key = ns.Config("editBar")
	local def = ns.BAR[key] or ns.BAR.bar1
	local cfg = ns.Config(def.key)
	local size, gap = Widgets.Snap(self, cfg.size), Widgets.Snap(self, cfg.spacing)
	local count = Fits(self.parentFrame, size, gap, min(def.max, cfg.buttons))
	local rows = min(cfg.rows, count)
	local width, height = ns.GridSize(count, rows, size, gap)
	self:SetSize(width, height)
	local r, g, b = ns.AccentRGB()
	for i, button in ipairs(self.buttons) do
		if i <= count then
			local col, row = ns.Cell(i, count, rows, cfg.orientation, cfg.growth)
			button.opts.size = cfg.size
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self, "TOPLEFT", col * (size + gap), -row * (size + gap))
			button:Restyle()
			button:Show()
			button:SetIcon(Sample(def.kind == "action" and ns.Slot(i, def.page or 1) or i))
			button:SetHotkey(cfg.hotkey and ns.ShortKey(ns.FirstKey(def.binding .. i)) or nil)
			button.hotkey:SetShown(cfg.hotkey == true)
			button:SetCount(i == 2 and cfg.count and "3" or nil)
			button:SetAccent(r, g, b)
			ns.StyleTextsFor(button, def.key)
		else
			button:Hide()
		end
	end
	local procButton, rangeButton, powerButton = self.buttons[1], self.buttons[4], self.buttons[5]
	procButton:SetProc(true)
	local range, power = ns.Config("rangeColor"), ns.Config("powerColor")
	rangeButton:SetTint(range.r, range.g, range.b)
	ns.Socket.Tint(rangeButton, "rangeColor")
	powerButton.lacksPower = true
	powerButton:SetTint(power.r, power.g, power.b)
	local cooldown = self.buttons[3]
	if type(GetTime) == "function" then
		cooldown:SetCooldown(GetTime() - SAMPLE_ELAPSED, SAMPLE_COOLDOWN)
	end
	cooldown.cooldown:SetHideCountdownNumbers(cfg.cooldown ~= true)
	local alpha = cfg.fade and max(cfg.fadeAlpha, FADED_PREVIEW_ALPHA) or 1
	self:SetAlpha(alpha)
end

function ns.Preview(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame.parentFrame = parent
	frame:SetPoint("CENTER", parent, "CENTER")
	frame.buttons = {}
	for i = 1, ns.BAR.bar1.max do
		local button = ns.Socket.Decorate(Widgets.IconButton(frame, { size = ns.Config("bar1").size, silent = true, primary = true }))
		button.macroText = Widgets.Text(button.overlay, "caption", "textEmphasis")
		button.macroText:SetPoint("BOTTOM", button, "BOTTOM", 0, Widgets.Snap(button, 2))
		frame.buttons[i] = button
	end
	for k, fn in pairs(Preview) do
		frame[k] = fn
	end
	frame:Refresh()
	return frame
end
