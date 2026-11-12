-- test-meters-group.lua: the group meter as Details! draws it (LEE-430): a party of five and a raid of twenty each get a row per member with the class colour, the class icon, the name, the amount and the share, sorted; rows refresh at most every 0.5 s and the client eases the bars; the cap switches between damage and healing; a click opens that player's spells; a raid scrolls and keeps the player's own row in view; and in combat secret values reach only widget setters.
local M = dofile("Tools/regression/meters_env.lua")
local W = M.W

local EASE = 7

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	return args and args[1]
end

local function Plain(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Source(name, class, total, perSecond, guid, own)
	return {
		name = name, classFilename = class, totalAmount = total, amountPerSecond = perSecond, sourceGUID = guid,
		sourceDisplayType = 1, isLocalPlayer = own == true, deathRecapID = 0, deathTimeSeconds = 0, classification = "normal",
	}
end

local function Spell(id, total, perSecond)
	return {
		spellID = id, totalAmount = total, amountPerSecond = perSecond, creatureName = "", overkillAmount = 0,
		isAvoidable = false, isDeadly = false,
		combatSpellDetails = { unitName = "", unitClassFilename = "", classification = "", isPet = false, isMob = false, amount = 0, specIconID = 0 },
	}
end

local CLASSES = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "HUNTER", "PALADIN", "DRUID", "WARLOCK", "SHAMAN" }

-- A party of five, handed over out of order: the meter sorts plain amounts itself.
local PARTY = {
	{ "Sylaen", "PRIEST", 900 },
	{ "Kragar", "WARRIOR", 3000 },
	{ "Tester", "HUNTER", 2000, true },
	{ "Brannoc", "ROGUE", 2600 },
	{ "Ilyra", "MAGE", 1500 },
}

local function Party(env, healing)
	local sources, total = {}, 0
	for i, member in ipairs(PARTY) do
		local amount = healing and (6 - i) * 100 or member[3]
		sources[i] = Source(member[1], member[2], amount, amount / 10, "Player-" .. i, member[4])
		total = total + amount
	end
	env._session = { combatSources = sources, maxAmount = healing and 500 or 3000, totalAmount = total, durationSeconds = 10 }
end

-- A raid of twenty, sorted by the game, the player fourteenth.
local function Raid(env)
	local sources, total = {}, 0
	for i = 1, 20 do
		local amount = 4000 - i * 100
		local own = i == 14
		sources[i] = Source(own and "Tester" or ("Raider" .. i), CLASSES[(i - 1) % #CLASSES + 1], amount, amount / 10, "Player-" .. i, own)
		total = total + amount
	end
	env._session = { combatSources = sources, maxAmount = 3900, totalAmount = total, durationSeconds = 10 }
end

local function Atlases(env)
	env.GetClassAtlas = function(class)
		return ("classicon-%s"):format(class)
	end
	env.C_Texture = {
		GetAtlasInfo = function(name)
			if tostring(name):find("^classicon%-") then
				return { width = 64, height = 64 }
			end
		end,
	}
end

local function New(group, extra)
	local env, K, ns = M.New({
		game = function(e)
			e._group = group
			e._units.player.guid = "Player-3"
			e.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = EASE }
			Atlases(e)
			for id = 1, 3 do
				e._spells[id] = { name = "Spell " .. id, icon = 500 + id }
			end
			if extra then
				extra(e)
			end
		end,
	})
	return env, K, ns
end

local function Refresh(env)
	env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
	env.RunTimers()
end

-- A party of five ------------------------------------------------------------------------------------------------
local env, K, ns = New({ raid = false, size = 5 }, Party)
M.Enable(env, K)
env.RunTimers()
local list = ns.Damage.list
local order = { "Kragar", "Brannoc", "Tester", "Ilyra", "Sylaen" }
local amounts = { "3K", "2.6K", "2K", "1.5K", "900" }
local shares = { "30%", "26%", "20%", "15%", "9%" }
local classes = { "WARRIOR", "ROGUE", "HUNTER", "MAGE", "PRIEST" }
assert(list.count == 5, "every member of a party of five gets a row: " .. tostring(list.count))
for i = 1, 5 do
	local row = list.rows[i]
	assert(row.frame:IsShown(), i .. ": the row shows")
	assert(Text(row.name) == order[i], i .. ": rows sort by amount, highest first: " .. tostring(Text(row.name)))
	assert(Text(row.value) == amounts[i], i .. ": the amount: " .. tostring(Text(row.value)))
	assert(Text(row.percent) == shares[i] and row.dot:IsShown(), i .. ": the share: " .. tostring(Text(row.percent)))
	local cr, cg, cb = K.Theme.ClassColor(classes[i])
	local fill = M.Last(row.bar, "SetStatusBarColor")
	assert(fill[1] == cr and fill[2] == cg and fill[3] == cb, i .. ": the fill is the class colour")
	assert(row.icon:IsShown() and M.Last(row.icon, "SetAtlas")[1] == "classicon-" .. classes[i], i .. ": the class icon leads the row")
	local value = M.Last(row.bar, "SetValue")
	assert(value[2] == EASE, i .. ": the client eases the bar to its new value")
end
assert(M.Last(list.rows[1].bar, "SetMinMaxValues")[2] == 3000, "the bars run to the top amount")
assert(tostring(Text(list.column)):find("^200") and tostring(Text(list.column)):find("dps$"), "the cap shows the player's own rate: " .. tostring(Text(list.column)))
assert(Plain(Text(list.title)) == "DAMAGE  HEALING", "the cap is the damage and healing switch")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

-- A row's atlas is set once, not on every refresh.
do
	local before = M.Calls(list.rows[1].icon, "SetAtlas")
	Refresh(env)
	assert(M.Calls(list.rows[1].icon, "SetAtlas") == before, "an unchanged class icon is not set again")
end

-- Rows refresh on a 0.5 s timer: a burst of updates costs one read.
do
	local delays, after = {}, env.C_Timer.After
	env.C_Timer.After = function(delay, fn)
		delays[#delays + 1] = delay
		return after(delay, fn)
	end
	local reads, get = 0, env.C_DamageMeter.GetCombatSessionFromType
	env.C_DamageMeter.GetCombatSessionFromType = function(...)
		reads = reads + 1
		return get(...)
	end
	for _ = 1, 25 do
		env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
	end
	env.RunTimers()
	assert(#delays == 1 and delays[1] == 0.5, "twenty-five updates wait one 0.5 s tick: " .. #delays .. " timers")
	assert(reads == 1, "and read the session once: " .. reads)
	env.C_Timer.After = after
	env.C_DamageMeter.GetCombatSessionFromType = get
end

-- The cap switches between damage and healing; per-second meters keep their kind.
do
	local hit = list.titleHit
	assert(hit and hit:IsMouseEnabled(), "the cap's title takes clicks")
	Party(env, true)
	hit._scripts.OnMouseUp(hit, "LeftButton")
	env.RunTimers()
	assert(ns.Get("damage.meter") == "HealingDone", "a click on the title shows healing")
	assert(env._lastSession[2] == M.METER.HealingDone, "the window reads healing done")
	assert(Plain(Text(list.title)) == "DAMAGE  HEALING" and Text(list.title):find("HEALING|r", 1, true), "healing is lit")
	assert(Text(list.rows[1].name) == "Sylaen", "the healers lead the healing list: " .. tostring(Text(list.rows[1].name)))
	assert(Text(list.column):find("hps", 1, true), "the rate's unit follows: " .. tostring(Text(list.column)))
	hit._scripts.OnMouseUp(hit, "LeftButton")
	env.RunTimers()
	assert(ns.Get("damage.meter") == "DamageDone", "a second click returns to damage")
	M.Write(env, K, "damage.meter", "Dps")
	hit._scripts.OnMouseUp(hit, "LeftButton")
	env.RunTimers()
	assert(ns.Get("damage.meter") == "Hps", "damage per second switches to healing per second")
	M.Write(env, K, "damage.meter", "Interrupts")
	hit._scripts.OnMouseUp(hit, "LeftButton")
	env.RunTimers()
	assert(ns.Get("damage.meter") == "DamageDone", "any other meter switches back to damage")
	Party(env)
	Refresh(env)
end

-- A click on a member opens that member's spells, with their icons; a click goes back.
do
	env._sources["Player-4"] = { combatSpells = { Spell(2, 1600, 160), Spell(1, 1000, 100) }, maxAmount = 1600, totalAmount = 2600 }
	list.rows[2].frame._scripts.OnMouseUp(list.rows[2].frame, "LeftButton")
	env.RunTimers()
	assert(env._lastSource[4] == "Player-4", "the click asks for Brannoc's spells by his GUID")
	assert(list.count == 2 and Text(list.rows[1].name) == "Spell 2", "his spells list: " .. tostring(Text(list.rows[1].name)))
	assert(M.Last(list.rows[1].icon, "SetTexture")[1] == 502, "each with its spell icon")
	assert(tostring(Text(list.title)):upper():find("BRANNOC", 1, true), "the card is titled by him")
	list.rows[1].frame._scripts.OnMouseUp(list.rows[1].frame, "LeftButton")
	env.RunTimers()
	assert(list.count == 5 and Plain(Text(list.title)) == "DAMAGE  HEALING", "a click goes back to the group")
end

-- Out of the atlas: the class icon falls back to the class texture's coordinates.
do
	local envF, KF, nsF = New({ raid = false, size = 5 }, function(e)
		Party(e)
		e.C_Texture = nil
		e.CLASS_ICON_TCOORDS = { WARRIOR = { 0, 0.25, 0, 0.25 }, ROGUE = { 0.5, 0.75, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, MAGE = { 0.25, 0.5, 0, 0.25 }, PRIEST = { 0.5, 0.75, 0.25, 0.5 } }
	end)
	M.Enable(envF, KF)
	envF.RunTimers()
	local row = nsF.Damage.list.rows[1]
	assert(row.icon:IsShown() and M.Last(row.icon, "SetTexCoord")[2] == 0.25, "the fallback crops the class texture")
	assert(M.Logged(envF, "class icon atlas is missing"), "and logs the path once")
	assert(#envF._errors == 0, "no Lua error: " .. tostring(envF._errors[1]))
end

-- In combat the game hides the numbers and the names: rows stay in the game's order, the bars and amounts take
-- the secrets, no share is worked out, and only the player's own row opens.
do
	local envS, KS, nsS = New({ raid = false, size = 5 }, Party)
	M.Enable(envS, KS)
	envS.RunTimers()
	local card = nsS.Damage.list
	local S = envS.Secret
	local sources = envS._session.combatSources
	for _, source in ipairs(sources) do
		source.totalAmount, source.amountPerSecond = S(source.totalAmount), S(source.amountPerSecond)
		source.name, source.sourceGUID = S(source.name), S(source.sourceGUID)
	end
	envS._session.maxAmount, envS._session.totalAmount = S(3000), S(10000)
	envS.SetCombat(true)
	envS.FireEvent("PLAYER_REGEN_DISABLED")
	Refresh(envS)
	assert(card.count == 5, "every member still has a row in combat")
	assert(envS.Reveal(Text(card.rows[1].name)) == "Sylaen", "secret amounts are not sorted: the game's order stands")
	assert(envS.issecretvalue(Text(card.rows[1].value)), "the amount is the game's abbreviation of the secret")
	assert(not card.rows[1].percent:IsShown() and not card.rows[1].dot:IsShown(), "no share is worked out from secrets")
	assert(envS.issecretvalue(M.Last(card.rows[1].bar, "SetValue")[1]), "the bar takes the secret")
	assert(M.Last(card.rows[2].icon, "SetAtlas")[1] == "classicon-WARRIOR", "the class icon needs no secret: classFilename is never secret")
	envS._sources["Player-3"] = { combatSpells = { Spell(3, S(2000), S(200)) }, maxAmount = S(2000), totalAmount = S(2000) }
	card.rows[2].frame._scripts.OnMouseUp(card.rows[2].frame, "LeftButton")
	envS.RunTimers()
	assert(card.count == 5, "another member's row cannot open in combat: their GUID is secret")
	card.rows[3].frame._scripts.OnMouseUp(card.rows[3].frame, "LeftButton")
	envS.RunTimers()
	assert(envS._lastSource[4] == "Player-3", "the player's own row opens with the player's own GUID")
	assert(card.count == 1 and Text(card.rows[1].name) == "Spell 3" and envS.issecretvalue(Text(card.rows[1].value)), "and lists the player's spells in combat")
	assert(#envS._errors == 0, "no Lua error: " .. tostring(envS._errors[1]))
end

-- A raid of twenty -----------------------------------------------------------------------------------------------
do
	local envR, KR, nsR = New({ raid = true, size = 20 }, Raid)
	M.Enable(envR, KR)
	envR.RunTimers()
	local raid = nsR.Damage.list
	assert(raid.capacity == 5, "the default card holds five rows: " .. tostring(raid.capacity))
	local function Names()
		local out = {}
		for i = 1, raid.count do
			out[i] = Plain(Text(raid.rows[i].name))
		end
		return table.concat(out, ",")
	end
	assert(Names() == "Raider1,Raider2,Raider3,Raider4,14. Tester", "the top four, then the player's own row with the rank: " .. Names())
	assert(M.Last(raid.rows[5].icon, "SetAtlas")[1] == "classicon-" .. CLASSES[(14 - 1) % #CLASSES + 1], "the pinned row keeps the player's class icon")
	local wheel = raid.panel._scripts.OnMouseWheel
	assert(wheel, "the card scrolls")
	wheel(raid.panel, -1)
	wheel(raid.panel, -1)
	assert(Names() == "Raider3,Raider4,Raider5,Raider6,14. Tester", "scrolling down moves the list and keeps the player's row: " .. Names())
	for _ = 1, 8 do
		wheel(raid.panel, -1)
	end
	assert(Names() == "Raider11,Raider12,Raider13,Tester,Raider15", "the player's row in view is not pinned twice: " .. Names())
	for _ = 1, 20 do
		wheel(raid.panel, -1)
	end
	assert(Names() == "Raider17,Raider18,Raider19,Raider20,14. Tester", "the last member is reachable with the player pinned: " .. Names())
	for _ = 1, 40 do
		wheel(raid.panel, 1)
	end
	assert(Names() == "Raider1,Raider2,Raider3,Raider4,14. Tester", "scrolling up returns to the top: " .. Names())

	-- A taller card shows more of the raid.
	raid.holder:SetHeight(460)
	envR.RunTimers()
	Refresh(envR)
	assert(raid.capacity >= 19, "a taller card holds more rows: " .. tostring(raid.capacity))
	assert(raid.count == raid.capacity, "and fills them")
	raid.holder:SetHeight(500)
	envR.RunTimers()
	Refresh(envR)
	assert(raid.count == 20 and Plain(Text(raid.rows[14].name)) == "Tester", "with room for all twenty nothing is pinned: " .. raid.count)
	raid.holder:SetHeight(158)
	envR.RunTimers()

	-- A changed meter starts at the top again.
	wheel(raid.panel, -1)
	M.Write(envR, KR, "damage.meter", "HealingDone")
	Refresh(envR)
	assert(Plain(Text(raid.rows[1].name)) == "Raider1", "a new view starts from the top")
	M.Write(envR, KR, "damage.meter", "DamageDone")

	-- In combat: twenty secret rows, the player's still found by isLocalPlayer, which is never secret.
	local S = envR.Secret
	for _, source in ipairs(envR._session.combatSources) do
		source.totalAmount, source.amountPerSecond, source.name = S(source.totalAmount), S(source.amountPerSecond), S(source.name)
	end
	envR._session.maxAmount, envR._session.totalAmount = S(3900), S(50000)
	envR.SetCombat(true)
	Refresh(envR)
	assert(raid.count == 5 and envR.Reveal(Text(raid.rows[5].name)) == "14. Tester", "in combat the player's row stays pinned, its rank joined to the secret name")
	assert(envR.issecretvalue(Text(raid.rows[5].name)), "the joined name stays secret")
	assert(#envR._errors == 0, "no Lua error: " .. tostring(envR._errors[1]))
end

-- Alone: the card is the player's own spell list, as before, now led by spell icons; the switch works there too.
do
	local envA, KA, nsA = New({ raid = false, size = 0 }, function(e)
		e._sources["Player-3"] = { combatSpells = { Spell(1, 900, 90), Spell(2, 400, 40) }, maxAmount = 900, totalAmount = 1300 }
		e._session = { combatSources = { Source("Tester", "HUNTER", 1300, 130, "Player-3", true) }, maxAmount = 1300, totalAmount = 1300 }
	end)
	M.Enable(envA, KA)
	envA.RunTimers()
	local solo = nsA.Damage.list
	assert(solo.count == 2 and Text(solo.rows[1].name) == "Spell 1", "alone, the card lists the player's spells")
	assert(M.Last(solo.rows[1].icon, "SetTexture")[1] == 501, "led by the spell's icon")
	solo.titleHit._scripts.OnMouseUp(solo.titleHit, "LeftButton")
	envA.RunTimers()
	assert(envA._lastSource[3] == M.METER.HealingDone and envA._lastSource[4] == "Player-3", "the switch reads the player's own healing")
	M.Write(envA, KA, "damage.icons", false)
	assert(not solo.rows[1].icon:IsShown() and not solo.rows[1].back:IsShown(), "Show icons off removes the icon square")
	assert(W.Near(solo.rows[1].bar:GetWidth(), solo.rows[1].frame:GetWidth()), "and the bar spans the row again")
	assert(#envA._errors == 0, "no Lua error: " .. tostring(envA._errors[1]))
end

print("meters group: ok")
