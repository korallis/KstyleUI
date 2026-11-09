-- Preview.lua: the settings window's live preview: the frame being customised, drawn with sample values at its current size and scaled to fill the pane, its sample auras a full grid with times, stacks and the +N chip the live row shows.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, L = K.Widgets, K.Tokens, K.Theme, K.L
local Settings, Style, Format, Geometry = ns.Settings, ns.Style, ns.Format, ns.Geometry

local Preview = {}
ns.Preview = Preview

local MARGIN = 8
local MIN_SCALE, MAX_SCALE = 0.5, 1.5
local INCOMING_SHARE = 0.08
local SKULL = 8
local CAST_GAP = 4
local CAST_SHARE = 0.6
local CAST_LEFT = 1.2
local CAST_ICON = 135846
local AURA_ICONS = { 135846, 136096, 135813, 136075 }
local AURA_TIMES = { "12s", "4s", "1m", "25s", "8s", "3m", "40s", "2m" }
local AURA_STACKS = { [2] = "3", [5] = "2" }
local AURA_MORE = 3
local CHIP_SHARE, CHIP_MIN, CHIP_LEVEL = 0.42, 8, 4
local THREAT_TANKING = 3

local SAMPLES = {
	player = { name = L["Valerin"], level = 60, health = 3120, healthMax = 3980, power = 3120, powerMax = 3980, reaction = 5, own = true, leader = true, resting = true, caption = L["Battle Stance"] },
	target = { name = L["Frost Howler"], level = 61, classification = "elite", creature = L["Beast"], health = 2240, healthMax = 4020, power = 40, powerMax = 100, reaction = 2, marker = true, threat = true },
	targettarget = { name = L["Valerin"], level = 60, health = 3120, healthMax = 3980, power = 3120, powerMax = 3980, reaction = 5, own = true },
	focus = { name = L["Elunara"], level = 60, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, reaction = 2 },
	focustarget = { name = L["Krazhk"], level = 60, health = 3300, healthMax = 4000, power = 1800, powerMax = 3600, reaction = 2 },
	pet = { name = L["Wolf"], level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 },
	boss = { name = L["Magmatus"], level = -1, classification = "worldboss", health = 72000, healthMax = 100000, power = 0, powerMax = 100, reaction = 2, marker = true, threat = true },
}

local function EditKind()
	local kind = Settings.Module().edit
	if Settings.defaults[kind] then
		return kind
	end
	return "player"
end

local function SampleColor(s, sample, source, custom)
	if source == "custom" then
		return custom.r, custom.g, custom.b
	end
	if source == "power" then
		return ns.Unit.PowerTypeColor(sample.own and "player" or nil)
	end
	if source == "class" and sample.own then
		return Theme.ClassColor(Theme.Class())
	end
	return ns.Unit.ReactionColor(sample.reaction)
end

local function GlowAlpha(share)
	local points = ns.Unit.GLOW_POINTS
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if share <= b[1] then
			return a[2] + (b[2] - a[2]) * (share - a[1]) / (b[1] - a[1])
		end
	end
	return points[#points][2]
end

local function PaintLumen(view, kind, sample)
	local s, form = view.s, view.form
	local share = sample.healthMax > 0 and sample.health / sample.healthMax or 0
	if form == "vitals" then
		local split = s.healthText == "both" or s.healthText == "currentMax"
		Format.Sample(view.healthText, split and "current" or s.healthText, sample.health, sample.healthMax)
		if split then
			Format.SampleMax(view.healthSub, sample.healthMax)
		else
			view.healthSub:SetText("")
		end
		view.caption:SetText(sample.caption or "")
		view.levelText:SetText(sample.level)
		if view.geometry.portrait then
			local r, g, b = Tokens.Color("healthHostile")
			view.ringGlow:SetVertexColor(r, g, b, GlowAlpha(share))
			view.ringGlow:Show()
		end
	elseif form == "card" then
		Format.Sample(view.healthText, Format.Main(s.healthText), sample.health, sample.healthMax)
		ns.Unit.LevelText(view.caption, sample.level, sample.classification, nil, true)
		view.capLabel:SetText(Settings.CAP_LABELS[kind] or "")
	elseif form == "sigil" then
		ns.Unit.LevelText(view.caption, sample.level, sample.classification, sample.creature, false)
	else
		Format.Sample(view.healthText, s.healthText, sample.health, sample.healthMax)
	end
end

local function Paint(view, kind)
	local s, sample = view.s, SAMPLES[kind]
	view.health:SetBarRange(0, sample.healthMax)
	view.health:SetValue(sample.health)
	view.health:SetBarColor(SampleColor(s, sample, s.healthColor, s.healthCustom))
	Style.HealthTint(view, SampleColor(s, sample, s.healthColor, s.healthCustom))
	local split = view.geometry and view.geometry.healthSub
	if view.form == "plate" then
		Format.Sample(view.healthText, split and Format.Main(s.healthText) or s.healthText, sample.health, sample.healthMax)
		Format.SampleDetail(view.healthSub, split and s.healthText or "none", sample.health, sample.healthMax)
	end
	view.power:SetBarRange(0, sample.powerMax)
	view.power:SetValue(sample.power)
	view.power:SetBarColor(SampleColor(s, sample, s.powerColor, s.powerCustom))
	Format.Sample(view.powerText, s.powerText, sample.power, sample.powerMax)
	if s.healPrediction then
		view.incoming:SetBarRange(0, sample.healthMax)
		view.incoming:SetValue(sample.healthMax * INCOMING_SHARE)
		view.incoming:Show()
	else
		view.incoming:Hide()
	end
	view.absorb:Hide()
	ns.Unit.SetName(view, sample.name)
	view.levelText:SetText(sample.level > 0 and sample.level or "??")
	view.levelText:SetTextColor(Tokens.Color("textEmphasis"))
	if view.form ~= "plate" then
		PaintLumen(view, kind, sample)
	end
	if s.portraitStyle == "class" and GetClassAtlas and Theme.Class() then
		view.portrait:SetAtlas(GetClassAtlas(Theme.Class()))
	elseif SetPortraitTexture then
		view.portrait:SetTexCoord(0, 1, 0, 1)
		SetPortraitTexture(view.portrait, "player", s.portraitShape ~= "round")
	end
end

local function PaintIndicators(view, s, sample)
	local icons = view.icons
	for _, key in ipairs(ns.Indicators.SLOTS) do
		icons[key]:SetAlpha(1)
		icons[key]:SetShown(s[key] == true and sample[key] == true)
	end
	if s.raidMarker and sample.marker then
		view.marker:SetSpriteSheetCell(SKULL, 4, 4)
		view.marker:Show()
	else
		view.marker:Hide()
	end
	ns.Indicators.Fit(view)
	local r, g, b
	if s.threat and sample.threat then
		r, g, b = K.Theme.ThreatColor(THREAT_TANKING)
	end
	if r then
		K.Widgets.ColorSlice(view.glow, r, g, b, 0.9)
		view.glowFrame:Show()
	else
		view.glowFrame:Hide()
	end
end

local function CastHeight(kind)
	local key = Settings.CAST_ELEMENTS[kind]
	if not key then
		return Settings.Value(kind, "castbarHeight")
	end
	local saved = K.Layout and K.Layout.Get and K.Layout.Get(key)
	if saved and type(saved.height) == "number" then
		return saved.height
	end
	return K.Setup.Layouts.Element(key).height
end

local function PaintCast(frame, view, kind, height)
	local cb = frame.casts[kind]
	if not (Settings.CASTBAR[kind] and Settings.Value(kind, "castbar")) then
		if cb then
			cb.frame:Hide()
		end
		return 0
	end
	if not cb then
		cb = ns.CastBars.NewBar(frame.holders[kind], kind, true)
		frame.casts[kind] = cb
	end
	local g = view.geometry
	local castH = CastHeight(kind)
	local x, y, w, extra = g.panel.x, height + CAST_GAP, g.panel.w, castH + CAST_GAP
	if g.form ~= "plate" then
		if not g.cast then
			cb.frame:Hide()
			return 0
		end
		x, y, w, castH, extra = g.cast.x, g.cast.y, g.cast.w, g.cast.h, 0
	end
	cb.frame:ClearAllPoints()
	cb.frame:SetPoint("TOPLEFT", frame.holders[kind], "TOPLEFT", x, -y)
	cb.frame:SetSize(w, castH)
	cb.sampleReaction = SAMPLES[kind].reaction
	ns.CastBars.Restyle(cb)
	ns.CastBars.Layout(cb, w, castH)
	cb.bar:SetMinMaxValues(0, 1)
	cb.bar:SetValue(CAST_SHARE)
	ns.CastBars.SetName(cb, L["Frostbolt"])
	cb.timer:SetFormattedText("%.1fs", CAST_LEFT)
	cb.icon:SetTexture(CAST_ICON)
	cb.frame:SetAlpha(1)
	cb.frame:Show()
	return extra
end

local function Chip(frame, kind, host)
	local chip = frame.auraChips[kind]
	if not chip then
		chip = CreateFrame("Frame", nil, host)
		chip.chrome = Widgets.IconChrome(chip)
		chip.text = Widgets.FontString(chip, "OVERLAY")
		chip.text:SetAllPoints(chip)
		chip.text:SetJustifyH("CENTER")
		chip.text:SetJustifyV("MIDDLE")
		frame.auraChips[kind] = chip
	end
	return chip
end

local function PaintChip(frame, kind, host, last, size, room)
	local chip = Chip(frame, kind, host)
	chip:ClearAllPoints()
	chip:SetPoint("TOPLEFT", last.skin, "TOPLEFT", 0, 0)
	chip:SetSize(size, size + room)
	chip:SetFrameLevel(last.skin:GetFrameLevel() + CHIP_LEVEL)
	chip.chrome:Restyle()
	local r, g, b = Tokens.Color("buttonFill")
	chip.chrome:SetFillRGBA(r, g, b, 1)
	chip.chrome:SetRimAccent(Settings.Accent())
	chip.text:SetFont(Tokens.Font("number"), math.max(CHIP_MIN, math.floor(size * CHIP_SHARE + 0.5)), "")
	pcall(chip.text.SetTextColor, chip.text, Tokens.Color("textEmphasis"))
	chip.text:SetText("+" .. AURA_MORE)
	last.timer:Hide()
	last.count:Hide()
	last.countBadge:Hide()
	chip:Show()
end

local function PlaceTile(skin, host, kind, i, count, size, spacing, pitch, corner, growth)
	local columns = Settings.Value(kind, "auraColumns")
	local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
	skin:ClearAllPoints()
	if Settings.Value(kind, "auraPosition") == "CENTER" then
		local inRow = math.min(columns, count - row * columns)
		local start = -(inRow * size + (inRow - 1) * spacing) / 2
		skin:SetPoint("TOPLEFT", host, "TOP", start + col * (size + spacing), -row * pitch)
	else
		local sx = growth[2] == "Left" and -1 or 1
		local sy = growth[3] == "Up" and 1 or -1
		skin:SetPoint(corner, host, corner, sx * col * (size + spacing), sy * row * pitch)
	end
	skin:SetSize(size, size)
end

local function PaintAuras(frame, view, kind)
	local tiles = frame.auraTiles[kind]
	if not tiles then
		tiles = {}
		frame.auraTiles[kind], frame.auraIcons[kind] = tiles, {}
	end
	local icons = frame.auraIcons[kind]
	local holder = frame.holders[kind]
	local host = frame.auraHosts[kind]
	if not host then
		host = CreateFrame("Frame", nil, holder)
		frame.auraHosts[kind] = host
	end
	local on = Settings.AURAS[kind] and Settings.Value(kind, "auras")
	local count = on and Settings.Value(kind, "auraColumns") * Settings.Value(kind, "auraRows") or 0
	local chip = frame.auraChips[kind]
	if count > 0 then
		local width, height, corner, _, growth = ns.Auras.Footprint(kind, host)
		local size = Widgets.Snap(host, Settings.Value(kind, "auraSize"))
		local spacing = Widgets.Snap(host, Settings.Value(kind, "auraSpacing"))
		local room = Widgets.Snap(host, ns.Auras.TimerRoom(kind))
		local timers = Settings.Value(kind, "auraTimer") == true
		local rows = Settings.Value(kind, "auraRows")
		host:SetSize(width, math.min(height, rows * (size + room) + (rows - 1) * spacing))
		ns.Auras.Anchor(host, holder, kind, view.geometry.panel.x)
		host:Show()
		for i = 1, count do
			local tile = tiles[i]
			if not tile then
				tile = ns.Auras.SampleTile(host)
				tiles[i], icons[i] = tile, tile.skin
			end
			tile.icon:SetTexture(AURA_ICONS[(i - 1) % #AURA_ICONS + 1])
			PlaceTile(tile.skin, host, kind, i, count, size, spacing, size + room + spacing, corner, growth)
			ns.Auras.LayoutTile(tile)
			ns.Auras.StyleSample(tile, kind)
			tile.timer:SetText(AURA_TIMES[(i - 1) % #AURA_TIMES + 1])
			tile.timer:SetShown(timers)
			local stack = AURA_STACKS[i]
			tile.count:SetText(stack or "")
			tile.count:SetShown(stack ~= nil)
			tile.countBadge:SetShown(stack ~= nil)
			tile.skin:Show()
		end
		PaintChip(frame, kind, host, tiles[count], size, timers and room or 0)
	else
		host:Hide()
		if chip then
			chip:Hide()
		end
	end
	for i = count + 1, #icons do
		icons[i]:Hide()
	end
	return count
end

local function Room(value)
	if type(value) ~= "number" or (issecretvalue and issecretvalue(value)) or value <= 2 * MARGIN then
		return nil
	end
	return value - 2 * MARGIN
end

local function Size(frame, kind)
	local key = Settings.ELEMENTS[kind]
	local element = K.Setup.Layouts.Element(key)
	local width, height = element.width, element.height
	local saved = K.Layout and K.Layout.Get and K.Layout.Get(key)
	if saved and type(saved.width) == "number" and type(saved.height) == "number" then
		width, height = saved.width, saved.height
	end
	if kind == "boss" then
		height = Geometry.Slots(Geometry.BOSS_COUNT, Geometry.BOSS_GAP, width, height)[1].h
	end
	local room = Room(frame:GetWidth())
	if room then
		width = math.min(width, room / MIN_SCALE)
	end
	return width, height
end

local OFFSET = {
	TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 },
}

local function Box(region, holder, width, height)
	if not region:IsShown() then
		return nil
	end
	local point, relative, relPoint, x, y = region:GetPoint(1)
	local from, to = OFFSET[point], OFFSET[relPoint]
	if relative ~= holder or not (from and to) then
		return nil
	end
	local w, h = region:GetSize()
	local left = to[1] * width + (x or 0) - from[1] * w
	local top = to[2] * height - (y or 0) - from[2] * h
	return left, top, left + w, top + h
end

local function Fit(frame, holder, kind, width, height)
	local l, t, r, b = 0, 0, width, height
	for _, region in ipairs({ frame.auraHosts[kind], frame.casts[kind] and frame.casts[kind].frame }) do
		local rl, rt, rr, rb = Box(region, holder, width, height)
		if rl then
			l, t, r, b = math.min(l, rl), math.min(t, rt), math.max(r, rr), math.max(b, rb)
		end
	end
	local scale = MAX_SCALE
	local roomW, roomH = Room(frame:GetWidth()), Room(frame:GetHeight())
	if roomW then
		scale = math.min(scale, roomW / (r - l))
	end
	if roomH then
		scale = math.min(scale, roomH / (b - t))
	end
	holder:SetScale(scale)
	holder:ClearAllPoints()
	holder:SetPoint("CENTER", frame, "CENTER", (width - l - r) / 2, (t + b - height) / 2)
end

local function Refresh(frame)
	local kind = EditKind()
	for other, holder in pairs(frame.holders) do
		holder:SetShown(other == kind)
	end
	local holder = frame.holders[kind]
	if not holder then
		holder = CreateFrame("Frame", nil, frame)
		frame.holders[kind] = holder
		frame.views[kind] = Style.New(holder, kind)
	end
	local view = frame.views[kind]
	local width, height = Size(frame, kind)
	view.s = Settings.Snapshot(kind)
	if Settings.CASTBAR[kind] and not Settings.CAST_ELEMENTS[kind] and view.s.castbar and view.s.form == "plate" then
		height = math.max(0, height - view.s.castbarHeight - CAST_GAP)
	end
	holder:SetSize(width, height)
	holder:Show()
	Style.Restyle(view, kind)
	Style.Layout(view, view.s, width, height)
	Paint(view, kind)
	PaintIndicators(view, view.s, SAMPLES[kind])
	PaintCast(frame, view, kind, height)
	frame.auraCount = PaintAuras(frame, view, kind)
	Fit(frame, holder, kind, width, height)
	frame.kind = kind
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.holders, frame.views, frame.casts, frame.auraIcons, frame.auraTiles, frame.auraHosts, frame.auraChips = {}, {}, {}, {}, {}, {}, {}
	frame.Refresh = Refresh
	frame:SetScript("OnSizeChanged", function(self)
		if self.kind then
			Refresh(self)
		end
	end)
	Refresh(frame)
	return frame
end
