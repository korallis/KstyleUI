-- Bars.lua: a holder of KstyleUI tracked buff bars: a glass tile with the icon on a dark button tile, the buff's name, a subtle fill driven by a duration object and a right-aligned countdown.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Grid, Style = ns.Grid, ns.Style

local BarRow = {}
BarRow.__index = BarRow
ns.BarRow = BarRow

local ICON_CROP = 0.07
local ICON_INSET_LINES = 3
local ICON_INSET_MAX_SHARE = 0.2
local TEXT_INSET = 10

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

function BarRow:StyleBar(bar)
	local cfg, current = self.cfg, ns.Settings.current
	local holder = self.holder
	Widgets.Size(bar, cfg.width, cfg.height)
	local height = Widgets.Snap(holder, cfg.height)
	local border = Widgets.Border(bar)
	local inset = Widgets.Snap(holder, TEXT_INSET)
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
	status:Restyle()
	Color(bar)
	bar.timer:SetHideCountdownNumbers(not cfg.timer)
	Style.Countdown(bar.timer)
	local countdown = bar.countdown
	local nameEnd, nameEndPoint = bar, "RIGHT"
	if countdown then
		countdown:ClearAllPoints()
		countdown:SetPoint("RIGHT", bar, "RIGHT", -inset, 0)
		countdown:SetJustifyH("RIGHT")
		Style.Font(countdown, current.timerFont, cfg.timerSize, current.timerOutline)
		if cfg.timer then
			nameEnd, nameEndPoint = countdown, "LEFT"
		end
	end
	bar.name:ClearAllPoints()
	if cfg.icon then
		bar.name:SetPoint("LEFT", tile, "RIGHT", inset, 0)
	else
		bar.name:SetPoint("LEFT", bar, "LEFT", inset, 0)
	end
	bar.name:SetPoint("RIGHT", nameEnd, nameEndPoint, -inset, 0)
	bar.name:SetShown(cfg.name)
	Style.Font(bar.name, current.nameFont, cfg.nameSize, current.nameOutline, "body")
	Style.Font(bar.count, current.countFont, cfg.countSize, current.countOutline)
	bar.count:ClearAllPoints()
	bar.count:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", 0, 0)
	bar.count:SetShown(cfg.icon)
	Style.Mouse(bar, current.tooltips)
end

function BarRow:Bar(index)
	local bar = self.bars[index]
	if bar then
		return bar
	end
	bar = CreateFrame("Frame", nil, self.content)
	bar.chrome = Widgets.Chrome(bar, { shape = "tile", fill = "surface", edge = "edgeBar", shadow = false })
	local tile = CreateFrame("Frame", nil, bar)
	tile:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	tile.chrome = Widgets.Chrome(tile, { shape = "tile", fill = "buttonFill", shadow = false })
	bar.iconTile = tile
	local icon = tile:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = tile:CreateMaskTexture()
	mask:SetTexture(Tokens.Texture("iconMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	bar.icon = icon
	bar.status = Widgets.StatusBar(bar, { background = false })
	local timer = CreateFrame("Cooldown", nil, bar.status, "CooldownFrameTemplate")
	timer:SetAllPoints(bar.status)
	timer:SetDrawSwipe(false)
	timer:SetDrawEdge(false)
	timer:SetDrawBling(false)
	bar.timer = timer
	local countdown = timer:GetCountdownFontString()
	if countdown then
		Widgets.StyleText(countdown, "number")
		Widgets.TextColor(countdown, "textEmphasis")
	end
	bar.countdown = countdown
	local overlay = CreateFrame("Frame", nil, bar)
	overlay:SetAllPoints(bar)
	overlay:SetFrameLevel(timer:GetFrameLevel() + 1)
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

function BarRow:SetCount(count)
	if count > self.cfg.count then
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
	self:SetCount(self.count)
end
