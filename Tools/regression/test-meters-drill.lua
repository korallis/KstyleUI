-- test-meters-drill.lua: the damage meter window's depth: a click on a source lists its spells through C_DamageMeter's source calls, the fight segments (current, previous fight, overall), the rows it holds while combat hides the data, the group-only default in both styles, and the style picked once at login.
local M = dofile("Tools/regression/meters_env.lua")

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	return args and args[1]
end

local function Session(sources, maxAmount, total)
	return { combatSources = sources, maxAmount = maxAmount, totalAmount = total, durationSeconds = 30 }
end

local function Source(name, class, total, perSecond, guid, creatureID)
	return {
		name = name, classFilename = class, totalAmount = total, amountPerSecond = perSecond, sourceGUID = guid,
		sourceCreatureID = creatureID, sourceDisplayType = 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0,
	}
end

local function Spell(id, total, perSecond, creature)
	return {
		spellID = id, totalAmount = total, amountPerSecond = perSecond, creatureName = creature or "", overkillAmount = 0,
		isAvoidable = false, isDeadly = false,
		combatSpellDetails = { unitName = "", unitClassFilename = "", classification = "", isPet = false, isMob = false, amount = 0, specIconID = 0 },
	}
end

local function Click(frame, button)
	frame._scripts.OnMouseUp(frame, button or "LeftButton")
end

local function Row(schema, key)
	for _, row in ipairs(schema) do
		if row.key == key then
			return row
		end
	end
end

local env, K, ns = M.New({
	game = function(env)
		env._group = { raid = false, size = 2 }
		env._spells[100] = { name = "Mortal Strike", icon = "Interface\\Icons\\ability_warrior_savageblow" }
		env._spells[200] = { name = "Bite", icon = "Interface\\Icons\\ability_druid_ferociousbite" }
	end,
})
env._session = Session({
	Source("Kragar", "WARRIOR", 3000, 30, "Player-1"), Source("Tester", "HUNTER", 2000, 20, "Player-2"), Source("Boar", "", 500, 5, nil, 4242),
}, 3000, 5500)
env._sources["Player-1"] = { combatSpells = { Spell(100, 1800, 18), Spell(200, 1200, 12, "Wolf") }, maxAmount = 1800, totalAmount = 3000 }
env._sources[4242] = { combatSpells = { Spell(200, 500, 5) }, maxAmount = 500, totalAmount = 500 }
M.Enable(env, K)
local Damage = ns.Damage
local list = Damage.list
assert(list.panel:IsShown() and list.count == 3, "three sources show in a group")

-- A click on a source lists that source's spells, read with GetCombatSessionSourceFromType for the fight shown.
Click(list.rows[1].frame)
env.RunTimers()
local call = env._lastSource
assert(call and call[1] == "type" and call[2] == M.SESSION.Current and call[3] == M.METER.DamageDone, "the spells come from the current fight's damage done")
assert(call[4] == "Player-1" and call[5] == nil, "the source is asked for by its GUID")
assert(list.count == 2, "the source's two spells show: " .. tostring(list.count))
assert(Text(list.rows[1].name) == "Mortal Strike", "a spell row is named by C_Spell.GetSpellName")
assert(Text(list.rows[2].name) == "Bite (Wolf)", "a pet's spell names the pet")
assert(Text(list.rows[1].value) == "~1800", "the spell's amount is abbreviated")
assert(Text(list.rows[1].percent) == "60%", "the share is of the source's total")
assert(M.Last(list.rows[1].bar, "SetMinMaxValues")[2] == 1800, "the bars run to the source's top spell")
assert(list.rows[1].icon:IsShown() and M.Last(list.rows[1].icon, "SetTexture")[1] == env._spells[100].icon, "a spell row shows the spell's icon")
assert(Text(list.title) ~= nil and tostring(Text(list.title)):upper():find("KRAGAR", 1, true), "the title names the source: " .. tostring(Text(list.title)))
local r, g, b = K.Theme.ClassColor("WARRIOR")
local fill = M.Last(list.rows[2].bar, "SetStatusBarColor")
assert(fill[1] == r and fill[2] == g and fill[3] == b, "spell rows take the source's class colour")

-- Updates keep the spell list current.
env._sources["Player-1"] = { combatSpells = { Spell(100, 2400, 24), Spell(200, 1200, 12, "Wolf") }, maxAmount = 2400, totalAmount = 3600 }
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 5)
env.RunTimers()
assert(Text(list.rows[1].value) == "~2400", "a session update refreshes the spells")

-- A click on the panel goes back to the sources, without changing the meter; so does a right-click.
Click(list.panel)
env.RunTimers()
assert(ns.Get("damage.meter") == "DamageDone", "going back leaves the meter as it was")
assert(list.count == 3 and Text(list.rows[1].name) == "Kragar", "the sources show again")
assert(not list.rows[1].icon:IsShown(), "source rows show no icon")
assert(tostring(Text(list.title)):upper():find("DAMAGE", 1, true), "the title names the meter again")
Click(list.rows[1].frame)
env.RunTimers()
Click(list.panel, "RightButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Current" and list.count == 3, "a right-click in the spell list goes back, not to another fight")

-- A creature is asked for by its creature ID.
Click(list.rows[3].frame)
env.RunTimers()
assert(env._lastSource[4] == nil and env._lastSource[5] == 4242, "a creature source is asked for by its creature ID")
assert(list.count == 1, "the creature's spell shows")
Click(list.panel)
env.RunTimers()

-- Changing the meter goes back to the sources.
Click(list.rows[1].frame)
env.RunTimers()
M.Write(env, K, "damage.meter", "Dps")
assert(Text(list.rows[1].name) == "Kragar", "a new meter starts at the sources")
M.Write(env, K, "damage.meter", "DamageDone")

-- Deaths have no spell list: a click does nothing.
M.Write(env, K, "damage.meter", "Deaths")
local before = env._lastSource
Click(list.rows[1].frame)
env.RunTimers()
assert(env._lastSource == before, "a death row opens no spell list")
M.Write(env, K, "damage.meter", "DamageDone")

-- Fight segments: current, the previous fight and overall. The previous fight is the newest fight the game still
-- holds other than the current one (DAMAGE_METER_COMBAT_SESSION_UPDATED names the current fight's ID).
env._available = { { sessionID = 3, name = "" }, { sessionID = 4, name = "Hogger", durationSeconds = 55 }, { sessionID = 5, name = "" } }
env._sessions[4] = Session({ Source("Kragar", "WARRIOR", 900, 9, "Player-1") }, 900, 900)
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 5)
env.RunTimers()
M.Write(env, K, "damage.session", "Previous")
assert(env._lastSessionID and env._lastSessionID[1] == 4 and env._lastSessionID[2] == M.METER.DamageDone, "the previous fight is read by its session ID")
assert(list.count == 1, "the previous fight's one source shows")
assert(tostring(Text(list.column)):upper():find("HOGGER", 1, true), "the column names the fight: " .. tostring(Text(list.column)))
-- A fight name too long to share the cap with the title gives way to a short label, so the two never overlap.
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
	local short = tostring(Text(list.column)):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	assert(short == "Last", "a long fight name gives way to the short label: " .. short)
	list.title.GetStringWidth, list.column.GetStringWidth = titleWidth, columnWidth
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.RunTimers()
	assert(tostring(Text(list.column)):upper():find("HOGGER", 1, true), "a name that fits stays")
end
Click(list.rows[1].frame)
env.RunTimers()
assert(env._lastSource[1] == "id" and env._lastSource[2] == 4, "the previous fight's spells come from GetCombatSessionSourceFromID")
Click(list.panel)
env.RunTimers()
env._available = { { sessionID = 3, name = "" }, { sessionID = 5, name = "" } }
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 5)
env.RunTimers()
assert(env._lastSessionID[1] == 3, "an unnamed previous fight is still found")
assert(tostring(Text(list.column)):upper():find("LAST", 1, true), "an unnamed fight is called the last fight")
env._available = { { sessionID = 5, name = "" } }
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
env.RunTimers()
assert(list.count == 0 and list.note:IsShown(), "no earlier fight leaves an empty list with a note")

-- The current fight's ID is forgotten while the window stops listening, so fights missed meanwhile still count.
M.Write(env, K, "damage.mode", "skin")
env._available = { { sessionID = 5, name = "" }, { sessionID = 6, name = "" }, { sessionID = 7, name = "" } }
M.Write(env, K, "damage.mode", "window")
M.Write(env, K, "damage.session", "Previous")
env.RunTimers()
assert(env._lastSessionID[1] == 6, "after missed fights the previous fight is the one before the newest: " .. tostring(env._lastSessionID[1]))

-- A spell whose ID is secret is named by the game, its secret name passed straight to the row.
M.Write(env, K, "damage.session", "Current")
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
env.RunTimers()
env._sources["Player-1"] = { combatSpells = { Spell(env.Secret(100), 1800, 18) }, maxAmount = 1800, totalAmount = 1800 }
local getName = env.C_Spell.GetSpellName
env.C_Spell.GetSpellName = function(id)
	return env.Secret("Mortal Strike")
end
Click(list.rows[1].frame)
env.RunTimers()
assert(env.issecretvalue(Text(list.rows[1].name)), "a secret spell name reaches the row whole")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))
env.C_Spell.GetSpellName = getName
Click(list.panel)
env.RunTimers()
env._available = { { sessionID = 5, name = "" } }

-- A right-click on the title steps through the fights: current, previous, overall, current.
M.Write(env, K, "damage.session", "Current")
Click(list.panel, "RightButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Previous", "current, then the previous fight")
Click(list.panel, "RightButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Overall", "then overall")
Click(list.panel, "RightButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Current", "then current again")

-- In combat the game hides the data from addons: the rows read last stay, and the column says the list is paused.
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
env.RunTimers()
assert(list.count == 3, "three sources before the pull")
env.SetCombat(true)
env.RunTimers()
env._locked[env._session] = true
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 6)
env.RunTimers()
assert(list.count == 3 and list.rows[1].frame:IsShown(), "the rows read before the pull stay")
assert(not list.note:IsShown(), "no note covers the held rows")
assert(tostring(Text(list.column)):upper():find("PAUSED", 1, true), "the column says the list is paused: " .. tostring(Text(list.column)))
-- A source GUID the game keeps secret cannot be passed back: the click does nothing and raises no error.
env._locked[env._session] = nil
env._session = Session({ Source(env.Secret("Kragar"), "WARRIOR", env.Secret(10), env.Secret(1), env.Secret("Player-1")) }, env.Secret(10), env.Secret(10))
env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 6)
env.RunTimers()
before = env._lastSource
Click(list.rows[1].frame)
env.RunTimers()
assert(env._lastSource == before, "a secret GUID opens no spell list")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))
-- A different view in combat has nothing to hold: it says the data is hidden.
env._locked[env._session] = true
M.Write(env, K, "damage.meter", "HealingDone")
assert(list.count == 0 and list.note:IsShown() and Text(list.note) == "Hidden in combat", "a new view in combat says the data is hidden")
env._locked[env._session] = nil
env.SetCombat(false)
env.FireEvent("PLAYER_REGEN_ENABLED")
env.RunTimers()
assert(not tostring(Text(list.column)):upper():find("PAUSED", 1, true), "out of combat the column names the fight again")
M.Write(env, K, "damage.meter", "DamageDone")

-- Group only is the default: alone, the window hides.
assert(ns.Get("damage.group") == true, "the damage meter shows only in a group by default")
env._group = { raid = false, size = 0 }
env.FireEvent("GROUP_ROSTER_UPDATE")
env.RunTimers()
assert(not list.panel:IsShown(), "alone, the window hides")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

-- The style is picked once: a later answer from C_Secrets changes nothing this session.
env._secretRestrictions = true
assert(Damage.Mode() == "window", "auto stays KstyleUI's window after the first answer")

-- A restricted client: auto is Blizzard's window, restyled, decided at login and named in the settings.
local envR, KR, nsR = M.New({ restricted = true })
M.Enable(envR, KR)
local blizzard = envR.DamageMeter
assert(nsR.Damage.Mode() == "skin", "restricted: Blizzard's window restyled")
envR._secretRestrictions = false
assert(nsR.Damage.Mode() == "skin", "the style does not change under the player")
local style = Row(nsR.schema, "damage.mode")
assert(type(style.options) == "function", "the style's options name what auto picked on this client")
local auto
for _, option in ipairs(style.options()) do
	if option.value == "auto" then
		auto = option.label
	end
end
assert(auto and auto:find("Blizzard", 1, true), "auto names Blizzard's window on this client: " .. tostring(auto))
local settings = { damage = { mode = "auto" } }
assert(not Row(nsR.schema, "damage.meter").showWhen(settings), "window-only settings hide when auto picked the restyle")
assert(Row(nsR.schema, "damage.group").showWhen == nil, "group only applies to both styles")
local autoHere
for _, option in ipairs(Row(ns.schema, "damage.mode").options()) do
	if option.value == "auto" then
		autoHere = option.label
	end
end
assert(autoHere and autoHere:find("KstyleUI", 1, true), "auto names KstyleUI's window where it reads in combat: " .. tostring(autoHere))
assert(Row(ns.schema, "damage.meter").showWhen(settings), "window-only settings show when auto picked the window")

-- Group only holds Blizzard's restyled window too: hidden alone, back in a group, back when switched off.
assert(KR.Safe.IsHidden(blizzard), "alone, Blizzard's restyled window is held hidden")
envR._group = { raid = false, size = 3 }
envR.FireEvent("GROUP_ROSTER_UPDATE")
envR.RunTimers()
assert(not KR.Safe.IsHidden(blizzard), "in a group Blizzard's window comes back")
envR._group = { raid = false, size = 0 }
envR.FireEvent("GROUP_ROSTER_UPDATE")
envR.RunTimers()
assert(KR.Safe.IsHidden(blizzard), "alone again, it hides again")
M.Write(envR, KR, "damage.group", false)
assert(not KR.Safe.IsHidden(blizzard), "with group only off, Blizzard's window stays alone too")
assert(#envR._errors == 0, "no Lua error: " .. tostring(envR._errors[1]))

print("meters drill ok")
