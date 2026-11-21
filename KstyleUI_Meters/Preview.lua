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
	local CASTS = {}
	for i = 1, 10 do CASTS[i] = SPELLS[(i - 1) % #SPELLS + 1][1] end
	local SAMPLE = {
		{ class = "WARRIOR", damage = 28400, threat = 100, raw = 3240000, died = 67 },
		{ class = "MAGE", damage = 24700, threat = 88, raw = 2851000, player = true, died = 102 },
		{ class = "PRIEST", damage = 20100, threat = 61, raw = 1977000, died = 131 },
		{ class = "ROGUE", damage = 17600, threat = 42, raw = 1361000, died = 158 },
		{ class = "HUNTER", damage = 14200, threat = 23, raw = 745000, died = 204 },
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

	local function Units()
		return ns.Get("damage.englishUnits") and Logic.Abbreviate or Logic.GameUnits
	end

	local function Rate(list, key)
		local info = ns.MeterInfo(key)
		list:SetTitle(info.cap or info.label)
		return info.rate and Logic.FormatRate(DAMAGE_SAMPLE_RATE, info.rate, Units()) or ""
	end

	local function FillDamage(list)
		local total = 0
		for _, spell in ipairs(SPELLS) do
			total = total + spell[2]
		end
		local count = math.min(#SPELLS, list.capacity or 0)
		local percent, units = ns.Get("damage.percent"), Units()
		for i = 1, count do
			local id, amount = SPELLS[i][1], SPELLS[i][2]
			list:SetRow(i, SpellLabel(id), Theme.Class(), "friendly", amount, SPELLS[1][2], units(amount),
				percent and Logic.FormatPercent(Logic.Percent(amount, total)) or "", nil, Logic.SchoolToken(id))
			list:SetRowIcon(i, SpellIcon(id))
		end
		list:Finish(count)
		list:SetColumn(Rate(list, "damage.meter"))
	end

	local function FillSecond(list)
		local count, total = math.min(#SAMPLE, list.capacity or 0), 0
		for _, sample in ipairs(SAMPLE) do
			total = total + sample.damage
		end
		local percent, units, deaths = ns.Get("damage.percent"), Units(), ns.MeterInfo("damage2.meter").deaths
		for i = 1, count do
			local sample = SAMPLE[i]
			if deaths then
				list:SetRow(i, Name(sample.class), sample.class, "friendly", 1, 1, ns.DeathText(sample.died), "")
			else
				list:SetRow(i, Name(sample.class), sample.class, "friendly", sample.damage, SAMPLE[1].damage, units(sample.damage),
					percent and Logic.FormatPercent(Logic.Percent(sample.damage, total)) or "")
			end
			ns.SetClassIcon(list, i, sample.class)
			list:SetMarker(i, sample.player)
		end
		list:Finish(count)
		list:SetRest(Rate(list, "damage2.meter"))
		ns.FightSwitch(list, "damage2.session")
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

	local function Nothing() end

	local function Lists(frame)
		local second = ns.Get("damage2.shown")
		if second and not frame.second then
			frame.second = ns.BarList.New(frame, "damage", { width = FALLBACK_WIDTH / 2, height = FALLBACK_HEIGHT, columns = Columns("damage"), block = true, icons = Icons, onReset = Nothing, onSwitch = Nothing })
		end
		if frame.second then frame.second.holder:SetShown(second) end
		local lists = second and { frame.damage, frame.second, frame.threat } or { frame.damage, frame.threat }
		local on = ns.Get("history.bars") and not ns.History.Hidden()
		if on and not frame.history then
			frame.history = ns.BarList.New(frame, "history", { width = FALLBACK_WIDTH / 2, height = FALLBACK_HEIGHT, block = true,
				columns = function() return { value = false, percent = false } end, icons = function() return true end })
			frame.history:SetTitle(L["Spell history"])
		end
		if frame.history then frame.history.holder:SetShown(on) end
		if on then lists[#lists + 1] = frame.history end
		return lists
	end

	local function Band(frame, width, height)
		local History, timer, grow = ns.History, ns.Get("timer.shown"), ns.Get("history.grow")
		local icons, upright = ns.Get("history.icons") and not History.Hidden(), grow == "UP" or grow == "DOWN"
		local size, gap, air = ns.Get("history.size"), ns.Get("history.gap"), Tokens.Size("gapMedium")
		if timer and not frame.timer then frame.timer = Widgets.FontString(frame, "OVERLAY") end
		local text, band, side = frame.timer, 0, 0
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
			Widgets.Point(text, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, SWING_HEIGHT + air)
			if timer then band = tall end
		end
		if icons and not frame.strip then frame.strip = History.Strip(frame, {}) end
		local strip = frame.strip
		if strip then strip.holder:SetShown(icons) end
		if icons then
			local room = upright and height - SWING_HEIGHT - air - (band > 0 and band + air or 0) or width - 80
			History.StyleStrip(strip, math.max(1, math.min(ns.Get("history.count"), math.floor((room + gap) / (size + gap)))))
			History.PaintStrip(strip, CASTS)
			if strip.look ~= ns.Get("history.anim") .. grow then
				strip.look = ns.Get("history.anim") .. grow
				History.Slide(strip)
			end
			strip.holder:ClearAllPoints()
			if upright then
				Widgets.Point(strip.holder, "TOPRIGHT", frame, "TOPRIGHT")
				side = size + air
			else
				Widgets.Point(strip.holder, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, SWING_HEIGHT + air)
				band = math.max(band, size)
			end
		end
		return band, side
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
		local lists = Lists(frame)
		local band, side = Band(frame, width, height)
		local n, room = #lists, width - side
		local stacked = math.floor((room - gap * (n - 1)) / n) < STACK_BELOW
		local listWidth = stacked and room or math.floor((room - gap * (n - 1)) / n)
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
				Widgets.Point(list.holder, "TOPRIGHT", frame, "TOPRIGHT", -side, 0)
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
		if frame.second and frame.second.holder:IsShown() then
			frame.second:Restyle()
			FillSecond(frame.second)
		end
		if frame.history and frame.history.holder:IsShown() then
			frame.history:Restyle()
			FillHistory(frame.history)
		end
		StyleSwing(frame.swing)
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		Widgets.Fill(frame, parent, 0, 0, 0, 0)
		frame.damage = ns.BarList.New(frame, "damage", { width = FALLBACK_WIDTH / 2, height = FALLBACK_HEIGHT, columns = Columns("damage"), block = true, icons = Icons, onReset = Nothing })
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
