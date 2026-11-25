-- test-unitframes-energy-tick.lua: the player's energy tick spark, on both HUD styles: it is on by default, waits for a natural two-second tick (one that fills the bar counts), loops across the visible track inside the bar from that tick, ignores refunds, keeps its phase while hidden at full energy, reads energy at most ten times a second only while it is readable, below its maximum and changing, re-arms only when energy changes, never compares secret values, and hides out of cat form and when off.
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
	local made = ns.Style.Spark
	ns.Style.Spark = function(view, key)
		local spark = made(view, key)
		if key == "energySpark" and not spark.counted then
			local play = spark.group.Play
			spark.group.Play = function(self, reverse, offset)
				plays[#plays + 1] = offset
				return play(self, reverse, offset)
			end
			spark.counted = true
		end
		return spark
	end
	-- The game reports a change through UNIT_POWER_UPDATE; the poll reads energy on its next tenth of a second.
	local function spend(value, at)
		env._time, me.power = at, value
		env.FireEvent("UNIT_POWER_UPDATE", "player", "ENERGY")
	end
	local function tick(value, at)
		env._time, me.power = at, value
		W.Tick(env, 0.1)
	end
	local function polling()
		return player.energyPoll ~= nil and player.energyPoll:GetScript("OnUpdate") ~= nil
	end

	check(ns.Settings.Value("player", "energyTick") == true, "the energy tick is on by default")
	check(player.energySpark == nil and not polling(), "a mana user gets no energy spark and no poll")

	me.class, me.powerType, me.powerToken, me.power, me.powerMax = "ROGUE", 3, "ENERGY", 80, 100
	env._time = 1
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	check(polling() and player.energySpark == nil, "below full it polls, and waits for a natural tick to show the cadence")
	local reads, read = 0, env.UnitPower
	env.UnitPower = function(...)
		reads = reads + 1
		return read(...)
	end
	for _ = 1, 240 do W.Tick(env, 1 / 240) end
	env.UnitPower = read
	check(reads <= 10, "a second at 240 frames reads energy at most ten times, got " .. reads)
	tick(100, 2)
	check(player.energySpark == nil and not polling(), "full energy shows nothing and stops the poll")
	spend(60, 2.4)
	local spark = assert(player.energySpark, style .. ": a natural tick that fills the bar sets the cadence")
	check(spark:IsShown() and spark.group:IsPlaying() and math.abs(plays[1] - 0.4) < 1e-9 and polling(), "spending from full shows it at that tick's phase")
	check(W.LastCall(spark.group, "SetLooping")[1] == "REPEAT" and W.LastCall(spark.move, "SetDuration")[1] == 2, "it loops every two seconds")

	-- The line sweeps the visible track: from clear of the Medallions portrait to the bar's far end, inside the bar.
	local g, w = player.geometry, player.power:GetWidth()
	local cover = g.medal and math.max(0, g.medal.x + g.medal.w - g.power.x) or 0
	local point, _, relative, x, y = spark:GetPoint(1)
	local across, run = W.LastCall(spark, "SetSize")[1], W.LastCall(spark.move, "SetOffset")
	check(point == "LEFT" and relative == "LEFT" and y == 0 and x >= cover - 1e-6, "the line starts inside the bar, clear of the portrait (x " .. tostring(x) .. ", cover " .. cover .. ")")
	check(run[1] > 0 and run[2] == 0 and math.abs(x + across + run[1] - w) < 1e-6, "the line ends flush with the inside of the bar's far end")
	check(frames == (cover == 0), "only the Medallions portrait covers the bar's start")

	spend(40, 2.9)
	tick(65, 3.3)
	check(#plays == 1, "a spend and a 25-energy refund do not resync it")
	tick(85, 4)
	check(plays[2] == 0, "the next natural tick resyncs it")

	for _ = 1, 50 do W.Tick(env, 0.1) end
	check(not polling() and spark:IsShown(), "unchanged energy stops the poll; the sweep runs on")
	env.FireEvent("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
	check(not polling(), "a power event that leaves energy alone does not re-arm it")
	spend(45, 10)
	check(polling(), "the next energy change re-arms it")
	env._restricted = true
	tick(75, 11)
	check(spark:IsShown() and spark.group:IsPlaying() and #plays == 2 and not polling(), "secret energy stops the poll and keeps the last cadence sweeping")
	env._restricted = false
	spend(30, 11.5)
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
	spend(20, 13)
	check(not spark:IsShown() and not polling(), "off, energy changes leave it hidden")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

print("ok - test-unitframes-energy-tick")
