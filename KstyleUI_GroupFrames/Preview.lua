-- Preview.lua: the settings window's live preview: sample party and raid frames drawn with the same look as the real ones.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme, L = K.Tokens, K.Theme, K.L
local Settings, Geometry, Style, Unit = ns.Settings, ns.Geometry, ns.Style, ns.Unit

local Preview = {}
ns.Preview = Preview

local PARTY_SHOWN = 3
local RAID_GROUPS_SHOWN = 2
local GROUP_SIZE = 5
local SECTION_GAP = 16
local SAMPLE_LEVEL = 60
local SAMPLE_MAX = 4200
local PERCENT = 100

local SAMPLES = {
	{ name = "Thaldren", class = "WARRIOR", health = 0.92, power = 0.35 },
	{ name = "Sylaen", class = "DRUID", health = 0.87, power = 0.8, far = true },
	{ name = "Kragar", class = "SHAMAN", health = 0.76, power = 0.6, target = true },
	{ name = "Lunara", class = "MAGE", health = 0, power = 0, dead = true },
	{ name = "Vexen", class = "PRIEST", health = 0.94, power = 0.9 },
	{ name = "Orrin", class = "PALADIN", health = 0.55, power = 0.5 },
	{ name = "Kesh", class = "ROGUE", health = 1, power = 1 },
	{ name = "Maela", class = "HUNTER", health = 0.68, power = 0.7 },
	{ name = "Durn", class = "WARLOCK", health = 0.81, power = 0.4, offline = true },
	{ name = "Ysra", class = "PRIEST", health = 0.33, power = 0.6 },
}

local function HealthText(f, sample)
	local text = f.healthText
	text:SetAlpha(1)
	if sample.offline then
		text:SetText(L["Offline"])
		return
	elseif sample.dead then
		text:SetText(L["Dead"])
		return
	end
	local format = Settings.current[f.kind].healthText
	local current = math.floor(SAMPLE_MAX * sample.health + 0.5)
	local percent = math.floor(PERCENT * sample.health + 0.5)
	if format == "NONE" then
		text:SetText("")
	elseif format == "PERCENT" then
		text:SetFormattedText("%d%%", percent)
	elseif format == "DEFICIT" then
		text:SetText(sample.health < 1 and ("-" .. (SAMPLE_MAX - current)) or "")
	elseif format == "CURRENT_MAX" then
		text:SetFormattedText("%d / %d", current, SAMPLE_MAX)
	elseif format == "CURRENT_PERCENT" then
		text:SetFormattedText("%d  %d%%", current, percent)
	else
		text:SetText(current)
	end
end

local function Paint(f, sample)
	local cfg = Settings.current
	local cr, cg, cb = Theme.ClassColor(sample.class)
	f.health:SetBarRange(0, 1)
	f.health:SetBarValue(sample.health)
	if sample.dead or sample.offline then
		f.health:SetBarColor(Tokens.Color("textDisabled"))
	elseif cfg.health.colorSource == "class" then
		f.health:SetBarColor(cr, cg, cb)
	elseif cfg.health.colorSource == "reaction" then
		f.health:SetBarColor(Tokens.Color("friendly"))
	else
		local c = cfg.health.color
		f.health:SetBarColor(c.r, c.g, c.b)
	end
	if f.showPower then
		f.power:SetBarRange(0, 1)
		f.power:SetBarValue(sample.power)
		local c = cfg.power.color
		if cfg.power.colorSource == "custom" then
			f.power:SetBarColor(c.r, c.g, c.b)
		elseif cfg.power.colorSource == "class" then
			f.power:SetBarColor(cr, cg, cb)
		else
			f.power:SetBarColor(Tokens.Color("rare"))
		end
	end
	f.name:SetText(sample.name)
	if cfg.text.nameColorSource == "class" then
		f.name:SetTextColor(cr, cg, cb)
	end
	if f.showPortrait then
		f.ring:SetVertexColor(cr, cg, cb)
		f.portrait:SetTexture((Tokens.Texture("logo")))
		f.level:SetText(SAMPLE_LEVEL)
	end
	HealthText(f, sample)
	local fade = cfg.range.fade and sample.far
	f:SetAlpha(fade and cfg.range.alpha or 1)
	f.target:SetAlpha(sample.target and 1 or 0)
	for _, hook in ipairs(Preview.painters) do
		hook(f, sample)
	end
end

Preview.painters = {}

local function Sample(parent, kind, index)
	local f = CreateFrame("Frame", nil, parent)
	Style.Build(f, kind)
	f.sample = SAMPLES[(index - 1) % #SAMPLES + 1]
	for _, hook in ipairs(ns.Button.built) do
		hook(f)
	end
	return f
end

local function PlaceRun(frames, holder, s, growth, count, x0, y0, corner)
	local dx, dy = Geometry.Offset(growth, 1)
	local stepX = Geometry.IsVertical(growth) and 0 or (s.width + s.spacing)
	local stepY = Geometry.IsVertical(growth) and (s.height + s.spacing) or 0
	for i = 1, count do
		local f = frames[i]
		f:ClearAllPoints()
		f:SetSize(s.width, s.height)
		f:SetPoint(corner, holder, corner, x0 + dx * stepX * (i - 1), y0 + dy * stepY * (i - 1))
	end
end

local function Layout(preview)
	local cfg = Settings.Refresh()
	local party, raid = cfg.party, cfg.raid
	local partyGeo = Geometry.Party(party)
	local count = math.min(PARTY_SHOWN, partyGeo.count)
	local pw = Geometry.IsVertical(party.growth) and party.width or Geometry.Line(count, party.width, party.spacing)
	local ph = Geometry.IsVertical(party.growth) and Geometry.Line(count, party.height, party.spacing) or party.height
	preview.party:SetSize(pw, ph)
	preview.party:ClearAllPoints()
	preview.party:SetPoint("TOPLEFT", preview.canvas, "TOPLEFT", 0, 0)
	PlaceRun(preview.partyFrames, preview.party, party, party.growth, count, 0, 0, partyGeo.corner)
	for i, f in ipairs(preview.partyFrames) do
		f:SetShown(i <= count)
		Style.Apply(f, party.width, party.height)
		Paint(f, f.sample)
	end
	local gw, gh
	if Geometry.IsVertical(raid.growth) then
		gw, gh = raid.width, Geometry.Line(GROUP_SIZE, raid.height, raid.spacing)
	else
		gw, gh = Geometry.Line(GROUP_SIZE, raid.width, raid.spacing), raid.height
	end
	local groupsWide = not Geometry.IsVertical(Geometry.Perpendicular(raid.growth, raid.groupGrowth))
	local rw = groupsWide and Geometry.Line(RAID_GROUPS_SHOWN, gw, raid.groupSpacing) or gw
	local rh = groupsWide and gh or Geometry.Line(RAID_GROUPS_SHOWN, gh, raid.groupSpacing)
	preview.raid:SetSize(rw, rh)
	preview.raid:ClearAllPoints()
	preview.raid:SetPoint("TOPLEFT", preview.party, "BOTTOMLEFT", 0, -SECTION_GAP)
	local corner = Geometry.Corner(raid.growth, raid.groupGrowth)
	for g = 1, RAID_GROUPS_SHOWN do
		local frames = {}
		for m = 1, GROUP_SIZE do
			frames[m] = preview.raidFrames[(g - 1) * GROUP_SIZE + m]
		end
		local ox, oy = Geometry.Offset(Geometry.Perpendicular(raid.growth, raid.groupGrowth), (g - 1) * ((groupsWide and gw or gh) + raid.groupSpacing))
		PlaceRun(frames, preview.raid, raid, raid.growth, GROUP_SIZE, ox, oy, corner)
	end
	for _, f in ipairs(preview.raidFrames) do
		Style.Apply(f, raid.width, raid.height)
		Paint(f, f.sample)
	end
	local width = math.max(pw, rw)
	local height = ph + SECTION_GAP + rh
	preview.canvas:SetSize(width, height)
	local availW, availH = preview:GetWidth(), preview:GetHeight()
	local scale = 1
	if type(availW) == "number" and type(availH) == "number" and availW > 0 and availH > 0 and not Unit.IsSecret(availW) then
		scale = math.min(1, availW / width, availH / height)
	end
	preview.canvas:SetScale(scale)
end

function Preview.Build(parent)
	local preview = CreateFrame("Frame", nil, parent)
	preview:SetAllPoints(parent)
	preview.canvas = CreateFrame("Frame", nil, preview)
	preview.canvas:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, 0)
	preview.party = CreateFrame("Frame", nil, preview.canvas)
	preview.raid = CreateFrame("Frame", nil, preview.canvas)
	preview.partyFrames, preview.raidFrames = {}, {}
	for i = 1, PARTY_SHOWN do
		preview.partyFrames[i] = Sample(preview.party, "party", i)
	end
	for i = 1, RAID_GROUPS_SHOWN * GROUP_SIZE do
		preview.raidFrames[i] = Sample(preview.raid, "raid", i)
	end
	preview.Refresh = Layout
	Layout(preview)
	return preview
end
