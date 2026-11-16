-- Slab.lua: the Medallions unit frame, a flat slab with procedural pixel edges, clean bars and a medallion on its outer end, with the slab's colours and texts and the event effects (target flip-in, low-health ring, portrait sheen).
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local Settings = ns.Settings

local Slab = {}
ns.Slab = Slab

local HOSTILE_MAX = 3
local UNKNOWN_LEVEL = "??"
local LEVEL_MEDAL = 3
local SHEEN = { player = true, target = true }
local INK_LUMINANCE, INK_FILL = 0.5, 0.65

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Lines(owner, layer, sublevel, name)
	local lines = {}
	for i = 1, 4 do
		local line = owner:CreateTexture(nil, layer, nil, sublevel)
		line:SetColorTexture(Tokens.Color(name))
		lines[i] = line
	end
	return lines
end

local function PlaceLines(lines, frame, inset, px)
	local o = inset * px
	local top, bottom, left, right = lines[1], lines[2], lines[3], lines[4]
	for _, line in ipairs(lines) do
		line:ClearAllPoints()
	end
	top:SetPoint("TOPLEFT", frame, "TOPLEFT", o, -o)
	top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -o, -o)
	top:SetHeight(px)
	bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", o, o)
	bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -o, o)
	bottom:SetHeight(px)
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", o, -o - px)
	left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", o, o + px)
	left:SetWidth(px)
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -o, -o - px)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -o, o + px)
	right:SetWidth(px)
end

local function Gradient(texture)
	if type(CreateColor) == "function" and texture.SetGradient then
		texture:SetColorTexture(Tokens.Color("white"))
		texture:SetGradient("VERTICAL", CreateColor(Tokens.Color("slabBottom")), CreateColor(Tokens.Color("slabTop")))
	else
		texture:SetColorTexture(Tokens.Color("slabBottom"))
	end
end

local function Muted(view, text)
	local path, size, flags = Settings.Font(view.kind, "level")
	Widgets.ApplyFont(text, path, size, flags)
	text:SetTextColor(Tokens.Color("labelMuted"))
end

local function Build(view)
	local panel = view.panel
	local slab = { fill = panel:CreateTexture(nil, "BACKGROUND", nil, 1) }
	slab.fill:SetAllPoints(panel)
	Gradient(slab.fill)
	slab.outer = Lines(panel, "BACKGROUND", 2, "black")
	slab.hairline = Lines(panel, "BORDER", 6, "steelEdge")
	slab.inner = Lines(panel, "BORDER", 7, "slabInner")
	view.slab = slab
	view.slabLevel = Widgets.FontString(view.top, "OVERLAY")
	view.slabLevel:SetWordWrap(false)
	view.slabLevel:SetJustifyV("MIDDLE")
	Muted(view, view.slabLevel)
	local medallion = Widgets.Medallion(view.parent)
	medallion:SetFrameLevel(view.parent:GetFrameLevel() + LEVEL_MEDAL)
	view.medallion = medallion
end

local function ShowSlab(view, shown)
	local slab = view.slab
	slab.fill:SetShown(shown)
	for _, key in ipairs({ "outer", "hairline", "inner" }) do
		for _, line in ipairs(slab[key]) do
			line:SetShown(shown)
		end
	end
end

local function Hide(view)
	ShowSlab(view, false)
	view.slabLevel:Hide()
	local m = view.medallion
	m:Sheen(false)
	m:LowHealth(nil)
	m:Hide()
end

local function Place(view, region, rect)
	local Snap = Widgets.Snap
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", view.parent, "TOPLEFT", Snap(view.parent, rect.x), -Snap(view.parent, rect.y))
	region:SetSize(Snap(view.parent, rect.w), Snap(view.parent, rect.h))
end

local function Extra(view, text, rect, justify)
	if not rect then
		text:Hide()
		return
	end
	Place(view, text, rect)
	text:SetJustifyH(justify)
	text:SetJustifyV("MIDDLE")
	text:Show()
end

local function NameLine(view, g)
	local name, level, rect = view.name, view.slabLevel, g.name
	if not (rect and g.medal) then
		level:Hide()
		name:SetJustifyH(g.medal and (g.mirror and "RIGHT" or "LEFT") or "CENTER")
		return
	end
	local Snap, parent = Widgets.Snap, view.parent
	local y, gap = -Snap(parent, rect.y + rect.h / 2), Snap(parent, g.levelGap)
	name:ClearAllPoints()
	level:ClearAllPoints()
	name:SetHeight(Snap(parent, rect.h))
	level:SetHeight(Snap(parent, rect.h))
	name:SetWidth(view.nameBound and Snap(parent, g.nameRoom) or 0)
	level:SetWidth(0)
	if g.mirror then
		level:SetPoint("RIGHT", parent, "TOPLEFT", Snap(parent, rect.x + rect.w), y)
		name:SetPoint("RIGHT", level, "LEFT", -gap, 0)
		name:SetJustifyH("RIGHT")
	else
		name:SetPoint("LEFT", parent, "TOPLEFT", Snap(parent, rect.x), y)
		level:SetPoint("LEFT", name, "RIGHT", gap - Widgets.TrackPad(name), 0)
		name:SetJustifyH("LEFT")
	end
	level:SetJustifyH(g.mirror and "RIGHT" or "LEFT")
	level:Show()
end

function Slab.Layout(view, g)
	if g.form ~= "slab" then
		if view.slab then
			Hide(view)
		end
		return
	end
	if not view.slab then
		Build(view)
	end
	ShowSlab(view, true)
	local slab, panel = view.slab, view.panel
	local px = Widgets.Border(panel)
	PlaceLines(slab.outer, panel, -1, px)
	PlaceLines(slab.hairline, panel, 0, px)
	PlaceLines(slab.inner, panel, 1, px)
	local m, rect = view.medallion, g.medal
	if rect then
		Place(view, m, rect)
		m:Layout(rect.w, g.medalSide)
		m:Show()
		m:Sheen(SHEEN[view.kind] == true)
	else
		m:Sheen(false)
		m:LowHealth(nil)
		m:Hide()
	end
	NameLine(view, g)
	view.healthText:SetJustifyH("CENTER")
	local opposite = g.mirror and "LEFT" or "RIGHT"
	Extra(view, view.healthSub, g.healthSub, opposite)
	Extra(view, view.caption, g.caption, opposite)
	view.levelText:Hide()
end

function Slab.Restyle(view, form)
	view.health:SetFlat(form == "slab")
	view.power:SetFlat(form == "slab")
	if form ~= "slab" then
		return
	end
	view.health:SetBarTexture("Flat")
	view.power:SetBarTexture("Flat")
	Muted(view, view.healthSub)
	Muted(view, view.caption)
	if view.slabLevel then
		Muted(view, view.slabLevel)
	end
	view.healthText:SetTextColor(Tokens.Color("textEmphasis"))
end

local function Active(view)
	return view.form == "slab" and view.medallion ~= nil and view.geometry ~= nil and view.geometry.medal ~= nil
end

local inkCurves

local function HealthInk(view, unit)
	if view.form ~= "slab" or not view.slabInk then
		return
	end
	if not inkCurves and C_CurveUtil and C_CurveUtil.CreateCurve and UnitHealthPercent then
		inkCurves = {}
		local light, dark = { Tokens.Color("textEmphasis") }, { Tokens.Color("slabBottom") }
		for i = 1, 3 do
			local curve = C_CurveUtil.CreateCurve()
			if Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step and curve.SetType then
				curve:SetType(Enum.LuaCurveType.Step)
			end
			curve:AddPoint(0, light[i])
			curve:AddPoint(INK_FILL, light[i])
			curve:AddPoint(INK_FILL + 0.001, dark[i])
			curve:AddPoint(1, dark[i])
			inkCurves[i] = curve
		end
	end
	if inkCurves and unit then
		view.healthText:SetTextColor(UnitHealthPercent(unit, true, inkCurves[1]), UnitHealthPercent(unit, true, inkCurves[2]), UnitHealthPercent(unit, true, inkCurves[3]))
	end
end

function Slab.Ink(view, r, g, b)
	view.slabInk = Plain(r, "number") and Plain(g, "number") and Plain(b, "number")
		and 0.2126 * r + 0.7152 * g + 0.0722 * b >= INK_LUMINANCE
	view.healthText:SetTextColor(Tokens.Color(view.slabInk and "slabBottom" or "textEmphasis"))
end

local function ClassFile(unit)
	local _, file = UnitClass(unit)
	return IsSecret(file) or type(file) == "string", file
end

local function IsPlayer(unit)
	if unit == "player" then
		return true
	end
	local player = UnitIsPlayer and UnitIsPlayer(unit)
	return Plain(player, "boolean") and player
end

local function Hostile(unit)
	local reaction = UnitReaction and UnitReaction(unit, "player")
	return Plain(reaction, "number") and reaction <= HOSTILE_MAX
end

local function Dead(unit)
	local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
	return Plain(dead, "boolean") and dead
end

local function RingColor(view, unit)
	if Dead(unit) then
		return Tokens.Color("medDead")
	end
	if view.kind == "boss" then
		return Tokens.Color("steel")
	end
	local known, file = ClassFile(unit)
	if known and IsPlayer(unit) then
		return Theme.ClassColorForWidget(file)
	end
	return ns.Unit.ReactionColor(UnitReaction and UnitReaction(unit, "player"))
end

function Slab.Colors(view, unit)
	if view.form ~= "slab" then
		return
	end
	HealthInk(view, unit)
	local known, file = ClassFile(unit)
	if Hostile(unit) then
		view.name:SetTextColor(Tokens.Color("nameHostile"))
	elseif unit ~= "player" and known and IsPlayer(unit) then
		view.name:SetTextColor(Theme.ClassColorForWidget(file))
	else
		view.name:SetTextColor(Tokens.Color("textEmphasis"))
	end
	if Active(view) then
		view.medallion:SetRingColor(RingColor(view, unit))
	end
end

function Slab.Health(view, unit)
	HealthInk(view, unit)
	if not Active(view) then
		return
	end
	local m, dead = view.medallion, Dead(unit)
	if dead ~= (view.slabDead == true) then
		view.slabDead = dead
		m:SetDead(dead)
		m:SetRingColor(RingColor(view, unit))
	end
	m:LowHealth(not dead and unit or nil)
end

function Slab.Portrait(view, unit)
	if Active(view) then
		view.medallion:SetUnit(unit, "bust")
	end
end

function Slab.Level(view, unit)
	if not Active(view) then
		return
	end
	local level = UnitLevel(unit)
	local classification = UnitClassification and UnitClassification(unit)
	if not (IsSecret(level) or IsSecret(classification)) and (classification == "worldboss" or type(level) ~= "number" or level <= 0) then
		level = UNKNOWN_LEVEL
	end
	view.medallion:SetLevel(level)
	view.slabLevel:SetText(level)
end

function Slab.Refresh(view, unit)
	if view.form ~= "slab" then
		return
	end
	ns.Unit.Portrait(view, unit)
	ns.Unit.HealthColor(view, unit)
	ns.Unit.Caption(view, unit)
end

function Slab.FlipIn(view)
	if view and Active(view) then
		view.medallion:FlipIn()
	end
end
