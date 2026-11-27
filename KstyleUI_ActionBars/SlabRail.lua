-- SlabRail.lua: the hunter's five-seat crest rail (docs/medallions-effects.md#hunter-crest-rail): up to four of the talent tree's own abilities and the on-use trinket stand as forged medals on an arc above the crest, built only for the seats the hunter knows; a ready medal lights gold and breathes, a press dips it and bursts, a buffed major lifts a medal to the crown that the engine shows from the aura's own slot while the seat's ring drains, the medal cools to steel and folds back to its seat as the buff ends, a dark sweep and a refilling steel ring count the cooldown and the medal relights with a flare when it is ready again; Calm lights in place with no lift, burst or breathing, Off shows only lit, cooling and ready, and Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Effects, Widgets = K.Effects, K.Widgets
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals

local Rail = {}
ns.SlabRail = Rail

local SEAT, CROWN, PITCH, PEAK, BOW, CROWN_Y = 28, 34, 31, 126, 10, 90
local SPAN = 2 * PITCH
local SIGIL, ICON, SHADE, PAD, REFILL = 0.86, 0.74, 1.9, 5, 0.6
local BREATH, BREATH_RUN, GLOW, READY_GLOW, READY_RING, READY_RUN, RELIGHT = { 0.1, 0.2 }, 1.2, 1.6, 44, 34, 0.3, 0.18
local DIP, DIP_RUN, BURST, BURST_RUN = 0.86, 0.12, { 0.85, 1.45 }, 0.4
local LIFT_RUN, TURN, POP, POP_RUN, SETTLE_RUN, FOLD_RUN, HOME_RUN = 0.28, 16, 1.29 / 1.21, 0.2, 0.16, 0.35, 0.3
local FIRE_TRAP = { 13795, 14302, 14303, 14304, 14305, 13813, 14316, 14317 }
local ABILITIES = {
	rapid = { spells = { 3045 }, sigil = "Volley", unit = "player" },
	wrath = { spells = { 19574 }, sigil = "Paw", unit = "pet" },
	deter = { spells = { 19263 }, sigil = "Deflect", unit = "player" },
	intimidate = { spells = { 19577 }, sigil = "Intimidate" },
	trap = { spells = FIRE_TRAP, sigil = "FireTrap" },
	sniper = { spells = { 1310786, 1310785, 1310687 }, sigil = "Sniper" },
	aimed = { spells = { 20904, 20903, 20902, 20901, 20900, 19434 }, sigil = "Aimed" },
	strider = { spells = { 1317257 }, sigil = "Strider" },
}
local TREES = {
	{ "wrath", "rapid", "intimidate", "trap" },
	{ "rapid", "trap", "sniper", "aimed" },
	{ "rapid", "deter", "trap", "strider" },
}
local SIGNS = { { "wrath", "intimidate" }, { "sniper", "aimed" }, { "deter", "strider" } }
Rail.ABILITIES, Rail.TREES = ABILITIES, TREES

local function Trinket()
	if ns.Config("crestTrinkets") == false or type(GetInventoryItemID) ~= "function" then
		return nil
	end
	local get = C_Item and C_Item.GetItemSpell
	for slot = 13, 14 do
		local item = GetInventoryItemID("player", slot)
		local spell = not IsSecret(item) and item and type(get) == "function" and select(2, get(item))
		if spell and not IsSecret(spell) then
			return slot
		end
	end
end

function Rail.Seats()
	local best, most = 1, 0
	for i, sign in ipairs(SIGNS) do
		local n = 0
		for _, key in ipairs(sign) do
			n = n + (Medals.Known(ABILITIES[key].spells) and 1 or 0)
		end
		if n > most then
			best, most = i, n
		end
	end
	local seats = {}
	for _, key in ipairs(TREES[best]) do
		local id = Medals.Known(ABILITIES[key].spells)
		if id then
			seats[#seats + 1] = { key = key, spell = id }
		end
	end
	local slot = Trinket()
	if slot then
		seats[#seats + 1] = { key = "trinket", slot = slot }
	end
	return seats
end

function Rail.Known()
	return #Rail.Seats() > 0 and 3045 or nil
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

local function Face(piece, parent, size, art, gold, level)
	piece.add(Medals.Texture(parent, "BACKGROUND", 0, "glow", "black", size * SHADE)):SetAlpha(0.7)
	piece.add(Medals.Texture(parent, "BORDER", 0, "medEnamel", "steel", size))
	if gold then
		Medals.Mark(piece, parent, art, size * SIGIL, "jewelHawk", nil, nil, nil, level)
	else
		piece.add(Medals.Texture(parent, "ARTWORK", -1, art, "steel", size * SIGIL))
	end
	piece.add(Medals.Texture(parent, "OVERLAY", 0, "medRing", "white", size))
end

local function Timer(seat, level, texture, color, alpha, units)
	return seat.add(Medals.Timer(seat, level, texture, color, alpha), units)
end

local function Seat(r, at)
	local level = r:GetFrameLevel() + 2
	local seat = Medals.Piece(r, level, SEAT)
	local art = "sigil" .. (ABILITIES[at.key] and ABILITIES[at.key].sigil or "Charm")
	seat.key, seat.ability = at.key, ABILITIES[at.key]
	Face(seat, seat, SEAT, art, false)
	seat.lit = Medals.Layer(seat, level + 1)
	seat.glow = seat.add(Medals.Texture(seat.lit, "BACKGROUND", 1, "glow", "jewelHawk", SEAT * GLOW, "ADD"))
	seat.glow:SetAlpha(BREATH[1])
	seat.breath = ns.Slab.Group(seat.glow, "BOUNCE")
	ns.Slab.Fade(seat.breath, BREATH[1], BREATH[2], BREATH_RUN)
	Medals.Mark(seat, seat.lit, art, SEAT * SIGIL, "jewelHawk", nil, nil, nil, level + 1)
	seat.relight = ns.Slab.Group(seat.lit)
	ns.Slab.Fade(seat.relight, 0, 1, RELIGHT)
	seat.sweep = Timer(seat, level + 3, "dot", "black", 0.7, SEAT * ICON)
	seat.refill = Timer(seat, level + 3, "orbRing", "steel", REFILL, SEAT + PAD)
	seat.refill:SetReverse(true)
	seat.sweep:SetHideCountdownNumbers(false)
	seat.sweep:SetScript("OnCooldownDone", function()
		Rail.Ready(seat)
	end)
	local flare = Medals.Layer(seat, level + 4)
	seat.flare = { flare = flare }
	for i, part in ipairs({ { "glow", READY_GLOW, 1.3 }, { "medRing", READY_RING, 1.35 } }) do
		local t = seat.add(Medals.Texture(flare, "OVERLAY", i, part[1], i == 1 and "jewelHawk" or "gilt", part[2], "ADD"))
		t:SetAlpha(0)
		local g = ns.Slab.Group(t)
		Grow(g, 1, part[3], READY_RUN)
		ns.Slab.Fade(g, 0.9, 0, READY_RUN)
		seat.flare[i] = g
	end
	seat.burst = seat.add(Medals.Texture(flare, "OVERLAY", 3, "medBurstHunter", "white", SEAT * 1.25, "ADD"))
	seat.burst:SetAlpha(0)
	seat.bursting = ns.Slab.Group(seat.burst)
	Grow(seat.bursting, BURST[1], BURST[2], BURST_RUN)
	ns.Slab.Fade(seat.bursting, 1, 0, BURST_RUN)
	seat.dip = ns.Slab.Group(seat)
	Grow(seat.dip, 1, DIP, DIP_RUN, 1)
	Grow(seat.dip, DIP, 1, DIP_RUN, 2)
	return seat
end

local function Major(r, seat, ability)
	local level = seat:GetFrameLevel() + 6
	local spec = { feed = "aura", unit = ability.unit, filter = "HELPFUL", spells = ability.spells }
	local slot = Medals.Lit(seat, spec, level)
	seat.hold = slot.hold
	seat.add(Medals.Texture(slot, "ARTWORK", 0, "dot", "black", SEAT)):SetAlpha(0.75)
	slot.timer = seat.add(Medals.Timer(slot, level + 1, "orbRing", "jewelHawk"), SEAT + PAD)
	slot:SetDurationCooldown(slot.timer)
	seat.add(Medals.Ember(seat, slot, slot.timer, "Band", level + 2, SEAT))
	r.lits[#r.lits + 1] = slot
	local crown = r.crown
	local top = crown:GetFrameLevel() + 2
	seat.gate = Medals.Layer(crown, top)
	seat.lift = Medals.Layer(seat.gate, top)
	local lit = Medals.Feed(seat.lift, spec, top)
	lit.hold = seat.gate
	Face(crown, lit, CROWN, "sigil" .. ability.sigil, true, top + 1)
	lit.timer = crown.add(Medals.Timer(lit, top + 3, "orbRing", "jewelHawk"), CROWN + PAD)
	lit:SetDurationCooldown(lit.timer)
	lit.timer:SetScript("OnCooldownDone", function()
		Rail.Fold(r, seat)
	end)
	r.lits[#r.lits + 1] = lit
	seat.crowned = lit
	seat.ghost = Medals.Layer(crown, top)
	crown.add(Medals.Texture(seat.ghost, "ARTWORK", 0, "sigil" .. ability.sigil, "steel", CROWN * SIGIL))
	seat.ghost:SetAlpha(0)
end

local function Aim(seat, crown)
	local _, _, _, sx, sy = seat:GetPoint(1)
	local _, _, _, cx, cy = crown:GetPoint(1)
	return (sx or 0) - (cx or 0), (sy or 0) - (cy or 0)
end

local function Motions(r, seat)
	local dx, dy = Aim(seat, r.crown)
	if seat.aim and seat.aim[1] == dx and seat.aim[2] == dy then
		return
	end
	seat.aim = { dx, dy }
	local from = SEAT * DIP / CROWN
	seat.rise = ns.Slab.Group(seat.lift)
	Move(seat.rise, dx, dy, 0.001, 1, "NONE")
	Grow(seat.rise, from, from, 0.001, 1)
	Move(seat.rise, -dx, -dy, LIFT_RUN, 2, "OUT")
	Grow(seat.rise, from, POP, POP_RUN, 2)
	Turn(seat.rise, TURN, LIFT_RUN, 2, "OUT")
	Grow(seat.rise, POP, 1, SETTLE_RUN, 3)
	Turn(seat.rise, -TURN, SETTLE_RUN, 3, "IN_OUT")
	seat.home = ns.Slab.Group(seat.ghost)
	ns.Slab.Fade(seat.home, 1, 1, FOLD_RUN, 1)
	Move(seat.home, dx, dy, HOME_RUN, 2, "IN_OUT")
	Grow(seat.home, 1, SEAT / CROWN, HOME_RUN, 2)
	ns.Slab.Fade(seat.home, 1, 0, HOME_RUN, 2)
end

function Rail.Build(parent, spec, level)
	local r = Medals.Piece(parent, level, 2 * (SPAN + SEAT))
	r.rail, r.order, r.made = true, {}, {}
	r.crown = Medals.Piece(r, level + 12, CROWN)
	r.add(r.crown)
	r.spec = spec
	return r
end

local function Light(seat, ready, flare)
	local was = seat.ready
	seat.ready = ready
	local full, calm = Effects.Allows("ambient") and not ns.Slab.Resting(), Effects.Allows("flare")
	seat.relight:Stop()
	seat.lit:SetAlpha(ready and 1 or 0)
	if ready and was == false and flare and calm then
		seat.relight:Play()
		for i = 1, full and 2 or 0 do
			seat.flare[i]:Stop()
			seat.flare[i]:Play()
		end
	end
	if ready and full then
		if not seat.breath:IsPlaying() then
			seat.breath:Play()
		end
	else
		seat.breath:Stop()
	end
end

function Rail.Ready(seat)
	if seat.ready == false then
		Light(seat, true, true)
	end
end

local function Cool(seat)
	local cooling
	if seat.slot then
		local start, length, enable = 0, 0, 0
		if type(GetInventoryItemCooldown) == "function" then
			start, length, enable = GetInventoryItemCooldown("player", seat.slot)
		end
		cooling = not (IsSecret(start) or IsSecret(length) or IsSecret(enable)) and type(length) == "number" and length > 0 and enable ~= 0
		for _, t in ipairs({ seat.sweep, seat.refill }) do
			if cooling then
				t:SetCooldown(start, length)
			else
				t:Clear()
			end
		end
	else
		local api = C_Spell
		local duration = api and type(api.GetSpellCooldownDuration) == "function" and api.GetSpellCooldownDuration(seat.spell, true)
		for _, t in ipairs({ seat.sweep, seat.refill }) do
			if duration and t.SetCooldownFromDurationObject then
				t:SetCooldownFromDurationObject(duration, true)
			else
				t:Clear()
			end
		end
		local cd = api and type(api.GetSpellCooldown) == "function" and api.GetSpellCooldown(seat.spell)
		local active, gcd = type(cd) == "table" and cd.isActive, type(cd) == "table" and cd.isOnGCD
		if IsSecret(active) or IsSecret(gcd) then
			cooling = seat.ready == false
		else
			cooling = active == true and gcd ~= true
		end
	end
	Light(seat, not cooling, false)
end

local function Crown(r)
	local up = Effects.Allows("flare")
	local owner = r.owner
	if not (owner and owner:IsShown()) then
		owner = nil
		for _, seat in ipairs(r.order) do
			owner = owner or seat.crowned and seat:IsShown() and seat or nil
		end
	end
	for _, seat in pairs(r.made) do
		if seat.crowned then
			seat.gate:SetAlpha(up and seat == owner and 1 or 0)
			seat.hold:SetAlpha(up and 1 or 0)
		end
	end
	return owner
end

local function Press(r, seat)
	local full = Effects.Allows("ambient") and not ns.Slab.Resting()
	if full then
		seat.dip:Stop()
		seat.dip:Play()
		seat.bursting:Stop()
		seat.bursting:Play()
	end
	if seat.crowned then
		r.owner = seat
		Crown(r)
		if full then
			Motions(r, seat)
			seat.home:Stop()
			seat.ghost:SetAlpha(0)
			seat.rise:Stop()
			seat.rise:Play()
		end
	end
end

function Rail.Fold(r, seat)
	if r.owner == seat and Effects.Allows("ambient") and not ns.Slab.Resting() and seat.home then
		seat.home:Stop()
		seat.home:Play()
	end
end

function Rail.Place(r, anchor)
	Medals.Place(r, anchor, 0, 0)
	if Medals.Locked() then
		return
	end
	local seats = Rail.Seats()
	r.order = {}
	for _, seat in pairs(r.made) do
		seat:Hide()
	end
	Medals.Place(r.crown, r, 0, CROWN_Y)
	for i, at in ipairs(seats) do
		local seat = r.made[at.key]
		if not seat then
			seat = Seat(r, at)
			r.made[at.key] = seat
			if seat.ability and seat.ability.unit then
				Major(r, seat, seat.ability)
			end
		end
		seat.spell, seat.slot = at.spell, at.slot
		local x = (i - (#seats + 1) / 2) * PITCH
		Medals.Place(seat, r, x, PEAK - BOW * (x / SPAN) ^ 2)
		seat:Show()
		r.order[i] = seat
	end
	for _, seat in pairs(r.made) do
		seat.aim = nil
	end
	r.crown.sized = nil
	Medals.Size(r.crown)
	Rail.Paint(r)
end

function Rail.Paint(r, event, _, _, spell)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if IsSecret(spell) then
			return
		end
		for _, seat in ipairs(r.order) do
			for _, id in ipairs(seat.ability and seat.ability.spells or {}) do
				if id == spell then
					return Press(r, seat)
				end
			end
		end
		return
	end
	for _, seat in ipairs(r.order) do
		Cool(seat)
	end
	Crown(r)
end
