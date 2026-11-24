-- SlabRanged.lua: a hunter's, mage's and warlock's crest trackers, registered as rows with the one tracker lifecycle (SlabTrackers.lua; docs/medallions-effects.md#ranged-crest-trackers lists every seat): each seat's choices cover every build, pet state and level band, and each breaks out of the medal into the crest in additive light, never a spell or item icon and never a socket: your damage over time a fuse burning down the right band with its own mark at its head, the pet's or demon's health light along the band, an Aspect, armor or demon sigil perched on the ring, a mage's armor as crystals that thaw along the upper left band and Frost Nova's frost over the inner ring, Hunter's Mark and the ready shots over the emblem, a bag gem hanging from the lower right, an interrupt's blade through the lower left, a school's stacks as embers and a cooldown as an arc filling on the left band, the warlock's spires with their glyphs at their feet and its soul wisps, the Auto Shot ring and the class moments (Quick Shots, Clearcasting, Shadow Trance); the same effects free-standing in a row under Frames (Effect and its LOOKS, Well and Trinket); Blizzard's aura slots light every aura piece and blink it in its pandemic window, so Lua never reads or compares a secret.
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

local function Polar(r, angle)
	return r * cos(rad(angle)), r * sin(rad(angle))
end

local SIZE, BASE, SPIRE, WISP, LIFT, BAR, NECK = 26, 17, 34, 16, 3, 3, 8
local SOCKETS, ORBIT, PERIOD, STEPS, WISPS, HALO, INNER, LOW_AMMO, FAINT = 82, 46, 12, 24, 5, 1.6, 112, 200, 0.35
local STEEL, LIGHT, GROOVE, PERCH, GEM, SHOT, FLASH, HEAD = 0.45, 0.8, 0.35, 28, 26, 80, 36, 1
local MOODS = { "hostile", "neutral", "friendly" }
local BREATH = { { 0.6, 1, 0.9 }, { 1, 0.6, 0.9 } }
local GLEAM = { { 0.8, 1, 0.7 }, { 1, 0.8, 0.7 } }
local BURN = { { 1, 0.7, 0.1 }, { 0.7, 1, 0.08 }, { 1, 0.8, 0.12 }, { 0.8, 1, 0.1 } }
local BLINK = { { 1, 0.2, 0.1 }, { 0.2, 1, 0.1 } }
local GROW = { { 0, 1, 0.6 } }
local BAND = {
	right = { "glyphArcRight", 64, 0, 58 }, left = { "glyphArcLeft", -64, 0, 58 }, pet = { "glyphArcPet", 42, -46, 42 },
	rim = { "glyphRimLeft", -72, 0, 62 }, armor = { "glyphArmorFrost", -37, 51, 64 }, frost = { "glyphFrost", 0, -39, 108 }, mark = { "glyphMarkReticle", 0, 0, 108 },
}
local EMBLEM, PERCH_LEFT, PERCH_RIGHT, PENDANT, SIGIL = { 0, 0 }, { Polar(73, 228) }, { Polar(74, 312) }, { Polar(80, 312) }, { Polar(62, 184) }
local LOOKS = {
	glyph = { k = 1.25, loop = BREATH, white = 0.25 },
	brand = { k = 1.2, bar = true, flame = true, loop = BURN, warn = true },
	timed = { k = 1.25, bar = true, loop = BREATH, warn = true },
	orb = { art = "stormOrb", k = 1.15 },
	gem = { art = "glyphFacet", k = 1, white = 0.15 },
	shard = { art = "pipShard50", steel = "pipShardSteel50", k = 1.4, bar = true, solid = true, native = true, rest = 0.9 },
	blade = { art = "pipBlade50", steel = "pipBladeSteel50", k = 1.4, bar = true, solid = true, rest = 0.9 },
}
local COME, FROM, GUST_RUN, GUST_REST = 0.45, { 46, 18 }, 0.7, 0.5
local PET_EVENTS = { { "UNIT_HEALTH", "pet" }, { "UNIT_MAXHEALTH", "pet" }, { "UNIT_HAPPINESS", "pet" } }
local ON = {
	swing = { PLAYER_SWING = true, UNIT_INVENTORY_CHANGED = true },
	pet = { UNIT_PET = true, UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_HAPPINESS = true },
	wisps = { BAG_UPDATE_DELAYED = true },
	usable = { SPELL_UPDATE_USABLE = true, SPELL_UPDATE_COOLDOWN = true, PLAYER_TARGET_CHANGED = true },
}

local function At(band)
	return { band[2], band[3] }
end

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

local function Lift(color, white)
	local r, g, b = Tokens.Color(color)
	white = white or 0.4
	return white + (1 - white) * r, white + (1 - white) * g, white + (1 - white) * b
end

local function Spot(p, parent, art, color, size, x, y, layer, blend)
	local t = p.add(Medals.Texture(parent, layer or "ARTWORK", 0, art, color, size, blend or "ADD"))
	t:SetPoint("CENTER", p, "CENTER", x, y)
	return t
end

local function Flare(p, lit, level, size, x, y)
	Medals.Flare(p, lit, level, "glow", size)
	p.parts[#p.parts]:SetPoint("CENTER", p, "CENTER", x, y)
end

local function Embers(p, lit, each, level, place)
	for n = 1, each.stacks do
		local slot = lit.container:AddAuraSlot("ember" .. n, each.filter, each.options)
		pcall(slot.EnableMouse, slot, false)
		slot:SetAllPoints(p)
		slot:SetFrameLevel(level)
		local x, y, art, size = place(n)
		local ember = p.add(Bar(slot, art, "white", "ADD"), size)
		ember:SetStatusBarColor(Lift(each.color))
		ember:SetPoint("CENTER", p, "CENTER", x, y)
		slot:SetApplicationBar(ember, { minApplications = n - 1, maxApplications = n })
	end
end

local function Light(p, each, level, look)
	local art, size = each.glyph or look.art, p.units * look.k
	local lit = Medals.Lit(p, each, level)
	local hold = lit.container and lit or Medals.Layer(lit, level)
	lit.glow = p.add(Medals.Texture(hold, "BACKGROUND", 1, "glow", each.color, p.units * 2.2, "ADD"))
	lit.glow:SetAlpha(LIGHT)
	local warn = look.warn and lit.container and Medals.Layer(lit, level + 1)
	local light = Medals.Layer(warn or (look.bar and lit or hold), level + 2)
	if look.flame then
		p.add(Medals.Texture(light, "BACKGROUND", 0, "trackerFlame", each.color, size * 1.3, "ADD")):SetDesaturated(true)
	end
	if look.bar then
		lit.art = p.add(Bar(light, art, "white", not look.solid and "ADD" or nil), size)
		lit.art:GetStatusBarTexture():SetDesaturated(not look.native)
		lit.art:SetPoint("CENTER", p, "CENTER", 0, 0)
		if not look.native then
			lit.art:SetStatusBarColor(Lift(each.color, look.flame and 0.7 or nil))
		end
	else
		lit.art = p.add(Medals.Texture(light, "ARTWORK", 0, art, "white", size, "ADD"))
		lit.art:SetDesaturated(true)
		lit.art:SetVertexColor(Lift(each.color, look.white))
	end
	if lit.container then
		if each.stacks then
			Embers(p, lit, each, level + 3, function(n)
				local x, y = Polar(p.units * 0.64, 210 + (n - 1) * 30)
				return x, y, "glow", 10
			end)
		end
		if look.bar then
			Timed(lit, lit.art)
		end
		lit.loop = look.loop and Medals.Steps(light, look.loop, true)
		lit.warn = warn and Medals.Steps(warn, BLINK, true)
	else
		p.ready, p.bar = hold, look.bar and lit.art or nil
		if p.bar then
			p.bar:SetMinMaxValues(0, 1)
			p.bar:SetValue(1)
		end
		p.timer = p.add(Medals.Timer(lit, level + 3, "orbRing", each.color), max(size, p.units) + 4)
		p.timer:SetReverse(true)
		p.timer:SetScript("OnCooldownDone", function()
			hold:Show()
			Medals.Fire(p)
		end)
		lit:SetShown(each.feed == "cooldown")
	end
	Medals.Flare(p, lit, level + 6, each.feed == "usable" and each.burst or art, size * 1.8)
end

local function Effect(parent, spec, level, form)
	local look = LOOKS[spec.look]
	local p = Medals.Piece(parent, level, spec.size or SIZE)
	if form ~= "crest" then
		p.add(Medals.Texture(p, "BACKGROUND", -1, "glow", "black", p.units * 1.9)):SetAlpha(0.7)
	end
	for _, each in ipairs(spec.feeds or { spec }) do
		Light(p, each == spec and spec or setmetatable(each, { __index = spec }), level + 1, look)
	end
	p.rest = Medals.Layer(spec.feed == "item" and p.lit or p, level)
	p.rest:SetAlpha(look.rest or STEEL)
	p.add(Medals.Texture(p.rest, "ARTWORK", 0, look.steel or spec.glyph or look.art, "steel", p.units * look.k)):SetDesaturated(true)
	return p
end

local function Crest(build)
	return function(parent, spec, level, form)
		return (form == "crest" and build or Effect)(parent, spec, level, form)
	end
end

local function Flash(parent, spec, level, form)
	local p = Effect(parent, spec, level, form)
	if form == "crest" then
		p.ready:SetAlpha(0)
		p.rest:Hide()
		p.timer:SetDrawSwipe(false)
	end
	return p
end

local function Groove(p, band, k)
	p.add(Medals.Texture(p, "BACKGROUND", 0, band[1], "black", band[4] * (k or 1))):SetAlpha(GROOVE)
end

local function Band(p, each, level, band, horizontal, white, k)
	local lit = Medals.Lit(p, each, level)
	local warn = Medals.Layer(lit, level)
	local light = Medals.Layer(warn, level + 1)
	lit.art = p.add(Bar(light, each.art or band[1], "white", "ADD", horizontal), band[4] * (k or 1))
	lit.art:SetStatusBarColor(Lift(each.color, white))
	lit.art:SetPoint("CENTER", p, "CENTER", 0, 0)
	Timed(lit, lit.art)
	lit.warn = Medals.Steps(warn, BLINK, true)
	return lit, light
end

local function Fuse(parent, spec, level)
	local band = BAND.right
	local p = Medals.Piece(parent, level, band[4])
	Groove(p, band)
	for _, each in ipairs(spec.feeds or { spec }) do
		each = each == spec and spec or setmetatable(each, { __index = spec })
		local lit, light = Band(p, each, level + 1, band, false, 0.3)
		local head = CreateFrame("Frame", nil, light)
		head:SetFrameLevel(level + 3)
		head:SetSize(1, 1)
		head:SetPoint("CENTER", lit.art:GetStatusBarTexture(), "TOP", HEAD, 0)
		lit.head = head
		local burn = Medals.Layer(head, level + 3)
		lit.glow = p.add(Medals.Texture(head, "BACKGROUND", 0, "glow", each.color, 36, "ADD"))
		local flame = p.add(Medals.Texture(burn, "BORDER", 0, "trackerFlame", each.color, 24, "ADD"))
		flame:SetDesaturated(true)
		flame:SetPoint("CENTER", head, "CENTER", 0, 5)
		lit.mark = p.add(Medals.Texture(burn, "ARTWORK", 0, each.glyph, "white", 16, "ADD"))
		lit.mark:SetVertexColor(Lift(each.color, 0.8))
		lit.loop = Medals.Steps(burn, BURN, true)
		Flare(p, lit, level + 6, 60, -3, 27)
	end
	return p
end

local function Armor(parent, spec, level)
	local band = BAND.armor
	local p = Medals.Piece(parent, level, band[4])
	p.add(Medals.Texture(p, "BACKGROUND", 0, band[1], "steel", band[4])):SetAlpha(0.3)
	for _, each in ipairs(spec.feeds) do
		local lit, light = Band(p, setmetatable(each, { __index = spec }), level + 1, band, true, 0.35)
		lit.art:SetReverseFill(true)
		lit.loops = { Medals.Steps(light, GROW) }
		Flare(p, lit, level + 6, 70, 0, 0)
	end
	return p
end

local function Frozen(parent, spec, level)
	local band = BAND.frost
	local p = Medals.Piece(parent, level, band[4])
	local lit, light = Band(p, spec, level + 1, band, true, 0.45)
	lit.loops = { Medals.Steps(light, GROW) }
	Flare(p, lit, level + 6, 60, 0, -16)
	return p
end

local function Mark(parent, spec, level)
	local band = BAND.mark
	local p = Medals.Piece(parent, level, band[4])
	local lit = Medals.Lit(p, spec, level + 1)
	local warn = Medals.Layer(lit, level + 1)
	local light = Medals.Layer(warn, level + 2)
	lit.glow = Spot(p, light, "glow", spec.color, 26, 0, -6, "BACKGROUND")
	lit.art = p.add(Medals.Texture(light, "ARTWORK", 0, band[1], "white", band[4], "ADD"))
	lit.art:SetVertexColor(Lift(spec.color, 0.2))
	local close = lit.art:CreateAnimationGroup()
	ns.Slab.Grow(close, 1.6, 1, 0.5, 1, "OUT")
	ns.Slab.Fade(close, 0, 1, 0.25)
	lit.loops = { Medals.Steps(light, GLEAM, true), close }
	lit.warn = Medals.Steps(warn, BLINK, true)
	return p
end

local function Stacks(parent, spec, level)
	local band = BAND.left
	local p = Medals.Piece(parent, level, band[4])
	Groove(p, band)
	local lit = Medals.Lit(p, spec, level + 1)
	lit.glow = Spot(p, lit, "glow", spec.color, 40, -3, 0, "BACKGROUND")
	lit.glow:SetAlpha(FAINT)
	Embers(p, lit, spec, level + 3, function(n)
		local x, y = Polar(67, 166 + (n - 1) * 10)
		return x - band[2], y - band[3], spec.ember, 16
	end)
	Flare(p, lit, level + 6, 60, -3, 0)
	return p
end

local function Charge(parent, spec, level)
	local band = BAND.left
	local p = Medals.Piece(parent, level, band[4])
	Groove(p, band)
	Medals.Lit(p, spec, level + 1)
	p.bar = p.add(Bar(p.lit, band[1], "white", "ADD"), band[4])
	p.bar:SetStatusBarColor(Lift(spec.color, 0.3))
	p.bar:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.bar:SetMinMaxValues(0, 1)
	p.bar:SetValue(1)
	p.ready = Medals.Layer(p.lit, level + 2)
	local x, y = Polar(67, 160)
	x, y = x - band[2], y - band[3]
	p.lit.glow = Spot(p, p.ready, "glow", spec.color, 32, x, y, "BACKGROUND")
	Spot(p, p.ready, "stormOrb", "white", 22, x, y):SetVertexColor(Lift(spec.color, 0.3))
	p.timer = p.add(Medals.Timer(p.lit, level + 3, "orbRing", spec.color), 8)
	p.timer:SetDrawSwipe(false)
	p.timer:SetScript("OnCooldownDone", function()
		p.ready:Show()
		Medals.Fire(p)
	end)
	Flare(p, p.lit, level + 6, 70, x, y)
	return p
end

local function Shot(parent, spec, level, form)
	local p = Medals.Piece(parent, level, spec.size or SIZE)
	if form ~= "crest" then
		p.add(Medals.Texture(p, "BACKGROUND", 0, "pipArrowSteel90", "white", p.units)):SetAlpha(STEEL)
	end
	p.lit = Medals.Lit(p, spec, level + 1)
	p.lit:Hide()
	p.shots = {}
	for _, look in ipairs(spec.looks) do
		local layer = Medals.Layer(p.lit, level + 2)
		layer:Hide()
		p.add(Medals.Texture(layer, "BACKGROUND", 0, "glow", look.color, p.units * 0.9, "ADD")):SetAlpha(FAINT)
		for _, art in ipairs(look.arrows or { look.glyph }) do
			if look.arrows then
				p.add(Medals.Texture(layer, "BORDER", 0, "pipArrowGlow" .. art, look.color, p.units, "ADD"))
				p.add(Medals.Texture(layer, "ARTWORK", 0, "pipArrow" .. art, "white", p.units))
			else
				p.add(Medals.Texture(layer, "ARTWORK", 0, art, "white", p.units * 0.82, "ADD")):SetVertexColor(Lift(look.color, 0.2))
			end
		end
		p.shots[look] = layer
	end
	local rise = Medals.Steps(p.lit, { { 0, 1, 0.15 } })
	local jump, move = rise:CreateAnimation("Translation"), rise:CreateAnimation("Translation")
	jump:SetOffset(0, -p.units * 0.4)
	jump:SetDuration(0)
	move:SetOffset(0, p.units * 0.4)
	move:SetDuration(0.35)
	move:SetSmoothing("OUT")
	p.flare = { play = rise }
	return p
end

local function Bob(m)
	if m.pet:IsVisible() and not m.still then
		if not m.bob:IsPlaying() then
			m.bob:Play()
		end
	else
		m.bob:Stop()
	end
end

local function Pet(parent, spec, level, form)
	local band = BAND[spec.band]
	local k = form == "crest" and 1 or SIZE / band[4]
	local m = Medals.Piece(parent, level, band[4] * k)
	local function Off(r, angle)
		local x, y = Polar(r, angle)
		return (x - band[2]) * k, (y - band[3]) * k
	end
	if form ~= "crest" then
		m.add(Medals.Texture(m, "BACKGROUND", -1, "glow", "black", m.units * 1.9)):SetAlpha(0.7)
	end
	Groove(m, band, k)
	m.pet = Medals.Layer(m, level + 1)
	m.health = m.add(Bar(m.pet, band[1], "white", "ADD", spec.band == "pet"), m.units)
	m.health:SetStatusBarColor(Lift(spec.light, 0.3))
	m.health:SetReverseFill(true)
	m.health:SetPoint("CENTER", m, "CENTER", 0, 0)
	if spec.mood then
		m.mood = Spot(m, m.pet, "glow", "friendly", 14 * k, Off(67, 335))
	end
	if spec.mend then
		local mend = Medals.Feed(m.pet, { feed = "aura", unit = "pet", spells = spec.mend }, level + 2)
		mend.loops = {}
		for i = 1, 4 do
			local mote = Medals.Layer(mend, level + 2)
			Spot(m, mote, "glow", "friendly", 10 * k, Off(67, 335 - 11 * i))
			mote:SetAlpha(0)
			local group = mote:CreateAnimationGroup()
			group:SetLooping("REPEAT")
			for n, step in ipairs({ { 0, 0, 0.15 * i }, { 0, 1, 0.25 }, { 1, 0, 0.25 }, { 0, 0, 0.15 * (5 - i) } }) do
				ns.Slab.Fade(group, step[1], step[2], step[3], n)
			end
			mend.loops[i] = group
		end
		m.lits[#m.lits + 1] = mend
	end
	if spec.sigil then
		m.sigil = Medals.Layer(m.pet, level + 3)
		Spot(m, m.sigil, "glow", spec.light, 44 * k, Off(67, 184)):SetAlpha(0.5)
		Spot(m, m.sigil, spec.sigil, "white", 28 * k, Off(67, 184)):SetVertexColor(Lift(spec.light, 0.2))
		m.bob = m.sigil:CreateAnimationGroup()
		m.bob:SetLooping("REPEAT")
		for n, dy in ipairs({ 2, -2 }) do
			local t = m.bob:CreateAnimation("Translation")
			t:SetOffset(0, dy * k)
			t:SetDuration(1.1)
			t:SetOrder(n)
			t:SetSmoothing("IN_OUT")
		end
	end
	if spec.feed == "aura" then
		local lit, light = Band(m, setmetatable({ art = BAND.rim[1] }, { __index = spec }), level + 4, BAND.rim, false, 0.5, k)
		lit.art:SetPoint("CENTER", m, "CENTER", (BAND.rim[2] - band[2]) * k, 0)
		for i = 0, 5 do
			Spot(m, light, "trackerFlame", spec.color, 24 * k, Off(69, 162 + 8 * i)):SetDesaturated(true)
		end
		lit.loop = Medals.Steps(light, BURN, true)
		Flare(m, lit, level + 8, 120 * k, Off(67, 184))
	end
	return m
end

local function Gem(parent, spec, level, form)
	local m = Effect(parent, spec, level, form)
	if C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function" and UnitPowerPercent then
		m.lowMana = Medals.Layer(m.ready, level + 1)
		m.add(Medals.Texture(m.lowMana, "OVERLAY", 2, "glow", "magic", m.units * 2.2, "ADD"))
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

local function Well(parent, spec, level, form)
	if form == "crest" then
		return Medals.Plaque(parent, spec, level)
	end
	local p = Medals.Piece(parent, level, SIZE)
	p.add(Medals.Texture(p, "ARTWORK", 0, "glow", "magic", SIZE, "ADD")):SetAlpha(FAINT)
	p.timer = p.add(Medals.Timer(p, level + 4, "orbRing", spec.color), SIZE + 4)
	return p
end

local function Trinket(parent, spec, level, form)
	if form == "crest" then
		return Medals.Socket(parent, spec, level)
	end
	return Effect(parent, setmetatable({ look = "gem" }, { __index = spec }), level, form)
end

local function Jewel(parent, spec, level, form)
	return (form == "crest" and Medals.Socket or Effect)(parent, spec, level, form)
end

local function Swing(parent, spec, level)
	return ns.SlabRings.Swing(parent, spec, level, "crest")
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
	t.base = Medals.Piece(p, level, BASE)
	t.dim = t.base.add(Medals.Texture(t.base, "ARTWORK", 0, s.glyph, "steel", BASE - 3))
	t.dim:SetAlpha(STEEL)
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
	t.rune = lit:CreateTexture(nil, "OVERLAY")
	t.rune:SetTexture((Tokens.Texture(s.glyph)))
	t.rune:SetVertexColor(Lift(s.color))
	t.rune:SetBlendMode("ADD")
	t.rune:SetAllPoints(t.dim)
	t.neck = lit:CreateTexture(nil, "OVERLAY")
	t.neck:SetTexture((Tokens.Texture("glow")))
	t.neck:SetVertexColor(Lift(s.color, 0.2))
	t.neck:SetBlendMode("ADD")
	t.neck:SetSize(NECK, NECK)
	t.neck:SetPoint("CENTER", t.base, "CENTER", Polar(BASE / 2 + LIFT / 2, angle))
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
		t.base:SetShown(known)
		t.spire:SetShown(known)
		if known then
			local sx, sy = Medals.Cell(line + count)
			if form == "crest" then
				sx, sy = Polar(SOCKETS, t.angle)
			end
			count = count + 1
			local reach = BASE / 2 + LIFT + SPIRE / 2
			Medals.Place(t.base, anchor, sx, sy)
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
	if up and UnitHealthMax and UnitHealth then
		m.health:SetMinMaxValues(0, UnitHealthMax("pet"))
		m.health:SetValue(UnitHealth("pet"))
	end
	if m.bob then
		Bob(m)
	end
end

local function PaintShot(m)
	local shot = m.spec.shots[m.usable]
	if shot ~= m.shot then
		if m.shot then
			m.shots[m.shot]:Hide()
		end
		if shot then
			m.shots[shot]:Show()
		end
		m.shot = shot
	end
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
	if event == "PLAYER_SWING" then
		ns.SlabRings.Start(r, duration, kind)
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
		elseif shown and p.health and (all or ON.pet[event]) then
			PaintPet(p)
		elseif shown and p.curve and (all or event == "UNIT_POWER_UPDATE") then
			p.lowMana:SetAlpha(UnitPowerPercent("player", Enum and Enum.PowerType and Enum.PowerType.Mana or 0, false, p.curve))
		elseif shown and p.shots and (all or ON.usable[event]) then
			PaintShot(p)
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
		elseif p.bob then
			p.still = still
			Bob(p)
		end
	end
end

if CLASS == "HUNTER" then
	local ASPECTS = {
		{ spells = { 13165, 14318, 14319, 14320, 14321, 14322, 25296, 469145 }, color = "gilt", glyph = "glyphHawk" },
		{ spells = { 13163 }, color = "neutral", glyph = "glyphCrescents" },
		{ spells = { 5118 }, color = "steelLit", glyph = "glyphPaw" },
		{ spells = { 13159 }, color = "steelLit", glyph = "glyphPack" },
		{ spells = { 20043, 20190 }, color = "schoolNature", glyph = "glyphLeaf" },
		{ spells = { 13161, 1299445, 1299446, 1299447 }, color = "hostile", glyph = "glyphClaws" },
		{ spells = { 415423 }, color = "magic", glyph = "glyphCoil" },
	}
	local STINGS = {
		{ spells = { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295 }, color = "schoolNature", glyph = "glyphSerpent" },
		{ spells = { 3034, 14279, 14280 }, color = "magic", glyph = "glyphDrop" },
		{ spells = { 3043, 14275, 14276, 14277 }, color = "neutral", glyph = "glyphHook" },
		{ spells = { 19386, 24132, 24133, 24131, 24134, 24135 }, color = "jewelShard", glyph = "glyphWing" },
		{ spells = { 24118, 24119, 24120, 1299332 }, color = "hostile", glyph = "glyphTear" },
		{ spells = { 3674, 14296 }, color = "schoolShadow", glyph = "glyphBlackArrow" },
	}
	local COUNTER, MONGOOSE, AIMED, MULTI = { 20910, 20909, 19306, 1242634 }, { 14271, 14270, 14269, 1495 }, { 20904, 20903, 20902, 20901, 20900, 19434 }, { 2643 }
	local SHOTS, SHOWS = {}, {}
	for _, shot in ipairs({ { COUNTER, { glyph = "glyphCounter", color = "hostile" } }, { MONGOOSE, { glyph = "glyphFangs", color = "hostile" } },
		{ AIMED, { arrows = { 90 }, color = "giltLit" } }, { MULTI, { arrows = { 105, 90, 75 }, color = "steelLit" } } }) do
		SHOWS[#SHOWS + 1] = shot[2]
		for _, id in ipairs(shot[1]) do SHOTS[id] = shot[2] end
	end

	Trackers.Register("HUNTER", {
		{ key = "crestShot", seat = EMBLEM, size = SHOT, feed = "usable", build = Shot, color = "giltLit", shots = SHOTS, looks = SHOWS,
			groups = { COUNTER, MONGOOSE, AIMED, MULTI } },
		{ key = "crestAspect", seat = PERCH_LEFT, size = PERCH, build = Effect, choices = {
			{ feed = "aura", look = "glyph", glyph = "glyphHawk", spells = Trackers.Joined(ASPECTS[1].spells, ASPECTS[2].spells, ASPECTS[3].spells, ASPECTS[4].spells,
				ASPECTS[5].spells, ASPECTS[6].spells, ASPECTS[7].spells), feeds = ASPECTS },
			{ build = Flash, seat = EMBLEM, size = FLASH, feed = "cooldown", look = "orb", glyph = "glyphEdge", color = "gilt",
				known = { 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 } },
		} },
		{ key = "crestPet", seat = At(BAND.pet), choices = {
			{ build = Pet, band = "pet", light = "giltLit", known = { 883 }, mood = true, mend = { 136, 3111, 3661, 3662, 13542, 13543, 13544 } },
			{ build = Flash, seat = EMBLEM, size = FLASH, feed = "cooldown", look = "orb", color = "schoolArcane", known = { 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 } },
		} },
		{ key = "crestMark", seat = EMBLEM, build = Crest(Mark), look = "timed", glyph = "glyphReticle", feed = "aura", unit = "target", filter = "HARMFUL", color = "hostile",
			spells = { 1130, 14323, 14324, 14325 } },
		{ key = "crestSting", seat = At(BAND.right), build = Crest(Fuse), look = "brand", glyph = "glyphSerpent", feed = "aura", unit = "target",
			filter = "HARMFUL|PLAYER", color = "schoolNature", known = { 1978, 3034, 3043, 24118, 3674 }, feeds = STINGS },
		{ key = "crestAutoShot", seat = "rim", build = Swing, color = "steelLit", known = { 75 } },
		{ key = "crestCooldowns", seat = "cooldowns", color = "jewelHawk", families = { { spells = { 3045 }, sigil = "Volley" }, { spells = { 19263 }, sigil = "Deflect" },
			{ spells = { 19574 }, unit = "pet", sigil = "Paw" } } },
		{ key = "crestGust", seat = "rim", build = Moment, place = Ring, feed = "aura", spells = { 6150, 1299448, 469144, 3045 }, known = { 3045, 19552, 19553, 19554, 19555, 19556 },
			color = "jewelHawk", ambient = "medAmbientHunter", gust = true },
	}, { burst = "medBurstHunter", events = { { "UNIT_PET", "player" }, PET_EVENTS[1], PET_EVENTS[2], PET_EVENTS[3], "PLAYER_SWING", { "UNIT_INVENTORY_CHANGED", "player" } },
		paint = Paint, fiveSecond = Well, trinket = Trinket })
end

if CLASS == "MAGE" then
	local GEMS, INTELLECT = { 8008, 8007, 5513, 5514 }, { 1459, 1460, 1461, 10156, 10157, 23028 }
	local FROST_ARMOR, MAGE_ARMOR = { 168, 7300, 7301, 7302, 7320, 10219, 10220 }, { 6117, 22782, 22783 }
	local WARDS = { 11426, 13031, 13032, 13033, 1463, 8494, 8495, 10191, 10192, 10193, 543, 8457, 8458, 10223, 10225, 6143, 8461, 8462, 10177, 28609 }
	local FROSTBOLT = { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 }
	local CHILLS = Trackers.Joined(FROSTBOLT, { 120, 8492, 10159, 10160, 10161 })
	local NOVA = { 10230, 6131, 865, 122 }
	local CONJURE = { 10054, 10053, 3552, 759 }
	local IGNITE = { 11119, 11120, 12846, 12847, 12848 }
	local FIRE = { 412538, 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 }
	local WINTERS = { 11180, 28592, 28593, 28594, 28595 }

	Trackers.Register("MAGE", {
		{ key = "crestArmor", seat = At(BAND.armor), build = Crest(Armor), look = "timed", glyph = "glyphShieldFrost", feed = "aura", spells = Trackers.Joined(FROST_ARMOR, MAGE_ARMOR),
			feeds = { { spells = FROST_ARMOR, color = "schoolFrost", art = "glyphArmorFrost" },
				{ spells = MAGE_ARMOR, color = "schoolArcane", glyph = "glyphShieldArcane", art = "glyphArmorArcane" } } },
		{ key = "crestManaGem", seat = PENDANT, choices = {
			{ build = Gem, look = "gem", size = GEM, feed = "item", items = GEMS, color = "magic", lowMana = 0.3,
				known = function() return Medals.Known(CONJURE) or Have(GEMS) and CONJURE[#CONJURE] end },
			{ build = Effect, seat = PERCH_RIGHT, size = PERCH, look = "glyph", glyph = "glyphIntellect", feed = "aura", spells = INTELLECT, color = "schoolArcane" },
		} },
		{ key = "crestCounterspell", seat = PERCH_LEFT, build = Effect, look = "shard", feed = "cooldown", choices = {
			{ known = { 2139 }, color = "magic" },
			{ known = { 10199, 10197, 8413, 8412, 2138, 2137, 2136 }, look = "orb", color = "schoolFire" },
		} },
		{ key = "crestSchool", seat = At(BAND.left), look = "orb", choices = {
			{ build = Crest(Stacks), feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 22959 }, known = { 11095, 12872, 12873 }, color = "schoolFire",
				stacks = 5, ember = "trackerFlame" },
			{ build = Crest(Stacks), feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 12579 }, known = WINTERS, color = "schoolFrost", stacks = 5,
				ember = "glyphChillShard" },
			{ build = Crest(Charge), feed = "cooldown", known = { 1326079 }, color = "schoolArcane" },
			{ build = Crest(Charge), feed = "cooldown", known = NOVA, color = "schoolFrost" },
		} },
		{ key = "crestFrozen", seat = At(BAND.frost), build = Crest(Frozen), look = "timed", glyph = "glyphCrystal", feed = "aura", unit = "target", filter = "HARMFUL|PLAYER",
			color = "schoolFrost", choices = {
				{ spells = { 122, 865, 6131, 10230, 12494 }, known = NOVA },
				{ spells = FROSTBOLT },
			} },
		{ key = "crestYourSpell", seat = At(BAND.right), build = Crest(Fuse), look = "brand", feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", newest = true, choices = {
			{ spells = FIRE, known = IGNITE, color = "schoolFire", glyph = "glyphFireTongue" },
			{ spells = CHILLS, known = WINTERS, color = "schoolFrost", glyph = "glyphChillShard" },
			{ spells = { 118, 12824, 12825, 12826, 28271, 28272 }, color = "schoolArcane", glyph = "glyphPolyCurl" },
		} },
		{ key = "crestCooldowns", seat = "cooldowns", color = "pipMageGlow", families = { { spells = { 12042 }, sigil = "Arcane" },
			{ spells = { 12043 }, sigil = "Hourglass" }, { spells = { 11129, 28682 }, known = { 11129 }, sigil = "Flame" }, { spells = { 12051 }, sigil = "Vortex" },
			{ spells = { 11958, 27619 }, known = { 11958 }, sigil = "Crystal" } } },
		{ key = "crestWard", seat = "rim", build = Ward, place = Ring, feed = "aura", spells = WARDS, color = "rim", ward = true },
		{ key = "crestClearcasting", seat = "rim", build = Moment, place = Ring, feed = "aura", spells = { 12536 }, known = { 11213, 12574, 12575, 12576, 12577 },
			color = "schoolArcane", ambient = "medAmbientMage" },
	}, { burst = "medBurstMage", events = { { "UNIT_POWER_UPDATE", "player" } }, paint = Paint, fiveSecond = Well, trinket = Trinket })
end

if CLASS == "WARLOCK" then
	local DEMONS, SACRIFICE = { 688, 697, 712, 713, 691 }, { 18788 }
	local ARMORS = { 11735, 11734, 11733, 1086, 706, 696, 687 }
	local STONES = { 9421, 19012, 19013, 5510, 19010, 19011, 5509, 19008, 19009, 5511, 19006, 19007, 5512, 19004, 19005 }
	local CREATE = { 11730, 11729, 5699, 6202, 6201 }
	local CURSES = {
		{ spells = { 702, 1108, 6205, 7646, 11707, 11708 }, color = "jewelShard", glyph = "glyphWeakness" },
		{ spells = { 704, 7658, 7659, 11717 }, color = "hostile", glyph = "glyphBurst" },
		{ spells = { 1714, 11719 }, color = "schoolArcane", glyph = "glyphTongue" },
		{ spells = { 440892, 1311676, 1311677, 1311680 }, color = "schoolFire", glyph = "glyphElements" },
		{ spells = { 18223 }, color = "schoolFrost", glyph = "glyphHourglass" },
	}

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
		{ key = "crestDemon", seat = At(BAND.left), choices = {
			{ build = Pet, band = "left", light = "schoolNature", sigil = "glyphFangs", known = DEMONS, active = Demon, feed = "aura", color = "jewelShard",
				spells = { 18789, 18790, 18791, 18792 } },
			{ build = Effect, seat = SIGIL, size = PERCH, look = "glyph", glyph = "glyphHorns", feed = "aura", color = "jewelShard", spells = ARMORS },
		} },
		{ key = "crestHealthstone", seat = PENDANT, build = Effect, choices = {
			{ look = "gem", size = GEM, feed = "item", items = STONES, color = "friendly", known = function() return Medals.Known(CREATE) or Have(STONES) and CREATE[#CREATE] end },
			{ seat = PERCH_RIGHT, size = PERCH, look = "glyph", glyph = "glyphHorns", feed = "aura", color = "jewelShard", spells = ARMORS,
				known = function() return Medals.Known(DEMONS) and Medals.Known(ARMORS) end, active = Demon },
		} },
		{ key = "crestStone", seat = "lowerLeft", build = Jewel, look = "glyph", glyph = "glyphEdge", feed = "enchant", slot = "MainHand", color = "schoolFire",
			known = { 17728, 17727, 2362, 17953, 17952, 17951, 6366 } },
		{ key = "crestConflagrate", seat = "lowerRight", build = Jewel, look = "orb", glyph = "glyphCoal", feed = "cooldown", color = "schoolFire", known = { 1293818, 1293817, 18932, 18931, 18930, 17962 } },
		{ key = "crestCurse", seat = At(BAND.right), build = Crest(Fuse), look = "brand", glyph = "glyphWeakness", feed = "aura", unit = "target",
			filter = "HARMFUL|PLAYER", color = "jewelShard", known = Trackers.Joined(CURSES[1].spells, CURSES[2].spells, CURSES[3].spells, CURSES[4].spells,
			CURSES[5].spells), feeds = CURSES },
		{ key = "crestSpellLock", seat = PERCH_LEFT, build = Effect, feed = "cooldown", color = "schoolShadow", choices = {
			{ look = "blade", known = function() return Medals.Known({ 691 }) and (SpellLock() or 19244) end, active = SpellLock },
			{ look = "orb", known = { 17926, 17925, 6789 } },
		} },
		{ key = "crestCooldowns", seat = "cooldowns", color = "jewelShard", families = { { spells = { 18288 }, sigil = "Curse" },
			{ spells = { 18708 }, sigil = "Horns" }, { spells = { 6229, 11739, 11740, 28610 }, sigil = "Shade" },
			{ spells = { 7812, 19438, 19440, 19441, 19442, 19443 }, known = {}, sigil = "Void" } } },
		{ key = "crestWisps", seat = "rim", build = Wisps, place = PlaceWisps, items = { 6265 },
			known = function() return Medals.Known({ 1120, 8288, 8289, 11675 }) or Count(6265) > 0 and 1120 end },
		{ key = "crestTorments", seat = "rim", build = Spires, place = PlaceSpires, spires = {
			{ angle = 126, glyph = "glyphSwirl", color = "totemEarth", spells = { 172, 6222, 6223, 7648, 11671, 11672, 25311 } },
			{ angle = 102, glyph = "glyphEye", color = "jewelShard", spells = { 980, 1014, 6217, 11711, 11712, 11713, 603, 1225228 } },
			{ angle = 78, glyph = "glyphFireTongue", color = "schoolFire", spells = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 } },
			{ angle = 54, glyph = "glyphSiphon", color = "healthHostile", spells = { 18265, 18879, 18880, 18881 } },
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
		events = { PET_EVENTS[1], PET_EVENTS[2], "BAG_UPDATE_DELAYED", "PLAYER_TARGET_CHANGED" },
		update = { "UNIT_PET" },
		paint = Paint,
		motion = Motion,
		fiveSecond = Well,
		trinket = Trinket,
	})
end
