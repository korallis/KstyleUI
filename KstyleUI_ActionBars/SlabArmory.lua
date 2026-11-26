-- SlabArmory.lua: the warrior's, paladin's and rogue's crest effects (docs/medallions-effects.md#melee-crest-effects): a seat whose row names a look is part of the crest itself, never a spell's icon in a socket: an object perched inside the ring (a horn, a weapon on its planted hilt, a hammer, a brand, a shield, a drop of blood, a flask, a flame), a seal above it whose colour floods the inner rim, a groove cut into the rune band that charges or drains, a ward or an oath's arc over the emblem, blood flooding the ring's side, flames along the band, a veil over the emblem in Stealth. The lit part is a plain fill cut by the piece's own outline (and shaded by a metal object's art), so a partial fill never redraws it; a light rides the fill's edge and the glow rises with it. An aura or enchant drains it, a cooldown charges it and flares when ready, a usable strike lights its own weapon in its colour and sweeps the light up it, an item fills its flask; a flare can flash half the rune band; an aura's piece flickers through its last fifth and fades a gilt glow when it ends, as a medal's ember does; at Full the engine loops each look's motion while the aura shows. Under Frames each stands free in its row cell. Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Tokens, Effects, Medals = K.Tokens, K.Effects, ns.SlabMedals

local Armory = {}
ns.SlabArmory = Armory

local ART = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\Effects\\"
local CLAMP = "CLAMPTOBLACKADDITIVE"
local TRACK, INNER, RIM, GLOW, BURST, GHOST, HALO, SLIDE, EDGE = 4, 112, 150, 1.5, 2.4, 0.8, 0.85, 0.5, 0.45
local LOOKS = {
	sword = { art = "Sword", metal = true, hilt = true }, axe = { art = "Axe", metal = true, hilt = true },
	dagger = { art = "Dagger", metal = true, hilt = true }, hammer = { art = "Hammer", metal = true, hilt = true },
	horn = { art = "Horn", metal = true, loop = "call" }, shield = { art = "Shield", metal = true, ghost = "ShieldCracked" },
	seal = { art = "Seal", metal = true, flood = true, loop = "halo" }, brand = { art = "Brand", metal = true, loop = "halo" },
	drop = { art = "Drop", metal = true, loop = "drip" }, vial = { art = "Vial", metal = true, ghost = "VialGlass", glass = true, loop = "bubble" },
	flame = { token = "trackerFlame", blend = "ADD", loop = "flicker" },
	grooveLL = { art = "GrooveLL", groove = true, reverse = true }, grooveLR = { art = "GrooveLR", groove = true },
	grooveBL = { art = "GrooveBL", groove = true, across = true }, grooveBR = { art = "GrooveBR", groove = true, across = true },
	ward = { art = "Ward", hidden = true, halo = 0.3 }, oath = { art = "Oath", hidden = true }, oathInner = { art = "OathInner", hidden = true },
	stain = { art = "Stain", hidden = true, loop = "drip" }, flames = { art = "Flames", blend = "ADD", hidden = true, loop = "flicker" },
}
Armory.LOOKS, Armory.ART = LOOKS, ART
local LEAD = { VERTICAL = { "TOP", "BOTTOM", 0, 1 }, HORIZONTAL = { "RIGHT", "LEFT", 1, 0 } }

local function Path(look, ghost)
	local name = ghost and look.ghost or look.token or look.art
	return look.token and (Tokens.Texture(name)) or ART .. name .. ".png"
end

local function Glow(look)
	return look.art and not look.blend and ART .. look.art .. "Glow.png" or (Tokens.Texture("glow"))
end

local function Move(group, y, duration, order)
	local t = group:CreateAnimation("Translation")
	t:SetOffset(0, y)
	t:SetDuration(duration)
	t:SetOrder(order or 1)
	return t
end

local LOOPS = {
	call = function(m, gate, color, size, _, hub)
		local ring = m.add(Medals.Texture(gate, "OVERLAY", 0, "ringLine8", color, size * 0.6, "ADD"))
		ring:SetPoint("CENTER", m, "CENTER", -size * 0.3, size * 0.32)
		local group = ns.Slab.Group(ring)
		ns.Slab.Grow(group, 0.5, 1.6, 0.8)
		ns.Slab.Fade(group, 0.9, 0, 0.8)
		if not hub then
			return group
		end
		local wave = m.add(Medals.Texture(gate, "OVERLAY", 1, ART .. "Wave.png", color, RIM, "ADD"))
		wave:SetPoint("CENTER", hub, "CENTER", 0, 0)
		local travel = ns.Slab.Group(wave)
		local turn = travel:CreateAnimation("Rotation")
		turn:SetDegrees(-120)
		turn:SetDuration(0.8)
		ns.Slab.Fade(travel, 1, 0, 0.8)
		return group, travel
	end,
	halo = function(m, gate, color, size, look)
		return Medals.Steps(m.add(Medals.Texture(gate, "BACKGROUND", 0, Glow(look), color, size * GLOW * 1.2, "ADD")), { { 0.2, 1, 1.2 }, { 1, 0.2, 1.2 } }, true)
	end,
	drip = function(m, gate, color, size)
		local drop = m.add(Medals.Texture(gate, "OVERLAY", 0, ART .. "Drop.png", color, 6))
		drop:SetPoint("CENTER", m, "CENTER", size * 0.08, -size * 0.3)
		local group = ns.Slab.Group(drop, "REPEAT")
		Move(group, -size * 0.2, 0.6)
		ns.Slab.Fade(group, 1, 0, 0.6):SetEndDelay(1.4)
		return group
	end,
	bubble = function(m, gate, _, size)
		local bubble = m.add(Medals.Texture(gate, "OVERLAY", 0, "glow", "white", size * 0.14, "ADD"))
		bubble:SetPoint("CENTER", m, "CENTER", -size * 0.06, -size * 0.24)
		local group = ns.Slab.Group(bubble, "REPEAT")
		Move(group, size * 0.3, 1.1)
		ns.Slab.Fade(group, 0, 0.8, 0.3)
		ns.Slab.Fade(group, 0.8, 0, 0.4, 1, 0.7):SetEndDelay(0.6)
		return group
	end,
	flicker = function(m, gate, color, size)
		return ns.Slab.Flicker(m.add(Medals.Texture(gate, "BACKGROUND", 0, "glow", color, size * 1.6, "ADD")))
	end,
	crackle = function(m, gate, color, size, look)
		return ns.Slab.Flicker(m.add(Medals.Texture(gate, "OVERLAY", 0, Glow(look), color, size * GLOW, "ADD")))
	end,
}

local function Fill(m, lit, look, color, units, level, usable)
	local holder = usable and Medals.Layer(lit, level) or lit
	local orient = look.across and "HORIZONTAL" or "VERTICAL"
	local lead, tail, dx, dy = unpack(LEAD[orient])
	if look.reverse then
		lead, tail, dx, dy = tail, lead, -dx, -dy
	end
	lit.bar = m.add(CreateFrame("StatusBar", nil, holder), units)
	lit.bar:SetPoint("CENTER", m, "CENTER", 0, 0)
	lit.bar:SetOrientation(orient)
	lit.bar:SetReverseFill(look.reverse == true)
	lit.bar:SetStatusBarTexture((Tokens.Texture("barFlat")))
	lit.bar:SetStatusBarColor(Tokens.Color(color))
	lit.bar:SetMinMaxValues(0, 1)
	lit.bar:SetValue(1)
	local fill = lit.bar:GetStatusBarTexture()
	if look.blend then
		fill:SetBlendMode(look.blend)
	end
	lit.mask = lit.bar:CreateMaskTexture()
	lit.mask:SetTexture(Path(look), CLAMP, CLAMP)
	lit.mask:SetAllPoints(m.ghost or m)
	fill:AddMaskTexture(lit.mask)
	lit.edge = Medals.Texture(lit.bar, "OVERLAY", 0, "glow", "white", nil, "ADD")
	lit.edge:SetSize(units * EDGE, units * EDGE)
	lit.edge:ClearAllPoints()
	lit.edge:SetPoint("CENTER", fill, lead, 0, 0)
	lit.edge:AddMaskTexture(lit.mask)
	lit.glow = Medals.Texture(lit.bar, "BACKGROUND", 0, Glow(look), color, nil, "ADD")
	lit.glow:SetAlpha(look.halo or HALO)
	lit.glow:ClearAllPoints()
	lit.glow:SetSize(units * GLOW, units * GLOW)
	if look.groove or look.hidden then
		lit.glow:SetPoint("CENTER", m, "CENTER", 0, 0)
	else
		lit.glow:SetPoint(lead, fill, lead, dx * units * 0.25, dy * units * 0.25)
		lit.glow:SetPoint(tail, m, "CENTER", -dx * units * GLOW / 2, -dy * units * GLOW / 2)
	end
	if usable then
		m.slide = ns.Slab.Group(holder)
		Move(m.slide, -units * SLIDE, 0, 1)
		Move(m.slide, units * SLIDE, 0.18, 2):SetSmoothing("OUT")
	end
end

local function Light(m, look, each, level, size, top, share, form)
	local color = each.tint or each.color or "gilt"
	local lit = Medals.Lit(m, each, level, share)
	local fed, hub = lit.container ~= nil, form == "crest" and m:GetParent() or nil
	if look.flood and fed then
		lit.timer = m.add(Medals.Timer(lit, level + 1, hub and "ringLine16" or "orbRing", color), hub and INNER or size + TRACK)
		lit.timer:ClearAllPoints()
		lit.timer:SetPoint("CENTER", hub or m, "CENTER", 0, 0)
		if hub then
			lit.timer:SetFrameLevel(hub:GetFrameLevel() + 1)
		end
		lit:SetDurationCooldown(lit.timer)
	end
	Fill(m, lit, look, color, size, level, each.feed == "usable")
	if fed and not look.flood then
		local timer = Enum and Enum.StatusBarTimerDirection
		lit:SetDurationBar(lit.bar, { direction = timer and timer.RemainingTime or 1 })
	end
	if fed then
		local at
		if hub and each.pipsAt then
			at = {}
			for n, p in ipairs(each.pipsAt) do
				at[n] = { p[1] - each.seat[1], p[2] - each.seat[2] }
			end
		end
		Medals.Pips(m, lit, each, size, level + 1, at)
	elseif each.feed == "cooldown" or each.feed == "item" then
		lit.timer = m.add(Medals.Timer(lit, level + 1, "orbRing", color, each.feed == "item" and 1 or 0), size + TRACK)
		lit.timer:SetDrawSwipe(each.feed == "item")
		lit.timer:SetScript("OnCooldownDone", function() Medals.Fire(m) end)
		m.bar = m.bar or lit.bar
	end
	if not fed then
		lit:SetShown(each.feed == "cooldown")
	end
	m.timer = m.timer or lit.timer
	for _, flare in ipairs(Medals.Flare(m, lit, top + 1, each.burst or "glow", size * BURST)) do
		if hub and each.flash then
			local band = m.add(Medals.Texture(flare:GetParent(), "ARTWORK", 1, ART .. "BandFlash.png", color, RIM, "ADD"))
			band:SetPoint("CENTER", hub, "CENTER", 0, 0)
			band:SetTexCoord(each.flash == "left" and 1 or 0, each.flash == "left" and 0 or 1, 0, 1)
		end
	end
	if fed and (each.loop or look.loop) then
		Medals.Awake(m, lit, top + 1)
		lit.awake.lit.loops = { LOOPS[each.loop or look.loop](m, lit.awake.lit, color, size, look, hub) }
		for _, group in ipairs(lit.awake.lit.loops) do
			group:GetParent():SetAlpha(0)
		end
		if (each.loop or look.loop) == "call" then
			m.recall = function()
				if Effects.Allows("ambient") and not ns.Slab.Resting() then
					for _, group in ipairs(lit.awake.lit.loops) do
						group:Stop()
						group:Play()
					end
				end
			end
		end
	end
end

local function Picker(m, spec)
	local arts = {}
	for g, group in ipairs(spec.groups) do
		for _, id in ipairs(group) do
			arts[id] = spec.arts and spec.arts[g]
		end
	end
	return function(id)
		local art, lit = arts[id], m.lit
		if art then
			local look = LOOKS[art[1]]
			lit.mask:SetTexture(Path(look), CLAMP, CLAMP)
			lit.bar:SetStatusBarColor(Tokens.Color(art[2]))
			lit.glow:SetTexture(Glow(look))
			lit.glow:SetVertexColor(Tokens.Color(art[2]))
			m.ghost:SetTexture(Path(look, true))
			m.shade:SetTexture(ART .. look.art .. "Shade.png")
			m.hilt:SetShown(look.hilt == true)
			if look.hilt then
				m.hilt:SetTexture(ART .. look.art .. "Hilt.png")
			end
		end
		if Effects.Allows("ambient") and not ns.Slab.Resting() then
			m.slide:Stop()
			m.slide:Play()
		end
	end
end

function Armory.Build(parent, spec, level, form)
	local look, size = LOOKS[spec.look], spec.size or Medals.SIZE
	local m = Medals.Piece(parent, level, size)
	local feeds = spec.feeds or { spec }
	local top = level + 1 + 2 * #feeds
	if spec.veil and form == "crest" then
		for i, veil in ipairs({ { "black", 0.55 }, { spec.veil, 0.35, "ADD" } }) do
			local t = m.add(Medals.Texture(m, "BACKGROUND", i, "glow", veil[1], INNER, veil[3]))
			t:SetAlpha(veil[2])
			t:SetPoint("CENTER", parent, "CENTER", 0, 0)
		end
	end
	if not look.hidden then
		m.ghost = m.add(Medals.Texture(m, "ARTWORK", 0, Path(look, true), look.groove and "medSocket" or look.glass and "white" or "steel", size, look.blend))
		m.ghost:SetAlpha((look.groove or look.glass) and 1 or GHOST)
	end
	local warned, order = {}, {}
	for i, feed in ipairs(feeds) do
		local each = feed == spec and spec or setmetatable(feed, { __index = spec })
		local first = m.lits[1]
		local share = i > 1 and each.feed == "aura" and first and first.container and first.spec.unit == each.unit and first.spec.filter == each.filter and first
		Light(m, LOOKS[each.look], each, level + 1 + 2 * (i - 1), size, top, share, form)
		local c = m.lits[#m.lits].container
		if each.feed == "aura" and c then
			if not warned[c] then
				warned[c] = setmetatable({ spells = {} }, { __index = each })
				order[#order + 1] = warned[c]
			end
			for _, id in ipairs(each.spells) do
				table.insert(warned[c].spells, id)
			end
		end
	end
	for _, warn in ipairs(order) do
		Medals.Warn(m, warn, m.add(Medals.Texture(Medals.Layer(m, top + 1), "OVERLAY", 0, Glow(LOOKS[warn.look]), "gilt", size * GLOW, "ADD")))
	end
	if look.metal then
		local cover = Medals.Layer(m, top)
		m.shade = m.add(Medals.Texture(cover, "OVERLAY", 0, ART .. look.art .. "Shade.png", "white", size))
		m.hilt = look.hilt and m.add(Medals.Texture(cover, "OVERLAY", 1, ART .. look.art .. "Hilt.png", "gilt", size))
	end
	m.pick = spec.feed == "usable" and Picker(m, spec) or nil
	m.spec = spec
	return m
end
