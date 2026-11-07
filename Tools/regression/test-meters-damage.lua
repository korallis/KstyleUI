-- test-meters-damage.lua: the damage meter mirrors C_DamageMeter in KstyleUI's window, hides Blizzard's meter only while it shows, and restyles Blizzard's window when the data cannot be read.
local M = dofile("Tools/regression/meters_env.lua")
local CoreEnv = M.CoreEnv

local env, K, ns = M.New()
local S = env.Secret

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	return args and args[1]
end

local function Session(sources, maxAmount, total)
	return { combatSources = sources, maxAmount = maxAmount, totalAmount = total, durationSeconds = 30 }
end

local function Source(name, class, total, perSecond, display)
	return {
		name = name, classFilename = class, totalAmount = total, amountPerSecond = perSecond,
		sourceDisplayType = display or 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0,
	}
end

env._session = Session({ Source("Kragar", "WARRIOR", 2840, 28.4), Source("Tester", "HUNTER", 2160, 21.6) }, 2840, 5000)

local blizzard = env.DamageMeter
assert(blizzard:GetParent() == env.UIParent, "Blizzard's meter starts on UIParent")
M.Enable(env, K)
local Damage = ns.Damage
local list = Damage.list

-- KstyleUI's window replaces Blizzard's while it shows.
assert(list.panel:IsShown(), "the window shows")
assert(blizzard:GetParent() ~= env.UIParent, "Blizzard's meter is hidden through Safe")
assert(K.Safe.IsHidden(blizzard), "Safe holds Blizzard's meter")
assert(M.Calls(blizzard, "Hide") == 0 and M.Calls(blizzard, "SetScript") == 0, "Blizzard's meter is never hidden or scripted directly")

-- Rows mirror the current session.
assert(env._lastSession[1] == M.SESSION.Current and env._lastSession[2] == M.METER.DamageDone, "the window reads the current fight's damage done")
assert(list.count == 2, "two sources show")
assert(Text(list.rows[1].name) == "Kragar", "the first source is named")
assert(Text(list.rows[1].value) == "~2840", "the value is abbreviated")
assert(Text(list.rows[1].percent) == "57%", "the share of the total shows")
local range = M.Last(list.rows[1].bar, "SetMinMaxValues")
assert(range[1] == 0 and range[2] == 2840, "bars run to the session's top amount")
assert(M.Last(list.rows[2].bar, "SetValue")[1] == 2160, "each bar shows its source's amount")
assert(Text(list.title) == "DAMAGE DONE", "the title names the meter")

-- Session updates refresh the rows once per burst.
env._session = Session({ Source("Kragar", "WARRIOR", 3000, 30), Source("Tester", "HUNTER", 3000, 30), Source("Sylaen", "PRIEST", 900, 9) }, 3000, 6900)
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
env.RunTimers()
assert(list.count == 3, "a third source appears after the update")

-- The meter type and the session come from the settings, and per-second types show rates.
M.Write(env, K, "damage.meter", "Dps")
assert(env._lastSession[2] == M.METER.Dps, "the window reads damage per second")
assert(Text(list.rows[1].value) == "~30", "per-second meters show the rate")
M.Write(env, K, "damage.session", "Overall")
assert(env._lastSession[1] == M.SESSION.Overall, "the window reads the overall session")
M.Write(env, K, "damage.percent", false)
assert(not list.rows[1].percent:IsShown(), "percentages can be switched off")
M.Write(env, K, "damage.percent", true)

-- Clicking the title changes the meter; right-clicking changes the fight.
list.panel._scripts.OnMouseUp(list.panel, "LeftButton")
env.RunTimers()
assert(K.Store.Module("Meters").damage.meter == "HealingDone", "a click moves to the next meter")
list.panel._scripts.OnMouseUp(list.panel, "RightButton")
env.RunTimers()
assert(K.Store.Module("Meters").damage.session == "Current", "a right-click switches the fight")
M.Write(env, K, "damage.meter", "DamageDone")

-- Deaths show the time of death.
local dead = Source("Lunara", "MAGE", 0, 0)
dead.deathRecapID, dead.deathTimeSeconds = 7, 83
env._session = Session({ dead }, 0, 0)
M.Write(env, K, "damage.meter", "Deaths")
assert(Text(list.rows[1].value) == "1:23", "a death shows its time")
M.Write(env, K, "damage.meter", "DamageDone")

-- Secret values in combat reach only widget setters.
env.SetCombat(true)
env.RunTimers()
local secretTotal = S(4000)
env._session = Session({ Source(S("Kragar"), "WARRIOR", secretTotal, S(40), S(1)) }, S(4000), S(4000))
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
env.RunTimers()
assert(#env._errors == 0, "secret meter values raise no error: " .. tostring(env._errors[1]))
assert(M.Last(list.rows[1].bar, "SetValue")[1] == secretTotal, "the secret amount goes straight to the bar")
assert(env.issecretvalue(Text(list.rows[1].name)), "the secret name passes through whole")
assert(env.issecretvalue(Text(list.rows[1].value)), "the secret amount is abbreviated by the game")
assert(Text(list.rows[1].percent) == "", "no percentage from secret values")
local locked = Source("Hidden", "ROGUE", 10, 1)
env._locked[locked] = true
env._session = Session({ Source("Kragar", "WARRIOR", 20, 2), locked }, 20, 30)
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
env.RunTimers()
assert(list.count == 1, "a source the game locks ends the list there")
env.SetCombat(false)
env.RunTimers()
assert(Damage.Mode() == "window", "readable tables keep KstyleUI's window")

-- Group only hides the window while alone.
M.Write(env, K, "damage.group", true)
assert(not list.panel:IsShown(), "the window hides while alone")
env._group = { raid = false, size = 2 }
env.FireEvent("GROUP_ROSTER_UPDATE")
env.RunTimers()
assert(list.panel:IsShown(), "the window shows in a group")
M.Write(env, K, "damage.group", false)

-- Switching the meter off gives Blizzard's meter back.
M.Write(env, K, "damage.shown", false)
assert(not Damage.holder:IsShown(), "the window hides")
assert(blizzard:GetParent() == env.UIParent, "Blizzard's meter is restored")
M.Write(env, K, "damage.shown", true)
assert(K.Safe.IsHidden(blizzard), "showing the window hides Blizzard's meter again")

-- Data that stays hidden in combat makes the meter restyle Blizzard's window from the end of combat.
env.SetCombat(true)
env.RunTimers()
env._locked[env._session] = true
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
env.RunTimers()
assert(list.note:IsShown(), "hidden data shows a note")
assert(Text(list.note) == "Hidden in combat", "the note says why")
assert(K.Safe.IsHidden(blizzard), "Blizzard's meter stays hidden during combat")
env.SetCombat(false)
env.RunTimers()
assert(Damage.Mode() == "skin", "after combat the meter falls back to Blizzard's window")
assert(not Damage.holder:IsShown(), "KstyleUI's window hides")
assert(blizzard:GetParent() == env.UIParent, "Blizzard's meter comes back")
assert(ns.DamageSkin.active, "Blizzard's meter is restyled")
assert(CoreEnv.Printed(env, "Damage Meter"), "the player is told once")
assert(M.Logged(env, "hidden in combat"), "the fallback is logged")

-- Turning the module off after a restyle asks for a reload.
M.Disable(env, K)
assert(CoreEnv.Printed(env, "/reload"), "a restyled Blizzard window needs a reload to undo")
assert(blizzard:GetParent() == env.UIParent, "Blizzard's meter stays on UIParent")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

-- Without C_DamageMeter the module restyles Blizzard's window from the start.
local env2, K2, ns2 = M.New({ noMeter = true })
M.Enable(env2, K2)
assert(ns2.Damage.Mode() == "skin", "no C_DamageMeter, no window")
assert(not ns2.Damage.holder:IsShown(), "the window stays hidden")
assert(not K2.Safe.IsHidden(env2.DamageMeter), "Blizzard's meter stays")
assert(M.Logged(env2, "C_DamageMeter is missing"), "the path is logged")
assert(#env2._errors == 0, "no Lua error: " .. tostring(env2._errors[1]))

-- The restyle style by choice.
local env3, K3, ns3 = M.New()
M.Enable(env3, K3)
M.Write(env3, K3, "damage.mode", "skin")
assert(not ns3.Damage.holder:IsShown(), "the restyle style hides KstyleUI's window")
assert(not K3.Safe.IsHidden(env3.DamageMeter), "and keeps Blizzard's meter")
M.Write(env3, K3, "damage.mode", "window")
assert(ns3.Damage.holder:IsShown(), "the window style shows the window again")
assert(K3.Safe.IsHidden(env3.DamageMeter), "and hides Blizzard's meter")
assert(#env3._errors == 0, "no Lua error: " .. tostring(env3._errors[1]))

print("meters damage ok")
