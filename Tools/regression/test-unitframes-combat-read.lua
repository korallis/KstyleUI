-- test-unitframes-combat-read.lua: the combat centre reads at a glance (round 2: Astra #4, Opus #4, Grok #2, Muse #1): readable cast text over a smaller name; the target's Medallions cast bar greys while the cast cannot be interrupted, through the engine's flag, secret or not; and the boss you target collapses to a slim Targeted chip.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({ lumen = true })
local Settings, Frames, CastBars = ns.Settings, ns.Frames, ns.CastBars

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
assert(Settings.Snapshot("target").fonts.cast.size >= 13, "the sigil's cast text is at least 13, got " .. Settings.Snapshot("target").fonts.cast.size)
assert(defaults.boss.fonts.cast.size >= 12 and defaults.focus.fonts.cast.size >= 12, "the card cast text is at least 12")
assert(Settings.Snapshot("target").fonts.name.size / Settings.Snapshot("target").fonts.cast.size <= 1.35, "the sigil's name is at most a third larger than its cast")
assert(Settings.Value("focus", "auraPosition") == "ABOVE", "the focus card's debuffs sit over it, inside the layouts' reserve")

-- The target's Medallions cast bar: grey while you cannot interrupt the cast ---------------------------------------

U.SetUnit(env, "target", { name = "Bloodtalon Matriarch", level = 38, classification = "elite", creature = "Beast", health = 620, healthMax = 1000, reaction = 2, canAttack = true,
	cast = { name = "Terrifying Screech", texture = 132127, start = 1000, finish = 3500, spellID = 5000 } })
env.SetTarget(true)
env.RunTimers()
local line = CastBars.Inline("target")[1]
assert(line.frame:IsShown(), "the target's cast bar shows")
local open = line.bar.colorRGBA
env.FireEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
assert(sameColor(line.bar.colorRGBA, K.Tokens.Color("textDisabled")), "the cast turns uninterruptible: the bar goes grey")
env.FireEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "target")
assert(sameColor(line.bar.colorRGBA, open[1], open[2], open[3]), "interruptible again: its colour is back")
env._units.target.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-1", 5000)
settle()

env._units.target.cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, notInterruptible = true, spellID = 999 }
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-2", 999)
assert(sameColor(line.bar.colorRGBA, K.Tokens.Color("textDisabled")), "a cast that starts uninterruptible is grey at once")
env._units.target.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-2", 999)
settle()

-- A secret flag never meets an if: the bar takes its colour from it.
env._units.target.secretCast = true
env._units.target.cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, notInterruptible = true, spellID = 999 }
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-3", 999)
local tint = W.LastCall(line.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
assert(tint and env.issecretvalue(tint[1]), "the bar takes its colour from the same flag")
env._units.target.cast = nil
env._units.target.secretCast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-3", 999)
settle()
noErrors("locked")

-- Boss frames: the targeted boss collapses to a slim chip -----------------------------------------------------------

local uf = Frames.Get("boss")
for i = 1, 2 do
	U.SetUnit(env, "boss" .. i, { name = "Boss " .. i, level = 38, classification = "elite", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
end
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
settle()
local b1, b2 = uf.views[1], uf.views[2]
local idleH = select(2, b2.panel:GetSize())

env._units.target = env._units.boss1
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(b1.body and b1.chip, "each boss card has a body and a Targeted chip")
assert(b1.body:GetAlpha() < 0.5 and visible(b1.chip), "the targeted boss steps its card back to the chip")
assert(U.Shown(env, b1.chip.text) == K.L["Targeted"], "the chip reads Targeted")
local chipW, chipH = b1.chip:GetSize()
-- Round 4 (Grok #2, Muse D7, Opus #13) reversed round 3's hugging pill, which read as orphaned beside the column: the
-- chip is a strip as wide as the card, naming its boss. Round 5 (Fable #5, Grok #3) closed the hole the slim strip
-- left under it: the chip is as tall as the card at rest, so the folded card keeps the column's rhythm.
assert(near(chipH, idleH, 0.5), "the chip is as tall as a resting card: " .. chipH .. " of " .. idleH)
assert(near(chipW, select(1, b1.button:GetSize()), 1), "the chip spans the card's width: " .. chipW)
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
