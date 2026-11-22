-- Frames.lua: the secure unit buttons for each frame, their Layout elements, unit watches and events; the boss you target folds its card to a Targeted chip in the resting card's place and glass, which out of combat is all of the card that takes clicks, and a card with no cast hugs its pill.
local _, ns = ...

local K = KstyleUI
local Settings, Geometry, Style, Unit, Indicators = ns.Settings, ns.Geometry, ns.Style, ns.Unit, ns.Indicators

local Frames = {}
ns.Frames = Frames

local MODULE = Settings.MODULE
local BOSS_COUNT, BOSS_GAP = Geometry.BOSS_COUNT, Geometry.BOSS_GAP
local CAST_GAP = { focus = 4, boss = 2 }
local PET_CAST_GAP = 4
local SLAB_CAST_GAP, SLAB_CAST_H = 2, 20
local MIN_FRAME_HEIGHT = 20
local POLL_INTERVAL = 0.2
local CHIP_LEVEL, CHIP_GAP, CHIP_HEIGHT, CHIP_PAD, CHIP_EM = 9, 6, 20, 10, 0.62

local FULL_LIMITS = { minWidth = 120, minHeight = 24, maxWidth = 640, maxHeight = 160 }
local SMALL_LIMITS = { minWidth = 60, minHeight = 14, maxWidth = 400, maxHeight = 120 }
local BOSS_LIMITS = { minWidth = 120, minHeight = 100, maxWidth = 640, maxHeight = 800 }

local POLLED = { targettarget = true, focustarget = true }
local LOSS_EVENT = "UNIT_MAX_HEALTH_MODIFIERS_CHANGED"
local CAST_OWNER = MODULE .. ":cost"
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED" }

local UNIT_EVENTS = {
	UNIT_HEALTH = "Health",
	UNIT_MAXHEALTH = "MaxHealth",
	UNIT_HEAL_PREDICTION = "Prediction",
	UNIT_ABSORB_AMOUNT_CHANGED = "Prediction",
	UNIT_HEAL_ABSORB_AMOUNT_CHANGED = "Prediction",
	UNIT_POWER_UPDATE = "Power",
	UNIT_MAXPOWER = "Power",
	UNIT_DISPLAYPOWER = "PowerType",
	UNIT_NAME_UPDATE = "Name",
	UNIT_TARGET = "Target",
	UNIT_LEVEL = "Level",
	UNIT_CLASSIFICATION_CHANGED = "Level",
	UNIT_PORTRAIT_UPDATE = "Portrait",
	UNIT_MODEL_CHANGED = "Portrait",
	UNIT_FACTION = "Colors",
	UNIT_FLAGS = "Colors",
	UNIT_CONNECTION = "Colors",
	PLAYER_FLAGS_CHANGED = "Flags",
	UNIT_IN_RANGE_UPDATE = "Range",
}

local frames, order = {}, {}
local running = false

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function Owner(unit)
	return MODULE .. ":" .. unit
end

local function Settle(region)
	if region.rangeTween then K.Motion.Stop(region.rangeTween); region.rangeTween = nil end
end

function Frames.Range(view)
	if view.kind ~= "target" or type(UnitInRange) ~= "function" then return end
	if not Settings.Value("target", "rangeFade") then
		for _, region in ipairs({ view.name, view.portrait }) do
			Settle(region)
			region:SetAlpha(1)
		end
		view.rangeAlpha = 1
		return
	end
	local inRange, checked = UnitInRange(view.unit)
	local alpha
	if not issecretvalue(inRange) and not issecretvalue(checked) then
		alpha = 1
		if checked == true and inRange == false then alpha = 0.55 end
	end
	for _, region in ipairs({ view.name, view.portrait }) do
		if region.SetAlphaFromBoolean then
			if issecretvalue(inRange) or issecretvalue(checked) then
				Settle(region)
				region:SetAlphaFromBoolean(inRange, 1, 0.55)
				region:SetAlphaFromBoolean(checked, region:GetAlpha(), 1)
			elseif view.rangeAlpha ~= alpha then
				region:SetAlphaFromBoolean(inRange == true or checked ~= true, 1, 0.55)
				region.rangeTween = K.Motion.Tween(region, "SetAlpha", view.rangeAlpha or 1, alpha, 0.15)
			end
		end
	end
	view.rangeAlpha = alpha
end

local HANDLERS = {
	Target = function() end,
	Range = Frames.Range,
	Health = function(view, unit)
		Unit.Health(view, unit)
	end,
	MaxHealth = function(view, unit)
		Unit.HealthRange(view, unit)
		Unit.Health(view, unit)
	end,
	Prediction = function(view, unit)
		Unit.Prediction(view, unit)
	end,
	Power = function(view, unit)
		Unit.Power(view, unit)
	end,
	PowerType = function(view, unit)
		Unit.PowerColor(view, unit)
		Unit.Power(view, unit, true)
	end,
	Name = function(view, unit)
		Unit.Name(view, unit)
		if view.chip then
			Frames.ChipName(view)
		end
	end,
	Level = function(view, unit)
		Unit.Level(view, unit)
		Indicators.Extra(view, unit)
	end,
	Portrait = function(view, unit)
		Unit.Portrait(view, unit)
	end,
	Colors = function(view, unit)
		Unit.HealthColor(view, unit, true)
		Unit.Health(view, unit)
		if view.s.powerColor == "reaction" or view.s.powerColor == "class" then Unit.PowerColor(view, unit) end
		Indicators.Combat(view, unit)
		Indicators.PvP(view, unit)
	end,
	Flags = function(view, unit)
		Indicators.PvP(view, unit)
	end,
}

local function Active(view)
	return running and view.uf.active
end

function Frames.Edge(view, sample)
	local s, edge = view.s, view.edge
	local target = s and s.targetBorder and view.kind ~= "target"
	local on = false
	if s and (s.hoverBorder or target) then
		local same = target and view.unit and UnitExists(view.unit) and UnitIsUnit and UnitIsUnit(view.unit, "target")
		on = sample == true or s.hoverBorder and view.hovered or not issecretvalue(same) and same == true
	end
	if not on then
		if edge and edge:IsShown() then edge:Hide() end
		return
	end
	if not edge then
		edge = CreateFrame("Frame", nil, view.chip and view.button or view.parent)
		edge.line = K.Widgets.NineSlice(edge, "lumenOutline", "OVERLAY")
		edge.line.cacheColor = true
		view.edge = edge
	end
	local chip = view.targeted and view.chip
	local host = chip or view.panel
	if edge.host ~= host then
		edge.host = host
		local level = (chip or view.top):GetFrameLevel()
		if not issecretvalue(level) then edge:SetFrameLevel(level + (chip and 1 or -1)) end
		edge:ClearAllPoints()
		edge:SetAllPoints(host)
	end
	K.Widgets.LayoutSlice(edge.line, edge, K.Tokens.Size("radiusTile"), 0)
	local r, g, b = Settings.Accent()
	K.Widgets.ColorSlice(edge.line, r, g, b, 1)
	if not edge:IsShown() then edge:Show() end
end

local function Refresh(view, instant)
	if Active(view) then
		Unit.All(view, view.unit, instant)
		Frames.Range(view)
		Frames.Edge(view)
	end
end

local function Visible(frame)
	local shown = frame:IsVisible()
	return (issecretvalue and issecretvalue(shown)) or shown == true
end

local function EachShown(fn)
	for _, kind in ipairs(order) do
		local uf = frames[kind]
		if running and uf.active then
			for _, view in ipairs(uf.views) do
				if Visible(view.button) then
					fn(view, view.unit)
				end
			end
		end
	end
end

local function OnThreat(_, unit)
	if unit == "player" then
		EachShown(Indicators.Threat)
		return
	end
	for _, kind in ipairs(order) do
		local uf = frames[kind]
		if running and uf.active then
			for _, view in ipairs(uf.views) do
				if view.unit == unit and Visible(view.button) then
					Indicators.Threat(view, unit)
				end
			end
		end
	end
end

local function OnPlayer(fn)
	local uf = frames.player
	if running and uf and uf.active then
		fn(uf.views[1], "player")
	end
end

local function RefreshKind(kind, instant)
	local uf = frames[kind]
	if uf then
		for _, view in ipairs(uf.views) do
			Refresh(view, instant)
		end
	end
	ns.CastBars.Refresh(kind)
end

local hovered
local function Tooltip(button, combat)
	local mode = Settings.Module().unitTooltip
	local show = mode == "always" or mode == "noCombat" and not combat
	if show ~= button.tip then
		button.tip = show
		local fn = show and UnitFrame_OnEnter or UnitFrame_OnLeave
		if fn then fn(button) end
	end
end

local function OnEnter(button)
	hovered, button.tip = button, false
	Tooltip(button, InCombatLockdown())
	button.view.hovered = true
	Frames.Edge(button.view)
end

local function OnLeave(button)
	if UnitFrame_OnLeave then
		UnitFrame_OnLeave(button)
	end
	hovered, button.tip = nil, nil
	button.view.hovered = false
	Frames.Edge(button.view)
end

local function Poll(uf)
	local view = uf.views[1]
	if Active(view) and UnitExists(view.unit) then
		Unit.Health(view, view.unit, true)
		Unit.Power(view, view.unit, true)
		Unit.TextTags(view, view.unit)
	end
end

local function StartPolling(uf)
	if POLLED[uf.kind] and not uf.polling then
		if C_Timer and type(C_Timer.NewTicker) == "function" then
			uf.polling = C_Timer.NewTicker(POLL_INTERVAL, function()
				Poll(uf)
			end)
		else
			uf.polling, uf.elapsed = true, 0
			uf.holder:SetScript("OnUpdate", function(_, elapsed)
				uf.elapsed = uf.elapsed + elapsed
				if uf.elapsed >= POLL_INTERVAL then
					uf.elapsed = 0
					Poll(uf)
				end
			end)
		end
	end
end

local function StopPolling(uf)
	if uf.polling then
		if uf.polling == true then
			uf.holder:SetScript("OnUpdate", nil)
		else
			uf.polling:Cancel()
		end
		uf.polling = nil
	end
end

local function TargetTransitions(view)
	return view.kind == "target" and view.form == "slab" and Settings.Value("target", "transitions")
end

local function HideBody(body)
	body:Hide()
	body:SetAlpha(1)
end

local function TargetLoss(view)
	if not view.body or view.kind ~= "target" then return end
	view.targetSeen = false
	local body = view.body
	view.targetLoss = (view.targetLoss or 0) + 1
	local token = view.targetLoss
	if TargetTransitions(view) then
		K.Motion.Tween(body, "SetAlpha", body:GetAlpha(), body:GetAlpha(), 0)
		local function Fade()
			if view.targetLoss == token and not view.targetSeen then
				K.Motion.Tween(body, "SetAlpha", body:GetAlpha(), 0, 0.15, function(t) return t * t end, HideBody)
			end
		end
		if view.deathTween and K.Motion.IsPlaying(view.deathTween) then
			C_Timer.After(math.max(0, 0.2 - (GetTime() - view.deathAt)), Fade)
		else
			Fade()
		end
	else
		K.Motion.Tween(body, "SetAlpha", 1, 0, 0, nil, HideBody)
	end
end

local function OnButtonShow(button)
	local view = button.view
	if Active(view) then
		StartPolling(view.uf)
		if view.kind == "target" and view.body then view.body:Show() end
		if not TargetTransitions(view) then Unit.All(view, view.unit, true) end
		Frames.Range(view)
	end
	ns.Auras.Sync(view)
end

local function OnButtonHide(button)
	StopPolling(button.view.uf)
	TargetLoss(button.view)
	ns.Auras.Sync(button.view)
end

local function NewChip(button, shape)
	local chip = CreateFrame("Frame", nil, button)
	chip:SetFrameLevel(button:GetFrameLevel() + CHIP_LEVEL)
	chip.chrome = K.Widgets.Chrome(chip, { shape = shape, fill = "surface", shadow = false })
	chip.gem = ns.Lumen.Gem(chip)
	chip.name = K.Widgets.FontString(chip, "OVERLAY")
	chip.name:SetJustifyH("LEFT")
	chip.name:SetJustifyV("MIDDLE")
	chip.name:SetWordWrap(false)
	chip.text = K.Widgets.FontString(chip, "OVERLAY")
	chip.text:SetJustifyH("RIGHT")
	chip.text:SetJustifyV("MIDDLE")
	chip.text:SetText(K.L["Targeted"])
	chip.chrome.ornament = K.Widgets.Ornament(chip, "corners", nil, true)
	chip.chrome.ornament.chrome, chip.chrome.ornament.inside = chip.chrome, { chip.gem, chip.name, chip.text }
	chip.chrome:SetShown(false)
	chip:Hide()
	return chip
end

local function Sigil()
	return running and Settings.Value("target", "enabled") and true or false
end

local function AuraParts(view)
	local a = view.auras
	if not (a and a.container) then
		return nil
	end
	local parts = ns.Auras.Parts(view)
	local filter = Settings.Value("target", "auraFilter")
	if not Settings.Value("target", "auras") or (filter ~= "both" and filter ~= Settings.Value(view.kind, "auraFilter")) then
		for _, part in ipairs(parts) do
			part:SetAlpha(1)
		end
		return nil
	end
	return parts
end

local function Size(frame)
	local w, h = frame:GetSize()
	if (issecretvalue and (issecretvalue(w) or issecretvalue(h))) or type(w) ~= "number" or type(h) ~= "number" then
		return nil
	end
	return w, h
end

local function Hit(view, folded)
	if InCombatLockdown() then
		return
	end
	local button = view.button
	local bw, bh = Size(button)
	local cw, ch = Size(view.chip)
	if folded and bw and cw then
		button:SetHitRectInsets(math.max(0, bw - cw), 0, 0, math.max(0, bh - ch))
	else
		button:SetHitRectInsets(0, 0, 0, 0)
	end
end

local function ChipFont(text, path, size, flags)
	if not K.Widgets.ApplyFont(text, path, size, flags) then
		K.Widgets.ApplyFont(text, (K.Tokens.Font("body")), size, flags)
	end
end

local function ChipText(view)
	local chip = view.chip
	local text, font = chip.name, chip.nameFont
	local name = UnitName and UnitName(view.unit)
	if not font then
		return
	end
	ChipFont(text, font[1], font[2], font[3])
	local style = view.s.fonts.name
	if style.colorMode ~= "" then K.Widgets.TextTint(text, style.colorMode, style.color, view.unit) end
	if style.textFormat ~= "" then
		K.Widgets.TagText(text, style.textFormat, view.unit)
		return
	end
	if issecretvalue and issecretvalue(name) then
		text:SetText(name)
		return
	elseif type(name) ~= "string" then
		text:SetText("")
		return
	end
	text:SetText(view.s.nameCaps and Unit.Tracked(name, font[1]) or name)
	local width = K.Widgets.TextWidth(text)
	if width and chip.room and width > chip.room then
		ChipFont(text, (K.Tokens.Font("body")), font[2], font[3])
		text:SetText(name)
	end
end

local function ChipName(view)
	ChipText(view)
	view.chip.chrome:RestyleOrnament()
end

function Frames.ChipName(view)
	if Sigil() and UnitExists(view.unit) then
		ChipName(view)
	end
end

local function MarkTarget(view)
	local chip, body = view.chip, view.body
	if not chip then
		return
	end
	local same = false
	if Sigil() and UnitExists(view.unit) then
		same = UnitIsUnit("target", view.unit)
		ChipName(view)
	end
	local auras = AuraParts(view) or {}
	if issecretvalue and issecretvalue(same) then
		chip:Show()
		chip:SetAlphaFromBoolean(same, 1, 0)
		body:SetAlphaFromBoolean(same, 0, 1)
		for _, part in ipairs(auras) do
			part:SetAlphaFromBoolean(same, 0, 1)
		end
		Hit(view, false)
		view.targeted = false
		Frames.Edge(view)
		return
	end
	same = same == true
	chip:SetAlpha(1)
	chip:SetShown(same)
	body:SetAlpha(same and 0 or 1)
	for _, part in ipairs(auras) do
		part:SetAlpha(same and 0 or 1)
	end
	Hit(view, same)
	view.targeted = same
	Frames.Edge(view)
end

local function OpenHits()
	local uf = frames.boss
	if uf then
		for _, view in ipairs(uf.views) do
			Hit(view, false)
		end
	end
end

function Frames.MarkTargets()
	local uf = frames.boss
	if not uf then
		return
	end
	for _, view in ipairs(uf.views) do
		MarkTarget(view)
	end
end

local function PlaceChip(view, width)
	local chip, button, Snap = view.chip, view.button, K.Widgets.Snap
	chip:ClearAllPoints()
	chip:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	local g = view.geometry
	chip:SetSize(Snap(button, width), Snap(button, g and (g.rest or g.glass.h) or CHIP_HEIGHT))
	local gem = ns.Geometry.GEM
	chip.gem:ClearAllPoints()
	chip.gem:SetPoint("LEFT", chip, "LEFT", Snap(button, CHIP_PAD), 0)
	chip.gem:SetSize(Snap(button, gem), Snap(button, gem))
	local path, size, flags = Settings.Font(view.kind, "cast")
	chip.text:ClearAllPoints()
	chip.text:SetPoint("RIGHT", chip, "RIGHT", -Snap(button, CHIP_PAD), 0)
	chip.text:SetHeight(Snap(button, CHIP_HEIGHT))
	ChipFont(chip.text, path, size, flags)
	chip.text:SetTextColor(ns.Lumen.Color("goldLit"))
	local namePath, _, nameFlags = Settings.Font(view.kind, "name")
	chip.nameFont = { namePath, size, nameFlags }
	chip.name:ClearAllPoints()
	chip.name:SetPoint("LEFT", chip.gem, "RIGHT", Snap(button, CHIP_GAP), 0)
	chip.name:SetPoint("RIGHT", chip.text, "LEFT", -Snap(button, CHIP_GAP), 0)
	chip.name:SetHeight(Snap(button, CHIP_HEIGHT))
	chip.name:SetTextColor(K.Tokens.Color("textEmphasis"))
	local label = K.Widgets.TextWidth(chip.text, #K.L["Targeted"] * size * CHIP_EM)
	chip.room = width - 2 * CHIP_PAD - gem - 2 * CHIP_GAP - label
	chip.chrome:RestyleOrnament()
end

local function Reach(view, g, width)
	local button, p = view.button, (g.form == "column" and g.portrait) or (g.form == "slab" and g.medal)
	if p then
		button:SetHitRectInsets(math.min(0, p.x), -math.max(0, p.x + p.w - width), 0, 0)
		view.reached = true
	elseif view.reached then
		button:SetHitRectInsets(0, 0, 0, 0)
		view.reached = false
	end
end

local function FitCard(view)
	local g = view.geometry
	if not (g and g.form == "card" and g.rest and g.cast) then
		return
	end
	local cb = view.castbar
	local open = cb ~= nil and (cb.active == true or cb.idle == true)
	view.panel:SetHeight(K.Widgets.Snap(view.parent, open and g.glass.h or g.rest))
end

local function NewView(uf, unit)
	local button = CreateFrame("Button", nil, uf.holder, "SecureUnitButtonTemplate")
	button:SetAttribute("unit", unit)
	button:SetAttribute("type1", "target")
	button:SetAttribute("type2", "togglemenu")
	button:RegisterForClicks("AnyUp")
	button.unit = unit
	button:HookScript("OnEnter", OnEnter)
	button:HookScript("OnLeave", OnLeave)
	local body
	if uf.kind == "boss" or uf.kind == "target" then
		body = CreateFrame("Frame", nil, uf.kind == "target" and uf.holder or button)
		if uf.kind == "target" then body:SetFrameLevel(button:GetFrameLevel()) end
		body:SetAllPoints(button)
	end
	local view = Style.New(body or button, uf.kind)
	view.button, view.unit, view.uf, view.body = button, unit, uf, body
	button.view = view
	button:HookScript("OnShow", OnButtonShow)
	button:HookScript("OnHide", OnButtonHide)
	if uf.kind == "boss" then
		view.chip = NewChip(button, view.chrome.shapeName)
	end
	if Settings.CASTBAR[uf.kind] and (uf.kind ~= "pet" or Settings.Value("pet", "castbar")) then
		local cb = ns.CastBars.Attach(view)
		cb.notify = function()
			FitCard(view)
		end
	end
	return view
end

local function Limits(kind)
	if kind == "boss" then
		return BOSS_LIMITS
	end
	return K.Setup.Layouts.Element(Settings.ELEMENTS[kind]).height < Geometry.FULL_MIN_HEIGHT and SMALL_LIMITS or FULL_LIMITS
end

local function ClampColumn(uf, left, bottom, width, height, rootWidth, rootHeight)
	if not (uf.s and uf.s.form == "column") then return end
	local view, Snap = uf.views[1], K.Widgets.Snap
	local g = view.geometry
	if not g then return end
	local p, trim = g.portrait, K.Tokens.Size("gapSmall")
	local reachLeft, reachRight = trim, trim
	if p then reachLeft, reachRight = math.max(trim, -Snap(view.button, p.x) + trim), math.max(trim, Snap(view.button, p.x) + Snap(view.button, p.w) - width + trim) end
	if g.aura and uf.s.auras and uf.s.auraPosition == "SIDE" then
		local host = view.auras and view.auras.host or view.button
		reachRight = math.max(reachRight, Snap(host, g.aura.x + uf.s.auraX) + ns.Auras.Footprint(uf.kind, host) - width)
	end
	local margin, origin, pixel = K.Tokens.Size("screenMargin"), K.Scale.Origin(), K.Scale.Pixel(1)
	if left - reachLeft < -origin then left = math.ceil((margin + reachLeft - origin) / pixel) * pixel
	elseif left + width + reachRight > rootWidth + origin then left = math.floor((rootWidth + origin - margin - width - reachRight) / pixel) * pixel end
	local inset = K.Tokens.Size("gapTiny")
	if bottom < margin + inset then bottom = math.ceil((margin + inset) / pixel) * pixel
	elseif bottom > rootHeight - margin - inset - height then bottom = math.floor((rootHeight - margin - inset - height) / pixel) * pixel end
	return left, bottom
end

local function Register(uf)
	local key = Settings.ELEMENTS[uf.kind]
	local element = K.Setup.Layouts.Element(key)
	local position = K.Setup.Layouts.Default(key)
	local holder = uf.holder
	holder:SetSize(element.width, element.height)
	holder:ClearAllPoints()
	holder:SetPoint(position.anchor, K.Scale.Root(), position.anchor, position.x, position.y)
	local Layout = K.Layout
	if not (Layout and Layout.Register) then
		Log("Layout.Register is missing; " .. key .. " keeps its default position")
		return
	end
	local limits = Limits(uf.kind)
	Layout.Register(holder, key, position, {
		label = element.label,
		clamp = function(...) return ClampColumn(uf, ...) end,
		module = MODULE,
		resizable = true,
		minWidth = limits.minWidth,
		minHeight = limits.minHeight,
		maxWidth = limits.maxWidth,
		maxHeight = limits.maxHeight,
	})
end

local function Build(kind)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	local uf = { kind = kind, holder = holder, views = {}, elapsed = 0, active = false }
	holder.uf = uf
	local count = kind == "boss" and BOSS_COUNT or 1
	for i = 1, count do
		local unit = kind == "boss" and ("boss" .. i) or kind
		uf.views[i] = NewView(uf, unit)
	end
	holder:HookScript("OnSizeChanged", function()
		Frames.Relayout(uf)
	end)
	frames[kind] = uf
	order[#order + 1] = kind
	Register(uf)
	return uf
end

local function Protected()
	return InCombatLockdown()
end

local function Queue(uf, field, fn)
	if uf[field] then
		return
	end
	uf[field] = true
	K.Combat.Queue(function()
		uf[field] = false
		fn(uf)
	end)
end

local function Slots(uf, w, h)
	if uf.kind == "boss" then
		return Geometry.Slots(BOSS_COUNT, uf.s and uf.s.gap or BOSS_GAP, w, h, uf.s and uf.s.growth == "UP")
	end
	return { { x = 0, y = 0, w = w, h = h } }
end

function Frames.Relayout(uf)
	if Protected() then
		Queue(uf, "layoutQueued", Frames.Relayout)
		return
	end
	local w, h = Size(uf.holder)
	if not (w and uf.s) then
		return
	end
	local slots = Slots(uf, w, h)
	local gap = CAST_GAP[uf.kind]
	local below = uf.s.form == "plate" or uf.s.form == "slab"
	local castH = gap and below and uf.s.castbar and uf.s.castbarHeight or 0
	for i, view in ipairs(uf.views) do
		local slot = slots[i]
		local button = view.button
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", uf.holder, "TOPLEFT", K.Widgets.Snap(button, slot.x), -K.Widgets.Snap(button, slot.y))
		K.Widgets.Size(button, slot.w, slot.h)
		local room = castH > 0 and math.min(castH, math.max(0, slot.h - gap - MIN_FRAME_HEIGHT)) or 0
		local frameH = room > 0 and slot.h - room - gap or slot.h
		local before = view.geometry or {}
		local g = Style.Layout(view, uf.s, slot.w, frameH)
		Reach(view, g, slot.w)
		if ((before.healthSub == nil) ~= (g.healthSub == nil) or before.compact ~= g.compact) and Active(view) and UnitExists(view.unit) then
			Unit.HealthColor(view, view.unit)
			Unit.Health(view, view.unit, true)
		end
		if (before.power == nil) ~= (g.power == nil) and Active(view) and UnitExists(view.unit) then
			Unit.Power(view, view.unit, true)
		end
		if view.tagged and Active(view) and UnitExists(view.unit) then
			Unit.TextTags(view, view.unit)
			Unit.BarIcon(view, view.unit)
		end
		if (uf.s.auraSimple or "") ~= "" then ns.Auras.Apply(view) else ns.Auras.Place(view) end
		local cb, cx, cy, cw, ch = view.castbar
		if cb and g.cast then
			cx, cy, cw, ch = g.cast.x, g.cast.y, g.cast.w, g.cast.h
		elseif cb and uf.kind == "pet" then
			cx, cy = g.panel.x, math.max(slot.h, g.medal and g.medal.y + g.medal.h or 0) + PET_CAST_GAP
			cw, ch = uf.s.castbarWidth > 0 and uf.s.castbarWidth or g.panel.w, uf.s.castbarHeight
		elseif cb and uf.s.inlineCast and (g.form == "slab" or g.form == "plate") then
			cx, cy, cw, ch = g.panel.x, slot.h + SLAB_CAST_GAP, g.panel.w, SLAB_CAST_H
		end
		if cx then
			cb.frame:ClearAllPoints()
			cb.frame:SetPoint("TOPLEFT", button, "TOPLEFT", K.Widgets.Snap(button, cx), -K.Widgets.Snap(button, cy))
			cb.frame:SetSize(K.Widgets.Snap(button, cw), K.Widgets.Snap(button, ch))
			cb.noRoom = false
			cb.frame:SetShown(cb.active == true or cb.idle == true)
			ns.CastBars.Layout(cb, cw, ch)
		elseif cb and gap and (g.form == "plate" or g.form == "slab") then
			cw = (uf.s.castbarWidth or 0) > 0 and math.min(uf.s.castbarWidth, g.panel.w) or g.panel.w
			cb.frame:ClearAllPoints()
			cb.frame:SetPoint("TOPLEFT", button, "TOPLEFT", g.panel.x, -(frameH + gap))
			cb.frame:SetSize(cw, room)
			cb.noRoom = room <= 0
			cb.frame:SetShown(room > 0 and (cb.active == true or cb.idle == true))
			ns.CastBars.Layout(cb, cw, room)
		elseif cb then
			cb.noRoom = true
			cb.frame:Hide()
		end
		FitCard(view)
		if view.chip then
			PlaceChip(view, slot.w)
			MarkTarget(view)
		end
	end
	if uf.kind == "player" then
		ns.Dispel.Apply(uf.views[1])
		ns.Totems.Apply(uf)
	end
	return true
end

local function PrepareTarget(view)
	if view.kind ~= "target" then return end
	if view.deathTween then
		K.Motion.Stop(view.deathTween)
		view.deathTween = nil
		view.medallion:SetDead(view.slabDead == true)
	end
	K.Motion.Tween(view.body, "SetAlpha", view.body:GetAlpha(), 1, 0)
	view.body:SetShown(view.button:IsShown())
	view.targetSeen = UnitExists("target") and true or false
end

local function TargetChange(view)
	local exists = view and view.body and UnitExists("target")
	if exists then
		local on, seen = TargetTransitions(view), view.targetSeen
		view.targetSeen = true
		if view.deathTween then K.Motion.Stop(view.deathTween); view.deathTween = nil end
		if on and seen then
			view.flipIn = view.flipIn or function()
				RefreshKind("target", true)
				ns.Slab.FlipIn(view)
				K.Motion.FadeIn(view.body, 0.06)
			end
			K.Motion.Tween(view.body, "SetAlpha", view.body:GetAlpha(), 0, 0.06, "inOutSine", view.flipIn)
			return
		elseif on then
			K.Motion.FadeIn(view.body, 0.12)
		else
			K.Motion.Tween(view.body, "SetAlpha", view.body:GetAlpha(), 1, 0)
			view.body:Show()
		end
	end
	RefreshKind("target", true)
	if exists then ns.Slab.FlipIn(view) end
end

local castsHeard = false
local function OnCast(event, _, castGUID, spellID)
	local uf = frames.player
	if not (running and uf and uf.active) then return end
	local view = uf.views[1]
	if event == "UNIT_SPELLCAST_START" then
		view.costCast = not issecretvalue(castGUID) and castGUID or nil
		Unit.Cost(view, spellID)
	elseif issecretvalue(castGUID) or view.costCast == nil or castGUID == view.costCast then
		view.costCast = nil
		Unit.Cost(view)
	end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then Unit.Spark(view, spellID) end
end

local function HearCasts()
	local uf = frames.player
	local on = running and uf and uf.active and uf.s and (uf.s.powerCost or uf.s.manaSpark) and true or false
	if on == castsHeard then return end
	castsHeard = on
	for _, event in ipairs(CAST_EVENTS) do
		if on then
			K.Events.RegisterUnit(CAST_OWNER, event, OnCast, "player")
		else
			K.Events.Unregister(CAST_OWNER, event)
		end
	end
end

local function HearLoss(view)
	local on = view.s.maxHealthLoss and view.handler and not POLLED[view.uf.kind] and Active(view) and true or false
	if on ~= (view.hearsLoss == true) then
		view.hearsLoss = on
		if on then
			K.Events.RegisterUnit(Owner(view.unit), LOSS_EVENT, view.handler, view.unit)
		else
			K.Events.Unregister(Owner(view.unit), LOSS_EVENT)
		end
	end
end

function Frames.Restyle(uf)
	uf.s = Settings.Snapshot(uf.kind)
	if uf.kind == "pet" and uf.s.castbar and not uf.views[1].castbar then ns.CastBars.Attach(uf.views[1]) end
	for _, view in ipairs(uf.views) do
		view.s = uf.s
		Style.Restyle(view, uf.kind)
		if view.hearsLoss or uf.s.maxHealthLoss then HearLoss(view) end
	end
	if uf.kind == "player" then
		HearCasts()
		if not uf.s.powerCost then Unit.Cost(uf.views[1]) end
		Unit.Spark(uf.views[1])
	end
	local applied = Frames.Relayout(uf) and (uf.s.auraSimple or "") ~= ""
	for _, view in ipairs(uf.views) do
		PrepareTarget(view)
		Refresh(view, true)
		if not applied then ns.Auras.Apply(view) end
	end
end

local function RegisterUnitEvents(view)
	if POLLED[view.uf.kind] then
		return
	end
	local owner = Owner(view.unit)
	local handler = view.handler
	if not handler then
		handler = function(event)
			local name = event == LOSS_EVENT and "MaxHealth" or UNIT_EVENTS[event]
			if name and Active(view) then
				HANDLERS[name](view, view.unit)
				Unit.TextTags(view, view.unit, name)
			end
		end
		view.handler = handler
	end
	for event in pairs(UNIT_EVENTS) do
		K.Events.RegisterUnit(owner, event, handler, view.unit)
	end
end

function Frames.Apply(uf)
	local want = running and Settings.Value(uf.kind, "enabled")
	if Protected() then
		Queue(uf, "applyQueued", Frames.Apply)
		return
	end
	uf.active = want and true or false
	local Layout = K.Layout
	if Layout and Layout.SetLive and Settings.ELEMENTS[uf.kind] then
		Layout.SetLive(Settings.ELEMENTS[uf.kind], uf.active)
	end
	if want and uf.hiddenByModule then
		uf.hiddenByModule = false
		uf.holder:Show()
	end
	for _, view in ipairs(uf.views) do
		local button = view.button
		if want then
			RegisterUnitEvents(view)
			RegisterUnitWatch(button)
		else
			UnregisterUnitWatch(button)
			button:Hide()
			TargetLoss(view)
			K.Events.UnregisterAll(Owner(view.unit))
			view.hearsLoss = false
		end
	end
	if want then
		Frames.Restyle(uf)
	end
	if want and Visible(uf.views[1].button) then
		StartPolling(uf)
	elseif not want then
		StopPolling(uf)
		if uf.kind == "player" then HearCasts() end
		for _, view in ipairs(uf.views) do
			ns.Auras.Apply(view)
		end
		if uf.kind == "player" then
			ns.Dispel.Apply(uf.views[1])
			ns.Totems.Apply(uf)
		end
	end
end

local function ForEach(fn)
	for _, kind in ipairs(order) do
		fn(frames[kind])
	end
end

local REACTION_KEYS = { reactionColors = true, hostileColor = true, neutralColor = true, friendlyColor = true, tappedColor = true }

local function PlaceCasts()
	for kind in pairs(Settings.CAST_ELEMENTS) do
		if frames[kind] and frames[kind].active then Frames.Restyle(frames[kind]) end
	end
	ns.CastBars.Apply()
end

local function OnSettingChanged(_, module, key)
	if module ~= MODULE then
		return
	end
	local kind, rest = key:match("^(%w+)%.(.+)$")
	local uf = kind and frames[kind]
	if uf then
		if rest == "enabled" then
			Frames.Apply(uf)
			ns.CastBars.Apply()
			ns.Blizzard.Apply(running)
		elseif uf.active then
			Frames.Restyle(uf)
			if rest == "rangeFade" then for _, view in ipairs(uf.views) do Frames.Range(view) end end
		end
		if Settings.AURA_LOOK[rest] or Settings.LISTS[rest] or rest == "style" or rest == "auraLists" then
			ForEach(function(each)
				if each ~= uf and each.active and (Settings.Value(each.kind, "auraCopy") == kind or Settings.Lists(each.kind) == Settings.Lists(kind)) then Frames.Restyle(each) end
			end)
		end
		if kind == "target" then
			Frames.MarkTargets()
		end
		if rest == "powerMana" then ns.Resource.Restyle() end
		if rest == "style" or rest:find("^castbar") or rest:find("^fonts%.cast") then
			ns.CastBars.Apply()
			ns.Blizzard.Apply(running)
		end
		return
	end
	if kind == "resource" then
		ns.Resource.Restyle()
	elseif REACTION_KEYS[key:match("^%a+")] then
		ForEach(function(each) RefreshKind(each.kind, true) end)
	elseif key == "auraLayout" or key == "stableSlabNames" or key == "singleSlabLevel" or key == "healthDecimal" or key == "healthDecimalBoss" or key == "healthDecimalTrim" or key == "healthDecimalPercentOnly" then
		K.Combat.Queue(function()
			ForEach(function(each)
				if each.active then Frames.Restyle(each) end
			end)
		end)
	elseif key:find("^dispel") then
		ForEach(function(each)
			if each.active then Frames.Restyle(each) end
		end)
	elseif key == "hideBlizzard" then
		ns.Blizzard.Apply(running)
	elseif key == "castbarOnFrame" then
		K.Combat.Queue(PlaceCasts)
	elseif key == "castbarRaise" then
		K.Combat.Queue(ns.CastBars.Apply)
	elseif key == "unitTooltip" then
		if hovered then Tooltip(hovered, InCombatLockdown()) end
	elseif key == "cleanLowRing" then
		ForEach(function(each)
			if each.active then
				for _, view in ipairs(each.views) do
					ns.Slab.Colors(view, view.unit)
					ns.Slab.Health(view, view.unit)
				end
			end
		end)
	elseif key == "accent" or key == "accentColor" then
		ForEach(function(each)
			for _, view in ipairs(each.views) do
				Style.Accent(view)
				Frames.Edge(view)
			end
		end)
	end
end

local function RestyleAll()
	ForEach(function(uf)
		if uf.active then
			Frames.Restyle(uf)
		end
	end)
	ns.Resource.Restyle()
	ns.CastBars.Apply()
end

local function OnHudStyleChanged()
	Frames.Apply(frames.player)
	RestyleAll()
	ns.Blizzard.Apply(running)
end

local function OnProfileChanged()
	ForEach(Frames.Apply)
	ns.Resource.Restyle()
	ns.CastBars.Apply()
	ns.Blizzard.Apply(running)
end

local function OnLayoutChanged(_, key, reason)
	if reason == "scale" then return end
	if key == ns.Fan.KEY and frames.target and frames.target.views[1].auras then
		ns.Auras.Apply(frames.target.views[1])
	end
	if key == ns.Resource.KEY then
		ns.Resource.Layout()
	end
	for kind, castKey in pairs(Settings.CAST_ELEMENTS) do
		if key == castKey then
			ns.CastBars.LayoutElement(kind)
			local uf = frames[kind]
			if uf and uf.active and uf.s and K.HudStyle.Current() == "medallions" and uf.s.inlineCast ~= Settings.CastOnFrame(kind) then
				K.Combat.Queue(PlaceCasts)
			end
		end
	end
	ForEach(function(uf)
		if Settings.ELEMENTS[uf.kind] == key and uf.active then
			Frames.Relayout(uf)
		end
	end)
end

local function RefreshRestricted()
	if K.HudStyle.Current() == "medallions" then
		EachShown(ns.Slab.Refresh)
	end
	EachShown(Indicators.Threat)
end

local function OnRestriction(_, _, state)
	local states = Enum and Enum.AddOnRestrictionState
	local activating = states and states.Activating
	if activating ~= nil and not (issecretvalue and issecretvalue(state)) and state == activating and C_Timer and C_Timer.After then
		C_Timer.After(0, RefreshRestricted)
		return
	end
	RefreshRestricted()
end

local function RegisterEvents()
	local Events = K.Events
	Events.Register(MODULE, "PLAYER_TARGET_CHANGED", function()
		TargetChange(frames.target and frames.target.views[1])
		RefreshKind("targettarget", true)
		Frames.MarkTargets()
		EachShown(Frames.Edge)
		ns.Blizzard.TargetSound()
	end)
	Events.Register(MODULE, "PLAYER_FOCUS_CHANGED", function()
		RefreshKind("focus", true)
		RefreshKind("focustarget", true)
	end)
	Events.RegisterUnit(MODULE, "UNIT_TARGET", function(_, unit)
		RefreshKind(unit == "focus" and "focustarget" or "targettarget", true)
	end, "target", "focus")
	Events.RegisterUnit(MODULE, "UNIT_PET", function()
		RefreshKind("pet", true)
	end, "player")
	Events.RegisterUnit(MODULE, "UNIT_HAPPINESS", function()
		local uf = frames.pet
		if running and uf and uf.active then Indicators.Extra(uf.views[1], "pet") end
	end, "pet")
	Events.Register(MODULE, "INSTANCE_ENCOUNTER_ENGAGE_UNIT", function()
		RefreshKind("boss", true)
		Frames.MarkTargets()
	end)
	Events.Register(MODULE, "UNIT_TARGETABLE_CHANGED", function(_, unit)
		if type(unit) == "string" and not (issecretvalue and issecretvalue(unit)) and not unit:match("^boss[1-8]$") then
			return
		end
		RefreshKind("boss", true)
		Frames.MarkTargets()
	end)
	Events.Register(MODULE, "RAID_TARGET_UPDATE", function()
		EachShown(Indicators.Marker)
	end)
	for _, event in ipairs({ "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }) do
		Events.Register(MODULE, event, function()
			EachShown(Indicators.Status)
			EachShown(function(view, unit) Unit.TextTags(view, unit, "Group") end)
			OnPlayer(Indicators.Threat)
		end)
	end
	Events.Register(MODULE, "ADDON_RESTRICTION_STATE_CHANGED", OnRestriction)
	Events.Register(MODULE, "PVP_TIMER_UPDATE", function()
		OnPlayer(Indicators.PvP)
	end)
	Events.Register(MODULE, "UNIT_THREAT_SITUATION_UPDATE", OnThreat)
	Events.Register(MODULE, "UNIT_THREAT_LIST_UPDATE", OnThreat)
	Events.Register(MODULE, "PLAYER_REGEN_DISABLED", function()
		OnPlayer(Indicators.Combat)
		OpenHits()
		if hovered then Tooltip(hovered, true) end
	end)
	Events.Register(MODULE, "PLAYER_REGEN_ENABLED", function()
		OnPlayer(Indicators.Combat)
		Frames.MarkTargets()
		if hovered then Tooltip(hovered, false) end
	end)
	Events.Register(MODULE, "PLAYER_UPDATE_RESTING", function()
		OnPlayer(Indicators.Resting)
	end)
	for _, event in ipairs({ "UPDATE_SHAPESHIFT_FORM", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" }) do
		Events.Register(MODULE, event, function()
			OnPlayer(Unit.Caption)
		end)
	end
	Events.Register(MODULE, "PLAYER_ENTERING_WORLD", function()
		ForEach(function(uf)
			RefreshKind(uf.kind, true)
		end)
	end)
	local Callbacks = K.Callbacks
	Callbacks.Register("SettingChanged", MODULE, OnSettingChanged)
	Callbacks.Register("ThemeChanged", MODULE, RestyleAll)
	Callbacks.Register("ScaleChanged", MODULE, RestyleAll)
	Callbacks.Register("ProfileChanged", MODULE, OnProfileChanged)
	Callbacks.Register("LayoutChanged", MODULE, OnLayoutChanged)
	Callbacks.Register("HudStyleChanged", MODULE, OnHudStyleChanged)
end

function Frames.Enable()
	running = true
	if #order == 0 then
		for _, kind in ipairs(Settings.KINDS) do
			Build(kind)
		end
		ns.CastBars.Build()
		Log("built " .. #order .. " unit frames")
	end
	RegisterEvents()
	ns.Auras.Enable()
	ForEach(Frames.Apply)
	ns.Resource.Enable()
	ns.CastBars.Enable()
	ns.Blizzard.Apply(true)
end

function Frames.Disable()
	running = false
	ForEach(function(uf)
		Frames.Apply(uf)
		if not Protected() then
			uf.holder:Hide()
			uf.hiddenByModule = true
		end
	end)
	ns.Resource.Disable()
	ns.CastBars.Disable()
	ns.Auras.Disable()
	ns.Blizzard.Apply(false)
end

function Frames.Get(kind)
	return frames[kind]
end

function Frames.IsRunning()
	return running
end
