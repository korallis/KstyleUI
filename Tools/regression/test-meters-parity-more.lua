-- test-meters-parity-more.lua: legacy refresh, hover count, pinned rank, icon crop and spell tooltip defaults persist, and new settings change the damage window.
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
for i = 1, 12 do env._spells[i] = { name = "Spell " .. i, icon = 1000 + i } end
assert(ns.Get("damage.iconZoom") == 0.08 and not ns.Get("damage.spellTooltips"), "v0.2.8 icon crop and spell tooltip defaults")
local row = list.rows[1]
row.frame._scripts.OnMouseUp(row.frame, "LeftButton"); env.RunTimers()
local function crop(expected)
	local call = M.Last(row.icon, "SetTexCoord")
	assert(call and math.abs(call[1] - expected) < 1e-6 and math.abs(call[2] - (1 - expected)) < 1e-6, "spell icons crop " .. expected)
end
crop(0.08)
M.Write(env, K, "damage.iconZoom", 0.2); crop(0.2)
assert(K.Store.Module("Meters").damage.iconZoom == 0.2, "zoom is saved")
M.Write(env, K, "damage.iconZoom", 0.08); crop(0.08)
local owner, shown
env.GameTooltip = { SetOwner = function(_, frame) owner = frame end, SetSpellByID = function(_, id) shown = id end, AddLine = function() end,
	Show = function() end, Hide = function() owner = nil end, IsOwned = function(_, frame) return owner == frame end }
local tip = K.Widgets.Tooltip()
assert(list.rowTooltip(tip, list, 1) == true and shown == nil, "the back hint stays the only tooltip by default")
M.Write(env, K, "damage.spellTooltips", true)
assert(K.Store.Module("Meters").damage.spellTooltips == true, "spell tooltips are saved")
assert(list.rowTooltip(tip, list, 1) == false and shown == 1 and owner == row.frame, "the game's spell tooltip shows for the pointed spell")
row.frame._scripts.OnLeave(row.frame)
assert(owner == nil, "leaving the row hides the spell tooltip")
assert(list.rowTooltip(tip, list, 1) == false and owner == row.frame, "the spell tooltip shows again")
local get, reads = ns.Get, 0
ns.Get = function(key) if key == "damage.iconZoom" then reads = reads + 1 end return get(key) end
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
ns.Get = get
assert(reads == 0 and owner == row.frame, "a refresh reads no crop and keeps the tooltip of an unchanged row")
row.frame._scripts.OnMouseUp(row.frame, "LeftButton"); env.RunTimers()
assert(owner == nil, "going back hides the spell tooltip of a row that changes")
M.Write(env, K, "damage.spellTooltips", false)
assert(#env._errors == 0 and K.ErrorCount() == 0, "more meter settings apply without errors")
local solo, SK, sns = M.New({ game = function(e) e._group = { raid = false, size = 0 } end })
solo._units.player.guid = "Player-1"
solo._session = { combatSources = { { name = "Tester", classFilename = "WARRIOR", totalAmount = 100, amountPerSecond = 10, sourceDisplayType = 1, isLocalPlayer = true } }, maxAmount = 100, totalAmount = 100, durationSeconds = 10 }
solo._spells[100] = { name = "Test spell", icon = 101 }
solo._sources["Player-1"] = { combatSpells = { { spellID = 100, totalAmount = 100, amountPerSecond = 10 } }, maxAmount = 100, totalAmount = 100 }
M.Enable(solo, SK); M.Write(solo, SK, "damage.spellTooltips", true)
local hint
shown = nil
solo.GameTooltip = { SetOwner = function() end, SetSpellByID = function(_, id) shown = id end, AddLine = function() hint = true end, Show = function() end,
	Hide = function() end, IsOwned = function() return false end }
solo.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4); solo.RunTimers()
local own = sns.Damage.list
assert(sns.Damage.resting and own.count == 1, "a solo player sees their own spells")
assert(own.rowTooltip(SK.Widgets.Tooltip(), own, 1) == false and shown == 100 and not hint, "a solo player's spells show their tooltip without the back hint")
assert(#solo._errors == 0 and SK.ErrorCount() == 0, "solo spell tooltips show without errors")
print("more meter parity ok")
