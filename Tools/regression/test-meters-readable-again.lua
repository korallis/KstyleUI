-- test-meters-readable-again.lua: readable data restores the meter's aside after a hidden session paused it.
local M = dofile("Tools/regression/meters_env.lua")
for _, size in ipairs({ 0, 2 }) do
	local env, K, ns = M.New({ game = function(e) e._group = { raid = false, size = size } end })
	env._units.player.guid = "Player-1"
	env._session = { combatSources = {
		{ name = "Tester", classFilename = "WARRIOR", totalAmount = 2840, amountPerSecond = 28.4, sourceDisplayType = 1, isLocalPlayer = true },
	}, maxAmount = 2840, totalAmount = 2840, durationSeconds = 30 }
	local source = { combatSpells = { { spellID = 100, totalAmount = 2840, amountPerSecond = 28.4 } }, maxAmount = 2840, totalAmount = 2840 }
	env._sources[env.UnitGUID("player")] = source
	M.Enable(env, K)
	local list = ns.Damage.list
	local function Update()
		env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
		env.RunTimers()
	end
	Update()
	local before = list.column:GetText()
	local withheld = size == 0 and source or env._session
	env._locked[withheld] = true
	Update()
	assert(list.column:GetText() == K.L["Paused"], "the fixture must pause a populated meter")
	env._locked[withheld] = nil
	Update()
	assert(list.column:GetText() == before and list.switchWords, "restore the fight switch after hidden meter data becomes readable")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "meter recovery must leave no errors")
end
print("meters readable again ok")
