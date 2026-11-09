-- test-meters-fights.lua: the damage meter card shows its fight switch in the cap, the current fight, the last fight and every fight, with the one shown lit, and a click on it steps through them.
local M = dofile("Tools/regression/meters_env.lua")

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	return args and args[1]
end

local function Plain(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- The colour a word of a coloured text is drawn in, as "rrggbb", or nil when it carries none.
local function ColourOf(text, word)
	return tostring(text or ""):match("|cff(%x%x%x%x%x%x)" .. word .. "|r")
end

local function Hex(r, g, b)
	return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Session(sources, maxAmount, total)
	return { combatSources = sources, maxAmount = maxAmount, totalAmount = total, durationSeconds = 30 }
end

local function Source(name, class, total, guid)
	return {
		name = name, classFilename = class, totalAmount = total, amountPerSecond = total / 30, sourceGUID = guid,
		sourceDisplayType = 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0,
	}
end

local env, K, ns = M.New({
	game = function(env)
		env._group = { raid = false, size = 2 }
	end,
})
env._session = Session({ Source("Kragar", "WARRIOR", 3000, "Player-1"), Source("Tester", "HUNTER", 2000, "Player-2") }, 3000, 5000)
env._available = { { sessionID = 4, name = "Riverglade Crocolisk", durationSeconds = 20 }, { sessionID = 5, name = "", durationSeconds = 10 } }
env._sessions[4] = Session({ Source("Kragar", "WARRIOR", 900, "Player-1") }, 900, 900)
M.Enable(env, K)
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 5)
env.RunTimers()
local list = ns.Damage.list
assert(list.panel:IsShown() and list.count == 2, "the card shows the current fight's two sources")

-- The switch sits in the cap: the three fights in words, the shown one in the cap's gilt, the others muted.
local switch = list.switch
assert(switch and switch:IsShown(), "the card shows a fight switch")
assert((M.Last(switch, "EnableMouse") or {})[1] == true, "the switch takes clicks of its own")
local aside = Text(list.column)
assert(Plain(aside) == "Now  Last  All", "the switch names the current fight, the last fight and every fight: " .. Plain(aside))
local lit = Hex(K.Widgets.Rgba("giltLit"))
local muted = Hex(K.Widgets.Rgba("muted"))
assert(ColourOf(aside, "Now") == lit, "the current fight is lit: " .. tostring(aside))
assert(ColourOf(aside, "Last") == muted and ColourOf(aside, "All") == muted, "the other fights are muted")

-- A click on the switch shows the last fight, read by its session ID, and lights it; the meter type stays.
local meter = ns.Get("damage.meter")
switch._scripts.OnMouseUp(switch, "LeftButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Previous", "a click on the switch shows the last fight")
assert(env._lastSessionID and env._lastSessionID[1] == 4, "the last fight is read by its session ID")
assert(list.count == 1, "the last fight's one source shows")
assert(Plain(Text(list.column)) == "Now  Riverglade Crocolisk  All", "the last fight goes by the name the game recorded: " .. Plain(Text(list.column)))
assert(ColourOf(Text(list.column), "Riverglade Crocolisk") == lit and ColourOf(Text(list.column), "Now") == muted, "the last fight is lit")
assert(ns.Get("damage.meter") == meter, "the switch never changes the meter type")

-- The next clicks show every fight, then the current fight again.
switch._scripts.OnMouseUp(switch, "LeftButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Overall" and ColourOf(Text(list.column), "All") == lit, "then every fight")
switch._scripts.OnMouseUp(switch, "LeftButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Current" and ColourOf(Text(list.column), "Now") == lit, "then the current fight again")

-- The switch's tooltip names the last fight as the game recorded it.
local lines = {}
local tip = { AddLine = function(_, line)
	lines[#lines + 1] = tostring(line)
end }
assert(type(list.switchTooltip) == "function", "the switch explains itself")
list.switchTooltip(tip)
assert(table.concat(lines, " "):find("Riverglade Crocolisk", 1, true), "the tooltip names the last fight: " .. table.concat(lines, " | "))

-- A spell list keeps the switch, and a click on it keeps the source's spells, now from the next fight.
list.rows[1].frame._scripts.OnMouseUp(list.rows[1].frame, "LeftButton")
env.RunTimers()
assert(switch:IsShown() and Plain(Text(list.column)) == "Now  Last  All", "the spell list keeps the switch")
switch._scripts.OnMouseUp(switch, "LeftButton")
env.RunTimers()
assert(env._lastSource and env._lastSource[1] == "id" and env._lastSource[2] == 4, "the source's spells now come from the last fight")
assert(ns.Get("damage.session") == "Previous", "the switch moved to the last fight")
M.Write(env, K, "damage.session", "Current")
env.RunTimers()

-- A card too narrow for the three words keeps the fight shown alone, still lit and still a switch.
do
	local titleWidth, columnWidth = list.title.GetStringWidth, list.column.GetStringWidth
	list.title.GetStringWidth = function()
		return 110
	end
	list.column.GetStringWidth = function()
		return list.barWidth - 110
	end
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.RunTimers()
	assert(Plain(Text(list.column)) == "Now" and ColourOf(Text(list.column), "Now") == lit, "a narrow card shows the fight shown alone: " .. Plain(Text(list.column)))
	assert(switch:IsShown(), "and keeps the switch")
	list.title.GetStringWidth, list.column.GetStringWidth = titleWidth, columnWidth
end

-- The threat meter shares the card and has no fights: no switch.
assert(ns.Threat.list == nil or ns.Threat.list.switch == nil, "the threat meter has no fight switch")

print("ok - meters fights: the card's switch shows now, last and all, lights the one shown, and steps on a click")
