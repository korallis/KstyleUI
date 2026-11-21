-- Pips.lua: the class-themed combo point row over the plain pips' places, Widgets.ClassPip daggers for a rogue and claw marks for a cat-form druid, with a glow under the full row that breathes under Medallions at Full; under Medallions a rogue's points are the crest's crown of blades instead.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local issecretvalue = issecretvalue or function() return false end

local Pips = {}
ns.Pips = Pips

local ART, ROW = 1.6, 0.35
local LOW, BREATH, FADE = 0.55, 1.1, 0.2
local SETS = {
	ROGUE = { lit = "pipBlade90", steel = "pipBladeSteel90", shape = "pipBladeShape90", glow = "pipBladeGlow90", glowColor = "pipRogueGlow", coreColor = "pipRogueCore", axis = 90 },
	DRUID = { lit = "pipDruid", steel = "pipDruidSocket", shape = "pipDruidShape", glow = "glow", glowColor = "pipDruidGlow", coreColor = "pipDruidCore", axis = 232 },
}

local state = { pips = {}, count = 0 }
Pips.state = state

local function Glow(row, from, to)
	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetFrameLevel(row:GetFrameLevel())
	bar:SetAllPoints(row)
	bar:SetStatusBarTexture((Tokens.Texture("glow")))
	bar:GetStatusBarTexture():SetBlendMode("ADD")
	bar.anim = bar:CreateAnimationGroup()
	local a = bar.anim:CreateAnimation("Alpha")
	a:SetDuration(FADE)
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	return bar
end

local function BuildRow(set, count)
	local row = CreateFrame("Frame", nil, state.parent)
	row:SetFrameLevel(state.parent:GetFrameLevel() + 1)
	row.now, row.was = Glow(row, 0, 1), Glow(row, 1, 0)
	for _, bar in ipairs({ row.now, row.was }) do
		bar:SetStatusBarColor(Tokens.Color(set.glowColor))
		bar:SetMinMaxValues(count - 1, count)
	end
	row.was:Hide()
	row.was.anim:SetScript("OnFinished", function() row.was:Hide() end)
	row.breath = row:CreateAnimationGroup()
	row.breath:SetLooping("BOUNCE")
	local a = row.breath:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(LOW)
	a:SetDuration(BREATH)
	a:SetSmoothing("IN_OUT")
	return row
end

function Pips.Apply(class, parent, count)
	local set = class and SETS[class]
	state.theme = set
	if not set then
		for _, p in ipairs(state.pips) do
			p.frame:Hide()
		end
		if state.row then
			state.row:Hide()
		end
		return false
	end
	state.parent, state.count = parent, count
	for i = #state.pips + 1, count do
		state.pips[i] = Widgets.ClassPip(parent, set, i, count)
	end
	state.row = state.row or BuildRow(set, count)
	for _, p in ipairs(state.pips) do
		p.frame:Show()
	end
	state.row:Show()
	return true
end

function Pips.Layout(cells, size)
	if not state.theme then
		return
	end
	local art = Widgets.Snap(state.parent, size) + 2 * Widgets.Snap(state.parent, size * (ART - 1) / 2)
	for i, p in ipairs(state.pips) do
		p.frame:ClearAllPoints()
		p.frame:SetPoint("CENTER", cells[i], "CENTER", 0, 0)
		p:Layout(art)
	end
	local row, pad = state.row, Widgets.Snap(state.parent, size * ROW)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", cells[1], "TOPLEFT", -pad, pad)
	row:SetPoint("BOTTOMRIGHT", cells[state.count], "BOTTOMRIGHT", pad, -pad)
end

function Pips.Set(points, animate)
	if not state.theme then
		return
	end
	local was = state.seen and state.points or points
	state.points, state.seen = points, true
	local moving = animate and Effects.Allows("flare")
	local idle = Effects.Active() and Effects.Allows("pulse") and not issecretvalue(points) and type(points) == "number" and points >= state.count
	for _, p in ipairs(state.pips) do
		p:Set(points, was, moving, idle)
	end
	local row = state.row
	row.now.anim:Stop()
	row.was.anim:Stop()
	row.was:Hide()
	row.now:SetValue(points)
	row.was:SetValue(was)
	if moving then
		row.was:Show()
		row.now.anim:Play()
		row.was.anim:Play()
	end
	if idle then
		if not row.breath:IsPlaying() then
			row.breath:Play()
		end
	else
		row.breath:Stop()
	end
end
