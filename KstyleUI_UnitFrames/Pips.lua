-- Pips.lua: the class-themed combo point row over the plain pips' places for Frames, Widgets.ClassPip daggers for a rogue and claws for a cat-form druid, with a glow under the full row; while the Medallions crest's crown shows them the row hides. Under Frames the same row holds the crowns the game feeds, upright Widgets.FedCrown pieces centred on the pips' places (a warrior's banners, a priest's candles, a mage's shards, a hunter's arrows, a bear's talons, a shaman's Lightning Shield charges as storm orbs) with the same glow at the maximum, standing on the druid bar when it shows (a bear's talons at a cat's claws' size); a build or rebind that meets secret auras waits for the end of combat.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local IsSecret = Widgets.IsSecret

local Pips = {}
ns.Pips = Pips

local ART, ROW, FADE = 1.6, 0.35, 0.2
local OWNER = "UnitFrames:pips"

local state = { pips = {}, count = 0, fed = {} }
Pips.state = state

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

local function Kind(class)
	local kind = class and Widgets.CrownKind(class == "SHAMAN" and "STORM" or class)
	return kind and Widgets.CrownCount(kind) and kind or nil
end

local function Watch(on)
	if on == state.watching then
		return
	end
	state.watching = on
	if on then
		K.Events.Register(OWNER, "SPELLS_CHANGED", ns.Resource.Visibility)
		K.Callbacks.Register("EffectsLevelChanged", OWNER, ns.Resource.Visibility)
	else
		K.Events.Unregister(OWNER, "SPELLS_CHANGED")
		K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
	end
end

local function Build(kind, parent, moving)
	local angles = {}
	for i = 1, Widgets.CrownCount(kind) do
		angles[i] = 90
	end
	local crown = Widgets.FedCrown(parent, kind, angles, 1, moving)
	if not crown then
		return false
	end
	local frame = CreateFrame("Frame", nil, crown.max)
	frame:SetFrameLevel(parent:GetFrameLevel() + 1)
	crown.glow = frame:CreateTexture(nil, "ARTWORK")
	crown.glow:SetAllPoints(frame)
	crown.glow:SetTexture((Tokens.Texture("glow")))
	crown.glow:SetBlendMode("ADD")
	crown.glow:SetVertexColor(Tokens.Color(Widgets.ClassPipSet(kind, 90).glowColor))
	crown:SetShown(false)
	return crown
end

function Pips.Fed(class, parent)
	local kind, moving = Kind(class), Effects.Allows("flare")
	if kind and state.fed[kind] == nil and Widgets.CrownOpen() then
		state.fed[kind] = Build(kind, parent, moving)
	end
	local pending = kind ~= nil and state.fed[kind] == nil
	for name, crown in pairs(state.fed) do
		if crown then
			crown:SetShown(name == kind)
			crown:Listen(OWNER .. ":" .. name, name == kind)
			pending = not crown:SetMotion(moving) or pending
		end
	end
	K.Events.Unregister(OWNER, "PLAYER_REGEN_ENABLED")
	if pending then
		K.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", ns.Resource.Visibility)
	end
	Watch(Widgets.CrownCount(class == "SHAMAN" and "STORM" or class == "DRUID" and "BEAR" or class) ~= nil)
	state.crown = kind and state.fed[kind] or nil
	return state.crown ~= nil
end

function Pips.Layout(cells, size, spacing, floor)
	local parent = cells[1]:GetParent()
	local art = Widgets.Snap(parent, size) + 2 * Widgets.Snap(parent, size * (ART - 1) / 2)
	local crown = state.crown
	if crown then
		local n, half = #crown.pips, size / 2 + size * ROW
		for i, p in ipairs(crown.pips) do
			local x = (i - (n + 1) / 2) * (size + spacing)
			x = x < 0 and -Widgets.Snap(parent, -x) or Widgets.Snap(parent, x)
			p.frame:ClearAllPoints()
			if floor then
				p.frame:SetPoint("BOTTOM", floor, "TOP", x, Widgets.Snap(parent, 1))
			else
				p.frame:SetPoint("CENTER", cells[3], "CENTER", x, 0)
			end
		end
		crown:Layout(art)
		local glow = crown.glow:GetParent()
		glow:ClearAllPoints()
		glow:SetPoint("TOPLEFT", crown.pips[1].frame, "CENTER", -Widgets.Snap(parent, half), Widgets.Snap(parent, half))
		glow:SetPoint("BOTTOMRIGHT", crown.pips[n].frame, "CENTER", Widgets.Snap(parent, half), -Widgets.Snap(parent, half))
	end
	if not state.theme then
		return
	end
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
	local was = points
	if state.seen then
		was = state.points
		if animate and not IsSecret(points) and not IsSecret(was) and points == was then
			return
		end
	end
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
