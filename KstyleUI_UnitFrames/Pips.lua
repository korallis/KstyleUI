-- Pips.lua: the class-themed combo point pips over the plain pips' places, a rogue's daggers and a cat-form druid's claw marks; every lit layer is a one-point status bar fed the raw count now or the count before, so the engine compares and Lua never reads a secret: a gain slides the pip in under a flare, a spend holds, slashes and drains it, and the maximum sweeps a shine along the row over a glow that breathes under Medallions.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local issecretvalue = issecretvalue or function() return false end

local Pips = {}
ns.Pips = Pips

local ART, HALO, SLIDE, ROW = 1.6, 1.25, 0.4, 0.35
local ALPHA, LOW, BREATH = 0.4, 0.55, 1.1
local RISE, FALL, DRAIN, FADE = 0.03, 0.09, 0.18, 0.2
local HOLD = RISE + FALL
local CUT, SWEEP, STAGGER, REST = 0.16, 0.3, 0.05, 3.5
local THEMES = {
	ROGUE = { art = "pipRogue", socket = "pipRogueSocket", shape = "pipRogueShape", glow = "pipRogueGlow", core = "pipRogueCore", from = -1 },
	DRUID = { art = "pipDruid", socket = "pipDruidSocket", shape = "pipDruidShape", glow = "pipDruidGlow", core = "pipDruidCore", from = 1 },
}
local LAYERS = {
	{ key = "halo", feed = "now", art = "glow", add = true },
	{ key = "haloWas", feed = "was", art = "glow", add = true, transient = true },
	{ key = "rise", feed = "now", art = "art", mask = true, transient = true },
	{ key = "flare", feed = "now", art = "shape", add = true, transient = true },
	{ key = "ember", feed = "was", art = "art", transient = true },
	{ key = "slash", feed = "was", art = "streak", add = true, mask = true, transient = true },
	{ key = "blade", feed = "now", art = "art" },
	{ key = "shine", feed = "max", art = "streak", add = true, mask = true, transient = true },
}

local state = { pips = {}, count = 0 }
Pips.state = state

local function Create(bar, kind)
	bar.anim = bar.anim or bar:CreateAnimationGroup()
	return bar.anim:CreateAnimation(kind)
end

local function Step(bar, order, duration, from, to, smoothing)
	local a = Create(bar, "Alpha")
	a:SetOrder(order)
	a:SetDuration(duration)
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetSmoothing(smoothing or "NONE")
	return a
end

local function Move(bar, order, duration, smoothing)
	local a = Create(bar, "Translation")
	a:SetOrder(order)
	a:SetDuration(duration)
	a:SetSmoothing(smoothing or "NONE")
	return a
end

local function Idle(p)
	p.shineWait:SetDuration(REST + (p.i - 1) * STAGGER)
	p.shine.anim:SetLooping("REPEAT")
	p.shine:Show()
	p.shine.anim:Play()
end

local function Animate(p)
	Step(p.halo, 1, FADE, 0, ALPHA)
	Step(p.haloWas, 1, FADE, ALPHA, 0)
	p.slideFrom = Move(p.rise, 1, 0)
	p.slideTo = Move(p.rise, 2, HOLD, "OUT")
	Step(p.rise, 1, 0, 0, 0)
	Step(p.rise, 2, RISE, 0, 1)
	Step(p.rise, 3, RISE, 1, 1)
	Step(p.flare, 1, RISE, 0, 1)
	Step(p.flare, 2, FALL, 1, 0)
	Step(p.ember, 1, HOLD, 1, 1)
	Step(p.ember, 2, DRAIN, 1, 0)
	Step(p.slash, 1, HOLD, 0, 0)
	Step(p.slash, 2, RISE, 0, 1)
	Step(p.slash, 3, CUT, 1, 0, "IN")
	Step(p.blade, 1, HOLD, 0, 0)
	Step(p.blade, 2, 0, 1, 1)
	p.shineFrom = Move(p.shine, 1, 0)
	p.shineWait = Step(p.shine, 1, HOLD, 0, 0)
	p.shineTo = Move(p.shine, 2, SWEEP, "IN_OUT")
	Step(p.shine, 2, SWEEP, 1, 1)
	for _, layer in ipairs(LAYERS) do
		local bar = p[layer.key]
		if layer.transient then
			bar:Hide()
			bar.anim:SetScript("OnFinished", function()
				if bar == p.shine and state.idle then
					Idle(p)
				else
					bar:Hide()
				end
			end)
		end
	end
end

local function Build(i, theme)
	local holder = CreateFrame("Frame", nil, state.parent)
	local level = state.parent:GetFrameLevel() + 2
	holder:SetFrameLevel(level)
	local p = { holder = holder, i = i }
	p.socket = holder:CreateTexture(nil, "BACKGROUND")
	p.socket:SetTexture((Tokens.Texture(theme.socket)))
	p.socket:SetAllPoints(holder)
	p.mask = holder:CreateMaskTexture()
	p.mask:SetTexture((Tokens.Texture(theme.shape)), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	p.mask:SetAllPoints(holder)
	local files = { art = theme.art, shape = theme.shape, streak = "pipStreak", glow = "glow" }
	for n, layer in ipairs(LAYERS) do
		local bar = CreateFrame("StatusBar", nil, holder)
		bar:SetFrameLevel(level + n)
		bar:SetStatusBarTexture((Tokens.Texture(files[layer.art])))
		if layer.key == "halo" or layer.key == "haloWas" then
			bar:SetPoint("CENTER", holder, "CENTER", 0, 0)
			bar:SetAlpha(ALPHA)
		else
			bar:SetAllPoints(holder)
		end
		local texture = bar:GetStatusBarTexture()
		if layer.add then
			texture:SetBlendMode("ADD")
		end
		if layer.mask then
			texture:AddMaskTexture(p.mask)
		end
		p[layer.key] = bar
	end
	Animate(p)
	return p
end

local function BuildRow()
	local row = CreateFrame("Frame", nil, state.parent)
	row:SetFrameLevel(state.parent:GetFrameLevel() + 1)
	row.now = CreateFrame("StatusBar", nil, row)
	row.was = CreateFrame("StatusBar", nil, row)
	for _, bar in ipairs({ row.now, row.was }) do
		bar:SetFrameLevel(row:GetFrameLevel())
		bar:SetAllPoints(row)
		bar:SetStatusBarTexture((Tokens.Texture("glow")))
		bar:GetStatusBarTexture():SetBlendMode("ADD")
	end
	Step(row.now, 1, FADE, 0, 1)
	Step(row.was, 1, FADE, 1, 0)
	row.was:Hide()
	row.was.anim:SetScript("OnFinished", function() row.was:Hide() end)
	row.breath = row:CreateAnimationGroup()
	row.breath:SetLooping("BOUNCE")
	local a = row.breath:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(LOW)
	a:SetDuration(BREATH)
	a:SetSmoothing("IN_OUT")
	state.row = row
	return row
end

local function Paint(theme)
	local core = { Tokens.Color(theme.core) }
	local glow = { Tokens.Color(theme.glow) }
	for _, p in ipairs(state.pips) do
		for _, layer in ipairs(LAYERS) do
			local color = layer.art == "glow" and glow or layer.add and core or nil
			p[layer.key]:SetStatusBarColor(color and color[1] or 1, color and color[2] or 1, color and color[3] or 1)
		end
	end
	for _, bar in ipairs({ state.row.now, state.row.was }) do
		bar:SetStatusBarColor(glow[1], glow[2], glow[3])
	end
end

function Pips.Apply(class, parent, count)
	local theme = class and THEMES[class]
	state.theme = theme
	if not theme then
		for _, p in ipairs(state.pips) do
			p.holder:Hide()
		end
		if state.row then
			state.row:Hide()
		end
		return false
	end
	state.parent, state.count = parent, count
	for i = #state.pips + 1, count do
		state.pips[i] = Build(i, theme)
	end
	if not state.row then
		BuildRow()
	end
	for i, p in ipairs(state.pips) do
		p.holder:SetShown(i <= count)
		for _, layer in ipairs(LAYERS) do
			local bar = p[layer.key]
			if layer.feed == "max" then
				bar:SetMinMaxValues(count - 1, count)
			else
				bar:SetMinMaxValues(i - 1, i)
			end
		end
	end
	for _, bar in ipairs({ state.row.now, state.row.was }) do
		bar:SetMinMaxValues(count - 1, count)
	end
	state.row:Show()
	Paint(theme)
	return true
end

function Pips.Layout(cells, size)
	if not state.theme then
		return
	end
	local Snap = function(units) return Widgets.Snap(state.parent, units) end
	local art = Snap(size) + 2 * Snap(size * (ART - 1) / 2)
	local halo = art + 2 * Snap(art * (HALO - 1) / 2)
	for i, p in ipairs(state.pips) do
		local cell = cells[i]
		p.holder:ClearAllPoints()
		p.holder:SetPoint("CENTER", cell, "CENTER", 0, 0)
		p.holder:SetSize(art, art)
		p.halo:SetSize(halo, halo)
		p.haloWas:SetSize(halo, halo)
		local x = state.theme.from * art * SLIDE
		p.slideFrom:SetOffset(x, x)
		p.slideTo:SetOffset(-x, -x)
		p.shineFrom:SetOffset(-art, 0)
		p.shineTo:SetOffset(2 * art, 0)
	end
	local row, pad = state.row, Snap(size * ROW)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", cells[1], "TOPLEFT", -pad, pad)
	row:SetPoint("BOTTOMRIGHT", cells[state.count], "BOTTOMRIGHT", pad, -pad)
end

local function Restart(bar)
	bar.anim:Stop()
	bar.anim:SetLooping("NONE")
	bar:Show()
	bar.anim:Play()
end

local function Still()
	for _, p in ipairs(state.pips) do
		for _, layer in ipairs(LAYERS) do
			local bar = p[layer.key]
			bar.anim:Stop()
			if layer.transient then
				bar:Hide()
			end
		end
	end
	state.row.now.anim:Stop()
	state.row.was.anim:Stop()
	state.row.was:Hide()
end

function Pips.Set(points, animate)
	if not state.theme then
		return
	end
	local was = state.seen and state.points or points
	state.points, state.seen = points, true
	local moving = animate and Effects.Allows("flare")
	state.idle = Effects.Active() and Effects.Allows("pulse") and not issecretvalue(points) and type(points) == "number" and points >= state.count
	Still()
	for _, p in ipairs(state.pips) do
		for _, layer in ipairs(LAYERS) do
			p[layer.key]:SetValue(layer.feed == "was" and was or points)
		end
		if moving then
			for _, layer in ipairs(LAYERS) do
				if layer.key ~= "shine" then
					Restart(p[layer.key])
				end
			end
			p.shineWait:SetDuration(HOLD + (p.i - 1) * STAGGER)
			Restart(p.shine)
		elseif state.idle then
			Idle(p)
		end
	end
	local row = state.row
	row.now:SetValue(points)
	row.was:SetValue(was)
	if moving then
		Restart(row.now)
		Restart(row.was)
	end
	if state.idle then
		if not row.breath:IsPlaying() then
			row.breath:Play()
		end
	else
		row.breath:Stop()
	end
end
