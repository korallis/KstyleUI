-- Slab.lua: Medallions unit slabs and portrait effects.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local Settings = ns.Settings

local Slab = {}
ns.Slab = Slab

local HOSTILE_MAX = 3
local UNKNOWN_LEVEL = "??"
local LEVEL_MEDAL, LEVEL_FIT = 3, 7
local TEXT_GAP = 4
local SHEEN = { player = true, target = true }
local DOCK, DOCK_UNDER, DOCK_SHORT, DOCK_H = { player = 1, target = -1 }, 20, 40, 16
local HOME = { "anchor", "x", "y", "width", "height", "scale", "attachTo" }

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Muted(view, text, token)
	local path, size, flags = Settings.Font(view.kind, "level")
	Widgets.ApplyFont(text, path, size, flags)
	text:SetTextColor(Tokens.Color(view.s and view.s.fittedSlabs and (token or "muted") or "labelMuted"))
end

function Slab.Material(owner, slice)
	local name = Settings.Module().slabCaps ~= false and "medUnitSlabCap" or "medUnitSlab"
	if not slice then return Widgets.NineSlice(owner, name, "BACKGROUND", 1) end
	if slice.texture ~= name then Widgets.PaintSlice(slice, name) end
	return slice
end

local function Build(view)
	view.slabLevel = Widgets.FontString(view.top, "OVERLAY")
	view.slabLevel:SetWordWrap(false)
	view.slabLevel:SetJustifyV("MIDDLE")
	Muted(view, view.slabLevel)
	view.medallion = Widgets.Medallion(view.parent)
end

local function Hide(view)
	Widgets.ShowSlice(view.slab, false)
	if view.dock then view.dock:Hide() end
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
	local single = Settings.Module().singleSlabLevel ~= false
	local plaque = g.medal and g.medalSide
	if not rect or single and (plaque or not view.s.level) or not single and not g.medal then
		level:Hide()
		if rect and single then
			local room = g.nameRoom or rect.w
			name:ClearAllPoints()
			name:SetPoint(g.mirror and "RIGHT" or "LEFT", view.parent, "TOPLEFT", Widgets.Snap(view.parent, rect.x + (g.mirror and rect.w or 0)), -Widgets.Snap(view.parent, rect.y + rect.h / 2))
			name:SetHeight(Widgets.Snap(view.parent, rect.h))
			name:SetWidth(view.nameBound and math.max(Widgets.Border(name), Widgets.Snap(view.parent, room)) or 0)
			name:SetShown(room > 0)
		end
		name:SetJustifyH(g.medal and (g.mirror and "RIGHT" or "LEFT") or "CENTER")
		return
	end
	local Snap, parent = Widgets.Snap, view.parent
	local y, gap = -Snap(parent, rect.y + rect.h / 2), Snap(parent, g.levelGap)
	name:ClearAllPoints()
	level:ClearAllPoints()
	name:SetHeight(Snap(parent, rect.h))
	level:SetHeight(Snap(parent, rect.h))
	name:SetWidth(view.nameBound and math.max(Widgets.Border(name), Snap(parent, g.nameRoom)) or 0)
	name:SetShown(g.nameRoom > 0)
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

local function MeasureCaption(ruler, label)
	ruler:SetText(ns.Unit.Tracked(label, (ruler:GetFont())))
	local width = ruler:GetUnboundedStringWidth()
	return Plain(width, "number") and width or 0
end

local function CaptionWidth(view)
	local text = view.caption
	local ruler = view.captionRuler
	if not ruler then
		ruler = Widgets.FontString(view.top, "OVERLAY")
		ruler:SetWordWrap(false)
		ruler:Hide()
		Widgets.Fitted(ruler)
		view.captionRuler = ruler
	end
	Widgets.ApplyFont(ruler, text:GetFont())
	if view.plainCaption then
		return MeasureCaption(ruler, view.plainCaption)
	end
	local api, width = C_CreatureInfo, 0
	if api and api.GetCreatureTypeIDs and api.GetCreatureTypeInfo then
		for _, id in ipairs(api.GetCreatureTypeIDs()) do
			local info = api.GetCreatureTypeInfo(id)
			if info and Plain(info.name, "string") then
				width = math.max(width, MeasureCaption(ruler, info.name))
			end
		end
	end
	return width > 0 and width or view.geometry.health.w
end

function Slab.SetCaption(view, label)
	view.plainCaption = Plain(label, "string") and label or nil
	if view.caption.ClearText then view.caption:ClearText() end
	view.caption:SetText(view.plainCaption and ns.Unit.Tracked(label, (view.caption:GetFont())) or label)
	Slab.Caption(view)
end

function Slab.Caption(view)
	local g = view.geometry
	if not (g and g.form == "slab" and g.caption) then
		return
	end
	local text, bar, rect = view.caption, g.lane, g.caption
	local size = Settings.FontSize(view.kind, "level")
	local levelWidth = Widgets.TextWidth(view.slabLevel, math.ceil(ns.Geometry.SLAB_PAD.levelEm * size))
	local levelRoom = g.name and math.ceil(levelWidth) + g.levelGap or 0
	if Settings.Module().singleSlabLevel ~= false and (g.medal and g.medalSide or not view.s.level) then levelRoom = 0 end
	local gap = g.name and TEXT_GAP or 0
	rect.w = math.min(CaptionWidth(view) + 2 * Widgets.Border(view.parent), math.max(0, bar.w - levelRoom - gap))
	if g.name then
		local room = math.max(0, bar.w - rect.w - TEXT_GAP)
		g.name.x, g.name.w = bar.x + bar.w - room, room
		g.nameRoom = math.max(0, room - levelRoom)
	end
	Extra(view, text, rect, "LEFT")
	NameLine(view, g)
end

local function Home(key, bar)
	local el = K.Layout and K.Layout.Element and K.Layout.Element(key)
	if not (el and el.settings and el.default) then return bar == true end
	if bar and not el.frame:IsShown() then return false end
	for _, field in ipairs(HOME) do
		local a, b = el.settings[field], el.default[field]
		if a ~= b and not (type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.5) then return false end
	end
	return true
end

local function Docked(view)
	local bars = K.Store.Module("ActionBars") or {}
	return DOCK[view.kind] ~= nil and view.s.fittedSlabs and K.HudStyle.Current() == "medallions" and bars.enabled ~= false
		and bars.slab ~= false and bars.extraBarsApplied ~= "rows" and Home(Settings.ELEMENTS[view.kind]) and Home("actionbars.bar1", true) and Home("actionbars.bar2", true) or false
end

local function Dock(view, g)
	local arm = view.dock
	if not Docked(view) then
		if arm then arm:Hide() end
		return
	end
	if not arm then
		arm = CreateFrame("Frame", nil, view.parent)
		arm:SetFrameStrata("LOW")
		arm.slice = Widgets.NineSlice(arm, "medUnitSlab", "BACKGROUND", 1)
		view.dock = arm
	end
	arm:SetFrameLevel(K.Scale.Root():GetFrameLevel() + 1)
	local layouts, w = K.Setup.Layouts, view.slabWidth
	local reach = layouts.MEDALLIONS_RING / 2 + layouts.MEDALLIONS_UNITS.reach - DOCK_SHORT
	Place(view, arm, { x = DOCK[view.kind] > 0 and w - DOCK_UNDER or -reach, y = g.glass.h - DOCK_H, w = reach + DOCK_UNDER, h = DOCK_H })
	Widgets.LayoutSlice(arm.slice, arm, select(3, Tokens.Texture("medUnitSlab")))
	arm:Show()
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
	local resized = view.slabWidth ~= g.glass.w or view.slabHeight ~= g.glass.h
	view.slabWidth, view.slabHeight = g.glass.w, g.glass.h
	view.slab = Slab.Material(view.panel, view.slab)
	Widgets.ShowSlice(view.slab, true)
	Widgets.LayoutSlice(view.slab, view.panel, select(3, Tokens.Texture("medUnitSlab")))
	local m, rect = view.medallion, g.medal
	if rect then
		m:SetFrameLevel(view.parent:GetFrameLevel() + (view.s.fittedSlabs and LEVEL_FIT or LEVEL_MEDAL))
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
	view.healthText:SetJustifyH(g.mirror and "LEFT" or "RIGHT")
	local opposite = g.mirror and "LEFT" or "RIGHT"
	Extra(view, view.healthSub, g.healthSub, opposite)
	if view.kind == "target" and view.s.percentLead and view.s.healthText == "both" and view.s.fonts.health.textFormat == "" and g.healthText then
		local bar, pad = g.lane, view.s.fittedSlabs and 0 or ns.Geometry.SLAB_PAD.valuePad
		Extra(view, view.healthSub, { x = bar.x + bar.w / 2, y = g.health.y, w = bar.w / 2 - pad, h = g.health.h }, "RIGHT")
		view.healthText:SetWidth(Widgets.Snap(view.parent, math.max(0, bar.w / 2 - pad)))
		view.healthText:SetJustifyH("LEFT")
	end
	Extra(view, view.caption, g.caption, opposite)
	Slab.Caption(view)
	if resized then ns.Unit.Refit(view) end
	view.levelText:Hide()
	Dock(view, g)
end

function Slab.Restyle(view, form)
	local finish = form == "slab" and "medallions" or nil
	view.health:SetFinish(finish)
	view.power:SetFinish(finish)
	if form ~= "slab" then
		return
	end
	Muted(view, view.healthSub, "text")
	if view.kind == "target" and view.s.percentLead then
		Widgets.ApplyFont(view.healthSub, (Tokens.Font("number")), 10 * K.Theme.FontScale(), "OUTLINE")
	end
	Muted(view, view.caption)
	if view.slabLevel then
		Muted(view, view.slabLevel)
	end
	local path, size, flags, outline = Settings.Font(view.kind, "health")
	Widgets.ApplyFont(view.healthText, path, size, outline == "INHERIT" and "OUTLINE" or flags)
	view.healthText:SetTextColor(Tokens.Color("textEmphasis"))
end

local function Active(view)
	return view.form == "slab" and view.medallion ~= nil and view.geometry ~= nil and view.geometry.medal ~= nil
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
	local known, file = ClassFile(unit)
	local hostile = Hostile(unit)
	if hostile then
		view.name:SetTextColor(Tokens.Color("nameHostile"))
	elseif unit ~= "player" and known and IsPlayer(unit) then
		view.name:SetTextColor(Theme.ClassColorForWidget(file))
	else
		view.name:SetTextColor(Tokens.Color("textEmphasis"))
	end
	if Active(view) then
		local clean = Settings.Module().cleanLowRing ~= false
		if view.lowEnemy ~= hostile or view.medallion.cleanLow ~= clean then
			view.lowEnemy = hostile
			view.medallion:LowHealthStyle(unit, hostile, clean)
		end
		view.medallion:SetRingColor(RingColor(view, unit))
	end
end

local function DeathBlend(view, progress)
	local m = view.medallion
	if type(m.portrait.SetDesaturation) == "function" then
		m.portrait:SetDesaturation(progress)
	end
	if progress == 1 then m:SetDead(true) end
	local shade = 1 - 0.55 * progress
	m.portrait:SetVertexColor(shade, shade, shade, 1)
	local c = view.deathColor
	local r, g, b = Tokens.Color("medDead")
	view.health:SetBarColor(c[1] + (r - c[1]) * progress, c[2] + (g - c[2]) * progress, c[3] + (b - c[3]) * progress)
end

function Slab.Health(view, unit)
	if not Active(view) then
		return
	end
	local m, dead = view.medallion, Dead(unit)
	if dead ~= (view.slabDead == true) then
		view.slabDead = dead
		if view.kind == "target" and Settings.Value("target", "transitions") and dead then
			local c = view.health.colorRGBA
			if not (IsSecret(c[1]) or IsSecret(c[2]) or IsSecret(c[3])) then
				view.deathColor = { c[1], c[2], c[3] }
				view.health:SetHealthUnit(nil)
				view.deathAt = GetTime()
				view.deathTween = K.Motion.Tween(view, DeathBlend, 0, 1, 0.2, "outQuad")
			else
				m:SetDead(true)
			end
		else
			if view.deathTween then K.Motion.Stop(view.deathTween); view.deathTween = nil end
			m:SetDead(dead)
		end
		m:SetRingColor(RingColor(view, unit))
	end
	if dead and view.kind == "target" and Settings.Value("target", "transitions") and not K.Motion.IsPlaying(view.deathTween) then
		view.health:SetHealthUnit(nil)
		view.health:SetBarColor(Tokens.Color("medDead"))
	end
	m:LowHealth(not dead and unit or nil)
end

function Slab.Portrait(view, unit)
	if Active(view) then
		view.medallion:SetUnit(unit, "bust")
	end
end

function Slab.Level(view, unit)
	if view.form ~= "slab" or not view.slabLevel then
		return
	end
	local level = UnitLevel(unit)
	local classification = UnitClassification and UnitClassification(unit)
	if not (IsSecret(level) or IsSecret(classification)) and (classification == "worldboss" or type(level) ~= "number" or level <= 0) then
		level = UNKNOWN_LEVEL
	end
	if Active(view) then view.medallion:SetLevel(level) end
	if not IsSecret(level) then level = tostring(level) end
	view.slabLevel:SetText(level)
	if view.s.levelDifficulty or view.levelTinted then
		local tint = view.s.levelDifficulty and unit
		view.levelTinted = tint
		view.slabLevel:SetTextColor(ns.Unit.LevelColor(tint, "labelMuted", nil, view.s.levelFriendly))
		view.medallion.levelText:SetTextColor(ns.Unit.LevelColor(tint, "steelLit", nil, view.s.levelFriendly))
	end
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
		local now = GetTime()
		if view.kind == "target" and Settings.Value("target", "transitions") and view.targetFlipAt and now - view.targetFlipAt < 0.09 then return end
		view.targetFlipAt = now
		view.medallion:FlipIn()
	end
end
