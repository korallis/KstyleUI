-- test-unitframes-energy-tick.lua: the player's energy tick spark, on both HUD styles: it is on by default, polls energy only while it is readable and below its maximum, waits for a natural two-second tick, loops across the bar from that tick, ignores refunds, keeps its phase while hidden at full energy, never compares secret values, hides out of cat form and when off.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

for _, frames in ipairs({ false, true }) do
	local style = frames and "Frames" or "Medallions"
	local env, K, ns = U.New({ frames = frames, setup = function(e)
		e.GetPowerRegen = function() return 10, 10 end
	end })
	local function check(ok, message) assert(ok, style .. ": " .. message) end
	local me, player = env._units.player, ns.Frames.Get("player").views[1]
	local plays = {}
	-- The game reports a spend through UNIT_POWER_UPDATE; a tick lands on the next frame the poll draws.
	local function spend(value, at)
		env._time, me.power = at, value
		env.FireEvent("UNIT_POWER_UPDATE", "player", "ENERGY")
	end
	local function tick(value, at)
		env._time, me.power = at, value
		W.Tick(env, 0.016)
	end
	local function polling()
		return player.energyPoll ~= nil and player.energyPoll:IsShown()
	end

	check(ns.Settings.Value("player", "energyTick") == true, "the energy tick is on by default")
	check(player.energySpark == nil and not polling(), "a mana user gets no energy spark and no poll")

	me.class, me.powerType, me.powerToken, me.power, me.powerMax = "ROGUE", 3, "ENERGY", 100, 100
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	check(not polling(), "full energy runs no OnUpdate")
	spend(60, 10)
	check(polling() and player.energySpark == nil, "below full it polls, and waits for a natural tick to show the cadence")
	tick(80, 11)
	local spark = assert(player.energySpark, style .. ": a natural tick starts the spark")
	local play = spark.group.Play
	spark.group.Play = function(self, reverse, offset)
		plays[#plays + 1] = offset
		return play(self, reverse, offset)
	end
	check(spark:IsShown() and spark.group:IsPlaying(), "the spark sweeps from the tick")
	check(W.LastCall(spark.group, "SetLooping")[1] == "REPEAT" and W.LastCall(spark.move, "SetDuration")[1] == 2, "it loops every two seconds")
	local offset = W.LastCall(spark.move, "SetOffset")
	check(math.abs(offset[1] - player.power.opts.width) < 1 and offset[2] == 0, "it crosses the bar")

	spend(40, 11.4)
	tick(65, 11.8)
	check(#plays == 0, "a spend and a 25-energy refund do not resync it")
	tick(85, 13)
	check(plays[1] == 0, "the next natural tick resyncs it")

	tick(100, 15)
	check(not spark:IsShown() and not spark.group:IsPlaying() and not polling(), "full energy hides it and stops the poll")
	spend(55, 15.5)
	check(spark:IsShown() and math.abs(plays[2] - 0.5) < 1e-9 and polling(), "spending from full shows it at the tick's phase")

	env._restricted = true
	tick(75, 17)
	check(spark:IsShown() and spark.group:IsPlaying() and #plays == 2 and not polling(), "secret energy stops the poll and keeps the last cadence sweeping")
	env._restricted = false
	spend(30, 17.5)
	check(polling() and spark:IsShown() and #plays == 2, "readable energy polls again without moving the sweep")

	me.class, me.powerType, me.powerToken = "DRUID", 0, "MANA"
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	check(not spark:IsShown() and not spark.group:IsPlaying() and not polling(), "leaving cat form hides it and stops the poll")
	me.powerType, me.powerToken, me.power = 3, "ENERGY", 0
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	check(spark:IsShown() and polling(), "back in cat form it sweeps on the kept cadence")

	K.Options.Write("UnitFrames", "player.energyTick", false)
	env.RunTimers()
	check(not spark:IsShown() and not spark.group:IsPlaying() and not polling(), "off stops and hides it")
	spend(20, 19)
	check(not spark:IsShown() and not polling(), "off, energy changes leave it hidden")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

print("ok - test-unitframes-energy-tick")
