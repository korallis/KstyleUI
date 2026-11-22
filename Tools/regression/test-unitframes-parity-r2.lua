-- test-unitframes-parity-r2.lua: parity round 2 options keep a v0.2.8 profile's look and regions, then write and apply pet auras, aura offsets, stack and timer text, dispel edges, power fill opacity and gradient, boss spacing, cast icon, name and timer offsets, spell targets and important cast outlines, after their events, in combat, off again and in the preview.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local env, K, ns = U.New({
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true, target = { auraSize = 24, auraColumns = 6 } } } }, characters = {}, layouts = {} },
	setup = function(e)
		e._important = false
		e.C_Spell.IsSpellImportant = function() return e._important end
		e.UnitShouldDisplaySpellTargetName = function() return e._castTarget ~= nil end
		e.UnitSpellTargetName = function() return e._castTarget end
	end,
})
local Settings = ns.Settings

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
	assert(K.Options.Read("UnitFrames", key) == value, key .. " must round-trip")
end

local function snap(region, units)
	return K.Widgets.Snap(region, units)
end

local function clean()
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Defaults keep today's look and make nothing new.
local DEFAULTS = {
	powerAlpha = 1, powerGradient = "", auraX = 0, auraY = 0, auraTimerX = 0, auraTimerY = 0, auraCountSize = 0,
	auraCountPoint = "TOPRIGHT", auraCountX = 0, auraCountY = 0, auraDispel = true, auraBuffDispel = false, auraStealable = false,
	castbarIconX = 0, castbarIconY = 0, castbarTextX = 0, castbarTextY = 0, castbarTimerX = 0, castbarTimerY = 0,
	castbarTarget = false, castbarImportant = false,
}
for _, kind in ipairs(U.KINDS) do
	for key, value in pairs(DEFAULTS) do
		assert(Settings.Value(kind, key) == value, kind .. "." .. key .. " keeps its default")
	end
	for _, view in ipairs(ns.Frames.Get(kind).views) do
		assert(not (view.castbar and view.castbar.important), kind .. " makes no important outline until it is on")
	end
end
assert(Settings.Value("boss", "gap") == ns.Geometry.BOSS_GAP, "boss frames keep today's gap")
assert(Settings.Value("target", "auraSize") == 24, "a v0.2.8 profile keeps its saved aura size")
local pet = ns.Frames.Get("pet").views[1]
assert(Settings.Value("pet", "auras") == false and pet.auras == nil, "pet auras start off and build nothing")
local rows = {}
for _, row in ipairs(Settings.Schema()) do
	if row.key then rows[row.key] = row end
end
assert(rows["pet.auras"] and rows["pet.auraCountSize"] and not rows["targettarget.auras"], "the pet has aura rows; the polled frames have none")
assert(rows["boss.gap"] and not rows["focus.gap"], "only boss frames have a spacing row")
assert(rows["target.castbarImportant"] and not rows["player.castbarImportant"], "the important outline is for other units' casts")

local target = ns.Frames.Get("target").views[1]
local auras = assert(target.auras, "the target has auras")
local debuff, buff
for _, entry in ipairs(auras.buttons) do
	if entry.key == "debuffs" then debuff = debuff or entry else buff = buff or entry end
end
assert(debuff and buff, "the target has debuff and buff buttons")
local pieces = #debuff.button._aura.dispel
assert(pieces > 0 and not buff.button._aura.dispel, "debuffs keep their dispel edge and buffs have none")

-- Pet auras: built on first use, placed above the frame, sized, off again.
U.SetUnit(env, "pet", { name = "Wolf", level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 })
write("pet.auras", true)
local petAuras = assert(pet.auras and pet.auras.container, "pet auras build when switched on")
assert(pet.auras.host:IsShown(), "pet auras show")
local point = W.LastCall(pet.auras.host, "SetPoint")
assert(point[1] == "BOTTOMLEFT" and point[2] == pet.button and point[3] == "TOPLEFT", "pet auras sit above the frame")
assert(petAuras._groups.debuffs.filter == "HARMFUL" and not petAuras._groups.buffs.enabled, "pet auras show the pet's debuffs")
write("pet.auraFilter", "both")
assert(petAuras._groups.buffs.enabled and petAuras._groups.buffs.filter == "HELPFUL", "and its buffs on request")
write("pet.auraSize", 24)
assert(near(W.LastCall(pet.auras.buttons[1].button, "SetSize")[1], snap(pet.auras.host, 24)), "the aura size reaches the pet's icons")
U.SetUnit(env, "pet", nil)
assert(not pet.auras.host:IsShown(), "dismissing the pet hides its auras")
U.SetUnit(env, "pet", { name = "Wolf", level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 })
assert(pet.auras.host:IsShown(), "a new pet shows them again")
write("pet.auras", false)
assert(not pet.auras.host:IsShown() and not petAuras._enabled, "turning pet auras off hides and stops them")

-- Aura block offsets move the whole block, and off returns it.
local host = auras.host
local before = W.LastCall(host, "SetPoint")
write("target.auraX", 10)
write("target.auraY", -6)
local moved = W.LastCall(host, "SetPoint")
assert(near(moved[4] - before[4], snap(host, 10)) and near(moved[5] - before[5], snap(host, -6)), "the aura offsets move the block")
write("target.auraX", 0)
write("target.auraY", 0)
moved = W.LastCall(host, "SetPoint")
assert(moved[1] == before[1] and moved[4] == before[4] and moved[5] == before[5], "zero offsets restore the block's place")

-- Stack text: size, corner and offsets; the timer keeps the aura text size.
local _, timerSize = debuff.timer:GetFont()
local _, countSize = debuff.count:GetFont()
assert(near(countSize, timerSize), "stacks start at the aura text size")
write("target.auraCountSize", 14)
_, countSize = debuff.count:GetFont()
assert(near(countSize, 14 * K.Theme.FontScale()) and near(select(2, debuff.timer:GetFont()), timerSize), "the stack size reaches stacks only")
local inset = snap(debuff.skin, 1)
write("target.auraCountPoint", "TOPLEFT")
write("target.auraCountX", 3)
point = W.LastCall(debuff.count, "SetPoint")
assert(point[1] == "TOPLEFT" and near(point[4], snap(debuff.skin, 3) - inset), "the stack moves to the top left, nudged right")
assert(W.LastCall(debuff.count, "SetJustifyH")[1] == "LEFT", "a left stack aligns left")
local timerBefore = W.LastCall(debuff.timer, "SetPoint")
write("target.auraTimerY", 4)
local timerAfter = W.LastCall(debuff.timer, "SetPoint")
assert(near(timerAfter[5] - timerBefore[5], snap(debuff.skin, 4)), "the timer offset moves the timer")
env.SetCombat(true)
write("target.auraCountX", 0)
assert(near(W.LastCall(debuff.count, "SetPoint")[4], snap(debuff.skin, 3) - inset), "a combat change waits for readable auras")
env.SetCombat(false)
env.RunTimers()
assert(near(W.LastCall(debuff.count, "SetPoint")[4], -inset), "combat's end applies it")
write("target.auraCountPoint", "TOPRIGHT")
write("target.auraCountSize", 0)
write("target.auraTimerY", 0)
point = W.LastCall(debuff.count, "SetPoint")
assert(point[1] == "TOPRIGHT" and near(point[4], inset) and near(point[5], inset), "the default corner returns")
assert(W.LastCall(debuff.count, "SetJustifyH")[1] == "RIGHT" and near(select(2, debuff.count:GetFont()), timerSize), "and its alignment and size")
assert(W.LastCall(debuff.timer, "SetPoint")[5] == timerBefore[5], "and the timer's place")

-- Dispel edges: debuff edges off and on, buff edges, stealable buffs only.
write("target.auraDispel", false)
assert(#debuff.button._aura.dispel == 0, "debuff dispel edges are removed")
for _, piece in ipairs(debuff.dispel) do assert(not piece:IsShown(), "and hidden") end
write("target.auraDispel", true)
assert(#debuff.button._aura.dispel == pieces and debuff.button._aura.dispelOptions.showWhenHarmful, "debuff edges return as before")
write("target.auraBuffDispel", true)
local options = buff.button._aura.dispelOptions
assert(#buff.button._aura.dispel == pieces and options.showWhenHelpful and options.stealableFilter == nil, "buffs get dispel edges")
write("target.auraStealable", true)
options = buff.button._aura.dispelOptions
assert(#buff.button._aura.dispel == pieces and options.stealableFilter == env.Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable, "stealable buffs only, not doubled")
write("target.auraBuffDispel", false)
assert(#buff.button._aura.dispel == 0, "buff edges are removed when off")
write("target.auraStealable", false)

-- Power fill opacity and gradient follow power-type changes; off restores the flat colour.
local player = ns.Frames.Get("player").views[1]
local power = player.power
assert(W.LastCall(power, "SetStatusBarColor").n == 3, "the power fill starts solid")
write("player.powerAlpha", 0.5)
assert(W.LastCall(power, "SetStatusBarColor")[4] == 0.5, "fill opacity reaches the power fill")
env.FireEvent("UNIT_DISPLAYPOWER", "player")
assert(W.LastCall(power, "SetStatusBarColor")[4] == 0.5, "a power type change keeps it")
write("player.powerGradient", "VERTICAL")
local fill = power:GetStatusBarTexture()
local shaded = W.LastCall(fill, "SetGradient")
assert(shaded and shaded[1] == "VERTICAL" and near(shaded[3].a, 0.5), "the gradient shades the power fill")
local gradients = #W.Calls(fill, "SetGradient")
env.FireEvent("UNIT_DISPLAYPOWER", "player")
assert(#W.Calls(fill, "SetGradient") > gradients, "a power type change reapplies it")
write("player.powerGradient", "")
write("player.powerAlpha", 1)
gradients = #W.Calls(fill, "SetGradient")
env.FireEvent("UNIT_DISPLAYPOWER", "player")
assert(#W.Calls(fill, "SetGradient") == gradients and W.LastCall(power, "SetStatusBarColor").n == 3, "off repaints the flat solid colour")

-- Boss spacing re-slots the frames inside the element, and waits for combat's end.
local boss = ns.Frames.Get("boss")
local w, h = boss.holder:GetSize()
write("boss.gap", 12)
local slots = ns.Geometry.Slots(5, 12, w, h)
assert(near(-W.LastCall(boss.views[2].button, "SetPoint")[5], snap(boss.views[2].button, slots[2].y)), "the second boss moves by the new gap")
env.SetCombat(true)
write("boss.gap", 6)
assert(near(-W.LastCall(boss.views[2].button, "SetPoint")[5], snap(boss.views[2].button, slots[2].y)), "secure frames wait for combat's end")
env.SetCombat(false)
env.RunTimers()
slots = ns.Geometry.Slots(5, 6, w, h)
assert(near(-W.LastCall(boss.views[2].button, "SetPoint")[5], snap(boss.views[2].button, slots[2].y)), "combat's end restores the gap")

-- Cast offsets: the Medallions player cast bar's name and timer.
local cb = ns.CastBars.Inline("player")[1]
local text0, timer0 = W.LastCall(cb.text, "SetPoint"), W.LastCall(cb.timer, "SetPoint")
write("player.castbarTextX", 6)
write("player.castbarTimerY", 2)
assert(near(W.LastCall(cb.text, "SetPoint")[4] - text0[4], snap(cb.frame, 6)), "the name moves")
assert(near(W.LastCall(cb.timer, "SetPoint")[5] - timer0[5], snap(cb.frame, 2)), "the timer moves")
write("player.castbarTextX", 0)
write("player.castbarTimerY", 0)
assert(W.LastCall(cb.text, "SetPoint")[4] == text0[4] and W.LastCall(cb.timer, "SetPoint")[5] == timer0[5], "zero offsets restore them")

-- Spell target after the name, including a secret name; off removes it.
local tcb = ns.CastBars.Inline("target")[1]
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, reaction = 2, canAttack = true })
env._castTarget = "Valerin"
write("target.castbarTarget", true)
env._units.target.cast = { name = "Shadow Bolt", texture = 1, start = 1000, finish = 3000, spellID = 686 }
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
assert(U.Shown(env, tcb.text):gsub("\226\128\137", ""):find("SHADOW BOLT - Valerin", 1, true), "the target follows the name: " .. U.Shown(env, tcb.text))
env._castTarget = env.Secret("Ogre")
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
assert(U.Shown(env, tcb.text):find(" - Ogre", 1, true), "a secret target name still shows")
env._castTarget = nil
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
assert(not U.Shown(env, tcb.text):find(" - ", 1, true), "no shown target, no suffix")
env._castTarget = "Valerin"
write("target.castbarTarget", false)
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
assert(not U.Shown(env, tcb.text):find("Valerin", 1, true), "off removes the target")

-- Important cast outline: lazily made, readable and secret answers, hidden when the cast ends or the option goes off.
write("target.castbarImportant", true)
env._important = true
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
local glow = assert(tcb.important, "an important cast makes the outline")
assert(glow:IsShown() and glow:GetAlpha() == 1, "an important cast shows it")
env._important = false
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
assert(not glow:IsShown(), "an ordinary cast hides it")
env._important = env.Secret(true)
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
assert(glow:IsShown() and W.LastCall(glow, "SetAlphaFromBoolean"), "a secret answer drives the alpha")
env._important = true
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
K.Options.Write("UnitFrames", "target.castbarImportantColor", { r = 0, g = 1, b = 0 })
env.RunTimers()
local piece = W.LastCall(glow.line[1], "SetVertexColor")
assert(piece and piece[1] == 0 and piece[2] == 1, "the outline takes its colour")
env._units.target.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-1", 686)
assert(not glow:IsShown(), "the outline goes with the cast")
env.RunTimers()
env._units.target.cast = { name = "Shadow Bolt", texture = 1, start = 1000, finish = 3000, spellID = 686 }
write("target.castbarImportant", false)
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
assert(not glow:IsShown(), "off keeps it hidden")
env._units.target.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-1", 686)
env.RunTimers()

-- The preview reflects each option.
write("edit", "player")
local pane = ns.Preview.Build(env.UIParent)
write("player.powerAlpha", 0.5)
pane:Refresh()
assert(W.LastCall(pane.views.player.power, "SetStatusBarColor")[4] == 0.5, "the preview power fill takes its opacity")
write("edit", "pet")
write("pet.auras", true)
pane:Refresh()
assert(pane.auraCount > 0 and pane.auraHosts.pet:IsShown(), "the pet preview shows its auras")
write("edit", "target")
write("target.auraCountPoint", "TOPLEFT")
pane:Refresh()
assert(W.LastCall(pane.auraTiles.target[2].count, "SetPoint")[1] == "TOPLEFT", "the preview stacks take their corner")
clean()
print("test-unitframes-parity-r2: ok")
