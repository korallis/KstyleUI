-- Preview.lua: the settings window's live preview of the meters: a sample damage meter, threat meter and swing bar drawn with the current settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local L = K.L
local Logic = ns.Logic

local Preview = {}
ns.Preview = Preview

local build
function Preview.Build(...)
	if build then return build(...) end
	local FALLBACK_WIDTH, FALLBACK_HEIGHT = 420, 220
	local SWING_HEIGHT = 8
	local STACK_BELOW = 240
	local SWING_FILL = 0.6
	local PERCENT_MAX = 100
	local DAMAGE_SAMPLE_RATE = 38.4
	local SPELLS = { { 403, 412 }, { 8050, 188 }, { 8042, 134 }, { 6603, 107 }, { 3599, 54 } }
	local SAMPLE = {
		{ class = "WARRIOR", damage = 28400, threat = 100, raw = 3240000 },
		{ class = "MAGE", damage = 24700, threat = 88, raw = 2851000, player = true },
		{ class = "PRIEST", damage = 20100, threat = 61, raw = 1977000 },
		{ class = "ROGUE", damage = 17600, threat = 42, raw = 1361000 },
		{ class = "HUNTER", damage = 14200, threat = 23, raw = 745000 },
	}

	local function Name(classFile)
		local names = LOCALIZED_CLASS_NAMES_MALE
		return type(names) == "table" and names[classFile] or classFile
	end

	local function Columns(section)
		return function()
			if section == "threat" then
				local value = ns.Get("threat.value")
				return { value = value ~= "percent", percent = value ~= "threat" }
			end
			return { value = true, percent = ns.Get("damage.percent") }
		end
	end

	local function SpellLabel(id)
		local spells = C_Spell
		local name = type(spells) == "table" and type(spells.GetSpellName) == "function" and spells.GetSpellName(id)
		if type(name) == "string" and name ~= "" and not Logic.IsSecret(name) then
			return name
		end
		return string.format("%s %d", L["Spell"], id)
	end

	local function SpellIcon(id)
		local spells = C_Spell
		if type(spells) == "table" and type(spells.GetSpellTexture) == "function" then
			return spells.GetSpellTexture(id)
		end
		return nil
	end

	local function Icons()
		return ns.Get("damage.icons") == true
	end

	local function FillDamage(list)
		local total = 0
		for _, spell in ipairs(SPELLS) do
			total = total + spell[2]
		end
		local count = math.min(#SPELLS, list.capacity or 0)
		local percent = ns.Get("damage.percent")
		for i = 1, count do
			local id, amount = SPELLS[i][1], SPELLS[i][2]
			list:SetRow(i, SpellLabel(id), Theme.Class(), "friendly", amount, SPELLS[1][2], Logic.Abbreviate(amount),
				percent and Logic.FormatPercent(Logic.Percent(amount, total)) or "", nil, Logic.SchoolToken(id))
			list:SetRowIcon(i, SpellIcon(id))
		end
		list:Finish(count)
		local info = ns.METER_TYPES[1]
		for _, entry in ipairs(ns.METER_TYPES) do
			if entry.value == ns.Get("damage.meter") then
				info = entry
			end
		end
		list:SetTitle(info.cap or info.label)
		list:SetColumn(info.rate and Logic.FormatRate(DAMAGE_SAMPLE_RATE, info.rate) or "")
	end

	local function FillThreat(list)
		local count = math.min(#SAMPLE, list.capacity or 0)
		local rows = {}
		for i = 1, count do
			local sample = SAMPLE[i]
			list:SetRow(i, Name(sample.class), sample.class, "friendly", sample.threat, PERCENT_MAX,
				Logic.ThreatText(sample.raw), Logic.FormatPercent(sample.threat))
			if ns.Get("nameplateRows") then ns.SetClassIcon(list, i, sample.class) end
			list:SetMarker(i, sample.player)
			rows[i] = { isPlayer = sample.player == true, tanking = i == 1, scaled = sample.threat }
		end
		list:Finish(count)
		list:SetTitle(L["Threat"])
		local watched = Logic.ThreatWatch(rows, count)
		list:SetColumn(watched and Logic.FormatPercent(watched.scaled) or "")
		local level = Logic.NO_WARNING
		if ns.Get("threat.warnings") then
			level = Logic.ThreatWarning(rows, count, ns.Get("threat.warnAt"), ns.Get("threat.dangerAt"))
		end
		list:SetWarning(level)
	end

	local function FillHistory(list)
		local count = math.min(#SPELLS, ns.Get("history.barCount"), list.capacity or 0)
		for i = 1, count do
			local id = SPELLS[#SPELLS + 1 - i][1]
			list:SetRow(i, SpellLabel(id), Theme.Class(), "friendly", 1, 1, "", "")
			list:SetRowIcon(i, SpellIcon(id))
		end
		list:Finish(count)
	end

	local function Lists(frame)
		local lists = { frame.damage, frame.threat }
		local on = ns.Get("history.bars")
		if on and not frame.history then
			frame.history = ns.BarList.New(frame, "history", { width = FALLBACK_WIDTH / 2, height = FALLBACK_HEIGHT, block = true,
				columns = function() return { value = false, percent = false } end, icons = function() return true end })
			frame.history:SetTitle(L["Spell history"])
		end
		if frame.history then frame.history.holder:SetShown(on) end
		if on then lists[3] = frame.history end
		return lists
	end

	local function Band(frame, width)
		local icons, timer = ns.Get("history.icons"), ns.Get("timer.shown")
		local size, gap = ns.Get("history.size"), ns.Get("history.gap")
		local count = icons and math.min(ns.Get("history.count"), math.floor((width - 80 + gap) / (size + gap))) or 0
		frame.icons = frame.icons or {}
		for i = 1, math.max(count, #frame.icons) do
			local icon = frame.icons[i]
			if i <= count and not icon then
				icon = frame:CreateTexture(nil, "ARTWORK")
				frame.icons[i] = icon
			end
			if icon then
				local id = SPELLS[(i - 1) % #SPELLS + 1][1]
				local slot = ns.Get("history.grow") == "LEFT" and count - i or i - 1
				icon:SetTexture(SpellIcon(id))
				icon:SetShown(i <= count)
				icon:ClearAllPoints()
				Widgets.Size(icon, size, size)
				Widgets.Point(icon, "BOTTOMLEFT", frame, "BOTTOMLEFT", slot * (size + gap), SWING_HEIGHT + Tokens.Size("gapMedium"))
			end
		end
		if timer and not frame.timer then frame.timer = Widgets.FontString(frame, "OVERLAY") end
		local text = frame.timer
		local height = icons and size or 0
		if text then
			text:SetShown(timer)
			ns.ApplyFont(text, "timer", nil, "timer")
			text:SetJustifyH(ns.Get("timer.align"))
			text:SetText(ns.Timer.Format(84.3, ns.Get("timer.decimal")))
			local c = ns.Get("timer.color")
			local grey = ns.Get("timer.ooc") and ns.Get("timer.desat") and c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			text:SetTextColor(grey or c.r, grey or c.g, grey or c.b)
			local tall = ns.Get("timer.fontSize") * Theme.FontScale() + 4
			text:ClearAllPoints()
			Widgets.Size(text, 80, tall)
			Widgets.Point(text, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, SWING_HEIGHT + Tokens.Size("gapMedium"))
			if timer then height = math.max(height, tall) end
		end
		return height
	end

	local function Arrange(frame)
		local parent = frame:GetParent()
		local width = Logic.Plain(parent:GetWidth()) or 0
		local height = Logic.Plain(parent:GetHeight()) or 0
		if width <= 0 then
			width = FALLBACK_WIDTH
		end
		if height <= 0 then
			height = FALLBACK_HEIGHT
		end
		local gap = Widgets.Snap(frame, Tokens.Size("gapMedium"))
		local lists, band = Lists(frame), Band(frame, width)
		local n = #lists
		local stacked = math.floor((width - gap * (n - 1)) / n) < STACK_BELOW
		local listWidth = stacked and width or math.floor((width - gap * (n - 1)) / n)
		local listHeight = height - SWING_HEIGHT - gap - (band > 0 and band + gap or 0)
		if stacked then
			listHeight = math.floor((listHeight - gap * (n - 1)) / n)
		end
		for i, list in ipairs(lists) do
			list.width, list.height = listWidth, listHeight
			Widgets.Size(list.holder, listWidth, listHeight)
			list.holder:ClearAllPoints()
			if i == 1 then
				Widgets.Point(list.holder, "TOPLEFT", frame, "TOPLEFT")
			elseif stacked then
				Widgets.Point(list.holder, "TOPLEFT", lists[i - 1].holder, "BOTTOMLEFT", 0, -gap)
			elseif i == n then
				Widgets.Point(list.holder, "TOPRIGHT", frame, "TOPRIGHT")
			else
				Widgets.Point(list.holder, "TOPLEFT", lists[i - 1].holder, "TOPRIGHT", gap, 0)
			end
		end
		local swing = frame.swing
		swing.opts.width, swing.opts.height = width, SWING_HEIGHT
		swing:Restyle()
		swing:ClearAllPoints()
		Widgets.Point(swing, "BOTTOMLEFT", frame, "BOTTOMLEFT")
	end

	local function StyleSwing(swing)
		swing:SetBarTexture(ns.Get("swing.texture"))
		swing:SetReverseFill(ns.Get("swing.reverse"))
		swing:SetBarColor(ns.BarColor("swing", Theme.Class(), "friendly"))
		swing:SetShown(ns.Get("swing.shown"))
	end

	local function Refresh(frame)
		Arrange(frame)
		frame.damage:Restyle()
		frame.threat:Restyle()
		frame.damage.holder:SetShown(ns.MeterShown("damage"))
		frame.threat.holder:SetShown(ns.MeterShown("threat"))
		FillDamage(frame.damage)
		FillThreat(frame.threat)
		if frame.history and frame.history.holder:IsShown() then
			frame.history:Restyle()
			FillHistory(frame.history)
		end
		StyleSwing(frame.swing)
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		Widgets.Fill(frame, parent, 0, 0, 0, 0)
		frame.damage = ns.BarList.New(frame, "damage", { width = FALLBACK_WIDTH / 2, height = FALLBACK_HEIGHT, columns = Columns("damage"), block = true, icons = Icons, onReset = function() end })
		frame.threat = ns.BarList.New(frame, "threat", { width = FALLBACK_WIDTH / 2, height = FALLBACK_HEIGHT, columns = Columns("threat"), icons = Icons })
		frame.swing = Widgets.StatusBar(frame, {
			texture = ns.Get("swing.texture"), background = "track", border = true, min = 0, max = 1, value = SWING_FILL,
			width = FALLBACK_WIDTH, height = SWING_HEIGHT,
		})
		frame.Refresh = Refresh
		frame:HookScript("OnSizeChanged", Refresh)
		Refresh(frame)
		return frame
	end
	return build(...)
end
