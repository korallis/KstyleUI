-- test-meters-damage.lua: the damage meter mirrors C_DamageMeter in KstyleUI's window, hides Blizzard's meter only while it shows, and restyles Blizzard's window when the data cannot be read.
local M = dofile("Tools/regression/meters_env.lua")
local CoreEnv = M.CoreEnv

-- In a group: the damage meter shows only in a group by default, in either style.
local env, K, ns = M.New({ game = function(e) e._group = { raid = false, size = 2 } end })
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

-- Each row's track is the near-black button body, as the unit frames' tracks inside their glass.
do
	local fr, fg, fb = K.Tokens.Color("buttonFill")
	assert(M.W.SameRGB(list.rows[1].bar.background, fr, fg, fb), "a meter row's track is the buttonFill body")
end

-- The picture's card (test-meters-card.lua pins its numbers): a section cap (gem, tracked title, fading rule, the
-- rate) over rows that are bars as tall as the row, 16 units in from the card's edge.
do
	local inset = 16
	assert(M.W.Near(list.pad, inset), "the meter's padding is the picture's 16 units, got " .. tostring(list.pad))
	local cap = list.cap
	assert(cap and cap.gem and cap.title and cap.rule and cap.aside, "the header is the shared section cap")
	assert(list.title == cap.title and list.column == cap.aside, "the title and the column heading are the cap's title and aside")
	local capRight = { cap.frame:GetPoint(2) }
	assert(capRight[1] == "TOPRIGHT" and M.W.Near(capRight[4], -inset), "the cap spans the content width to the same inset from the right")
	assert(M.W.Near(list:Top(), 35.5), "the rows start 35.5 units under the card's top")
	local row = list.rows[1]
	local frame = { row.frame:GetPoint(1) }
	assert(frame[1] == "TOPLEFT" and M.W.Near(frame[4], inset), "each row starts the inset from the left")
	assert(M.W.Near(row.frame:GetWidth(), list.holder:GetWidth() - 2 * inset), "the row spans the content width: " .. tostring(row.frame:GetWidth()))
	local percent = { row.percent:GetPoint(1) }
	assert(percent[1] == "RIGHT" and percent[2] == row.frame and percent[3] == "RIGHT" and percent[4] < 0, "the share sits at the row's right end, inside the fill")
	local value = { row.value:GetPoint(1) }
	assert(value[2] == row.percent and value[3] == "LEFT", "the value sits left of the share")
	local name = { row.name:GetPoint(2) }
	assert(name[1] == "RIGHT" and name[2] == row.value and name[3] == "LEFT", "the name stops before the value, so a long name never runs under it")
	assert(M.W.Near(row.bar:GetHeight(), row.frame:GetHeight()), "the bar is as tall as the row")
	assert(M.W.Near(row.bar:GetWidth(), row.frame:GetWidth()), "the bar spans the row")
	assert(row.edge == nil and row.glow == nil, "no separate edge line and no glow ride on the bar")
	for _, region in ipairs(row.frame._regions or {}) do
		local blend = M.Last(region, "SetBlendMode")
		assert(not (blend and blend[1] == "ADD"), "no additive lens draws on the row")
	end
	local capacity = list:Capacity()
	local height, spacing = row.frame:GetHeight(), ns.Get("damage.spacing")
	local room = list.holder:GetHeight() - list:Top() - inset
	assert(height >= ns.Get("damage.rowHeight"), "a row is never shorter than the set height")
	assert(height >= ns.Get("damage.fontSize") * K.Theme.FontScale() + 2, "a row is never shorter than its text and 2 units of air")
	assert(capacity * (height + spacing) - spacing <= room + 0.01, "the rows counted fit the room: " .. tostring(height) .. " x " .. capacity .. " in " .. tostring(room))
end

-- Readable fills: a source's bar is its class colour at full strength; white text reads above it on any class.
do
	local row = list.rows[1]
	local fill = M.Last(row.bar, "SetStatusBarColor")
	assert(fill and (fill[4] == nil or fill[4] == 1), "the bar is the class colour at full strength: " .. tostring(fill and fill[4]))
	local r, g, b = K.Theme.ClassColor("WARRIOR")
	assert(fill[1] == r and fill[2] == g and fill[3] == b, "a source's bar is its class colour: the school colour belongs to a spell")
end

-- Rows mirror the current session.
assert(env._lastSession[1] == M.SESSION.Current and env._lastSession[2] == M.METER.DamageDone, "the window reads the current fight's damage done")
assert(list.count == 2, "two sources show")
assert(Text(list.rows[1].name) == "Kragar", "the first source is named")
assert(Text(list.rows[1].value) == "~2840", "the value is abbreviated")
assert(Text(list.rows[1].percent) == "  \194\183  57%", "the share of the total shows after the middle dot")
local range = M.Last(list.rows[1].bar, "SetMinMaxValues")
assert(range[1] == 0 and range[2] == 2840, "bars run to the session's top amount")
assert(M.Last(list.rows[2].bar, "SetValue")[1] == 2160, "each bar shows its source's amount")
assert(Text(list.title) == "DAMAGE", "the cap names the meter, not the source")

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
env._group = { raid = false, size = 0 }
env.FireEvent("GROUP_ROSTER_UPDATE")
env.RunTimers()
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

-- The style setting defaults to auto: KstyleUI's window where the client lets addons read the data in combat,
-- Blizzard's window restyled where it does not (C_Secrets.HasSecretRestrictions), decided once at the start.
-- No mode flips mid-session and nothing is printed: a player who picks the window keeps it, with a note in combat.
assert(ns.Get("damage.mode") == "auto", "the style defaults to auto")
assert(Damage.Mode() == "window", "without secret restrictions auto is KstyleUI's window")
M.Write(env, K, "damage.mode", "window")
env.SetCombat(true)
env.RunTimers()
env._locked[env._session] = true
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
env.RunTimers()
-- The rows read before the pull stay, and the column says the list is paused (test-meters-drill.lua).
assert(list.count > 0 and not list.note:IsShown(), "hidden data keeps the rows read last")
assert(Text(list.column) == "Paused", "the column says why")
assert(K.Safe.IsHidden(blizzard), "Blizzard's meter stays hidden during combat")
env.SetCombat(false)
env._locked[env._session] = nil
env.FireEvent("PLAYER_REGEN_ENABLED")
env.RunTimers()
assert(Damage.Mode() == "window", "after combat the chosen window stays the window")
assert(Damage.holder:IsShown() and not list.note:IsShown(), "and fills again when the data can be read")
assert(not CoreEnv.Printed(env, "Damage Meter"), "nothing is printed to chat")
assert(M.Logged(env, "hidden from addons"), "the hidden spell is logged")
M.Write(env, K, "damage.mode", "skin")
assert(Damage.Mode() == "skin" and ns.DamageSkin.active, "Blizzard's window restyled, by choice")

-- Turning the module off after a restyle asks for a reload.
M.Disable(env, K)
assert(CoreEnv.Printed(env, "/reload"), "a restyled Blizzard window needs a reload to undo")
assert(blizzard:GetParent() == env.UIParent, "Blizzard's meter stays on UIParent")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

-- On a client with secret restrictions auto restyles Blizzard's window from the start, so the meter reads in
-- combat, and says so once in the log.
local envR, KR, nsR = M.New({ restricted = true })
M.Enable(envR, KR)
assert(nsR.Damage.Mode() == "skin", "secret restrictions: auto is Blizzard's window restyled")
assert(nsR.DamageSkin.active and not nsR.Damage.holder:IsShown(), "restyled from the start, KstyleUI's window never shows")
assert(M.Logged(envR, "secret in combat"), "the choice is logged")
assert(not CoreEnv.Printed(envR, "Damage Meter"), "and not printed")
M.Write(envR, KR, "damage.mode", "window")
assert(nsR.Damage.Mode() == "window" and nsR.Damage.holder:IsShown(), "the player may still choose the window")
assert(#envR._errors == 0, "no Lua error: " .. tostring(envR._errors[1]))

-- Without C_DamageMeter the module restyles Blizzard's window from the start.
local env2, K2, ns2 = M.New({ noMeter = true, game = function(e) e._group = { raid = false, size = 2 } end })
M.Enable(env2, K2)
assert(ns2.Damage.Mode() == "skin", "no C_DamageMeter, no window")
assert(not ns2.Damage.holder:IsShown(), "the window stays hidden")
assert(not K2.Safe.IsHidden(env2.DamageMeter), "Blizzard's meter stays")
assert(M.Logged(env2, "C_DamageMeter is missing"), "the path is logged")
assert(#env2._errors == 0, "no Lua error: " .. tostring(env2._errors[1]))

-- The restyle style by choice.
local env3, K3, ns3 = M.New({ game = function(e) e._group = { raid = false, size = 2 } end })
M.Enable(env3, K3)
M.Write(env3, K3, "damage.mode", "skin")
assert(not ns3.Damage.holder:IsShown(), "the restyle style hides KstyleUI's window")
assert(not K3.Safe.IsHidden(env3.DamageMeter), "and keeps Blizzard's meter")
M.Write(env3, K3, "damage.mode", "window")
assert(ns3.Damage.holder:IsShown(), "the window style shows the window again")
assert(K3.Safe.IsHidden(env3.DamageMeter), "and hides Blizzard's meter")
assert(#env3._errors == 0, "no Lua error: " .. tostring(env3._errors[1]))

print("meters damage ok")
