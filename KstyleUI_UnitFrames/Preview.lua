-- Preview.lua: the settings window's live preview: the frame being customised, drawn with sample values at its current size.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, L = K.Widgets, K.Tokens, K.Theme, K.L
local Settings, Style, Format, Geometry = ns.Settings, ns.Style, ns.Format, ns.Geometry

local Preview = {}
ns.Preview = Preview

local MARGIN = 16
local INCOMING_SHARE = 0.08
local SKULL = 8
local CAST_GAP = 4
local CAST_SHARE = 0.6
local CAST_LEFT = 1.2
local CAST_ICON = 135846
local AURA_ICONS = { 135846, 136096, 135813, 136075 }
local THREAT_TANKING = 3

local SAMPLES = {
	player = { name = L["Valerin"], level = 60, health = 3120, healthMax = 3980, power = 3120, powerMax = 3980, reaction = 5, own = true, leader = true, resting = true },
	target = { name = L["Frost Howler"], level = 61, health = 2240, healthMax = 4020, power = 40, powerMax = 100, reaction = 2, marker = true, threat = true },
	targettarget = { name = L["Valerin"], level = 60, health = 3120, healthMax = 3980, power = 3120, powerMax = 3980, reaction = 5, own = true },
	focus = { name = L["Elunara"], level = 60, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, reaction = 2 },
	focustarget = { name = L["Krazhk"], level = 60, health = 3300, healthMax = 4000, power = 1800, powerMax = 3600, reaction = 2 },
	pet = { name = L["Wolf"], level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 },
	boss = { name = L["Magmatus"], level = -1, health = 72000, healthMax = 100000, power = 0, powerMax = 100, reaction = 2, marker = true, threat = true },
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

local function Paint(view, kind)
	local s, sample = view.s, SAMPLES[kind]
	view.health:SetBarRange(0, sample.healthMax)
	view.health:SetValue(sample.health)
	view.health:SetBarColor(SampleColor(s, sample, s.healthColor, s.healthCustom))
	Style.HealthTint(view, SampleColor(s, sample, s.healthColor, s.healthCustom))
	local split = view.geometry and view.geometry.healthSub
	Format.Sample(view.healthText, split and Format.Main(s.healthText) or s.healthText, sample.health, sample.healthMax)
	Format.SampleDetail(view.healthSub, split and s.healthText or "none", sample.health, sample.healthMax)
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
		cb = ns.CastBars.NewBar(frame.holders[kind], kind)
		frame.casts[kind] = cb
	end
	local g = view.geometry
	local castH = CastHeight(kind)
	cb.frame:ClearAllPoints()
	cb.frame:SetPoint("TOPLEFT", frame.holders[kind], "TOPLEFT", g.panel.x, -(height + CAST_GAP))
	cb.frame:SetSize(g.panel.w, castH)
	cb.sampleReaction = SAMPLES[kind].reaction
	ns.CastBars.Restyle(cb)
	ns.CastBars.Layout(cb, g.panel.w, castH)
	cb.bar:SetMinMaxValues(0, 1)
	cb.bar:SetValue(CAST_SHARE)
	ns.CastBars.SetName(cb, L["Frostbolt"])
	cb.timer:SetFormattedText("%.1fs", CAST_LEFT)
	cb.icon:SetTexture(CAST_ICON)
	cb.frame:SetAlpha(1)
	cb.frame:Show()
	return castH + CAST_GAP
end

local function PaintAuras(frame, view, kind)
	local icons, tiles = frame.auraIcons[kind], frame.auraTiles[kind]
	if not icons then
		icons, tiles = {}, {}
		frame.auraIcons[kind], frame.auraTiles[kind] = icons, tiles
	end
	local holder = frame.holders[kind]
	local host = frame.auraHosts[kind]
	if not host then
		host = CreateFrame("Frame", nil, holder)
		frame.auraHosts[kind] = host
	end
	local on = Settings.AURAS[kind] and Settings.Value(kind, "auras")
	local count = on and math.min(#AURA_ICONS, Settings.Value(kind, "auraColumns")) or 0
	if count > 0 then
		local width, height, corner, _, growth = ns.Auras.Footprint(kind, host)
		host:SetSize(width, height)
		ns.Auras.Anchor(host, holder, kind, view.geometry.panel.x)
		host:Show()
		local size = Widgets.Snap(host, Settings.Value(kind, "auraSize"))
		local spacing = Widgets.Snap(host, Settings.Value(kind, "auraSpacing"))
		local sx = growth[2] == "Left" and -1 or 1
		for i = 1, count do
			local tile = tiles[i]
			if not tile then
				tile = ns.Auras.NewTile(host)
				tiles[i], icons[i] = tile, tile.skin
			end
			tile.icon:SetTexture(AURA_ICONS[i])
			local skin = tile.skin
			skin:ClearAllPoints()
			skin:SetPoint(corner, host, corner, sx * (i - 1) * (size + spacing), 0)
			skin:SetSize(size, size)
			ns.Auras.LayoutTile(tile)
			skin:Show()
		end
	else
		host:Hide()
	end
	for i = count + 1, #icons do
		icons[i]:Hide()
	end
	return count
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
	local room = frame:GetWidth()
	if type(room) == "number" and not (issecretvalue and issecretvalue(room)) and room > 2 * MARGIN then
		width = math.min(width, room - 2 * MARGIN)
	end
	return width, height
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
	if Settings.CASTBAR[kind] and not Settings.CAST_ELEMENTS[kind] and view.s.castbar then
		height = math.max(0, height - view.s.castbarHeight - CAST_GAP)
	end
	holder:SetSize(width, height)
	holder:Show()
	Style.Restyle(view, kind)
	Style.Layout(view, view.s, width, height)
	Paint(view, kind)
	PaintIndicators(view, view.s, SAMPLES[kind])
	local extra = PaintCast(frame, view, kind, height)
	frame.auraCount = PaintAuras(frame, view, kind)
	holder:ClearAllPoints()
	holder:SetPoint("CENTER", frame, "CENTER", 0, extra / 2)
	frame.kind = kind
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.holders, frame.views, frame.casts, frame.auraIcons, frame.auraTiles, frame.auraHosts = {}, {}, {}, {}, {}, {}
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end
