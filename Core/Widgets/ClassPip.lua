-- ClassPip.lua: one class-themed resource pip, an art set (lit, dormant, shape, glow) seen along an axis; every lit layer is a one-point status bar fed the raw count now, before, or at the maximum, so the engine compares and Lua never reads a secret: a gain slides the art out along its axis under a flare, a spend holds, slashes and cools to the dormant art, and the maximum runs a glint up the axis. Widgets.FedCrown builds the crowns the game feeds instead: an aura's stacks through Blizzard's aura slots, each piece's glow and lit art an application bar (the art sweeping up from its base on a gain and draining on a loss), with a gate shown only at the maximum (a hunter's arrows instead burn the arrow figure's aura inside a frame clipped to that bar's fill); STORM is a shaman's Lightning Shield charges as storm orbs, a kind no class maps to, so only the Frames row asks for it. While the crest's crown shows a class's points it hands SetClassCrown a seat just above its tips, so the unit frames hand the points over only then and seat the druid bar there.
local _, ns = ...

local Widgets, Tokens = ns.Widgets, ns.Tokens
local cos, sin, rad = math.cos, math.sin, math.rad
local IsSecret = Widgets.IsSecret

local HALO, SLIDE, SLASH_W, SLASH_H, GLINT, RUN = 1.2, 0.35, 0.55, 0.16, 0.3, 0.42
local ALPHA = 0.7
local RISE, FALL, DRAIN, FADE = 0.03, 0.09, 0.18, 0.2
local HOLD = RISE + FALL
local CUT, SWEEP, STAGGER, REST = 0.16, 0.3, 0.05, 3.5
local LAYERS = {
	{ key = "halo", feed = "now", art = "glow", tint = "glowColor", add = true },
	{ key = "haloWas", feed = "was", art = "glow", tint = "glowColor", add = true, transient = true },
	{ key = "rise", feed = "now", art = "lit", mask = true, transient = true },
	{ key = "flare", feed = "now", art = "shape", tint = "coreColor", add = true, transient = true },
	{ key = "ember", feed = "was", art = "lit", transient = true },
	{ key = "slash", feed = "was", art = "spot", tint = "coreColor", add = true, mask = true, transient = true },
	{ key = "blade", feed = "now", art = "lit" },
	{ key = "shine", feed = "max", art = "spot", tint = "coreColor", add = true, transient = true },
}

local CLASSES = {
	ROGUE = { art = "pipBlade", glowColor = "jewelCombo", coreColor = "jewelComboCore" },
	DRUID = { art = "pipClaw", glowColor = "pipDruidGlow", coreColor = "pipDruidCore" },
	WARRIOR = { art = "pipBanner", glowColor = "pipWarriorGlow", count = 5, unit = "target", filter = "HARMFUL", spells = { 7386, 7405, 8380, 11596, 11597, 20243 } },
	PRIEST = { art = "pipCandle", glowColor = "pipPriestGlow", count = 5, unit = "target", filter = "HARMFUL", spells = { 15258 }, known = { 15257 } },
	MAGE = {
		art = "pipShard", glowColor = "pipMageGlow", count = 4, unit = "player", filter = "HELPFUL",
		spells = { 400573, 1300176, 1300177, 400586 }, known = { 400574, 1239696, 1239697, 1239699, 1239700 },
	},
	HUNTER = { art = "pipArrow", aura = "auraFigureArrow", glowColor = "jewelHawk", count = 3, unit = "player", filter = "HELPFUL", spells = ns.SpellFamilies.HUNTER.sniper.spells },
	BEAR = { art = "pipTalon", glowColor = "pipBearGlow", count = 5, unit = "target", filter = "HARMFUL|PLAYER", spells = { 1328617, 1328616, 414644, 1235826, 1235827 } },
	STORM = { art = "pipStorm", glowColor = "pipStormGlow", count = 3, unit = "player", filter = "HELPFUL", spells = { 10432, 10431, 8134, 945, 905, 325, 324 } },
	PALADIN = {
		art = "pipShard", glowColor = "jewelHoly", count = 5, unit = "player", filter = "HELPFUL", spells = { 20050, 20925, 20927, 20928, 1239570, 1326084 },
		known = { 20049, 20056, 20057, 20058, 20059, 20925, 20927, 20928, 1239570, 20177, 20179, 20180, 20181, 20182 },
	},
}

local Pip = {}
local crown, follower = nil, nil

local function Create(bar, kind, order, duration, smoothing)
	bar.anim = bar.anim or bar:CreateAnimationGroup()
	local a = bar.anim:CreateAnimation(kind)
	a:SetOrder(order)
	a:SetDuration(duration)
	a:SetSmoothing(smoothing or "NONE")
	return a
end

local function Fade(bar, order, duration, from, to, smoothing)
	local a = Create(bar, "Alpha", order, duration, smoothing)
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	return a
end

local function Restart(bar)
	bar:Show()
	bar.anim:Play()
end

function Pip:Idle(wait)
	self.shineWait:SetDuration(wait)
	Restart(self.shine)
end

function Pip:Layout(size)
	local px = Widgets.Snap(self.frame, size)
	self.frame:SetSize(px, px)
	local halo = Widgets.Snap(self.frame, px * HALO)
	self.halo:SetSize(halo, halo)
	self.haloWas:SetSize(halo, halo)
	self.slash:SetSize(Widgets.Snap(self.frame, px * SLASH_W), Widgets.Snap(self.frame, px * SLASH_H))
	local glint = Widgets.Snap(self.frame, px * GLINT)
	self.shine:SetSize(glint, glint)
	local x, y = cos(rad(self.axis)) * px, sin(rad(self.axis)) * px
	self.slideFrom:SetOffset(-x * SLIDE, -y * SLIDE)
	self.slideTo:SetOffset(x * SLIDE, y * SLIDE)
	self.shineFrom:SetOffset(-x * RUN, -y * RUN)
	self.shineTo:SetOffset(2 * x * RUN, 2 * y * RUN)
end

function Pip:Set(now, was, moving, idle)
	self.idle = idle
	for _, layer in ipairs(LAYERS) do
		local bar = self[layer.key]
		bar.anim:Stop()
		if layer.transient then
			bar:Hide()
		end
		if layer.feed == "was" then
			bar:SetValue(was)
		else
			bar:SetValue(now)
		end
	end
	if moving then
		self.shineWait:SetDuration(HOLD + (self.i - 1) * STAGGER)
		for _, layer in ipairs(LAYERS) do
			Restart(self[layer.key])
		end
	elseif idle then
		self:Idle(REST + (self.i - 1) * STAGGER)
	end
end

function Widgets.SetClassCrown(seat)
	if seat ~= crown then
		crown = seat
		if follower then
			follower()
		end
	end
end

function Widgets.ClassCrown(follow)
	follower = follow or follower
	return crown
end

local sets = {}

function Widgets.ClassPipSet(kind, angle)
	local c = CLASSES[kind]
	if not c then
		return nil
	end
	sets[kind] = sets[kind] or {}
	local set = sets[kind][angle]
	if not set then
		set = {
			lit = c.art .. angle, steel = c.art .. "Steel" .. angle, shape = c.art .. "Shape" .. angle, glow = c.art .. "Glow" .. angle,
			glowColor = c.glowColor, coreColor = c.coreColor, axis = angle,
		}
		sets[kind][angle] = set
	end
	return set
end

function Widgets.ClassPip(parent, set, i, count)
	local frame = CreateFrame("Frame", nil, parent)
	local level = parent:GetFrameLevel() + 2
	frame:SetFrameLevel(level)
	local p = setmetatable({ frame = frame, i = i, axis = set.axis }, { __index = Pip })
	p.steel = frame:CreateTexture(nil, "BACKGROUND")
	p.steel:SetTexture((Tokens.Texture(set.steel)))
	p.steel:SetAllPoints(frame)
	p.mask = frame:CreateMaskTexture()
	p.mask:SetTexture((Tokens.Texture(set.shape)), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	p.mask:SetAllPoints(frame)
	for n, layer in ipairs(LAYERS) do
		local bar = CreateFrame("StatusBar", nil, frame)
		bar:SetFrameLevel(level + n)
		bar:SetStatusBarTexture((Tokens.Texture(set[layer.art] or "glow")))
		bar:SetStatusBarColor(Tokens.Color(layer.tint and set[layer.tint] or "white"))
		bar:SetPoint("CENTER", frame, "CENTER", 0, 0)
		local texture = bar:GetStatusBarTexture()
		if layer.add then
			texture:SetBlendMode("ADD")
		end
		if layer.mask then
			texture:AddMaskTexture(p.mask)
		end
		local top = layer.feed == "max" and count or i
		bar:SetMinMaxValues(top - 1, top)
		bar:SetValue(0)
		p[layer.key] = bar
	end
	for _, key in ipairs({ "rise", "flare", "ember", "blade" }) do
		p[key]:SetAllPoints(frame)
	end
	p.halo:SetAlpha(ALPHA)
	p.haloWas:SetAlpha(ALPHA)
	Fade(p.halo, 1, FADE, 0, ALPHA)
	Fade(p.haloWas, 1, FADE, ALPHA, 0)
	p.slideFrom = Create(p.rise, "Translation", 1, 0)
	p.slideTo = Create(p.rise, "Translation", 2, HOLD, "OUT")
	Fade(p.rise, 1, 0, 0, 0)
	Fade(p.rise, 2, RISE, 0, 1)
	Fade(p.rise, 3, RISE, 1, 1)
	Fade(p.flare, 1, RISE, 0, 1)
	Fade(p.flare, 2, FALL, 1, 0)
	Fade(p.ember, 1, HOLD, 1, 1)
	Fade(p.ember, 2, DRAIN, 1, 0)
	Fade(p.slash, 1, HOLD, 0, 0)
	Fade(p.slash, 2, RISE, 0, 1)
	Fade(p.slash, 3, CUT, 1, 0, "IN")
	Fade(p.blade, 1, HOLD, 0, 0)
	Fade(p.blade, 2, 0, 1, 1)
	p.shineFrom = Create(p.shine, "Translation", 1, 0)
	p.shineWait = Fade(p.shine, 1, HOLD, 0, 0)
	p.shineTo = Create(p.shine, "Translation", 2, SWEEP, "IN_OUT")
	Fade(p.shine, 2, SWEEP, 1, 1)
	for _, layer in ipairs(LAYERS) do
		local bar = p[layer.key]
		if layer.transient then
			bar:Hide()
			bar.anim:SetScript("OnFinished", function()
				if bar == p.shine and p.idle then
					p:Idle(REST)
				else
					bar:Hide()
				end
			end)
		end
	end
	return p
end

local function Known(ids)
	local book = C_SpellBook
	if not (book and type(book.IsSpellKnown) == "function") then
		return false
	end
	for _, id in ipairs(ids) do
		local known = book.IsSpellKnown(id)
		if not IsSecret(known) and known == true then
			return true
		end
	end
	return false
end

function Widgets.CrownKind(class)
	if class == "DRUID" then
		local form, types = UnitPowerType and UnitPowerType("player"), Enum and Enum.PowerType or {}
		if IsSecret(form) then
			return nil
		elseif form == (types.Energy or 3) then
			return "DRUID"
		end
		class = form == (types.Rage or 1) and "BEAR" or nil
	end
	local c = CLASSES[class]
	if not c or c.spells and not Known(c.known or c.spells) then
		return nil
	end
	return class
end

function Widgets.CrownCount(kind)
	return CLASSES[kind] and CLASSES[kind].count
end

function Widgets.CrownOpen()
	local secrets = C_Secrets
	if not (secrets and type(secrets.ShouldAurasBeSecret) == "function") then
		return true
	end
	local ok, secret = pcall(secrets.ShouldAurasBeSecret)
	return ok and not IsSecret(secret) and secret ~= true
end

local Crown = {}

local function Interpolation(moving)
	local modes = Enum and Enum.StatusBarInterpolation or {}
	return moving and (modes.ExponentialEaseOut or 1) or (modes.Immediate or 0)
end

local function Slot(fed, key, anchor, level, low, ease, texture, color, add, container)
	local button = (container or fed.container):AddAuraSlot(key, fed.c.filter, fed.options)
	pcall(button.EnableMouse, button, false)
	button:SetFrameLevel(level)
	button:SetAllPoints(anchor)
	local bar = CreateFrame("StatusBar", nil, button)
	bar:SetAllPoints(button)
	if texture then
		bar:SetStatusBarTexture((Tokens.Texture(texture)))
		bar:SetStatusBarColor(Tokens.Color(color))
		bar:SetOrientation("VERTICAL")
		if add then
			bar:GetStatusBarTexture():SetBlendMode("ADD")
		end
	end
	fed.feeds[#fed.feeds + 1] = { button = button, bar = bar, low = low, ease = ease }
	return bar
end

-- A hunter's arrows: each arrow's still copy sits on an aura slot under a layer of the crown's own, because only that layer can
-- swap it while auras are secret, and the engine's stack count reveals it the way it sweeps the other crowns' art.
local function Gate(fed, level)
	local gate = CreateFrame("Frame", nil, fed.holder)
	gate:SetAllPoints(fed.holder)
	gate:SetFrameLevel(level)
	local container = CreateFrame("AuraContainer", nil, gate, "CustomAuraContainerTemplate")
	Widgets.KeepOut(container)
	container:SetFrameLevel(level)
	container:SetUnit(fed.c.unit)
	gate.container = container
	fed.containers[#fed.containers + 1] = container
	return gate
end

-- The burning copy is the crown's own frame, not an aura button's, so Lua can stop its loop while auras are secret. It is clipped
-- to the still copy's application bar fill, and Pace shows and plays it only for a stack the player is known to hold.
local function Ember(fed, p, token)
	local rows, columns, frames, seconds, span = Tokens.Flipbook(token)
	local bar = Slot(fed, "lit" .. p.i, p.frame, fed.cool:GetFrameLevel() + 1, p.i - 1, true, nil, nil, nil, fed.cool.container)
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", p.frame, "CENTER", 0, 0)
	bar:SetStatusBarTexture((Tokens.Texture("barFlat")))
	bar:SetOrientation("VERTICAL")
	local fill = bar:GetStatusBarTexture()
	fill:SetAlpha(0)
	local function Copy(owner)
		local clip = CreateFrame("Frame", nil, owner)
		clip:SetClipsChildren(true)
		clip:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
		clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
		local t = clip:CreateTexture(nil, "ARTWORK")
		t:SetTexture((Tokens.Texture(token)))
		t:SetBlendMode("ADD")
		t:SetAllPoints(bar)
		t:SetTexCoord(0, 1 / columns, 0, 1 / rows)
		return t, clip
	end
	local a = { span = span or 1, bars = { bar } }
	a.still = Copy(bar)
	a.moving, a.lit = Copy(fed.burn)
	a.lit:Hide()
	a.loop = a.moving:CreateAnimationGroup()
	a.loop:SetLooping("REPEAT")
	local flip = a.loop:CreateAnimation("FlipBook")
	flip:SetFlipBookRows(rows)
	flip:SetFlipBookColumns(columns)
	flip:SetFlipBookFrames(frames)
	flip:SetDuration(seconds)
	fed.auras[#fed.auras + 1] = a
	p.aura = a
end

local function Bind(feeds, moving)
	for _, f in ipairs(feeds) do
		f.button:SetApplicationBar(f.bar, { minApplications = f.low, maxApplications = f.low + 1, interpolation = Interpolation(f.ease and moving) })
	end
end

-- The player's stacks, read only while auras are open; nil when they are secret or unreadable, so no secret is ever compared.
local function Stacks(c)
	local read = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if c.unit ~= "player" or type(read) ~= "function" or not Widgets.CrownOpen() then
		return nil
	end
	for _, id in ipairs(c.spells) do
		local ok, aura = pcall(read, id)
		if not ok or IsSecret(aura) then
			return nil
		end
		if aura then
			local n = aura.applications
			if IsSecret(n) or type(n) ~= "number" then
				return nil
			end
			return n
		end
	end
	return 0
end

-- Arrow i burns and loops only while the crown burns, shows and the player holds i stacks; otherwise, and whenever auras are
-- secret, every loop stops and the engine-fed still copies show.
function Crown:Pace()
	if not self.burn then
		return
	end
	local n = self.burning and self.shown and Stacks(self.c) or 0
	self.burn:SetAlpha(n > 0 and 1 or 0)
	self.cool:SetAlpha(n > 0 and 0 or 1)
	for i, a in ipairs(self.auras) do
		local lit = i <= n
		a.lit:SetShown(lit)
		if not lit then
			a.loop:Stop()
		elseif not a.loop:IsPlaying() then
			a.loop:Play()
		end
	end
end

-- burning: whether the arrows' auras loop (Full, and the crest awake); otherwise each shows its first frame.
function Crown:SetBurning(burning)
	self.burning = burning == true and self.auras[1] ~= nil
	self:Pace()
	return self.burning
end

function Crown:SetMotion(moving, burning)
	self:SetBurning(burning)
	if moving ~= self.moving and pcall(Bind, self.feeds, moving) then
		self.moving = moving
	end
	return moving == self.moving
end

function Crown:Listen(owner, on)
	if self.listening == on then
		return
	end
	self.listening = on
	local Events = ns.Events
	Events.UnregisterAll(owner)
	if on and self.c.unit == "target" then
		Events.Register(owner, "PLAYER_TARGET_CHANGED", function()
			for _, container in ipairs(self.containers) do container:UpdateAllAuras() end
		end)
	end
	if on and self.burn then
		local function Pace() self:Pace() end
		Events.RegisterUnit(owner, "UNIT_AURA", Pace, "player")
		Events.Register(owner, "ADDON_RESTRICTION_STATE_CHANGED", Pace)
	end
end

function Crown:Layout(size)
	for _, p in ipairs(self.pips) do
		local px = Widgets.Snap(p.frame, size)
		p.frame:SetSize(px, px)
		if p.aura then
			local side = Widgets.Snap(p.frame, px * p.aura.span)
			for _, bar in ipairs(p.aura.bars) do bar:SetSize(side, side) end
		end
		local halo = Widgets.Snap(p.frame, px * HALO)
		p.haloFrame:SetSize(halo, halo)
	end
end

function Crown:SetShown(on)
	self.holder:SetShown(on)
	for _, container in ipairs(self.containers) do container:SetEnabled(on) end
	self.shown = on == true
	self:Pace()
end

function Widgets.FedCrown(parent, kind, angles, size, moving)
	local c = CLASSES[kind]
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetAllPoints(parent)
	local made, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not made or type(container) ~= "table" or type(container.AddAuraSlot) ~= "function" then
		holder:Hide()
		return nil
	end
	local level = parent:GetFrameLevel() + 2
	Widgets.KeepOut(container)
	container:SetFrameLevel(level + 1)
	container:SetUnit(c.unit)
	local ids = {}
	for _, id in ipairs(c.spells) do
		ids[id] = true
	end
	local fed = setmetatable({ c = c, holder = holder, container = container, options = { candidateFilters = { includeSpellIDs = ids } }, pips = {}, feeds = {}, auras = {}, containers = { container } }, { __index = Crown })
	if c.aura then
		fed.cool = Gate(fed, level + 4)
		fed.burn = CreateFrame("Frame", nil, holder)
		fed.burn:SetAllPoints(holder)
		fed.burn:SetFrameLevel(level + 6)
	end
	for i, angle in ipairs(angles) do
		local set = Widgets.ClassPipSet(kind, angle)
		local frame = CreateFrame("Frame", nil, holder)
		frame:SetFrameLevel(level)
		local p = { frame = frame, i = i, axis = angle }
		p.steel = frame:CreateTexture(nil, "BACKGROUND")
		p.steel:SetTexture((Tokens.Texture(set.steel)))
		p.steel:SetAllPoints(frame)
		p.haloFrame = CreateFrame("Frame", nil, frame)
		p.haloFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
		p.halo = Slot(fed, "halo" .. i, p.haloFrame, level + 2, i - 1, false, set.glow, set.glowColor, true)
		p.blade = Slot(fed, "lit" .. i, frame, level + 3, i - 1, true, set.lit, c.aura and "black" or "white")
		if c.aura then
			Ember(fed, p, c.aura .. angle)
		end
		fed.pips[i] = p
	end
	fed.max = Slot(fed, "max", holder, level + 1, #angles)
	fed:Layout(size)
	if not fed:SetMotion(moving) then
		holder:Hide()
		return nil
	end
	return fed
end
