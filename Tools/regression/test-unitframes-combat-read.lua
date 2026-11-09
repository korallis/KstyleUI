-- test-unitframes-combat-read.lua: the combat centre reads at a glance (round 2: Astra #4, Opus #4, Grok #2, Muse #1): the sigil and card cast lines are bold, with readable text over a smaller name; an uninterruptible cast reads Locked in grey through the engine's flag, secret or not; a dark scrim backs the sigil's text over bright sky; the boss you target collapses to a slim Targeted chip; and a boss card with no cast hugs its pill.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local Settings, Geometry, Frames, CastBars = ns.Settings, ns.Geometry, ns.Frames, ns.CastBars
local Layouts = K.Setup.Layouts

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function visible(region)
	return region:IsShown() and region:GetAlpha() > 0.5
end

local function sameColor(rgba, r, g, b)
	return rgba ~= nil and near(rgba[1], r) and near(rgba[2], g) and near(rgba[3], b)
end

-- Cast text and lines: readable minimums, the name no longer drowns the cast ------------------------------------

local defaults = Settings.defaults
assert(defaults.target.fonts.cast.size >= 13, "the sigil's cast text is at least 13, got " .. defaults.target.fonts.cast.size)
assert(defaults.boss.fonts.cast.size >= 12 and defaults.focus.fonts.cast.size >= 12, "the card cast text is at least 12")
assert(defaults.target.fonts.name.size / defaults.target.fonts.cast.size <= 1.35, "the sigil's name is at most a third larger than its cast")
local target = Layouts.Element("unitframes.target")
local sigil = Geometry.Frame(Settings.Snapshot("target"), target.width, target.height, 1)
assert(sigil.cast and sigil.cast.h >= 16, "the sigil keeps a bold 16-unit cast line")
assert(sigil.name and sigil.caption and sigil.health, "and its name, level line and pill")
local slots = Geometry.Slots(Geometry.BOSS_COUNT, Geometry.BOSS_GAP, 258, 334)
local card = Geometry.Frame(Settings.Snapshot("boss"), slots[1].w, slots[1].h, 1)
assert(card.cast and card.cast.h >= 16, "a boss card keeps a bold 16-unit cast line")
local focusElement = Layouts.Element("unitframes.focus")
local focusCard = Geometry.Frame(Settings.Snapshot("focus"), focusElement.width, focusElement.height, 1)
assert(focusCard.cast and focusCard.cast.h >= 16 and focusCard.cap, "the focus card keeps its cap and a bold cast line")
assert(Geometry.Frame(Settings.Snapshot("focus"), focusElement.width - 0.5, focusElement.height - 0.5, 1).cap, "the focus card keeps its cap after pixel snapping shaves a fraction off")
local vitals = Geometry.Frame(Settings.Snapshot("player"), 490, 80, 1)
assert(vitals.cast and vitals.cast.h <= 14, "your own vitals line keeps its thin cast line")
assert(Settings.Value("focus", "auraPosition") == "ABOVE", "the focus card's debuffs sit over it, inside the layouts' reserve")

-- The sigil's cast line: a 6-unit bar, gold while you can interrupt it, grey and Locked while you cannot -----------

U.SetUnit(env, "target", { name = "Bloodtalon Matriarch", level = 38, classification = "elite", creature = "Beast", health = 620, healthMax = 1000, reaction = 2, canAttack = true,
	cast = { name = "Terrifying Screech", texture = 132127, start = 1000, finish = 3500, spellID = 5000 } })
env.SetTarget(true)
env.RunTimers()
local line = CastBars.Inline("target")[1]
assert(line.frame:IsShown(), "the sigil's cast line shows")
assert(line.bar.opts.height >= 6, "the sigil's cast bar is at least 6 units thick, got " .. tostring(line.bar.opts.height))
assert(line.lock, "the cast line has a Locked label")
assert(visible(line.label) and not visible(line.lock), "an interruptible cast reads Casting")
local gr, gg, gb = ns.Lumen.Color("cast")
assert(sameColor(line.bar.colorRGBA, gr, gg, gb), "in gold")
assert(U.Shown(env, line.lock) == K.L["Locked"], "the lock reads Locked")

env.FireEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
assert(visible(line.lock) and not visible(line.label), "the cast turns uninterruptible: Locked replaces Casting")
assert(sameColor(line.bar.colorRGBA, K.Tokens.Color("textDisabled")), "and the bar goes grey")
env.FireEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "target")
assert(visible(line.label) and not visible(line.lock), "interruptible again: Casting is back")
-- A narrow cast line (the focus card's) drops its timer before it cuts the spell's name: the name is the urgent part.
CastBars.Layout(line, 168, 16)
assert(not line.timer:IsShown(), "a narrow line hides its timer")
local kept = line.text:GetWidth()
assert(kept == 0 or kept >= 72, "and leaves the spell's name at least 72 units, five and a half letters' widths more than with the timer: " .. tostring(kept))
CastBars.Layout(line, 294, 16)
assert(line.timer:IsShown(), "a wide line keeps its timer")
env._units.target.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-1", 5000)
settle()

env._units.target.cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, notInterruptible = true, spellID = 999 }
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-2", 999)
assert(visible(line.lock) and not visible(line.label), "a cast that starts uninterruptible reads Locked at once")
env._units.target.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-2", 999)
settle()

-- A secret flag never meets an if: the labels take their alpha from it, the bar its colour.
env._units.target.secretCast = true
env._units.target.cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, notInterruptible = true, spellID = 999 }
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-3", 999)
local lockCall, labelCall = W.LastCall(line.lock, "SetAlphaFromBoolean"), W.LastCall(line.label, "SetAlphaFromBoolean")
assert(lockCall and env.issecretvalue(lockCall[1]) and lockCall[2] == 1 and lockCall[3] == 0, "a secret flag shows Locked through SetAlphaFromBoolean")
assert(labelCall and env.issecretvalue(labelCall[1]) and labelCall[2] == 0 and labelCall[3] == 1, "and steps Casting back the same way")
assert(line.lock:IsShown() and line.label:IsShown(), "both labels are shown so their alpha decides")
local tint = W.LastCall(line.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
assert(tint and env.issecretvalue(tint[1]), "the bar takes its colour from the same flag")
env._units.target.cast = nil
env._units.target.secretCast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-3", 999)
settle()
noErrors("locked")

-- The scrim: a soft dark glow behind the sigil's text, so it reads over bright sky; cards and the vitals have none ---

local sigilView = Frames.Get("target").views[1]
local scrim = sigilView.scrim
assert(scrim and scrim:IsShown(), "the sigil has a scrim behind its text")
local sw, sh = scrim:GetSize()
assert(sw >= target.width and sh >= target.height, "the scrim covers the sigil: " .. sw .. " x " .. sh)
local scrimColor = W.LastCall(scrim, "SetVertexColor")
assert(scrimColor and scrimColor[1] <= 0.1 and scrimColor[2] <= 0.1 and scrimColor[3] <= 0.15, "the scrim is dark")
assert(scrimColor[4] >= 0.3 and scrimColor[4] <= 0.7, "and soft, not a slab: " .. tostring(scrimColor[4]))
assert(not Frames.Get("player").views[1].scrim:IsShown(), "the vitals line, on the hands, has no scrim")

-- Boss cards: the targeted boss collapses to a slim chip; the others hug their pill until they cast ----------------

local uf = Frames.Get("boss")
for i = 1, 2 do
	U.SetUnit(env, "boss" .. i, { name = "Boss " .. i, level = 38, classification = "elite", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
end
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
settle()
local b1, b2 = uf.views[1], uf.views[2]
local slotH = select(2, b1.button:GetSize())
local idleH = select(2, b2.panel:GetSize())
assert(b2.geometry.rest and near(idleH, b2.geometry.rest, 0.5) and idleH < slotH - 10, "a boss card with no cast hugs its pill: " .. idleH .. " of " .. slotH)
env._units.boss2.cast = { name = "Whirlwind", texture = 132369, start = 1000, finish = 3500, spellID = 1680 }
env.FireEvent("UNIT_SPELLCAST_START", "boss2", "Cast-1", 1680)
assert(near(select(2, b2.panel:GetSize()), slotH, 0.5), "a cast opens the card's cast row")
env._units.boss2.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "boss2", "Cast-1", 1680)
settle()
assert(near(select(2, b2.panel:GetSize()), idleH, 0.5), "and the card hugs its pill again when the cast ends")

env._units.target = env._units.boss1
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(b1.body and b1.chip, "each boss card has a body and a Targeted chip")
assert(b1.body:GetAlpha() < 0.5 and visible(b1.chip), "the targeted boss steps its card back to the chip")
assert(U.Shown(env, b1.chip.text) == K.L["Targeted"], "the chip reads Targeted")
local chipW, chipH = b1.chip:GetSize()
assert(chipH <= 24 and chipH >= 14, "the chip is slim: " .. chipH)
assert(chipW <= select(1, b1.button:GetSize()) / 2, "the chip hugs its label, not the card's width: " .. chipW)
local _, _, _, _, cy = b1.chip:GetPoint(1)
assert(near(cy, 0, 1), "the chip sits at the card's top")
assert(b1.chip.chrome, "the chip wears its own small glass")
assert(b2.body:GetAlpha() > 0.5 and not visible(b2.chip), "the other boss keeps its card")
if b1.auras and b1.auras.container then
	assert(b1.auras.container:GetAlpha() < 0.5, "the targeted boss's debuffs step back too: the sigil shows them")
end

-- The boss's auras step back only when the sigil shows the same ones: with the boss cards showing its buffs too and
-- the sigil only your debuffs, a purgeable buff stays on screen beside the chip.
K.Options.Write("UnitFrames", "boss.auraFilter", "both")
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(b1.body:GetAlpha() < 0.5 and visible(b1.chip), "the card still folds")
if b1.auras and b1.auras.container then
	assert(b1.auras.container:GetAlpha() > 0.5, "but the boss's buffs, which the sigil does not show, stay")
end
K.Options.Write("UnitFrames", "target.auraFilter", "both")
env.FireEvent("PLAYER_TARGET_CHANGED")
if b1.auras and b1.auras.container then
	assert(b1.auras.container:GetAlpha() < 0.5, "once the sigil shows them too, they step back")
end
K.Options.Write("UnitFrames", "target.auraFilter", "mine")
K.Options.Write("UnitFrames", "boss.auraFilter", "mine")
env.FireEvent("PLAYER_TARGET_CHANGED")

env._secretCompare = true
env.FireEvent("PLAYER_TARGET_CHANGED")
local body, chip = W.LastCall(b1.body, "SetAlphaFromBoolean"), W.LastCall(b1.chip, "SetAlphaFromBoolean")
assert(body and env.issecretvalue(body[1]) and body[2] == 0 and body[3] == 1, "a secret comparison steps the card back through SetAlphaFromBoolean")
assert(chip and env.issecretvalue(chip[1]) and chip[2] == 1 and chip[3] == 0, "and shows the chip the same way")
env._secretCompare = false
env._units.target = nil
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(b1.body:GetAlpha() > 0.5 and not visible(b1.chip), "no target: the card is back")
noErrors("boss chip")

print("unitframes combat read ok")
