-- test-meters-parity-more.lua: legacy refresh, hover count and pinned rank defaults persist, and new settings change the damage window.
local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New({ saved = { version = 42, profiles = { Default = { Meters = { enabled = true, followRole = false, damage = { shown = true, mode = "window" } } } }, characters = {} }, game = function(e)
	e._group = { raid = false, size = 5 }
end })
local sources, spells = {}, {}
for i = 1, 12 do
	sources[i] = { name = "Player " .. i, classFilename = "WARRIOR", totalAmount = 13000 - i * 1000, amountPerSecond = 1300 - i * 100,
		sourceGUID = "Player-" .. i, sourceDisplayType = 1, isLocalPlayer = i == 12 }
	spells[i] = { spellID = i, totalAmount = 13000 - i * 1000, amountPerSecond = 1300 - i * 100 }
end
env._session = { combatSources = sources, maxAmount = 12000, totalAmount = 78000, durationSeconds = 10 }
env._sources["Player-1"] = { combatSpells = spells, maxAmount = 12000, totalAmount = 78000 }
M.Enable(env, K); env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
local list = ns.Damage.list
assert(ns.Get("damage.refresh") == 0.5 and ns.Get("damage.hoverSpells") == 3 and not ns.Get("damage.hideRank"), "v0.2.8 defaults")
local function name()
	return M.Last(list.rows[list.count].name, "SetText")[1]
end
assert(name() == "12. Player 12", "pinned rank starts visible")
M.Write(env, K, "damage.hideRank", true)
assert(name() == "Player 12", "rank hides")
M.Write(env, K, "damage.hideRank", false)
assert(name() == "12. Player 12", "rank restores")
local split = { AddRow = function(self) self.count = self.count + 1 end, SetNote = function() end }
local function hover(count)
	split.count = 0
	assert(list.rowSplit(split, list, 1) and split.count == count, "hover shows the configured spell count")
end
hover(3)
M.Write(env, K, "damage.hoverSpells", 8); hover(8)
M.Write(env, K, "damage.hoverSpells", 1); hover(1)
M.Write(env, K, "damage.hoverSpells", 3)
local after, delays = env.C_Timer.After, {}
env.C_Timer.After = function(delay, fn) delays[#delays + 1] = delay; return after(delay, fn) end
for _, delay in ipairs({ 0.1, 2, 0.5 }) do
	M.Write(env, K, "damage.refresh", delay)
	delays = {}
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	assert(#delays == 1 and delays[1] == delay, "updates coalesce at the chosen interval")
	assert(K.Store.Module("Meters").damage.refresh == delay, "interval is saved")
	env.RunTimers()
end
assert(#env._errors == 0 and K.ErrorCount() == 0, "more meter settings apply without errors")
print("more meter parity ok")
