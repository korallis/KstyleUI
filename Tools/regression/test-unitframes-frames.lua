-- test-unitframes-frames.lua: the secure unit frames build on Enable, show their unit's data from secret values, follow settings and Layout, and hide Blizzard's frames.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local ELEMENTS = {
	player = "unitframes.player", target = "unitframes.target", targettarget = "unitframes.targettarget",
	focus = "unitframes.focus", focustarget = "unitframes.focustarget", pet = "unitframes.pet", boss = "unitframes.boss",
}
local UNITS = { player = "player", target = "target", targettarget = "targettarget", focus = "focus", focustarget = "focustarget", pet = "pet" }

local env, K, ns = U.New()
assert(K.Modules.IsRunning("UnitFrames"), "the module runs when its switch is on")
local Frames = ns.Frames
assert(type(Frames) == "table" and type(Frames.Get) == "function", "ns.Frames.Get is missing")

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end
noErrors("enable")

-- Layout: each frame is one element under its key, with the setup's label, resizable, at its footprint.
local registered = {}
for _, el in ipairs(K.Layout.Elements()) do
	registered[el.key] = el
end
for kind, key in pairs(ELEMENTS) do
	local uf = Frames.Get(kind)
	assert(uf and uf.holder, kind .. " has a holder frame")
	local el = registered[key]
	assert(el, key .. " is registered with Layout")
	assert(el.module == "UnitFrames", key .. " names its module")
	assert(el.label == K.Setup.Layouts.Element(key).label, key .. " uses the setup's label")
	assert(el.opts.resizable == true, key .. " is resizable")
	local _, _, width, height = K.Layout.Rect(key)
	local footprint = K.Setup.Layouts.Element(key)
	assert(math.abs(width - footprint.width) < 1 and math.abs(height - footprint.height) < 1,
		key .. " starts at its footprint, got " .. width .. " x " .. height)
end

-- Secure buttons: one per unit, a child of the holder, targeting on left click and the unit menu on right click.
local function checkButton(view, unit)
	local button = view.button
	assert(button._template == "SecureUnitButtonTemplate", unit .. " uses SecureUnitButtonTemplate")
	assert(button:GetAttribute("unit") == unit, unit .. " button has its unit attribute")
	assert(button:GetAttribute("type1") == "target", unit .. ": left click targets")
	assert(button:GetAttribute("type2") == "togglemenu", unit .. ": right click opens the unit menu")
	assert(W.LastCall(button, "RegisterForClicks")[1] == "AnyUp", unit .. " registers for clicks")
	assert(env._watched[button], unit .. " is watched with RegisterUnitWatch")
end
for kind, unit in pairs(UNITS) do
	local uf = Frames.Get(kind)
	assert(#uf.views == 1, kind .. " has one unit")
	checkButton(uf.views[1], unit)
	assert(uf.views[1].button:GetParent() == uf.holder, kind .. ": the button sits in the holder Layout moves")
end
local boss = Frames.Get("boss")
assert(#boss.views == 5, "five boss frames")
for i = 1, 5 do
	checkButton(boss.views[i], "boss" .. i)
end

-- The player frame shows the player's data. Health is secret: it reaches the bar untouched.
local player = Frames.Get("player").views[1]
local value, low, high = U.Bar(env, player.health)
assert(value == 3120 and low == 0 and high == 3980, "health reaches the bar: " .. tostring(value) .. " of " .. tostring(high))
assert(env.issecretvalue(W.LastCall(player.health, "SetValue")[1]), "the bar gets the secret itself")
assert(U.Shown(env, player.healthText) == "78%", "health text: " .. U.Shown(env, player.healthText))
assert(U.Shown(env, player.powerText) == "2000 / 4000", "power text: " .. U.Shown(env, player.powerText))
assert(U.Shown(env, player.name) == "TESTER", "the name in capitals: " .. U.Shown(env, player.name))
assert(U.Shown(env, player.levelText) == "60", "level: " .. U.Shown(env, player.levelText))
assert(env._portraits[player.portrait] == "player", "the 2D portrait shows the player")
assert(U.Bar(env, player.power) == 2000, "power reaches the bar")

-- Events update the frame.
env._units.player.health = 1990
env.FireEvent("UNIT_HEALTH", "player")
assert(U.Bar(env, player.health) == 1990, "UNIT_HEALTH updates the bar")
assert(U.Shown(env, player.healthText) == "50%", "UNIT_HEALTH updates the text")
env._units.player.power = 1000
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
assert(U.Bar(env, player.power) == 1000, "UNIT_POWER_UPDATE updates the power bar")
env._units.player.name = "Renamed"
env.FireEvent("UNIT_NAME_UPDATE", "player")
assert(U.Shown(env, player.name) == "RENAMED", "UNIT_NAME_UPDATE updates the name")
noErrors("player events")

-- Restricted: max health and power turn secret too, and nothing compares them.
env._restricted = true
env.FireEvent("UNIT_MAXHEALTH", "player")
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
env.FireEvent("UNIT_MAXPOWER", "player", "MANA")
env._restricted = false
noErrors("restricted values")

-- The target: an NPC takes its reaction colour, a player its class colour.
local target = Frames.Get("target").views[1]
U.SetUnit(env, "target", { name = "Wolf", level = 12, health = 50, healthMax = 200, power = 10, powerMax = 100, powerType = 1, powerToken = "RAGE", reaction = 2 })
env.SetTarget(true)
assert(U.Shown(env, target.name) == "WOLF", "the target frame shows the new target: " .. U.Shown(env, target.name))
assert(U.Shown(env, target.healthText) == "25%", "target health text")
local hr, hg, hb = K.Theme.ReactionColor(2)
local last = W.LastCall(target.health, "SetStatusBarColor")
assert(last[1] == hr and last[2] == hg and last[3] == hb, "a hostile NPC's health bar takes the hostile colour")
U.SetUnit(env, "target", { name = "Jaina", class = "MAGE", isPlayer = true, level = 60, health = 100, healthMax = 100, reaction = 5 })
env.SetTarget(true)
local cr, cg, cb = K.Theme.ClassColor("MAGE")
last = W.LastCall(target.health, "SetStatusBarColor")
assert(last[1] == cr and last[2] == cg and last[3] == cb, "a player target's health bar takes their class colour")
noErrors("target")

-- The target of target follows the target's target.
local tot = Frames.Get("targettarget").views[1]
U.SetUnit(env, "targettarget", { name = "Tester", class = "HUNTER", isPlayer = true, level = 60, health = 30, healthMax = 60 })
env.FireEvent("UNIT_TARGET", "target")
assert(U.Shown(env, tot.name) == "TESTER", "UNIT_TARGET on the target updates the target of target")
assert(U.Shown(env, tot.healthText) == "50%", "the target of target shows its health")

-- Units like targettarget fire no unit events, so their frame polls while it shows, and only then.
local totHolder = Frames.Get("targettarget").holder
assert(totHolder:GetScript("OnUpdate"), "the target of target polls while it shows")
env._units.targettarget.health = 15
W.Tick(env, 0.25)
assert(U.Shown(env, tot.healthText) == "25%", "polling updates the target of target's health")
U.SetUnit(env, "targettarget", nil)
assert(tot.button:IsShown() == false, "the unit watch hides the frame without a unit")
assert(totHolder:GetScript("OnUpdate") == nil, "a hidden target of target stops polling")
assert(Frames.Get("player").holder:GetScript("OnUpdate") == nil, "frames with unit events never poll")

-- The pet appears with UNIT_PET, and bosses with INSTANCE_ENCOUNTER_ENGAGE_UNIT.
local pet = Frames.Get("pet").views[1]
U.SetUnit(env, "pet", { name = "Wolf", level = 58, health = 10, healthMax = 20, reaction = 5 })
env.FireEvent("UNIT_PET", "player")
assert(U.Shown(env, pet.name) == "WOLF", "UNIT_PET updates the pet frame")
U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 72, healthMax = 100, reaction = 2 })
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
assert(U.Shown(env, boss.views[1].name) == "MAGMATUS", "bosses update on INSTANCE_ENCOUNTER_ENGAGE_UNIT")
assert(U.Shown(env, boss.views[1].levelText) == "??", "a level of -1 shows ??")
noErrors("other units")

-- Tooltips use Blizzard's unit frame helpers.
W.Enter(player.button)
assert(env._tooltip == "player", "hovering a frame shows the unit tooltip")
W.Leave(player.button)
assert(env._tooltip == nil, "leaving hides it")

-- Settings: switching the portrait off gives the panel the whole frame.
K.Options.Write("UnitFrames", "player.portrait", false)
assert(player.portraitFrame:IsShown() == false, "the portrait hides")
local point, _, _, x = player.panel:GetPoint(1)
assert(point == "TOPLEFT" and math.abs(x) < 1e-6, "the panel starts at the frame's left edge")
K.Options.Write("UnitFrames", "player.portrait", true)
assert(player.portraitFrame:IsShown() == true, "the portrait shows again")

-- Fonts follow their settings.
K.Options.Write("UnitFrames", "player.fonts.name.size", 15)
local font = W.LastCall(player.name, "SetFont")
assert(font[2] == 15 and font[3] == "", "the name font takes the new size")
K.Options.Write("UnitFrames", "player.fonts.name.outline", "OUTLINE")
assert(W.LastCall(player.name, "SetFont")[3] == "OUTLINE", "the name takes the outline")

-- The bar texture, colour source and fill direction.
local glass = K.Tokens.MediaList("statusbar")[3].path
K.Options.Write("UnitFrames", "player.healthTexture", glass)
assert(W.LastCall(player.health, "SetStatusBarTexture")[1] == glass, "the health texture changes")
K.Options.Write("UnitFrames", "player.healthColor", "custom")
K.Options.Write("UnitFrames", "player.healthCustom", { r = 0.2, g = 0.4, b = 0.6 })
last = W.LastCall(player.health, "SetStatusBarColor")
assert(last[1] == 0.2 and last[2] == 0.4 and last[3] == 0.6, "a custom colour applies")
K.Options.Write("UnitFrames", "player.healthOrientation", "UP")
assert(W.LastCall(player.health, "SetOrientation")[1] == "VERTICAL", "up fills vertically")
assert(W.LastCall(player.health, "SetReverseFill")[1] == false, "up fills from the bottom")
K.Options.Write("UnitFrames", "player.healthOrientation", "LEFT")
assert(W.LastCall(player.health, "SetOrientation")[1] == "HORIZONTAL" and W.LastCall(player.health, "SetReverseFill")[1] == true, "left fills from the right")
noErrors("settings")

-- Layout resizes the holder; the bars follow.
local before = player.health.opts.width
assert(K.Layout.Set("unitframes.player", "width", 320), "Layout takes a new width")
assert(player.health.opts.width > before, "a wider frame gets a wider health bar")
noErrors("resize")

-- The accent recolours the portrait ring on a theme change.
K.Options.Write("UnitFrames", "accent", "custom")
K.Options.Write("UnitFrames", "accentColor", { r = 0.9, g = 0.1, b = 0.1 })
assert(W.SameRGB(player.ring, 0.9, 0.1, 0.1), "the ring takes the custom accent")
K.Options.Write("UnitFrames", "accent", "class")
local ar, ag, ab = K.Theme.Accent()
assert(W.SameRGB(player.ring, ar, ag, ab), "the ring follows the class accent again")

-- Layout's shown rule wins over the module's own updates.
assert(K.Layout.Set("unitframes.player", "shown", "never"))
local playerHolder = Frames.Get("player").holder
assert(not playerHolder:IsShown(), "the never rule hides the player frame")
K.Options.Write("UnitFrames", "player.enabled", true)
K.Options.Write("UnitFrames", "player.healthText", "percent")
assert(not playerHolder:IsShown(), "a setting change leaves Layout's rule alone")
assert(K.Layout.Set("unitframes.resource", "shown", "never"))
K.Options.Write("UnitFrames", "resource.comboPoints", true)
assert(not ns.Resource.state.holder:IsShown(), "the class resource keeps Layout's rule too")
K.Layout.Reset("unitframes.player")
K.Layout.Reset("unitframes.resource")
assert(playerHolder:IsShown(), "resetting the rule shows the frame again")

-- Turning one frame off in combat waits for the end of combat, then stops its unit watch.
local focus = Frames.Get("focus").views[1]
env.SetCombat(true)
K.Options.Write("UnitFrames", "focus.enabled", false)
assert(env._watched[focus.button], "no protected change in combat")
assert(K.Combat.Pending() > 0, "the change waits for the end of combat")
env.SetCombat(false)
assert(not env._watched[focus.button], "after combat the focus frame stops watching its unit")
assert(focus.button:IsShown() == false, "and hides")
K.Options.Write("UnitFrames", "focus.enabled", true)
assert(env._watched[focus.button], "turning it on watches the unit again")
noErrors("combat")

-- Blizzard's frames are hidden through Safe, and come back when the module stops.
local blizzard = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "Boss1TargetFrame", "Boss5TargetFrame" }
for _, name in ipairs(blizzard) do
	assert(K.Safe.IsHidden(env[name]), name .. " is hidden")
end
K.Modules.Disable("UnitFrames")
env.RunTimers()
for _, name in ipairs(blizzard) do
	assert(not K.Safe.IsHidden(env[name]), name .. " is restored when the module stops")
end
for kind in pairs(ELEMENTS) do
	local uf = Frames.Get(kind)
	assert(uf.holder:IsShown() == false, kind .. " hides when the module stops")
	for _, view in ipairs(uf.views) do
		assert(not env._watched[view.button], kind .. " stops its unit watch")
	end
end
env._units.player.health = 100
local calls = #player.health._calls
env.FireEvent("UNIT_HEALTH", "player")
assert(#player.health._calls == calls, "a stopped module ignores unit events")
noErrors("disable")

-- Enabling again reuses the frames.
local holder = Frames.Get("player").holder
K.Modules.Enable("UnitFrames")
env.RunTimers()
assert(Frames.Get("player").holder == holder and holder:IsShown(), "enabling again reuses and shows the frames")
assert(env._watched[player.button], "and watches the units again")

-- With hideBlizzard off, Blizzard's frames stay.
K.Options.Write("UnitFrames", "hideBlizzard", false)
env.RunTimers()
assert(not K.Safe.IsHidden(env.PlayerFrame), "hideBlizzard off restores Blizzard's player frame")
K.Options.Write("UnitFrames", "hideBlizzard", true)
env.RunTimers()
assert(K.Safe.IsHidden(env.PlayerFrame), "hideBlizzard on hides it again")
noErrors("re-enable")

-- A frame that starts switched off is styled before its unit watch first shows it.
do
	local env2, K2, ns2 = U.New({ saved = { version = 2, profiles = { Default = { UnitFrames = { enabled = true, player = { enabled = false } } } }, characters = {} } })
	local view = ns2.Frames.Get("player").views[1]
	assert(not env2._watched[view.button], "a switched-off frame has no unit watch")
	K2.Options.Write("UnitFrames", "player.enabled", true)
	assert(#env2._errors == 0, "enabling a frame later raises no error: " .. tostring(env2._errors[1]))
	assert(env2._watched[view.button] and U.Shown(env2, view.healthText) == "78%", "and it shows its unit at once")
end

print("unitframes frames ok")
