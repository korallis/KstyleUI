-- Preview.lua: the settings window's live preview: sample essential, utility and buff rows and buff bars drawn with the current settings (with sample keybinds and a press on the first cooldown, a sample potion and trinket while an item option is changed, a sample cooldown bar with its charge sections, eased in while it is smoothed, the custom bar group under its name with the samples it takes (or, with a shift, empty and covered by the bars below it), a swing sweep at the start of the late-swing window, and a sample enemy plate with the focus interrupt on its chosen side and the reminder under it while either is on), cooldown samples passed to the other row past its grid, and every sample treated as listed in each spell rule that is not empty, with the list's first colour, name or threshold.
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
	local PLATE_WIDTH, PLATE_FILL = 156.75, 0.7
	local focusStyle = setmetatable({ group = "utility" }, Row)
	local OTHER = { essential = "utility", utility = "essential" }
	local SAMPLE_PROC = { essential = { [4] = true } }
	local SAMPLE_BARS = {
		{ icon = 132208, name = L["Rapid Fire"], duration = 15, left = 9, count = 3 },
		{ icon = 136076, name = L["Aspect of the Hawk"], duration = 1800, left = 1260 },
	}
	local SAMPLE_BAR_FILL = 0.6
	local SAMPLE_KEYS = { "1", "2", "3", "Q", "E", "R" }
	local SAMPLE_RANK = 3
	local SAMPLE_COOLDOWN_BAR = { icon = 132111, name = L["Multi-Shot"], duration = 10, left = 4, charges = 2 }
	local ORDER = { "essential", "utility", "buffs", "custom", "bars" }

	local function Samples(frame, group)
		local list, other = {}, OTHER[group]
		for i = 1, #SAMPLE_ICONS[group] do list[i] = { group, i } end
		local cfg = other and frame.rows[other].cfg
		if cfg and cfg.overflow then
			for i = Grid.Capacity(cfg) + 1, #SAMPLE_ICONS[other] do list[#list + 1] = { other, i } end
		end
		local own = frame.rows[group].cfg
		if other and (own.trinkets or own.hideMissing or own.itemQuality or not own.itemCount) then list[#list + 1] = { "items", 1 } end
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
				row:Swing(icon, rule.swing and now - SAMPLE_SWING + current.swingWindow, SAMPLE_SWING)
				if charges and charges > 0 and (rule.chargeSwipe or rule.chargeTimer) then
					icon:ChargeCooldown():SetCooldown(now - 4, 10)
					row:Recharge(icon)
				elseif icon.chargeCooldown then
					icon.chargeCooldown:Clear()
				end
				row:Visible(icon)
				icon:SetHotkey(cfg.keybind and SAMPLE_KEYS[i] or nil)
				Style.Rank(icon, cfg.itemQuality and from == "items" and SAMPLE_RANK or nil)
				if cfg.pressMirror and i == 1 then
					icon:AnimatePress(true)
					icon:AnimatePress(false)
				end
			end
		end
		row:Settle()
	end

	local function FocusSample(frame)
		local current, plate = Settings.current, frame.plate
		local spell, note = current.focusSpell ~= "", current.focusReminder
		if not (plate or spell or note) then return end
		if not plate then
			plate = Widgets.StatusBar(frame, { color = "hostile", width = PLATE_WIDTH, height = Tokens.Size("barHeight"), min = 0, max = 1, value = PLATE_FILL })
			plate.note = Widgets.Text(plate, "caps", "hostile")
			Widgets.SetText(plate.note, L["Focus"])
			Widgets.Point(plate.note, "TOP", plate, "BOTTOM", 0, -Tokens.Size("actionGap"))
			frame.plate, frame.focus = plate, Style.Decorate(Widgets.Slot(plate, { size = current.utility.size }), "utility")
		end
		local icon, side, gap = frame.focus, ns.Focus.SIDES[current.focusSide], Tokens.Size("actionGap")
		plate:SetShown(spell or note)
		plate.note:SetShown(note)
		icon:SetShown(spell)
		plate:ClearAllPoints()
		Widgets.Point(plate, "TOP", frame.rows.bars.holder, "BOTTOM", 0, -Tokens.Size("gapMedium") - current.utility.size)
		if not spell then return end
		focusStyle.cfg = current.utility
		focusStyle:StyleIcon(icon)
		local id = ns.Focus.Spell(current.focusSpell)
		local ok, texture = pcall(C_Spell.GetSpellTexture, id)
		icon:SetIcon(id and ok and not issecretvalue(texture) and texture or ns.Data.UNKNOWN_ICON)
		icon:ClearAllPoints()
		Widgets.Point(icon, side[1], plate, side[2], side[3] * gap, side[4] * gap)
	end

	local function FillBars(row, rule, samples)
		local count = row:SetCount(#samples)
		local now = GetTime and GetTime() or 0
		for i = 1, count do
			local bar, sample = row.bars[i], samples[i]
			local sections = sample.charges and row.cfg.hashLines and sample.charges or nil
			row:Hash(bar, sections)
			row:Recharge(bar, sections and true)
			bar.icon:SetTexture(sample.icon)
			Widgets.SetText(bar.name, type(rule.names) == "string" and rule.names or sample.name)
			bar.status:SetMinMaxValues(0, 1)
			bar.status:SetValue(row.cfg.fillUp and 1 - SAMPLE_BAR_FILL or SAMPLE_BAR_FILL)
			bar.timer:SetCooldown(now - (sample.duration - sample.left), sample.duration)
			Widgets.SetText(bar.count, rule.count and sample.count or nil)
			row:ShowCount(bar, rule)
			bar:SetAlpha((rule.hide or rule.missing) and not sample.charges and 0 or 1)
			if sections then
				bar.status:SetMinMaxValues(0, sections)
				bar.status:SetValue(1)
				bar.recharge:SetMinMaxValues(0, 1)
				bar.recharge:SetValue(SAMPLE_BAR_FILL)
			end
			if sample.charges and row.cfg.cdSmooth and Enum.StatusBarInterpolation then
				local fill = sections and bar.recharge or bar.status
				local value = fill:GetValue()
				fill:SetValue(0)
				fill:SetValue(value, Enum.StatusBarInterpolation.ExponentialEaseOut)
			end
		end
	end

	local function Fitted(frame, cfg, group)
		local width = frame.pane:GetWidth()
		local free = cfg.vertical and Settings.Free(group)
		if not free and (issecretvalue(width) or type(width) ~= "number" or width <= 0) then
			return cfg
		end
		local out = {}
		for key, value in pairs(cfg) do
			out[key] = value
		end
		out.columns = free and math.max(1, math.min(cfg.columns, #SAMPLE_ICONS[group])) or cfg.columns
		while not free and out.columns > 1 and Grid.Size(out) > width do
			out.columns = out.columns - 1
		end
		return out.columns == cfg.columns and cfg or out
	end

	local function Refresh(frame)
		Settings.Read()
		local gap, current = Tokens.Size("gapMedium"), Settings.current
		local cfg, caption = current.custom, frame.caption
		local previous, rule = nil, {}
		for _, key in ipairs(Settings.RULES) do rule[key] = Rules.Sample(key) end
		local using = current.rules.group ~= "" or cfg.autoAdd
		local listed, samples, main, mine = using and cfg.shift == "", rule.cdBars and { SAMPLE_BARS[1], SAMPLE_COOLDOWN_BAR } or SAMPLE_BARS, {}, {}
		for _, sample in ipairs(samples) do
			local into = listed and (rule.group or cfg.autoAdd and not sample.charges) and mine or main
			into[#into + 1] = sample
		end
		Widgets.SetText(caption, cfg.name ~= "" and cfg.name or L["Custom bars"])
		caption:SetShown(using)
		frame.rows.custom.holder:SetShown(using)
		for _, group in ipairs(ORDER) do
			local row = frame.rows[group]
			row:Apply(group == "bars" and current.bars or group == "custom" and cfg or Fitted(frame, current[group], group))
			row.holder:ClearAllPoints()
			if group == "custom" and not using then
				row:SetCount(0)
			else
				local y = -gap
				if group == "custom" then y = y - Widgets.LineHeight(caption) - gap end
				if group == "bars" and using and not listed then y = y + (cfg.shift == "up" and 1 or -1) * (cfg.height + cfg.spacing + cfg.shiftY) end
				if previous then
					Widgets.Point(row.holder, "TOP", previous.holder, "BOTTOM", 0, y)
				else
					Widgets.Point(row.holder, "TOP", frame, "TOP", 0, -Tokens.Size("gapHuge"))
				end
				previous = row
			end
		end
		Widgets.Point(caption, "BOTTOMLEFT", frame.rows.custom.holder, "TOPLEFT", 0, gap)
		for _, group in ipairs(Settings.GROUPS) do
			if group ~= "bars" then Fill(frame.rows[group], group, Samples(frame, group), rule) end
		end
		FillBars(frame.rows.bars, rule, main)
		if using then FillBars(frame.rows.custom, rule, mine) end
		FocusSample(frame)
	end

	build = function(parent)
		Settings.Read()
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetAllPoints(parent)
		frame.pane = parent
		frame.rows = {}
		for _, group in ipairs(ORDER) do
			if group == "bars" or group == "custom" then
				frame.rows[group] = BarRow.New(frame, Settings.current[group])
			else
				frame.rows[group] = Row.New(frame, group, Settings.current[group])
			end
		end
		frame.caption = Widgets.Text(frame, "caps", "text")
		frame.Refresh = Refresh
		Refresh(frame)
		return frame
	end
	return build(...)
end
