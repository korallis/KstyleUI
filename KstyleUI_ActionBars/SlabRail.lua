-- SlabRail.lua: the hunter's five-seat crest rail (docs/medallions-effects.md#hunter-crest-rail): up to four abilities of the talent tree the game names and the on-use trinket stand as forged medals on an arc above the crest (a flat row between the cooldown rows while the centred cast bars show), built only for the seats the hunter has; a ready seat burns with its sigil's animated Blender aura, breathes and is crossed by a glint, a press dips it, bursts and flashes its ring, a buffed major rises to the crown, where the engine shows the aura's own slot burning with a draining ring, a bead, a last-fifth notch and a countdown, the newest running buff, by your cast or its readable start, owns the crown (handed off by the engine's aura-shown signal), an ended one cools to steel and folds home, a dark sweep and a refilling steel ring count the cooldown under a small steel sigil and the medal relights with a flare; each flare or press claims the crest's one flare as a whole; the seats are chosen afresh only while the crest can be rebuilt, so the other trackers stand down for the seats picked out of lockdown, take back at once the cues of any the rail could not show, and a switched-off rail stays while locked until they can take their cues back; a hidden rail plays nothing, and no aura is read while auras are secret, an unseen buff dated once they read; Calm lights in place with still auras and no lift, burst or breathing, Off shows only lit, cooling and ready, a motion change or hiding stops what is in flight, and Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Effects, Widgets = K.Effects, K.Widgets
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals
local rad = math.rad

local Rail = {}
ns.SlabRail = Rail

local SEAT, CROWN, PITCH, PEAK, BOW, CROWN_Y = 28, 34, 31, 126, 10, 90
local LOW_Y, LOW_CROWN = 227, 6
local SPAN = 2 * PITCH
local SIGIL, ICON, SHADE, PAD, REFILL, AURA = 0.86, 0.74, 1.9, 5, 0.6, 0.86 / 0.62
local BREATH, BREATH_RUN, GLOW, READY_GLOW, READY_RING, READY_RUN, RELIGHT = { 0.1, 0.2 }, 1.2, 1.6, 44, 34, 0.3, 0.18
local GLINT, GLINT_RUN, FLASH_RUN, NOTCH, FIFTH, CLAIM_PAD = 6, 0.18, 0.27, 4, 0.2, 0.05
local MARK, MARK_RISE, MARK_DROP = 0.42, 0.2, 0.2
local DIP, DIP_RUN, BURST, BURST_RUN = 0.86, 0.12, { 0.85, 1.45 }, 0.4
local LIFT_RUN, TURN, POP, POP_RUN, SETTLE_RUN, FOLD_RUN, HOME_RUN = 0.28, 16, 1.29 / 1.21, 0.2, 0.16, 0.35, 0.3
local CASTS = { "unitframes.castbar.player", "unitframes.castbar.target" }
local OWNER, NONE = "ActionBars.SlabRail", {}
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
	trinket = { sigil = "Charm" },
}
local TREES = {
	{ "wrath", "rapid", "intimidate", "trap" },
	{ "rapid", "trap", "sniper", "aimed" },
	{ "rapid", "deter", "trap", "strider" },
}
local SIGNS = { { "wrath", "intimidate" }, { "sniper", "aimed" }, { "deter", "strider" } }
Rail.ABILITIES, Rail.TREES = ABILITIES, TREES
Rail.picked, Rail.held = NONE, NONE

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
	local info = C_SpecializationInfo
	local index = info and type(info.GetSpecialization) == "function" and info.GetSpecialization()
	if not IsSecret(index) and TREES[index] then
		return index
	end
	local best, most = nil, 0
	for i in ipairs(info and type(info.GetSpecializationInfo) == "function" and TREES or NONE) do
		local points = select(7, info.GetSpecializationInfo(i, false, false))
		if not IsSecret(points) and type(points) == "number" and points > most then
			best, most = i, points
		end
	end
	if best then
		return best
	end
	best, most = 1, 0
	for i, sign in ipairs(SIGNS) do
		local n = 0
		for _, key in ipairs(sign) do
			n = n + (Medals.Known(ABILITIES[key].spells) and 1 or 0)
		end
		if n > most then
			best, most = i, n
		end
	end
	return best
end

function Rail.Seats()
	local seats = {}
	for _, key in ipairs(TREES[Rail.Tree()]) do
		local id = Medals.Known(ABILITIES[key].spells)
		if id then
			seats[#seats + 1] = { key = key, spell = id }
		end
	end
	local slot, spell = Trinket()
	if slot then
		seats[#seats + 1] = { key = "trinket", slot = slot, press = spell }
	end
	return seats
end

local function Named(seats)
	local keys = {}
	for i, at in ipairs(seats) do
		keys[i] = at.key .. (at.slot or "")
	end
	return table.concat(keys, ",")
end

function Rail.Pick(form)
	if not Medals.Locked() then
		local was = Named(Rail.picked)
		Rail.picked = form == "crest" and ns.Config("crestRail") ~= false and Rail.Seats() or NONE
		if Named(Rail.picked) ~= was then
			Rail.held = Rail.picked
		end
	end
end

function Rail.Known()
	return (#Rail.picked > 0 or #Rail.held > 0) and 3045 or nil
end

function Rail.Holding()
	return #Rail.held > 0 and Medals.Locked()
end

function Rail.Commit()
	if Medals.Locked() then
		return false
	end
	local r = Rail.piece
	local seats = r and r:IsShown() and r.seated or NONE
	local changed = Named(seats) ~= Named(Rail.held)
	Rail.held = seats
	return changed
end

function Rail.Holds(spells, slot)
	for _, at in ipairs(Rail.held) do
		if slot and at.slot == slot then
			return true
		end
		for _, id in ipairs(spells or NONE) do
			for _, own in ipairs(ABILITIES[at.key].spells or NONE) do
				if id == own then
					return true
				end
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

local function Face(piece, parent, size, art)
	piece.add(Medals.Texture(parent, "BACKGROUND", 0, "glow", "black", size * SHADE)):SetAlpha(0.7)
	piece.add(Medals.Texture(parent, "BORDER", 0, "medEnamel", "steel", size))
	if art then
		piece.add(Medals.Texture(parent, "ARTWORK", -1, art, "steel", size * SIGIL))
	end
	piece.add(Medals.Texture(parent, "OVERLAY", 0, "medRing", "white", size))
end

local function Aura(piece, parent, size, sigil)
	local token = "railAura" .. sigil
	local still = piece.add(Medals.Texture(parent, "ARTWORK", 1, token, "white", size * AURA, "ADD"))
	still:SetTexCoord(0, 0.25, 0, 0.25)
	local moving = piece.add(Medals.Texture(parent, "ARTWORK", 1, token, "white", size * AURA, "ADD"))
	moving:SetAlpha(0)
	return { still = still, moving = moving, loop = Medals.Flip(moving, token, 1) }
end

local function Burning(aura, on)
	aura.still:SetAlpha(on and 0 or 1)
	aura.moving:SetAlpha(on and 1 or 0)
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
	local level = r:GetFrameLevel() + 2
	local ability = ABILITIES[at.key]
	local seat = Medals.Piece(r, level, SEAT)
	seat.key, seat.ability = at.key, ability
	Face(seat, seat, SEAT, "sigil" .. ability.sigil)
	seat.lit = Medals.Layer(seat, level + 1)
	seat.glow = seat.add(Medals.Texture(seat.lit, "BACKGROUND", 1, "glow", "jewelHawk", SEAT * GLOW, "ADD"))
	seat.glow:SetAlpha(BREATH[1])
	seat.breath = ns.Slab.Group(seat.glow, "BOUNCE")
	ns.Slab.Fade(seat.breath, BREATH[1], BREATH[2], BREATH_RUN)
	seat.add(Medals.Texture(seat.lit, "BORDER", 1, "dot", "black", SEAT * ICON)):SetAlpha(0.55)
	seat.aura = Aura(seat, seat.lit, SEAT, ability.sigil)
	seat.relight = ns.Slab.Group(seat.lit)
	ns.Slab.Fade(seat.relight, 0, 1, RELIGHT)
	seat.glint = seat.add(Medals.Texture(seat.lit, "OVERLAY", 2, "diamond", "white", GLINT, "ADD"))
	seat.glint:SetPoint("CENTER", seat, "CENTER", -SEAT * 0.4, SEAT * 0.2)
	seat.glint:SetAlpha(0)
	seat.glinting = ns.Slab.Group(seat.glint)
	for order, fade in ipairs({ { 0, 0.9 }, { 0.9, 0 } }) do
		Move(seat.glinting, SEAT * 0.4, -SEAT * 0.2, GLINT_RUN, order, "NONE")
		ns.Slab.Fade(seat.glinting, fade[1], fade[2], GLINT_RUN, order)
	end
	seat.sweep = Timer(seat, level + 3, "dot", "black", 0.7, SEAT * ICON)
	seat.refill = Timer(seat, level + 3, "orbRing", "steel", REFILL, SEAT + PAD)
	seat.refill:SetReverse(true)
	seat.sweep:SetHideCountdownNumbers(false)
	local count = seat.sweep.GetCountdownFontString and seat.sweep:GetCountdownFontString()
	if count then
		count:ClearAllPoints()
		count:SetPoint("CENTER", seat, "CENTER", 0, -SEAT * MARK_DROP)
	end
	seat.sweep:SetScript("OnCooldownDone", function()
		Rail.Ready(seat)
	end)
	seat.cold = Medals.Layer(seat, level + 4)
	seat.add(Medals.Texture(seat.cold, "ARTWORK", 0, "sigil" .. ability.sigil, "steelLit", SEAT * MARK)):SetPoint("CENTER", seat, "CENTER", 0, SEAT * MARK_RISE)
	seat.cold:SetAlpha(0)
	local flare = Medals.Layer(seat, level + 5)
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
	seat.ring = seat.add(Medals.Texture(flare, "OVERLAY", 4, "medRing", "gilt", SEAT, "ADD"))
	seat.ring:SetAlpha(0)
	seat.flash = ns.Slab.Group(seat.ring)
	ns.Slab.Fade(seat.flash, 1, 0, FLASH_RUN)
	seat.dip = ns.Slab.Group(seat)
	Grow(seat.dip, 1, DIP, DIP_RUN, 1)
	Grow(seat.dip, DIP, 1, DIP_RUN, 2)
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

local function Started(seat)
	local get = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	for _, id in ipairs(type(get) == "function" and not Medals.Restricted() and seat.ability.spells or NONE) do
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
		seat.gate:SetAlpha(up and (top == nil or seat == top) and 1 or 0)
		seat.hold:SetAlpha(up and 1 or 0)
		local crowned = seat == top
		local aura, burning = seat.crowned.aura, full and crowned
		seat.burn:SetAlpha(crowned and 1 or 0)
		Burning(aura, burning)
		if not burning then
			aura.loop:Stop()
		elseif not aura.loop:IsPlaying() then
			aura.loop:Play()
		end
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
	local level = seat:GetFrameLevel() + 6
	local spec = { feed = "aura", unit = ability.unit, filter = "HELPFUL", spells = ability.spells }
	local slot = Medals.Lit(seat, spec, level)
	seat.hold = slot.hold
	seat.hold.add = seat.add
	seat.add(Medals.Texture(slot, "ARTWORK", 0, "dot", "black", SEAT)):SetAlpha(0.75)
	slot.timer = seat.add(Medals.Timer(slot, level + 1, "orbRing", "jewelHawk"), SEAT + PAD)
	slot:SetDurationCooldown(slot.timer)
	seat.add(Medals.Ember(seat.hold, slot, slot.timer, "Band", level + 2, SEAT))
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
	lit.aura = Aura(crown, seat.burn, CROWN, ability.sigil)
	lit.timer = crown.add(Medals.Timer(lit, top + 3, "orbRing", "jewelHawk"), CROWN + PAD)
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
	crown.add(Medals.Texture(seat.ghost, "ARTWORK", 0, "sigil" .. ability.sigil, "steel", CROWN * SIGIL))
	seat.ghost:SetAlpha(0)
	seat.rise = ns.Slab.Group(seat.lift)
	local from = SEAT * DIP / CROWN
	seat.out = Move(seat.rise, 0, 0, 0.001, 1, "NONE")
	Grow(seat.rise, from, from, 0.001, 1)
	seat.back = Move(seat.rise, 0, 0, LIFT_RUN, 2, "OUT")
	seat.pop = Grow(seat.rise, from, POP, POP_RUN, 2)
	seat.turns = { Turn(seat.rise, TURN, LIFT_RUN, 2, "OUT") }
	seat.settle = Grow(seat.rise, POP, 1, SETTLE_RUN, 3)
	seat.turns[2] = Turn(seat.rise, -TURN, SETTLE_RUN, 3, "IN_OUT")
	seat.rise:SetScript("OnFinished", function()
		if r.rising == seat then
			r.rising = nil
			Crown(r)
		end
	end)
	seat.home = ns.Slab.Group(seat.ghost)
	ns.Slab.Fade(seat.home, 1, 1, FOLD_RUN, 1)
	seat.away = Move(seat.home, 0, 0, HOME_RUN, 2, "IN_OUT")
	Grow(seat.home, 1, SEAT / CROWN, HOME_RUN, 2)
	ns.Slab.Fade(seat.home, 1, 0, HOME_RUN, 2)
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
	seat.back:SetOffset(-dx, -dy)
	seat.away:SetOffset(dx, dy)
	local pop, turn = r.low and 1 or POP, r.low and 0 or TURN
	seat.pop:SetScaleTo(pop, pop)
	seat.settle:SetScaleFrom(pop, pop)
	seat.turns[1]:SetDegrees(turn)
	seat.turns[2]:SetDegrees(-turn)
end

local function Quiet(r, seat, calm)
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
			aura.loop:Stop()
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

local function Light(seat, ready, flare)
	local was = seat.ready
	seat.ready = ready
	local shown = seat:IsVisible()
	local full, calm = shown and Full(), shown and Effects.Allows("flare")
	if ready ~= was then
		seat.relight:Stop()
	end
	seat.lit:SetAlpha(ready and 1 or 0)
	seat.cold:SetAlpha(ready and 0 or 1)
	if ready and was == false and flare and calm then
		seat.relight:Play()
		if full then
			seat.welcome()
		end
	end
	local burning = ready and full
	Burning(seat.aura, burning)
	if burning then
		if not seat.breath:IsPlaying() then
			seat.breath:Play()
		end
		if not seat.aura.loop:IsPlaying() then
			seat.aura.loop:Play()
		end
	else
		seat.breath:Stop()
		seat.aura.loop:Stop()
	end
end

function Rail.Ready(seat)
	if seat.ready == false then
		Light(seat, true, true)
	end
end

local function Cool(seat, flare)
	local cooling
	if seat.slot then
		local start, length, enable, gcd = 0, 0, 0, nil
		if type(GetInventoryItemCooldown) == "function" then
			start, length, enable, gcd = GetInventoryItemCooldown("player", seat.slot)
		end
		cooling = not (IsSecret(start) or IsSecret(length) or IsSecret(enable) or IsSecret(gcd)) and type(length) == "number" and length > 0
			and enable ~= 0 and gcd ~= true
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
	Light(seat, not cooling, flare)
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
Rail.Low = Low

function Rail.Build(parent, spec, level)
	local r = Medals.Piece(parent, level, 2 * (SPAN + SEAT))
	r.rail, r.order, r.made, r.majors, r.running, r.stamps = true, {}, {}, {}, {}, {}
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

function Rail.Place(r, anchor)
	r.anchor = anchor
	Medals.Place(r, anchor, 0, 0)
	if Medals.Locked() then
		return
	end
	local seats, low = Rail.picked, Low()
	r.order, r.low = {}, low
	for _, seat in pairs(r.made) do
		seat:Hide()
	end
	Medals.Place(r.crown, r, low and -#seats / 2 * PITCH - LOW_CROWN or 0, low and LOW_Y or CROWN_Y)
	for i, at in ipairs(seats) do
		local seat = r.made[at.key]
		if not seat then
			seat = Seat(r, at)
			r.made[at.key] = seat
			if seat.ability.unit then
				Major(r, seat, seat.ability)
			end
		end
		seat.spell, seat.slot, seat.press = at.spell, at.slot, at.press
		local x = low and (i - #seats / 2) * PITCH or (i - (#seats + 1) / 2) * PITCH
		Medals.Place(seat, r, x, low and LOW_Y or PEAK - BOW * (x / SPAN) ^ 2)
		seat:Show()
		r.order[i] = seat
		if seat.crowned then
			Aim(r, seat)
		end
	end
	for _, seat in pairs(r.made) do
		if not seat:IsShown() then
			Quiet(r, seat)
			Running(r, seat, false)
		end
	end
	r.seated = seats
	r.crown.sized = nil
	Medals.Size(r.crown)
	Rail.Paint(r)
end

local function Pressed(seat, spell)
	if seat.press == spell then
		return true
	end
	for _, id in ipairs(seat.ability.spells or NONE) do
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
		for _, seat in ipairs(r.order) do
			if Pressed(seat, spell) then
				return Press(r, seat)
			end
		end
	elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
		local item = event == "BAG_UPDATE_COOLDOWN"
		for _, seat in ipairs(r.order) do
			if (seat.slot ~= nil) == item then
				Cool(seat, true)
			end
		end
	elseif event == nil then
		Settle(r)
		for _, seat in ipairs(r.order) do
			Cool(seat)
		end
		for _, seat in ipairs({ unpack(r.running) }) do
			r.stamps[seat] = r.stamps[seat] or Started(seat)
			Running(r, seat, true)
		end
		Crown(r)
	end
end
