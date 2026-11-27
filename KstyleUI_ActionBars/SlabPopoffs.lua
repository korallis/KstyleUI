-- SlabPopoffs.lua: the crest's signature pop-offs (docs/medallions-effects.md#signature-pop-offs), one or two class moments that rise off the crest into a seat above it while their aura lasts.
local _, ns = ...

local K = KstyleUI
local Effects = K.Effects
local Medals = ns.SlabMedals

local Popoffs = {}
ns.SlabPopoffs = Popoffs

local KEY = "crestPopoffs"
local SIZE, TRACK, BURST = 26, 4, 1.1
local RISE, RISE_RUN, RISE_FROM, FLASH, POP, POP_RUN = 22, 0.32, 0.55, 0.05, 1.15, 0.35
local ARRIVE = { { 0, 0, RISE_RUN - 0.08 }, { 0, 1, 0.1 } }
local FOLD, FOLD_RUN = 1.4, 0.4

local function Move(group, dx, dy, duration, order, smoothing)
	local t = group:CreateAnimation("Translation")
	t:SetOffset(dx, dy)
	t:SetDuration(duration)
	t:SetOrder(order)
	t:SetSmoothing(smoothing)
	return t
end

local function Travel(flare)
	local play = ns.Slab.Group(flare)
	Move(play, 0, -RISE, 0.01, 1, "NONE")
	Move(play, 0, RISE, RISE_RUN, 2, "OUT")
	ns.Slab.Grow(play, RISE_FROM, 1, RISE_RUN, 2, "OUT")
	ns.Slab.Fade(play, 0, 1, FLASH, 2)
	ns.Slab.Grow(play, 1, POP, POP_RUN, 3)
	ns.Slab.Fade(play, 1, 0, POP_RUN, 3)
	play.held = RISE_RUN + POP_RUN
	flare.play = play
end

local function Fold(piece, spec, level)
	local fold = Medals.Layer(piece, level)
	piece.add(Medals.Texture(fold, "ARTWORK", 0, "sigil" .. spec.art, spec.color, SIZE, "ADD"))
	piece.add(Medals.Texture(fold, "BACKGROUND", 0, "glow", spec.color, SIZE * 2, "ADD"))
	fold:SetAlpha(0)
	fold.play = ns.Slab.Group(fold)
	ns.Slab.Grow(fold.play, 1, FOLD, FOLD_RUN)
	ns.Slab.Fade(fold.play, 1, 0, FOLD_RUN)
	return fold
end

local function Folds(piece)
	piece.settling = nil
	if piece.up or not (piece:IsVisible() and Effects.Allows("ambient") and not ns.Slab.Resting()) then
		return
	end
	piece.fold.play:Stop()
	piece.fold.play:Play()
end

local function Watch(piece, lit)
	local watch = ns.Slab.Group(Medals.Layer(lit, lit:GetFrameLevel()), "REPEAT")
	ns.Slab.Fade(watch, 1, 1, 1)
	watch:SetScript("OnPlay", function()
		piece.up = true
		piece.fold.play:Stop()
	end)
	watch:SetScript("OnStop", function()
		piece.up = nil
		if not piece.settling and C_Timer and C_Timer.After then
			piece.settling = true
			C_Timer.After(0, function() Folds(piece) end)
		end
	end)
	lit:AddAuraShownAnimation(watch)
	piece.watch = watch
end

function Popoffs.Build(parent, spec, level)
	local piece = Medals.Piece(parent, level, SIZE)
	local lit = Medals.Lit(piece, spec, level + 1)
	Medals.Mark(piece, lit, "pop" .. spec.art, SIZE, spec.color)
	lit.timer = piece.add(Medals.Timer(lit, level + 2, "ringLine16", spec.color), SIZE + TRACK)
	lit:SetDurationCooldown(lit.timer)
	piece.add(Medals.Ember(piece, lit, lit.timer, "RingLine16", level + 3, SIZE + TRACK))
	lit.loops = { Medals.Steps(lit, ARRIVE) }
	for _, flare in ipairs(Medals.Flare(piece, lit, level + 5, "sigil" .. spec.art, SIZE * BURST)) do
		flare:SetVertexColor(K.Tokens.Color(spec.color))
	end
	local gate = lit.flareGate
	for _, each in ipairs(gate and { gate, gate.other } or {}) do
		Travel(each.lit.flare)
	end
	if not Medals.twin then
		piece.fold = Fold(piece, spec, level + 4)
		Watch(piece, lit)
	end
	piece.spec = spec
	return piece
end

local function Row(seat, art, color, spells, known, unit)
	return { key = KEY, seat = ns.SlabSeats.AT[seat], crestOnly = true, feed = "aura", build = Popoffs.Build, art = art, color = color, spells = spells, known = known, unit = unit }
end

Popoffs.CLASSES = {
	{ "MAGE", { Row("popLeft", "Crystal", "schoolFrost", { 11958, 27619 }, { 11958 }), Row("popRight", "Vortex", "schoolArcane", { 12051 }) } },
	{ "HUNTER", { Row("popLeft", "Paw", "schoolFire", { 19574 }, nil, "pet"), Row("popRight", "Deflect", "schoolPhysical", { 19263 }) } },
	{ "PALADIN", { Row("popLeft", "Bubble", "schoolHoly", { 642, 1020 }), Row("popRight", "Sun", "jewelHoly", { 20216 }) } },
	{ "PRIEST", { Row("popLeft", "Infusion", "schoolHoly", { 10060 }), Row("popRight", "Focus", "schoolArcane", { 14751 }) } },
	{ "WARLOCK", { Row("popLeft", "Void", "schoolShadow", { 17941 }, { 18094 }), Row("popRight", "Curse", "jewelShard", { 18288 }) } },
	{ "DRUID", { Row("popLeft", "Innervate", "schoolNature", { 29166 }), Row("popRight", "Swift", "schoolNature", { 17116 }) } },
	{ "SHAMAN", { Row("popLeft", "Bolt", "schoolFrost", { 16246 }, { 16164 }), Row("popRight", "Swift", "schoolNature", { 16188 }) } },
	{ "WARRIOR", { Row("popRight", "Sweep", "schoolPhysical", { 12292 }) } },
	{ "ROGUE", { Row("popRight", "Veil", "schoolShadow", { 1784, 1785, 1786, 1787 }) } },
}

local CLASS = UnitClass and select(2, UnitClass("player"))
for _, entry in ipairs(Popoffs.CLASSES) do
	if entry[1] == CLASS then
		ns.SlabTrackers.Register(entry[1], entry[2])
	end
end
