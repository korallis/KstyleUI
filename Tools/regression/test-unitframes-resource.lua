-- test-unitframes-resource.lua: combo points draw as one-point status bars fed the secret count, and the druid's mana shows in bear and cat form.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function rogue(env)
	env._units.player.class = "ROGUE"
	env._units.player.powerType, env._units.player.powerToken = 3, "ENERGY"
end

local env, K, ns = U.New({ setup = rogue })
local Resource = ns.Resource
local state = Resource.state

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

-- Layout: one element under the player frame.
local found
for _, el in ipairs(K.Layout.Elements()) do
	if el.key == "unitframes.resource" then
		found = el
	end
end
assert(found and found.module == "UnitFrames" and found.opts.resizable, "the class resource is a resizable Layout element")
assert(found.label == K.Setup.Layouts.Element("unitframes.resource").label, "with the setup's label")

-- A rogue gets five pips, each a status bar from i - 1 to i, so the engine compares the count.
assert(state.showCombo and not state.showMana and state.content:IsShown(), "a rogue sees combo points")
for i, pip in ipairs(state.pips) do
	local range = W.LastCall(pip, "SetMinMaxValues")
	assert(range[1] == i - 1 and range[2] == i, "pip " .. i .. " spans one point")
	assert(pip:IsShown(), "pip " .. i .. " shows")
end
env._restricted = true
env._comboPoints = 3
env.FireEvent("COMBO_TARGET_CHANGED")
for i, pip in ipairs(state.pips) do
	local value = W.LastCall(pip, "SetValue")[1]
	assert(env.issecretvalue(value) and env.Reveal(value) == 3, "pip " .. i .. " gets the secret count itself")
end
env._comboPoints = 5
env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
assert(env.Reveal(W.LastCall(state.pips[5], "SetValue")[1]) == 5, "power events update the pips")
env._restricted = false
noErrors("rogue")

-- Pips sit in one row, left to right, inside the element.
local x1 = select(4, state.pips[1]:GetPoint(1))
local x5 = select(4, state.pips[5]:GetPoint(1))
assert(x1 >= 0 and x5 > x1, "the pips run left to right")

-- At the smallest allowed size and the widest spacing, every pip stays inside the element.
K.Options.Write("UnitFrames", "resource.spacing", 12)
assert(K.Layout.Set("unitframes.resource", "width", 40) and K.Layout.Set("unitframes.resource", "height", 4))
for i, pip in ipairs(state.pips) do
	local x = select(4, pip:GetPoint(1))
	local w, h = pip:GetSize()
	assert(x >= -1e-6 and x + w <= 40 + 1e-6 and h <= 4 + 1e-6, "pip " .. i .. " stays inside a 40 by 4 element")
end
K.Layout.Reset("unitframes.resource")
K.Options.Write("UnitFrames", "resource.spacing", 3)

-- Combo point colour follows the class accent, or a custom colour.
local ar = K.Theme.Accent()
assert(W.LastCall(state.pips[1], "SetStatusBarColor")[1] == ar, "pips take the class accent")
K.Options.Write("UnitFrames", "resource.comboColor", "custom")
K.Options.Write("UnitFrames", "resource.comboCustom", { r = 0.1, g = 0.9, b = 0.2 })
local c = W.LastCall(state.pips[1], "SetStatusBarColor")
assert(c[1] == 0.1 and c[2] == 0.9 and c[3] == 0.2, "pips take a custom colour")

-- Switching the element off hides it.
K.Options.Write("UnitFrames", "resource.enabled", false)
assert(not state.content:IsShown(), "the class resource hides when switched off")
K.Options.Write("UnitFrames", "resource.enabled", true)
assert(state.content:IsShown(), "and shows again")
noErrors("settings")

-- A mage has no class resource.
local mage = U.New({ setup = function(e)
	e._units.player.class = "MAGE"
end })
assert(mage._addons.KstyleUI_UnitFrames.Resource.state.content:IsShown() == false, "a mage sees nothing")

-- A druid: mana in bear and cat form, combo points in cat form only, nothing in caster form.
local denv, DK, dns = U.New({ setup = function(e)
	e._units.player.class = "DRUID"
	e._units.player.powerType, e._units.player.powerToken = 0, "MANA"
	e._units.player.powers = { [0] = 1500 }
	e._units.player.powerMaxes = { [0] = 3000 }
end })
local d = dns.Resource.state
assert(not d.showCombo and not d.showMana and not d.content:IsShown(), "caster form: nothing")
denv._units.player.powerType, denv._units.player.powerToken = 1, "RAGE"
denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
assert(d.showMana and not d.showCombo, "bear form: mana only")
local value, low, high = U.Bar(denv, d.mana)
assert(value == 1500 and low == 0 and high == 3000, "the mana bar reads mana, not rage")
denv._units.player.powerType, denv._units.player.powerToken = 3, "ENERGY"
denv.FireEvent("UNIT_DISPLAYPOWER", "player")
assert(d.showMana and d.showCombo, "cat form: combo points and mana")
assert(DK.Layout.Set("unitframes.resource", "height", 4), "the smallest height")
local my = select(5, d.mana:GetPoint(1))
local _, mh = d.mana:GetSize()
assert(-my + mh <= 4 + 1e-6 and -my >= -1e-6, "in cat form at 4 units tall the mana bar stays inside")
for _, pip in ipairs(d.pips) do
	local py = select(5, pip:GetPoint(1))
	assert(py <= 1e-6, "pips stay inside too")
end
DK.Layout.Reset("unitframes.resource")
denv._units.player.powers[0] = 900
denv.FireEvent("UNIT_POWER_FREQUENT", "player", "MANA")
assert(U.Bar(denv, d.mana) == 900, "mana updates in cat form")
assert(W.LastCall(d.mana, "SetOrientation")[1] == "HORIZONTAL" and W.LastCall(d.mana, "SetReverseFill")[1] == false, "the mana bar fills left to right by default")
DK.Options.Write("UnitFrames", "resource.manaOrientation", "LEFT")
assert(W.LastCall(d.mana, "SetOrientation")[1] == "HORIZONTAL" and W.LastCall(d.mana, "SetReverseFill")[1] == true, "the mana bar can fill right to left")
DK.Options.Write("UnitFrames", "resource.manaOrientation", "UP")
assert(W.LastCall(d.mana, "SetOrientation")[1] == "VERTICAL" and W.LastCall(d.mana, "SetReverseFill")[1] == false, "or bottom to top")
DK.Options.Write("UnitFrames", "resource.manaOrientation", "RIGHT")
DK.Options.Write("UnitFrames", "resource.druidMana", false)
assert(not d.showMana and d.showCombo, "druid mana can be switched off")
assert(#denv._errors == 0, "druid: " .. tostring(denv._errors[1]))

-- UNIT_POWER_FREQUENT, the busiest unit event, is registered only while the element shows something.
local function powerListeners(e)
	local n = 0
	for _, frame in ipairs(e._frames) do
		if frame._events.UNIT_POWER_FREQUENT then
			n = n + 1
		end
	end
	return n
end
assert(powerListeners(env) == 1, "a rogue listens to power events")
K.Options.Write("UnitFrames", "resource.enabled", false)
assert(powerListeners(env) == 0, "with the class resource off, nothing listens to power events")
K.Options.Write("UnitFrames", "resource.enabled", true)
assert(powerListeners(env) == 1 and state.showCombo, "turning it back on listens again")
do
	local henv = U.New()
	assert(powerListeners(henv) == 0, "a hunter shows no class resource, so nothing listens to power events")
end
assert(powerListeners(denv) == 1, "a druid in cat form listens for combo points")
noErrors("power events")

-- Stopping the module hides the element and stops its events.
K.Modules.Disable("UnitFrames")
assert(not state.holder:IsShown(), "the element hides with the module")
local calls = #state.pips[1]._calls
env.FireEvent("COMBO_TARGET_CHANGED")
assert(#state.pips[1]._calls == calls, "a stopped module ignores combo events")
noErrors("disable")

print("unitframes resource ok")
