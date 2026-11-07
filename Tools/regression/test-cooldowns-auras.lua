-- test-cooldowns-auras.lua: on the mirror path, tracked buff icons and bars follow the player's and the target's auras through duration objects, and never read secret aura data.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local function LastArg(frame, method, n)
	local call = W.LastCall(frame, method)
	return call and call[n or 1]
end

local function Registered(K, key)
	for _, element in ipairs(K.Layout.Elements()) do
		if element.key == key then
			return element
		end
	end
end

local env, K, ns = C.New({ setup = C.Game })
local cdm = env._cdm

-- Aura(unit, info) fires UNIT_AURA and ends the frame, when the mirror's queued refresh runs.
local function Aura(unit, info)
	env.FireEvent("UNIT_AURA", unit, info)
	env.RunTimers()
end
cdm.auras[3001] = { auraInstanceID = 71 }
cdm.stacks[71] = "3"
cdm.auras[4001] = { auraInstanceID = 81 }
K.Options.Write("Cooldowns", "path", "mirror")
C.Enable(env, K)
assert(ns.Path.Get("buffs") == "mirror" and ns.Path.Get("bars") == "mirror", "a forced mirror runs the buff groups")

-- Both groups are Layout elements at their footprints in the HUD band.
local buffs, bars = ns.Mirror.Row("buffs"), ns.Mirror.Row("bars")
for _, key in ipairs({ "cooldowns.buffs", "cooldowns.bars" }) do
	local element = Registered(K, key)
	assert(element and element.opts.scalable and element.module == "Cooldowns", key .. " registers, scalable")
end
local bw, bh = buffs.holder:GetSize()
assert(bw == 195 and bh == 30, "the buff icons fill a 195 by 30 footprint")
local rw, rh = bars.holder:GetSize()
assert(rw == 172 and rh == 78, "three bars of 172 by 24 fill a 172 by 78 footprint, got " .. tostring(rw) .. " by " .. tostring(rh))
assert(env._viewers.BuffIconCooldownViewer:GetAlpha() == 0 and env._viewers.BuffBarCooldownViewer:GetAlpha() == 0, "Blizzard's buff viewers are faded")

-- Only active buffs show; an icon sweeps backward from its aura's duration object and shows its stacks.
assert(buffs.count == 1 and buffs.icons[1].entry.spellID == 3001, "one active buff shows")
local icon = buffs.icons[1]
assert(LastArg(icon.cooldown, "SetCooldownFromDurationObject") == cdm.auraDurations[71], "the icon sweeps from the aura's duration object")
assert(LastArg(icon.cooldown, "SetReverse") == true, "buff sweeps run backward")
assert(icon.count:GetText() == "3", "the stack count shows")

-- A bar fills from the aura's duration object, draining by the time left, with a countdown and the spell's name.
assert(bars.count == 1, "one active bar shows")
local bar = bars.bars[1]
local timer = W.LastCall(bar.status, "SetTimerDuration")
assert(timer and timer[1] == cdm.auraDurations[81], "the bar runs on the aura's duration object")
assert(timer[3] == env.Enum.StatusBarTimerDirection.RemainingTime, "the bar drains by the time left")
assert(LastArg(bar.timer, "SetCooldownFromDurationObject") == cdm.auraDurations[81], "the countdown runs on the same duration")
assert(bar.name:GetText() == "Spell 4001", "the bar shows the spell's name")

-- A buff with no expiry fills its bar and shows no countdown.
cdm.permanent[81] = true
Aura("player", { updatedAuraInstanceIDs = { 81 } })
assert(LastArg(bar.status, "SetValue") == 1, "a buff with no expiry fills its bar")
cdm.permanent[81] = nil
Aura("player", { updatedAuraInstanceIDs = { 81 } })

-- UNIT_AURA on the player brings in a new buff.
cdm.auras[3002] = { auraInstanceID = 72 }
Aura("player", { addedAuras = { { spellId = 3002, auraInstanceID = 72 } } })
assert(buffs.count == 2, "a new aura adds its icon")

-- A debuff the player put on the target shows after a target change.
cdm.targetAuras["Spell 4002"] = { auraInstanceID = 82 }
env.SetTarget(true)
env.RunTimers()
assert(bars.count == 2, "the target's debuff adds a bar")
local targetCalls = C.Calls(env, "GetAuraDuration")
local found = false
for _, args in ipairs(targetCalls) do
	found = found or (args[1] == "target" and args[2] == 82)
end
assert(found, "the target's aura duration is read from the target")

-- A buff that ends drops its icon.
cdm.auras[3001] = nil
Aura("player", { removedAuraInstanceIDs = { 71 } })
assert(buffs.count == 1 and buffs.icons[1].entry.spellID == 3002, "the ended buff drops out")

-- Show inactive keeps every tracked buff, the inactive ones dimmed.
K.Options.Write("Cooldowns", "buffs.inactive", true)
assert(buffs.count == 2, "inactive buffs stay with the setting on")
assert(buffs.icons[1].usable == false and buffs.icons[2].usable == true, "the inactive buff is dimmed")
K.Options.Write("Cooldowns", "buffs.inactive", false)

-- While aura data is secret nothing is read: the last state stays.
cdm.secretAuras = true
local reads = #C.Calls(env, "GetPlayerAuraBySpellID")
cdm.auras[3001] = { auraInstanceID = 73 }
Aura("player", env.Secret({ addedAuras = { { spellId = 3001, auraInstanceID = 73 } } }))
assert(#C.Calls(env, "GetPlayerAuraBySpellID") == reads, "no aura is read while auras are secret")
assert(buffs.count == 1, "the last state stays")
cdm.secretAuras = false

-- A secret aura record or instance ID is never indexed or compared: it counts as not found.
cdm.auras[3001] = env.Secret({ auraInstanceID = 74 })
cdm.auras[3002] = { auraInstanceID = env.Secret(75) }
Aura("player", { isFullUpdate = true })
assert(buffs.count == 0, "secret aura data shows nothing rather than failing")
assert(ns.Path.Get("buffs") == "mirror", "secret aura data is not a failure")

-- Bar settings: width, height, texture and a custom colour reach the bars.
cdm.auras[3001] = nil
cdm.auras[3002] = nil
K.Options.Write("Cooldowns", "bars.width", 220)
K.Options.Write("Cooldowns", "bars.height", 20)
assert(bar:GetWidth() == 220 and bar:GetHeight() == 20, "bars follow the width and height settings")
local fw, fh = bars.holder:GetSize()
assert(fw == 220 and fh == 3 * 20 + 2 * 3, "the holder follows the bar size")
K.Options.Write("Cooldowns", "bars.texture", "Interface\\AddOns\\Some\\Bar.tga")
assert(LastArg(bar.status, "SetStatusBarTexture") == "Interface\\AddOns\\Some\\Bar.tga", "the texture setting reaches the bar")
K.Options.Write("Cooldowns", "bars.colorSource", "custom")
K.Options.Write("Cooldowns", "bars.color", { r = 0.2, g = 0.4, b = 0.6 })
local r, g, b = LastArg(bar.status, "SetStatusBarColor", 1), LastArg(bar.status, "SetStatusBarColor", 2), LastArg(bar.status, "SetStatusBarColor", 3)
assert(r == 0.2 and g == 0.4 and b == 0.6, "a custom bar colour applies")
K.Options.Write("Cooldowns", "bars.orientation", "VERTICAL")
assert(LastArg(bar.status, "SetOrientation") == "VERTICAL", "the orientation setting reaches the bar")
K.Options.Write("Cooldowns", "bars.count", 5)
assert(select(2, bars.holder:GetSize()) == 5 * 20 + 4 * 3, "the holder grows with the bar count")

-- A widget restyle, such as the shadows switch, keeps the bar colour.
K.Widgets.RestyleAll()
r, g, b = bar.status:GetStatusBarColor()
assert(r == 0.2 and g == 0.4 and b == 0.6, "a kit restyle keeps the custom bar colour")

-- Disable gives the buff viewers back.
K.Modules.Disable("Cooldowns")
assert(env._viewers.BuffBarCooldownViewer:GetAlpha() == 1, "Disable restores Blizzard's bar viewer")

-- A failing aura duration call switches the group to the reskin.
do
	local env2, K2, ns2 = C.New({ setup = C.Game })
	env2._cdm.auras[3001] = { auraInstanceID = 91 }
	K2.Options.Write("Cooldowns", "path", "mirror")
	C.Enable(env2, K2)
	assert(ns2.Mirror.Row("buffs").count == 1, "the buff shows first")
	env2._cdm.auraDurationError = "secret arguments are not allowed"
	env2.FireEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 91 } })
	env2.RunTimers()
	assert(ns2.Path.Get("buffs") == "reskin", "a failing duration call switches the buff icons to the reskin")
	assert(env2._viewers.BuffIconCooldownViewer:GetAlpha() == 1, "Blizzard's buff viewer shows again")
end

-- A profile with another display path takes effect when the player switches to it.
do
	local env3, K3, ns3 = C.New({ setup = C.Game })
	C.Enable(env3, K3)
	assert(ns3.Path.Get("essential") == "mirror", "the default profile mirrors")
	K3.Store.SetProfile("Restyled")
	K3.Options.Write("Cooldowns", "path", "reskin")
	K3.Modules.Enable("Cooldowns")
	assert(ns3.Path.Get("essential") == "reskin", "the new profile restyles")
	K3.Store.SetProfile("Default")
	assert(ns3.Path.Get("essential") == "mirror", "switching back to the default profile mirrors again")
	assert(env3._viewers.EssentialCooldownViewer:GetAlpha() == 0, "Blizzard's viewer fades again")
end

print("cooldowns auras ok")
