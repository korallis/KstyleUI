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

-- Each row's track is the near-black button body, as the unit frames' tracks inside their glass, not the kit's translucent track.
do
	local fr, fg, fb = K.Tokens.Color("buttonFill")
	assert(M.W.SameRGB(list.rows[1].bar.background, fr, fg, fb), "a meter row's track is the buttonFill body")
end

-- The title, the rows and the values sit one content inset inside the glass, the rule every text panel follows,
-- so nothing sits under a corner cut or on the light line.
do
	local inset = list.panel.chrome:Inset()
	assert(M.W.Near(list.pad, inset), "the meter's padding is the chrome's content inset, got " .. tostring(list.pad) .. " for " .. tostring(inset))
	local title = { list.title:GetPoint(1) }
	assert(title[1] == "TOPLEFT" and M.W.Near(title[4], inset) and M.W.Near(title[5], -inset), "the title starts one inset from the top left")
	local column = { list.column:GetPoint(1) }
	assert(column[1] == "TOPRIGHT" and M.W.Near(column[4], -inset), "the column heading ends one inset from the right")
	local row = list.rows[1]
	local bar = { row.bar:GetPoint(1) }
	assert(bar[1] == "TOPLEFT" and M.W.Near(bar[4], inset), "each bar starts one inset from the left")
	-- A row is one bar across the content width that carries its name, value and share, as a player reads a
	-- meter row; the numbers no longer hang outside a short bar.
	assert(M.W.Near(row.bar:GetWidth(), list.holder:GetWidth() - 2 * inset), "the bar spans the content width: " .. tostring(row.bar:GetWidth()))
	local percent = { row.percent:GetPoint(1) }
	assert(percent[2] == row.bar and percent[3] == "RIGHT" and M.W.Near(percent[4], -list.gap), "the share sits a gap inside the bar's right end")
	local value = { row.value:GetPoint(1) }
	assert(value[2] == row.percent and value[3] == "LEFT", "the value sits left of the share")
	local name = { row.name:GetPoint(2) }
	assert(name[1] == "RIGHT" and name[2] == row.value and name[3] == "LEFT", "the name stops before the value, so a long name never runs under it")
	-- The rows fill the column to one inset above the bottom: no dead band under the last row.
	local capacity = list:Capacity()
	local height, spacing = row.bar:GetHeight(), ns.Get("damage.spacing")
	local room = list.holder:GetHeight() - list:Top() - inset
	assert(height >= ns.Get("damage.rowHeight"), "a row is never shorter than the set height")
	assert(capacity * (height + spacing) - spacing <= room + 0.01 and room - (capacity * (height + spacing) - spacing) < capacity, "the rows fill the column to within a pixel per row: " .. tostring(height) .. " x " .. capacity .. " in " .. tostring(room))
	-- The header: a faint rule across the content width under the title, the accent mark on it at the left.
	assert(list.rule and list.rule:IsShown(), "a rule underlines the header")
	assert(M.W.Near(list.rule:GetWidth(), list.holder:GetWidth() - 2 * inset), "the rule spans the content width")
	local rule, mark = { list.rule:GetPoint(1) }, { list.mark:GetPoint(1) }
	assert(rule[2] == list.mark or (rule[2] == list.panel and mark[2] == list.title), "the mark sits on the rule")
end

-- Readable fills: the class colour fills the row dimmed under the text, and a full-strength edge of the same
-- length runs along the row's foot, so the colour still names the class and white text reads on any class.
do
	local row = list.rows[1]
	local fill = M.Last(row.bar, "SetStatusBarColor")
	assert(fill and fill[4] and fill[4] < 0.7 and fill[4] >= 0.4, "the fill is the class colour dimmed under the text: " .. tostring(fill and fill[4]))
	assert(row.edge, "each row has an edge in the class colour")
	local edge = M.Last(row.edge, "SetStatusBarColor")
	assert(edge and (edge[4] == nil or edge[4] == 1) and edge[1] == fill[1] and edge[2] == fill[2] and edge[3] == fill[3], "the edge is the same colour at full strength")
	assert(row.edge:GetHeight() <= 2 and row.edge:GetHeight() > 0, "the edge is a thin line")
end

-- Rows mirror the current session.
assert(env._lastSession[1] == M.SESSION.Current and env._lastSession[2] == M.METER.DamageDone, "the window reads the current fight's damage done")
assert(list.count == 2, "two sources show")
assert(Text(list.rows[1].name) == "Kragar", "the first source is named")
assert(Text(list.rows[1].value) == "~2840", "the value is abbreviated")
assert(Text(list.rows[1].percent) == "57%", "the share of the total shows")
local range = M.Last(list.rows[1].bar, "SetMinMaxValues")
assert(range[1] == 0 and range[2] == 2840, "bars run to the session's top amount")
assert(M.Last(list.rows[2].bar, "SetValue")[1] == 2160, "each bar shows its source's amount")
assert(M.Last(list.rows[2].edge, "SetValue")[1] == 2160 and M.Last(list.rows[1].edge, "SetMinMaxValues")[2] == 2840, "each edge runs as far as its bar")
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
assert(M.Last(list.rows[1].edge, "SetValue")[1] == secretTotal, "and straight to the edge")
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
assert(not K.Layout.Live("meters.damage"), "and leaves Layout Mode and the Elements page")
assert(blizzard:GetParent() == env.UIParent, "Blizzard's meter is restored")
M.Write(env, K, "damage.shown", true)
assert(K.Safe.IsHidden(blizzard), "showing the window hides Blizzard's meter again")
assert(K.Layout.Live("meters.damage"), "and its element comes back")

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
