-- SlabRanged.lua: a hunter's, mage's and warlock's crest trackers, registered as rows with the one tracker lifecycle (SlabTrackers.lua; docs/medallions-effects.md#ranged-crest-trackers lists every seat): each seat's choices cover every build, pet state and level band, and each breaks out of the medal into the crest in additive light (a hunter's marks as looping spell-light auras in their sockets or over their dark figures, Medals.Mark), never a spell or item icon and never a round socket frame (a mage's or warlock's seated aura mark burns over its own small empty socket plate): your damage over time a fuse burning down the right band with its own mark at its head, the pet's or demon's health light along the band (a hunter's pet below Happy also lands a burning haunch on the lower right and tints its light amber or red), an Aspect, armor or demon sigil perched on the ring, a mage's armor as crystals that thaw along the upper left band and Frost Nova's frost over the inner ring, Hunter's Mark, the ready shots (each shot's layer drawn the first time it comes up) and the hunter's range ring over the emblem, the hunter pet's focus within its light, its family ability, Growl's orders and a potion on the hunter's trinket and lower band seats, a bag gem hanging from the lower right, an interrupt's blade through the lower left, a school's stacks as embers and a cooldown as an arc filling on the left band, the warlock's spires with their glyphs at their feet and its soul wisps, the Auto Shot ring and the class moments (Quick Shots, Clearcasting, Shadow Trance); the same effects free-standing in a row under Frames (Effect and its LOOKS, Well and Trinket); Blizzard's aura slots light every aura piece and blink it in its pandemic window, so Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local cos, sin, rad, min, max = math.cos, math.sin, math.rad, math.min, math.max
local IsSecret = Widgets.IsSecret
local Medals, Trackers = ns.SlabMedals, ns.SlabTrackers
local NIGHTFALL = { 18094, 18095 }
ns.SlabRanged = { NIGHTFALL = NIGHTFALL, PENDANT = { 80 * cos(rad(312)), 80 * sin(rad(312)) } }
local CLASS = UnitClass and select(2, UnitClass("player"))
if IsSecret(CLASS) or CLASS ~= "HUNTER" and CLASS ~= "MAGE" and CLASS ~= "WARLOCK" then
	return
end

local function Polar(r, angle)
	return r * cos(rad(angle)), r * sin(rad(angle))
end

local SIZE, BASE, SPIRE, WISP, LIFT, BAR, NECK = 26, 17, 24, 16, 1, 3, 8
local SOCKETS, ORBIT, PERIOD, STEPS, WISPS, HALO, INNER, LOW_AMMO, FAINT = 67, 46, 12, 24, 5, 1.6, 112, 200, 0.35
local STEEL, LIGHT, GROOVE, PERCH, GEM, SHOT, FLASH, HEAD = 0.45, 0.8, 0.35, 28, 26, 80, 36, 1
local MOODS, NONE = { "hostile", "neutral" }, {}
local LOOSE = { add = function(part) return part end }
local HAUNCH, HAUNCH_HALO, HAUNCH_BLINK, HAUNCH_HOLD, HAUNCH_FADE = 28, 1.65, 3, 0.15, 0.45
local FOCUS, REACH = 0.84, 92
local BREATH = { { 0.6, 1, 0.9 }, { 1, 0.6, 0.9 } }
local GLEAM = { { 0.8, 1, 0.7 }, { 1, 0.8, 0.7 } }
local MARK, MARK_IN, MARK_BACK, REST_FORGED, SHOT_FLAT, SHOT_FORGED = 24, 14, 2.6, 0.85, 0.82, 0.45
local DEMON, DEMON_SIZE = "glyphHornsPet", 24
local OPENING = { { 0, 1, 0.06 }, { 1, 0.3, 0.1 }, { 0.3, 1, 0.08 }, { 1, 0.3, 0.1 }, { 0.3, 1, 0.1 } }
local GROW = { { 0, 1, 0.6 } }
local BAND = {
	right = { "glyphArcRight", 64, 0, 58 }, left = { "glyphArcLeft", -64, 0, 58 }, pet = { "glyphArcPet", 42, -46, 42 },
	rim = { "glyphRimLeft", -72, 0, 62 }, armor = { "glyphArmorFrost", -37, 51, 64 }, frost = { "glyphFrost", 0, -39, 108 }, mark = { "glyphMarkReticle", -56, 0, 36 },
}
local EMBLEM, PERCH_LEFT, PERCH_RIGHT, PENDANT, SIGIL = { 0, 0 }, { Polar(73, 228) }, { Polar(74, 312) }, ns.SlabRanged.PENDANT, { Polar(56, 184) }
local LOOKS = {
	glyph = { k = 1.25, loop = BREATH, white = 0.1 },
	orb = { art = "stormOrb", k = 1.15 },
	gem = { art = "glyphFacet", k = 1, white = 0.15 },
	shard = { art = "pipShard50", steel = "pipShardSteel50", k = 1.4, bar = true, solid = true, native = true, rest = 0.9 },
	blade = { art = "pipBlade50", steel = "pipBladeSteel50", k = 1.4, bar = true, solid = true, rest = 0.9 },
}
local COME, FROM, GUST_RUN, GUST_REST = 0.45, { 20, 8 }, 0.7, 0.5
local PET_EVENTS = { { "UNIT_HEALTH", "pet" }, { "UNIT_MAXHEALTH", "pet" }, { "UNIT_HAPPINESS", "pet" } }
local ON = {
	swing = { PLAYER_SWING = true, UNIT_INVENTORY_CHANGED = true },
	pet = { UNIT_PET = true, UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_HAPPINESS = true, UNIT_POWER_UPDATE = true, UNIT_MAXPOWER = true },
	tracking = { PLAYER_TARGET_CHANGED = true, MINIMAP_UPDATE_TRACKING = true, UNIT_FACTION = true },
	range = { SPELL_RANGE_CHECK_UPDATE = true, PLAYER_TARGET_CHANGED = true, UNIT_FACTION = true },
	orders = { UNIT_PET = true, UNIT_TARGET = true, PLAYER_TARGET_CHANGED = true, GROUP_ROSTER_UPDATE = true },
	wisps = { BAG_UPDATE_DELAYED = true },
	usable = { SPELL_UPDATE_USABLE = true, SPELL_UPDATE_COOLDOWN = true, PLAYER_TARGET_CHANGED = true },
	rail = { SPELL_UPDATE_COOLDOWN = true, BAG_UPDATE_COOLDOWN = true, UNIT_SPELLCAST_SUCCEEDED = true },
}

local function Railed(on, spells, seated)
	return function()
		if ns.SlabRail.Holds(seated) == on then
			return Medals.Known(spells)
		end
	end
end

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

local function Hostile()
	local can = UnitCanAttack and UnitCanAttack("player", "target")
	return not IsSecret(can) and can == true
end

local function Plain(v)
	if not IsSecret(v) then
		return v
	end
end

local function PetKnown(spells)
	return function()
		local book, bank = C_SpellBook, Enum and Enum.SpellBookSpellBank
		if not (book and type(book.IsSpellKnown) == "function" and bank and bank.Pet) then
			return nil
		end
		for _, id in ipairs(spells) do
			local known = book.IsSpellKnown(id, bank.Pet)
			if not IsSecret(known) and known == true then
				return id
			end
		end
	end
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

local function Bloom(texture, from)
	local group, still = texture:CreateAnimationGroup(), texture:CreateAnimationGroup()
	ns.Slab.Grow(group, from, 1, 0.5)
	ns.Slab.Fade(group, 0, 1, 0.15)
	ns.Slab.Grow(still, from, from, 0.5)
	group.held, still.held = 0.5, 0.5
	return { play = group, still = still }
end

local function Swell(p, flare, seat, art, size, color, gold, r, g, b)
	if select(5, Tokens.Flipbook(select(5, Tokens.Texture(art)))) ~= 1 then
		return
	end
	flare.socket = p.add(Medals.Texture(seat, "ARTWORK", -1, "auraSocket", gold and "coinGold" or color, size))
	if r and not gold then
		flare.socket:SetVertexColor(r, g, b)
	end
end

local function Light(p, each, level, look)
	local art, size = each.glyph or look.art, p.units * look.k
	local lit = Medals.Lit(p, each, level)
	local hold = lit.container and lit or Medals.Layer(lit, level)
	local light = Medals.Layer(look.bar and lit or hold, level + 2)
	local cast, gated
	if look.bar then
		lit.art = p.add(Bar(light, art, "white", not look.solid and "ADD" or nil), size)
		lit.art:GetStatusBarTexture():SetDesaturated(not look.native)
		lit.art:SetPoint("CENTER", p, "CENTER", 0, 0)
		if not look.native then
			lit.art:SetStatusBarColor(Lift(each.color))
		end
	else
		local r, g, b = Lift(each.color, look.white)
		local aura
		local lights = lit.container and select(5, Tokens.Texture(art)) and Medals.Lights(p, lit, level + 3, light) or nil
		local gold
		lit.art, cast, _, gold, aura = Medals.Mark(p, light, art, size, each.color, r, g, b, level + 2, lights)
		lit.art:SetDesaturated(not aura)
		if lights and lights.flame:GetParent().container then
			local copy = lights.flame:GetParent()
			copy.flare, copy.loops, gated = Bloom(lights.flame, 1.2), { look.loop and Medals.Steps(lights.flame, look.loop, true) or nil }, true
			copy.flare.gate = lit.flames
			Swell(p, copy.flare, lights.flame, art, size, each.color, gold, r, g, b)
			Medals.Cue(p, lit, level + 3, light, art, lit.art, size, 1.2)
		end
	end
	if lit.container then
		lit.loop = Medals.Steps(light, look.loop, true)
		lit.flare = not gated and Bloom(cast or lit.art, 1.2) or nil
		if each.ring then
			lit.timer = p.add(Medals.Timer(lit, level + 3, "orbRing", each.color), max(size, p.units) + 4)
			lit:SetDurationCooldown(lit.timer)
		end
		return
	end
	lit.glow = p.add(Medals.Texture(hold, "BACKGROUND", 1, "glow", each.color, p.units * 1.6, "ADD"))
	lit.glow:SetAlpha(LIGHT)
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
	Medals.Flare(p, lit, level + 6, art, size * (select(4, Tokens.Texture(art)) and 1 or 1.8), nil, each.color)
end

local function Shadow(p, form)
	if form ~= "crest" then
		p.add(Medals.Texture(p, "BACKGROUND", -1, "glow", "black", p.units * 1.9)):SetAlpha(0.7)
	end
end

local function Effect(parent, spec, level, form)
	local look = LOOKS[spec.look]
	local p = Medals.Piece(parent, level, spec.size or SIZE)
	Shadow(p, form)
	for _, each in ipairs(spec.feeds or { spec }) do
		Light(p, each == spec and spec or setmetatable(each, { __index = spec }), level + 1, look)
	end
	p.rest = Medals.Layer(spec.feed == "item" and p.lit or p, level)
	local art = look.steel or spec.glyph or look.art
	p.rest:SetAlpha(look.rest or select(4, Tokens.Texture(art)) and REST_FORGED or STEEL)
	local learned = not (spec.learned and spec.feeds)
	for _, each in ipairs(learned and NONE or spec.feeds) do
		learned = learned or each.glyph == art and Medals.Known(rawget(each, "known") or each.spells) ~= nil
	end
	if learned then
		Medals.Dim(p, p.rest, art, p.units * look.k, "steel"):SetDesaturated(true)
	else
		p.add(Medals.Texture(p.rest, "ARTWORK", 0, art, "steel", p.units * look.k)):SetDesaturated(true)
	end
	for i, each in ipairs(select(4, Tokens.Texture(art)) and spec.feeds or {}) do
		if each.glyph ~= art then
			p.add(Medals.Texture(Medals.Layer(p.lits[i], level + 1), "BACKGROUND", 0, art, "black", p.units * look.k))
		end
	end
	return p
end

local function Flash(parent, spec, level, form)
	local p = Effect(parent, spec, level, form)
	if form == "crest" then
		p.ready:SetAlpha(0)
		Medals.Settle(p.lit.art, true)
		p.rest:Hide()
		p.timer:SetDrawSwipe(false)
	end
	return p
end

local function Window(parent, level, band, form)
	local k = form == "crest" and 1 or SIZE / band[4]
	local p = Medals.Piece(parent, level, band[4] * k)
	Shadow(p, form)
	return p, k, max(k, 0.6)
end

local function Spot(p, parent, art, color, size, x, y, layer)
	local t = p.add(Medals.Texture(parent, layer or "ARTWORK", 0, art, color, size, "ADD"))
	t:SetPoint("CENTER", p, "CENTER", x, y)
	return t
end

local function Seat(m, parent, art, color, size, x, y, lights)
	local seat = CreateFrame("Frame", nil, parent)
	seat:SetFrameLevel(parent:GetFrameLevel())
	seat:SetSize(1, 1)
	seat:SetPoint("CENTER", m, "CENTER", x, y)
	local r, g, b = Lift(color, 0.2)
	seat.fire = Medals.Mark(m, seat, art, size, color, r, g, b, nil, lights and lights(seat))
	return seat
end

local function Flare(p, lit, level, size, x, y)
	for _, flare in ipairs(Medals.Flare(p, lit, level, "glow", size)) do
		flare:SetPoint("CENTER", p, "CENTER", x, y)
	end
end

local function Groove(p, band, k)
	p.add(Medals.Texture(p, "BACKGROUND", 0, band[1], "black", band[4] * k)):SetAlpha(GROOVE)
end

local function Band(p, each, level, band, horizontal, white, k)
	local lit = Medals.Lit(p, each, level)
	local blink = Medals.Layer(lit, level)
	local light = Medals.Layer(blink, level + 1)
	lit.art = p.add(Bar(light, each.art or band[1], "white", "ADD", horizontal), band[4] * k)
	lit.art:SetStatusBarColor(Lift(each.color, white))
	lit.art:SetPoint("CENTER", p, "CENTER", 0, 0)
	Timed(lit, lit.art)
	lit.flicker = ns.Slab.Flicker(blink)
	return lit, light
end

local function Fuse(parent, spec, level, form)
	local band = BAND.right
	local p, k, h = Window(parent, level, band, form)
	Groove(p, band, k)
	for _, each in ipairs(spec.feeds or { spec }) do
		each = each == spec and spec or setmetatable(each, { __index = spec })
		local lit, light = Band(p, each, level + 1, band, false, 0.3, k)
		lit.head = CreateFrame("Frame", nil, light)
		lit.head:SetFrameLevel(level + 3)
		lit.head:SetSize(1, 1)
		lit.head:SetPoint("CENTER", lit.art:GetStatusBarTexture(), "TOP", HEAD * k, 0)
		local burn = Medals.Layer(lit.head, level + 3)
		local flame = p.add(Medals.Texture(burn, "BORDER", 0, "trackerFlame", each.color, 24 * h, "ADD"))
		flame:SetDesaturated(true)
		flame:SetPoint("CENTER", lit.head, "CENTER", 0, 5 * h)
		local r, g, b = Lift(each.color, 0.3)
		local seat, size = burn, 16 * h
		if select(4, Tokens.Texture(each.glyph)) then
			seat, size = CreateFrame("Frame", nil, lit.head), MARK * h
			seat:SetFrameLevel(level + 3)
			seat:SetSize(1, 1)
			seat:SetPoint("CENTER", lit.head, "CENTER", -MARK_IN * h, 0)
			for sub = -2, -1 do
				p.add(Medals.Texture(seat, "BACKGROUND", sub, "glow", "black", size * MARK_BACK))
			end
		end
		local above = level + (seat == burn and 3 or 4)
		if select(5, Tokens.Texture(each.glyph)) then
			local host = Medals.Layer(seat, above)
			lit.flare = not lit.container and Bloom(host, 1.5) or nil
			Medals.Later(p, each == spec and spec.known or rawget(each, "known") or each.spells, function()
				local lights = lit.container and Medals.Lights(p, lit, above + 1, host) or nil
				local gold
				lit.mark, _, _, gold = Medals.Mark(p, host, each.glyph, size, each.color, r, g, b, nil, lights)
				if lights and lights.flame:GetParent().container then
					local copy = lights.flame:GetParent()
					copy.flare, copy.flicker = Bloom(lights.flame, 1.5), ns.Slab.Flicker(lights.flame)
					copy.flare.gate = lit.flames
					Swell(p, copy.flare, lights.flame, each.glyph, size, each.color, gold, r, g, b)
					Medals.Cue(p, lit, above + 1, host, each.glyph, lit.mark, size, 1.5)
				end
			end)
		else
			local mark, cast = Medals.Mark(p, seat, each.glyph, size, each.color, r, g, b, above)
			lit.mark, lit.flare = mark, Bloom(cast, 1.5)
		end
		lit.loop = ns.Slab.Flicker(burn)
	end
	return p
end

local function Armor(parent, spec, level, form)
	local band = BAND.armor
	local p, k = Window(parent, level, band, form)
	p.add(Medals.Texture(p, "BACKGROUND", 0, band[1], "steel", band[4] * k)):SetAlpha(0.3)
	for _, each in ipairs(spec.feeds) do
		local lit, light = Band(p, setmetatable(each, { __index = spec }), level + 1, band, true, 0.35, k)
		lit.art:SetReverseFill(true)
		lit.loops = { Medals.Steps(light, GROW) }
		Flare(p, lit, level + 6, 60 * k, 0, 0)
	end
	return p
end

local function Frozen(parent, spec, level, form)
	local band = BAND.frost
	local p, k = Window(parent, level, band, form)
	local lit, light = Band(p, spec, level + 1, band, true, 0.45, k)
	lit.art:SetFillStyle(Enum and Enum.StatusBarFillStyle and Enum.StatusBarFillStyle.Center or "CENTER")
	lit.loops = { Medals.Steps(light, GROW) }
	Flare(p, lit, level + 6, 40 * k, 0, -10 * k)
	return p
end

local function Mark(parent, spec, level, form)
	local band = BAND.mark
	local p, k = Window(parent, level, band, form)
	local lit = Medals.Lit(p, spec, level + 1)
	local blink = Medals.Layer(lit, level + 1)
	local light = Medals.Layer(blink, level + 2)
	lit.glow = Spot(p, light, "glow", spec.color, 30 * k, 0, 0, "BACKGROUND")
	lit.art = p.add(Medals.Texture(light, "ARTWORK", 0, band[1], "white", band[4] * k, "ADD"))
	lit.art:SetVertexColor(Lift(spec.color, 0.2))
	lit.loops = { Medals.Steps(light, GLEAM, true), Bloom(lit.art, 1.25).play }
	lit.flicker = ns.Slab.Flicker(blink)
	return p
end

local function Stacks(parent, spec, level, form)
	local band = BAND.left
	local p, k, h = Window(parent, level, band, form)
	Groove(p, band, k)
	local lit = Medals.Lit(p, spec, level + 1)
	lit.glow = Spot(p, lit, "glow", spec.color, 40 * k, -3 * k, 0, "BACKGROUND")
	lit.glow:SetAlpha(FAINT)
	for n = 1, spec.stacks do
		local slot = lit.container:AddAuraSlot("ember" .. n, spec.filter, spec.options)
		pcall(slot.EnableMouse, slot, false)
		slot:SetAllPoints(p)
		slot:SetFrameLevel(level + 3)
		slot.container, slot.hold = lit.container, lit.hold
		local ember = p.add(Bar(slot, spec.ember, "white", "ADD"), 16 * h)
		ember:SetStatusBarColor(Lift(spec.color))
		local x, y = Polar(67, 166 + (n - 1) * 10)
		ember:SetPoint("CENTER", p, "CENTER", (x - band[2]) * k, (y - band[3]) * k)
		if select(5, Tokens.Texture(spec.ember)) then
			ember:GetStatusBarTexture():SetAlpha(0)
			local function Clip(owner)
				local clip = CreateFrame("Frame", nil, owner)
				clip:SetAllPoints(ember:GetStatusBarTexture())
				clip:SetClipsChildren(true)
				local seat = CreateFrame("Frame", nil, clip)
				seat:SetSize(1, 1)
				seat:SetPoint("CENTER", ember, "CENTER", 0, 0)
				return seat
			end
			local hosts = Medals.Lights(p, lit, level + 4, false)
			local flame, calm = hosts.flame, hosts.calm
			if not flame.embers then
				flame.embers, calm.embers = Medals.Layer(flame, level + 4), Medals.Layer(calm, level + 4)
				flame.flicker = flame.container and ns.Slab.Flicker(flame.embers) or nil
			end
			local r, g, b = Lift(spec.color, 0.3)
			ember.aura = Medals.Mark(p, Clip(ember), spec.ember, 16 * h, spec.color, r, g, b, nil, { flame = Clip(flame.embers), calm = Clip(calm.embers) })
		end
		slot:SetApplicationBar(ember, { minApplications = n - 1, maxApplications = n })
		slot.flicker = ns.Slab.Flicker(ember)
		p.lits[#p.lits + 1] = slot
	end
	Flare(p, lit, level + 6, 40 * k, -3 * k, 0)
	return p
end

local function Charge(parent, spec, level, form)
	local band = BAND.left
	local p, k, h = Window(parent, level, band, form)
	Groove(p, band, k)
	local lit = Medals.Lit(p, spec, level + 1)
	p.bar = p.add(Bar(lit, band[1], "white", "ADD"), band[4] * k)
	p.bar:SetStatusBarColor(Lift(spec.color, 0.3))
	p.bar:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.bar:SetMinMaxValues(0, 1)
	p.bar:SetValue(1)
	p.ready = Medals.Layer(lit, level + 2)
	local x, y = Polar(67, 160)
	x, y = (x - band[2]) * k, (y - band[3]) * k
	lit.glow = Spot(p, p.ready, "glow", spec.color, 32 * h, x, y, "BACKGROUND")
	Spot(p, p.ready, "stormOrb", "white", 22 * h, x, y):SetVertexColor(Lift(spec.color, 0.3))
	p.timer = p.add(Medals.Timer(lit, level + 3, "orbRing", spec.color), 8)
	p.timer:SetDrawSwipe(false)
	p.timer:SetScript("OnCooldownDone", function()
		p.ready:Show()
		Medals.Fire(p)
	end)
	Flare(p, lit, level + 6, 40 * h, x, y)
	return p
end

local function Look(p, look, level)
	local layer = Medals.Layer(p.lit, level + 2)
	layer:Hide()
	p.add(Medals.Texture(layer, "BACKGROUND", 0, "glow", look.color, p.units * 0.9, "ADD")):SetAlpha(FAINT)
	for i, art in ipairs(look.arrows or { look.glyph }) do
		if look.arrows then
			p.add(Medals.Texture(layer, "ARTWORK", 2 * i - 4, "pipArrow" .. art, "black", p.units))
			local fire = Medals.Aura(p, layer, "auraFigureArrow" .. art, p.units)
			for _, t in ipairs({ fire, fire.still }) do
				t:SetDrawLayer("ARTWORK", 2 * i - 3)
			end
		else
			Medals.Mark(p, layer, art, p.units * (select(4, Tokens.Texture(art)) and SHOT_FORGED or SHOT_FLAT), look.color, Lift(look.color, 0.2))
		end
	end
	layer.play = Medals.Steps(layer, look.arrows and { { 0, 1, 0.15 } } or OPENING)
	if look.arrows then
		local jump, move = layer.play:CreateAnimation("Translation"), layer.play:CreateAnimation("Translation")
		jump:SetOffset(0, -p.units * 0.15)
		jump:SetDuration(0)
		move:SetOffset(0, p.units * 0.15)
		move:SetDuration(0.35)
		move:SetSmoothing("OUT")
	end
	p.shots[look] = layer
end

local function Shot(parent, spec, level, form)
	local p = Medals.Piece(parent, level, spec.size or SIZE)
	if form ~= "crest" then
		p.add(Medals.Texture(p, "BACKGROUND", 0, "pipArrowSteel90", "white", p.units)):SetAlpha(STEEL)
	end
	Medals.Lit(p, spec, level + 1)
	p.lit:Hide()
	p.shots, p.looks = {}, level
	return p
end

local function Haunch(m, level, k, x, y)
	local size, first = HAUNCH * k, #m.parts + 1
	local seat = m.add(Medals.Layer(m.pet, level), size)
	seat:ClearAllPoints()
	seat:SetPoint("CENTER", m, "CENTER", x, y)
	seat:Hide()
	local sheen, _, tint, gold, aura = Medals.Mark(m, seat, "glyphHaunch", size, "neutral", Lift("coinGold", 0.2))
	if gold then
		tint.units = size * HAUNCH_HALO
	end
	local a, f = tint:GetAlpha(), Tokens.Flicker
	local feed = { seat = seat, sheen = sheen, tint = tint, gold = gold, aura = aura }
	feed.land = Medals.Steps(seat, { { 0, 1, HAUNCH_HOLD } })
	ns.Slab.Grow(feed.land, 1.35, 1, 0.35)
	feed.appear = Medals.Steps(seat, { { 0, 1, HAUNCH_HOLD } })
	feed.leave = Medals.Steps(seat, { { 1, 1, HAUNCH_HOLD }, { 1, 0, HAUNCH_FADE } })
	feed.leave:SetScript("OnFinished", function() seat:Hide() end)
	feed.flash = Medals.Steps(tint, { { a, 1, HAUNCH_HOLD }, { 1, a, HAUNCH_FADE } })
	feed.breath = Medals.Steps(tint, { { a, a * f.low, 0.9 }, { a * f.low, a, 0.9 } }, true)
	local blinks = {}
	for _ = 1, HAUNCH_BLINK / (2 * f.step) do
		blinks[#blinks + 1] = { a, a * f.low, f.step }
		blinks[#blinks + 1] = { a * f.low, a, f.step }
	end
	feed.blink = Medals.Steps(tint, blinks)
	if m.sized then
		for i = first, #m.parts do
			Medals.Even(m.parts[i])
		end
	end
	return feed
end

local Mourn

local function Lost(m, level, k, x, y)
	local size = HAUNCH * k
	local seat = m.add(Medals.Layer(m, level), size)
	seat:ClearAllPoints()
	seat:SetPoint("CENTER", m, "CENTER", x, y)
	seat:Hide()
	local halo = m.add(Medals.Texture(seat, "BACKGROUND", 1, "glow", "hostile", size * HAUNCH_HALO, "ADD"))
	local hound = m.add(Medals.Texture(seat, "ARTWORK", 0, "glyphHound", "steel", size))
	hound:SetDesaturated(true)
	hound:SetAlpha(REST_FORGED)
	local a, low = LIGHT, LIGHT * Tokens.Flicker.low
	halo:SetAlpha(a)
	local l = { seat = seat, size = size, halo = halo, hound = hound, breath = Medals.Steps(halo, { { a, low, 0.9 }, { low, a, 0.9 } }, true) }
	seat:HookScript("OnHide", function()
		l.breath:Stop()
	end)
	seat:HookScript("OnShow", function()
		Mourn(m)
	end)
	return l
end

local function Pet(parent, spec, level, form)
	local band = BAND[spec.band]
	local m, k = Window(parent, level, band, form)
	local function Off(r, angle)
		local x, y = Polar(r, angle)
		return (x - band[2]) * k, (y - band[3]) * k
	end
	Groove(m, band, k)
	m.pet = Medals.Layer(m, level + 1)
	m.health = m.add(Bar(m.pet, band[1], "white", "ADD", spec.band == "pet"), m.units)
	m.health:SetStatusBarColor(Lift(spec.light, 0.3))
	m.health:SetReverseFill(true)
	m.health:SetPoint("CENTER", m, "CENTER", 0, 0)
	if spec.mood then
		m.haunch = { level + 5, k, Off(80, 312) }
	end
	if spec.lost then
		m.lost = Lost(m, level + 5, k, Off(80, 312))
	end
	if spec.focus then
		m.focus = m.add(Bar(m.pet, band[1], "white", "ADD", spec.band == "pet"), m.units * FOCUS)
		m.focus:SetStatusBarColor(Lift(spec.focus, 0.3))
		m.focus:SetReverseFill(true)
		m.focus:SetPoint("CENTER", m, "CENTER", band[2] * k * (FOCUS - 1), band[3] * k * (FOCUS - 1))
	end
	if spec.mend then
		local mend = Medals.Feed(m.pet, { feed = "aura", unit = "pet", spells = spec.mend }, level + 2)
		mend.loops = {}
		for i = 1, 4 do
			local mote = Medals.Layer(mend, level + 2)
			Spot(m, mote, "glow", "friendly", 10 * k, Off(67, 335 - 11 * i))
			mend.loops[i] = Medals.Steps(mote, { { 0.3, 0.3, 0.15 * i }, { 0.3, 1, 0.25 }, { 1, 0.3, 0.25 }, { 0.3, 0.3, 0.15 * (5 - i) } }, true)
		end
		m.lits[#m.lits + 1] = mend
	end
	if spec.demons then
		m.sigil = Medals.Layer(m.pet, level + 3)
		m.at, m.size = { Off(67, 184) }, DEMON_SIZE * k
		m.art, m.marks = DEMON, { [DEMON] = Seat(m, m.sigil, DEMON, spec.light, m.size, unpack(m.at)) }
		for n, demon in ipairs(spec.demons) do
			local summon = { demon[4] }
			Medals.Later(m, summon, function()
				m.marks[demon[1]] = Seat(m, m.sigil, demon[1], spec.light, m.size, unpack(m.at))
				m.marks[demon[1]]:Hide()
			end)
			Medals.Later(m, function()
				return m.fel and spec.sacrifice and Medals.Known(summon) and Medals.Known(spec.sacrifice)
			end, function()
				local x, y = unpack(m.at)
				m.fel[n].seat = Seat(m, m.fel[n], demon[1] .. "Fel", spec.color, m.size, x, y, function(seat)
					return Medals.Lights(m, m.fel.lit, level + 7, seat, "fel" .. n, "HELPFUL", { candidateFilters = { includeSpellIDs = { [demon[3]] = true } } })
				end)
			end)
		end
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
		lit.loop = ns.Slab.Flicker(light)
		m.fel = { lit = lit }
		for n, demon in ipairs(spec.demons) do
			local slot = lit.container:AddAuraSlot("fel" .. n, "HELPFUL", { candidateFilters = { includeSpellIDs = { [demon[3]] = true } } })
			pcall(slot.EnableMouse, slot, false)
			slot:SetAllPoints(m)
			slot:SetFrameLevel(level + 6)
			slot.container, slot.hold = lit.container, lit.hold
			m.lits[#m.lits + 1] = slot
			m.fel[n] = slot
		end
		Flare(m, lit, level + 8, 40 * k, Off(60, 184))
	end
	return m
end

local function Gem(parent, spec, level, form)
	local m = Effect(parent, spec, level, form)
	m.bail = m.add(Medals.Texture(m, "BORDER", 0, "glyphBail", "gilt", m.units))
	m.bail:SetPoint("CENTER", m, "CENTER", 0, m.units * 0.62)
	if C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function" and UnitPowerPercent and spec.lowMana then
		m.lowMana = Medals.Layer(m.ready, level + 1)
		local glow = m.add(Medals.Texture(m.lowMana, "OVERLAY", 2, "glow", "magic", m.units * 2.2, "ADD"))
		m.pulse = Medals.Steps(glow, { { 0.5, 1, 0.4 }, { 1, 0.5, 0.4 } }, true)
		Medals.OnRest(function(still)
			if still or not m:IsVisible() then
				m.pulse:Stop()
			else
				m.pulse:Play()
			end
		end)
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
	local feed = Medals.Feed(r.lit.hold or r, spec, level + 3)
	feed.hold = r.lit.hold
	local hosts = Medals.Lights(r, feed, level + 3, false)
	local flame, calm = hosts.flame, hosts.calm
	local gust = Medals.Layer(flame, level + 3)
	r.gust = Medals.Aura(LOOSE, gust, "auraTrackerGust", 1, nil, nil, nil, nil, { flame = gust, calm = Medals.Layer(calm, level + 3) })
	local loop = gust:CreateAnimationGroup()
	loop:SetLooping("REPEAT")
	local jump, move = loop:CreateAnimation("Translation"), loop:CreateAnimation("Translation")
	jump:SetOffset(-ns.Slab.RING * 0.45, 0)
	jump:SetDuration(0)
	move:SetOffset(ns.Slab.RING * 0.9, 0)
	move:SetDuration(GUST_RUN)
	ns.Slab.Fade(loop, 0, 1, GUST_RUN / 4)
	ns.Slab.Fade(loop, 1, 0, GUST_RUN / 4, 1, GUST_RUN * 3 / 4):SetEndDelay(GUST_REST)
	flame.loop = flame.container and loop or nil
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
		for _, face in ipairs(Medals.Restricted() and {} or { piece, unpack(piece.twins or {}) }) do
			if face.gust then
				Widgets.Size(face.gust, INNER, INNER / 4)
				Widgets.Size(face.gust.still, INNER, INNER / 4)
			end
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
		s.art = Medals.Mark(s, s.wisp, "trackerWisp", WISP, "jewelShard")
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
		b.container, b.hold = container, p.hold
		local bar = t.spire.add(Bar(b, art .. angle, color, blend), size)
		bar:SetPoint("CENTER", t.spire, "CENTER", 0, 0)
		Timed(b, bar)
		t[key] = bar
		return b
	end
	Slot("glow", "pipSpireGlow", s.color, "ADD", SPIRE * 1.5, 1)
	local lit = Slot("lit", "pipSpire", "white", nil, SPIRE, 2)
	lit.spec = { feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = s.spells }
	t.lit:SetStatusBarColor(Lift(s.color, 0.55))
	lit.flicker = ns.Slab.Flicker(t.lit)
	Slot("core", "pipSpireCore", s.color, "ADD", SPIRE, 3)
	local foot = CreateFrame("Frame", nil, lit)
	foot:SetFrameLevel(lit:GetFrameLevel())
	foot:SetAllPoints(t.base)
	Medals.Later(p, s.spells, function()
		local socket
		t.dim, socket = Medals.Dim(t.base, t.base, s.glyph, BASE - 3, "steel")
		t.dim:SetDesaturated(true)
		for _, part in ipairs({ t.dim, socket }) do
			part:SetAlpha(STEEL)
		end
		local r, g, b = Lift(s.color)
		t.rune = Medals.Mark(t.base, foot, s.glyph, BASE - 3, s.color, r, g, b, nil, Medals.Lights(p, lit, level + 2, foot))
		t.base.sized = nil
	end)
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
	p.hold = Medals.Layer(p, level)
	p.container = CreateFrame("AuraContainer", nil, p.hold, "CustomAuraContainerTemplate")
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
	for k, t in ipairs(p.spires) do
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
			for _, face in ipairs({ p, unpack(p.twins or {}) }) do
				local each = face.spires[k]
				Medals.Place(each.base, anchor, sx, sy)
				Medals.Place(each.spire, anchor, sx + reach * cos(rad(t.angle)), sy + reach * sin(rad(t.angle)))
			end
		end
	end
	return line + count
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

local function Sigil(m)
	local book, bank, art = C_SpellBook, Enum and Enum.SpellBookSpellBank, DEMON
	for _, demon in ipairs(book and type(book.IsSpellKnown) == "function" and bank and m.spec.demons or NONE) do
		for _, id in ipairs(demon[2]) do
			local known = book.IsSpellKnown(id, bank.Pet)
			if not IsSecret(known) and known == true then
				art = demon[1]
			end
		end
	end
	art = m.marks[art] and art or DEMON
	if art ~= m.art then
		m.marks[m.art]:Hide()
		m.marks[art]:Show()
		m.art = art
	end
end

local function Breathe(m)
	local f = m.feed
	if not (m.moody == 2 and Effects.Allows("pulse") and not m.still) then
		f.breath:Stop()
	elseif not f.breath:IsPlaying() then
		f.breath:Play()
	end
	if not Effects.Allows("pulse") then
		f.blink:Stop()
	end
end

function Mourn(m)
	local l = m.lost
	if l.gone == "dead" and Effects.Allows("pulse") and not m.still and l.seat:IsVisible() then
		if not l.breath:IsPlaying() then
			l.breath:Play()
		end
	else
		l.breath:Stop()
	end
end

local function Burn(m, l)
	local first = #m.parts + 1
	l.burn = m.add(Medals.Layer(l.seat, l.seat:GetFrameLevel() + 1), l.size)
	l.burn:ClearAllPoints()
	l.burn:SetPoint("CENTER", l.seat, "CENTER", 0, 0)
	l.burn:Hide()
	l.fire = Medals.Mark(m, l.burn, "glyphHound", l.size, "hostile")
	if m.sized then
		for i = first, #m.parts do
			Medals.Even(m.parts[i])
		end
	end
end

local function Gone(m, gone)
	local l = m.lost
	if gone == l.gone then
		return
	end
	l.gone = gone
	l.seat:SetShown(gone ~= nil)
	l.halo:SetShown(gone == "dead")
	if gone == "dead" and not l.burn then
		Burn(m, l)
	end
	l.hound:SetShown(gone ~= "dead")
	if l.burn then
		l.burn:SetShown(gone == "dead")
	end
	Mourn(m)
end

local function Tint(f, color)
	if f.gold then
		f.tint:SetVertexColor(Tokens.Color(color))
	else
		local r, g, b = Lift(color, 0.2)
		if not f.aura then
			f.sheen:SetVertexColor(r, g, b)
		end
		f.tint:SetVertexColor(r, g, b)
	end
end

local function Mood(m, mood, changed, happy)
	local was = m.moody
	m.moody = mood
	m.health:SetStatusBarColor(Lift(mood and MOODS[mood] or m.spec.light, 0.3))
	if mood == was then
		return
	end
	m.feed = m.feed or mood and Haunch(m, unpack(m.haunch))
	local f = m.feed
	if not f then
		return
	end
	local level = ns.Slab.Level()
	local moving = changed and level ~= "off"
	f.breath:Stop()
	f.blink:Stop()
	if mood then
		Tint(f, MOODS[mood])
		f.leave:Stop()
		f.flash:Stop()
		f.seat:Show()
		if moving and (was == nil or mood < was) then
			if level == "full" then
				Medals.Arbitrate(f.land):Play()
			else
				f.appear:Play()
			end
			if mood == 1 and level == "full" then
				f.blink:Play()
			end
		end
	elseif was and moving and happy then
		Tint(f, "friendly")
		if level == "full" then
			f.flash:Play()
		end
		f.leave:Play()
	else
		f.leave:Stop()
		f.seat:Hide()
	end
	Breathe(m)
end

local function Focus(m)
	if m.up and m.focus and UnitPowerMax and UnitPower then
		m.focus:SetMinMaxValues(0, UnitPowerMax("pet"))
		m.focus:SetValue(UnitPower("pet"))
	end
end

local function PaintPet(m, event)
	if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
		return Focus(m)
	end
	local out, dead = Out(), UnitIsDead and UnitIsDead("pet")
	dead = out and not IsSecret(dead) and dead == true
	local up = out and not dead
	if m.lost then
		Gone(m, not out and "missing" or dead and "dead" or nil)
	end
	if up ~= m.up then
		m.up = up
		m.pet:SetShown(up)
		if m.bob then
			Bob(m)
		end
	end
	if up and UnitHealthMax and UnitHealth then
		m.health:SetMinMaxValues(0, UnitHealthMax("pet"))
		m.health:SetValue(UnitHealth("pet"))
	end
	Focus(m)
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		return
	end
	if m.marks and up then
		Sigil(m)
	end
	if m.haunch then
		local info = C_PetInfo
		local mood = up and info and type(info.GetPetHappiness) == "function" and info.GetPetHappiness()
		mood = not IsSecret(mood) and mood
		Mood(m, MOODS[mood] and mood or nil, event == "UNIT_HAPPINESS", mood == 3)
	end
end

local function Sign(parent, spec, level, form)
	local look = LOOKS[spec.look]
	local p = Medals.Piece(parent, level, spec.size or SIZE)
	local size = p.units * look.k
	Shadow(p, form)
	p.rest = Medals.Layer(p, level)
	p.rest:SetAlpha(select(4, Tokens.Texture(spec.glyph)) and REST_FORGED or STEEL)
	p.add(Medals.Texture(p.rest, "ARTWORK", 0, spec.glyph, "steel", size)):SetDesaturated(true)
	p.match = Medals.Layer(p, level + 2)
	local r, g, b = Lift(spec.color, look.white)
	local art = Medals.Mark(p, p.match, spec.glyph, size, spec.color, r, g, b, level + 2)
	art:SetDesaturated(true)
	p.kind, p.tracking = spec.feed, spec.types
	p.rest:Hide()
	p.match:Hide()
	return p
end

local HELD = {}

local function Release(p, keep)
	for id in pairs(p.checked) do
		if not (keep and keep[id]) then
			p.checked[id] = nil
			HELD[id] = HELD[id] - 1
			if HELD[id] == 0 then
				HELD[id] = nil
				C_Spell.EnableSpellRangeCheck(id, false)
			end
		end
	end
end

local function Reach(parent, spec, level)
	local p = Medals.Piece(parent, level, spec.size or SIZE)
	p.ring = p.add(Medals.Texture(p, "OVERLAY", 0, "ringLine16", "white", p.units))
	p.ring:Hide()
	p.kind, p.checked, p.wanted = spec.feed, {}, {}
	p:HookScript("OnHide", function()
		Release(p)
	end)
	return p
end

local function Tracked(types)
	local map = C_Minimap
	local n = map and type(map.GetNumTrackingTypes) == "function" and type(map.GetTrackingInfo) == "function" and Plain(map.GetNumTrackingTypes())
	for i = 1, type(n) == "number" and n or 0 do
		local info = map.GetTrackingInfo(i)
		local id = type(info) == "table" and Plain(info.active) == true and Plain(info.spellID)
		if id and types[id] then
			return types[id]
		end
	end
end

local function PaintTrack(p)
	local hostile, of = Hostile(), nil
	if hostile and UnitCreatureType then
		of = Plain(select(2, UnitCreatureType("target")))
	end
	local kind = hostile and Tracked(p.tracking)
	local match = type(of) == "number" and kind == of
	p.rest:SetShown(hostile and not match)
	p.match:SetShown(match)
end

local function PaintOrders(p)
	local out, wrong = Out(), false
	if out then
		local get, auto = C_Spell and C_Spell.GetSpellAutoCast, nil
		if type(get) == "function" then
			auto = Plain(select(2, get(p.spec.spell)))
		end
		local grouped = Plain(IsInGroup and IsInGroup())
		wrong = type(auto) == "boolean" and auto == (grouped == true)
		if not wrong and Hostile() and UnitExists and UnitIsUnit then
			local has, same = UnitExists("pettarget"), UnitIsUnit("pettarget", "target")
			wrong = not IsSecret(has) and has == true and not IsSecret(same) and same == false
		end
	end
	p.rest:SetShown(out and not wrong)
	p.match:SetShown(out and wrong)
end

local function Check(p, id)
	if id and not p.checked[id] then
		p.checked[id] = true
		HELD[id] = (HELD[id] or 0) + 1
		if HELD[id] == 1 then
			C_Spell.EnableSpellRangeCheck(id, true)
		end
	end
end

local function PaintReach(p)
	local api, shot, melee = C_Spell, nil, nil
	if Hostile() and api and type(api.IsSpellInRange) == "function" and type(api.EnableSpellRangeCheck) == "function" then
		local close, wanted = Medals.Known(p.spec.melee), p.wanted
		for id in pairs(wanted) do
			wanted[id] = nil
		end
		wanted[p.spec.spell] = true
		if close then
			wanted[close] = true
		end
		Release(p, wanted)
		Check(p, p.spec.spell)
		Check(p, close)
		shot = Plain(api.IsSpellInRange(p.spec.spell, "target"))
		melee = close and Plain(api.IsSpellInRange(close, "target"))
	end
	local color = shot == false and (melee == true and "giltLit" or melee == false and "hostile") or nil
	p.ring:SetShown(color ~= nil)
	if color then
		p.ring:SetVertexColor(Tokens.Color(color))
	end
end

local function PaintShot(m)
	local shot = m.spec.shots[m.usable]
	if shot and not m.shots[shot] then
		local first = #m.parts + 1
		Look(m, shot, m.looks)
		for i = first, #m.parts do
			Medals.Even(m.parts[i])
		end
	end
	if shot ~= m.shot then
		if m.shot then
			m.shots[m.shot]:Hide()
		end
		m.shot, m.flare = shot, shot and m.shots[shot]
		if shot then
			m.flare:Show()
			Medals.Fire(m)
		end
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
	local claimed = moving and n < was and Medals.Claim(function()
		for _, s in ipairs(w.seats) do
			s.flare.play:Stop()
		end
	end) ~= nil
	for i, s in ipairs(w.seats) do
		s.wisp:SetShown(i <= n)
		s.come:Stop()
		if moving and i > was and i <= n then
			s.come:Play()
		elseif claimed and i <= was and i > n then
			s.flare.play:Stop()
			s.flare.play:Play()
		end
	end
	if w.full then
		w.full:SetShown(total >= WISPS)
	end
	Spin(w)
end

local PAINT = { tracking = PaintTrack, orders = PaintOrders, range = PaintReach }

local function Paint(form, event, ...)
	local all = event == nil
	for _, p in pairs(form.pieces) do
		if p.swing then
			if (all or ON.swing[event]) and p:IsShown() then
				PaintSwing(p, event, ...)
			end
		elseif p.health then
			if (all or ON.pet[event]) and p:IsShown() then
				PaintPet(p, event)
			end
		elseif p.curve then
			if (all or event == "UNIT_POWER_UPDATE") and p:IsShown() then
				p.lowMana:SetAlpha(UnitPowerPercent("player", Enum and Enum.PowerType and Enum.PowerType.Mana or 0, false, p.curve))
			end
		elseif p.kind then
			if (all or ON[p.kind][event]) and p:IsShown() then
				PAINT[p.kind](p)
			end
		elseif p.shots then
			if (all or ON.usable[event]) and p:IsShown() then
				PaintShot(p)
			end
		elseif p.seats then
			if (all or ON.wisps[event]) and p:IsShown() then
				PaintWisps(p, not all and Effects.Allows("flare"))
			end
		elseif p.rail then
			if (all or ON.rail[event]) and p:IsShown() then
				ns.SlabRail.Paint(p, event, ...)
			end
		elseif p.spires and event == "PLAYER_TARGET_CHANGED" and p:IsShown() then
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
		elseif p.haunch or p.lost then
			p.still = still
			if p.feed then
				Breathe(p)
			end
			if p.lost then
				Mourn(p)
			end
		elseif p.rail and p:IsShown() then
			ns.SlabRail.Paint(p)
		end
	end
end

if CLASS == "HUNTER" then
	local FAMILIES = K.SpellFamilies.HUNTER
	local function Family(key, color)
		return { spells = FAMILIES[key].spells, glyph = FAMILIES[key].glyph, color = color }
	end
	local ASPECTS = { Family("hawk", "gilt"), Family("monkey", "neutral"), Family("cheetah", "steelLit"), Family("pack", "steelLit"), Family("wild", "schoolNature"),
		Family("beast", "hostile"), Family("viper", "magic") }
	local STINGS = { Family("serpent", "schoolNature"), Family("viperSting", "magic"), Family("scorpid", "neutral"), Family("wyvern", "schoolFire"),
		Family("lacerate", "hostile"), Family("blackArrow", "schoolShadow"),
		{ spells = { 13797, 14298, 14299, 14300, 14301 }, known = { 13795, 14302, 14303, 14304, 14305 }, color = "schoolFire", glyph = "sigilFireTrapFuse" } }
	local RAPTOR = FAMILIES.raptor.spells
	local MELEE = Trackers.Joined(RAPTOR, { 14268, 14267, 2974 })
	local GROWL = { 14921, 14920, 14919, 14918, 14917, 14916, 2649 }
	local SCREECH, SCORPID = { 24579, 24578, 24577, 24423 }, { 24640, 24587, 24586, 24583 }
	local REND, DUST = { 1265069, 1265068, 1265067, 1265066, 1265065 }, { 1265904, 1265903, 1265902, 1265901, 1265899 }
	local HOWL = { 24605, 24604, 24603, 24597 }
	local FAMILY = Trackers.Joined(SCREECH, SCORPID, REND, DUST, HOWL, { 7371, 26177, 26178, 26179, 26201, 27685 }, { 23110, 23109, 23099 },
		{ 23148, 23147, 23145 }, { 1264455, 26188, 26187, 26090 }, { 26064 }, { 1264482, 1264481, 1264480, 1264479, 1264478 },
		{ 1265883, 1265881, 1265880, 1265878, 1265843 }, { 1264742, 1264741, 1264739, 1264736, 1264735 }, { 1265042, 1265041, 1265040, 1265039, 1265038 },
		{ 1264933, 1264930, 1264929, 1264927, 1264758 }, { 1265058, 1265057, 1265056, 1265055, 1265054 }, { 1310612 }, { 444681, 444678 })
	local POTIONS = { 13446, 13444, 3928, 13443, 1710, 6149, 929, 3827, 858, 3385, 118, 2455 }
	local TRUESHOT, TRUESHOT_SEAT, COMPASS_SEAT = { 19506, 20905, 20906, 1299346, 1299348 }, { Polar(74, 140) }, { Polar(74, 40) }
	local TRACKS = { [1494] = 1, [19879] = 2, [19878] = 3, [19880] = 4, [19882] = 5, [19884] = 6, [19883] = 7 }
	local COUNTER, MONGOOSE, AIMED, MULTI = FAMILIES.counter.spells, FAMILIES.mongoose.spells, FAMILIES.aimed.spells, { 2643 }
	local SHOTS, SHOWS = {}, {}
	for _, shot in ipairs({ { COUNTER, { glyph = FAMILIES.counter.glyph, color = "hostile" } }, { MONGOOSE, { glyph = FAMILIES.mongoose.glyph, color = "hostile" } },
		{ AIMED, { arrows = { 90 }, color = "giltLit" } }, { MULTI, { arrows = { 105, 75, 90 }, color = "steelLit" } } }) do
		SHOWS[#SHOWS + 1] = shot[2]
		for _, id in ipairs(shot[1]) do SHOTS[id] = shot[2] end
	end

	ns.SlabRail.Register("HUNTER", {
		color = "jewelHawk",
		burst = "medBurstHunter",
		abilities = {
			rapid = { spells = { 3045 }, sigil = "Volley", unit = "player" },
			wrath = { spells = { 19574 }, sigil = "Paw", unit = "pet" },
			deter = { spells = { 19263 }, sigil = "Deflect", unit = "player" },
			intimidate = { spells = { 19577 }, sigil = "Intimidate" },
			trap = { spells = { 14305, 14304, 14303, 14302, 13795, 14317, 14316, 13813 }, sigil = "FireTrap" },
			sniper = { spells = { 1310786, 1310785, 1310687 }, sigil = "Sniper" },
			aimed = { spells = AIMED, sigil = "Aimed" },
			strider = { spells = { 1317257 }, sigil = "Strider" },
		},
		majors = { "rapid", "wrath", "deter", "intimidate" },
		trees = {
			{ majors = { "wrath", "rapid", "intimidate" }, fill = { "trap" } },
			{ majors = { "rapid" }, fill = { "trap", "sniper", "aimed" } },
			{ majors = { "rapid", "deter" }, fill = { "trap", "strider" } },
		},
		signs = { { { 19574 }, { 19577 } }, { { 1310786, 1310785, 1310687 }, AIMED }, { { 19263 }, { 1317257 } } },
	})

	Trackers.Register("HUNTER", {
		{ key = "crestShot", seat = EMBLEM, size = SHOT, feed = "usable", build = Shot, color = "giltLit", shots = SHOTS, looks = SHOWS,
			groups = { COUNTER, MONGOOSE, AIMED, MULTI } },
		{ key = "crestAspect", seat = PERCH_LEFT, size = PERCH, build = Effect, choices = {
			{ feed = "aura", look = "glyph", glyph = "glyphHawk", spells = Trackers.Joined(ASPECTS[1].spells, ASPECTS[2].spells, ASPECTS[3].spells, ASPECTS[4].spells,
				ASPECTS[5].spells, ASPECTS[6].spells, ASPECTS[7].spells), feeds = ASPECTS, learned = true },
			{ build = Flash, seat = EMBLEM, overlay = true, size = FLASH, feed = "cooldown", look = "orb", glyph = FAMILIES.raptor.glyph, color = "gilt", known = RAPTOR },
		} },
		{ key = "crestPet", seat = At(BAND.pet), choices = {
			{ build = Pet, band = "pet", feed = "pet", light = "giltLit", focus = "steelLit", known = { 883 }, mood = true, lost = true,
				mend = FAMILIES.mend.spells },
			{ build = Flash, seat = EMBLEM, overlay = true, size = FLASH, feed = "cooldown", look = "orb", color = "schoolArcane", known = { 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 } },
		} },
		{ key = "crestMark", seat = At(BAND.mark), build = Mark, feed = "aura", unit = "target", filter = "HARMFUL", color = "hostile",
			spells = { 1130, 14323, 14324, 14325 } },
		{ key = "crestSting", seat = At(BAND.right), build = Fuse, glyph = "glyphSerpent", feed = "aura", unit = "target",
			filter = "HARMFUL|PLAYER", color = "schoolNature", known = { 1978, 3034, 3043, 24118, 3674, 13795 }, feeds = STINGS, learned = true },
		{ key = "crestTrueshot", seat = TRUESHOT_SEAT, size = PERCH, build = Effect, look = "glyph", glyph = "glyphTrueshot", feed = "aura", color = "gilt",
			spells = TRUESHOT },
		{ key = "crestTracking", seat = COMPASS_SEAT, size = PERCH, build = Sign, look = "glyph", glyph = "glyphCompass", feed = "tracking", color = "gilt",
			known = { 24293 }, types = TRACKS },
		{ key = "crestRange", seat = EMBLEM, overlay = true, size = REACH, build = Reach, feed = "range", known = { 75 }, melee = MELEE },
		{ key = "crestPetAbility", seat = { 33, -24 }, size = PERCH, build = Effect, look = "glyph", glyph = "glyphFamily", feed = "cooldown", route = "petCooldown",
			color = "giltLit", known = PetKnown(FAMILY), feeds = {
				{ feed = "cooldown" },
				{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = Trackers.Joined(SCREECH, SCORPID, REND, DUST), color = "hostile", ring = true },
				{ feed = "aura", filter = "HELPFUL|PLAYER", spells = HOWL, color = "gilt", ring = true },
			} },
		{ key = "crestOrders", seat = { 0, -39 }, size = PERCH, build = Sign, look = "glyph", glyph = "glyphGrowl", feed = "orders", color = "hostile",
			known = PetKnown(GROWL) },
		{ key = "crestTranq", seat = "footLeft", size = Medals.FOOT, build = Effect, look = "glyph", glyph = "glyphTranq", feed = "cooldown", color = "giltLit",
			known = { 19801 } },
		{ key = "crestPotion", seat = { -33, -24 }, size = GEM, build = Gem, look = "gem", feed = "item", items = POTIONS, color = "friendly", known = { 75 } },
		{ key = "crestAutoShot", seat = "rim", build = Swing, color = "steelLit", known = { 75 } },
		{ key = "crestCooldowns", seat = "cooldowns", color = "jewelHawk", families = { { spells = { 3045 }, sigil = "Volley", major = true }, { spells = { 19263 }, sigil = "Deflect", major = true },
			{ spells = { 19574 }, unit = "pet", sigil = "Paw", major = true } }, railed = ns.SlabRail.Holds },
		{ key = "crestGust", seat = "rim", build = Moment, place = Ring, feed = "aura", color = "jewelHawk", ambient = "medAmbientHunter", gust = true, choices = {
			{ spells = { 6150, 1299448, 469144, 3045 }, known = Railed(false, { 3045, 19552, 19553, 19554, 19555, 19556 }, { 3045 }) },
			{ spells = { 6150, 1299448, 469144 }, known = Railed(true, { 19552, 19553, 19554, 19555, 19556 }, { 3045 }) },
		} },
		{ key = "crestRail", seat = "rim", build = ns.SlabRail.Build, place = ns.SlabRail.Place, known = ns.SlabRail.Known, hold = ns.SlabRail.Holding, crestOnly = true },
	}, { burst = "medBurstHunter", pick = ns.SlabRail.Pick, commit = ns.SlabRail.Commit, rail = ns.SlabRail.Holds, update = { "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "PET_BAR_UPDATE" },
		events = { "PLAYER_SWING", { "UNIT_INVENTORY_CHANGED", "player" }, "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
		kinds = {
			pet = { { "UNIT_PET", "player" }, PET_EVENTS[1], PET_EVENTS[2], PET_EVENTS[3], { "UNIT_POWER_UPDATE", "pet" }, { "UNIT_MAXPOWER", "pet" } },
			tracking = { "PLAYER_TARGET_CHANGED", "MINIMAP_UPDATE_TRACKING", { "UNIT_FACTION", "target" } },
			range = { "SPELL_RANGE_CHECK_UPDATE", "PLAYER_TARGET_CHANGED", { "UNIT_FACTION", "target" } },
			orders = { { "UNIT_PET", "player" }, { "UNIT_TARGET", "pet" }, "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE" },
		}, paint = Paint, motion = Motion, figures = true })
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
	local CLEARCASTING = { 11213, 12574, 12575, 12576, 12577 }
	local function Shown(spells, slot)
		return ns.SlabRail.Holds(spells, slot) or ns.SlabOrb.Holds(spells)
	end
	local function Commit()
		local rail, orb = ns.SlabRail.Commit(), ns.SlabOrb.Commit()
		return rail or orb
	end

	local FIRE_BLAST = { 10199, 10197, 8413, 8412, 2138, 2137, 2136, 400623, 400622, 400621, 400620, 400616, 400619, 400618 }
	ns.SlabRail.Register("MAGE", {
		color = "pipMageGlow",
		burst = "medBurstMage",
		abilities = {
			power = { spells = { 12042 }, sigil = "Arcane", unit = "player" },
			presence = { spells = { 12043 }, sigil = "Hourglass", unit = "player" },
			combustion = { spells = { 11129 }, buffs = { 11129, 28682 }, sigil = "Flame", unit = "player" },
			block = { spells = { 11958 }, buffs = { 11958, 27619 }, sigil = "Crystal", unit = "player" },
			evocation = { spells = { 12051 }, sigil = "Vortex", unit = "player" },
			snap = { spells = { 12472 }, sigil = "ColdSnap" },
			blast = { spells = FIRE_BLAST, sigil = "FireBlast" },
			cone = { spells = { 10161, 10160, 10159, 8492, 120 } },
			barrier = { spells = { 13033, 13032, 13031, 11426 }, sigil = "IceBarrier" },
			blink = { spells = { 1953 }, sigil = "Blink" },
			nova = { spells = NOVA, sigil = "FrostNova" },
			blastWave = { spells = { 13021, 13020, 13019, 13018, 11113 }, sigil = "BlastWave" },
			lance = { spells = { 1240047, 1240046, 1240045, 1240044, 400640, 1312002 }, sigil = "IceLance" },
			escape = { spells = { 20589 }, sigil = "Escape", race = true, unit = "player" },
		},
		majors = { "power", "presence", "combustion", "block", "snap", "evocation", "blastWave", "blink", "nova", "lance", "blast" },
		overflow = { "escape" },
		held = ns.SlabOrb.Expected,
		trees = {
			{ majors = { "power", "presence", "evocation" }, fill = { "blast" } },
			{ majors = { "combustion", "block", "evocation" }, fill = { "cone" } },
			{ majors = { "block", "evocation", "snap" }, fill = { "barrier" } },
		},
		signs = { { { 12042 }, { 12043 } }, { { 11129 }, { 11113 } }, { { 12472 }, { 11426 } } },
	})

	Trackers.Register("MAGE", {
		{ key = "crestArmor", seat = At(BAND.armor), build = Armor, feed = "aura", spells = Trackers.Joined(FROST_ARMOR, MAGE_ARMOR),
			feeds = { { spells = FROST_ARMOR, color = "schoolFrost", art = "glyphArmorFrost" },
				{ spells = MAGE_ARMOR, color = "schoolArcane", art = "glyphArmorArcane" } } },
		{ key = "crestManaGem", seat = PENDANT, choices = {
			{ build = Gem, look = "gem", size = GEM, feed = "item", items = GEMS, color = "magic", lowMana = 0.3,
				known = function() return Medals.Known(CONJURE) or Have(GEMS) and CONJURE[#CONJURE] end },
			{ build = Effect, seat = PERCH_RIGHT, size = PERCH, look = "glyph", glyph = "glyphIntellect", feed = "aura", spells = INTELLECT, color = "schoolArcane" },
		} },
		{ key = "crestCounterspell", seat = PERCH_LEFT, build = Effect, look = "shard", feed = "cooldown", choices = {
			{ known = { 2139 }, color = "magic" },
			{ known = Railed(false, FIRE_BLAST, FIRE_BLAST), look = "orb", color = "schoolFire" },
		} },
		{ key = "crestSchool", seat = At(BAND.left), choices = {
			{ build = Stacks, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 22959 }, known = { 11095, 12872, 12873 }, color = "schoolFire",
				stacks = 5, ember = "trackerFlame" },
			{ build = Stacks, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 12579 }, known = WINTERS, color = "schoolFrost", stacks = 5,
				ember = "glyphChillShard" },
			{ build = Charge, feed = "cooldown", known = { 1326079 }, color = "schoolArcane" },
			{ build = Charge, feed = "cooldown", known = Railed(false, NOVA, NOVA), color = "schoolFrost" },
		} },
		{ key = "crestFrozen", seat = At(BAND.frost), build = Frozen, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER",
			color = "schoolFrost", choices = {
				{ spells = { 122, 865, 6131, 10230, 12494 }, known = NOVA },
				{ spells = FROSTBOLT },
			} },
		{ key = "crestYourSpell", seat = At(BAND.right), build = Fuse, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", newest = true, choices = {
			{ spells = FIRE, known = IGNITE, color = "schoolFire", glyph = "glyphFireTongue" },
			{ spells = CHILLS, known = WINTERS, color = "schoolFrost", glyph = "glyphChillShard" },
			{ spells = { 118, 12824, 12825, 12826, 28271, 28272 }, color = "schoolArcane", glyph = "glyphPolyCurl" },
		} },
		{ key = "crestCooldowns", seat = "cooldowns", color = "pipMageGlow", families = { { spells = { 12042 }, sigil = "Arcane", major = true },
			{ spells = { 12043 }, sigil = "Hourglass", major = true }, { spells = { 11129, 28682 }, known = { 11129 }, sigil = "Flame", major = true }, { spells = { 12051 }, sigil = "Vortex", major = true },
			{ spells = { 11958, 27619 }, known = { 11958 }, sigil = "Crystal", major = true } }, railed = Shown },
		{ key = "crestWard", seat = "rim", build = Ward, place = Ring, feed = "aura", spells = WARDS, color = "rim", ward = true },
		{ key = "crestClearcasting", seat = "rim", build = Moment, place = Ring, feed = "aura", spells = { 12536 },
			known = CLEARCASTING, color = "schoolArcane", proc = "schoolArcane" },
		{ key = "crestOrb", seat = "rim", build = ns.SlabOrb.Build, place = ns.SlabOrb.Place, feed = "cooldown", choices = ns.SlabOrb.Choices(), crestOnly = true },
		{ key = "crestRail", seat = "rim", build = ns.SlabRail.Build, place = ns.SlabRail.Place, known = ns.SlabRail.Known, hold = ns.SlabRail.Holding, crestOnly = true },
	}, { burst = "medBurstMage", pick = ns.SlabRail.Pick, commit = Commit, rail = Shown, update = { "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED" },
		events = { { "UNIT_POWER_UPDATE", "player" }, "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", { "UNIT_SPELLCAST_SUCCEEDED", "player" } }, paint = Paint, motion = Motion,
		figures = true })
end

if CLASS == "WARLOCK" then
	local DEMONS, SACRIFICE = { 688, 697, 712, 713, 691 }, { 18788 }
	local ARMORS = { 11735, 11734, 11733, 1086, 706, 696, 687 }
	local STONES = { 9421, 19012, 19013, 5510, 19010, 19011, 5509, 19008, 19009, 5511, 19006, 19007, 5512, 19004, 19005 }
	local CREATE = { 11730, 11729, 5699, 6202, 6201 }
	local SIGILS = {
		{ "glyphImp", { 3110, 7799, 7800, 7801, 7802, 11762, 11763 }, 18789, 688 },
		{ "glyphVoidwalker", { 3716, 7809, 7810, 7811, 11774, 11775 }, 18790, 697 },
		{ "glyphSuccubus", { 7814, 7815, 7816, 11778, 11779, 11780 }, 18791, 712 },
		{ "glyphFangs", { 19505, 19731, 19734, 19736, 19244, 19647 }, 18792, 691 },
	}
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

	local COIL = { 17926, 17925, 6789 }
	ns.SlabRail.Register("WARLOCK", {
		color = "jewelShard",
		burst = "medBurstWarlock",
		abilities = {
			amplify = { spells = { 18288 }, sigil = "Curse", unit = "player" },
			domination = { spells = { 18708 }, sigil = "Horns", unit = "player" },
			coil = { spells = COIL },
			inferno = { spells = { 1122 } },
			soulfire = { spells = { 17924, 6353 } },
			soulstone = { spells = { 20757, 20756, 20755, 20752, 693 }, items = { 16896, 16895, 16893, 16892, 5232 }, casts = { 20765, 20764, 20763, 20762, 20707 } },
			ritual = { spells = { 18540 } },
		},
		majors = { "coil", "inferno", "amplify", "domination", "soulfire" },
		overflow = { "soulstone", "ritual" },
		trees = {
			{ majors = { "coil", "inferno", "amplify", "domination", "soulfire" } },
			{ majors = { "coil", "inferno", "domination", "soulfire" } },
			{ majors = { "coil", "inferno", "amplify", "domination", "soulfire" } },
		},
		signs = { { { 18288 } }, { { 18708 } }, { { 1293818, 1293817, 18932, 18931, 18930, 17962 }, { 18871, 18870, 18869, 18868, 18867, 17877 } } },
	})

	Trackers.Register("WARLOCK", {
		{ key = "crestDemon", seat = At(BAND.left), choices = {
			{ build = Pet, band = "left", light = "schoolNature", demons = SIGILS, known = DEMONS, active = Demon, feed = "aura", color = "jewelShard",
				spells = { 18789, 18790, 18791, 18792 }, sacrifice = SACRIFICE },
			{ build = Effect, seat = SIGIL, size = PERCH, look = "glyph", glyph = "glyphHorns", feed = "aura", color = "jewelShard", spells = ARMORS },
		} },
		{ key = "crestHealthstone", seat = PENDANT, build = Effect, choices = {
			{ build = Gem, look = "gem", glyph = "glyphHealthstone", size = GEM, feed = "item", items = STONES, color = "friendly", known = function() return Medals.Known(CREATE) or Have(STONES) and CREATE[#CREATE] end },
			{ seat = PERCH_RIGHT, size = PERCH, look = "glyph", glyph = "glyphHorns", feed = "aura", color = "jewelShard", spells = ARMORS,
				known = function() return Medals.Known(DEMONS) and Medals.Known(ARMORS) end, active = Demon },
		} },
		{ key = "crestStone", seat = "lowerLeft", build = Medals.Socket, feed = "enchant", slot = "MainHand", color = "schoolFire",
			known = { 17728, 17727, 2362, 17953, 17952, 17951, 6366 } },
		{ key = "crestConflagrate", seat = "lowerRight", build = Medals.Socket, feed = "cooldown", color = "schoolFire", known = { 1293818, 1293817, 18932, 18931, 18930, 17962 } },
		{ key = "crestCurse", seat = At(BAND.right), build = Fuse, glyph = "glyphWeakness", feed = "aura", unit = "target",
			filter = "HARMFUL|PLAYER", color = "jewelShard", known = Trackers.Joined(CURSES[1].spells, CURSES[2].spells, CURSES[3].spells, CURSES[4].spells,
			CURSES[5].spells), feeds = CURSES },
		{ key = "crestSpellLock", seat = PERCH_LEFT, build = Effect, feed = "cooldown", color = "schoolShadow", choices = {
			{ look = "blade", known = function() return Medals.Known({ 691 }) and (SpellLock() or 19244) end, active = SpellLock },
			{ look = "orb", known = Railed(false, COIL, COIL) },
		} },
		{ key = "crestCooldowns", seat = "cooldowns", color = "jewelShard", families = { { spells = { 18288 }, sigil = "Curse", major = true },
			{ spells = { 18708 }, sigil = "Horns", major = true }, { spells = { 6229, 11739, 11740, 28610 }, sigil = "Shade" },
			{ spells = { 7812, 19438, 19440, 19441, 19442, 19443 }, known = {}, art = { 697 }, sigil = "Void" } }, railed = ns.SlabRail.Holds },
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
		{ key = "crestTrance", seat = "rim", build = Moment, place = Ring, feed = "aura", spells = { 17941 }, known = NIGHTFALL,
			color = "jewelShard", proc = "jewelShard" },
		{ key = "crestRail", seat = "rim", build = ns.SlabRail.Build, place = ns.SlabRail.Place, known = ns.SlabRail.Known, hold = ns.SlabRail.Holding, crestOnly = true },
	}, {
		burst = "medBurstWarlock",
		pick = ns.SlabRail.Pick,
		commit = ns.SlabRail.Commit,
		rail = ns.SlabRail.Holds,
		events = { PET_EVENTS[1], PET_EVENTS[2], "BAG_UPDATE_DELAYED", "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
		update = { "UNIT_PET", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED" },
		paint = Paint,
		motion = Motion,
		figures = true,
	})
end
