-- Frames.lua: the secure unit buttons for each frame, their Layout elements, unit watches and events; the boss you target folds its card to a Targeted chip in the resting card's place and glass, which out of combat is all of the card that takes clicks, and a card with no cast hugs its pill.
local _, ns = ...

local K = KstyleUI
local Settings, Geometry, Style, Unit, Indicators = ns.Settings, ns.Geometry, ns.Style, ns.Unit, ns.Indicators

local Frames = {}
ns.Frames = Frames

local MODULE = Settings.MODULE
local BOSS_COUNT, BOSS_GAP = Geometry.BOSS_COUNT, Geometry.BOSS_GAP
local CAST_GAP = { focus = 4, boss = 2 }
local MIN_FRAME_HEIGHT = 20
local POLL_INTERVAL = 0.2
local CHIP_LEVEL, CHIP_GAP, CHIP_HEIGHT, CHIP_PAD, CHIP_EM = 9, 6, 20, 10, 0.62

local FULL_LIMITS = { minWidth = 120, minHeight = 24, maxWidth = 640, maxHeight = 160 }
local SMALL_LIMITS = { minWidth = 60, minHeight = 14, maxWidth = 400, maxHeight = 120 }
local BOSS_LIMITS = { minWidth = 120, minHeight = 100, maxWidth = 640, maxHeight = 800 }

local POLLED = { targettarget = true, focustarget = true }

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
	end,
	Portrait = function(view, unit)
		Unit.Portrait(view, unit)
	end,
	Colors = function(view, unit)
		Unit.HealthColor(view, unit)
		Unit.Health(view, unit)
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

local function Refresh(view, instant)
	if Active(view) then
		Unit.All(view, view.unit, instant)
		Frames.Range(view)
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

local function OnEnter(button)
	if UnitFrame_OnEnter then
		UnitFrame_OnEnter(button)
	end
end

local function OnLeave(button)
	if UnitFrame_OnLeave then
		UnitFrame_OnLeave(button)
	end
end

local function Poll(uf)
	local view = uf.views[1]
	if Active(view) and UnitExists(view.unit) then
		Unit.Health(view, view.unit, true)
		Unit.Power(view, view.unit, true)
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
	if view.targetGhost then HideBody(view.targetGhost.parent) end
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
	local open = cb ~= nil and cb.active == true
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
	if Settings.CASTBAR[uf.kind] then
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
		return Geometry.Slots(BOSS_COUNT, BOSS_GAP, w, h, uf.s and uf.s.growth == "UP")
	end
	return { { x = 0, y = 0, w = w, h = h } }
end

local function Extent(uf)
	local view = uf.views[1]
	local g, button = view.geometry, view.button
	local Snap = K.Widgets.Snap
	local p = g.portrait or g.medal
	local width = Snap(button, g.panel.w)
	local left, right = 0, 0
	if p then
		left = math.max(0, -Snap(button, p.x))
		right = math.max(0, Snap(button, p.x) + Snap(button, p.w) - width)
	end
	if g.aura and uf.s.auras and uf.s.auraPosition == "SIDE" then
		local host = view.auras and view.auras.host or button
		local row = ns.Auras.Footprint(uf.kind, host)
		right = math.max(right, Snap(host, g.aura.x) + row - width)
	end
	return left, right
end

local function Keep(uf)
	local Layout = K.Layout
	if uf.s.form ~= "column" or uf.keeping or not (Layout and Layout.Rect and Layout.Get and Layout.Set and Layout.RootSize) then
		return
	end
	local key = Settings.ELEMENTS[uf.kind]
	local left, _, w = Layout.Rect(key)
	local saved = Layout.Get(key)
	if not (left and saved and type(saved.x) == "number") then
		return
	end
	local reachLeft, reachRight = Extent(uf)
	local rootW = Layout.RootSize()
	local shift = 0
	if left - reachLeft < 0 then
		shift = reachLeft - left
	elseif left + w + reachRight > rootW then
		shift = rootW - (left + w + reachRight)
	end
	if shift == 0 then
		return
	end
	uf.keeping = true
	K.Combat.Queue(function()
		Layout.Set(key, "x", saved.x + shift)
		uf.keeping = false
	end)
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
		ns.Auras.Place(view)
		local cb = view.castbar
		if cb and g.cast then
			local c = g.cast
			cb.frame:ClearAllPoints()
			cb.frame:SetPoint("TOPLEFT", button, "TOPLEFT", K.Widgets.Snap(button, c.x), -K.Widgets.Snap(button, c.y))
			cb.frame:SetSize(K.Widgets.Snap(button, c.w), K.Widgets.Snap(button, c.h))
			cb.noRoom = false
			cb.frame:SetShown(cb.active == true)
			ns.CastBars.Layout(cb, c.w, c.h)
		elseif cb and gap and (g.form == "plate" or g.form == "slab") then
			cb.frame:ClearAllPoints()
			cb.frame:SetPoint("TOPLEFT", button, "TOPLEFT", g.panel.x, -(frameH + gap))
			cb.frame:SetSize(g.panel.w, room)
			cb.noRoom = room <= 0
			cb.frame:SetShown(room > 0 and cb.active == true)
			ns.CastBars.Layout(cb, g.panel.w, room)
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
	Keep(uf)
end

local function PrepareTarget(view)
	if view.kind ~= "target" then return end
	local ghost = view.targetGhost
	if TargetTransitions(view) then
		if not ghost then
			local body = CreateFrame("Frame", nil, view.uf.holder)
			body:SetFrameLevel(view.body:GetFrameLevel())
			body:SetAllPoints(view.button)
			ghost = Style.New(body, "target")
			ghost.body = body
			view.targetGhost = ghost
		end
		ghost.s = view.s
		Style.Restyle(ghost, "target")
		Style.Layout(ghost, view.s, view.button:GetSize())
		view.targetKeys = {}
		for key in pairs(ghost) do view.targetKeys[#view.targetKeys + 1] = key end
	end
	if ghost then K.Motion.Tween(ghost.parent, "SetAlpha", 1, 0, 0, nil, HideBody) end
	K.Motion.Tween(view.body, "SetAlpha", view.body:GetAlpha(), 1, 0)
	view.body:SetShown(view.button:IsShown())
	view.targetSeen = UnitExists("target") and true or false
end

local function TargetChange(view)
	if not view or not view.body then return end
	if not UnitExists("target") then return end
	local on = TargetTransitions(view)
	if on and view.targetSeen and view.targetGhost then
		if view.deathTween then K.Motion.Stop(view.deathTween); view.deathTween = nil end
		local ghost = view.targetGhost
		Style.Layout(ghost, view.s, view.button:GetSize())
		for _, key in ipairs(view.targetKeys) do view[key], ghost[key] = ghost[key], view[key] end
		ghost.health:SetHealthUnit(nil)
		ghost.medallion:LowHealth(nil)
		K.Motion.Tween(ghost.parent, "SetAlpha", ghost.parent:GetAlpha(), 0, 0.12, "inOutSine", HideBody)
		view.medallion:SetDead(false)
		view.slabDead = false
		if view.castbar then view.castbar.frame:SetParent(view.body) end
		K.Motion.FadeIn(view.body, 0.12)
	elseif on then
		K.Motion.FadeIn(view.body, 0.12)
	else
		K.Motion.Tween(view.body, "SetAlpha", view.body:GetAlpha(), 1, 0)
		view.body:Show()
	end
	view.targetSeen = true
end

function Frames.Restyle(uf)
	uf.s = Settings.Snapshot(uf.kind)
	for _, view in ipairs(uf.views) do
		view.s = uf.s
		Style.Restyle(view, uf.kind)
	end
	Frames.Relayout(uf)
	for _, view in ipairs(uf.views) do
		PrepareTarget(view)
		Refresh(view, true)
		ns.Auras.Apply(view)
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
			local name = UNIT_EVENTS[event]
			if name and Active(view) then
				HANDLERS[name](view, view.unit)
			end
		end
		view.handler = handler
	end
	for event in pairs(UNIT_EVENTS) do
		K.Events.RegisterUnit(owner, event, handler, view.unit)
	end
end

function Frames.Apply(uf)
	local want = running and Settings.Value(uf.kind, "enabled") and not (uf.kind == "player" and ns.Orbs.Active())
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
		end
	end
	if want then
		Frames.Restyle(uf)
	end
	if want and Visible(uf.views[1].button) then
		StartPolling(uf)
	elseif not want then
		StopPolling(uf)
		for _, view in ipairs(uf.views) do
			ns.Auras.Apply(view)
		end
	end
end

local function ForEach(fn)
	for _, kind in ipairs(order) do
		fn(frames[kind])
	end
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
		if kind == "target" then
			Frames.MarkTargets()
		end
		if rest == "style" or rest:find("^castbar") or rest:find("^fonts%.cast") then
			ns.CastBars.Apply()
			ns.Blizzard.Apply(running)
		end
		return
	end
	if kind == "resource" then
		ns.Resource.Restyle()
	elseif key == "stableSlabNames" or key == "singleSlabLevel" then
		K.Combat.Queue(function()
			ForEach(function(each)
				if each.active then Frames.Restyle(each) end
			end)
		end)
	elseif key == "hideBlizzard" then
		ns.Blizzard.Apply(running)
	elseif key == "orbCastRoom" then
		ns.CastBars.Apply()
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
	ns.Orbs.Apply()
	Frames.Apply(frames.player)
	RestyleAll()
	ns.Blizzard.Apply(running)
end

local function OnProfileChanged()
	ns.Orbs.Apply()
	ForEach(Frames.Apply)
	ns.Resource.Restyle()
	ns.CastBars.Apply()
	ns.Blizzard.Apply(running)
end

local function OnLayoutChanged(_, key)
	if key == ns.Fan.KEY and frames.target and frames.target.views[1].auras then
		ns.Auras.Apply(frames.target.views[1])
	end
	if key == ns.Resource.KEY then
		ns.Resource.Layout()
	end
	for kind, castKey in pairs(Settings.CAST_ELEMENTS) do
		if key == castKey then
			ns.CastBars.LayoutElement(kind)
		end
	end
	ForEach(function(uf)
		if Settings.ELEMENTS[uf.kind] == key and uf.active then
			Frames.Relayout(uf)
		end
	end)
end

local function RefreshIdentity()
	if K.HudStyle.Current() == "medallions" then
		EachShown(ns.Slab.Refresh)
	end
end

local function OnRestriction(_, _, state)
	local states = Enum and Enum.AddOnRestrictionState
	local activating = states and states.Activating
	if activating ~= nil and not (issecretvalue and issecretvalue(state)) and state == activating and C_Timer and C_Timer.After then
		C_Timer.After(0, RefreshIdentity)
		return
	end
	RefreshIdentity()
end

local function RegisterEvents()
	local Events = K.Events
	Events.Register(MODULE, "PLAYER_TARGET_CHANGED", function()
		TargetChange(frames.target and frames.target.views[1])
		RefreshKind("target", true)
		if frames.target and UnitExists("target") then
			ns.Slab.FlipIn(frames.target.views[1])
		end
		RefreshKind("targettarget", true)
		Frames.MarkTargets()
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
		end)
	end
	Events.Register(MODULE, "ADDON_RESTRICTION_STATE_CHANGED", OnRestriction)
	Events.Register(MODULE, "UNIT_THREAT_SITUATION_UPDATE", OnThreat)
	Events.Register(MODULE, "UNIT_THREAT_LIST_UPDATE", OnThreat)
	Events.Register(MODULE, "PLAYER_REGEN_DISABLED", function()
		OnPlayer(Indicators.Combat)
		OpenHits()
	end)
	Events.Register(MODULE, "PLAYER_REGEN_ENABLED", function()
		OnPlayer(Indicators.Combat)
		Frames.MarkTargets()
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
		Log("built " .. #order .. " unit frames")
	end
	RegisterEvents()
	ns.Auras.Enable()
	ns.Orbs.Enable()
	ForEach(Frames.Apply)
	ns.Resource.Enable()
	ns.CastBars.Enable()
	ns.Blizzard.Apply(true)
end

function Frames.Disable()
	running = false
	ns.Orbs.Disable()
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
