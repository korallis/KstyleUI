-- test-meters-card.lua: the damage card as the owner's picture draws it (LEE-20, "let the picture win"): the cap names the meter with the rate at its right, five bars as tall as the row coloured by the spell's school, no icons, and "412 · 46%" at the right of each.
local M = dofile("Tools/regression/meters_env.lua")
local W = M.W

local DOT = "  \194\183  "
local SPELLS = {
	{ 403, "Lightning Bolt", 412, "meterNature" },
	{ 8050, "Flame Shock", 188, "meterFire" },
	{ 8042, "Earth Shock", 134, "meterNature" },
	{ 6603, "Melee", 107, "meterPhysical" },
	{ 3599, "Searing Totem", 54, "meterFire" },
}
local PERCENTS = { "46%", "21%", "15%", "12%", "6%" }

local function Spell(id, total, perSecond)
	return {
		spellID = id, totalAmount = total, amountPerSecond = perSecond or total / 60, creatureName = "", overkillAmount = 0,
		isAvoidable = false, isDeadly = false,
		combatSpellDetails = { unitName = "", unitClassFilename = "", classification = "", isPet = false, isMob = false, amount = 0, specIconID = 0 },
	}
end

local function Fight(env, group)
	env._group = group or { raid = false, size = 0 }
	env._units.player = { name = "Korallis", class = "SHAMAN", guid = "Player-7" }
	local spells, total = {}, 0
	for i, spell in ipairs(SPELLS) do
		env._spells[spell[1]] = { name = spell[2], icon = 100 + i }
		spells[i] = Spell(spell[1], spell[3])
		total = total + spell[3]
	end
	env._sources["Player-7"] = { combatSpells = spells, maxAmount = SPELLS[1][3], totalAmount = total }
	env._session = {
		combatSources = {
			{
				name = "Korallis", classFilename = "SHAMAN", totalAmount = total, amountPerSecond = 38.4, sourceGUID = "Player-7",
				sourceDisplayType = 1, isLocalPlayer = true, deathRecapID = 0, deathTimeSeconds = 0,
			},
		},
		maxAmount = total, totalAmount = total, durationSeconds = 60,
	}
end

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	return args and args[1]
end

local function Plain(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Color(frame)
	local fill = M.Last(frame, "SetStatusBarColor")
	return fill[1], fill[2], fill[3]
end

-- Alone: the card lists the player's own spells at rest, titled by the meter.
local env, K, ns = M.New({ game = function(e) Fight(e) end })
M.Enable(env, K)
env.RunTimers()
local list = ns.Damage.list
assert(list.block, "the damage card draws full-height bars")
assert(list.count == 5, "the player's five spells show: " .. tostring(list.count))
assert(W.Near(list.holder:GetWidth(), 269) and W.Near(list.holder:GetHeight(), 158), "the card is the picture's 269 by 158")

-- The cap: the meter's name in caps, the rate at its right; the source's name and the fight switch are not shown.
assert(Text(list.title) == "DAMAGE", "the cap names the meter, not the source: " .. tostring(Text(list.title)))
assert(Text(list.column) == "38.4 dps", "the cap's right end is the player's rate: " .. tostring(Text(list.column)))
assert(select(1, list.column:GetFont()) == K.Tokens.Font("number"), "the rate is set in the bold figure face")
local r, g, b = K.Tokens.Color("textEmphasis")
local tint = M.Last(list.column, "SetTextColor")
assert(tint and tint[1] == r and tint[2] == g and tint[3] == b, "and in white")
assert(not Plain(Text(list.column)):find("Now", 1, true), "the fight switch does not show at rest")
assert(list.cap.gem and list.cap.rule, "the cap carries the kit's gem and rule")
assert(select(1, list.title:GetFont()) == K.Tokens.Font("caps"), "DAMAGE is set in the tracked caps face")
local gr, gg, gb = K.Tokens.Color("capsGold")
local gold = M.Last(list.title, "SetTextColor")
assert(gold and gold[1] == gr and gold[2] == gg and gold[3] == gb, "in the picture's caption gold")
assert(not Text(list.title):find("\226\128\137", 1, true), "with no thin space: the face carries the tracking")

-- The switch is still there: on hover it shows the fights, a click steps to the next, and the setting is kept.
local switch = list.switch
switch._scripts.OnEnter(switch)
assert(Plain(Text(list.column)) == "Now  Last  All", "hovering the cap's right end shows the fights: " .. Plain(Text(list.column)))
switch._scripts.OnLeave(switch)
assert(Text(list.column) == "38.4 dps", "leaving it brings the rate back")
switch._scripts.OnMouseUp(switch, "LeftButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Previous", "a click on the switch still steps the fight setting")
M.Write(env, K, "damage.session", "Current")

-- The rows: bars 18 units tall, 21 apart, 16 in from the card's edge, the first 35.5 under its top (LEE-70 remeasured the picture's first fill at 2986, 1991).
for i, spell in ipairs(SPELLS) do
	local row = list.rows[i]
	local at = { row.frame:GetPoint(1) }
	assert(W.Near(row.frame:GetHeight(), 18), i .. ": the row is 18 units tall, got " .. tostring(row.frame:GetHeight()))
	assert(W.Near(row.bar:GetHeight(), 18), i .. ": the bar is as tall as the row")
	assert(at[1] == "TOPLEFT" and W.Near(at[4], 16), i .. ": the row is 16 units in from the left")
	assert(W.Near(-at[5], 35.5 + (i - 1) * 21, 0.51), i .. ": the row is " .. (35.5 + (i - 1) * 21) .. " units under the card's top, got " .. tostring(-at[5]))
	assert(W.Near(row.frame:GetWidth(), 237), i .. ": the row ends 16 units from the right edge")
	assert(not row.icon:IsShown(), i .. ": no icon")
	assert(Text(row.name) == spell[2], i .. ": the name is the spell's: " .. tostring(Text(row.name)))
	assert(Text(row.value) == "~" .. spell[3], i .. ": the amount: " .. tostring(Text(row.value)))
	assert(Text(row.percent) == DOT .. PERCENTS[i], i .. ": the share after the middle dot: " .. tostring(Text(row.percent)))
	local cr, cg, cb = K.Tokens.Color(spell[4])
	local br, bg, bb = Color(row.bar)
	assert(br == cr and bg == cg and bb == cb, i .. ": the bar is the spell's school colour (" .. spell[4] .. ")")
	local range = M.Last(row.bar, "SetMinMaxValues")
	assert(range[2] == 412 and M.Last(row.bar, "SetValue")[1] == spell[3], i .. ": the fill is the spell's share of the top spell")
end

-- The text sits inside the fill: the name at the left, the amount and share at the right, the value bold.
do
	local row = list.rows[1]
	local name = { row.name:GetPoint(1) }
	assert(name[1] == "LEFT" and name[2] == row.frame and name[4] > 0 and name[4] < 12, "the name starts just inside the bar's left edge")
	local share = { row.percent:GetPoint(1) }
	assert(share[1] == "RIGHT" and share[4] < 0 and share[4] > -12, "the share ends just inside the bar's right edge")
	assert(M.Last(row.value, "SetFont")[1] == K.Tokens.Font("number"), "the amount is bold")
	assert(M.Last(row.percent, "SetFont")[1] == K.Tokens.Font("number"), "and so is the share")
	assert(M.Last(row.name, "SetFont")[1] == K.Tokens.Font("body"), "the name is the body face")
	assert(row.name:GetParent() ~= row.frame and row.name:GetParent():GetFrameLevel() > row.bar:GetFrameLevel(), "the text is drawn above the bar")
	local nr, ng, nb = K.Tokens.Color("textEmphasis")
	local tnt = M.Last(row.name, "SetTextColor")
	assert(tnt[1] == nr and tnt[2] == ng and tnt[3] == nb, "the name is white")
	local track = K.Tokens.Color("buttonFill")
	assert(row.bar.background ~= nil and track ~= nil, "the rest of the row is a dark track")
end

-- No class-blue line, no pill: the bar is the whole row and nothing else rides under it.
assert(list.rows[1].edge == nil and list.rows[1].glow == nil, "no thin line under a row")
assert(M.Calls(list.rows[1].bar.keyline, "Hide") > 0 and M.Calls(list.rows[1].bar.lit, "Hide") > 0 and M.Calls(list.rows[1].bar.shade, "Hide") > 0, "the bar is flat: its keyline, highlight and shade are off")

-- Clicking a row does nothing: the spell list is the rest state, and there is nothing behind it to go back to.
local before = env._lastSource
list.rows[1].frame._scripts.OnMouseUp(list.rows[1].frame, "LeftButton")
env.RunTimers()
assert(env._lastSource == before or env._lastSource[4] == "Player-7", "a click on a spell row opens nothing new")
assert(Text(list.title) == "DAMAGE" and list.count == 5, "and the card stays on the spell list")
assert(list.rows[1].more == nil or not list.rows[1].more:IsShown(), "no chevron on a spell row")

-- The meter's name follows the meter type; the rate's unit follows it too.
M.Write(env, K, "damage.meter", "Dps")
assert(Text(list.title) == "DAMAGE", "damage per second is still the damage card")
M.Write(env, K, "damage.meter", "HealingDone")
assert(Text(list.title) == "HEALING DONE", "healing names itself: " .. tostring(Text(list.title)))
M.Write(env, K, "damage.meter", "DamageDone")

-- The percent switch drops the share and the dot together.
M.Write(env, K, "damage.percent", false)
assert(Text(list.rows[1].percent) == "" and not list.rows[1].percent:IsShown(), "no share, no dot")
M.Write(env, K, "damage.percent", true)

-- The old default stays a setting: the colour source "class" brings the class colour back on spells.
M.Write(env, K, "damage.colorSource", "class")
local cr, cg, cb = K.Theme.ClassColor("SHAMAN")
local br, bg, bb = Color(list.rows[1].bar)
assert(br == cr and bg == cg and bb == cb, "the class colour source colours a spell by class")
M.Write(env, K, "damage.colorSource", "school")
assert(ns.defaults.damage.colorSource == "school" and ns.defaults.damage.spacing == 3 and ns.defaults.damage.rowHeight == 18, "the picture's look is the default")

-- In a group the card lists the sources, titled by the meter, with the player's rate in the cap; a click opens one
-- source's spells, titled by the source.
do
	local envG, KG, nsG = M.New({ game = function(e) Fight(e, { raid = false, size = 2 }) end })
	M.Enable(envG, KG)
	envG.RunTimers()
	local group = nsG.Damage.list
	assert(Text(group.title) == "DAMAGE" and group.count == 1, "in a group the card lists the sources under the meter's name")
	assert(Text(group.column) == "38.4 dps", "the cap shows the local player's rate: " .. tostring(Text(group.column)))
	local ar, ag, ab = KG.Theme.ClassColor("SHAMAN")
	local sr, sg, sb = Color(group.rows[1].bar)
	assert(sr == ar and sg == ag and sb == ab, "a source's bar is its class colour")
	group.rows[1].frame._scripts.OnMouseUp(group.rows[1].frame, "LeftButton")
	envG.RunTimers()
	assert(Plain(Text(group.title)) == "Korallis" or tostring(Text(group.title)):upper() == "KORALLIS", "an opened source titles the card: " .. tostring(Text(group.title)))
	assert(group.count == 5 and not group.rows[1].icon:IsShown(), "its spells list as bars without icons")
	assert(Text(group.column) == "38.4 dps", "and the cap keeps the source's rate")
	assert(#envG._errors == 0, "no Lua error: " .. tostring(envG._errors[1]))
end

-- In combat on a client that hides the data the rows stay and nothing is compared: a secret rate and secret
-- amounts reach only widget setters.
do
	local envS, KS, nsS = M.New({ game = function(e) Fight(e) end })
	M.Enable(envS, KS)
	envS.RunTimers()
	local card = nsS.Damage.list
	local S = envS.Secret
	local Cap = getmetatable(card.cap)
	local setAside = Cap.SetAside
	function Cap.SetAside(self, text)
		assert(not envS.issecretvalue(text), "a secret reached the cap's aside, which compares its text")
		return setAside(self, text)
	end
	envS.SetCombat(true)
	local secretSpells = { Spell(403, S(412), S(7)), Spell(8050, S(188), S(3)) }
	envS._sources["Player-7"] = { combatSpells = secretSpells, maxAmount = S(412), totalAmount = S(895) }
	envS._session.combatSources[1].amountPerSecond = S(38.4)
	envS.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 8)
	envS.RunTimers()
	assert(#envS._errors == 0, "secret values raise no error: " .. tostring(envS._errors[1]))
	assert(envS.issecretvalue(Text(card.column)), "a secret rate reaches the cap through AbbreviateNumbers whole")
	assert(card.column:IsShown() and card.hasRest, "the aside shows and the list tracks it itself")
	envS.SetCombat(false)
	envS._session.combatSources[1].amountPerSecond = 38.4
	envS.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 8)
	envS.RunTimers()
	assert(Text(card.column) == "38.4 dps" and card.hasRest, "the plain rate takes the aside back after combat")
	Cap.SetAside = setAside
	assert(envS.issecretvalue(Text(card.rows[1].value)), "a secret amount is abbreviated by the game")
	assert(Text(card.rows[1].percent) == "" and not card.rows[1].percent:IsShown(), "no share is worked out from secret values")
	local nr, ng, nb = KS.Tokens.Color("meterNature")
	local fr, fg, fb = Color(card.rows[1].bar)
	assert(fr == nr and fg == ng and fb == nb, "a secret amount still gets its school colour: the school comes from the spell ID")
end

-- A fight that has no data clears the rate: Previous with no earlier fight shows no rate beside its note.
do
	local envP, KP, nsP = M.New({ game = function(e) Fight(e) end })
	M.Enable(envP, KP)
	envP.RunTimers()
	local card = nsP.Damage.list
	assert(Text(card.column) == "38.4 dps", "Now shows the rate")
	M.Write(envP, KP, "damage.session", "Previous")
	envP.RunTimers()
	assert(card.count == 0 and Text(card.note) == "No earlier fight yet", "Previous has no rows and says so")
	assert(Text(card.column) == "" and not card.hasRest, "and no rate stays beside it: " .. tostring(Text(card.column)))
	M.Write(envP, KP, "damage.session", "Current")
	envP.RunTimers()
	assert(Text(card.column) == "38.4 dps", "back on Now the rate returns")
	assert(#envP._errors == 0, "no Lua error: " .. tostring(envP._errors[1]))
end

-- The school table: the client gives no school for a spell ID, so KstyleUI_Meters carries the table
-- Tools/build/gen_spell_schools.py writes from Tools/data/abilities.json.
do
	local L = ns.Logic
	assert(L.SchoolToken(403) == "meterNature" and L.SchoolToken(8042) == "meterNature", "nature spells")
	assert(L.SchoolToken(8050) == "meterFire" and L.SchoolToken(3599) == "meterFire", "fire spells")
	assert(L.SchoolToken(116) == "meterFrost", "frost: Frostbolt")
	assert(L.SchoolToken(686) == "meterShadow", "shadow: Shadow Bolt")
	assert(L.SchoolToken(3044) == "meterArcane", "arcane: Arcane Shot")
	assert(L.SchoolToken(585) == "meterHoly", "holy: Smite")
	assert(L.SchoolToken(6603) == "meterPhysical" and L.SchoolToken(5215) == "meterPhysical", "melee and physical spells")
	assert(L.SchoolToken(99999999) == "meterPhysical" and L.SchoolToken(nil) == "meterPhysical", "an unknown spell falls back to physical")
	assert(L.SchoolToken(env.Secret(403)) == "meterPhysical", "a secret spell ID is never looked up")
	assert(L.FormatRate(38.4, "dps") == "38.4 dps" and L.FormatRate(0, "dps") == "0.0 dps", "a rate shows one decimal and its unit")
	assert(L.FormatRate(1234.5, "dps") == "~1234.5 dps", "a large rate is abbreviated by the game")
	assert(L.FormatRate(nil, "dps") == "" and L.FormatRate("x", "dps") == "", "no rate, no text")
end

assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))
print("meters card ok")
