-- SlabTarget.lua: the crest's two target effects (docs/medallions-effects.md#target-effects): Kill window, a tracker row, burns the foot of the inner rim red-hot while the target is under the class's execute line (UnitHealthPercent through a step curve into its alpha, so Lua never reads the health), sends one wave outward as the value crosses the line and beats; Target lock, built with the hub out of combat for every class, closes four forged claws inward round the ring on a new hostile target and lights the top gem in the target's rank while that seat is free.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local IsSecret = Widgets.IsSecret
local Medals, Trackers, Slab = ns.SlabMedals, ns.SlabTrackers, ns.Slab
local cos, sin, rad = math.cos, math.sin, math.rad

local Target = {}
ns.SlabTarget = Target

local OWNER = "ActionBars.SlabTarget"
local EXECUTE = { WARRIOR = { 20662, 20661, 20660, 20658, 5308 }, PALADIN = { 24275, 24274, 24239 } }
local LINE, CUT, INNER, EDGE, BLAZE, FOOT = 0.2, 25.2, 112, 122, 140, 56
local FADE_IN, WAVE, DROP, SPREAD, BEAT, BEAT_LOW = 0.2, 0.4, 9, 1.22, 0.4, 0.7
local CLAW, REACH, TRAVEL, CLOSE, HOLD, GO = 36, 84, 12, 0.2, 0.3, 0.3
local CORNERS = {
	{ 120, { 1, 1, 1, 0, 0, 1, 0, 0 } }, { 240, { 1, 0, 1, 1, 0, 0, 0, 1 } },
	{ 60, { 0, 1, 0, 0, 1, 1, 1, 0 } }, { 300, { 0, 0, 0, 1, 1, 0, 1, 1 } },
}
local RANKS = { elite = "gilt", rare = "steelLit", rareelite = "steelLit", worldboss = "plateHostile" }
local GATES = { "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }
local kills, curve = {}, nil
Target.kills = kills

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

local function Burn(k)
	local step = Hostile() and Curve()
	if not step and k.dark then
		return
	end
	k.dark = not step
	local value = 0
	if step then
		value = UnitHealthPercent("target", true, step)
	end
	k:SetAlpha(value)
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

function Target.Seat()
	local l = Target.lock
	local shown = l ~= nil and l.hostile == true and TopFree()
	if l and l.shown ~= shown then
		l.shown = shown
		l.gem:SetShown(shown)
	end
end

local function Still(l)
	for _, c in ipairs(l.claws) do
		c.play:Stop()
	end
end

local function Lock(l, event)
	local hostile = Hostile()
	if not (hostile or l.hostile) then
		return
	end
	if event or not hostile then
		Still(l)
		Effects.Release("hub", l.token)
		l.token = nil
	end
	l.hostile = hostile
	local rank = hostile and Rank()
	if rank and l.rank ~= rank then
		l.rank = rank
		l.stone:SetVertexColor(Tokens.Color(rank))
	end
	Target.Seat()
	if event and hostile and Effects.Allows("flare") then
		l.token = Effects.ClaimFor("hub", Effects.PRIORITY.target, CLOSE + HOLD + GO, l.still)
		for _, c in ipairs(l.token and l.claws or {}) do
			c.play:Play()
		end
	end
end

local function OnEvent(event)
	for _, k in ipairs(kills) do
		if k:IsVisible() then
			Burn(k)
		end
	end
	local l = Target.lock
	local dead = event == "UNIT_HEALTH" and l and l.hostile and UnitIsDead and UnitIsDead("target")
	if l and l.on and (event == "PLAYER_TARGET_CHANGED" or not IsSecret(dead) and dead == true) then
		Lock(l, event == "PLAYER_TARGET_CHANGED" and event or nil)
	end
end

local function Listen()
	K.Events.Register(OWNER, "PLAYER_TARGET_CHANGED", OnEvent)
	K.Events.RegisterUnit(OWNER, "UNIT_HEALTH", OnEvent, "target")
end

local function Arc(parent, token, color, size, feather)
	local t = parent:CreateTexture(nil, "ARTWORK")
	local share = 0.5 - CUT / size
	local r, g, b = Tokens.Color(color)
	t:SetTexture((Tokens.Texture(token)))
	t:SetGradient("VERTICAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, feather))
	t:SetBlendMode("ADD")
	t:SetTexCoord(0, 1, 1 - share, 1)
	t:SetPoint("BOTTOM", parent, "CENTER", 0, -size / 2)
	t:SetSize(size, size * share)
	return t
end

local function Heat(parent, color, width, height)
	local t = Medals.Texture(parent, "OVERLAY", 0, "glow", color, 0, "ADD")
	t:SetPoint("CENTER", parent, "CENTER", 0, -FOOT)
	t:SetSize(width, height)
	return t
end

local function Kill(parent, _, level, form)
	local k = Medals.Piece(parent, level, Medals.SIZE)
	k.fade = Medals.Layer(k, level)
	k.beat = Medals.Layer(k.fade, level)
	if form == "crest" then
		k.band = Arc(k.beat, "medLowHealthRing", "white", BLAZE, 0.35)
		Arc(k.beat, "medLowHealthRing", "schoolFire", BLAZE + 10, 0.2)
		k.edge = Arc(k.beat, "ringLine12", "jewelCombo", EDGE, 0.3)
		Heat(k.beat, "schoolFire", 64, 22)
		k.core = Heat(k.beat, "jewelComboCore", 26, 9)
		k.ripple = Medals.Layer(k, level)
		k.ripple:SetAlpha(0)
		k.ripple.play = k.ripple:CreateAnimationGroup()
		local drop = k.ripple.play:CreateAnimation("Translation")
		drop:SetOffset(0, -DROP)
		drop:SetDuration(WAVE)
		drop:SetSmoothing("OUT")
		Slab.Fade(k.ripple.play, 1, 0, WAVE, 1):SetSmoothing("OUT")
		k.ripple.grow = Arc(k.ripple, "ringLine12", "jewelComboCore", INNER, 0.2):CreateAnimationGroup()
		Slab.Grow(k.ripple.grow, 1, SPREAD, WAVE):SetSmoothing("OUT")
	else
		k.line = Medals.Texture(k.beat, "ARTWORK", 0, "barFlat", "hostile", 0)
		k.line:SetHeight(2)
	end
	k.fade.play = k.fade:CreateAnimationGroup()
	Slab.Fade(k.fade.play, 0, 1, FADE_IN, 1):SetSmoothing("OUT")
	k.beat.play = k.beat:CreateAnimationGroup()
	k.beat.play:SetLooping("REPEAT")
	Slab.Fade(k.beat.play, 1, BEAT_LOW, BEAT, 1):SetSmoothing("IN_OUT")
	Slab.Fade(k.beat.play, BEAT_LOW, 1, BEAT, 2):SetSmoothing("IN_OUT")
	k.feed = CreateFrame("StatusBar", nil, k)
	k.feed:SetMinMaxValues(0, 1)
	k.feed:SetValue(0)
	k.feed:SetScript("OnValueChanged", function()
		for _, group in ipairs({ k.fade.play, k.ripple and k.ripple.play, k.ripple and k.ripple.grow }) do
			group:Stop()
			if Effects.Allows("flare") then
				group:Play()
			end
		end
	end)
	kills[#kills + 1] = k
	Listen()
	return k
end

local function PlaceKill(k, anchor, form, _, n)
	local cells = form == "row" and math.max(1, math.min(n, Medals.LINE)) or 0
	if k.anchor ~= anchor or k.cells ~= cells then
		k.anchor, k.cells = anchor, cells
		local pitch = Medals.SIZE + Medals.GAP
		Medals.Place(k, anchor, math.max(0, cells - 1) * pitch / 2, cells > 0 and -pitch / 2 or 0)
		if k.line then
			k.line:SetWidth(cells * pitch - Medals.GAP)
		end
	end
	Burn(k)
	return n
end

local function Claws(l)
	l.claws = {}
	for i, corner in ipairs(CORNERS) do
		local a = rad(corner[1])
		local c = CreateFrame("Frame", nil, l)
		c:SetSize(CLAW, CLAW)
		c:SetPoint("CENTER", l, "CENTER", Widgets.Snap(l, (REACH + TRAVEL) * cos(a)), Widgets.Snap(l, (REACH + TRAVEL) * sin(a)))
		c:SetAlpha(0)
		c.glow = Medals.Texture(c, "ARTWORK", 0, "pipClawGlow130", "giltLit", 0, "ADD")
		c.art = Medals.Texture(c, "ARTWORK", 1, "pipClaw130", "white", 0)
		c.glow:SetAlpha(0.75)
		for _, t in ipairs({ c.glow, c.art }) do
			local side = CLAW * (t == c.glow and 1.3 or 1)
			t:SetTexCoord(unpack(corner[2]))
			t:SetSize(side, side)
		end
		c.play = c:CreateAnimationGroup()
		local close = c.play:CreateAnimation("Translation")
		close:SetOffset(-TRAVEL * cos(a), -TRAVEL * sin(a))
		close:SetDuration(CLOSE)
		close:SetSmoothing("OUT")
		Slab.Fade(c.play, 1, 1, CLOSE + HOLD, 1)
		Slab.Fade(c.play, 1, 0, GO, 2):SetSmoothing("IN")
		l.claws[i] = c
	end
end

local function Lockup(hub)
	local l = Medals.Piece(hub.top, hub.top:GetFrameLevel() + 2, Medals.SIZE)
	l:SetPoint("CENTER", hub, "CENTER", 0, 0)
	Claws(l)
	l.still = function() Still(l) end
	l.gem = Medals.Layer(l, l:GetFrameLevel() + 1)
	l.gem:ClearAllPoints()
	l.gem:SetSize(1, 1)
	l.add(Medals.Texture(l.gem, "ARTWORK", 0, "diamond", "gilt", 12))
	l.add(Medals.Texture(l.gem, "ARTWORK", 1, "diamond", "jewelSetting", 10))
	l.stone = l.add(Medals.Texture(l.gem, "ARTWORK", 2, "forgedDiamond", "white", 8))
	l.stone:SetTexCoord(1, 0, 0, 1)
	l.gem:Hide()
	l.shown = false
	return l
end

function Target.Update()
	local hub = ns.Slab.hub
	local on = hub ~= nil and hub:IsShown() and ns.Config("crestLock") ~= false
	local locked = Medals.Locked()
	local listen = on and locked and K.Events.Register or K.Events.Unregister
	for _, event in ipairs(GATES) do
		listen(OWNER, event, Target.Update)
	end
	local l = Target.lock or on and not locked and Lockup(hub) or nil
	Target.lock = l
	if not l then
		return
	end
	l.on = on
	l:SetShown(on)
	if not on then
		Still(l)
		Effects.Release("hub", l.token)
		l.token, l.hostile = nil, nil
		Target.Seat()
		return
	end
	local px = not locked and Widgets.Border(l)
	if px and l.px ~= px then
		l.px = px
		for _, part in ipairs(l.parts) do
			Medals.Even(part)
		end
		local x, y = Medals.Seat("topGem")
		l.gem:SetPoint("CENTER", l, "CENTER", Widgets.Snap(hub, x), Widgets.Snap(hub, y))
	end
	Listen()
	Lock(l)
end

local CLASS = UnitClass and select(2, UnitClass("player"))
if EXECUTE[CLASS] then
	Trackers.Register(CLASS, { { key = "crestKill", seat = "rim", known = EXECUTE[CLASS], build = Kill, place = PlaceKill } })
end
