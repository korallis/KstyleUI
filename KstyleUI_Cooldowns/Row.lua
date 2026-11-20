-- Row.lua: a holder of KstyleUI icon buttons placed on the grid, shared by the cooldown rows and the preview, each icon dressed by its spell rules and hidden or faded by them (Close gaps re-places the rest); past the grid, a "+N" chip one socket left of the tracked buffs' full row, away from the combat cluster, lists the rest on hover.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Grid, Style = ns.Grid, ns.Style

local Row = {}
Row.__index = Row
ns.Row = Row

local OVERFLOW = { buffs = true }
local COOLDOWN_GROUPS = ns.Settings.COOLDOWN_GROUPS
local EMPTY = ns.Rules.EMPTY
local styleCooldown

local function StyleCooldown(icon, real)
	local key, charge = icon.cooldownStyleKey, icon.cooldownStyleCharge
	styleCooldown(icon, real)
	if key == icon.cooldownStyleKey and charge == icon.cooldownStyleCharge then return end
	if icon.hideEdge then icon.cooldown:SetDrawEdge(false) end
	if icon.hideChargeEdge and icon.chargeCooldown then icon.chargeCooldown:SetDrawEdge(false) end
	local tint = icon.swipeTint
	if tint then icon.cooldown:SetSwipeColor(tint[1], tint[2], tint[3], icon.cooldownStyleKey == 1 and 0.4 or 0.65) end
end

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
	icon.opts.quietCooldown = ns.Settings.current.quietCooldown
	icon.opts.readableCountdown = ns.Settings.current.readableCountdown
	local cfg, current = self.cfg, ns.Settings.current
	icon.icon:SetTexCoord(cfg.iconZoom, 1 - cfg.iconZoom, cfg.iconZoom, 1 - cfg.iconZoom)
	if icon.opts.size ~= cfg.size then
		icon.opts.size = cfg.size
		icon:Restyle()
	end
	Style.Countdown(icon.cooldown, self.group == "essential")
	Style.Font(icon.cooldown:GetCountdownFontString(), current.timerFont, cfg.timerSize, current.timerOutline, self.group ~= "essential" and "timer" or nil)
	Style.Font(icon.count, current.countFont, cfg.countSize, current.countOutline)
	Style.PlaceText(icon, self.group)
	Style.Mouse(icon, current.tooltips and not icon.ruleHidden)
	Style.Accent(icon)
	Style.Dress(icon)
	self:Look(icon)
end

function Row:Look(icon)
	local cfg, group, rule = self.cfg, self.group, icon.rule or EMPTY
	local cooldowns = COOLDOWN_GROUPS[group]
	local only = cooldowns and cfg.countOnly or false
	local cooldown = icon.cooldown
	cooldown:SetHideCountdownNumbers(not cfg.timer or only)
	if type(cooldown.SetDrawSwipe) == "function" then cooldown:SetDrawSwipe(cfg.swipe and not rule.noSwipe and not only) end
	cooldown:SetReverse(group == "buffs" or rule.reverse == true)
	icon.count:SetAlpha(cfg.showCount and not rule.noCount and 1 or 0)
	if (icon.countOnly or false) ~= only then
		icon.countOnly = only
		icon.icon:SetAlpha(only and 0 or 1)
	end
	icon.greyWhileCooling = (cfg.desaturate or rule.grey == true) and not rule.colour
	if not cooldowns then
		icon.inactiveShade = rule.grey and "grey" or rule.colour and "colour" or cfg.inactiveShade
		icon:Paint()
		return
	end
	local hide = not cfg.edge or only or nil
	local hideCharge = hide or rule.noEdge or nil
	local tint = rule.tint and { ns.Settings.SourceColor("tint") } or nil
	if icon.hideEdge ~= hide or icon.hideChargeEdge ~= hideCharge or tint or icon.swipeTint then
		styleCooldown = styleCooldown or icon.StyleCooldown
		icon.StyleCooldown, icon.hideEdge, icon.hideChargeEdge, icon.swipeTint, icon.cooldownStyleKey = StyleCooldown, hide, hideCharge, tint, nil
		if icon.chargeCooldown then icon.chargeCooldown:SetDrawEdge(not hideCharge) end
	end
	local glow = rule.glow and { ns.Settings.SourceColor("glow") } or nil
	if glow or icon.glowTint then
		icon.glowTint = glow
		Style.GlowColor(icon)
	end
	icon:StyleCooldown()
end

function Row:Visible(icon)
	local rule, current = icon.rule or EMPTY, ns.Settings.current
	local cooling = icon.onCooldown == true
	local ready = not cooling and not (icon.recharging and not rule.spent)
	local hidden = rule.hideCooling and cooling or rule.hideReady and ready or rule.hideUnusable and (cooling or icon.castable == false) or false
	local alpha = hidden and 0 or rule.fade and cooling and current.fadeAlpha or 1
	if (icon.ruleAlpha or 1) ~= alpha then
		icon.ruleAlpha = alpha
		icon:SetAlpha(alpha)
	end
	if icon.ruleHidden ~= hidden then
		icon.ruleHidden = hidden
		Style.Mouse(icon, current.tooltips and not hidden)
		if current.closeGaps then self:Place() end
	end
end

function Row:Icon(index)
	local icon = self.icons[index]
	if not icon then
		icon = Style.Decorate(Widgets.Slot(self.content, { size = self.cfg.size }), self.group)
		self.icons[index] = icon
		self:StyleIcon(icon)
	end
	return icon
end

function Row:Place()
	local cfg, count = self.cfg, self.count
	local gaps = ns.Settings.current.closeGaps and COOLDOWN_GROUPS[self.group]
	local shown, slot = count, 0
	if gaps then
		for i = 1, count do
			if self.icons[i].ruleHidden then shown = shown - 1 end
		end
	end
	for i = 1, count do
		local icon = self.icons[i]
		if not (gaps and icon.ruleHidden) then
			slot = slot + 1
			local x, y = Grid.Offset(slot, shown, cfg)
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", self.content, "TOPLEFT", Widgets.Snap(self.holder, x), -Widgets.Snap(self.holder, y))
		end
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
	if cfg.wrap == "down" and cfg.timer then
		chip:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMLEFT", -Widgets.Snap(chip, cfg.spacing), Widgets.Snap(chip, cfg.cellHeight - cfg.size))
	end
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
		icon.onCooldown, icon.coolingEntry, icon.coolingTrusted = nil, nil, false
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
