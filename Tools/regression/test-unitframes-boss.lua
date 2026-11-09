-- test-unitframes-boss.lua: the boss column holds five compact cards that keep the name, the pill and the cast line, inside the footprint the layouts reserve with the cards' aura room; the boss you target folds its card to a slim Targeted chip, because the sigil already carries its name, health and cast (round 2: Grok #2, Muse #1). A secret unit comparison goes through SetAlphaFromBoolean.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local Frames, Geometry, Layouts = ns.Frames, ns.Geometry, K.Setup.Layouts

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.5)
end

-- The column: five slots at the element's own size, each a card with a name, a pill and a cast line ------------------

local element = Layouts.Element("unitframes.boss")
local uf = Frames.Get("boss")
assert(#uf.views == 5, "five boss cards, boss1 to boss5")
local slots = Geometry.Slots(Geometry.BOSS_COUNT, Geometry.BOSS_GAP, element.width, element.height)
local last = slots[#slots]
assert(near(last.y + last.h, element.height, 1e-6), "the fifth card ends at the column's foot")
local s = ns.Settings.Snapshot("boss")
local g = Geometry.Frame(s, slots[1].w, slots[1].h, 1)
assert(g.form == "card", "each boss is a card")
assert(g.name and g.health and g.cast, "a compact card keeps the name, the pill and the cast line")
assert(g.cap == nil, "a compact card drops the section cap: five caps reading Boss say nothing")
assert(g.name.h >= 14 and g.cast.h >= Geometry.CAST_LINE, "the name and cast line keep their size")
assert(g.cast.y + g.cast.h <= slots[1].h + 1e-6 and g.name.y >= 1, "everything sits inside the card")
assert(g.health.y >= g.name.y + g.name.h and g.cast.y >= g.health.y + g.health.h, "name, then pill, then cast line")
local tall = Geometry.Frame(s, 318, 120, 1)
assert(tall.cap, "a full-height card still has its cap")

-- The footprint: the layouts reserve the whole column plus the aura room the cards hang to their left -------------
local fw, fh = Layouts.Footprint("DPS", "unitframes.boss")
assert(fh >= element.height, "the boss footprint holds all five cards, got " .. fh .. " for a " .. element.height .. " column")
assert(s.auraPosition == "LEFT", "boss auras hang to the left of the cards, towards the centre")
local room = s.auraColumns * s.auraSize + (s.auraColumns - 1) * s.auraSpacing + 2
assert(fw >= element.width + room, "the footprint covers the cards and their aura room: " .. fw .. " < " .. element.width .. " + " .. room)
assert(fw <= 318, "the column is a rail's width at most, got " .. fw)

-- The live holder at its default size lays the five buttons inside it -------------------------------------------
local _, _, hw, hh = K.Layout.Rect("unitframes.boss")
assert(near(hw, element.width) and near(hh, element.height), "the holder starts at the column's size")
for i = 1, 5 do
	U.SetUnit(env, "boss" .. i, { name = "Boss " .. i, level = 62, classification = "elite", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
end
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
env.RunTimers()
for i, view in ipairs(uf.views) do
	assert(view.button:IsShown(), "boss" .. i .. " shows")
	local _, _, _, x, y = view.button:GetPoint(1)
	local bw, bh = view.button:GetSize()
	assert(x >= 0 and -y >= 0 and x + bw <= hw + 0.5 and -y + bh <= hh + 0.5, "boss" .. i .. " sits inside the column")
	assert(view.geometry.cast, "boss" .. i .. " has room for its cast line")
end
noErrors("column")

-- Targeted: the boss you target folds its card to the chip; the sigil carries the full read -------------------------

local b1, b2, b3 = uf.views[1], uf.views[2], uf.views[3]
assert(b1.chip and b1.body, "each card has a Targeted chip and a body holding everything the card draws")
assert(b1.castbar.frame:GetParent() == b1.body and b1.panel:GetParent() == b1.body, "the cast line and the glass live in that body")

local function shown(region)
	return region:IsShown() and region:GetAlpha() > 0.5
end
local function muted(view)
	return view.body:GetAlpha() < 0.5
end

env._units.target = env._units.boss1
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(shown(b1.chip) and muted(b1), "boss1 is the target: its card folds to the Targeted chip")
assert(not shown(b2.chip) and not muted(b2), "boss2 keeps its card")
assert(U.Shown(env, b1.chip.text) == K.L["Targeted"], "the chip reads Targeted")
-- Round 4 (Grok #2, Opus #6, Muse D7): the chip names its boss and spans the card's width, a folded card in the column
-- rather than a lone pill beside it.
assert(b1.chip.name and U.Shown(env, b1.chip.name):upper():gsub("[^%w ]", "") == "BOSS 1", "the chip names its boss: " .. U.Shown(env, b1.chip.name))
assert(b1.chip.name:IsShown(), "and shows the name")
do
	local cwidth = b1.chip:GetWidth()
	local bwidth = b1.button:GetWidth()
	assert(near(cwidth, bwidth, 1), "the chip spans the card's width: " .. cwidth .. " of " .. bwidth)
end
-- The chip holds the column's rail-side edge, at the top of the folded slot, so it lines up with the cards still
-- standing and with the rail beside the column instead of floating over the world (round 3: Muse #2, Grok #3).
local point, rel, relPoint, mx, my = b1.chip:GetPoint(1)
assert(point == "TOPRIGHT" and rel == b1.button and relPoint == "TOPRIGHT" and near(mx, 0, 1) and near(my, 0, 1), "the chip sits at the card's top right, the column's rail edge: " .. tostring(point))
-- Round 5 (Fable #5, Grok #3): a 20-unit chip at the top of the slot left a hole the height of a card under it, and
-- with one boss the chip floated alone. The folded card keeps the resting card's place: the chip is as tall as a
-- standing card with no cast and wears the card's glass, with its name and Targeted on its middle line.
do
	local _, restH = b2.panel:GetSize()
	local _, chipH = b1.chip:GetSize()
	assert(not b2.castbar.active and near(chipH, restH, 0.5), "the folded card is as tall as a resting card: " .. chipH .. " of " .. restH)
	assert(b1.chip.chrome.shapeName == b2.chrome.shapeName, "and wears the card's glass, not a tile's: " .. tostring(b1.chip.chrome.shapeName))
	for _, part in ipairs({ b1.chip.name, b1.chip.text }) do
		local p = part:GetPoint(1)
		assert(p == "LEFT" or p == "RIGHT", "the chip's text sits on its middle line: " .. tostring(p))
	end
	local gp, grel, grp = b1.chip.gem:GetPoint(1)
	assert(gp == "LEFT" and grel == b1.chip and grp == "LEFT", "and so does its gem")
end
-- Out of combat the folded card takes clicks only on its chip: the rest of its invisible slot lets them through.
local bw, bh = b1.button:GetSize()
local cw, ch = b1.chip:GetSize()
local l, r, t, b = b1.button:GetHitRectInsets()
assert(near(l, bw - cw) and near(r, 0) and near(t, 0) and near(b, bh - ch), "the folded card's hit rect shrinks to its chip: " .. tostring(l) .. "," .. tostring(r) .. "," .. tostring(t) .. "," .. tostring(b))
l, r, t, b = b2.button:GetHitRectInsets()
assert((l or 0) == 0 and (r or 0) == 0 and (t or 0) == 0 and (b or 0) == 0, "a standing card takes clicks over all of it")

env._units.boss1.cast = { name = "Terrifying Screech", texture = 132127, start = 1000, finish = 3500, spellID = 5000 }
env.FireEvent("UNIT_SPELLCAST_START", "boss1", "Cast-1", 5000)
assert(b1.castbar.frame:IsShown() and muted(b1), "a cast on the targeted boss stays with the sigil: the card's body is not drawn")
env._units.boss1.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "boss1", "Cast-1", 5000)

env._units.target = env._units.boss2
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(not shown(b1.chip) and not muted(b1), "boss1 gets its card back when you target another")
l, r, t, b = b1.button:GetHitRectInsets()
assert(l == 0 and r == 0 and t == 0 and b == 0, "and its whole card takes clicks again")
assert(shown(b2.chip) and muted(b2), "boss2 is now the target")

env._units.target = nil
env.FireEvent("PLAYER_TARGET_CHANGED")
for i, view in ipairs(uf.views) do
	assert(not shown(view.chip) and not muted(view), "boss" .. i .. ": no target, no chip")
end
noErrors("targeted")

-- A boss that turns into the target without a target change (a new encounter unit) is marked too ------------------
env._units.target = env._units.boss3
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
assert(shown(uf.views[3].chip), "a refresh of the boss units marks the target")
env._units.target = nil
env.FireEvent("PLAYER_TARGET_CHANGED")

-- A secret comparison: the answer goes straight to SetAlphaFromBoolean, never into an if ---------------------------
env._secretCompare = true
env._units.target = env._units.boss1
env.FireEvent("PLAYER_TARGET_CHANGED")
local mark = W.LastCall(b1.chip, "SetAlphaFromBoolean")
local mute = W.LastCall(b1.body, "SetAlphaFromBoolean")
assert(mark and env.issecretvalue(mark[1]) and mark[2] == 1 and mark[3] == 0, "a secret answer shows the chip through SetAlphaFromBoolean")
assert(mute and env.issecretvalue(mute[1]) and mute[2] == 0 and mute[3] == 1, "and steps the card back the same way")
assert(env.Reveal(mark[1]) == true, "the secret answer is boss1")
assert(b1.chip:IsShown(), "the chip is shown so its alpha decides")
do
	-- A long boss name drops to the body face, mixed case, before it truncates in the chip.
	local D = dofile("Tools/regression/databars_env.lua")
	env._textWidth = D.TextWidth
	env._units.boss1.name = "Bloodtalon Matriarch"
	env._secretCompare = false
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env._secretCompare = true
	local chipW = b1.chip:GetWidth()
	local tw = b1.chip.text:GetUnboundedStringWidth()
	local nw = b1.chip.name:GetUnboundedStringWidth()
	assert(nw and tw and nw + tw + 30 < chipW, "the long name fits beside Targeted: " .. tostring(nw) .. " + " .. tostring(tw) .. " in " .. chipW)
	assert(U.Shown(env, b1.chip.name) == "Bloodtalon Matriarch", "in mixed case: " .. U.Shown(env, b1.chip.name))
	env._textWidth = nil
end
-- A targeted boss renamed in place (a phase change) renames its chip without a target change.
env._secretCompare = false
env._units.boss1.name = "Boss One Reborn"
env.FireEvent("UNIT_NAME_UPDATE", "boss1")
assert(U.Shown(env, b1.chip.name):upper():gsub("[^%u ]", "") == "BOSS ONE REBORN", "the chip follows a name update: " .. U.Shown(env, b1.chip.name))
env._secretCompare = true
env.FireEvent("PLAYER_TARGET_CHANGED")
env._units.boss1.name = env.Secret("Boss 1")
env.FireEvent("PLAYER_TARGET_CHANGED")
local named = W.LastCall(b1.chip.name, "SetText")
assert(named and env.issecretvalue(named[1]), "a secret boss name reaches the chip's SetText untouched")
env._units.boss1.name = "Boss 1"
env._secretCompare = false
env._units.target = nil
env.FireEvent("PLAYER_TARGET_CHANGED")
noErrors("secret")

-- The card folds whenever the sigil shows the boss: the target's cast line is the player's own choice for any target,
-- so turning it off no longer brings the duplicate card back (round 3, Muse D6). With the target frame off the boss
-- card keeps its own read.
env._units.target = env._units.boss1
K.Options.Write("UnitFrames", "target.castbar", false)
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(shown(b1.chip) and muted(b1), "no target cast line: the sigil still shows the boss, so its card stays folded")
K.Options.Write("UnitFrames", "target.castbar", true)
assert(shown(b1.chip) and muted(b1), "the target's cast line back on: the card stays folded")
K.Options.Write("UnitFrames", "target.enabled", false)
env.RunTimers()
assert(not shown(b1.chip) and not muted(b1), "no target frame: the boss card keeps its own read")
K.Options.Write("UnitFrames", "target.enabled", true)
env.RunTimers()
env._units.target = nil
env.FireEvent("PLAYER_TARGET_CHANGED")
noErrors("no sigil cast")

-- No combat lockdown is needed for the fold: the chip and the body are plain frames, so the swap runs mid-pull. The
-- secure button's hit rect is protected, so it opens to the whole card as combat starts and waits for the end of it.
env._units.target = env._units.boss1
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(select(4, b1.button:GetHitRectInsets()) > 0, "out of combat the folded card clicks on its chip only")
env.SetCombat(true)
l, r, t, b = b1.button:GetHitRectInsets()
assert(l == 0 and r == 0 and t == 0 and b == 0, "combat opens the folded card's whole slot before lockdown")
env._units.target = env._units.boss2
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(shown(b2.chip) and muted(b2), "the swap happens in combat")
l, r, t, b = b2.button:GetHitRectInsets()
assert(l == 0 and r == 0 and t == 0 and b == 0, "in combat no hit rect changes")
-- Round 5 (Muse #7): the hit rect is protected in combat, and restricted code has no UnitIsUnit to shrink it from
-- (Blizzard_RestrictedAddOnEnvironment/RestrictedEnvironment.lua), so a mid-pull swap cannot shrink it. Instead the
-- folded card draws where a resting card draws: in combat it takes clicks over exactly the slot a standing card with
-- no cast takes them over, its glass covering the same part, so no full card's worth of invisible rect is left.
do
	local slotW, slotH = b2.button:GetSize()
	local standW, standH = b3.button:GetSize()
	local _, chipH = b2.chip:GetSize()
	local _, restH = b3.panel:GetSize()
	assert(near(slotW, standW) and near(slotH, standH), "the folded slot is a standing card's slot")
	assert(near(chipH, restH, 0.5), "and its glass covers what a resting card's covers: " .. chipH .. " of " .. restH)
	local sl, sr, st, sb = b3.button:GetHitRectInsets()
	assert((sl or 0) == 0 and (sr or 0) == 0 and (st or 0) == 0 and (sb or 0) == 0, "a standing card takes clicks over its whole slot too")
end
env.SetCombat(false)
assert(select(4, b2.button:GetHitRectInsets()) > 0, "after combat the folded card shrinks to its chip again")
noErrors("combat")

-- Round 6 (Grok #4): the column grows up from its foot when boss.growth is UP, so boss1, alone in most pulls, sits at
-- the foot by the combat cluster instead of alone at the top of the screen; the slots keep their size and gap.
do
	local w, h = element.width, element.height
	local down = Geometry.Slots(Geometry.BOSS_COUNT, Geometry.BOSS_GAP, w, h)
	local up = Geometry.Slots(Geometry.BOSS_COUNT, Geometry.BOSS_GAP, w, h, true)
	assert(near(up[1].y + up[1].h, h, 1e-6) and near(up[5].y, 0, 1e-6), "growing up, boss1 is the foot slot and boss5 the top")
	for i = 1, Geometry.BOSS_COUNT do
		assert(near(up[i].h, down[i].h, 1e-6) and near(up[i].y, down[Geometry.BOSS_COUNT + 1 - i].y, 1e-6), "growing up reverses the order, slot " .. i)
	end
	K.Options.Write("UnitFrames", "boss.growth", "UP")
	env.RunTimers()
	local holder = uf.holder
	local _, columnH = holder:GetSize()
	local at = { uf.views[1].button:GetPoint(1) }
	local _, cardH = uf.views[1].button:GetSize()
	assert(at[1] == "TOPLEFT" and at[2] == holder and near(-at[5] + cardH, columnH, 0.5), "boss1's card stands at the column's foot, got y " .. tostring(at[5]))
	at = { uf.views[5].button:GetPoint(1) }
	assert(near(at[5], 0, 0.5), "boss5 heads the column")
	K.Options.Write("UnitFrames", "boss.growth", "DOWN")
	env.RunTimers()
	at = { uf.views[1].button:GetPoint(1) }
	assert(near(at[5], 0, 0.5), "growing down, boss1 heads the column again")
	noErrors("growth")
end

print("unitframes boss ok")
