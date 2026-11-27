-- Row.lua: a holder of KstyleUI icon buttons placed on the grid (two rows may differ in count and icon size), shared by the cooldown rows and the preview, each icon dressed by its spell rules (recharge swipe and countdown included) and hidden or faded by them, by its form, an unknown talent or a missing item (Close gaps re-places the rest); past the grid, a "+N" chip one socket left of the tracked buffs' full row, away from the combat cluster, lists the rest on hover.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Grid, Style, Rules = ns.Grid, ns.Style, ns.Rules

local Row = {}
Row.__index = Row
ns.Row = Row

local OVERFLOW = { buffs = true }
local COOLDOWN_GROUPS = ns.Settings.COOLDOWN_GROUPS
local EMPTY = ns.Rules.EMPTY
local SWIPE_ALPHA = 0.65
local RAIL = { 0.16, 0.06 }
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

local function Countdown(cooldown, group, rule)
	local current = ns.Settings.current
	local tenths = rule.decimals and (tonumber(rule.decimals) or current.decimalBelow) or nil
	Style.Countdown(cooldown, group == "essential", false, tenths, rule.threshold and Style.Hex(Rules.Colour(rule.threshold, "threshold")), current.thresholdBelow)
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
	self.cfg.free = self.cfg.vertical and ns.Settings.Free(self.group) or nil
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
	Style.Font(icon.cooldown:GetCountdownFontString(), current.timerFont, cfg.timerSize, current.timerOutline, self.group ~= "essential" and "timer" or nil)
	Style.Font(icon.count, current.countFont, cfg.countSize, current.countOutline)
	if cfg.keybind then Style.Font(icon.hotkey, current.countFont, cfg.countSize, current.countOutline) end
	Style.PlaceText(icon, self.group)
	Style.Mouse(icon, current.tooltips and not icon.ruleHidden and not icon.blank)
	Style.Accent(icon)
	Style.Dress(icon, self.group)
	Style.Lift(icon)
	self:Look(icon)
end

function Row:Recharge(icon, dress)
	local charge, rule, cfg = icon.chargeCooldown, icon.rule or EMPTY, self.cfg
	if not charge then return end
	local idle = not icon.onCooldown
	local swipe, numbers = rule.chargeSwipe ~= nil and idle, rule.chargeTimer ~= nil and idle and cfg.timer and not cfg.countOnly
	if (icon.rechargeSwipe or false) ~= swipe then
		icon.rechargeSwipe = swipe
		charge:SetDrawSwipe(swipe)
		if swipe then
			charge:SetSwipeTexture((K.Tokens.Texture(icon.medRound and "dot" or "iconMask")))
			charge:SetSwipeColor(Widgets.Rgba("black", SWIPE_ALPHA))
		end
	end
	if (icon.rechargeNumbers or false) == numbers and not (numbers and dress) then return end
	icon.rechargeNumbers = numbers
	charge:SetHideCountdownNumbers(not numbers)
	local text = numbers and charge:GetCountdownFontString()
	if text then
		local current = ns.Settings.current
		Style.Font(text, current.timerFont, cfg.timerSize, current.timerOutline, self.group ~= "essential" and "timer" or nil)
		Widgets.TextColor(text, "slotNumber")
		Style.TextColour(text, rule.timerColour, "slotNumber")
		text:ClearAllPoints()
		text:SetPoint("CENTER", icon.countdown, "CENTER")
		Countdown(charge, self.group, rule)
	end
end

function Row:Look(icon)
	local cfg, group, rule = self.cfg, self.group, icon.rule or EMPTY
	local cooldowns = COOLDOWN_GROUPS[group]
	local only = cooldowns and cfg.countOnly or false
	local bare = only or cfg.numbersOnly
	local cooldown = icon.cooldown
	cooldown:SetHideCountdownNumbers(not cfg.timer or only)
	if type(cooldown.SetDrawSwipe) == "function" then cooldown:SetDrawSwipe(cfg.swipe and not rule.noSwipe and not bare) end
	cooldown:SetReverse(group == "buffs" or rule.reverse and true or false)
	icon.count:SetAlpha((cfg.showCount or rule.count) and not rule.noCount and not cfg.numbersOnly and 1 or 0)
	if (icon.countOnly or false) ~= bare then
		icon.countOnly = bare
		icon.icon:SetAlpha(bare and 0 or 1)
	end
	Countdown(cooldown, group, rule)
	Style.TextColour(icon.countdown, rule.timerColour, "slotNumber")
	local grey = (cfg.desaturate or rule.grey) and not rule.colour and true or false
	local repaint = (icon.greyWhileCooling or false) ~= grey
	icon.greyWhileCooling = grey
	local hide = cooldowns and (not cfg.edge or bare) or nil
	local hideCharge = hide or cooldowns and rule.noEdge or nil
	local tint = rule.tint and { Rules.Colour(rule.tint, "tint") } or nil
	if icon.hideEdge ~= hide or icon.hideChargeEdge ~= hideCharge or tint or icon.swipeTint then
		styleCooldown = styleCooldown or icon.StyleCooldown
		icon.StyleCooldown, icon.hideEdge, icon.hideChargeEdge, icon.swipeTint, icon.cooldownStyleKey = StyleCooldown, hide, hideCharge, tint, nil
		if icon.chargeCooldown then icon.chargeCooldown:SetDrawEdge(not hideCharge) end
	end
	local glow = cooldowns and rule.glow or not cooldowns and rule.activeGlow
	glow = glow and { Rules.Colour(glow, "glow") } or nil
	if glow or icon.glowTint then
		icon.glowTint = glow
		Style.GlowColor(icon)
	end
	icon:StyleCooldown()
	self:Recharge(icon, true)
	if not cooldowns then
		icon.inactiveShade = rule.grey and "grey" or rule.colour and "colour" or cfg.inactiveShade
		icon:Paint()
	elseif repaint then
		icon:Paint()
	end
end

function Row:Swing(icon, start, duration)
	local sweep = icon.swingSweep
	if start and not sweep then
		sweep = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
		sweep:SetAllPoints(icon.icon)
		sweep:SetSwipeTexture((K.Tokens.Texture(icon.medRound and "dot" or "iconMask")))
		sweep:SetSwipeColor(Widgets.Rgba("black", SWIPE_ALPHA))
		sweep:SetDrawEdge(false)
		sweep:SetDrawBling(false)
		sweep:SetHideCountdownNumbers(true)
		icon.swingSweep = sweep
	end
	if start then
		sweep:SetCooldown(start, duration)
	elseif sweep then
		sweep:Clear()
	end
end

local function Outside(form)
	local now = ns.form
	if now == nil then return false end
	if type(form) ~= "string" or not now then return not now end
	return not (strcmputf8i and strcmputf8i(now, form) == 0 or now:lower() == form:lower())
end

function Row:Visible(icon)
	local rule, current = icon.rule or EMPTY, ns.Settings.current
	local cooling = icon.onCooldown == true
	local ready = not cooling and not (icon.recharging and not rule.spent)
	local hidden = (rule.hide or rule.form and Outside(rule.form) or type(rule.talent) == "string" and not Rules.Known(rule.talent) or icon.missing and self.cfg.hideMissing or rule.hideCooling and cooling or rule.hideReady and ready or rule.hideUnusable and (cooling or icon.castable == false)) and true or false
	local alpha = hidden and 0 or rule.fade and cooling and current.fadeAlpha or 1
	if (icon.ruleAlpha or 1) ~= alpha then
		icon.ruleAlpha = alpha
		icon:SetAlpha(alpha)
	end
	if icon.ruleHidden ~= hidden then
		icon.ruleHidden = hidden
		Style.Mouse(icon, current.tooltips and not hidden)
	end
	local gap = hidden and (current.closeGaps or rule.shift) and true or false
	if (icon.ruleGap or false) ~= gap then
		icon.ruleGap = gap
		self.placeOwed = true
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

function Row:Settle()
	if self.placeOwed then self:Place() end
end

function Row:Place()
	local cfg, count = self.cfg, self.count
	self.placeOwed = nil
	local gaps = COOLDOWN_GROUPS[self.group]
	local shown, slot = count, 0
	for i = 1, count do
		if gaps and self.icons[i].ruleGap then shown = shown - 1 end
	end
	for i = 1, count do
		local icon = self.icons[i]
		if not (gaps and icon.ruleGap) then
			slot = slot + 1
			local x, y = Grid.Offset(slot, shown, cfg)
			local size = Grid.Cell(slot, cfg)
			if icon.opts.size ~= size then
				icon.opts.size = size
				icon:Restyle()
			end
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", self.content, "TOPLEFT", Widgets.Snap(self.holder, x), -Widgets.Snap(self.holder, y))
		end
	end
	self:Rails()
end

function Row:Rails()
	local lines, order = {}, {}
	for i = 1, self.count do
		local icon = self.icons[i]
		local _, _, _, x, y = icon:GetPoint(1)
		if icon.medRound and not icon.ruleGap and x then
			local size = icon.opts.size
			local line = lines[y]
			if not line then
				line = { left = x, right = x + size, size = size }
				lines[y] = line
				order[#order + 1] = y
			end
			line.left, line.right, line.size = math.min(line.left, x), math.max(line.right, x + size), math.max(line.size, size)
		end
	end
	self.rails = self.rails or {}
	for i = 1, math.max(#order, #self.rails) do
		local rail, y = self.rails[i], order[i]
		local line = y and lines[y]
		if line and not rail then
			rail = { self.content:CreateTexture(nil, "BACKGROUND", nil, 1), self.content:CreateTexture(nil, "BACKGROUND", nil, 2) }
			rail[1]:SetColorTexture(K.Tokens.Color("black"))
			rail[2]:SetColorTexture(K.Tokens.Color("medSocketLip"))
			self.rails[i] = rail
		end
		for layer, texture in ipairs(rail or {}) do
			texture:SetShown(line ~= nil and line.right - line.left > line.size)
			if line then
				local half = line.size / 2
				texture:ClearAllPoints()
				texture:SetPoint("LEFT", self.content, "TOPLEFT", line.left + half, y - half)
				texture:SetPoint("RIGHT", self.content, "TOPLEFT", line.right - half, y - half)
				texture:SetHeight(Widgets.Snap(self.holder, line.size * RAIL[layer]))
			end
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
