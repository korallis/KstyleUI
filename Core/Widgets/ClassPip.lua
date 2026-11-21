-- ClassPip.lua: one class-themed resource pip, an art set (lit, dormant, shape, glow) seen along an axis; every lit layer is a one-point status bar fed the raw count now, before, or at the maximum, so the engine compares and Lua never reads a secret: a gain slides the art out along its axis under a flare, a spend holds, slashes and cools to the dormant art, and the maximum runs a glint up the axis, staggered along the row and then back on one common period; while the crest's crown shows the combo points it hands SetClassCrown a seat just above its tips, so the unit frames hand the points over only then and seat the druid bar there.
local _, ns = ...

local Widgets, Tokens = ns.Widgets, ns.Tokens
local cos, sin, rad = math.cos, math.sin, math.rad

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

function Widgets.ClassPipSet(class, angle)
	local c = CLASSES[class]
	return c and {
		lit = c.art .. angle, steel = c.art .. "Steel" .. angle, shape = c.art .. "Shape" .. angle, glow = c.art .. "Glow" .. angle,
		glowColor = c.glowColor, coreColor = c.coreColor, axis = angle,
	}
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
