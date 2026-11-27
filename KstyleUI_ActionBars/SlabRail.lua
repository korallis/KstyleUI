-- SlabRail.lua: every class's crest rail (docs/medallions-effects.md#crest-rail): a class registers its abilities and one list per talent tree, and up to four known abilities of the tree the game names (its long cooldowns first, then its rotation cooldowns in any free seat, or the seats the player picks in the settings) and the on-use trinket stand as forged medals on an arc above the crest (a flat row between the cooldown rows while the centred cast bars show), while the class's other known long cooldowns and the player's racial stand as smaller round medals on a second rail flanking it; a ready medal burns with its sigil's animated Blender aura, the rail's own or the one its sigil publishes (the still sigil, or the spell's own icon, where neither is yet), breathes and is crossed by a glint, a press dips it, bursts and flashes its ring, a buffed one rises to the crown from either rail, where the engine shows the aura's own slot burning with a draining ring, a bead, a last-fifth notch and a countdown, the newest running buff, by your cast or its readable start, owns the crown (handed off by the engine's aura-shown signal), an ended one cools to steel and folds home, a dark sweep and a refilling steel ring count the cooldown under a small steel mark and the medal relights with a flare; the global cooldown flag counts only as a cooldown event reads it, kept for that same cooldown (spell, start and duration), so a rebuild shows an active cooldown steel unless that event named it the global cooldown, and a seat a rebuild could only guess steel, never one already confirmed cooling, relights with no flare; each flare or press claims the crest's one flare as a whole; the seats are chosen afresh only while the crest can be rebuilt, so the other trackers stand down for the medals picked out of lockdown, take back at once the cues of any the rail could not show, and a switched-off rail stays while locked until they can take their cues back; a hidden rail plays nothing, and no aura is read while auras are secret, an unseen buff dated once they read; Calm lights in place with still auras and no lift, burst or breathing, Off shows only lit, cooling and ready, a motion change or hiding stops what is in flight, and Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Effects, Widgets, Tokens = K.Effects, K.Widgets, K.Tokens
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals
local rad = math.rad
local L = K.L

local Rail = {}
ns.SlabRail = Rail

local SEAT, SPARE, CROWN, PITCH, SPARE_PITCH, PEAK, BOW, CROWN_Y = 28, 22, 34, 31, 25, 126, 10, 90
local LOW_Y, LOW_CROWN, SPARE_Y, SPARE_GAP, SPARES, SEATS, GCD = 227, 6, 127, 8, 6, 4, 1.5
local SPARK, LEGS, LANE, LOW_LANE = 4, 3, 8, -22
local SPAN = 2 * PITCH
local SIGIL, ICON, SHADE, PAD, REFILL = 0.86, 0.74, 1.9, 5, 0.6
local BREATH, BREATH_RUN, GLOW, READY_GLOW, READY_RING, READY_RUN, RELIGHT = { 0.1, 0.2 }, 1.2, 1.6, 44 / 28, 34 / 28, 0.3, 0.18
local GLINT, GLINT_RUN, FLASH_RUN, NOTCH, FIFTH, CLAIM_PAD = 6 / 28, 0.18, 0.27, 4, 0.2, 0.05
local MARK, MARK_RISE, MARK_DROP = 0.42, 0.2, 0.2
local DIP, DIP_RUN, BURST, BURST_RUN = 0.86, 0.12, { 0.85, 1.45 }, 0.4
local LIFT_RUN, TURN, POP, POP_RUN, SETTLE_RUN, FOLD_RUN, HOME_RUN = 0.28, 16, 1.29 / 1.21, 0.2, 0.16, 0.35, 0.3
local CASTS = { "unitframes.castbar.player", "unitframes.castbar.target" }
local OWNER, NONE = "ActionBars.SlabRail", {}
local RACIALS = ns.SlabTrackers.RACIALS
local RACIAL = {}
for _, racial in ipairs(RACIALS) do
	RACIAL[racial.key] = true
end
Rail.picked, Rail.held, Rail.spared, Rail.kept = NONE, NONE, NONE, NONE

function Rail.Register(_, data)
	for _, racial in ipairs(RACIALS) do
		data.abilities[racial.key] = data.abilities[racial.key] or racial
	end
	data.abilities.trinket = data.abilities.trinket or { sigil = "Charm" }
	data.second = {}
	for _, key in ipairs(data.overflow or NONE) do
		data.second[key] = true
	end
	Rail.data = data
end

local function Data()
	return Rail.data
end

local function Ability(key)
	local data = Data()
	return data and data.abilities[key]
end

local function Full()
	return Effects.Allows("ambient") and not ns.Slab.Resting()
end

local function Trinket()
	if ns.Config("crestTrinkets") == false or type(GetInventoryItemID) ~= "function" then
		return nil
	end
	local get = C_Item and C_Item.GetItemSpell
	for slot = 13, 14 do
		local item = GetInventoryItemID("player", slot)
		local spell = not IsSecret(item) and item and type(get) == "function" and select(2, get(item))
		if spell and not IsSecret(spell) then
			return slot, spell
		end
	end
end

function Rail.Tree()
	local data = Data()
	local trees = data and data.trees or NONE
	local info = C_SpecializationInfo
	local index = info and type(info.GetSpecialization) == "function" and info.GetSpecialization()
	if not IsSecret(index) and trees[index] then
		return index
	end
	local best, most = nil, 0
	for i in ipairs(info and type(info.GetSpecializationInfo) == "function" and trees or NONE) do
		local points = select(7, info.GetSpecializationInfo(i, false, false))
		if not IsSecret(points) and type(points) == "number" and points > most then
			best, most = i, points
		end
	end
	if best then
		return best
	end
	best, most = 1, 0
	for i, sign in ipairs(data and data.signs or NONE) do
		local n = 0
		for _, spells in ipairs(sign) do
			n = n + (Medals.Known(spells) and 1 or 0)
		end
		if n > most then
			best, most = i, n
		end
	end
	return best
end

local function Learned(key)
	local ability = Ability(key)
	return ability and ability.spells and Medals.Known(ability.spells)
end

local function Taken(data, key)
	local held = data.held and data.held()
	for _, id in ipairs(held and data.abilities[key].spells or NONE) do
		if id == held then
			return true
		end
	end
	return false
end

local function Picked(data)
	local picks, used = {}, {}
	for i = 1, SEATS do
		local key = ns.Config("crestRailSeat" .. i)
		if type(key) == "string" and key ~= "" and not used[key] and data.abilities[key] and key ~= "trinket" and not data.second[key] and Learned(key) and not Taken(data, key) then
			picks[i], used[key] = key, true
		end
	end
	return picks, used
end

local function Order(data)
	local tree = data.trees[Rail.Tree()] or NONE
	local seats, spare, held, used, places = {}, {}, {}, {}, nil
	local function take(key, list)
		if not used[key] and Learned(key) and not Taken(data, key) then
			used[key] = true
			list[#list + 1] = key
		end
	end
	for _, key in ipairs(tree.majors or NONE) do
		take(key, #seats < SEATS and seats or spare)
	end
	local fills, filling = {}, {}
	for _, key in ipairs(tree.fill or NONE) do
		filling[key] = true
		take(key, #seats < SEATS and seats or fills)
	end
	for _, key in ipairs(data.majors) do
		take(key, #seats < SEATS and seats or spare)
	end
	for _, key in ipairs(data.overflow or NONE) do
		take(key, held)
	end
	for _, racial in ipairs(RACIALS) do
		take(racial.key, spare)
	end
	local picks, picked = Picked(data)
	if next(picks) then
		local rest, out = {}, {}
		for _, list in ipairs({ seats, spare }) do
			for _, key in ipairs(list) do
				if not picked[key] then
					rest[#rest + 1] = key
				end
			end
		end
		for _, key in ipairs(fills) do
			if not picked[key] then
				rest[#rest + 1] = key
			end
		end
		local n = 1
		for i = 1, SEATS do
			out[i] = picks[i]
			if not out[i] then
				out[i] = rest[n]
				n = n + 1
			end
		end
		seats, spare, places = {}, {}, {}
		for i = 1, SEATS do
			if out[i] then
				seats[#seats + 1], places[#seats + 1] = out[i], i
			end
		end
		for i = n, #rest do
			local key = rest[i]
			if not filling[key] then
				spare[#spare + 1] = key
			end
		end
	end
	local at = #spare + 1
	for i = #spare, 1, -1 do
		if RACIAL[spare[i]] then
			at = i
		end
	end
	for i, key in ipairs(held) do
		table.insert(spare, at + i - 1, key)
	end
	for i = #spare, SPARES + 1, -1 do
		spare[i] = nil
	end
	return seats, spare, places
end

function Rail.Seats()
	local data = Data()
	if not data then
		return NONE, NONE
	end
	local keys, extra, places = Order(data)
	local seats, spare = {}, {}
	for i, key in ipairs(keys) do
		seats[#seats + 1] = { key = key, spell = Learned(key), place = places and places[i] or i }
	end
	local slot, spell = Trinket()
	if slot then
		seats[#seats + 1] = { key = "trinket", slot = slot, press = spell, place = SEATS + 1 }
	end
	for _, key in ipairs(extra) do
		spare[#spare + 1] = { key = key, spell = Learned(key), small = true }
	end
	return seats, spare
end

function Rail.Choices()
	local out, data, seen = { { value = "", label = L["Tree's choice"] } }, Data(), {}
	local get = C_Spell and C_Spell.GetSpellName
	local function add(key)
		local id = not seen[key] and Learned(key)
		seen[key] = true
		local name = id and type(get) == "function" and get(id)
		if name and not IsSecret(name) then
			out[#out + 1] = { value = key, label = name }
		end
	end
	for _, tree in ipairs(data and data.trees or NONE) do
		for _, key in ipairs(tree.majors or NONE) do
			add(key)
		end
	end
	for _, key in ipairs(data and data.majors or NONE) do
		add(key)
	end
	for _, tree in ipairs(data and data.trees or NONE) do
		for _, key in ipairs(tree.fill or NONE) do
			add(key)
		end
	end
	for _, racial in ipairs(data and RACIALS or NONE) do
		add(racial.key)
	end
	return out
end

local function Named(seats)
	local keys = {}
	for i, at in ipairs(seats) do
		keys[i] = at.key .. (at.slot or "") .. "@" .. (at.place or i)
	end
	return table.concat(keys, ",")
end

function Rail.Pick(form)
	if not Medals.Locked() then
		Rail.form = form
		local was = Named(Rail.picked) .. "|" .. Named(Rail.spared)
		if form == "crest" and ns.Config("crestRail") ~= false then
			Rail.picked, Rail.spared = Rail.Seats()
		else
			Rail.picked, Rail.spared = NONE, NONE
		end
		if Named(Rail.picked) .. "|" .. Named(Rail.spared) ~= was then
			Rail.held, Rail.kept = Rail.picked, Rail.spared
		end
	end
end

function Rail.Known()
	for _, list in ipairs({ Rail.picked, Rail.held, Rail.spared, Rail.kept }) do
		local at = list[1]
		if at then
			return at.spell or at.press
		end
	end
end

function Rail.Holding()
	return (#Rail.held > 0 or #Rail.kept > 0) and Medals.Locked()
end

function Rail.Commit()
	if Medals.Locked() then
		return false
	end
	local r = Rail.piece
	local shown = r and r:IsShown()
	local seats, spare = shown and r.seated or NONE, shown and r.spared or NONE
	local changed = Named(seats) ~= Named(Rail.held) or Named(spare) ~= Named(Rail.kept)
	Rail.held, Rail.kept = seats, spare
	return changed
end

local function Owns(at, spells, slot)
	if slot and at.slot == slot then
		return true
	end
	local ability = Ability(at.key) or NONE
	for _, id in ipairs(spells or NONE) do
		for _, list in ipairs({ ability.spells or NONE, ability.buffs or NONE }) do
			for _, own in ipairs(list) do
				if id == own then
					return true
				end
			end
		end
	end
	return false
end

function Rail.Holds(spells, slot)
	for _, list in ipairs({ Rail.held, Rail.kept }) do
		for _, at in ipairs(list) do
			if Owns(at, spells, slot) then
				return true
			end
		end
	end
	return false
end

local function Grow(g, from, to, run, order)
	return ns.Slab.Grow(g, from, to, run, order)
end

local function Move(g, dx, dy, run, order, smoothing)
	local t = g:CreateAnimation("Translation")
	t:SetOffset(dx, dy)
	t:SetDuration(run)
	t:SetOrder(order)
	t:SetSmoothing(smoothing)
	return t
end

local function Turn(g, degrees, run, order, smoothing)
	local t = g:CreateAnimation("Rotation")
	t:SetDegrees(degrees)
	t:SetDuration(run)
	t:SetOrder(order)
	t:SetSmoothing(smoothing)
	return t
end

local function Mark(piece, parent, layer, sublevel, seat, color, size)
	local sigil = seat.ability.sigil
	if sigil then
		return piece.add(Medals.Texture(parent, layer, sublevel, "sigil" .. sigil, color, size))
	end
	local t = Medals.Round(parent)
	t:SetDrawLayer(layer, sublevel)
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	t:SetTexture(ns.SlabTrackers.Texture(seat.spell))
	t:SetDesaturated(color ~= "white")
	t:SetVertexColor(Tokens.Color(color == "white" and "white" or "steelLit"))
	return piece.add(t, size)
end

local function Face(piece, parent, size, seat)
	piece.add(Medals.Texture(parent, "BACKGROUND", 0, "glow", "black", size * SHADE)):SetAlpha(0.7)
	piece.add(Medals.Texture(parent, "BORDER", 0, "medEnamel", "steel", size))
	if seat then
		Mark(piece, parent, "ARTWORK", -1, seat, seat.ability.sigil and "steel" or "white", size * (seat.ability.sigil and SIGIL or ICON))
	end
	piece.add(Medals.Texture(parent, "OVERLAY", 0, "medRing", "white", size))
end

local function Baked(sigil)
	if not sigil then
		return nil
	end
	local found, _, _, _, _, aura = pcall(Tokens.Texture, "sigil" .. sigil)
	if found and aura then
		local _, _, _, _, span = Tokens.Flipbook(aura)
		return aura, SIGIL * span
	end
end

local function Aura(piece, parent, size, seat)
	local sigil = seat.ability.sigil
	local token, span = Baked(sigil)
	if not token then
		Mark(piece, parent, "ARTWORK", 1, seat, "white", size * (sigil and SIGIL or ICON))
		return { still = false, moving = false, loop = false }
	end
	local still = piece.add(Medals.Texture(parent, "ARTWORK", 1, token, "white", size * span, "ADD"))
	still:SetTexCoord(0, 0.25, 0, 0.25)
	local moving = piece.add(Medals.Texture(parent, "ARTWORK", 1, token, "white", size * span, "ADD"))
	moving:SetAlpha(0)
	return { still = still, moving = moving, loop = Medals.Flip(moving, token, 1) }
end

local function Burning(aura, on)
	if aura.loop then
		aura.still:SetAlpha(on and 0 or 1)
		aura.moving:SetAlpha(on and 1 or 0)
		if not on then
			aura.loop:Stop()
		elseif not aura.loop:IsPlaying() then
			aura.loop:Play()
		end
	end
end

local function Timer(seat, level, texture, color, alpha, units)
	return seat.add(Medals.Timer(seat, level, texture, color, alpha), units)
end

local function Cue(groups, seconds)
	local function stop()
		for _, g in ipairs(groups) do
			g:Stop()
		end
	end
	return function()
		if Medals.Claim(stop, seconds) then
			for _, g in ipairs(groups) do
				g:Stop()
				g:Play()
			end
		end
	end
end

local function Seat(r, at)
	local data = Data()
	local level = r:GetFrameLevel() + 2
	local ability = data.abilities[at.key]
	local size = at.small and SPARE or SEAT
	local seat = Medals.Piece(r, level, size)
	seat.key, seat.ability, seat.size, seat.spell, seat.small = at.key, ability, size, at.spell, at.small
	Face(seat, seat, size, seat)
	seat.lit = Medals.Layer(seat, level + 1)
	seat.glow = seat.add(Medals.Texture(seat.lit, "BACKGROUND", 1, "glow", data.color, size * GLOW, "ADD"))
	seat.glow:SetAlpha(BREATH[1])
	seat.breath = ns.Slab.Group(seat.glow, "BOUNCE")
	ns.Slab.Fade(seat.breath, BREATH[1], BREATH[2], BREATH_RUN)
	seat.add(Medals.Texture(seat.lit, "BORDER", 1, "dot", "black", size * ICON)):SetAlpha(0.55)
	seat.aura = Aura(seat, seat.lit, size, seat)
	seat.relight = ns.Slab.Group(seat.lit)
	ns.Slab.Fade(seat.relight, 0, 1, RELIGHT)
	seat.glint = seat.add(Medals.Texture(seat.lit, "OVERLAY", 2, "diamond", "white", size * GLINT, "ADD"))
	seat.glint:SetPoint("CENTER", seat, "CENTER", -size * 0.4, size * 0.2)
	seat.glint:SetAlpha(0)
	seat.glinting = ns.Slab.Group(seat.glint)
	for order, fade in ipairs({ { 0, 0.9 }, { 0.9, 0 } }) do
		Move(seat.glinting, size * 0.4, -size * 0.2, GLINT_RUN, order, "NONE")
		ns.Slab.Fade(seat.glinting, fade[1], fade[2], GLINT_RUN, order)
	end
	seat.sweep = Timer(seat, level + 3, "dot", "black", 0.7, size * ICON)
	seat.refill = Timer(seat, level + 3, "orbRing", "steel", REFILL, size + PAD)
	seat.refill:SetReverse(true)
	seat.timers = { seat.sweep, seat.refill }
	seat.sweep:SetHideCountdownNumbers(false)
	local count = seat.sweep.GetCountdownFontString and seat.sweep:GetCountdownFontString()
	if count then
		count:ClearAllPoints()
		count:SetPoint("CENTER", seat, "CENTER", 0, -size * MARK_DROP)
	end
	seat.sweep:SetScript("OnCooldownDone", function()
		Rail.Ready(seat)
	end)
	seat.cold = Medals.Layer(seat, level + 4)
	Mark(seat, seat.cold, "ARTWORK", 0, seat, "steelLit", size * MARK):SetPoint("CENTER", seat, "CENTER", 0, size * MARK_RISE)
	seat.cold:SetAlpha(0)
	local flare = Medals.Layer(seat, level + 5)
	seat.flare = { flare = flare }
	for i, part in ipairs({ { "glow", READY_GLOW, 1.3 }, { "medRing", READY_RING, 1.35 } }) do
		local t = seat.add(Medals.Texture(flare, "OVERLAY", i, part[1], i == 1 and data.color or "gilt", size * part[2], "ADD"))
		t:SetAlpha(0)
		local g = ns.Slab.Group(t)
		Grow(g, 1, part[3], READY_RUN)
		ns.Slab.Fade(g, 0.9, 0, READY_RUN)
		seat.flare[i] = g
	end
	seat.burst = seat.add(Medals.Texture(flare, "OVERLAY", 3, data.burst, "white", size * 1.25, "ADD"))
	seat.burst:SetAlpha(0)
	seat.bursting = ns.Slab.Group(seat.burst)
	Grow(seat.bursting, BURST[1], BURST[2], BURST_RUN)
	ns.Slab.Fade(seat.bursting, 1, 0, BURST_RUN)
	seat.ring = seat.add(Medals.Texture(flare, "OVERLAY", 4, "medRing", "gilt", size, "ADD"))
	seat.ring:SetAlpha(0)
	seat.flash = ns.Slab.Group(seat.ring)
	ns.Slab.Fade(seat.flash, 1, 0, FLASH_RUN)
	seat.dip = ns.Slab.Group(seat)
	Grow(seat.dip, 1, DIP, DIP_RUN, 1)
	Grow(seat.dip, 1, 1 / DIP, DIP_RUN, 2)
	seat.welcome = Cue({ seat.flare[1], seat.flare[2], seat.glinting }, 2 * GLINT_RUN + CLAIM_PAD)
	seat.struck = Cue({ seat.bursting, seat.dip, seat.flash }, BURST_RUN + CLAIM_PAD)
	return seat
end

local function Has(list, seat)
	for _, each in ipairs(list) do
		if each == seat then
			return true
		end
	end
	return false
end

local function Stamp(r, seat)
	return r.stamps[seat] or -math.huge
end

local function Running(r, seat, on)
	for i = #r.running, 1, -1 do
		if r.running[i] == seat then
			table.remove(r.running, i)
		end
	end
	if on then
		local at = #r.running
		while at > 0 and Stamp(r, r.running[at]) > Stamp(r, seat) do
			at = at - 1
		end
		table.insert(r.running, at + 1, seat)
	else
		r.stamps[seat] = nil
	end
end

local function Buffs(ability)
	return ability.buffs or ability.spells
end

local function Started(seat)
	local get = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	for _, id in ipairs(type(get) == "function" and not Medals.Restricted() and Buffs(seat.ability) or NONE) do
		local a = get(seat.ability.unit, id)
		local ends, length = not IsSecret(a) and type(a) == "table" and a.expirationTime, not IsSecret(a) and type(a) == "table" and a.duration
		if not (IsSecret(ends) or IsSecret(length)) and type(ends) == "number" and type(length) == "number" and length > 0 then
			return ends - length
		end
	end
end

local function Crown(r)
	local up, full = Effects.Allows("flare"), r:IsVisible() and Full()
	local owner
	for i = #r.running, 1, -1 do
		owner = owner or r.running[i]:IsShown() and r.running[i] or nil
	end
	local top = r.rising or owner
	for _, seat in ipairs(r.majors) do
		seat.gate:SetAlpha(up and seat:IsShown() and (top == nil or seat == top) and 1 or 0)
		seat.hold:SetAlpha(up and 1 or 0)
		local crowned = seat == top
		seat.burn:SetAlpha(crowned and 1 or 0)
		Burning(seat.crowned.aura, full and crowned)
	end
	local was = r.owner
	r.owner = owner
	if was and was ~= owner and not Has(r.running, was) and full and was:IsVisible() then
		was.home:Stop()
		was.home:Play()
	end
end

function Rail.Fold(r, seat)
	Running(r, seat, false)
	Crown(r)
end

local function Major(r, seat, ability)
	local data = Data()
	local size = seat.size
	local level = seat:GetFrameLevel() + 6
	local spec = { feed = "aura", unit = ability.unit, filter = "HELPFUL", spells = Buffs(ability) }
	local slot = Medals.Lit(seat, spec, level)
	seat.hold = slot.hold
	seat.hold.add = seat.add
	seat.add(Medals.Texture(slot, "ARTWORK", 0, "dot", "black", size)):SetAlpha(0.75)
	slot.timer = seat.add(Medals.Timer(slot, level + 1, "orbRing", data.color), size + PAD)
	slot:SetDurationCooldown(slot.timer)
	seat.add(Medals.Ember(seat.hold, slot, slot.timer, "Band", level + 2, size))
	r.lits[#r.lits + 1] = slot
	local crown = r.crown
	local top = crown:GetFrameLevel() + 2
	seat.gate = Medals.Layer(crown, top)
	seat.lift = Medals.Layer(seat.gate, top)
	seat.lift.add = crown.add
	local lit = Medals.Feed(seat.lift, spec, top)
	lit.hold = seat.gate
	Face(crown, lit, CROWN)
	seat.burn = Medals.Layer(seat.lift, top + 2)
	lit.aura = Aura(crown, seat.burn, CROWN, seat)
	lit.timer = crown.add(Medals.Timer(lit, top + 3, "orbRing", data.color), CROWN + PAD)
	local turned = lit.timer.SetRotation ~= nil and pcall(lit.timer.SetRotation, lit.timer, rad(90))
	ns.SlabRings.Head(lit.timer, 1.4)
	lit.timer:SetHideCountdownNumbers(false)
	local tag = lit.timer.GetCountdownFontString and lit.timer:GetCountdownFontString()
	if tag then
		tag:ClearAllPoints()
		tag:SetPoint("TOP", lit.timer, "BOTTOM", 0, -1)
	end
	lit:SetDurationCooldown(lit.timer)
	lit.timer:SetScript("OnCooldownDone", function()
		Rail.Fold(r, seat)
	end)
	local at = rad((turned and 270 or 0) + 360 * (1 - FIFTH))
	local notch = crown.add(Medals.Texture(lit, "OVERLAY", 2, "diamond", "gilt", NOTCH))
	notch:SetPoint("CENTER", lit, "CENTER", (CROWN + PAD) / 2 * math.sin(at), (CROWN + PAD) / 2 * math.cos(at))
	crown.add(Medals.Ember(seat.lift, lit, lit.timer, "Band", top + 4, CROWN))
	local mark = crown.add(Medals.Texture(lit, "BACKGROUND", 0, "dot", "black", 1))
	mark:SetAlpha(0)
	local signal = ns.Slab.Group(mark, "REPEAT")
	ns.Slab.Fade(signal, 0, 0, 3600)
	signal:SetScript("OnPlay", function()
		if not Has(r.running, seat) then
			r.stamps[seat] = r.stamps[seat] or Started(seat)
			Running(r, seat, true)
		end
		if r.rising == seat then
			r.rising = nil
		end
		Crown(r)
	end)
	signal:SetScript("OnStop", function()
		Rail.Fold(r, seat)
	end)
	lit:AddAuraShownAnimation(signal)
	seat.signal = signal
	r.lits[#r.lits + 1] = lit
	seat.crowned = lit
	seat.ghost = Medals.Layer(crown, top)
	Mark(crown, seat.ghost, "ARTWORK", 0, seat, "steel", CROWN * (ability.sigil and SIGIL or ICON))
	seat.ghost:SetAlpha(0)
	seat.rise = ns.Slab.Group(seat.lift)
	local from, spark, legs = size * DIP / CROWN, SPARK / CROWN, seat.small and LEGS or 1
	local run, first = LIFT_RUN / legs, seat.small and 3 or 2
	local last = first + legs - 1
	seat.out = Move(seat.rise, 0, 0, 0.001, 1, "NONE")
	Grow(seat.rise, from, from, 0.001, 1)
	seat.base = seat.small and spark or from
	if seat.small then
		Grow(seat.rise, 1, spark / from, run, 2)
	end
	seat.legs = {}
	for i = 1, legs do
		seat.legs[i] = Move(seat.rise, 0, 0, run, first + i - 1, i == legs and "OUT" or "IN_OUT")
	end
	local land = seat.small and last + 1 or last
	seat.pop = Grow(seat.rise, 1, POP / seat.base, POP_RUN, land)
	seat.turns = { Turn(seat.rise, TURN, seat.small and POP_RUN or run, land, "OUT") }
	seat.settle = Grow(seat.rise, 1, 1 / POP, SETTLE_RUN, land + 1)
	seat.turns[2] = Turn(seat.rise, -TURN, SETTLE_RUN, land + 1, "IN_OUT")
	seat.rise:SetScript("OnFinished", function()
		if r.rising == seat then
			r.rising = nil
			Crown(r)
		end
	end)
	seat.home = ns.Slab.Group(seat.ghost)
	ns.Slab.Fade(seat.home, 1, 1, FOLD_RUN, 1)
	run = HOME_RUN / legs
	if seat.small then
		Grow(seat.home, 1, spark, run, 2)
	end
	seat.trail = {}
	for i = 1, legs do
		seat.trail[i] = Move(seat.home, 0, 0, run, first + i - 1, "IN_OUT")
	end
	Grow(seat.home, 1, size / CROWN / (seat.small and spark or 1), run, land)
	ns.Slab.Fade(seat.home, 1, 0, run, land)
	r.majors[#r.majors + 1] = seat
end

local function Aim(r, seat)
	local _, _, _, sx, sy = seat:GetPoint(1)
	local _, _, _, cx, cy = r.crown:GetPoint(1)
	local dx, dy = (sx or 0) - (cx or 0), (sy or 0) - (cy or 0)
	if seat.aim and seat.aim[1] == dx and seat.aim[2] == dy and seat.aim[3] == r.low then
		return
	end
	seat.aim = { dx, dy, r.low }
	seat.out:SetOffset(dx, dy)
	if seat.small then
		local lane = r.low and LOW_LANE or LANE
		seat.legs[1]:SetOffset(0, lane - dy)
		seat.legs[2]:SetOffset(-dx, 0)
		seat.legs[3]:SetOffset(0, -lane)
		seat.trail[1]:SetOffset(0, lane)
		seat.trail[2]:SetOffset(dx, 0)
		seat.trail[3]:SetOffset(0, dy - lane)
	else
		seat.legs[1]:SetOffset(-dx, -dy)
		seat.trail[1]:SetOffset(dx, dy)
	end
	local pop, turn = r.low and 1 or POP, r.low and 0 or TURN
	seat.pop:SetScaleTo(pop / seat.base, pop / seat.base)
	seat.settle:SetScaleTo(1 / pop, 1 / pop)
	seat.turns[1]:SetDegrees(turn)
	seat.turns[2]:SetDegrees(-turn)
end

local function Quiet(r, seat, calm)
	seat.burning = nil
	for _, g in ipairs({ seat.dip, seat.bursting, seat.flash, seat.glinting, seat.flare[1], seat.flare[2], seat.breath, seat.rise or false, seat.home or false }) do
		if g then
			g:Stop()
		end
	end
	if not calm then
		seat.relight:Stop()
	end
	for _, aura in ipairs({ seat.aura, seat.crowned and seat.crowned.aura or false }) do
		if aura then
			Burning(aura, false)
		end
	end
	if r.rising == seat then
		r.rising = nil
	end
end

local function Settle(r, all)
	if all or not Full() then
		local calm = not all and Effects.Allows("flare")
		for _, seat in pairs(r.made) do
			Quiet(r, seat, calm)
		end
	end
end

local function Light(seat, ready, flare, full, calm)
	local was = seat.ready
	seat.ready = ready
	if ready ~= was then
		seat.relight:Stop()
		seat.lit:SetAlpha(ready and 1 or 0)
		seat.cold:SetAlpha(ready and 0 or 1)
	end
	if ready and was == false and flare and calm then
		seat.relight:Play()
		if full then
			seat.welcome()
		end
	end
	local burning = ready and full or false
	if burning ~= seat.burning or burning and not seat.breath:IsPlaying() then
		seat.burning = burning
		Burning(seat.aura, burning)
		if burning then
			seat.breath:Play()
		else
			seat.breath:Stop()
		end
	end
end

local function Mood(r)
	local shown = r:IsVisible()
	return shown and Full() or false, shown and Effects.Allows("flare") or false
end

function Rail.Ready(seat)
	if seat.ready == false then
		Light(seat, true, true, Mood(seat))
	end
end

local function Stored(seat)
	if seat.slot then
		if type(GetInventoryItemCooldown) == "function" then
			return GetInventoryItemCooldown("player", seat.slot)
		end
		return 0, 0, 0
	end
	local get = C_Item and C_Item.GetItemCooldown
	local start, length, enable = 0, 0, false
	for _, id in ipairs(type(get) == "function" and seat.ability.items or NONE) do
		start, length, enable = get(id)
		if IsSecret(length) or type(length) == "number" and length > GCD then
			break
		end
	end
	return start, length, enable, not IsSecret(length) and type(length) == "number" and length <= GCD
end

local function Cool(seat, event, full, calm)
	local cooling, guess
	if seat.item then
		local start, length, enable, gcd = Stored(seat)
		if IsSecret(start) or IsSecret(length) or IsSecret(enable) or IsSecret(gcd) then
			return
		end
		cooling = type(length) == "number" and length > 0 and enable ~= 0 and enable ~= false and gcd ~= true
		for _, t in ipairs(seat.timers) do
			if cooling then
				t:SetCooldown(start, length)
			else
				t:Clear()
			end
		end
	else
		local api = C_Spell
		local duration = api and type(api.GetSpellCooldownDuration) == "function" and api.GetSpellCooldownDuration(seat.spell, true)
		for _, t in ipairs(seat.timers) do
			if duration and t.SetCooldownFromDurationObject then
				t:SetCooldownFromDurationObject(duration, true)
			else
				t:Clear()
			end
		end
		local cd = api and type(api.GetSpellCooldown) == "function" and api.GetSpellCooldown(seat.spell)
		local active = type(cd) == "table" and cd.isActive
		if IsSecret(active) then
			cooling, guess = seat.ready == false, seat.guess
		elseif active ~= true then
			cooling = false
		else
			local start, length = cd.startTime, cd.duration
			local plain = not IsSecret(start) and not IsSecret(length)
			if event == "SPELL_UPDATE_COOLDOWN" then
				local gcd = cd.isOnGCD
				if IsSecret(gcd) then
					cooling, guess, seat.heardSpell = seat.ready == false, seat.guess, nil
				else
					cooling = gcd ~= true
					if plain and type(start) == "number" and type(length) == "number" then
						seat.heardSpell, seat.heardStart, seat.heardLength, seat.heardCooling = seat.spell, start, length, cooling
					else
						seat.heardSpell = nil
					end
				end
			elseif plain and seat.heardSpell == seat.spell and seat.heardStart == start and seat.heardLength == length then
				cooling = seat.heardCooling
			else
				cooling, guess = true, seat.ready ~= false or seat.guess
			end
		end
	end
	Light(seat, not cooling, event ~= nil and not seat.guess, full, calm)
	seat.guess = guess
end

local function Press(r, seat)
	local full = Full()
	if full then
		seat.struck()
	end
	if seat.crowned then
		r.stamps[seat] = type(GetTime) == "function" and GetTime() or nil
		if Has(r.running, seat) then
			Running(r, seat, true)
		end
		if full then
			r.rising = seat
			seat.home:Stop()
			seat.rise:Stop()
			seat.rise:Play()
		end
		Crown(r)
	end
end

local function Low()
	local Layout = K.Layout
	return Layout ~= nil and type(Layout.Live) == "function" and (Layout.Live(CASTS[1]) or Layout.Live(CASTS[2])) or false
end

function Rail.Build(parent, spec, level)
	local r = Medals.Piece(parent, level, 2 * (SPAN + SEAT))
	r.rail, r.order, r.spare, r.all, r.made, r.majors, r.running, r.stamps = true, {}, {}, {}, {}, {}, {}, {}
	r.crown = Medals.Piece(r, level + 12, CROWN)
	r.add(r.crown)
	r.spec = spec
	Rail.piece = r
	r:SetScript("OnHide", function()
		Settle(r, true)
	end)
	K.Callbacks.Register("LayoutChanged", OWNER, function(_, key)
		if (key == CASTS[1] or key == CASTS[2]) and r.anchor and r:IsVisible() and r.low ~= Low() and not Medals.Locked() then
			Rail.Place(r, r.anchor)
		end
	end)
	return r
end

local function Made(r, at)
	local name = at.key .. (at.small and "+" or "")
	local seat = r.made[name]
	if not seat then
		seat = Seat(r, at)
		r.made[name] = seat
		if seat.ability.unit then
			Major(r, seat, seat.ability)
		end
	end
	seat.spell, seat.slot, seat.press = at.spell, at.slot, at.press
	seat.item = at.slot ~= nil or seat.ability.items ~= nil
	return seat
end

local function Flank(i, n, low)
	local side, step = i % 2 == 1 and -1 or 1, math.floor((i - 1) / 2)
	local edge
	if low then
		edge = side < 0 and n / 2 * PITCH + LOW_CROWN + CROWN / 2 or n / 2 * PITCH + SEAT / 2
	else
		edge = (n - 1) / 2 * PITCH + SEAT / 2
	end
	local x = side * (edge + SPARE_GAP + SPARE / 2 + step * SPARE_PITCH)
	return x, low and LOW_Y or SPARE_Y
end

function Rail.Place(r, anchor)
	r.anchor = anchor
	Medals.Place(r, anchor, 0, 0)
	if Medals.Locked() then
		return
	end
	local seats, spare, low = Rail.picked, Rail.spared, Low()
	r.order, r.spare, r.all, r.low = {}, {}, {}, low
	for _, seat in pairs(r.made) do
		seat:Hide()
	end
	local n = math.max(seats[#seats] and seats[#seats].place or #seats, 1)
	Medals.Place(r.crown, r, low and -n / 2 * PITCH - LOW_CROWN or 0, low and LOW_Y or CROWN_Y)
	for i, at in ipairs(seats) do
		local seat = Made(r, at)
		local p = at.place or i
		local x = low and (p - n / 2) * PITCH or (p - (n + 1) / 2) * PITCH
		Medals.Place(seat, r, x, low and LOW_Y or PEAK - BOW * (x / SPAN) ^ 2)
		r.order[i] = seat
	end
	for i, at in ipairs(spare) do
		local seat = Made(r, at)
		Medals.Place(seat, r, Flank(i, n, low))
		r.spare[i] = seat
	end
	for _, list in ipairs({ r.order, r.spare }) do
		for _, seat in ipairs(list) do
			seat:Show()
			r.all[#r.all + 1] = seat
			if seat.crowned then
				Aim(r, seat)
			end
		end
	end
	for _, seat in pairs(r.made) do
		if not seat:IsShown() then
			Quiet(r, seat)
			Running(r, seat, false)
		end
	end
	r.seated, r.spared = seats, spare
	r.crown.sized = nil
	Medals.Size(r.crown)
	Rail.Paint(r)
end

local function Pressed(seat, spell)
	if seat.press == spell then
		return true
	end
	for _, id in ipairs(seat.ability.casts or seat.ability.spells or NONE) do
		if id == spell then
			return true
		end
	end
	return false
end

function Rail.Paint(r, event, _, _, spell)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if IsSecret(spell) then
			return
		end
		for _, seat in ipairs(r.all) do
			if Pressed(seat, spell) then
				return Press(r, seat)
			end
		end
	elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
		local item, full, calm = event == "BAG_UPDATE_COOLDOWN", Mood(r)
		for _, seat in ipairs(r.all) do
			if seat.item == item then
				Cool(seat, event, full, calm)
			end
		end
	elseif event == nil then
		Settle(r)
		local full, calm = Mood(r)
		for _, seat in ipairs(r.all) do
			Cool(seat, nil, full, calm)
		end
		for _, seat in ipairs({ unpack(r.running) }) do
			r.stamps[seat] = r.stamps[seat] or Started(seat)
			Running(r, seat, true)
		end
		Crown(r)
	end
end
