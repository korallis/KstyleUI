-- SlabVigil.lua: the priest's crest trackers, registered with SlabTrackers, each on its own switch: Inner Fire as a halo round the inner rim and four flames on gilt studs, five charges each, burning down from the top right as hits spend them (the last flickers and the halo dims while Lua can read the count); Penance, or Mind Blast before it and for a shadow priest, sweeping on the left shoulder medal and flaring when ready; on the right Shadowfiend for a holy or discipline priest, Shadowform for a shadow priest (steel until worn) and in Shadowform your Vampiric Embrace on the target; your Shadow Word: Pain as a shadow gem at the top of the ring; and the major cooldowns burning on the rim. Under Frames Inner Fire is a medal in the row. Aura slots, cooldown duration objects and the engine's shown animations draw every piece, so Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Effects, Medals, Widgets = K.Effects, ns.SlabMedals, K.Widgets
local sin, cos, rad = math.sin, math.cos, math.rad
local IsSecret = Widgets.IsSecret

local INNER_FIRE = { 10952, 10951, 1006, 602, 7128, 588 }
local PENANCE = { 1316995, 1240721, 1240720, 402174 }
local MIND_BLAST = { 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092 }
local SHADOWFIEND, SHADOWFORM, EMBRACE = { 401977 }, { 15473 }, { 15286 }
local PAIN = { 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local FLAMES, PER, CHARGES, DIM = { 315, 225, 135, 45 }, 5, 20, 0.5
local ORBIT, FLAME, STUD, WELL, PIN, GEM, GAP = 54, 26, 12, 10, 4, 60, 4
local FLICKER = { { 1, 0.45, 0.06 }, { 0.45, 0.9, 0.05 }, { 0.9, 0.35, 0.07 }, { 0.35, 1, 0.08 } }

local CAST = {}
for _, id in ipairs(INNER_FIRE) do CAST[id] = true end

local state = {}

local function Fire(parent, spec, level, form)
	if form == "row" then
		return Medals.Medal(parent, { feed = "aura", spells = INNER_FIRE, texture = spec.texture, color = "pipPriestGlow", burst = spec.burst }, level)
	end
	local r = Medals.Rim(parent, { feed = "aura", spells = INNER_FIRE, ambient = "medAmbientPriest", burst = spec.burst }, level)
	local modes = Enum and Enum.StatusBarInterpolation or {}
	r.ring = {}
	for k, angle in ipairs(FLAMES) do
		local seat = r.add(CreateFrame("Frame", nil, r), FLAME)
		seat:SetFrameLevel(level + 4)
		seat.angle = angle
		r.add(Medals.Texture(seat, "BACKGROUND", 0, "dot", "medSocket", WELL))
		r.add(Medals.Texture(seat, "BORDER", 0, "ring", "gilt", STUD))
		r.add(Medals.Texture(seat, "BORDER", 1, "dot", "steel", PIN)):SetAlpha(0.6)
		local lit = Medals.Feed(seat, { feed = "aura", spells = INNER_FIRE }, level + 5)
		local bar = r.add(CreateFrame("StatusBar", nil, lit), FLAME)
		bar:SetPoint("BOTTOM", seat, "CENTER", 0, 0)
		bar:SetStatusBarTexture((K.Tokens.Texture("trackerFlame")))
		bar:GetStatusBarTexture():SetBlendMode("ADD")
		bar:SetOrientation("VERTICAL")
		lit:SetApplicationBar(bar, { minApplications = (k - 1) * PER, maxApplications = k * PER, interpolation = modes.Immediate or 0 })
		r.lits[#r.lits + 1] = lit
		r.ring[k] = seat
	end
	r.flicker = Medals.Steps(r.ring[1], FLICKER, true)
	state.fire = r
	return r
end

local function Ring(piece, anchor, form, x)
	if form == "row" then
		Medals.Place(piece, anchor, x, 0)
		return x + Medals.SIZE + GAP
	end
	Medals.Place(piece, anchor, 0, 0)
	for _, seat in ipairs(piece.ring) do
		local a = rad(seat.angle)
		seat:ClearAllPoints()
		seat:SetPoint("CENTER", anchor, "CENTER", Widgets.Snap(anchor, ORBIT * sin(a)), Widgets.Snap(anchor, ORBIT * cos(a)))
	end
	return x
end

local function Gem(parent, spec, level, form)
	return (form == "crest" and Medals.Socket or Medals.Medal)(parent, spec, level)
end

local function Motion()
	local r, n = state.fire, state.count
	if not r then
		return
	end
	local resting = ns.Slab.Resting()
	local still, last = resting or not Effects.Allows("ambient"), n ~= nil and n > 0 and n <= PER
	if last then
		r.fire:SetAlpha(still and 0 or DIM)
		r.still:SetAlpha(still and DIM or 0)
	end
	if last and not resting and Effects.Allows("pulse") then
		if not r.flicker:IsPlaying() then
			r.flicker:Play()
		end
	else
		r.flicker:Stop()
	end
end

local function Read()
	local read = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not (read and state.fire and state.fire:IsVisible()) or Medals.Restricted() then
		return nil
	end
	local aura = state.rank and read(state.rank)
	if not aura then
		for _, id in ipairs(INNER_FIRE) do
			aura = read(id)
			if aura then
				state.rank = id
				break
			end
		end
	end
	local n = aura and aura.applications or 0
	return not IsSecret(n) and type(n) == "number" and n or nil
end

local function Count(n)
	if n and n ~= state.count then
		state.count = n
		Motion()
	end
end

local function Paint(_, event, _, _, spellID)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if not IsSecret(spellID) and CAST[spellID] and state.fire and state.fire:IsVisible() then
			Medals.Fire(state.fire)
			Count(CHARGES)
		end
	else
		Count(Read())
	end
end

ns.SlabTrackers.Register("PRIEST", {
	{ key = "crestInnerFire", seat = "rim", feed = "aura", spells = INNER_FIRE, build = Fire, place = Ring },
	{ key = "crestPenance", seat = "left", feed = "cooldown", choices = {
		{ known = function() return not Medals.Known(SHADOWFORM) and Medals.Known(PENANCE) or nil end },
		{ known = MIND_BLAST },
	} },
	{ key = "crestShadowfiend", seat = "right", choices = {
		{ forms = { 28 }, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = EMBRACE, color = "schoolShadow" },
		{ feed = "aura", spells = SHADOWFORM },
		{ feed = "cooldown", known = SHADOWFIEND },
	} },
	{ key = "crestPain", seat = { 0, GEM }, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = PAIN, color = "schoolShadow", build = Gem },
	{ key = "crestCooldowns", seat = "cooldowns", color = "pipPriestGlow", families = {
		{ spells = { 10060 } }, { spells = { 14751 } }, { spells = { 586, 9578, 9579, 9592, 10941, 10942 } }, { spells = { 6346 } },
		{ spells = { 2651 } }, { spells = { 13896, 19271, 19273, 19274, 19275 } }, { spells = { 1277324 } }, { spells = { 1277462 } },
	} },
}, {
	burst = "medBurstPriest",
	events = { { "UNIT_AURA", "player" }, { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
	paint = Paint,
	motion = Motion,
})
