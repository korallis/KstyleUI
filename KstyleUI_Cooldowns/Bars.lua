-- Bars.lua: a holder of KstyleUI tracked buff bars: a square bar (a black pixel round a dark track) with the icon on a dark button tile, the buff's name, a subtle fill driven by a duration object and a right-aligned countdown (a cooldown bar may split into one section per charge, with pixel lines and the recharging section filling, optionally darker, after the charges); past the last bar, a "+N" bar one slot above the full stack, clear of the buff row under it, lists the rest on hover.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Grid, Style, Rules = ns.Grid, ns.Style, ns.Rules

local BarRow = {}
BarRow.__index = BarRow
ns.BarRow = BarRow

local ICON_CROP = 0.07
local ICON_INSET_LINES = 3
local ICON_INSET_MAX_SHARE = 0.2
local TEXT_INSET = 10
local SPARK_EDGE = { HORIZONTAL = { "RIGHT", "LEFT" }, VERTICAL = { "TOP", "BOTTOM" } }

function BarRow.New(parent, cfg)
	local holder = CreateFrame("Frame", nil, parent)
	local content = CreateFrame("Frame", nil, holder)
	content:SetAllPoints(holder)
	local row = setmetatable({ group = "bars", holder = holder, content = content, bars = {}, count = 0, cfg = cfg }, BarRow)
	row:Resize()
	return row
end

function BarRow:Resize()
	local width, height = Grid.Size(self.cfg.grid)
	Widgets.Size(self.holder, width, height)
end

local function Color(bar)
	bar.status:SetBarColor(ns.Settings.BarColor())
end

function BarRow:ShowCount(bar, rule)
	rule = rule or Rules.For(bar.entry)
	local alpha = (self.cfg.showCount or rule.count) and not rule.noCount and 1 or 0
	if bar.countAlpha ~= alpha then
		bar.countAlpha = alpha
		bar.count:SetAlpha(alpha)
	end
end

function BarRow:StyleBar(bar)
	local cfg, current = self.cfg, ns.Settings.current
	local holder = self.holder
	bar.icon:SetTexCoord(cfg.iconZoom, 1 - cfg.iconZoom, cfg.iconZoom, 1 - cfg.iconZoom)
	Widgets.Size(bar, cfg.width, cfg.height)
	local height = Widgets.Snap(holder, cfg.height)
	local border = Widgets.Border(bar)
	local tile = bar.iconTile
	tile:SetShown(cfg.icon)
	local left = 0
	if cfg.icon then
		Widgets.Size(tile, cfg.height, cfg.height)
		local iconInset = math.min(border * ICON_INSET_LINES, Widgets.Snap(holder, cfg.height * ICON_INSET_MAX_SHARE))
		bar.icon:ClearAllPoints()
		bar.icon:SetPoint("TOPLEFT", tile, "TOPLEFT", iconInset, -iconInset)
		bar.icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -iconInset, iconInset)
		left = height
	end
	local status = bar.status
	status.opts.width = math.max(1, cfg.width - left - 2 * border)
	status.opts.height = math.max(1, cfg.height - 2 * border)
	status:ClearAllPoints()
	status:SetPoint("TOPLEFT", bar, "TOPLEFT", left + border, -border)
	status:SetOrientation(cfg.orientation)
	status:SetReverseFill(cfg.reverse)
	status:SetBarTexture(cfg.texture)
	status.vertical = cfg.orientation == "VERTICAL"
	status:Restyle()
	if status.vertical then Widgets.Size(status.spark, status.opts.width, status.spark:GetHeight()) end
	status.spark:ClearAllPoints()
	status.spark:SetPoint("CENTER", status:GetStatusBarTexture(), SPARK_EDGE[cfg.orientation][cfg.reverse and 2 or 1])
	status:SetSparkShown(cfg.spark)
	Color(bar)
	bar.timer:SetHideCountdownNumbers(not cfg.timer)
	Style.Countdown(bar.timer, false, true, cfg.decimals and cfg.decimalBelow or nil)
	local countdown = bar.countdown
	local nameEnd, nameEndPoint = bar, "RIGHT"
	if countdown then
		countdown:ClearAllPoints()
		Widgets.Point(countdown, "RIGHT", bar, "RIGHT", -TEXT_INSET, 0)
		countdown:SetJustifyH("RIGHT")
		Style.Font(countdown, current.timerFont, cfg.timerSize, current.timerOutline, "timer")
		if cfg.timer then
			nameEnd, nameEndPoint = countdown, "LEFT"
		end
	end
	bar.name:ClearAllPoints()
	if cfg.icon then
		Widgets.Point(bar.name, "LEFT", tile, "RIGHT", TEXT_INSET, 0)
	else
		Widgets.Point(bar.name, "LEFT", bar, "LEFT", TEXT_INSET, 0)
	end
	Widgets.Point(bar.name, "RIGHT", nameEnd, nameEndPoint, -TEXT_INSET, 0)
	bar.name:SetShown(cfg.name)
	if cfg.nameWrap or bar.nameWrap then
		bar.nameWrap = cfg.nameWrap
		bar.name:SetMaxLines(cfg.nameWrap and math.min(2, math.max(1, math.floor(status.opts.height / cfg.nameSize))) or 0)
	end
	Style.Font(bar.name, current.nameFont, cfg.nameSize, current.nameOutline, "body")
	Style.Font(bar.count, current.countFont, cfg.countSize, current.countOutline)
	bar.count:ClearAllPoints()
	bar.count:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", 0, 0)
	bar.count:SetShown(cfg.icon)
	self:ShowCount(bar)
	Style.Mouse(bar, current.tooltips)
	self:Hash(bar, bar.sections)
end

local FILL_END = { HORIZONTAL = { "LEFT", "RIGHT" }, VERTICAL = { "BOTTOM", "TOP" } }

function BarRow:Hash(bar, sections)
	bar.sections = sections
	local lines = bar.hashes
	if not (lines or sections) then return end
	lines = lines or {}
	bar.hashes = lines
	local cfg, status = self.cfg, bar.status
	local vertical = cfg.orientation == "VERTICAL"
	local length = vertical and status.opts.height or status.opts.width
	local width = cfg.lineWidth * K.Scale.Pixel(1) / Widgets.ScaleFactor(status)
	for i = 1, (sections or 1) - 1 do
		local line = lines[i] or bar.overlay:CreateTexture(nil, "ARTWORK")
		lines[i] = line
		line:SetColorTexture(cfg.lineColorR, cfg.lineColorG, cfg.lineColorB)
		line:ClearAllPoints()
		local at = Widgets.Snap(status, length * i / sections - width / 2)
		if vertical then
			line:SetPoint("BOTTOMLEFT", status, "BOTTOMLEFT", 0, at)
			line:SetPoint("BOTTOMRIGHT", status, "BOTTOMRIGHT", 0, at)
			line:SetHeight(width)
		else
			line:SetPoint("TOPLEFT", status, "TOPLEFT", at, 0)
			line:SetPoint("BOTTOMLEFT", status, "BOTTOMLEFT", at, 0)
			line:SetWidth(width)
		end
		line:Show()
	end
	for i = math.max(1, sections or 1), #lines do lines[i]:Hide() end
	if sections and bar.recharge then self:StyleRecharge(bar) end
end

function BarRow:StyleRecharge(bar)
	local cfg, status, charge = self.cfg, bar.status, bar.recharge
	local vertical, sections = cfg.orientation == "VERTICAL", bar.sections or 1
	charge.opts.width = vertical and status.opts.width or status.opts.width / sections
	charge.opts.height = vertical and status.opts.height / sections or status.opts.height
	charge:SetOrientation(cfg.orientation)
	charge:SetReverseFill(cfg.reverse)
	charge:SetBarTexture(cfg.texture)
	charge:Restyle()
	local r, g, b, a = ns.Settings.BarColor()
	local shade = cfg.chargeShade and 1 - cfg.shadeAlpha or 1
	charge:SetBarColor(r * shade, g * shade, b * shade, a)
	local edge = FILL_END[cfg.orientation]
	charge:ClearAllPoints()
	charge:SetPoint(edge[cfg.reverse and 2 or 1], status:GetStatusBarTexture(), edge[cfg.reverse and 1 or 2])
end

function BarRow:Recharge(bar, duration, smooth, elapsed)
	local charge = bar.recharge
	if not duration then
		if charge and charge:IsShown() then charge:Hide() end
		return
	end
	if not charge then
		charge = Widgets.StatusBar(bar, { background = false })
		charge:SetFrameLevel(bar.status:GetFrameLevel())
		bar.recharge = charge
		self:StyleRecharge(bar)
	end
	if duration ~= true then
		local ok, err = pcall(charge.SetTimerDuration, charge, duration, smooth, elapsed)
		if not ok then ns.LogOnce("charge-bar", "SetTimerDuration failed for a recharging section: " .. tostring(err)) end
	end
	charge:Show()
end

function BarRow:Bar(index)
	local bar = self.bars[index]
	if bar then
		return bar
	end
	bar = CreateFrame("Frame", nil, self.content)
	bar.edge = Widgets.BarEdge(bar)
	local tile = CreateFrame("Frame", nil, bar)
	tile:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	tile.chrome = Widgets.IconChrome(tile)
	bar.iconTile = tile
	local icon = tile:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = tile:CreateMaskTexture()
	mask:SetTexture(Tokens.Texture("iconMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	bar.icon = icon
	bar.status = Widgets.StatusBar(bar, { background = false, spark = true })
	local timer = CreateFrame("Cooldown", nil, bar.status, "CooldownFrameTemplate")
	timer:SetAllPoints(bar.status)
	timer:SetDrawSwipe(false)
	timer:SetDrawEdge(false)
	timer:SetDrawBling(false)
	bar.timer = timer
	local countdown = timer:GetCountdownFontString()
	if countdown then
		Widgets.StyleText(countdown, "timer")
		Widgets.TextColor(countdown, "textEmphasis")
	end
	bar.countdown = countdown
	local overlay = CreateFrame("Frame", nil, bar)
	overlay:SetAllPoints(bar)
	overlay:SetFrameLevel(timer:GetFrameLevel() + 1)
	bar.overlay = overlay
	bar.name = Widgets.Text(overlay, "body", "textEmphasis")
	bar.name:SetJustifyH("LEFT")
	bar.count = Widgets.Text(overlay, "number", "textEmphasis")
	Style.Tooltips(bar)
	self.bars[index] = bar
	self:StyleBar(bar)
	return bar
end

function BarRow:Place()
	local grid, count = self.cfg.grid, self.count
	for i = 1, count do
		local bar = self.bars[i]
		local x, y = Grid.Offset(i, count, grid)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", self.content, "TOPLEFT", Widgets.Snap(self.holder, x), -Widgets.Snap(self.holder, y))
	end
end

function BarRow:Overflow(hidden)
	local chip = self.chip
	if hidden <= 0 then
		if chip then
			chip:Hide()
		end
		return
	end
	if not chip then
		chip = Style.Chip(self.content, false)
		Style.Inspect(chip, self, K.L["%d more tracked bars"])
		self.chip = chip
	end
	local cfg = self.cfg
	Style.ShowChip(chip, self.content, "UP", cfg.spacing, cfg.width, cfg.height, "+" .. hidden, cfg.nameSize)
end

function BarRow:SetCount(count)
	self.requested = count
	local hidden = 0
	if count > self.cfg.count then
		hidden = count - self.cfg.count
		count = self.cfg.count
	end
	for i = 1, count do
		self:Bar(i):Show()
	end
	for i = count + 1, #self.bars do
		local bar = self.bars[i]
		bar.entry = nil
		bar:Hide()
	end
	self.count = count
	self:Place()
	self:Overflow(count > 0 and hidden or 0)
	return count
end

function BarRow:Restyle()
	self:Apply()
end

function BarRow:Apply(cfg)
	self.cfg = cfg or self.cfg
	self:Resize()
	for _, bar in ipairs(self.bars) do
		self:StyleBar(bar)
	end
	self:SetCount(self.requested or self.count)
end
