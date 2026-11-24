-- SlabRanged.lua: a hunter's, mage's and warlock's crest trackers, registered as rows with the one tracker lifecycle (SlabTrackers.lua; docs/medallions-effects.md#ranged-crest-trackers lists every seat): each seat's choices cover every build, pet state and level band, and the pieces SlabMedals has no builder for live here: the pet and demon medals (portrait, missing health, happiness, Mend Pet, Demonic Sacrifice), the mana gem and Healthstone medals (plain bag counts and item cooldowns), a warlock's torment spires and soul wisps, the Auto Shot ring and the class moments (Quick Shots, Clearcasting, Shadow Trance), each a row of Frames medals or a glow along that row under Frames; Blizzard's aura slots light every aura piece, so Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local cos, sin, rad, min, max = math.cos, math.sin, math.rad, math.min, math.max
local IsSecret = Widgets.IsSecret
local Medals, Trackers = ns.SlabMedals, ns.SlabTrackers
local CLASS = UnitClass and select(2, UnitClass("player"))
if IsSecret(CLASS) or CLASS ~= "HUNTER" and CLASS ~= "MAGE" and CLASS ~= "WARLOCK" then
	return
end

local SIZE, SOCKET, SPIRE, WISP, LIFT, BAR = 26, 17, 34, 16, 3, 3
local SOCKETS, ORBIT, PERIOD, STEPS, WISPS, HALO, SHADE, INNER, LOW_AMMO, FAINT = 82, 46, 12, 24, 5, 1.6, 0.8, 112, 200, 0.35
local MOODS = { "hostile", "neutral", "friendly" }
local PULSE = { { 0.25, 1, 0.5 }, { 1, 0.25, 0.5 } }
local COME, FROM, GUST_RUN, GUST_REST = 0.45, { 46, 18 }, 0.7, 0.5
local PET_EVENTS = { { "UNIT_HEALTH", "pet" }, { "UNIT_MAXHEALTH", "pet" }, { "UNIT_HAPPINESS", "pet" }, { "UNIT_PORTRAIT_UPDATE", "pet" } }
local ON = {
	swing = { PLAYER_SWING = true, UNIT_INVENTORY_CHANGED = true },
	pet = { UNIT_PET = true, UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_HAPPINESS = true, UNIT_PORTRAIT_UPDATE = true },
	mana = { UNIT_POWER_UPDATE = true, BAG_UPDATE_DELAYED = true, BAG_UPDATE_COOLDOWN = true },
	wisps = { BAG_UPDATE_DELAYED = true },
}

local function Count(id)
	local api = C_Item
	local n = api and type(api.GetItemCount) == "function" and api.GetItemCount(id)
	return not IsSecret(n) and type(n) == "number" and n or 0
end

local function Have(items)
	for _, id in ipairs(items) do
		if Count(id) > 0 then
			return id
		end
	end
end

local function Out()
	local here = UnitExists and UnitExists("pet")
	return not IsSecret(here) and here == true
end

local function Bar(parent, texture, color, blend, horizontal)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetOrientation(horizontal and "HORIZONTAL" or "VERTICAL")
	bar:SetStatusBarTexture((Tokens.Texture(texture)))
	bar:SetStatusBarColor(Tokens.Color(color))
	if blend then
		bar:GetStatusBarTexture():SetBlendMode(blend)
	end
	return bar
end

local function Timed(button, bar)
	local timer = Enum and Enum.StatusBarTimerDirection
	button:SetDurationBar(bar, { direction = timer and timer.RemainingTime or 1 })
end

local function Polar(r, angle)
	return r * cos(rad(angle)), r * sin(rad(angle))
end

local function Pet(parent, spec, level)
	local sacrifice = spec.feed == "aura"
	local m = Medals.Medal(parent, spec, level)
	m.pet = sacrifice and Medals.Layer(m, level + 2) or m.lit
	m.portrait = sacrifice and m.add(Medals.Round(m.pet), m.lit.icon.units) or m.lit.icon
	m.portrait:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.shade = Bar(m.pet, "dot", "dangerBody")
	m.shade:SetAllPoints(m.portrait)
	m.shade:SetReverseFill(true)
	m.shade:SetAlpha(SHADE)
	local top = Medals.Layer(m, level + 5)
	if spec.mood then
		m.mood = m.add(Medals.Texture(top, "OVERLAY", 0, "medRing", "friendly", SIZE))
	end
	if spec.mend then
		local mend = Medals.Feed(top, { feed = "aura", unit = "pet", spells = spec.mend }, level + 6)
		local pulse = Medals.Layer(mend, level + 6)
		m.add(Medals.Texture(pulse, "ARTWORK", 0, "orbRing", "friendly", SIZE + 6, "ADD"))
		mend.loop = Medals.Steps(pulse, PULSE, true)
		m.lits[#m.lits + 1] = mend
	end
	return m
end

local function Gem(parent, spec, level)
	local m = Medals.Medal(parent, spec, level)
	if C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function" and UnitPowerPercent then
		m.lowMana = Medals.Layer(m.lit, level + 1)
		m.add(Medals.Texture(m.lowMana, "OVERLAY", 2, "glow", "magic", SIZE * 2.2, "ADD"))
		m.curve = C_CurveUtil.CreateCurve()
		local kinds = Enum and Enum.LuaCurveType
		if kinds and kinds.Step and m.curve.SetType then
			m.curve:SetType(kinds.Step)
		end
		m.curve:AddPoint(0, 1)
		m.curve:AddPoint(spec.lowMana, 0)
		m.curve:AddPoint(1, 0)
	end
	return m
end

local function Jewel(parent, spec, level, form)
	return (form == "crest" and Medals.Socket or Medals.Medal)(parent, spec, level)
end

local function Swing(parent, spec, level, form)
	local crest = form == "crest"
	local r = crest and Medals.Piece(parent, level, INNER) or Medals.Medal(parent, { size = SIZE, texture = Trackers.Texture(75) }, level)
	r.swing = CreateFrame("Cooldown", nil, r, "CooldownFrameTemplate")
	r.swing:SetFrameLevel(level + 4)
	r.swing:SetAllPoints(r)
	r.swing:SetSwipeTexture((Tokens.Texture(crest and "ringLine16" or "orbRing")))
	r.swing:SetDrawEdge(false)
	r.swing:SetDrawBling(false)
	r.swing:SetHideCountdownNumbers(true)
	r.color = spec.color
	return r
end

local function Glow(parent, spec, level)
	local g = Medals.Piece(parent, level, SIZE)
	g.lit = Medals.Feed(g, spec, level)
	g.lits[1] = g.lit
	g.halo = g.lit:CreateTexture(nil, "BACKGROUND")
	g.halo:SetTexture((Tokens.Texture("glow")))
	g.halo:SetVertexColor(Tokens.Color(spec.color))
	g.halo:SetBlendMode("ADD")
	g.halo:SetAlpha(FAINT)
	Medals.Flare(g, g.lit, level + 1, spec.burst or "glow", SIZE * 3)
	if spec.ward then
		g.bar = Bar(g.lit, "barSheen", spec.color, nil, true)
		Timed(g.lit, g.bar)
	end
	return g
end

local function Ward(parent, spec, level, form)
	return (form == "row" and Glow or Medals.Rim)(parent, spec, level)
end

local function Gust(r, spec, level)
	local feed = Medals.Feed(r, spec, level + 3)
	local gust = Medals.Layer(feed, level + 3)
	r.gust = Medals.Texture(gust, "OVERLAY", 0, "trackerGust", spec.color, nil, "ADD")
	local loop = gust:CreateAnimationGroup()
	loop:SetLooping("REPEAT")
	local jump, move = loop:CreateAnimation("Translation"), loop:CreateAnimation("Translation")
	jump:SetOffset(-ns.Slab.RING * 0.45, 0)
	jump:SetDuration(0)
	move:SetOffset(ns.Slab.RING * 0.9, 0)
	move:SetDuration(GUST_RUN)
	ns.Slab.Fade(loop, 0, 1, GUST_RUN / 4)
	ns.Slab.Fade(loop, 1, 0, GUST_RUN / 4, 1, GUST_RUN * 3 / 4):SetEndDelay(GUST_REST)
	feed.loop = loop
	r.lits[#r.lits + 1] = feed
end

local function Moment(parent, spec, level, form)
	if form == "row" then
		return Glow(parent, spec, level)
	end
	local r = Medals.Rim(parent, setmetatable({ color = false }, { __index = spec }), level)
	local hub = ns.Slab.hub:GetFrameLevel()
	for _, part in ipairs({ { "medRuneGlyphs", 1, hub + 1, "ARTWORK" }, { "glow", HALO, max(0, hub - 1), "BACKGROUND" } }) do
		r.add(Medals.Texture(Medals.Layer(r.lit, part[3]), part[4], 0, part[1], spec.color, ns.Slab.RING * part[2], "ADD"))
	end
	if spec.gust then
		Gust(r, spec, level)
	end
	return r
end

local function Ring(piece, anchor, form, _, n)
	if form == "crest" then
		Medals.Place(piece, anchor, 0, 0)
		if piece.gust and not Medals.Restricted() then
			Widgets.Size(piece.gust, INNER, 28)
		end
		return n
	end
	local pitch, lines = SIZE + Medals.GAP, math.ceil(max(n, 1) / Medals.LINE)
	local w, h = min(max(n, 1), Medals.LINE) * pitch - Medals.GAP, lines * pitch - Medals.GAP
	Medals.Place(piece, anchor, (w - SIZE) / 2, (h - SIZE) / 2)
	Widgets.Size(piece, w + Medals.GAP, h + Medals.GAP)
	if Medals.Restricted() then
		return n
	end
	piece.halo:ClearAllPoints()
	piece.halo:SetPoint("TOPLEFT", piece, "TOPLEFT", -SIZE, SIZE / 2)
	piece.halo:SetPoint("BOTTOMRIGHT", piece, "BOTTOMRIGHT", SIZE, -SIZE / 2)
	if piece.bar then
		piece.bar:ClearAllPoints()
		piece.bar:SetPoint("BOTTOM", piece, "TOP", 0, 0)
		Widgets.Size(piece.bar, w, BAR)
	end
	return n
end

local function Orbit(seat, angle)
	local group = seat:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	for k = 1, STEPS do
		local a, b = rad(angle + (k - 1) * 360 / STEPS), rad(angle + k * 360 / STEPS)
		local t = group:CreateAnimation("Translation")
		t:SetOffset(ORBIT * (cos(b) - cos(a)), ORBIT * (sin(b) - sin(a)))
		t:SetDuration(PERIOD / STEPS)
		t:SetOrder(k)
	end
	return group
end

local function Wisps(parent, spec, level, form)
	local w = CreateFrame("Frame", nil, parent)
	w:SetFrameLevel(level)
	w.seats, w.lits, w.count, w.shard = {}, {}, 0, spec.items[1]
	w.number = Widgets.FontString(w, "OVERLAY")
	Widgets.ApplyFont(w.number, Tokens.Font("number"))
	w.number:Hide()
	if form == "crest" then
		w.full = Medals.Texture(w, "BACKGROUND", 0, "ringLine16", "jewelShard", INNER)
		w.full:SetAlpha(FAINT)
		w.full:Hide()
	end
	for i = 1, WISPS do
		local s = Medals.Piece(w, level, WISP)
		s.angle = 90 - (i - 1) * 360 / WISPS
		s.wisp = Medals.Layer(s, level)
		s.add(Medals.Texture(s.wisp, "BACKGROUND", -1, "glow", "black", WISP * 1.6))
		s.add(Medals.Texture(s.wisp, "BACKGROUND", 0, "glow", "jewelShard", WISP * 1.8, "ADD"))
		s.art = s.add(Medals.Texture(s.wisp, "ARTWORK", 0, "trackerWisp", "white", WISP, "ADD"))
		s.come = s.wisp:CreateAnimationGroup()
		local from, to = s.come:CreateAnimation("Translation"), s.come:CreateAnimation("Translation")
		from:SetOffset(FROM[1], FROM[2])
		from:SetDuration(0)
		to:SetOffset(-FROM[1], -FROM[2])
		to:SetDuration(COME)
		to:SetOrder(2)
		to:SetSmoothing("OUT")
		ns.Slab.Fade(s.come, 0, 1, COME, 2)
		Medals.Flare(s, s, level + 1, "glow", WISP * 2.4)
		s.parts[#s.parts]:SetVertexColor(Tokens.Color("jewelShardCore"))
		s.orbit = form == "crest" and Orbit(s, s.angle) or nil
		s.wisp:Hide()
		w.seats[i] = s
	end
	return w
end

local function PlaceWisps(w, anchor, form, _, n)
	local cx, cy = Medals.Cell(n)
	local left, step = cx - SIZE / 2, (3 * SIZE + 2 * Medals.GAP) / WISPS
	for i, s in ipairs(w.seats) do
		if form == "crest" then
			Medals.Place(s, anchor, Polar(ORBIT, s.angle))
		else
			Medals.Place(s, anchor, left + step * (i - 0.5), cy)
		end
	end
	if w.full then
		w.full:ClearAllPoints()
		w.full:SetPoint("CENTER", anchor, "CENTER", 0, 0)
		Medals.Even(w.full)
	end
	w.number:ClearAllPoints()
	w.number:SetPoint("CENTER", anchor, "CENTER", Widgets.Snap(anchor, form == "crest" and 0 or left + 1.5 * SIZE + Medals.GAP), Widgets.Snap(anchor, form == "crest" and -ORBIT or cy))
	return n + 3
end

local function Spire(p, container, i, s, angle, level)
	local t = { def = s, angle = angle }
	t.socket = Medals.Piece(p, level, SOCKET)
	t.socket.add(Medals.Texture(t.socket, "BACKGROUND", 0, "medSlotSocket", "white", SOCKET))
	t.dim = t.socket.add(Medals.Texture(t.socket, "ARTWORK", 0, "dot", "white", SOCKET - 4))
	t.dim:SetTexture(Trackers.Texture(Medals.Known(s.spells) or s.spells[1]))
	t.dim:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	t.dim:SetDesaturated(true)
	t.dim:SetAlpha(0.45)
	t.spire = Medals.Piece(p, level, SPIRE)
	t.spire.add(Medals.Texture(t.spire, "BACKGROUND", 0, "pipSpireSteel" .. angle, "white", SPIRE))
	local ids = {}
	for _, id in ipairs(s.spells) do
		ids[id] = true
	end
	local function Slot(key, art, color, blend, size, sublevel)
		local b = container:AddAuraSlot(key .. i, "HARMFUL|PLAYER", { candidateFilters = { includeSpellIDs = ids } })
		pcall(b.EnableMouse, b, false)
		b:SetAllPoints(t.spire)
		b:SetFrameLevel(level + sublevel)
		b.container = container
		local bar = t.spire.add(Bar(b, art .. angle, color, blend), size)
		bar:SetPoint("CENTER", t.spire, "CENTER", 0, 0)
		Timed(b, bar)
		t[key] = bar
		return b
	end
	Slot("glow", "pipSpireGlow", s.color, "ADD", SPIRE * 1.5, 1)
	local lit = Slot("lit", "pipSpire", "white", nil, SPIRE, 2)
	lit.spec = { feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = s.spells }
	local r, g, b = Tokens.Color(s.color)
	t.lit:SetStatusBarColor(0.55 + 0.45 * r, 0.55 + 0.45 * g, 0.55 + 0.45 * b)
	Slot("core", "pipSpireCore", s.color, "ADD", SPIRE, 3)
	t.icon = lit:CreateTexture(nil, "OVERLAY")
	t.icon:SetAllPoints(t.dim)
	t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	lit:SetIcon(t.icon)
	t.rim = lit:CreateTexture(nil, "OVERLAY", nil, 1)
	t.rim:SetTexture((Tokens.Texture("medSlotChecked")))
	t.rim:SetVertexColor(Tokens.Color(s.color))
	t.rim:SetBlendMode("ADD")
	t.rim:SetAllPoints(t.socket)
	Medals.Flare(t.spire, lit, level + 4, "pipSpireCore" .. angle, SPIRE)
	return t, lit
end

local function Spires(parent, spec, level, form)
	local p = CreateFrame("Frame", nil, parent)
	p:SetFrameLevel(level)
	p.spires, p.lits = {}, {}
	p.container = CreateFrame("AuraContainer", nil, p, "CustomAuraContainerTemplate")
	Widgets.KeepOut(p.container)
	p.container:SetUnit("target")
	for i, s in ipairs(spec.spires) do
		p.spires[i], p.lits[i] = Spire(p, p.container, i, s, form == "crest" and s.angle or 90, level)
	end
	return p
end

local function PlaceSpires(p, anchor, form, _, n)
	local line = math.ceil(n / Medals.LINE) * Medals.LINE
	local count = 0
	for _, t in ipairs(p.spires) do
		local known = Medals.Known(t.def.spells) ~= nil
		t.socket:SetShown(known)
		t.spire:SetShown(known)
		if known then
			local sx, sy = Medals.Cell(line + count)
			if form == "crest" then
				sx, sy = Polar(SOCKETS, t.angle)
			end
			count = count + 1
			local reach = SOCKET / 2 + LIFT + SPIRE / 2
			Medals.Place(t.socket, anchor, sx, sy)
			Medals.Place(t.spire, anchor, sx + reach * cos(rad(t.angle)), sy + reach * sin(rad(t.angle)))
		end
	end
	return line + count
end

local function PaintPet(m)
	local dead = UnitIsDead and UnitIsDead("pet")
	local up = Out() and not (not IsSecret(dead) and dead == true)
	m.pet:SetShown(up)
	if m.mood then
		local info = C_PetInfo
		local mood = up and info and type(info.GetPetHappiness) == "function" and info.GetPetHappiness()
		local color = not IsSecret(mood) and MOODS[mood] or nil
		m.mood:SetShown(color ~= nil)
		if color then
			m.mood:SetVertexColor(Tokens.Color(color))
		end
	end
	if not up then
		return
	end
	if SetPortraitTexture then
		SetPortraitTexture(m.portrait, "pet")
	end
	if UnitHealthMax and UnitHealthMissing then
		m.shade:SetMinMaxValues(0, UnitHealthMax("pet"))
		m.shade:SetValue(UnitHealthMissing("pet"))
	end
end

local function PaintLowMana(m, event)
	if event ~= "UNIT_POWER_UPDATE" then
		local item, api = Have(m.spec.items), C_Item
		local start, duration
		if item and type(api.GetItemCooldown) == "function" then
			start, duration = api.GetItemCooldown(item)
		end
		local cooling = not (IsSecret(start) or IsSecret(duration)) and type(duration) == "number" and duration > 0
		m.lowMana:SetShown(item ~= nil and not cooling)
	end
	m.lowMana:SetAlpha(UnitPowerPercent("player", Enum and Enum.PowerType and Enum.PowerType.Mana or 0, false, m.curve))
end

local function Ammo()
	local paper = C_PaperDollInfo
	local uses = UnitUsesAmmo and UnitUsesAmmo("player")
	local slot = not IsSecret(uses) and uses == true and paper and type(paper.GetInventorySlotInfo) == "function" and paper.GetInventorySlotInfo("AmmoSlot")
	local n = slot and not IsSecret(slot) and GetInventoryItemCount and GetInventoryItemCount("player", slot)
	return not IsSecret(n) and type(n) == "number" and n or nil
end

local function PaintSwing(r, event, duration, kind)
	local n = Ammo()
	local color = n and (n == 0 and "hostile" or n < LOW_AMMO and "neutral") or r.color
	r.swing:SetSwipeColor(Tokens.Color(color))
	local types = Enum and Enum.PlayerSwingType or {}
	if event ~= "PLAYER_SWING" or type(GetTime) ~= "function" or IsSecret(kind) or kind ~= (types.Ranged or 2) and kind ~= (types.MainHand or 0) then
		return
	end
	local util = C_DurationUtil
	r.duration = r.duration or util and type(util.CreateDuration) == "function" and util.CreateDuration()
	if r.duration and pcall(r.duration.SetTimeFromStart, r.duration, GetTime(), duration) then
		r.swing:SetCooldownFromDurationObject(r.duration)
	elseif not IsSecret(duration) and type(duration) == "number" then
		r.swing:SetCooldown(GetTime(), duration)
	end
end

local function Spin(w)
	local moving = Effects.Allows("pulse") and not w.still and w.count > 0 and w:IsShown()
	for _, s in ipairs(w.seats) do
		if s.orbit and moving then
			if not s.orbit:IsPlaying() then
				s.orbit:Play()
			end
		elseif s.orbit then
			s.orbit:Stop()
		end
	end
end

local function PaintWisps(w, moving)
	moving = moving and not w.still
	local total = Count(w.shard)
	local n, was = min(WISPS, total), w.count
	w.count = n
	w.number:SetShown(total > WISPS)
	w.number:SetText(total)
	for i, s in ipairs(w.seats) do
		s.wisp:SetShown(i <= n)
		s.come:Stop()
		if moving and i > was and i <= n then
			s.come:Play()
		elseif moving and i <= was and i > n then
			s.flare.play:Stop()
			s.flare.play:Play()
		end
	end
	if w.full then
		w.full:SetShown(total >= WISPS)
	end
	Spin(w)
end

local function Paint(form, event, ...)
	local moving, all = event ~= nil and Effects.Allows("flare"), event == nil
	for _, p in pairs(form.pieces) do
		local shown = p:IsShown()
		if shown and p.swing and (all or ON.swing[event]) then
			PaintSwing(p, event, ...)
		elseif shown and p.portrait and (all or ON.pet[event]) then
			PaintPet(p)
		elseif shown and p.lowMana and (all or ON.mana[event]) then
			PaintLowMana(p, event)
		elseif shown and p.seats and (all or ON.wisps[event]) then
			PaintWisps(p, moving)
		elseif shown and p.spires and event == "PLAYER_TARGET_CHANGED" then
			p.container:UpdateAllAuras()
		end
	end
end

local function Motion(form, _, still)
	for _, p in pairs(form.pieces) do
		if p.seats then
			p.still = still
			Spin(p)
		end
	end
end

if CLASS == "HUNTER" then
	local ASPECTS = { 13165, 14318, 14319, 14320, 14321, 14322, 25296, 13163, 5118, 13159, 20043, 20190, 13161, 1299445, 1299446, 1299447, 415423, 469145 }
	local STINGS = { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295, 3034, 14279, 14280, 3043, 14275, 14276, 14277, 19386, 24132, 24133, 24131, 24134, 24135,
		24118, 24119, 24120, 1299332, 3674, 14296 }

	Trackers.Register("HUNTER", {
		{ key = "crestShot", seat = "topGem", size = Medals.FOOT, feed = "usable", groups = { { 20910, 20909, 19306, 1242634 }, { 14271, 14270, 14269, 1495 },
			{ 20904, 20903, 20902, 20901, 20900, 19434 }, { 2643 } } },
		{ key = "crestAspect", seat = "leftHip", choices = {
			{ feed = "aura", spells = ASPECTS },
			{ feed = "cooldown", known = { 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 } },
		} },
		{ key = "crestPet", seat = "rightHip", choices = {
			{ build = Pet, known = { 883 }, mood = true, mend = { 136, 3111, 3661, 3662, 13542, 13543, 13544 } },
			{ feed = "cooldown", known = { 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 } },
		} },
		{ key = "crestMark", seat = "footLeft", size = Medals.FOOT, feed = "aura", unit = "target", filter = "HARMFUL", color = "hostile", spells = { 1130, 14323, 14324, 14325 } },
		{ key = "crestSting", seat = "footRight", size = Medals.FOOT, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", color = "schoolNature", newest = true,
			spells = STINGS, known = { 1978, 3034, 3043, 24118, 3674 } },
		{ key = "crestAutoShot", seat = "rim", build = Swing, color = "steelLit", known = { 75 } },
		{ key = "crestCooldowns", seat = "cooldowns", color = "jewelHawk", families = { { spells = { 3045 } }, { spells = { 19263 } }, { spells = { 19574 }, unit = "pet" } } },
		{ key = "crestGust", seat = "rim", build = Moment, place = Ring, feed = "aura", spells = { 6150, 1299448, 469144, 3045 }, known = { 3045, 19552, 19553, 19554, 19555, 19556 },
			color = "jewelHawk", ambient = "medAmbientHunter", gust = true },
	}, { burst = "medBurstHunter", events = { { "UNIT_PET", "player" }, PET_EVENTS[1], PET_EVENTS[2], PET_EVENTS[3], PET_EVENTS[4], "PLAYER_SWING", { "UNIT_INVENTORY_CHANGED", "player" } },
		paint = Paint })
end

if CLASS == "MAGE" then
	local GEMS, INTELLECT = { 8008, 8007, 5513, 5514 }, { 1459, 1460, 1461, 10156, 10157, 23028 }
	local WARDS = { 11426, 13031, 13032, 13033, 1463, 8494, 8495, 10191, 10192, 10193, 543, 8457, 8458, 10223, 10225, 6143, 8461, 8462, 10177, 28609 }
	local FROSTBOLT = { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 }
	local CHILLS = Trackers.Joined(FROSTBOLT, { 120, 8492, 10159, 10160, 10161 })
	local NOVA = { 10230, 6131, 865, 122 }
	local CONJURE = { 10054, 10053, 3552, 759 }
	local IGNITE = { 11119, 11120, 12846, 12847, 12848 }
	local FIRE = { 412538, 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 }
	local WINTERS = { 11180, 28592, 28593, 28594, 28595 }

	Trackers.Register("MAGE", {
		{ key = "crestArmor", seat = "left", feed = "aura", color = "schoolFrost", spells = { 168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783 } },
		{ key = "crestManaGem", seat = "right", choices = {
			{ build = Gem, feed = "item", items = GEMS, lowMana = 0.3, known = function() return Medals.Known(CONJURE) or Have(GEMS) and CONJURE[#CONJURE] end },
			{ feed = "aura", spells = INTELLECT, color = "schoolArcane" },
		} },
		{ key = "crestCounterspell", seat = "leftHip", feed = "cooldown", choices = {
			{ known = { 2139 } },
			{ known = { 10199, 10197, 8413, 8412, 2138, 2137, 2136 } },
		} },
		{ key = "crestSchool", seat = "rightHip", choices = {
			{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 22959 }, known = { 11095, 12872, 12873 }, color = "schoolFire", pips = 5 },
			{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 12579 }, known = WINTERS, color = "schoolFrost", pips = 5 },
			{ feed = "cooldown", known = { 1326079 } },
			{ feed = "cooldown", known = NOVA },
		} },
		{ key = "crestFrozen", seat = "footLeft", size = Medals.FOOT, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", color = "schoolFrost", choices = {
			{ spells = { 122, 865, 6131, 10230, 12494 }, known = NOVA },
			{ spells = FROSTBOLT },
		} },
		{ key = "crestYourSpell", seat = "footRight", size = Medals.FOOT, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", newest = true, choices = {
			{ spells = FIRE, known = IGNITE, color = "schoolFire" },
			{ spells = CHILLS, known = WINTERS, color = "schoolFrost" },
			{ spells = { 118, 12824, 12825, 12826, 28271, 28272 }, color = "schoolArcane" },
		} },
		{ key = "crestCooldowns", seat = "cooldowns", color = "pipMageGlow", families = { { spells = { 12042 } }, { spells = { 12043 } },
			{ spells = { 11129, 28682 }, known = { 11129 } }, { spells = { 12051 } }, { spells = { 11958, 27619 }, known = { 11958 } } } },
		{ key = "crestWard", seat = "rim", build = Ward, place = Ring, feed = "aura", spells = WARDS, color = "rim", ward = true },
		{ key = "crestClearcasting", seat = "rim", build = Moment, place = Ring, feed = "aura", spells = { 12536 }, known = { 11213, 12574, 12575, 12576, 12577 },
			color = "schoolArcane", ambient = "medAmbientMage" },
	}, { burst = "medBurstMage", events = { "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", { "UNIT_POWER_UPDATE", "player" } }, paint = Paint })
end

if CLASS == "WARLOCK" then
	local DEMONS, SACRIFICE = { 688, 697, 712, 713, 691 }, { 18788 }
	local ARMORS = { 11735, 11734, 11733, 1086, 706, 696, 687 }
	local STONES = { 9421, 19012, 19013, 5510, 19010, 19011, 5509, 19008, 19009, 5511, 19006, 19007, 5512, 19004, 19005 }
	local CREATE = { 11730, 11729, 5699, 6202, 6201 }
	local CURSES = { 702, 1108, 6205, 7646, 11707, 11708, 704, 7658, 7659, 11717, 1714, 11719, 440892, 1311676, 1311677, 1311680, 18223 }

	local function Demon()
		return Out() or Medals.Known(SACRIFICE) ~= nil
	end

	local function SpellLock()
		local book, bank = C_SpellBook, Enum and Enum.SpellBookSpellBank
		if not (Out() and book and type(book.IsSpellKnown) == "function" and bank) then
			return nil
		end
		for _, id in ipairs({ 19647, 19244 }) do
			local known = book.IsSpellKnown(id, bank.Pet)
			if not IsSecret(known) and known == true then
				return id
			end
		end
	end

	Trackers.Register("WARLOCK", {
		{ key = "crestDemon", seat = "left", choices = {
			{ build = Pet, known = DEMONS, active = Demon, feed = "aura", color = "jewelShard", spells = { 18789, 18790, 18791, 18792 } },
			{ feed = "aura", color = "jewelShard", spells = ARMORS },
		} },
		{ key = "crestHealthstone", seat = "right", choices = {
			{ feed = "item", items = STONES, known = function() return Medals.Known(CREATE) or Have(STONES) and CREATE[#CREATE] end },
			{ feed = "aura", color = "jewelShard", spells = ARMORS, known = function() return Medals.Known(DEMONS) and Medals.Known(ARMORS) end, active = Demon },
		} },
		{ key = "crestStone", seat = "lowerLeft", feed = "enchant", slot = "MainHand", color = "schoolFire", known = { 17728, 17727, 2362, 17953, 17952, 17951, 6366 } },
		{ key = "crestConflagrate", seat = "lowerRight", build = Jewel, feed = "cooldown", color = "schoolFire", known = { 1293818, 1293817, 18932, 18931, 18930, 17962 } },
		{ key = "crestCurse", seat = "footLeft", size = Medals.FOOT, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", color = "jewelShard", spells = CURSES },
		{ key = "crestSpellLock", seat = "footRight", size = Medals.FOOT, feed = "cooldown", choices = {
			{ known = function() return Medals.Known({ 691 }) and (SpellLock() or 19244) end, active = SpellLock },
			{ known = { 17926, 17925, 6789 } },
		} },
		{ key = "crestCooldowns", seat = "cooldowns", color = "jewelShard", families = { { spells = { 18288 } }, { spells = { 18708 } },
			{ spells = { 6229, 11739, 11740, 28610 } }, { spells = { 7812, 19438, 19440, 19441, 19442, 19443 } } } },
		{ key = "crestWisps", seat = "rim", build = Wisps, place = PlaceWisps, items = { 6265 },
			known = function() return Medals.Known({ 1120, 8288, 8289, 11675 }) or Count(6265) > 0 and 1120 end },
		{ key = "crestTorments", seat = "rim", build = Spires, place = PlaceSpires, spires = {
			{ angle = 126, color = "totemEarth", spells = { 172, 6222, 6223, 7648, 11671, 11672, 25311 } },
			{ angle = 102, color = "jewelShard", spells = { 980, 1014, 6217, 11711, 11712, 11713, 603, 1225228 } },
			{ angle = 78, color = "schoolFire", spells = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 } },
			{ angle = 54, color = "healthHostile", spells = { 18265, 18879, 18880, 18881 } },
		}, known = function(row)
			for _, s in ipairs(row.spires) do
				local id = Medals.Known(s.spells)
				if id then return id end
			end
		end },
		{ key = "crestTrance", seat = "rim", build = Moment, place = Ring, feed = "aura", spells = { 17941 }, known = { 18094, 18095 },
			color = "jewelShard", ambient = "medAmbientWarlock" },
	}, {
		burst = "medBurstWarlock",
		events = { PET_EVENTS[1], PET_EVENTS[2], PET_EVENTS[4], "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED" },
		update = { "UNIT_PET" },
		paint = Paint,
		motion = Motion,
	})
end
