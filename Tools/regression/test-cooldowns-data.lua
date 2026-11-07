-- test-cooldowns-data.lua: the Cooldowns data model reads the Cooldown Manager's categories, follows the player's Blizzard layout when it is clean, and never makes Blizzard rebuild it.
local C = dofile("Tools/regression/cooldowns_env.lua")

local function ids(list)
	local out = {}
	for i, entry in ipairs(list) do
		out[i] = entry.cooldownID
	end
	return table.concat(out, ",")
end

local function expect(list, wanted, what)
	assert(ids(list) == wanted, what .. ": expected " .. wanted .. ", got " .. ids(list))
end

-- Without Blizzard's settings provider the defaults apply: learned spells in API order, minus the
-- spells Blizzard hides by default.
do
	local env, _, ns = C.New()
	local Data = ns.Data
	assert(Data.Available(), "the API is there, so the data is available")
	local list, source = Data.Collect("essential", {})
	expect(list, "101,102,103", "default essential")
	assert(source == "defaults", "no provider: the source is the defaults, got " .. tostring(source))
	expect(Data.Collect("utility", {}), "201,202", "default utility skips the unlearned spell")
	expect(Data.Collect("buffs", {}), "301,302", "default tracked buffs")
	expect(Data.Collect("bars", {}), "401,402", "default tracked bars")

	-- An entry queries the override spell, and keeps the base spell for icons and events.
	local essential = Data.Collect("essential", {})
	local overridden = essential[3]
	assert(overridden.spellID == 1003 and overridden.spell == 1033, "an override spell drives the cooldown")
	assert(essential[2].charges == true, "a charge spell is marked")

	-- An override that changes later reaches every entry of its base spell.
	Data.SetOverride(1001, 1011)
	assert(essential[1].spell == 1011, "the override event moves the entry to the new spell")
	Data.SetOverride(1001, nil)
	assert(essential[1].spell == 1001, "a removed override goes back to the base spell")

	-- The out table is reused: a second collect empties it first.
	local out = { "stale" }
	expect(Data.Collect("utility", out), "201,202", "reused table")
	assert(out[3] == nil, "a reused table holds no stale rows")

	-- Entries are reused across collects, so a rebuild in combat allocates no new rows.
	local again = Data.Collect("essential", {})
	assert(again[1] == essential[1], "the same cooldown keeps its entry table")
	assert(#C.Calls(env, "GetCooldownViewerCategorySet") > 0, "the defaults come from the category sets")
end

-- A clean Blizzard layout wins: its order, and the categories the player moved cooldowns into.
do
	local _, _, ns = C.New({
		layout = {
			order = { 202, 103, 101, 201, 102, 104, 203, 301, 302, 401, 402 },
			category = { [101] = C.CATEGORY.Utility, [104] = C.CATEGORY.Essential },
		},
	})
	local list, source = ns.Data.Collect("essential", {})
	assert(source == "layout", "a clean provider is the source, got " .. tostring(source))
	expect(list, "103,102,104", "the player's essential order, with a spell moved in")
	expect(ns.Data.Collect("utility", {}), "202,101,201", "the player's utility order, with a spell moved in, minus the unlearned one")
end

-- A dirty provider is never read and never rebuilt: the caller hears "dirty".
do
	local _, _, ns = C.New({ dirty = true })
	local list, source = ns.Data.Collect("essential", {})
	assert(source == "dirty", "a dirty provider reports dirty, got " .. tostring(source))
	expect(list, "101,102,103", "dirty still fills the defaults for a caller that has nothing yet")
end

-- No Cooldown Manager API: nothing to show, and the reason is given.
do
	local _, _, ns = C.New({ noViewer = true })
	local ok, reason = ns.Data.Available()
	assert(not ok and type(reason) == "string", "without C_CooldownViewer the data is unavailable")
	local list, source = ns.Data.Collect("essential", {})
	assert(#list == 0 and source == "none", "an unavailable API collects nothing")
end

-- A secret category set is never indexed: it collects nothing and says so.
do
	local env, _, ns = C.New()
	env._cdm.secretSet = true
	local list, source = ns.Data.Collect("essential", {})
	assert(#list == 0 and source == "secret", "a secret set collects nothing, got " .. tostring(source))
end

print("cooldowns data ok")
