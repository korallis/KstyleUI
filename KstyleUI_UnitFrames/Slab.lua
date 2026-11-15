-- Slab.lua: the Medallions unit frame, a flat slab with procedural pixel edges, clean bars and a medallion on its outer end, with the slab's colours and texts and the event effects (target flip-in, low-health ring, portrait sheen).
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local Settings = ns.Settings

local Slab = {}
ns.Slab = Slab

local Color = Widgets.MedallionColor
local HOSTILE_MAX = 3
local UNKNOWN_LEVEL = "??"
local LEVEL_MEDAL = 3
local SHEEN = { player = true, target = true }

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Lines(owner, layer, sublevel, name, fallback)
	local lines = {}
	for i = 1, 4 do
		local line = owner:CreateTexture(nil, layer, nil, sublevel)
		line:SetColorTexture(Color(name, fallback))
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
		texture:SetGradient("VERTICAL", CreateColor(Color("slabBottom", "materialForged")), CreateColor(Color("slabTop", "materialFlat")))
	else
		texture:SetColorTexture(Color("slabBottom", "materialForged"))
	end
end

local function Build(view)
	local panel = view.panel
	local slab = { fill = panel:CreateTexture(nil, "BACKGROUND", nil, 1) }
	slab.fill:SetAllPoints(panel)
	Gradient(slab.fill)
	slab.outer = Lines(panel, "BACKGROUND", 2, "black", "black")
	slab.hairline = Lines(panel, "BORDER", 6, "steelEdge", "materialFlatEdge")
	slab.inner = Lines(panel, "BORDER", 7, "slabInner", "socketEdge")
	view.slab = slab
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
		m:Layout(rect.w, view.s and view.s.level and g.medalSide or nil)
		m:Show()
		m:Sheen(SHEEN[view.kind] == true)
	else
		m:Sheen(false)
		m:LowHealth(nil)
		m:Hide()
	end
	view.name:SetJustifyH(g.mirror and "RIGHT" or "LEFT")
	view.healthText:SetJustifyH("CENTER")
	local opposite = g.mirror and "LEFT" or "RIGHT"
	Extra(view, view.healthSub, g.healthSub, opposite)
	Extra(view, view.caption, g.caption, opposite)
	view.levelText:Hide()
end

function Slab.Restyle(view, form)
	if form ~= "slab" then
		return
	end
	local path, size, flags = Settings.Font(view.kind, "level")
	for _, key in ipairs({ "healthSub", "caption" }) do
		Widgets.ApplyFont(view[key], path, size, flags)
		view[key]:SetTextColor(Color("labelMuted", "muted"))
	end
	view.healthText:SetTextColor(Tokens.Color("textEmphasis"))
end

local function Active(view)
	return view.form == "slab" and view.medallion ~= nil and view.geometry ~= nil and view.geometry.medal ~= nil
end

local function ClassColor(unit)
	local _, file = UnitClass(unit)
	if IsSecret(file) or type(file) == "string" then
		return Theme.ClassColorForWidget(file)
	end
	return nil
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
		return Color("medDead", "textDisabled")
	end
	if view.kind == "boss" then
		return Color("steel", "muted")
	end
	if IsPlayer(unit) then
		local r, g, b = ClassColor(unit)
		if r then
			return r, g, b
		end
	end
	return ns.Unit.ReactionColor(UnitReaction and UnitReaction(unit, "player"))
end

function Slab.Colors(view, unit)
	if view.form ~= "slab" then
		return
	end
	if Hostile(unit) then
		view.name:SetTextColor(Color("nameHostile", "hostile"))
	elseif unit ~= "player" and IsPlayer(unit) and ClassColor(unit) then
		view.name:SetTextColor(ClassColor(unit))
	else
		view.name:SetTextColor(Tokens.Color("textEmphasis"))
	end
	if Active(view) then
		view.medallion:SetRingColor(RingColor(view, unit))
	end
end

function Slab.Health(view, unit)
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
	if IsSecret(level) or IsSecret(classification) then
		view.medallion:SetLevel(level)
	elseif classification == "worldboss" or type(level) ~= "number" or level <= 0 then
		view.medallion:SetLevel(UNKNOWN_LEVEL)
	else
		view.medallion:SetLevel(level)
	end
end

function Slab.FlipIn(view)
	if view and Active(view) then
		view.medallion:FlipIn()
	end
end
