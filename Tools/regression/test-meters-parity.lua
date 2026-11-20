-- test-meters-parity.lua: a legacy meter keeps player pinning and hover breakdowns, and each new option changes the real damage list.
local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New({ saved = { version = 4, profiles = { Default = { Meters = { enabled = true, followRole = false, damage = { shown = true, mode = "window" } } } }, characters = {} }, game = function(e)
 e._group = { raid = false, size = 5 }
 e.BreakUpLargeNumbers = function(n) return e.Secret("full") end
end })
local sources = {}
for i = 1, 12 do
 sources[i] = { name = "Player " .. i, classFilename = "WARRIOR", totalAmount = 13000 - i * 1000, amountPerSecond = 1300 - i * 100,
  sourceGUID = "Player-" .. i, sourceDisplayType = 1, isLocalPlayer = i == 12 }
end
env._session = { combatSources = sources, maxAmount = 12000, totalAmount = 78000, durationSeconds = 10 }
M.Enable(env, K); env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
local list = ns.Damage.list
assert(ns.Get("damage.alwaysPlayer") and ns.Get("damage.hover") and ns.Get("damage.format") == "short", "v0.2.8 keeps the old meter defaults")
assert(list.rowSplits(list, 1), "hover breakdowns start on")
K.Options.Write("Meters", "damage.hover", false); env.RunTimers()
assert(not list.rowSplits(list, 1), "hover breakdowns turn off")
K.Options.Write("Meters", "damage.hover", true); env.RunTimers()
assert(list.rowSplits(list, 1), "hover breakdowns return")
local function pinned()
 for _, row in ipairs(list.rows) do
  local call = M.Last(row.name, "SetText")
  if call and type(call[1]) == "string" and call[1]:find("Player 12", 1, true) then return true end
 end
 return false
end
assert(pinned(), "the low-ranked local player is pinned")
K.Options.Write("Meters", "damage.alwaysPlayer", false); env.RunTimers()
assert(not pinned(), "the toggle releases the local player's reserved row")
K.Options.Write("Meters", "damage.format", "full"); env.RunTimers()
assert(env.Reveal(M.Last(list.rows[1].value, "SetText")[1]) == "full", "full values are sent straight to setters even when the formatter returns secrets")
env.BreakUpLargeNumbers = function() error("unavailable formatter") end
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
assert(not env.issecretvalue(M.Last(list.rows[1].value, "SetText")[1]), "a failing full formatter falls back to existing abbreviations")
env.BreakUpLargeNumbers = nil
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
assert(not env.issecretvalue(M.Last(list.rows[1].value, "SetText")[1]), "a missing full formatter also falls back")
K.Options.Write("Meters", "damage.format", "short"); env.RunTimers()
assert(#env._errors == 0 and K.ErrorCount() == 0, "meter options apply without errors")
print("meters parity ok")
