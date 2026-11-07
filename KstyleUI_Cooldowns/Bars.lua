-- Bars.lua: a holder of KstyleUI tracked buff bars: a glass tile with an icon, the buff's name, a fill driven by a duration object and a countdown.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Grid, Style = ns.Grid, ns.Style

local BarRow = {}
BarRow.__index = BarRow
ns.BarRow = BarRow

local ICON_CROP = 0.07
local TIMER_SHARE = 2.5
local TEXT_INSET = 4
local EDGE_ALPHA = 0.5

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
	local left = 0
	bar.icon:ClearAllPoints()
	bar.icon:SetShown(cfg.icon)
	if cfg.icon then
		bar.icon:SetPoint("TOPLEFT", bar, "TOPLEFT", border, -border)
		bar.icon:SetPoint("BOTTOMRIGHT", bar, "TOPLEFT", height - border, -height + border)
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
	local inset = Widgets.Snap(holder, TEXT_INSET)
	bar.timer:ClearAllPoints()
	bar.timer:SetPoint("TOPRIGHT", status, "TOPRIGHT", 0, 0)
	bar.timer:SetPoint("BOTTOMRIGHT", status, "BOTTOMRIGHT", 0, 0)
	bar.timer:SetWidth(Widgets.Snap(holder, cfg.height * TIMER_SHARE))
	bar.timer:SetHideCountdownNumbers(not cfg.timer)
	bar.name:ClearAllPoints()
	bar.name:SetPoint("LEFT", status, "LEFT", inset, 0)
	bar.name:SetPoint("RIGHT", bar.timer, "LEFT", -inset, 0)
	bar.name:SetShown(cfg.name)
	Style.Font(bar.name, current.nameFont, cfg.nameSize, current.nameOutline, "body")
	Style.Font(bar.timer:GetCountdownFontString(), current.timerFont, cfg.timerSize, current.timerOutline)
	Style.Font(bar.count, current.countFont, cfg.countSize, current.countOutline)
	bar.count:ClearAllPoints()
	bar.count:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", 0, 0)
	bar.count:SetShown(cfg.icon)
	Style.Mouse(bar, current.tooltips)
	local r, g, b = ns.Settings.Accent()
	bar.chrome:SetEdgeRGBA(r, g, b, EDGE_ALPHA)
end

function BarRow:Bar(index)
	local bar = self.bars[index]
	if bar then
		return bar
	end
	bar = CreateFrame("Frame", nil, self.content)
	bar.chrome = Widgets.Chrome(bar, { shape = "tile", fill = "raised", shadow = false })
	local icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = bar:CreateMaskTexture()
	mask:SetTexture(Tokens.Texture("iconMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	bar.icon = icon
	bar.status = Widgets.StatusBar(bar, { background = "track" })
	local timer = CreateFrame("Cooldown", nil, bar.status, "CooldownFrameTemplate")
	timer:SetDrawSwipe(false)
	timer:SetDrawEdge(false)
	timer:SetDrawBling(false)
	bar.timer = timer
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
