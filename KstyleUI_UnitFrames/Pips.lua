-- Pips.lua: the class-themed combo point row over the plain pips' places for Frames and Orbs, Widgets.ClassPip daggers for a rogue and claws for a cat-form druid, with a glow under the full row; under Medallions the crest's crown shows them instead.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects

local Pips = {}
ns.Pips = Pips

local ART, ROW, FADE = 1.6, 0.35, 0.2

local state = { pips = {}, count = 0 }
Pips.state = state

function Pips.Has(class)
	return Widgets.ClassPipSet(class, 90) ~= nil
end

local function Glow(row, set, count, from, to)
	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetFrameLevel(row:GetFrameLevel())
	bar:SetAllPoints(row)
	bar:SetStatusBarTexture((Tokens.Texture("glow")))
	bar:GetStatusBarTexture():SetBlendMode("ADD")
	bar:SetStatusBarColor(Tokens.Color(set.glowColor))
	bar:SetMinMaxValues(count - 1, count)
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
	row.now, row.was = Glow(row, set, count, 0, 1), Glow(row, set, count, 1, 0)
	row.was:Hide()
	row.was.anim:SetScript("OnFinished", function() row.was:Hide() end)
	return row
end

function Pips.Apply(class, parent, count)
	local set = class and Widgets.ClassPipSet(class, 90)
	state.theme = set
	if set and #state.pips == 0 then
		state.parent, state.count = parent, count
		for i = 1, count do
			state.pips[i] = Widgets.ClassPip(parent, set, i, count)
		end
		state.row = BuildRow(set, count)
	end
	for _, p in ipairs(state.pips) do
		p.frame:SetShown(set ~= nil)
	end
	if state.row then
		state.row:SetShown(set ~= nil)
	end
	return set ~= nil
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
	for _, p in ipairs(state.pips) do
		p:Set(points, was, moving, false)
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
end
