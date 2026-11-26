-- SlabUnleashed.lua: Unleashed (docs/medallions-effects.md#unleashed), the crest erupting in class fire while a major cooldown burns: each cooldown rim container gets two more slots of its own newest aura, one awake and one still, each under a gate the crest owns, so motion swaps by gate alpha in combat; they hold the class's ambient fire as a corona hugging the ring, a hot line on the ring's edge, the rune glyphs blazing near white and turning at one and a half times combat speed, a dim outer ring draining with the aura and, awake, the class burst growing out of the ring as a cooldown is assigned. Every layer sits under the level badge and inside a 184-unit mask. The player's own cast lifts the emblem; while auras are readable the corona folds and the glyphs cool when the last tracked aura instance goes, and under hidden values they do so the frame after a hot line's timer ends or its slot hides, once no tracked slot of the player's or the pet's is still lit and while the switch is on. The switch off detaches and disables the slots at the next legal moment. Under Frames the newest-cooldown medal wears the corona over a breathing glow behind the row.
local _, ns = ...

local K = KstyleUI
local Tokens, Effects, Widgets = K.Tokens, K.Effects, K.Widgets
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals

local Unleashed = {}
ns.SlabUnleashed = Unleashed

local OWNER, WAIT = "ActionBars.SlabUnleashed", "ActionBars.SlabUnleashed.Bind"
local RIM, CORONA, MASK, LINE, ROW_CORONA, ROW_GLOW, EMBERS = 150, 212, 184, 154, 1.9, 3, 8
local FLIP, BREATH, BREATH_LOW, TURN = 0.96, 0.7, 0.85, 90 / (2.25 * 1.5)
local WHITE, WARM = 0.55, 0.6
local BURST = { 0.85, 1.45, 0.5 }
local LIFT = { { 1, 1.06, 0.12 }, { 1.06, 1.03, 0.25 }, { 1.03, 1.03, 0.6, "NONE" }, { 1.03, 1, 0.6 } }
local FOLD, FOLD_RUN, COOL_RUN = 1.12, 0.4, 0.6
local GATES = { "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }
local sets, tints, state, NONE = {}, {}, { ids = {} }, {}
Unleashed.sets, Unleashed.state = sets, state

local function Fade(group, from, to, duration)
	ns.Slab.Fade(group, from, to, duration)
	return group
end

local function Sized(piece, parent, level, units)
	local f = CreateFrame("Frame", nil, parent)
	f:SetPoint("CENTER", piece, "CENTER", 0, 0)
	f:SetFrameLevel(level)
	return piece.add(f, units)
end

local function Tint(region, white, alpha)
	local r, g, b = K.Theme.ClassColor(ns.class)
	region:SetVertexColor(r + (1 - r) * white, g + (1 - g) * white, b + (1 - b) * white, alpha or 1)
	tints[#tints + 1] = { region, white, alpha }
	return region
end

local function Mask(piece, frame, ...)
	local mask = frame:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("orbMask")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetPoint("CENTER", piece, "CENTER", 0, 0)
	piece.add(mask, MASK)
	for _, region in ipairs({ ... }) do
		region:AddMaskTexture(mask)
	end
end

local function Fire(piece, parent, level, units, ambient, masked, single)
	local fire = Sized(piece, parent, level, units)
	local cloud, embers = Medals.Cloud(fire, ambient, 0), not single and Medals.Cloud(fire, ambient, EMBERS) or nil
	if masked then
		Mask(piece, fire, cloud, embers)
	end
	return fire, cloud
end

local function Lights(piece, lit, spec, crest, awake)
	local ambient = (spec.burst or "medBurstWarrior"):gsub("^medBurst", "medAmbient")
	local level, hub = lit:GetFrameLevel() + 2, crest and ns.Slab.hub:GetFrameLevel()
	local gate = Medals.Layer(piece, level)
	local slot = Medals.Feed(gate, setmetatable({}, { __index = lit.spec }), level)
	gate.lit = slot
	local fire, cloud = Fire(piece, slot, hub and hub + 1 or level, crest and CORONA or piece.units * ROW_CORONA, ambient, crest)
	local glow
	if crest then
		local warm = Sized(piece, slot, hub - 1, CORONA)
		Mask(piece, warm, piece.add(Medals.Texture(warm, "ARTWORK", 0, spec.burst or "glow", "white", CORONA, "ADD")))
		warm:SetAlpha(WARM)
		glow = Tint(piece.add(Medals.Texture(fire, "OVERLAY", 0, "medRuneGlyphs", "white", RIM, "ADD")), WHITE)
		gate.timer = piece.add(Medals.Timer(slot, hub + 1, "ringLine32", spec.color), LINE)
		slot:SetDurationCooldown(gate.timer)
	else
		glow = Sized(piece, slot, piece:GetParent():GetFrameLevel(), piece.units * ROW_GLOW)
		Tint(Medals.Texture(glow, "BACKGROUND", 0, "glow", "white", nil, "ADD"), 0, 0.35):SetAllPoints(glow)
	end
	if awake then
		slot.loops = { Medals.Flip(cloud, ambient, FLIP / select(4, Tokens.Flipbook(ambient))), Fade(ns.Slab.Group(crest and fire or glow, "BOUNCE"), 1, BREATH_LOW, BREATH) }
		if crest then
			local spin = glow:CreateAnimationGroup()
			spin:SetLooping("REPEAT")
			local turn = spin:CreateAnimation("Rotation")
			turn:SetDegrees(-360)
			turn:SetDuration(TURN)
			slot.loops[3] = spin
			local burst = Medals.Layer(piece, level)
			burst.lit = Medals.Feed(burst, setmetatable({}, { __index = lit.spec }), level)
			local flare = piece.add(Medals.Texture(burst.lit, "OVERLAY", 1, spec.burst or "glow", "white", RIM, "ADD"))
			flare:SetAlpha(0)
			flare.play = flare:CreateAnimationGroup()
			ns.Slab.Grow(flare.play, BURST[1], BURST[2], BURST[3])
			Fade(flare.play, 1, 0, BURST[3]).held = BURST[3]
			flare.gate, burst.lit.flare, gate.burst = burst, flare, burst
		end
	end
	return gate
end

local function Fold(piece, spec)
	local hub = ns.Slab.hub:GetFrameLevel() + 1
	local _, fold = Fire(piece, piece, hub, CORONA, (spec.burst or "medBurstWarrior"):gsub("^medBurst", "medAmbient"), true, true)
	fold:SetAlpha(0)
	fold.play = fold:CreateAnimationGroup()
	ns.Slab.Grow(fold.play, FOLD, 1, FOLD_RUN)
	Fade(fold.play, 1, 0, FOLD_RUN)
	local cool = Sized(piece, piece, hub, RIM)
	Tint(piece.add(Medals.Texture(cool, "OVERLAY", 0, "medRuneGlyphs", "white", RIM, "ADD")), WHITE)
	cool:SetAlpha(0)
	cool.play = Fade(cool:CreateAnimationGroup(), 1, 0, COOL_RUN)
	return fold, cool
end

local Settle

function Unleashed.Dress(piece, spec, form)
	local crest = form == "crest"
	for i, lit in ipairs(piece.lits) do
		local set = { piece = piece, crest = crest, lit = lit, awake = Lights(piece, lit, spec, crest, true), still = Lights(piece, lit, spec, crest, false) }
		set.lits = { set.awake.lit, set.still.lit, set.awake.burst and set.awake.burst.lit }
		if crest then
			if i == 1 then
				set.fold, set.cool = Fold(piece, spec)
			end
			set.awake.lit:HookScript("OnShow", function() set.up, state.lit = true, true end)
			set.awake.lit:HookScript("OnHide", function()
				set.up = nil
				if piece:IsVisible() and set.awake:IsShown() then
					Settle()
				else
					state.lit = nil
				end
			end)
			set.awake.timer:SetScript("OnCooldownDone", function()
				set.up = nil
				Settle()
			end)
		end
		sets[#sets + 1] = set
	end
	for _, family in ipairs(spec.families) do
		for _, list in ipairs({ family.spells, family.known or NONE }) do
			for _, id in ipairs(list) do
				state.ids[id] = family.unit or "player"
			end
		end
	end
end

local function Moving(set)
	return Effects.Allows("pulse") and not (set.crest and ns.Slab.Resting())
end

local function Folds(set)
	if set.fold and set.piece:IsVisible() and Moving(set) then
		for _, region in ipairs({ set.fold, set.cool }) do
			region.play:Stop()
			region.play:Play()
		end
	end
end

local function Settled()
	state.settling = nil
	local fold
	for _, set in ipairs(sets) do
		if set.crest and set.up then
			return
		end
		fold = fold or set.fold and set
	end
	local was = state.lit
	state.lit = nil
	if was and fold and Medals.Restricted() and ns.Config("crestUnleashed") ~= false then
		Folds(fold)
	end
end

function Settle()
	if not state.settling and C_Timer and C_Timer.After then
		state.settling = true
		C_Timer.After(0, Settled)
	end
end

local function Scan()
	local get = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	state.live = nil
	if type(get) ~= "function" or Medals.Restricted() then
		return
	end
	local live = {}
	for id, unit in pairs(state.ids) do
		local aura = get(unit, id)
		if IsSecret(aura) then
			return
		end
		if aura then
			live[aura.auraInstanceID] = true
		end
	end
	state.live = live
end

local function OnAura(_, _, info)
	if Medals.Restricted() then
		state.live = nil
		return
	end
	if not state.live or type(info) ~= "table" or info.isFullUpdate then
		return Scan()
	end
	for _, aura in ipairs(info.addedAuras or NONE) do
		if state.ids[aura.spellId] then
			state.live[aura.auraInstanceID] = true
		end
	end
	local ended
	for _, id in ipairs(info.removedAuraInstanceIDs or NONE) do
		ended = ended or state.live[id]
		state.live[id] = nil
	end
	if not (ended and next(state.live) == nil) then
		return
	end
	for _, set in ipairs(sets) do
		Folds(set)
	end
end

local function OnCast(_, _, _, spell)
	local hub = ns.Slab.hub
	if IsSecret(spell) or not state.ids[spell] or not (hub and hub:IsVisible() and Effects.Allows("flare")) then
		return
	end
	if not hub.crest.lift then
		hub.crest.lift = hub.crest:CreateAnimationGroup()
		for i, s in ipairs(LIFT) do
			ns.Slab.Grow(hub.crest.lift, s[1], s[2], s[3], i, s[4])
		end
	end
	hub.crest.lift:Stop()
	hub.crest.lift:Play()
end

local function Bind()
	local locked, on = Medals.Locked(), ns.Config("crestUnleashed") ~= false
	if not locked then
		local r, g, b = K.Theme.ClassColor(ns.class)
		for _, t in ipairs(tints) do
			t[1]:SetVertexColor(r + (1 - r) * t[2], g + (1 - g) * t[2], b + (1 - b) * t[2], t[3] or 1)
		end
		for _, set in ipairs(sets) do
			Medals.Engine({ set }, on and set.lit.fed == true, on and Effects.Allows("pulse"))
		end
	end
	local listen = locked and K.Events.Register or K.Events.Unregister
	for _, event in ipairs(GATES) do
		listen(WAIT, event, Bind)
	end
end

function Unleashed.Paint()
	local on, crest, shown = ns.Config("crestUnleashed") ~= false, false, false
	for _, set in ipairs(sets) do
		local moving = Moving(set)
		set.awake:SetShown(on)
		set.still:SetShown(on)
		set.awake:SetAlpha(moving and 1 or 0)
		if set.awake.burst then
			set.awake.burst:SetShown(on)
			Medals.Gate(set.awake.burst, moving and 1 or 0)
		end
		set.still:SetAlpha(moving and 0 or 1)
		shown = shown or on and set.piece:IsVisible()
		crest = crest or on and set.crest and set.piece:IsVisible()
		if not on and set.fold then
			set.fold.play:Stop()
			set.cool.play:Stop()
		end
	end
	local lift = not on and ns.Slab.hub and ns.Slab.hub.crest.lift
	if lift then
		lift:Stop()
	end
	Bind()
	if shown ~= state.shown then
		state.shown = shown
		local listen = shown and K.Callbacks.Register or K.Callbacks.Unregister
		for _, event in ipairs({ "ThemeChanged", "ProfileChanged" }) do
			listen(event, OWNER, Unleashed.Paint)
		end
	end
	if crest ~= state.listening then
		state.listening = crest
		if crest then
			K.Events.RegisterUnit(OWNER, "UNIT_SPELLCAST_SUCCEEDED", OnCast, "player")
			K.Events.RegisterUnit(OWNER, "UNIT_AURA", OnAura, "player", "pet")
			Scan()
		else
			K.Events.UnregisterAll(OWNER)
			state.live = nil
		end
	end
end

Medals.OnRest(Unleashed.Paint)
