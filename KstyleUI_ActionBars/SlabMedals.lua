-- SlabMedals.lua: the Medallions crest's shared medals and ring sockets (docs/medallions-effects.md#crest-medals-and-sockets lists the API): the parts the hawk perches, storm orbs and Spirit Poles share, the crest's named seats, and three pieces the class trackers build: Medal, a round steel medal lit by an aura slot or a weapon enchant (with a timer ring the engine drains from the aura's own duration), by a spell's cooldown duration object or by a usable strike; Rim, an aura that burns round the crest's inner rim and drains with it; Socket, a jewel on the ring whose liquid drains with an aura or a weapon enchant. Engine enables the feeds and hands the engine the flares and the fire at Full while auras are readable; Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local cos, sin, rad, floor, max = math.cos, math.sin, math.rad, math.floor, math.max
local IsSecret = Widgets.IsSecret

local Medals = {}
ns.SlabMedals = Medals

local SIZE, TRACK, ICON, SHADE, BURST, STEEL = 26, 6, 0.74, 1.9, 2.4, 0.45
local RIM, INNER, SETTING, LIP, GEM, GLINT = 150, 112, 12, 10, 8, 2
local COOLDOWN_RING, STACK, STACK_GAP, STACK_DROP, STACK_MAX = 118, 14, 4, 30, 3
local SEATS = {
	left = { -1, 84, 32 }, right = { 1, 84, 32 }, top = { 1, 96, 90 }, topGem = { 1, 60, 90 }, lowerLeft = { -1, 62, -35 }, lowerRight = { 1, 62, -35 },
	leftHip = { 1, 76, 218 }, rightHip = { 1, 76, 322 }, footLeft = { 1, 67.5, 247 }, footRight = { 1, 67.5, 293 },
}
local PIP, PIP_RING, PIP_ARC, GLOW = 4, 17, 22, 0.35
local FLARE = { { 0, 1, 0.05 }, { 1, 0, 0.4 } }
local OWNER = "ActionBars.SlabMedals"
local refreshed, rims, watchers = {}, {}, {}
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

function Medals.Even(region)
	local px = Widgets.Border(region)
	local side = max(2, 2 * floor(region.units / px / 2 + 0.5)) * px
	region:SetSize(side, side)
end

function Medals.Texture(parent, layer, sublevel, texture, color, size, blend)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture((Tokens.Texture(texture)))
	t:SetVertexColor(Tokens.Color(color))
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	if blend then
		t:SetBlendMode(blend)
	end
	t.units = size
	return t
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

local function Art(parent, layer, name, color, blend)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture((Tokens.Texture(name)))
	t:SetVertexColor(Tokens.Color(color))
	if blend then t:SetBlendMode(blend) end
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

local function Timer(parent, level, texture, color, alpha)
	local t = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
	t:SetFrameLevel(level)
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	t:SetSwipeTexture((Tokens.Texture(texture)))
	local r, g, b = Tokens.Color(color)
	t:SetSwipeColor(r, g, b, alpha or 1)
	t:SetDrawEdge(false)
	t:SetDrawBling(false)
	t:SetHideCountdownNumbers(true)
	return t
end

function Medals.Feed(parent, spec, level)
	if spec.feed ~= "aura" and spec.feed ~= "enchant" then
		return Medals.Layer(parent, level)
	end
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
		button = container:AddAuraSlot("lit", spec.filter or "HELPFUL", spec.options)
	else
		button = container:AddItemEnchantment(AuraContainerItemEnchantmentSlot[spec.slot])
	end
	pcall(button.EnableMouse, button, false)
	button:SetAllPoints(parent)
	button:SetFrameLevel(level)
	button.container = container
	return button
end

function Medals.Flare(piece, lit, level, token, size)
	lit.flare = Medals.Layer(lit, level)
	piece.add(Medals.Texture(lit.flare, "ARTWORK", 0, token, "white", size, "ADD"))
	lit.flare:SetAlpha(0)
	lit.flare.play = Medals.Steps(lit.flare, FLARE)
	piece.flare = piece.flare or lit.flare
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

local function Lit(piece, spec, level)
	local lit = Medals.Feed(piece, spec, level)
	piece.lits[#piece.lits + 1] = lit
	piece.lit = piece.lit or lit
	return lit
end

function Medals.Medal(parent, spec, level)
	local size = spec.size or SIZE
	local m = Medals.Piece(parent, level, size)
	local feeds = spec.feeds or { spec }
	local add, timed, track = m.add, spec.color ~= nil, size < SIZE and 2 or TRACK
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
		if each.color and each.feed ~= "cooldown" then
			lit.timer = add(Timer(lit, level + 2 + 2 * (i - 1), "orbRing", each.color), size + track)
			if lit.container then
				lit:SetDurationCooldown(lit.timer)
			end
		elseif each.feed == "cooldown" or each.feed == "item" then
			lit.timer = add(Timer(lit, level + 2, "dot", "black", 0.7), size * ICON)
			lit.timer:SetScript("OnCooldownDone", function() Medals.Fire(m) end)
		end
		if each.count and lit.SetApplicationCount then
			lit.count = Widgets.FontString(lit, "OVERLAY")
			lit.count:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 2, -2)
			lit:SetApplicationCount(lit.count)
		end
		for n = 1, lit.container and each.pips or 0 do
			local slot = lit.container:AddAuraSlot("pip" .. n, each.filter or "HELPFUL", each.options)
			pcall(slot.EnableMouse, slot, false)
			slot:SetAllPoints(m)
			slot:SetFrameLevel(level + 2)
			local pip = add(CreateFrame("StatusBar", nil, slot), PIP)
			local a = rad(270 + (n - (each.pips + 1) / 2) * PIP_ARC)
			pip:SetPoint("CENTER", m, "CENTER", PIP_RING * cos(a), PIP_RING * sin(a))
			pip:SetStatusBarTexture((Tokens.Texture("dot")))
			pip:SetStatusBarColor(Tokens.Color(each.color or "gilt"))
			slot:SetApplicationBar(pip, { minApplications = n - 1, maxApplications = n })
		end
		m.timer = m.timer or lit.timer
		if each.feed == "usable" or each.feed == "item" then
			lit:Hide()
		end
	end
	for _, lit in ipairs(m.lits) do
		Medals.Flare(m, lit, top + 1, spec.burst or "glow", size * BURST)
	end
	m.spec, m.texture = spec, spec.texture
	return m
end

function Medals.Rim(parent, spec, level)
	local r = Medals.Piece(parent, level, RIM)
	local lit = Lit(r, spec, level + 1)
	if spec.ambient then
		r.still = Medals.Cloud(lit, spec.ambient, spec.cell or 0)
		r.fire = Medals.Cloud(lit, spec.ambient, spec.cell or 0)
		r.fire:SetAlpha(0)
		lit.loop = Medals.Flip(r.fire, spec.ambient, 1)
		rims[#rims + 1] = r
	end
	if spec.color then
		r.timer = r.add(Timer(lit, level + 2, "ringLine16", spec.color), INNER)
		if lit.container then
			lit:SetDurationCooldown(r.timer)
		end
	end
	Medals.Flare(r, lit, level + 3, spec.burst or "glow", RIM)
	r.spec = spec
	return r
end

function Medals.CooldownRim(parent, spec, level)
	local r = Medals.Piece(parent, level, RIM)
	local units, order = {}, {}
	for _, family in ipairs(spec.families) do
		local unit = family.unit or "player"
		if not units[unit] then
			units[unit] = { feed = "aura", unit = unit, filter = spec.filter or "HELPFUL", newest = true, spells = {} }
			order[#order + 1] = unit
		end
		for _, id in ipairs(family.spells) do
			table.insert(units[unit].spells, id)
		end
	end
	table.sort(order, function(a, b) return a == "player" and b ~= "player" end)
	r.stack = {}
	local previous
	for i, unit in ipairs(order) do
		local each = units[unit]
		local base = level + 5 * (#order - i)
		local lit = Lit(r, each, base + 1)
		lit.timer = r.add(Timer(lit, base + 2, "ringLine16", spec.color), COOLDOWN_RING)
		lit:SetDurationCooldown(lit.timer)
		Medals.Flare(r, lit, base + 3, spec.burst or "glow", RIM)
		local container, options = lit.container, each.options
		container:ClearAllPoints()
		if previous then
			container:SetPoint("TOPLEFT", previous, "TOPRIGHT", STACK_GAP, 0)
		else
			container:SetPoint("TOP", r, "CENTER", 0, -STACK_DROP)
		end
		container:SetFrameLevel(level + 5 * #order)
		options.maxFrameCount = spec.max or STACK_MAX
		options.layout = { elementWidth = STACK, elementHeight = STACK, elementSpacing = STACK_GAP }
		options.initializeFrame = function(button)
			pcall(button.EnableMouse, button, false)
			button.icon = Medals.Round(button)
			button.icon:SetAllPoints(button)
			button:SetIcon(button.icon)
			button.timer = Timer(button, button:GetFrameLevel() + 1, "orbRing", spec.color)
			button.timer:SetAllPoints(button)
			button:SetDurationCooldown(button.timer)
			r.stack[#r.stack + 1] = button
		end
		container:AddAuraGroup("stack", each.filter, options)
		previous = container
	end
	r.timer = r.lit.timer
	r.spec = spec
	return r
end

function Medals.Socket(parent, spec, level)
	local s = Medals.Piece(parent, level, SETTING)
	local add = s.add
	add(Medals.Texture(s, "ARTWORK", 0, "diamond", "gilt", SETTING))
	add(Medals.Texture(s, "ARTWORK", 1, "diamond", "jewelSetting", LIP))
	add(Medals.Texture(s, "ARTWORK", 2, "forgedDiamond", "jewelSocket", GEM)):SetTexCoord(1, 0, 0, 1)
	local lit = Lit(s, spec, level + 1)
	s.bar = add(CreateFrame("StatusBar", nil, lit), GEM)
	s.bar:SetPoint("CENTER", s, "CENTER", 0, 0)
	s.bar:SetOrientation("VERTICAL")
	s.bar:SetStatusBarTexture((Tokens.Texture("diamond")))
	s.bar:SetStatusBarColor(Tokens.Color(spec.color))
	if lit.container then
		local timer = Enum and Enum.StatusBarTimerDirection
		lit:SetDurationBar(s.bar, { direction = timer and timer.RemainingTime or 1 })
	elseif spec.feed == "cooldown" then
		s.timer = Timer(lit, level + 1, "dot", "black", 0)
		s.timer:SetDrawSwipe(false)
		s.timer:SetScript("OnCooldownDone", function() Medals.Fire(s) end)
	end
	s.glint = add(Medals.Texture(s.bar, "OVERLAY", 0, "diamond", "white", GLINT, "ADD"))
	Medals.Flare(s, lit, level + 3, "glow", SETTING * BURST)
	s.spec = spec
	return s
end

function Medals.Threat(parent, spec, level)
	local t = Medals.Piece(parent, level, SETTING)
	local add = t.add
	add(Medals.Texture(t, "ARTWORK", 0, "diamond", "gilt", SETTING))
	add(Medals.Texture(t, "ARTWORK", 1, "diamond", "jewelSetting", LIP))
	add(Medals.Texture(t, "ARTWORK", 2, "forgedDiamond", "jewelSocket", GEM)):SetTexCoord(1, 0, 0, 1)
	t.bar = add(CreateFrame("StatusBar", nil, t), GEM)
	t.bar:SetFrameLevel(level + 1)
	t.bar:SetPoint("CENTER", t, "CENTER", 0, 0)
	t.bar:SetOrientation("VERTICAL")
	t.bar:SetMinMaxValues(0, 100)
	t.bar:SetValue(0)
	t.bar:SetStatusBarTexture((Tokens.Texture("diamond")))
	t.bar:SetStatusBarColor(Tokens.Color(spec.color))
	t.bar:SetAlpha(0.6)
	t.lit = Medals.Layer(t, level + 2)
	add(Medals.Texture(t.lit, "ARTWORK", 0, "glow", spec.color, SETTING * 2, "ADD"))
	add(Medals.Texture(t.lit, "OVERLAY", 0, "diamond", spec.color, GEM))
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

function Medals.Place(piece, anchor, x, y)
	piece:ClearAllPoints()
	piece:SetPoint("CENTER", anchor, "CENTER", Widgets.Snap(anchor, x), Widgets.Snap(anchor, y))
	for _, part in ipairs(piece.parts) do
		Medals.Even(part)
	end
	if piece.glint then
		local at = Widgets.Snap(piece, 1)
		piece.glint:SetPoint("CENTER", piece.bar, "CENTER", -at, at)
	end
end

function Medals.Fire(piece)
	if piece.flare and Effects.Allows("ambient") then
		piece.flare.play:Stop()
		piece.flare.play:Play()
	end
end

function Medals.Engine(pieces, on, full)
	if Medals.Restricted() then
		return false
	end
	for _, p in ipairs(pieces) do
		for _, button in ipairs(p.lits or { p.lit }) do
			if button.container then
				if button.full ~= full then
					for _, group in pairs({ loop = button.loop, flare = button.flare and button.flare.play }) do
						if full then
							button:AddAuraShownAnimation(group)
						elseif button.full then
							button:RemoveAuraShownAnimation(group)
							group:Stop()
						end
					end
					button.full, button.fed = full, nil
				end
				if button.fed ~= on then
					if button.fed == nil then
						button.container:SetEnabled(false)
					end
					button.container:SetEnabled(on)
					button.fed, button.container.on = on, on
				end
			end
		end
	end
	return true
end

function Medals.Still(piece, still)
	if piece.fire then
		piece.fire:SetAlpha(still and 0 or 1)
		piece.still:SetAlpha(still and 1 or 0)
	end
end

function Medals.OnRest(fn)
	watchers[#watchers + 1] = fn
end

function Medals.Rest()
	local still = not Effects.Allows("ambient") or ns.Slab.Resting()
	for _, r in ipairs(rims) do
		Medals.Still(r, still)
	end
	for _, fn in ipairs(watchers) do
		fn(still)
	end
end

function Medals.Refresh(m)
	local spec = m.spec
	if spec.feed == "cooldown" then
		local api = C_Spell
		local duration = api and type(api.GetSpellCooldownDuration) == "function" and api.GetSpellCooldownDuration(spec.spell, true)
		if duration and m.timer.SetCooldownFromDurationObject then
			m.timer:SetCooldownFromDurationObject(duration, true)
		else
			m.timer:Clear()
		end
		if m.bar then
			local cd = api and type(api.GetSpellCooldown) == "function" and api.GetSpellCooldown(spec.spell)
			local modes = Enum or {}
			if duration and m.bar.SetTimerDuration and type(cd) == "table" and cd.isActive == true and cd.isOnGCD ~= true then
				local interpolation = modes.StatusBarInterpolation and modes.StatusBarInterpolation.Immediate or 0
				local direction = modes.StatusBarTimerDirection and modes.StatusBarTimerDirection.ElapsedTime or 0
				m.bar:SetTimerDuration(duration, interpolation, direction)
			else
				m.bar:SetMinMaxValues(0, 1)
				m.bar:SetValue(1)
			end
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
		local id
		for _, each in ipairs(spec.items) do
			local count = item and item.GetItemCount and item.GetItemCount(each)
			if not IsSecret(count) and type(count) == "number" and count > 0 then
				id = each
				break
			end
		end
		m.lit:SetShown(id ~= nil)
		if id then
			m.lit.icon:SetTexture(item.GetItemIconByID and item.GetItemIconByID(id) or spec.texture)
			local start, duration = item.GetItemCooldown(id)
			if not (IsSecret(start) or IsSecret(duration)) and type(duration) == "number" and duration > 0 then
				m.timer:SetCooldown(start, duration)
			else
				m.timer:Clear()
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
		local cd = type(api.GetSpellCooldown) == "function" and api.GetSpellCooldown(id)
		local cooling = type(cd) == "table" and cd.isActive == true and cd.isOnGCD ~= true
		if usable == true and not cooling then
			lit = id
			break
		end
	end
	if lit ~= m.usable then
		if lit then
			m.lit.icon:SetTexture(api.GetSpellTexture and api.GetSpellTexture(lit) or spec.texture)
			if not m.usable then
				Medals.Fire(m)
			end
		end
		m.lit:SetShown(lit ~= nil)
		m.usable = lit
	end
end
