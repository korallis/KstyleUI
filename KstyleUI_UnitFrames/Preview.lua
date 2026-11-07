-- Preview.lua: the settings window's live preview: the frame being customised, drawn with sample values at its current size.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme, L = K.Tokens, K.Theme, K.L
local Settings, Style, Format = ns.Settings, ns.Style, ns.Format

local Preview = {}
ns.Preview = Preview

local BOSS_SLOT_HEIGHT = 58
local MARGIN = 16
local INCOMING_SHARE = 0.08

local SAMPLES = {
	player = { name = L["Valerin"], level = 60, health = 3120, healthMax = 3980, power = 3120, powerMax = 3980, reaction = 5, own = true },
	target = { name = L["Frost Howler"], level = 61, health = 2240, healthMax = 4020, power = 40, powerMax = 100, reaction = 2 },
	targettarget = { name = L["Valerin"], level = 60, health = 3120, healthMax = 3980, power = 3120, powerMax = 3980, reaction = 5, own = true },
	focus = { name = L["Elunara"], level = 60, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, reaction = 2 },
	focustarget = { name = L["Krazhk"], level = 60, health = 3300, healthMax = 4000, power = 1800, powerMax = 3600, reaction = 2 },
	pet = { name = L["Wolf"], level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 },
	boss = { name = L["Magmatus"], level = -1, health = 72000, healthMax = 100000, power = 0, powerMax = 100, reaction = 2 },
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
		return Tokens.Color("rare")
	end
	if source == "class" and sample.own then
		return Theme.ClassColor(Theme.Class())
	end
	return Theme.ReactionColor(sample.reaction)
end

local function Paint(view, kind)
	local s, sample = view.s, SAMPLES[kind]
	view.health:SetBarRange(0, sample.healthMax)
	view.health:SetValue(sample.health)
	view.health:SetBarColor(SampleColor(s, sample, s.healthColor, s.healthCustom))
	Format.Sample(view.healthText, s.healthText, sample.health, sample.healthMax)
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
	view.name:SetText(s.nameCaps and sample.name:upper() or sample.name)
	view.levelText:SetText(sample.level > 0 and sample.level or "??")
	view.levelText:SetTextColor(Tokens.Color("textEmphasis"))
	if s.portraitStyle == "class" and GetClassAtlas and Theme.Class() then
		view.portrait:SetAtlas(GetClassAtlas(Theme.Class()))
	elseif SetPortraitTexture then
		view.portrait:SetTexCoord(0, 1, 0, 1)
		SetPortraitTexture(view.portrait, "player")
	end
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
		height = BOSS_SLOT_HEIGHT
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
	holder:ClearAllPoints()
	holder:SetPoint("CENTER", frame, "CENTER")
	holder:SetSize(width, height)
	holder:Show()
	view.s = Settings.Snapshot(kind)
	Style.Restyle(view, kind)
	Style.Layout(view, view.s, width, height)
	Paint(view, kind)
	frame.kind = kind
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.holders, frame.views = {}, {}
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end
