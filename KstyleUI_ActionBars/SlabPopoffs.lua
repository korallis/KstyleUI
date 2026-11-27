-- SlabPopoffs.lua: the crest's signature pop-offs (docs/medallions-effects.md#signature-pop-offs), one or two class moments that leave the crest while their aura lasts.
local _, ns = ...

local K = KstyleUI
local Effects = K.Effects
local Medals = ns.SlabMedals
local Ranged = ns.SlabRanged

local Popoffs = {}
ns.SlabPopoffs = Popoffs

local KEY = "crestPopoffs"
local SIZE, TRACK, BURST = 26, 4, 1.1
local RISE, RISE_RUN, RISE_FROM, FLASH, POP, POP_RUN = 22, 0.32, 0.55, 0.05, 1.15, 0.35
local ARRIVE = { { 0, 0, RISE_RUN - 0.08 }, { 0, 1, 0.1 } }
local FOLD, FOLD_RUN = 1.4, 0.4
local MOTE, TICK, TICK_RUN, TICK_OUT, TICK_FROM = 12, 2, 0.6, 0.2, 0.2
local FORBEARANCE = 25771
local OWNER = "ActionBars.SlabPopoffs"
local UPPER, PET = ns.SlabSeats.AT.upper, Ranged.PET
local OUT = math.sqrt(PET[1] * PET[1] + PET[2] * PET[2])
local EDGE, LIFT = 10 / OUT, 8 / OUT
local BEAST_AT = { PET[1] * (1 + EDGE) - UPPER[1], PET[2] * (1 + EDGE) - UPPER[2] }
local BEAST_TO = { PET[1] * LIFT, PET[2] * LIFT }
local pieces, watching = {}, false
local seen, present, live = { target = {}, focus = {}, roster = {} }, {}, {}
local PARTY, RAID, kind = {}, {}, nil
for i = 1, 4 do
	PARTY[i] = "party" .. i
end
for i = 1, 40 do
	RAID[i] = "raid" .. i
end

local function Kind()
	return IsInRaid and IsInRaid() and "raid" or IsInGroup and IsInGroup() and "party" or "solo"
end

local function Move(group, dx, dy, duration, order, smoothing)
	local t = group:CreateAnimation("Translation")
	t:SetOffset(dx, dy)
	t:SetDuration(duration)
	t:SetOrder(order)
	t:SetSmoothing(smoothing)
	return t
end

local function Travel(flare, from, to)
	local play = ns.Slab.Group(flare)
	local dx, dy = from[1], from[2]
	local ex, ey = to and to[1] or 0, to and to[2] or 0
	if dx ~= 0 or dy ~= 0 or to then
		Move(play, dx, dy, 0.01, 1, "NONE")
		Move(play, ex - dx, ey - dy, RISE_RUN, 2, "OUT")
	end
	ns.Slab.Grow(play, RISE_FROM, 1, RISE_RUN, 2, "OUT")
	ns.Slab.Fade(play, 0, 1, FLASH, 2)
	ns.Slab.Grow(play, 1, POP, POP_RUN, 3)
	ns.Slab.Fade(play, 1, 0, POP_RUN, 3)
	play.held = RISE_RUN + POP_RUN
	flare.play = play
end

local function Idle(flare)
	flare:Hide()
	for _, group in ipairs({ Medals.Arbitrate(flare.play, true, flare.gate), Medals.Arbitrate(Medals.Hold(flare), true, flare.gate) }) do
		group:HookScript("OnPlay", function() flare:SetShown(flare.gate.base ~= 0) end)
		group:HookScript("OnFinished", function() flare:Hide() end)
		group:HookScript("OnStop", function() flare:Hide() end)
	end
end

local function Ticks(piece, lit, spec, level)
	local layer = Medals.Layer(lit, level)
	piece.add(Medals.Texture(layer, "ARTWORK", 0, "glow", spec.color, MOTE, "ADD"))
	layer:SetAlpha(0)
	local g = ns.Slab.Group(layer, "REPEAT")
	local dx, dy = -spec.seat[1] * TICK_FROM, -spec.seat[2] * TICK_FROM
	Move(g, dx, dy, 0.01, 1, "NONE")
	Move(g, -dx, -dy, TICK_RUN, 2, "IN")
	ns.Slab.Fade(g, 0, 1, TICK_RUN, 2)
	ns.Slab.Fade(g, 1, 0, TICK_OUT, 3)
	ns.Slab.Fade(g, 0, 0, TICK - TICK_RUN - TICK_OUT - 0.01, 4)
	return g
end

local function After(piece, spec, level)
	local after = spec.after
	local lit = Medals.Lit(piece, setmetatable({ spells = { after.spell }, filter = "HARMFUL", unit = "player" }, { __index = spec }), level)
	lit.timer = piece.add(Medals.Timer(lit, level + 1, "ringLine16", after.color), after.size)
	lit:SetDurationCooldown(lit.timer)
	return lit
end

local function Twin(twin)
	local same = UnitIsUnit and UnitIsUnit(twin.unit, twin.other)
	twin:SetAlpha(1)
	if not (issecretvalue and issecretvalue(same)) then
		twin:SetShown(same ~= true)
	elseif twin.SetAlphaFromBoolean then
		twin:Show()
		twin:SetAlphaFromBoolean(same, 0, 1)
	else
		twin:Hide()
	end
end

local function Present(layer)
	local here = UnitExists and UnitExists(layer.unit)
	layer:SetShown(issecretvalue and issecretvalue(here) or here == true)
end

local function Fresh(list)
	for _, twin in ipairs(list) do
		Twin(twin)
	end
end

local function Rewarn()
	if ns.SlabRings then ns.SlabRings.Update() end
end

local function OnTarget()
	Fresh(seen.target)
	Rewarn()
end

local function OnFocus()
	Fresh(seen.focus)
	Rewarn()
end

local function OnRoster()
	if Kind() ~= kind then
		kind = Kind()
		ns.SlabTrackers.Update()
	end
	for _, layer in ipairs(present) do
		Present(layer)
	end
	Fresh(seen.roster)
	Rewarn()
end

local function Unseen(parent, unit, other, level)
	local twin = Medals.Layer(parent, level)
	twin.unit, twin.other = unit, other
	for token, list in pairs(seen) do
		if unit == token or other == token or token == "roster" and unit ~= "target" and unit ~= "focus" then
			list[#list + 1] = twin
		end
	end
	Twin(twin)
	return twin
end

local function Listening(piece, on)
	live[piece] = on or nil
	local any = false
	for each in pairs(live) do
		live[each] = each:IsShown() or nil
		any = any or each:IsShown()
	end
	for event, fn in pairs({ PLAYER_TARGET_CHANGED = OnTarget, PLAYER_FOCUS_CHANGED = OnFocus, GROUP_ROSTER_UPDATE = OnRoster }) do
		if any then
			K.Events.Register(OWNER, event, fn)
		else
			K.Events.Unregister(OWNER, event)
		end
	end
	if on then
		kind = Kind()
		OnRoster()
		OnTarget()
		OnFocus()
	end
end

local function Fold(piece, spec, size, level)
	local fold = Medals.Layer(piece, level)
	piece.add(Medals.Texture(fold, "ARTWORK", 0, "sigil" .. spec.art, spec.color, size, "ADD"))
	piece.add(Medals.Texture(fold, "BACKGROUND", 0, "glow", spec.color, size, "ADD"))
	fold:SetAlpha(0)
	fold:Hide()
	fold.play = ns.Slab.Group(fold)
	ns.Slab.Grow(fold.play, 1, spec.after and spec.after.size / size or spec.overlay and 1 / FOLD or FOLD, FOLD_RUN)
	ns.Slab.Fade(fold.play, 1, 0, FOLD_RUN)
	fold.play:SetScript("OnFinished", function() fold:Hide() end)
	fold.play:SetScript("OnStop", function() fold:Hide() end)
	return fold
end

local function Calm(still)
	if still then
		for _, piece in ipairs(pieces) do
			piece.settling = nil
			piece.fold.play:Stop()
		end
	end
end

local function Moving(piece)
	return piece:IsVisible() and Effects.Allows("ambient") and not ns.Slab.Resting()
end

local function Folds(piece)
	piece.settling = nil
	if next(piece.ups) or not Moving(piece) then
		return
	end
	piece.fold.play:Stop()
	piece.fold:Show()
	piece.fold.play:Play()
end

local function Watch(piece, lit)
	local watch = ns.Slab.Group(Medals.Layer(lit, lit:GetFrameLevel()), "REPEAT")
	ns.Slab.Fade(watch, 1, 1, 1)
	watch:SetScript("OnPlay", function()
		piece.ups[watch] = true
		piece.fold.play:Stop()
	end)
	watch:SetScript("OnStop", function()
		piece.ups[watch] = nil
		if not piece.settling and Moving(piece) and C_Timer and C_Timer.After then
			local mark = {}
			piece.settling = mark
			C_Timer.After(0, function()
				if piece.settling == mark then Folds(piece) end
			end)
		end
	end)
	lit:AddAuraShownAnimation(watch)
	lit.watch = watch
end

local function Hidden(piece)
	piece.settling = nil
	piece.fold.play:Stop()
end

local function Life(piece, lit, spec, size, level)
	Medals.Sheet(piece, lit, "pop" .. spec.art, size)
	lit.timer = piece.add(Medals.Timer(lit, level + 1, "ringLine16", spec.color), spec.ring or size + TRACK)
	lit:SetDurationCooldown(lit.timer)
	piece.add(Medals.Ember(piece, lit, lit.timer, "RingLine16", level + 2, spec.ring or size + TRACK))
	lit.loops = { Medals.Steps(lit, ARRIVE), spec.ticks and Ticks(piece, lit, spec, level + 2) or nil }
	for _, flare in ipairs(Medals.Flare(piece, lit, level + 4, "sigil" .. spec.art, spec.overlay and size / POP or size * BURST)) do
		flare:SetVertexColor(K.Tokens.Color(spec.color))
	end
	local gate, seat = lit.flareGate, spec.seat
	local reach = math.sqrt(seat[1] * seat[1] + seat[2] * seat[2])
	for _, each in ipairs(gate and { gate, gate.other } or {}) do
		local flare, at = each.lit.flare, spec.anchor
		if at then
			local host = flare:GetParent()
			flare:ClearAllPoints()
			flare:SetPoint("TOPLEFT", host, "TOPLEFT", at[1], at[2])
			flare:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", at[1], at[2])
		end
		Travel(each.lit.flare, spec.from or { -seat[1] * RISE / reach, -seat[2] * RISE / reach }, spec.to)
		Idle(each.lit.flare)
	end
	return lit
end

local function Ally(piece, spec, unit, others, size, level)
	local host = piece
	if unit ~= "target" and unit ~= "focus" then
		host = Medals.Layer(piece, level)
		host.unit = unit
		present[#present + 1] = host
		Present(host)
	end
	for _, other in ipairs(others) do
		host = Unseen(host, unit, other, level)
	end
	host.root, host.top, host.add, host.parts, host.lits, host.units = true, piece, piece.add, piece.parts, piece.lits, piece.units
	local ally = setmetatable({ unit = unit, filter = "HELPFUL|PLAYER" }, { __index = spec })
	return Life(host, Medals.Lit(host, ally, level), ally, size, level)
end

function Popoffs.Build(parent, spec, level)
	local size = spec.size or SIZE
	local piece = Medals.Piece(parent, level, size)
	local lits = { Life(piece, Medals.Lit(piece, spec, level + 1), spec, size, level + 1) }
	local others = { "player" }
	for _, unit in ipairs(spec.allies or {}) do
		lits[#lits + 1] = Ally(piece, spec, unit, others, size, level + 1)
		others[#others + 1] = unit
	end
	for _, unit in ipairs(spec.group or {}) do
		lits[#lits + 1] = Ally(piece, spec, unit, spec.group == RAID and { "player", "target", "focus" } or { "target", "focus" }, size, level + 1)
	end
	if spec.after then
		After(piece, spec, level + 1)
	end
	if not Medals.twin then
		piece.fold, piece.ups = Fold(piece, spec, size, level + 4), {}
		pieces[#pieces + 1] = piece
		for _, lit in ipairs(lits) do
			Watch(piece, lit)
		end
		piece:HookScript("OnHide", Hidden)
		if spec.allies then
			piece:HookScript("OnShow", function() Listening(piece, true) end)
			piece:HookScript("OnHide", function() Listening(piece, false) end)
			Listening(piece, piece:IsVisible())
		end
		if not watching then
			watching = true
			Medals.OnRest(Calm)
		end
	end
	piece.spec = spec
	return piece
end

local function Row(seat, art, color, spells, extra)
	local row = { key = KEY, seat = ns.SlabSeats.AT[seat] or seat, crestOnly = true, feed = "aura", build = Popoffs.Build, art = art, color = color, spells = spells }
	for k, v in pairs(extra or {}) do
		row[k] = v
	end
	return row
end

Popoffs.CLASSES = {
	{ "MAGE", {
		Row("emblem", "Crystal", "schoolFrost", { 11958, 27619 }, { known = { 11958 }, overlay = true, size = 84, ring = 62, from = { 0, 0 } }),
		Row(Ranged.PENDANT, "Vortex", "schoolArcane", { 12051 }, { overlay = true, ticks = true, from = { 0, 0 } }),
	} },
	{ "HUNTER", {
		Row("upper", "Beast", "schoolFire", { 19574 }, { unit = "pet", anchor = BEAST_AT, from = { 0, 0 }, to = BEAST_TO }),
		Row("popHunter", "Deflect", "schoolPhysical", { 19263 }, { from = { 0, -RISE } }),
	} },
	{ "PALADIN", {
		Row("emblem", "Bubble", "schoolHoly", { 642, 1020 }, { overlay = true, size = 52, ring = 48, from = { 0, 0 }, after = { spell = FORBEARANCE, size = 44, color = "jewelHoly" } }),
		Row("popRight", "Sun", "jewelHoly", { 20216 }),
	} },
	{ "PRIEST", {
		Row("popLeft", "Infusion", "schoolHoly", { 10060 }, { allies = { "target", "focus" }, choices = {
			{ lazy = true, group = RAID, active = function() return Kind() == "raid" end },
			{ lazy = true, group = PARTY, active = function() return Kind() == "party" end },
			{},
		} }),
		Row("popRight", "Focus", "schoolArcane", { 14751 }),
	} },
	{ "WARLOCK", {
		Row("popLeft", "Void", "schoolShadow", { 17941 }, { known = Ranged.NIGHTFALL }),
		Row("popRight", "Curse", "jewelShard", { 18288 }),
	} },
	{ "DRUID", { Row("popLeft", "Innervate", "schoolNature", { 29166 }), Row("popRight", "Swift", "schoolNature", { 17116 }) } },
	{ "SHAMAN", { Row("popLeft", "Bolt", "schoolFrost", { 16246 }, { known = { 16164 } }), Row("popRight", "Swift", "schoolNature", { 16188 }) } },
	{ "WARRIOR", { Row("popRight", "Sweep", "schoolPhysical", { 12292 }) } },
	{ "ROGUE", { Row("popRogue", "Veil", "schoolShadow", { 1784, 1785, 1786, 1787 }) } },
}

local CLASS = UnitClass and select(2, UnitClass("player"))
for _, entry in ipairs(Popoffs.CLASSES) do
	if entry[1] == CLASS then
		ns.SlabTrackers.Register(entry[1], entry[2])
	end
end
