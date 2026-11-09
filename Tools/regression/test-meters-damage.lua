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

-- Each row's pill track is the near-black button body, as the unit frames' tracks inside their glass.
do
	local fr, fg, fb = K.Tokens.Color("buttonFill")
	assert(M.W.SameRGB(list.rows[1].bar.background, fr, fg, fb), "a meter row's track is the buttonFill body")
end

-- The Lumen card: a section cap (gem, tracked title, fading rule, muted aside) one content inset inside the glass,
-- then rows of name, value and share with a 4-unit class pill under each, all inside the inset.
do
	local inset = list.panel.chrome:Inset()
	assert(M.W.Near(list.pad, inset), "the meter's padding is the chrome's content inset, got " .. tostring(list.pad) .. " for " .. tostring(inset))
	local cap = list.cap
	assert(cap and cap.gem and cap.title and cap.rule and cap.aside, "the header is the shared section cap")
	assert(list.title == cap.title and list.column == cap.aside, "the title and the column heading are the cap's title and aside")
	local capPoint = { cap.frame:GetPoint(1) }
	assert(capPoint[1] == "TOPLEFT" and M.W.Near(capPoint[4], inset) and M.W.Near(capPoint[5], -inset), "the cap starts one inset from the top left")
	local capRight = { cap.frame:GetPoint(2) }
	assert(capRight[1] == "TOPRIGHT" and M.W.Near(capRight[4], -inset), "the cap spans the content width to one inset from the right")
	assert(M.W.Near(list:Top(), inset + K.Widgets.SECTION_CAP_HEIGHT + K.Tokens.Size("gapMedium")), "the rows start under the cap and a gap")
	local row = list.rows[1]
	local frame = { row.frame:GetPoint(1) }
	assert(frame[1] == "TOPLEFT" and M.W.Near(frame[4], inset), "each row starts one inset from the left")
	assert(M.W.Near(row.frame:GetWidth(), list.holder:GetWidth() - 2 * inset), "the row spans the content width: " .. tostring(row.frame:GetWidth()))
	local percent = { row.percent:GetPoint(1) }
	assert(percent[2] == row.frame and percent[3] == "TOPRIGHT" and M.W.Near(percent[4], 0), "the share sits at the row's right end")
	local value = { row.value:GetPoint(1) }
	assert(value[2] == row.percent and value[3] == "LEFT", "the value sits left of the share")
	local name = { row.name:GetPoint(2) }
	assert(name[1] == "RIGHT" and name[2] == row.value and name[3] == "LEFT", "the name stops before the value, so a long name never runs under it")
	-- The pill: a 4-unit status bar along the row's foot, full width, so a secret amount can still drive it.
	local pill = { row.bar:GetPoint(1) }
	assert(pill[1] == "BOTTOMLEFT" and pill[2] == row.frame and M.W.Near(row.bar:GetHeight(), ns.BarList.PILL_HEIGHT), "the class pill runs along the row's foot, " .. ns.BarList.PILL_HEIGHT .. " tall: " .. tostring(row.bar:GetHeight()))
	assert(ns.BarList.PILL_HEIGHT == 4, "a 4-unit pill")
	assert(M.W.Near(row.bar:GetWidth(), row.frame:GetWidth()), "the pill spans the row")
	assert(row.edge == nil, "no separate edge line: the pill is the colour")
	assert(row.glow and row.glow:GetBlendMode() == "ADD", "a soft glow lies under the pill")
	local glow = { row.glow:GetPoint(1) }
	assert(glow[2] == row.bar:GetStatusBarTexture(), "the glow follows the pill's fill, so a secret value moves it too")
	-- The rows fill the column to one inset above the bottom: no dead band under the last row.
	local capacity = list:Capacity()
	local height, spacing = row.frame:GetHeight(), ns.Get("damage.spacing")
	local room = list.holder:GetHeight() - list:Top() - inset
	assert(height >= ns.Get("damage.rowHeight"), "a row is never shorter than the set height")
	assert(height >= ns.Get("damage.fontSize") * K.Theme.FontScale() + ns.BarList.PILL_HEIGHT + ns.BarList.PILL_GAP, "a row is never shorter than its text, the gap and the pill")
	assert(capacity * (height + spacing) - spacing <= room + 0.01 and room - (capacity * (height + spacing) - spacing) < capacity, "the rows fill the column to within a pixel per row: " .. tostring(height) .. " x " .. capacity .. " in " .. tostring(room))
end

-- Readable fills: the class colour fills the pill at full strength under the text line, and the glow is the same
-- colour, softer; white text reads above it on any class.
do
	local row = list.rows[1]
	local fill = M.Last(row.bar, "SetStatusBarColor")
	assert(fill and (fill[4] == nil or fill[4] == 1), "the pill is the class colour at full strength: " .. tostring(fill and fill[4]))
	local gr, gg, gb, ga = row.glow:GetVertexColor()
	assert(M.W.Near(gr, fill[1]) and M.W.Near(gg, fill[2]) and M.W.Near(gb, fill[3]) and ga < 0.6 and ga > 0, "the glow is the same colour, softer")
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
