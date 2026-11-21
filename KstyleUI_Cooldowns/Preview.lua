-- Preview.lua: the settings window's live preview: sample essential, utility and buff rows and buff bars drawn with the current settings (with a sample potion and trinket while an item option is changed, and the focus interrupt while one is named), cooldown samples passed to the other row past its grid, and every sample treated as listed in each spell rule that is not empty, with the list's first colour, name or threshold.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Row, BarRow, Style, Grid, Rules = ns.Settings, ns.Row, ns.BarRow, ns.Style, ns.Grid, ns.Rules

local Preview = {}
ns.Preview = Preview

local build
function Preview.Build(...)
	if build then return build(...) end
	local SAMPLE_ICONS = {
		essential = { 132176, 132153, 132111, 132157, 132169, 132172 },
		utility = { 132164, 132179, 132188, 132159 },
		buffs = { 132159, 132160, 132188 },
		items = { 134834, 133283 },
	}
	local SAMPLE_COOLDOWNS = {
		essential = { { 12, 6 }, false, { 30, 26 }, false, { 20, 18 }, { 8, 6 } },
		utility = { false, { 60, 48 }, false, false },
		buffs = { { 30, 12 }, { 600, 420 }, false },
		items = { false, false },
	}
	local SAMPLE_CHARGES = { essential = { [2] = 2 }, utility = { [2] = 0 }, buffs = { [1] = 3 }, items = { [1] = 3 } }
	local SAMPLE_SWING = 2.6
	local focusStyle = setmetatable({ group = "utility" }, Row)
	local OTHER = { essential = "utility", utility = "essential" }
	local SAMPLE_PROC = { essential = { [4] = true } }
	local SAMPLE_BARS = {
		{ icon = 132208, name = L["Rapid Fire"], duration = 15, left = 9, count = 3 },
		{ icon = 136076, name = L["Aspect of the Hawk"], duration = 1800, left = 1260 },
	}
	local SAMPLE_BAR_FILL = 0.6

	local function Samples(frame, group)
		local list, other = {}, OTHER[group]
		for i = 1, #SAMPLE_ICONS[group] do list[i] = { group, i } end
		local cfg = other and frame.rows[other].cfg
		if cfg and cfg.overflow then
			for i = Grid.Capacity(cfg) + 1, #SAMPLE_ICONS[other] do list[#list + 1] = { other, i } end
		end
		local own = frame.rows[group].cfg
		if other and (own.trinkets or own.hideMissing or not own.itemCount) then list[#list + 1] = { "items", 1 } end
		if other and own.trinkets then list[#list + 1] = { "items", 2 } end
		return list
	end

	local function Fill(row, group, list, rule)
		local cfg, current = row.cfg, Settings.current
		local count = row:SetCount(#list)
		local now = GetTime and GetTime() or 0
		local cooldownGroup = Settings.COOLDOWN_GROUPS[group]
		for i = 1, count do
			local icon, from, n = row.icons[i], list[i][1], list[i][2]
			icon:SetIcon(SAMPLE_ICONS[from][n])
			local sample = SAMPLE_COOLDOWNS[from][n]
			if sample and cooldownGroup then
				icon:SetCooldown(now - (sample[1] - sample[2]), sample[1])
			elseif sample then
				icon:ClearCooldown()
				icon.cooldown:SetCooldown(now - (sample[1] - sample[2]), sample[1])
			else
				icon:ClearCooldown()
			end
			icon.onCooldown = cooldownGroup and sample and true or false
			local charges = SAMPLE_CHARGES[from] and SAMPLE_CHARGES[from][n]
			icon.missing = from == "items" and n == 1 and cfg.hideMissing or nil
			if from == "items" and not cfg.itemCount then charges = nil end
			icon:SetCount(not (charges == 0 and cfg.hideZero) and charges or nil)
			local glows = not current.glowsInCombat or InCombatLockdown()
			Style.SetProc(icon, glows and cfg.procGlow and SAMPLE_PROC[from] and SAMPLE_PROC[from][n])
			Style.SetReady(icon, glows and cooldownGroup and cfg.readyGlow and not sample)
			if not cooldownGroup then
				icon:SetUsable(sample and true or false)
				icon:SetAlpha((rule.hide or rule.missing and sample or cfg.keepPlace and not cfg.inactive and not sample) and 0 or 1)
				Style.SetReady(icon, sample and rule.activeGlow)
			end
			icon.rule = rule
			row:Look(icon)
			if rule.range or icon.outOfRange then
				icon.outOfRange = rule.range
				if rule.range then icon:SetTint(current.rangeR, current.rangeG, current.rangeB) else icon:SetTint(1) end
			end
			icon:Paint()
			if cooldownGroup then
				Style.Glow(icon, icon, "lateGlow", rule.swingGlow ~= nil, Rules.Colour(rule.swingGlow, "glow"))
				row:Swing(icon, rule.swing and now - 1, SAMPLE_SWING)
				if charges and charges > 0 and (rule.chargeSwipe or rule.chargeTimer) then
					icon:ChargeCooldown():SetCooldown(now - 4, 10)
					row:Recharge(icon)
				elseif icon.chargeCooldown then
					icon.chargeCooldown:Clear()
				end
				row:Visible(icon)
			end
		end
		row:Settle()
	end

	local function FocusSample(frame)
		local spell, icon = Settings.current.focusSpell, frame.focus
		if spell == "" then
			if icon then icon:Hide() end
			return
		end
		if not icon then
			icon = Style.Decorate(Widgets.Slot(frame, { size = Settings.current.utility.size }), "utility")
			frame.focus = icon
		end
		focusStyle.cfg = Settings.current.utility
		focusStyle:StyleIcon(icon)
		local id = ns.Focus.Spell(spell)
		local ok, texture = pcall(C_Spell.GetSpellTexture, id)
		icon:SetIcon(id and ok and not issecretvalue(texture) and texture or ns.Data.UNKNOWN_ICON)
		icon:ClearAllPoints()
		Widgets.Point(icon, "TOP", frame.rows.bars.holder, "BOTTOM", 0, -Tokens.Size("gapMedium"))
		icon:Show()
	end

	local function FillBars(row, rule)
		local count = row:SetCount(#SAMPLE_BARS)
		local now = GetTime and GetTime() or 0
		for i = 1, count do
			local bar, sample = row.bars[i], SAMPLE_BARS[i]
			bar.icon:SetTexture(sample.icon)
			Widgets.SetText(bar.name, type(rule.names) == "string" and rule.names or sample.name)
			bar.status:SetMinMaxValues(0, 1)
			bar.status:SetValue(row.cfg.fillUp and 1 - SAMPLE_BAR_FILL or SAMPLE_BAR_FILL)
			bar.timer:SetCooldown(now - (sample.duration - sample.left), sample.duration)
			Widgets.SetText(bar.count, rule.count and sample.count or nil)
			row:ShowCount(bar, rule)
			bar:SetAlpha((rule.hide or rule.missing) and 0 or 1)
		end
	end

	local function Fitted(frame, cfg, group)
		local width = frame.pane:GetWidth()
		local columns = #SAMPLE_ICONS[group]
		if not (cfg.vertical and Settings.Free(group)) then
			if issecretvalue(width) or type(width) ~= "number" or width <= 0 then
				return cfg
			end
			columns = math.floor((width + cfg.spacing) / (cfg.size + cfg.spacing))
		end
		columns = math.max(1, math.min(cfg.columns, columns))
		if columns == cfg.columns then
			return cfg
		end
		local out = {}
		for key, value in pairs(cfg) do
			out[key] = value
		end
		out.columns = columns
		return out
	end

	local function Refresh(frame)
		Settings.Read()
		local gap = Tokens.Size("gapMedium")
		local previous, rule = nil, {}
		for _, key in ipairs(Settings.RULES) do rule[key] = Rules.Sample(key) end
		for _, group in ipairs(Settings.GROUPS) do
			local row = frame.rows[group]
			row:Apply(group == "bars" and Settings.current.bars or Fitted(frame, Settings.current[group], group))
			row.holder:ClearAllPoints()
			if previous then
				Widgets.Point(row.holder, "TOP", previous.holder, "BOTTOM", 0, -gap)
			else
				Widgets.Point(row.holder, "TOP", frame, "TOP", 0, -Tokens.Size("gapHuge"))
			end
			previous = row
		end
		for _, group in ipairs(Settings.GROUPS) do
			if group == "bars" then
				FillBars(frame.rows.bars, rule)
			else
				Fill(frame.rows[group], group, Samples(frame, group), rule)
			end
		end
		FocusSample(frame)
	end

	build = function(parent)
		Settings.Read()
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetAllPoints(parent)
		frame.pane = parent
		frame.rows = {}
		for _, group in ipairs(Settings.GROUPS) do
			if group == "bars" then
				frame.rows[group] = BarRow.New(frame, Settings.current.bars)
			else
				frame.rows[group] = Row.New(frame, group, Settings.current[group])
			end
		end
		frame.Refresh = Refresh
		Refresh(frame)
		return frame
	end
	return build(...)
end
