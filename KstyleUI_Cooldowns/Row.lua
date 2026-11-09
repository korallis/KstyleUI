-- Row.lua: a holder of KstyleUI icon buttons placed on the grid, shared by the cooldown rows and the preview; past the grid, a "+N" chip one socket left of the tracked buffs' full row, away from the combat cluster, lists the rest on hover.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Grid, Style = ns.Grid, ns.Style

local Row = {}
Row.__index = Row
ns.Row = Row

local OVERFLOW = { buffs = true }

function Row.New(parent, group, cfg)
	local holder = CreateFrame("Frame", nil, parent)
	local content = CreateFrame("Frame", nil, holder)
	content:SetAllPoints(holder)
	local row = setmetatable({ group = group, holder = holder, content = content, icons = {}, count = 0, cfg = cfg }, Row)
	row:Resize()
	return row
end

function Row:Resize()
	local width, height = Grid.Size(self.cfg)
	Widgets.Size(self.holder, width, height)
end

function Row:StyleIcon(icon)
	local cfg, current = self.cfg, ns.Settings.current
	if icon.opts.size ~= cfg.size then
		icon.opts.size = cfg.size
		icon:Restyle()
	end
	icon.cooldown:SetHideCountdownNumbers(not cfg.timer)
	icon.cooldown:SetReverse(self.group == "buffs")
	Style.Countdown(icon.cooldown)
	icon.greyWhileCooling = cfg.desaturate
	Style.Font(icon.cooldown:GetCountdownFontString(), current.timerFont, cfg.timerSize, current.timerOutline)
	Style.Font(icon.count, current.countFont, cfg.countSize, current.countOutline)
	Style.Mouse(icon, current.tooltips)
	Style.Accent(icon)
end

function Row:Icon(index)
	local icon = self.icons[index]
	if not icon then
		icon = Style.Decorate(Widgets.IconButton(self.content, { size = self.cfg.size }), ns.Settings.COOLDOWN_GROUPS[self.group] == true)
		self.icons[index] = icon
		self:StyleIcon(icon)
	end
	return icon
end

function Row:Place()
	local cfg, count = self.cfg, self.count
	for i = 1, count do
		local icon = self.icons[i]
		local x, y = Grid.Offset(i, count, cfg)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", self.content, "TOPLEFT", Widgets.Snap(self.holder, x), -Widgets.Snap(self.holder, y))
	end
end

function Row:Overflow(hidden)
	local chip = self.chip
	if hidden <= 0 then
		if chip then
			chip:Hide()
		end
		return
	end
	if not chip then
		chip = Style.Chip(self.content, true)
		Style.Inspect(chip, self, K.L["%d more tracked buffs"])
		self.chip = chip
	end
	local cfg = self.cfg
	local side = cfg.wrap == "down" and "LEFTBOTTOM" or "LEFT"
	Style.ShowChip(chip, self.content, side, cfg.spacing, cfg.size, cfg.size, "+" .. hidden, cfg.countSize + Style.CHIP_TEXT)
end

function Row:SetCount(count)
	self.requested = count
	local capacity = Grid.Capacity(self.cfg)
	local hidden = 0
	if count > capacity then
		hidden = count - capacity
		count = capacity
	end
	for i = 1, count do
		self:Icon(i):Show()
	end
	for i = count + 1, #self.icons do
		local icon = self.icons[i]
		icon.entry = nil
		Style.SetReady(icon, false)
		Style.SetProc(icon, false)
		icon:Hide()
	end
	self.count = count
	self:Place()
	self:Overflow(OVERFLOW[self.group] and count > 0 and hidden or 0)
	return count
end

function Row:Restyle()
	for _, icon in ipairs(self.icons) do
		icon:Restyle()
	end
	self:Place()
end

function Row:Apply(cfg)
	self.cfg = cfg or self.cfg
	self:Resize()
	for _, icon in ipairs(self.icons) do
		self:StyleIcon(icon)
	end
	self:SetCount(self.requested or self.count)
end
