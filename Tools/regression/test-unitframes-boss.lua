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

local b1, b2 = uf.views[1], uf.views[2]
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
local _, _, _, mx, my = b1.chip:GetPoint(1)
assert(near(mx, 0, 1) and near(my, 0, 1), "the chip sits at the card's top left")

env._units.boss1.cast = { name = "Terrifying Screech", texture = 132127, start = 1000, finish = 3500, spellID = 5000 }
env.FireEvent("UNIT_SPELLCAST_START", "boss1", "Cast-1", 5000)
assert(b1.castbar.frame:IsShown() and muted(b1), "a cast on the targeted boss stays with the sigil: the card's body is not drawn")
env._units.boss1.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "boss1", "Cast-1", 5000)

env._units.target = env._units.boss2
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(not shown(b1.chip) and not muted(b1), "boss1 gets its card back when you target another")
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
env._secretCompare = false
env._units.target = nil
env.FireEvent("PLAYER_TARGET_CHANGED")
noErrors("secret")

-- The card folds only for a sigil that shows the cast: with the target's cast line or frame off, the boss card keeps
-- its own read and shows no chip, so the cast never disappears from the screen.
env._units.target = env._units.boss1
K.Options.Write("UnitFrames", "target.castbar", false)
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(not shown(b1.chip) and not muted(b1), "no target cast line: the boss card keeps its own")
K.Options.Write("UnitFrames", "target.castbar", true)
assert(shown(b1.chip) and muted(b1), "the target's cast line back on: the card folds again at once")
K.Options.Write("UnitFrames", "target.enabled", false)
env.RunTimers()
assert(not shown(b1.chip) and not muted(b1), "no target frame: the boss card keeps its own read")
K.Options.Write("UnitFrames", "target.enabled", true)
env.RunTimers()
env._units.target = nil
env.FireEvent("PLAYER_TARGET_CHANGED")
noErrors("no sigil cast")

-- No combat lockdown is needed: the chip and the body are plain frames, so the swap runs mid-pull -----------------
env.SetCombat(true)
env._units.target = env._units.boss2
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(shown(b2.chip) and muted(b2), "the swap happens in combat")
env.SetCombat(false)
noErrors("combat")

print("unitframes boss ok")
