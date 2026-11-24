-- SlabTarget.lua: the crest's two target effects (docs/medallions-effects.md#target-effects): Kill window, a tracker row, burns the foot of the inner rim red-hot while the target is in the class's execute range (UnitHealthPercent through a step curve into its alpha, so Lua never reads the health), ripples as the value crosses the line and beats; Target lock closes four gilt claws round the ring on a new hostile target and lights the top gem in the target's rank, built with the hub for every class.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local IsSecret = Widgets.IsSecret
local Medals, Trackers, Fade = ns.SlabMedals, ns.SlabTrackers, ns.Slab.Fade

local Target = {}
ns.SlabTarget = Target

local OWNER = "ActionBars.SlabTarget"
local EXECUTE = { WARRIOR = { 20662, 20661, 20660, 20658, 5308 }, PALADIN = { 24275, 24274, 24239 } }
local LINE, CUT, INNER, BLAZE, RIPPLE = 0.2, 25.2, 112, 140, 1.22
local FADE_IN, RIPPLE_RUN, BEAT, BEAT_LOW = 0.2, 0.4, 0.4, 0.7
local CLAWS, CLAW, SHUT, CLOSE, HOLD, GO = 165, 0.3, 1.15, 0.2, 0.3, 0.3
local RANKS = { elite = "gilt", rare = "steelLit", rareelite = "steelLit", worldboss = "plateHostile" }
local pieces, listening, curve = {}, {}, nil
Target.pieces = pieces

local function Curve()
	local util = C_CurveUtil
	if curve or not (util and type(util.CreateCurve) == "function" and UnitHealthPercent) then
		return curve
	end
	curve = util.CreateCurve()
	local kinds = Enum and Enum.LuaCurveType
	if kinds and kinds.Step and curve.SetType then
		curve:SetType(kinds.Step)
	end
	curve:AddPoint(0, 1)
	curve:AddPoint(LINE, 0)
	curve:AddPoint(1, 0)
	return curve
end

local function Hostile()
	local can = UnitCanAttack and UnitCanAttack("player", "target")
	local dead = UnitIsDead and UnitIsDead("target")
	return not IsSecret(can) and can == true and not (not IsSecret(dead) and dead == true)
end

local function Play(group, kind)
	group:Stop()
	if Effects.Allows(kind) then
		group:Play()
	end
end

local function Burn(k, event)
	local step = Hostile() and Curve()
	if not step and k.dark or event and not k:IsVisible() then
		return
	end
	k.dark = not step
	local value = step and UnitHealthPercent("target", true, step) or 0
	k.gate:SetAlpha(value)
	k.feed:SetValue(value)
	if not (step and Effects.Allows("pulse")) then
		k.beat.play:Stop()
	elseif not k.beat.play:IsPlaying() then
		k.beat.play:Play()
	end
end

local function Rank()
	local level = UnitLevel and UnitLevel("target")
	if not IsSecret(level) and type(level) == "number" and level <= 0 then
		return "plateHostile"
	end
	local rank = UnitClassification and UnitClassification("target")
	return not IsSecret(rank) and RANKS[rank] or "steel"
end

local function TopFree()
	if (ns.SlabJewels.state.count or 0) > 0 then
		return false
	end
	local form = Trackers.state.forms.crest
	for _, p in pairs(form and form.pieces or {}) do
		if p.spec.seat == "topGem" and p:IsShown() then
			return false
		end
	end
	return true
end

local function Lock(l, event)
	local hostile = Hostile()
	if not (hostile or l.hostile) or event and not l:IsVisible() then
		return
	end
	l.hostile = hostile
	local shown, rank = hostile and TopFree(), hostile and Rank()
	if l.shown ~= shown then
		l.shown = shown
		l.gem:SetShown(shown)
	end
	if rank and l.rank ~= rank then
		l.rank = rank
		l.stone:SetVertexColor(Tokens.Color(rank))
	end
	if event == "PLAYER_TARGET_CHANGED" and hostile and Effects.Allows("flare") and Effects.ClaimFor("hub", Effects.PRIORITY.target, CLOSE + HOLD + GO, l.claws.stop) then
		Play(l.claws.play, "flare")
	end
end

local function Paint(event)
	for _, p in ipairs(pieces) do
		p.paint(p, event)
	end
end

local function Listen(event, unit)
	if not listening[event] then
		listening[event] = true
		if unit then
			K.Events.RegisterUnit(OWNER, event, Paint, unit)
		else
			K.Events.Register(OWNER, event, Paint)
		end
	end
end

local function Arc(parent, token, color, size, blend, fade)
	local t = parent:CreateTexture(nil, "ARTWORK")
	local share = 0.5 - CUT / size
	local r, g, b = Tokens.Color(color)
	t:SetTexture((Tokens.Texture(token)))
	if fade and t.SetGradient and CreateColor then
		t:SetGradient("VERTICAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, fade))
	else
		t:SetVertexColor(r, g, b)
	end
	t:SetBlendMode(blend)
	t:SetTexCoord(0, 1, 1 - share, 1)
	t:SetPoint("BOTTOM", parent, "CENTER", 0, -size / 2)
	t:SetSize(size, size * share)
	return t
end

local function Kill(parent, _, level, form)
	local k = Medals.Piece(parent, level, Medals.SIZE)
	k.gate = Medals.Layer(k, level)
	k.fade = Medals.Layer(k.gate, level)
	k.beat = Medals.Layer(k.fade, level)
	if form == "crest" then
		Arc(k.beat, "medLowHealthRing", "white", BLAZE, "ADD", 0.5)
		Arc(k.beat, "ringLine16", "hostile", INNER, "ADD")
		k.ripple = Medals.Layer(k.gate, level)
		Arc(k.ripple, "ringLine16", "hostile", INNER, "ADD")
		k.ripple:SetAlpha(0)
		k.ripple.play = k.ripple:CreateAnimationGroup()
		local grow = k.ripple.play:CreateAnimation("Scale")
		grow:SetScaleFrom(1, 1)
		grow:SetScaleTo(RIPPLE, RIPPLE)
		grow:SetDuration(RIPPLE_RUN)
		grow:SetSmoothing("OUT")
		Fade(k.ripple.play, 1, 0, RIPPLE_RUN, 1):SetSmoothing("OUT")
	else
		local line = k.beat:CreateTexture(nil, "ARTWORK")
		line:SetTexture((Tokens.Texture("barFlat")))
		line:SetVertexColor(Tokens.Color("hostile"))
		line:SetPoint("CENTER", k, "CENTER", 0, 0)
		line:SetSize(Medals.LINE * Medals.SIZE + (Medals.LINE - 1) * Medals.GAP, 2)
	end
	k.fade.play = k.fade:CreateAnimationGroup()
	Fade(k.fade.play, 0, 1, FADE_IN, 1):SetSmoothing("OUT")
	k.beat.play = k.beat:CreateAnimationGroup()
	k.beat.play:SetLooping("BOUNCE")
	Fade(k.beat.play, 1, BEAT_LOW, BEAT, 1):SetSmoothing("IN_OUT")
	k.feed = CreateFrame("StatusBar", nil, k)
	k.feed:SetMinMaxValues(0, 1)
	k.feed:SetValue(0)
	k.feed:SetScript("OnValueChanged", function()
		Play(k.fade.play, "flare")
		if k.ripple then
			Play(k.ripple.play, "flare")
		end
	end)
	k.paint = Burn
	pieces[#pieces + 1] = k
	Listen("PLAYER_TARGET_CHANGED")
	Listen("UNIT_HEALTH", "target")
	return k
end

local function PlaceKill(k, anchor, form, _, n)
	if k.anchor ~= anchor then
		k.anchor = anchor
		local row = form == "row" and Medals.SIZE + Medals.GAP or 0
		Medals.Place(k, anchor, (Medals.LINE - 1) * row / 2, -row / 2)
	end
	Burn(k)
	return n
end

local function Claws(l, level)
	local c = Medals.Layer(l, level)
	c:ClearAllPoints()
	c:SetPoint("CENTER", l, "CENTER", 0, 0)
	c:SetSize(CLAWS, CLAWS)
	c:SetAlpha(0)
	for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
		local t = c:CreateTexture(nil, "ARTWORK")
		local u, v = corner:find("LEFT") and 0 or 1 - CLAW, corner:find("TOP") and 0 or 1 - CLAW
		t:SetTexture((Tokens.Texture("ringLine24")))
		t:SetVertexColor(Tokens.Color("giltLit"))
		t:SetBlendMode("ADD")
		t:SetTexCoord(u, u + CLAW, v, v + CLAW)
		t:SetPoint(corner, c, corner, 0, 0)
		t:SetSize(CLAWS * CLAW, CLAWS * CLAW)
	end
	c.play = c:CreateAnimationGroup()
	local close = c.play:CreateAnimation("Scale")
	close:SetScaleFrom(SHUT, SHUT)
	close:SetScaleTo(1, 1)
	close:SetDuration(CLOSE)
	close:SetSmoothing("OUT")
	Fade(c.play, 1, 1, CLOSE + HOLD, 1)
	Fade(c.play, 1, 0, GO, 2):SetSmoothing("IN")
	c.stop = function()
		c.play:Stop()
	end
	return c
end

local function Lockup(hub)
	local l = Medals.Piece(hub.top, hub.top:GetFrameLevel() + 2, Medals.SIZE)
	l:SetPoint("CENTER", hub, "CENTER", 0, 0)
	l.claws = Claws(l, l:GetFrameLevel())
	l.gem = Medals.Layer(l, l:GetFrameLevel() + 1)
	l.gem:ClearAllPoints()
	l.gem:SetSize(1, 1)
	l.add(Medals.Texture(l.gem, "ARTWORK", 0, "diamond", "gilt", 12))
	l.add(Medals.Texture(l.gem, "ARTWORK", 1, "diamond", "jewelSetting", 10))
	l.stone = l.add(Medals.Texture(l.gem, "ARTWORK", 2, "forgedDiamond", "white", 8))
	l.stone:SetTexCoord(1, 0, 0, 1)
	l.gem:Hide()
	l.paint, l.shown = Lock, false
	pieces[#pieces + 1] = l
	return l
end

function Target.Update()
	local hub = ns.Slab.hub
	local on = hub ~= nil and hub:IsShown() and ns.Config("crestLock") ~= false
	local l = Target.lock or on and Lockup(hub)
	Target.lock = l
	if not l then
		return
	end
	l:SetShown(on)
	local px = on and Widgets.Border(l)
	if px and l.px ~= px then
		l.px = px
		for _, part in ipairs(l.parts) do
			Medals.Even(part)
		end
		local x, y = Medals.Seat("topGem")
		l.gem:SetPoint("CENTER", l, "CENTER", Widgets.Snap(hub, x), Widgets.Snap(hub, y))
	end
	if on then
		Listen("PLAYER_TARGET_CHANGED")
		Lock(l)
	end
end

K.Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
	if module == "ActionBars" and key == "crestLock" then
		Target.Update()
	end
end)

local CLASS = UnitClass and select(2, UnitClass("player"))
if EXECUTE[CLASS] then
	Trackers.Register(CLASS, { { key = "crestKill", seat = "rim", known = EXECUTE[CLASS], build = Kill, place = PlaceKill } })
end
