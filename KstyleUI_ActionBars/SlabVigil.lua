-- SlabVigil.lua: the priest's crest trackers, registered with SlabTrackers, each on its own switch: Inner Fire as a halo round the inner rim and four flames on gilt studs, five charges each, burning down from the top right as hits spend them (the last flickers and the halo dims while Lua can read the count); Penance's lance of light, or Mind Blast's orb before it and for a shadow priest, charging on the left shoulder and flaring when ready; on the right Shadowfiend's fiend charging for a holy or discipline priest, Shadowform's shroud for a shadow priest (steel until worn) and in Shadowform the crest flooded violet and your Vampiric Embrace's fangs burning down; your Shadow Word: Pain as a shadow gem at the top of the ring (a healer's Prayer of Mending ready from level 40); a healer's shield on the target as a dome of light over the crest and Renew and Prayer of Mending at the feet, each burning down; a shadow priest's Devouring Plague cloud and Shadow Word: Death's reaper blade on the foot perches and Silence ready in a ring socket; a main-hand oil socket while an oil is in the bags or on the weapon; and the major cooldowns burning on the rim. Under Frames Inner Fire is one flame burning down with its charges, and every piece keeps its figure or jewel, never an icon. Aura slots, cooldown duration objects and the engine's shown animations draw every piece, so Lua never reads or compares a secret.
local _, ns = ...
local class = UnitClass and select(2, UnitClass("player"))
if class ~= "PRIEST" and class ~= "DRUID" then
	return
end

local K = KstyleUI
local Effects, Medals, Widgets = K.Effects, ns.SlabMedals, K.Widgets
local sin, cos, rad = math.sin, math.cos, math.rad
local IsSecret = Widgets.IsSecret

local INNER_FIRE = { 10952, 10951, 1006, 602, 7128, 588 }
local PENANCE = { 1316995, 1240721, 1240720, 402174 }
local MIND_BLAST = { 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092 }
local SHADOWFIEND, SHADOWFORM, EMBRACE = { 401977 }, { 15473 }, { 15286 }
local PAIN = { 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local SHIELD = { 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }
local RENEW = { 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local MENDING, MENDED = { 1240827, 1240826, 401859 }, { 1240849, 1240848, 401877 }
local WEAVING, PLAGUE = { 15334, 15333, 15332, 15331, 15257 }, { 19280, 19279, 19278, 19277, 19276, 2944 }
local DEATH, SILENCE = { 1309636, 1309635, 1309633, 1309595 }, { 15487 }
local OILS, OILED = { 20744, 20745, 20746, 20747, 20748, 20749, 20750 }, {}
for _, id in ipairs({ 2623, 2624, 2625, 2626, 2627, 2628, 2629, 2685 }) do OILED[id] = true end
local FLAMES, PER, CHARGES, DIM = { 315, 225, 135, 45 }, 5, 20, 0.5
local ORBIT, FLAME, STUD, WELL, PIN, PERCH, FOOT = 54, 26, 12, 10, 4, 30, 22
local FLICKER = { { 1, 0.45, 0.06 }, { 0.45, 0.9, 0.05 }, { 0.9, 0.35, 0.07 }, { 0.35, 1, 0.08 } }

local CAST = {}
for _, id in ipairs(INNER_FIRE) do CAST[id] = true end

local state = {}

local function Fire(parent, spec, level, form)
	if form == "row" then
		return Medals.Figure(parent, { feed = "aura", spells = INNER_FIRE, figure = "trackerFlame", charges = CHARGES, burst = spec.burst, bloom = "jewelHoly" }, level)
	end
	local r = Medals.Rim(parent, { feed = "aura", spells = INNER_FIRE, ambient = "medAmbientPriest", burst = spec.burst, lua = true }, level)
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

local function Ring(piece, anchor, form, _, n)
	if form == "row" then
		Medals.Place(piece, anchor, Medals.Cell(n))
		return n + 1
	end
	Medals.Place(piece, anchor, 0, 0)
	if Medals.Restricted() then
		return n
	end
	for _, seat in ipairs(piece.ring) do
		local a = rad(seat.angle)
		seat:ClearAllPoints()
		seat:SetPoint("CENTER", anchor, "CENTER", Widgets.Snap(anchor, ORBIT * sin(a)), Widgets.Snap(anchor, ORBIT * cos(a)))
	end
	return n
end

local function Shadow()
	return Medals.Known(WEAVING) or Medals.Known(SHADOWFORM)
end

local function Healer(spells)
	return function() return not Shadow() and Medals.Known(spells) end
end

local function ShadowOnly(spells)
	return function() return Shadow() and Medals.Known(spells) end
end

local function Mend(spells, figure, seat, size, bloom)
	return { key = "crestMend", seat = seat, size = size, build = Medals.Figure, known = Healer(spells == MENDED and MENDING or spells),
		feed = "aura", unit = "target", filter = "HELPFUL|PLAYER", spells = spells, figure = figure, bloom = bloom,
		alpha = size > 60 and 0.6 or nil }
end

local function Flood(parent, spec, level, form)
	if form == "row" then
		return Medals.Figure(parent, { feed = "aura", spells = SHADOWFORM, figure = "figureShroud", steady = true, bloom = "schoolShadow" }, level)
	end
	local hub = ns.Slab.hub
	local f = Medals.Piece(parent, level, ns.Slab.RING)
	local tint = f:CreateTexture(nil, "ARTWORK")
	tint:SetTexture(hub.crestPath)
	tint:SetAllPoints(hub.crest)
	tint:SetVertexColor(K.Tokens.Color("schoolShadow"))
	tint:SetAlpha(0.45)
	f.add(Medals.Texture(f, "BACKGROUND", 0, "glow", "schoolShadow", ns.Slab.RING * 1.5, "ADD")):SetAlpha(0.8)
	f.add(Medals.Texture(f, "OVERLAY", 0, "medRuneGlyphs", "schoolShadow", ns.Slab.RING, "ADD"))
	return f
end

local function Oil()
	local item, info = C_Item, C_PaperDollInfo
	for _, id in ipairs(OILS) do
		local n = item and type(item.GetItemCount) == "function" and item.GetItemCount(id)
		if not IsSecret(n) and type(n) == "number" and n > 0 then
			return id
		end
	end
	local on = info and type(info.GetTemporaryEnchantmentInfo) == "function" and info.GetTemporaryEnchantmentInfo(16)
	local id = on and on.enchantID
	return not IsSecret(id) and OILED[id] and OILS[1] or nil
end

local function Motion()
	local r, n = state.fire, state.count
	if not r then
		return
	end
	local resting = ns.Slab.Resting()
	local still, last = resting or not Effects.Allows("ambient"), n ~= nil and n > 0 and n <= PER
	Medals.Still(r, still, last and DIM or 1)
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
	if not (read and state.rank and state.fire and state.fire:IsVisible()) or Medals.Restricted() then
		return nil
	end
	local aura, n = read(state.rank), 0
	if aura then
		n = aura.applications
	end
	return not IsSecret(n) and type(n) == "number" and n or nil
end

local function Count(n)
	if n ~= state.count then
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
	elseif event == nil or event == "UNIT_AURA" then
		if event == nil then
			state.rank = Medals.Known(INNER_FIRE)
		end
		Count(Read())
	end
end

ns.SlabVigil = { Oil = Oil, Ring = Ring }
if class ~= "PRIEST" then
	return
end

ns.SlabTrackers.Register("PRIEST", {
	{ key = "crestInnerFire", seat = "rim", feed = "aura", spells = INNER_FIRE, build = Fire, place = Ring },
	{ key = "crestPenance", seat = { -62, 40 }, size = PERCH, feed = "cooldown", build = Medals.Figure, choices = {
		{ known = Healer(PENANCE), figure = "figureLance", bloom = "jewelHoly" },
		{ known = MIND_BLAST, figure = "figureMindOrb", bloom = "schoolShadow" },
	} },
	{ key = "crestShadowfiend", seat = { 62, 40 }, size = PERCH, build = Medals.Figure, choices = {
		{ forms = { 28 }, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = EMBRACE, figure = "figureFangs", bloom = "plateHostile" },
		{ forms = { 0 }, feed = "aura", spells = SHADOWFORM, figure = "figureShroud", steady = true, bloom = "schoolShadow" },
		{ feed = "cooldown", known = SHADOWFIEND, figure = "figureFiend", bloom = "schoolShadow" },
	} },
	{ key = "crestShadowfiend", seat = "rim", known = SHADOWFORM, choices = { { forms = { 28 }, build = Flood } } },
	{ key = "crestPain", seat = "topGem", build = Medals.Socket, choices = {
		{ feed = "cooldown", known = Healer(MENDING), color = "white" },
		{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = PAIN, color = "schoolShadow" },
	} },
	Mend(SHIELD, "figureDome", { 0, 16 }, 116), Mend(RENEW, "figureRenew", { -30, -60 }, FOOT, "schoolNature"), Mend(MENDED, "figureMending", { 30, -60 }, FOOT, "jewelHoly"),
	{ key = "crestPlague", seat = { -30, -60 }, size = FOOT, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = PLAGUE,
		known = ShadowOnly(PLAGUE), build = Medals.Figure, figure = "figurePlague", bloom = "schoolNature" },
	{ key = "crestDeath", seat = { 30, -60 }, size = FOOT, feed = "cooldown", known = ShadowOnly(DEATH), build = Medals.Figure, figure = "figureReaper",
		bloom = "schoolShadow" },
	{ key = "crestSilence", seat = "lowerLeft", feed = "cooldown", known = SILENCE, color = "schoolShadow", build = Medals.Socket },
	{ key = "crestOil", seat = "lowerRight", feed = "enchant", slot = "MainHand", known = Oil, color = "jewelHoly", build = Medals.Socket },
	{ key = "crestCooldowns", seat = "cooldowns", color = "pipPriestGlow", bloom = "pipPriestGlow", families = {
		{ spells = { 10060 }, sigil = "Infusion" }, { spells = { 14751 }, sigil = "Focus" },
		{ spells = { 586, 9578, 9579, 9592, 10941, 10942 }, sigil = "Veil" }, { spells = { 6346 }, sigil = "Brave" }, { spells = { 2651 }, sigil = "Moon" },
		{ spells = { 13896, 19271, 19273, 19274, 19275 }, sigil = "Feedback" }, { spells = { 1277328, 1277327, 1277326, 1277325, 1277324 }, sigil = "Sacrifice" },
		{ spells = { 1277640, 1277639, 1277638, 1277634, 1277462 }, sigil = "Lifeline" },
	} },
}, {
	figures = true,
	burst = "medBurstPriest",
	update = { "BAG_UPDATE_DELAYED", "WEAPON_ENCHANT_CHANGED" },
	events = { { "UNIT_AURA", "player" }, { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
	paint = Paint,
	motion = Motion,
})
