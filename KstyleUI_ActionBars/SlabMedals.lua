-- SlabMedals.lua: the Medallions crest's shared medals and ring sockets (docs/medallions-effects.md#crest-medals-and-sockets lists the API): the parts the hawk perches, storm orbs and Spirit Poles share, the crest's named seats, and four pieces the class trackers build: Figure, a bare figure of light in a breathing bloom that burns down with an aura or charges over a cooldown, never in a socket; Medal, a round steel medal lit by an aura slot or a weapon enchant (with a timer ring the engine drains from the aura's own duration), by a spell's cooldown duration object or by a usable strike; Rim, an aura that burns round the crest's inner rim and drains with it; Socket, a jewel on the ring whose liquid drains with an aura or a weapon enchant. Engine enables the feeds and hands the engine the flares and the fire at Full while auras are readable; Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local cos, sin, rad, floor, max = math.cos, math.sin, math.rad, math.floor, math.max
local IsSecret = Widgets.IsSecret

local Medals = {}
ns.SlabMedals = Medals

local SIZE, TRACK, ICON, SHADE, BURST, STEEL = 26, 4, 0.74, 1.9, 2.4, 0.45
local RIM, INNER, SETTING, LIP, GEM, GLINT = 150, 112, 12, 10, 8, 2
local COOLDOWN_RING, STACK, STACK_GAP, STACK_DROP, ROW_SIGIL, SIGIL, ABOVE = 118, 14, 4, 30, 12, 0.86, 20
local SPARK, BLOOM, GLOW_LIT, FLARE_MAX = 0.3, 2.4, 0.75, 30
local FORGED, HALO, HALO_LIT, SHEEN, SHEEN_SMALL = 24, 1.7, 0.7, 0.15, 0.6
local FLASH, BREATH, FADE_IN = { { 0.75, 1, 0.05 }, { 1, 0.75, 0.4 } }, { { 0.75, 1, 0.8 }, { 1, 0.75, 0.8 } }, { { 0, 1, 0.12 } }
local SEATS = {
	left = { -1, 75.9, 24.8 }, right = { 1, 75.9, 24.8 }, top = { 1, 96, 90 }, topGem = { 1, 60, 90 }, lowerLeft = { -1, 62, -35 }, lowerRight = { 1, 62, -35 },
	leftHip = { 1, 76, 218 }, rightHip = { 1, 76, 322 }, footLeft = { 1, 67.5, 247 }, footRight = { 1, 67.5, 293 },
}
local PIP, PIP_ARC, GLOW, SPARK_LAP = 4, 22, 0.35, 1.6
local FLARE = { { 0, 1, 0.05 }, { 1, 0, 0.4 } }
local OWNER = "ActionBars.SlabMedals"
local refreshed, rims, watchers, gates, breaths, NONE = {}, {}, {}, {}, {}, {}
local REFRESH = { target = { "PLAYER_TARGET_CHANGED" }, pet = { "UNIT_PET", "player" }, focus = { "PLAYER_FOCUS_CHANGED" } }
Medals.SIZE, Medals.FOOT, Medals.LINE, Medals.GAP = SIZE, 15, 5, 4

function Medals.Cell(n)
	local pitch = SIZE + Medals.GAP
	return n % Medals.LINE * pitch, floor(n / Medals.LINE) * pitch
end

function Medals.Known(spells)
	local book = C_SpellBook
	if not (book and type(book.IsSpellKnown) == "function") then
		return nil
	end
	for _, id in ipairs(spells) do
		local known = book.IsSpellKnown(id)
		if not IsSecret(known) and known == true then
			return id
		end
	end
end

function Medals.Restricted()
	local ask = C_Secrets and C_Secrets.ShouldAurasBeSecret
	local secret = ask and ask()
	return IsSecret(secret) or secret == true
end

function Medals.Locked()
	local lock = InCombatLockdown and InCombatLockdown()
	return Medals.Restricted() or IsSecret(lock) or lock == true
end

function Medals.Even(region)
	local px = Widgets.Border(region)
	local side = max(2, 2 * floor(region.units / px / 2 + 0.5)) * px
	region:SetSize(side, side)
end

function Medals.Texture(parent, layer, sublevel, texture, color, size, blend)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(texture:find("\\", 1, true) and texture or (Tokens.Texture(texture)))
	t:SetVertexColor(Tokens.Color(color))
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	if blend then
		t:SetBlendMode(blend)
	end
	t.units = size
	return t
end

function Medals.Mark(piece, parent, art, size, color, r, g, b, level)
	local forged = select(4, Tokens.Texture(art))
	local host = forged and level and Medals.Layer(parent, level) or parent
	local t = piece.add(Medals.Texture(host, "ARTWORK", 0, art, color, size, "ADD"))
	if r then
		t:SetVertexColor(r, g, b)
	end
	if not forged then
		return t, t
	end
	local gold = size >= FORGED
	local body = piece.add(Medals.Texture(host, "ARTWORK", -1, art, gold and "coinGold" or color, size))
	if gold then
		piece.add(Medals.Texture(host, "BACKGROUND", 0, "glow", "black", size * SHADE)):SetAlpha(HALO_LIT)
		piece.add(Medals.Texture(host, "BACKGROUND", 1, "glow", color, size * HALO, "ADD")):SetAlpha(HALO_LIT)
	elseif r then
		body:SetVertexColor(r, g, b)
	end
	t:SetAlpha(gold and SHEEN or SHEEN_SMALL)
	return t, host ~= parent and host or t
end

function Medals.Layer(holder, level)
	local frame = CreateFrame("Frame", nil, holder)
	frame:SetAllPoints(holder)
	frame:SetFrameLevel(level)
	return frame
end

function Medals.Steps(target, steps, looping)
	local group = target:CreateAnimationGroup()
	for i, s in ipairs(steps) do
		ns.Slab.Fade(group, s[1], s[2], s[3], i)
	end
	if looping then
		group:SetLooping("REPEAT")
	end
	return group
end

function Medals.Cloud(parent, token, cell)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture((Tokens.Texture(token)))
	t:SetBlendMode("ADD")
	t:SetAllPoints(parent)
	local rows, columns = Tokens.Flipbook(token)
	local x, y = cell % columns, floor(cell / columns)
	t:SetTexCoord(x / columns, (x + 1) / columns, y / rows, (y + 1) / rows)
	return t
end

function Medals.Flip(texture, token, stretch)
	local rows, columns, frames, seconds = Tokens.Flipbook(token)
	local group = texture:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	local f = group:CreateAnimation("FlipBook")
	f:SetFlipBookRows(rows)
	f:SetFlipBookColumns(columns)
	f:SetFlipBookFrames(frames)
	f:SetDuration(seconds * stretch)
	return group
end

function Medals.Seat(name)
	local s = SEATS[name]
	return s[1] * s[2] * cos(rad(s[3])), s[2] * sin(rad(s[3]))
end

local function Art(parent, layer, name, color)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture((Tokens.Texture(name)))
	t:SetVertexColor(Tokens.Color(color))
	return t
end

function Medals.Round(frame)
	local t = frame:CreateTexture(nil, "ARTWORK")
	local mask = frame:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("dot")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(t)
	t:AddMaskTexture(mask)
	return t
end

function Medals.Dress(m, cover)
	m.shade = Art(m, "BACKGROUND", "glow", "black")
	m.shade:SetAlpha(0.7)
	m.icon = Medals.Round(m)
	cover = cover or m
	m.enamel = Art(cover, "OVERLAY", "medEnamel", "steel")
	m.enamel:SetAllPoints(m)
	m.ring = Art(cover, "OVERLAY", "medRing", "white")
	m.ring:SetAllPoints(m)
	return m
end

local function Timer(parent, level, texture, color, alpha, path)
	local t = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
	t:SetFrameLevel(level)
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	t:SetSwipeTexture(path or (Tokens.Texture(texture)))
	local r, g, b = Tokens.Color(color)
	t:SetSwipeColor(r, g, b, alpha or 1)
	t:SetDrawEdge(false)
	t:SetDrawBling(false)
	t:SetHideCountdownNumbers(true)
	return t
end

local function Container(parent, spec)
	local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	Widgets.KeepOut(container)
	container:SetUnit(spec.unit or "player")
	local refresh = REFRESH[spec.unit]
	if refresh then
		local list = refreshed[spec.unit]
		if not list then
			list = {}
			refreshed[spec.unit] = list
			local function update()
				for _, c in ipairs(list) do
					if c.on then
						c:UpdateAllAuras()
					end
				end
			end
			if refresh[2] then
				K.Events.RegisterUnit(OWNER, refresh[1], update, refresh[2])
			else
				K.Events.Register(OWNER, refresh[1], update)
			end
		end
		list[#list + 1] = container
	end
	return container
end

function Medals.Feed(parent, spec, level, share)
	if spec.feed ~= "aura" and spec.feed ~= "enchant" then
		return Medals.Layer(parent, level)
	end
	local gate = spec.feed == "enchant" and Medals.Layer(parent, level) or nil
	local container = share and share.container or Container(gate or parent, spec)
	container.slots = (container.slots or 0) + 1
	local button
	if spec.feed == "aura" then
		local ids = {}
		for _, id in ipairs(spec.spells) do
			ids[id] = true
		end
		local sort, direction = AuraContainerSortMethod, AuraContainerSortDirection
		spec.options = { candidateFilters = { includeSpellIDs = ids } }
		if spec.newest and sort and direction then
			spec.options.sortMethod, spec.options.sortDirection = sort.AuraInstanceIDOnly, direction.Reverse
		end
		button = container:AddAuraSlot(container.slots == 1 and "lit" or "lit" .. container.slots, spec.filter or "HELPFUL", spec.options)
	else
		button = container:AddItemEnchantment(AuraContainerItemEnchantmentSlot[spec.slot])
	end
	pcall(button.EnableMouse, button, false)
	button:SetAllPoints(parent)
	button:SetFrameLevel(level)
	button.container, button.gate, button.spec, button.share = container, gate, spec, share
	return button
end

local function Mirror(piece, lit, level)
	local share = lit.share and lit.share.awake
	local gate = share or Medals.Layer(piece, level)
	gate.lit = Medals.Feed(gate, setmetatable({}, { __index = lit.spec }), level, share and share.lit)
	lit.mirrors = lit.mirrors or {}
	lit.mirrors[#lit.mirrors + 1] = gate.lit
	return gate
end
Medals.Mirror, Medals.Timer = Mirror, Timer

function Medals.Flare(piece, lit, level, token, size, lua, color)
	if lit.container and not lua then
		lit.awake = lit.awake or Mirror(piece, lit, level)
	end
	local gate = not lua and lit.awake or Medals.Layer(lit.container and piece or lit, level)
	local flare = Medals.Layer(gate.lit or gate, level)
	gate:SetAlpha(ns.Slab.Resting() and 0 or 1)
	gates[#gates + 1] = gate
	lit.flareGate = gate
	if color and select(4, Tokens.Texture(token)) then
		Medals.Mark(piece, flare, token, size, color)
	else
		piece.add(Medals.Texture(flare, "ARTWORK", 0, token, "white", size, "ADD"))
	end
	flare:SetAlpha(0)
	flare.play = Medals.Steps(flare, FLARE)
	if gate.lit or not lit.container then
		(gate.lit or lit).flare = flare
	end
	piece.flare = piece.flare or flare
end

function Medals.Piece(parent, level, units)
	local piece = CreateFrame("Frame", nil, parent)
	piece:SetFrameLevel(level)
	piece.units, piece.parts, piece.lits = units, {}, {}
	piece.add = function(part, size)
		part.units = size or part.units
		piece.parts[#piece.parts + 1] = part
		return part
	end
	piece.add(piece)
	return piece
end

local function Lit(piece, spec, level, share)
	local lit = Medals.Feed(piece, spec, level, share)
	piece.lits[#piece.lits + 1] = lit
	piece.lit = piece.lit or lit
	return lit
end
Medals.Lit = Lit

function Medals.Pips(m, lit, each, size, level, at)
	for n = 1, lit.container and each.pips or 0 do
		local slot = lit.container:AddAuraSlot("pip" .. n, each.filter or "HELPFUL", each.options)
		pcall(slot.EnableMouse, slot, false)
		slot:SetAllPoints(m)
		slot:SetFrameLevel(level)
		local pip = m.add(CreateFrame("StatusBar", nil, slot), PIP)
		local a = rad(270 + (n - (each.pips + 1) / 2) * PIP_ARC)
		pip:SetPoint("CENTER", m, "CENTER", at and at[n][1] or (size / 2 + 4) * cos(a), at and at[n][2] or (size / 2 + 4) * sin(a))
		pip:SetStatusBarTexture((Tokens.Texture("dot")))
		pip:SetStatusBarColor(Tokens.Color(each.color or "gilt"))
		slot:SetApplicationBar(pip, { minApplications = n - 1, maxApplications = n })
	end
end

function Medals.Medal(parent, spec, level)
	local size = spec.size or SIZE
	local m = Medals.Piece(parent, level, size)
	local feeds = spec.feeds or { spec }
	local add, timed, track = m.add, spec.color ~= nil or spec.feed == "item", size < SIZE and 2 or TRACK
	for _, feed in ipairs(feeds) do
		timed = timed or feed.color ~= nil
	end
	local top = level + 1 + 2 * #feeds
	Medals.Dress(m, Medals.Layer(m, top))
	add(m.shade, size * SHADE):SetPoint("CENTER", m, "CENTER", 0, 0)
	if timed then
		add(Medals.Texture(m, "BORDER", 0, "orbRing", "medSocket", size + track))
	end
	m.steel = add(m.icon, size * ICON)
	m.steel:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.steel:SetTexture(spec.texture)
	m.steel:SetDesaturated(true)
	m.steel:SetVertexColor(Tokens.Color("steel"))
	m.steel:SetAlpha(STEEL)
	m.steel:SetShown(spec.feed ~= "item")
	for i, feed in ipairs(feeds) do
		local each = feed == spec and spec or setmetatable(feed, { __index = spec })
		local lit = Lit(m, each, level + 1 + 2 * (i - 1))
		lit.icon = add(Medals.Round(lit), size * ICON)
		lit.icon:SetPoint("CENTER", m, "CENTER", 0, 0)
		if each.feed == "aura" then
			lit:SetIcon(lit.icon)
		else
			lit.icon:SetTexture(spec.texture)
		end
		if (each.color or each.feed == "item") and each.feed ~= "cooldown" then
			lit.timer = add(Timer(lit, level + 2 + 2 * (i - 1), "orbRing", each.color or "gilt"), size + track)
			if lit.container then
				lit:SetDurationCooldown(lit.timer)
			end
			add(Medals.Ember(m, lit, lit.timer, "Band", level + 3 + 2 * (i - 1), size))
		elseif each.feed == "cooldown" then
			lit.timer = add(Timer(lit, level + 2, "dot", "black", 0.7), size * ICON)
		end
		if each.feed == "cooldown" or each.feed == "item" then
			lit.timer:SetScript("OnCooldownDone", function()
				lit.icon:SetDesaturated(false)
				Medals.Fire(m)
			end)
		end
		if each.count and lit.SetApplicationCount then
			local corner = (size * ICON / 2 - 1) / math.sqrt(2)
			lit.count = Widgets.Fitted(Widgets.FontString(Medals.Layer(lit, top + 2), "OVERLAY"))
			Widgets.ApplyFont(lit.count, (Tokens.Font("world")), corner * 2 / 1.2, "OUTLINE")
			lit.count:SetTextColor(Tokens.Color("textEmphasis"))
			lit.count:SetPoint("BOTTOMRIGHT", m.steel, "CENTER", corner, -corner)
			lit:SetApplicationCount(lit.count)
		end
		Medals.Pips(m, lit, each, size, level + 2)
		m.timer = m.timer or lit.timer
		if each.feed == "usable" or each.feed == "item" then
			lit:Hide()
		end
		Medals.Flare(m, lit, top + 1, spec.burst or "glow", size * BURST)
	end
	m.spec, m.texture = spec, spec.texture
	return m
end

function Medals.Figure(parent, spec, level)
	local size = spec.size or SIZE
	local f = Medals.Piece(parent, level, size)
	local feeds = spec.feeds or { spec }
	local top = level + 1 + 2 * #feeds
	if #feeds == 1 and (spec.feed == "cooldown" or spec.steady) then
		local steel = f.add(Medals.Texture(f, "BORDER", 0, spec.figure, "steel", size))
		steel:SetDesaturated(true)
		steel:SetAlpha(STEEL)
	end
	for i, feed in ipairs(feeds) do
		local each = feed == spec and spec or setmetatable(feed, { __index = spec })
		local lit = Lit(f, each, level + 1 + 2 * (i - 1))
		if each.bloom then
			lit.bloom = f.add(Medals.Texture(lit, "BACKGROUND", 0, "glow", each.bloom, size * BLOOM, "ADD"))
			lit.bloom:SetAlpha(GLOW_LIT)
			lit.loop = Medals.Steps(lit.bloom, BREATH, true)
			breaths[#breaths + 1] = not lit.container and lit.loop or nil
		end
		local bar = f.add(CreateFrame("StatusBar", nil, lit), size)
		bar:SetPoint("CENTER", f, "CENTER", 0, 0)
		bar:SetOrientation("VERTICAL")
		bar:SetStatusBarTexture((Tokens.Texture(each.figure)))
		bar:GetStatusBarTexture():SetBlendMode("ADD")
		bar:SetStatusBarColor(Tokens.Color(each.color or "white"))
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		local alpha = each.alpha or 1
		bar:SetAlpha(alpha)
		local spark = f.add(Medals.Texture(bar, "OVERLAY", 0, "glow", each.color or "white", size * SPARK, "ADD"))
		spark:ClearAllPoints()
		spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "TOP", 0, 0)
		if each.charges and lit.container then
			lit:SetApplicationBar(bar, { minApplications = 0, maxApplications = each.charges })
		elseif lit.container and not each.steady then
			local timer = Enum and Enum.StatusBarTimerDirection
			lit:SetDurationBar(bar, { direction = timer and timer.RemainingTime or 1 })
			lit.flicker = Medals.Steps(bar, { { alpha, alpha * 0.6, 0.25 }, { alpha * 0.6, alpha, 0.25 } }, true)
		elseif each.feed == "cooldown" then
			f.timer, f.bar = Timer(lit, level + 1, "dot", "black", 0), bar
			f.timer:SetDrawSwipe(false)
			f.timer:SetScript("OnCooldownDone", function() Medals.Fire(f) end)
		end
		if lit.container then
			lit.loops = { Medals.Steps(lit, FADE_IN), lit.loop }
		end
		lit.bar = bar
		if not each.alpha then
			Medals.Flare(f, lit, top + 1, spec.burst or "glow", math.min(size, FLARE_MAX) * BURST)
		end
	end
	f.spec = spec
	return f
end

function Medals.Rim(parent, spec, level)
	local r = Medals.Piece(parent, level, RIM)
	local lit = Lit(r, spec, level + 1)
	if spec.ambient then
		r.still = Mirror(r, lit, level + 1)
		Medals.Cloud(r.still.lit, spec.ambient, spec.cell or 0)
		lit.awake = Mirror(r, lit, level + 1)
		r.fire = lit.awake
		r.fire:SetAlpha(0)
		r.fire.lit.loop = Medals.Flip(Medals.Cloud(r.fire.lit, spec.ambient, spec.cell or 0), spec.ambient, 1)
		rims[#rims + 1] = r
	end
	if spec.color then
		r.timer = r.add(Timer(lit, level + 2, "ringLine16", spec.color, nil, spec.ring), spec.ringSize or INNER)
		if lit.container then
			lit:SetDurationCooldown(r.timer)
		end
		if spec.ring then
			Medals.Warn(r, spec, r.add(Medals.Texture(Medals.Layer(r, level + 3), "OVERLAY", 0, spec.ring, "gilt", spec.ringSize, "ADD")))
		else
			r.add(Medals.Ember(r, lit, r.timer, "RingLine16", level + 3, INNER))
		end
	end
	if spec.spark then
		lit.awake = lit.awake or Mirror(r, lit, level + 1)
		local orbit = ns.Slab.Group(r.add(Medals.Texture(lit.awake.lit, "OVERLAY", 0, spec.spark, spec.color, spec.ringSize, "ADD")), "REPEAT")
		local turn = orbit:CreateAnimation("Rotation")
		turn:SetDegrees(-360)
		turn:SetDuration(SPARK_LAP)
		ns.Slab.Fade(orbit, 1, 0, 0.03, 1, 0.72)
		ns.Slab.Fade(orbit, 0, 1, 0.03, 1, 0.96)
		lit.awake.lit.loop = orbit
	end
	Medals.Flare(r, lit, level + 3, spec.burst or "glow", RIM, spec.lua)
	r.spec = spec
	return r
end

local function Sigil(r, container, key, family, color, size, bloom)
	local ids = {}
	for _, id in ipairs(family.spells) do
		ids[id] = true
	end
	local options = { candidateFilters = { includeSpellIDs = ids } }
	local button = container:AddAuraSlot(key, "HELPFUL", options)
	pcall(button.EnableMouse, button, false)
	button:SetPoint("CENTER", r, "CENTER", 0, 0)
	button:SetFrameLevel(r:GetFrameLevel() + ABOVE)
	r.add(button, size)
	local back = r.add(Medals.Texture(button, "BACKGROUND", 0, "glow", bloom or "black", size * (bloom and BLOOM or SHADE), bloom and "ADD"))
	back:SetAlpha(bloom and GLOW_LIT or 0.7)
	button.loop = bloom and Medals.Steps(back, FLASH)
	r.add(Medals.Texture(button, "BACKGROUND", 1, "dot", "black", size)):SetAlpha(0.85)
	Medals.Mark(r, button, "sigil" .. family.sigil, size * SIGIL, color)
	r.add(Medals.Texture(button, "BORDER", 0, "medRing", "white", size))
	button.timer = Timer(button, button:GetFrameLevel() + 1, "orbRing", color)
	button.timer:SetAllPoints(button)
	button:SetDurationCooldown(button.timer)
	button.ember = Medals.EmberSlot(r, container, "ember" .. key, options, size, r:GetFrameLevel() + ABOVE + 2)
	button.container, button.key, button.family = container, key, family
	r.sigils[#r.sigils + 1] = button
end

function Medals.CooldownRim(parent, spec, level, form)
	local row = form == "row"
	local r = Medals.Piece(parent, level, row and SIZE or RIM)
	local units, order = {}, {}
	for _, family in ipairs(spec.families) do
		local unit = family.unit or "player"
		if not units[unit] then
			units[unit] = { feed = "aura", unit = unit, filter = spec.filter or "HELPFUL", newest = true, spells = {}, families = {} }
			order[#order + 1] = unit
		end
		for _, id in ipairs(family.spells) do
			table.insert(units[unit].spells, id)
		end
		table.insert(units[unit].families, family)
	end
	table.sort(order, function(a, b) return a == "player" and b ~= "player" end)
	r.sigils = {}
	local size = row and ROW_SIGIL or STACK
	r.pitch, r.per = size + (row and 2 or STACK_GAP), row and 10 or 3
	r.left, r.first, r.rise = row and 0 or -r.pitch, row and 0 or -STACK_DROP - size / 2, r.pitch
	for i, unit in ipairs(order) do
		local each = units[unit]
		local base = level + 5 * (#order - i)
		local lit = Lit(r, each, base + 1)
		if not row then
			lit.timer = r.add(Timer(lit, base + 2, "ringLine16", spec.color), COOLDOWN_RING)
			lit:SetDurationCooldown(lit.timer)
			r.add(Medals.Ember(r, lit, lit.timer, "RingLine16", base + 3, COOLDOWN_RING))
			Medals.Flare(r, lit, base + 3, spec.burst or "glow", RIM)
		end
		for k, family in ipairs(each.families) do
			Sigil(r, lit.container, "sigil" .. k, family, spec.color, size, spec.bloom)
		end
	end
	r.timer = r.lit.timer
	r.spec = spec
	return r
end

function Medals.Socket(parent, spec, level, form)
	local k = form == "row" and spec.size / SETTING or 1
	local s = Medals.Piece(parent, level, SETTING * k)
	local add = s.add
	add(Medals.Texture(s, "ARTWORK", 0, "diamond", "gilt", SETTING * k))
	add(Medals.Texture(s, "ARTWORK", 1, "diamond", "jewelSetting", LIP * k))
	add(Medals.Texture(s, "ARTWORK", 2, "forgedDiamond", "jewelSocket", GEM * k)):SetTexCoord(1, 0, 0, 1)
	local lit = Lit(s, spec, level + 1)
	s.bar = add(CreateFrame("StatusBar", nil, lit), GEM * k)
	s.bar:SetPoint("CENTER", s, "CENTER", 0, 0)
	s.bar:SetOrientation("VERTICAL")
	s.bar:SetStatusBarTexture((Tokens.Texture("diamond")))
	s.bar:SetStatusBarColor(Tokens.Color(spec.color))
	if lit.container then
		local timer = Enum and Enum.StatusBarTimerDirection
		lit:SetDurationBar(s.bar, { direction = timer and timer.RemainingTime or 1 })
	elseif spec.feed == "cooldown" or spec.feed == "item" then
		local rim = spec.slot ~= nil and form ~= "row"
		s.timer = Timer(lit, level + 1, rim and "ringLine16" or "dot", rim and spec.color or "black", rim and 1 or 0)
		s.timer:SetDrawSwipe(rim)
		s.timer:SetScript("OnCooldownDone", function() Medals.Fire(s) end)
		if rim then
			s.timer:ClearAllPoints()
			s.timer:SetPoint("CENTER", parent, "CENTER", 0, 0)
			add(s.timer, COOLDOWN_RING)
			add(Medals.Ember(s, nil, s.timer, "RingLine16", level + 2, COOLDOWN_RING))
		end
	end
	s.glint = add(Medals.Texture(s.bar, "OVERLAY", 0, "diamond", "white", GLINT * k, "ADD"))
	Medals.Flare(s, lit, level + 3, "glow", SETTING * k * BURST)
	s.spec = spec
	return s
end

function Medals.Threat(parent, spec, level)
	local k = (spec.size or SETTING) / SETTING
	local t = Medals.Piece(parent, level, SETTING * k)
	local add = t.add
	add(Medals.Texture(t, "ARTWORK", 0, "diamond", "gilt", SETTING * k))
	add(Medals.Texture(t, "ARTWORK", 1, "diamond", "jewelSetting", LIP * k))
	add(Medals.Texture(t, "ARTWORK", 2, "forgedDiamond", "jewelSocket", GEM * k)):SetTexCoord(1, 0, 0, 1)
	t.bar = add(CreateFrame("StatusBar", nil, t), GEM * k)
	t.bar:SetFrameLevel(level + 1)
	t.bar:SetPoint("CENTER", t, "CENTER", 0, 0)
	t.bar:SetOrientation("VERTICAL")
	t.bar:SetMinMaxValues(0, 100)
	t.bar:SetValue(0)
	t.bar:SetStatusBarTexture((Tokens.Texture("diamond")))
	t.bar:SetStatusBarColor(Tokens.Color(spec.color))
	t.bar:SetAlpha(0.6)
	t.lit = Medals.Layer(t, level + 2)
	add(Medals.Texture(t.lit, "ARTWORK", 0, "glow", spec.color, SETTING * 2 * k, "ADD"))
	add(Medals.Texture(t.lit, "OVERLAY", 0, "diamond", spec.color, GEM * k))
	t.lit:SetAlpha(0)
	t.lits, t.spec = { t.lit }, spec
	return t
end

function Medals.Plaque(parent, spec, level)
	local p = Medals.Piece(parent, level, SIZE)
	p.lit = Medals.Layer(p, level + 1)
	p.timer = p.add(Timer(p.lit, level + 1, "orbRing", spec.color), SIZE)
	p.lits, p.spec = { p.lit }, spec
	return p
end

function Medals.Emblem(parent, spec, level)
	local e = Medals.Piece(parent, level, RIM)
	e.lit = Medals.Layer(e, level + 1)
	e.add(Medals.Texture(e.lit, "OVERLAY", 0, "glow", spec.color, RIM, "ADD")):SetAlpha(GLOW)
	e.lit:SetAlpha(0)
	e.lits, e.spec = { e.lit }, spec
	return e
end

function Medals.Retexture(piece, texture)
	if piece.steel and piece.texture ~= texture then
		piece.texture, piece.usable = texture, nil
		piece.steel:SetTexture(texture)
		for _, lit in ipairs(piece.lits) do
			if not lit.container and lit.icon then
				lit.icon:SetTexture(texture)
			end
		end
	end
end

function Medals.Size(piece)
	local px = Widgets.Border(piece)
	if not piece.parts or piece.sized == px or Medals.Locked() then
		return
	end
	piece.sized = px
	for _, part in ipairs(piece.parts) do
		Medals.Even(part)
	end
	if piece.glint then
		local at = Widgets.Snap(piece, 1)
		piece.glint:SetPoint("CENTER", piece.bar, "CENTER", -at, at)
	end
end

local function Arrange(r)
	local n = 0
	for _, b in ipairs(r.sigils) do
		local f = b.family
		local on = f.known and not f.known[1] or Medals.Known(f.known or f.spells) ~= nil
		b.container:SetAuraSlotEnabled(b.key, on)
		b.container:SetAuraSlotEnabled(b.ember.key, on and ns.Config("crestEmber") ~= false)
		b.at = on and { r.left + n % r.per * r.pitch, r.first + floor(n / r.per) * r.rise } or nil
		if b.at then
			for _, slot in ipairs({ b, b.ember }) do
				slot:ClearAllPoints()
				slot:SetPoint("CENTER", r, "CENTER", Widgets.Snap(r, b.at[1]), Widgets.Snap(r, b.at[2]))
			end
			n = n + 1
		end
	end
end

function Medals.Place(piece, anchor, x, y)
	piece:ClearAllPoints()
	piece:SetPoint("CENTER", anchor, "CENTER", Widgets.Snap(anchor, x), Widgets.Snap(anchor, y))
	Medals.Size(piece)
	if piece.sigils and not Medals.Locked() then
		Arrange(piece)
	end
end

function Medals.Fire(piece)
	if piece.flare and Effects.Allows("ambient") and not ns.Slab.Resting() then
		piece.flare.play:Stop()
		piece.flare.play:Play()
	end
end

local function Animate(button, full)
	if button.full == full then
		return false
	end
	for kind, groups in pairs({ AuraShown = button.loops or { button.loop }, AuraAssigned = { button.flare and button.flare.play }, PandemicActive = { button.flicker } }) do
		for _, group in ipairs(groups) do
			if full then
				button["Add" .. kind .. "Animation"](button, group)
			elseif button.full then
				button["Remove" .. kind .. "Animation"](button, group)
				group:Stop()
			end
		end
	end
	button.full = full
	return true
end

local function Drive(button, on, full, armed)
	if Animate(button, full) then
		button.fed = nil
	end
	local c = button.container
	if button.fed ~= on and not armed[c] then
		armed[c] = true
		if button.fed == nil then
			c:SetEnabled(false)
		end
		c:SetEnabled(on)
		c.on = on
	end
	button.fed = on
end

function Medals.Engine(pieces, on, full)
	if Medals.Restricted() then
		return false
	end
	local armed = {}
	for _, p in ipairs(pieces) do
		for _, button in ipairs(p.sigils or NONE) do
			Animate(button, full)
		end
		for _, button in ipairs(p.lits or { p.lit }) do
			if button.container then
				Drive(button, on, full, armed)
			end
			for _, mirror in ipairs(button.mirrors or NONE) do
				Drive(mirror, on, full, armed)
			end
		end
	end
	return true
end

function Medals.Still(piece, still, alpha)
	piece.fire:SetAlpha(still and 0 or alpha)
	piece.still:SetAlpha(still and alpha or 0)
end

function Medals.OnRest(fn)
	watchers[#watchers + 1] = fn
end

function Medals.Rest()
	local still = not Effects.Allows("ambient") or ns.Slab.Resting()
	for _, r in ipairs(rims) do
		Medals.Still(r, still, 1)
	end
	for _, gate in ipairs(gates) do
		gate:SetAlpha(still and 0 or 1)
	end
	for _, loop in ipairs(breaths) do
		if still or not loop:GetParent():IsVisible() then
			loop:Stop()
		else
			loop:Play()
		end
	end
	for _, fn in ipairs(watchers) do
		fn(still)
	end
end

local function Cooling(m, id, event)
	m.cooling = m.cooling or {}
	if event == "SPELL_UPDATE_COOLDOWN" or event == nil and m.cooling[id] == nil then
		local get = C_Spell and C_Spell.GetSpellCooldown
		local cd = type(get) == "function" and get(id)
		m.cooling[id] = type(cd) == "table" and cd.isActive == true and cd.isOnGCD ~= true
	end
	return m.cooling[id] == true
end

local function Refill(bar, duration)
	local modes = Enum or {}
	if duration and bar.SetTimerDuration then
		local interpolation = modes.StatusBarInterpolation and modes.StatusBarInterpolation.Immediate or 0
		local direction = modes.StatusBarTimerDirection and modes.StatusBarTimerDirection.ElapsedTime or 0
		bar:SetTimerDuration(duration, interpolation, direction)
	else
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
	end
end

function Medals.Refresh(m, event)
	local spec = m.spec
	if spec.feed == "cooldown" then
		local api = C_Spell
		local duration = api and type(api.GetSpellCooldownDuration) == "function" and api.GetSpellCooldownDuration(spec.spell, true)
		if duration and m.timer.SetCooldownFromDurationObject then
			m.timer:SetCooldownFromDurationObject(duration, true)
		else
			m.timer:Clear()
		end
		local cooling = (m.bar or m.ready) and duration and Cooling(m, spec.spell, event) or false
		if cooling ~= m.cooled then
			m.cooled = cooling
			if m.bar then
				Refill(m.bar, cooling and duration)
			end
			if m.ready then
				m.ready:SetShown(not cooling)
			end
		end
		return
	end
	if spec.feed == "enchant" then
		local get = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
		local info = type(get) == "function" and get(spec.slot == "OffHand" and 17 or 16)
		local id = type(info) == "table" and info.enchantID
		local alpha = not IsSecret(id) and spec.reject and spec.reject[id] and 0 or 1
		m.lit.gate:SetAlpha(alpha)
		for _, mirror in ipairs(m.lit.mirrors or NONE) do
			mirror.gate:SetAlpha(alpha)
		end
		return
	end
	if spec.feed == "threat" then
		local read = UnitDetailedThreatSituation
		local tanking, _, scaled
		if read then
			tanking, _, scaled = read("player", "target")
		end
		if not IsSecret(scaled) and scaled == nil then
			scaled = 0
		end
		if not IsSecret(tanking) and tanking == nil then
			tanking = false
		end
		if m.bar then
			m.bar:SetValue(scaled)
		end
		m.lit:SetAlphaFromBoolean(tanking, 1, 0)
		return
	end
	if spec.feed == "item" then
		local item = C_Item
		local id, start, duration, enable, gcd
		if spec.slot and type(GetInventoryItemID) == "function" and type(GetInventoryItemCooldown) == "function" then
			id = GetInventoryItemID("player", spec.slot)
			id = not IsSecret(id) and id or nil
			start, duration, enable, gcd = GetInventoryItemCooldown("player", spec.slot)
		end
		for _, each in ipairs(spec.items or NONE) do
			local count = item and item.GetItemCount and item.GetItemCount(each)
			if not IsSecret(count) and type(count) == "number" and count > 0 then
				id = each
				start, duration = item.GetItemCooldown(each)
				break
			end
		end
		m.lit:SetShown(id ~= nil)
		if id then
			local icon = m.lit.icon
			if icon then
				icon:SetTexture(item.GetItemIconByID and item.GetItemIconByID(id) or spec.texture)
			end
			local cooling = not (IsSecret(start) or IsSecret(duration) or IsSecret(enable) or IsSecret(gcd)) and type(duration) == "number" and duration > 0
				and enable ~= 0 and gcd ~= true
			if cooling then
				m.timer:SetCooldown(start, duration)
			else
				m.timer:Clear()
			end
			if icon then
				icon:SetDesaturated(cooling)
			end
			if m.ready then
				m.ready:SetShown(not cooling)
			end
			if m.bar then
				local util = C_DurationUtil
				if cooling and not m.span and util and type(util.CreateDuration) == "function" then
					m.span = util.CreateDuration()
				end
				if cooling and m.span then
					m.span:SetTimeFromStart(start, duration)
				end
				Refill(m.bar, cooling and m.span)
			end
		end
		return
	end
	local api, lit = C_Spell, nil
	if not (api and type(api.IsSpellUsable) == "function") then
		return
	end
	for _, id in ipairs(spec.candidates) do
		local usable = api.IsSpellUsable(id)
		if IsSecret(usable) then
			return
		end
		if usable == true and not Cooling(m, id, event) then
			lit = id
			break
		end
	end
	if lit ~= m.usable then
		if lit and m.pick then
			m.pick(lit)
		elseif lit and m.lit.icon then
			m.lit.icon:SetTexture(api.GetSpellTexture and api.GetSpellTexture(lit) or spec.texture)
		end
		if lit and (not m.usable or m.pick) then
			Medals.Fire(m)
		end
		m.lit:SetShown(lit ~= nil)
		m.usable = lit
	end
end
