-- test-percent-rounding.lua: whole percentages follow Forever 9dc84f0's per-surface formulas, while restricted values keep their engine path.
local D = dofile("Tools/regression/databars_env.lua")
local cases = { 0, 0.4, 24.4, 24.5, 24.6, 99.6, 100, 114.6 }

-- Blizzard_TextStatusBar/TextStatusBar.lua:181,191,197; ExpBarOverrides.lua:27.
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns, game = D.New({ width = screen[1], height = screen[2] })
	for _, percent in ipairs(cases) do
		local current, maximum = percent * 100, 10000
		local expected = math.ceil(current * 100 / maximum)
		assert(ns.Format.Percent(current, maximum, true) == expected,
			"use the shared Blizzard whole-percent formula: " .. percent .. "% must show " .. expected .. "%")
		game.xp, game.xpMax, game.rested = current, maximum, current
		env.FireEvent("PLAYER_XP_UPDATE", "player")
		D.W.Settle(env)
		assert(ns.Strip.VALUES.xp() == math.min(100, expected) .. "%", "the strip uses the bar's percentage")
		assert(ns.Format.BarText("percentRested", current, maximum, nil, nil, current)
			== math.min(100, expected) .. "%" .. (current > 0 and " \194\183 rested " .. expected .. "%" or ""),
			"XP and rested captions share the same rounding, including rested overflow")
	end
	game.faction.reaction = 8
	game.paragon[72] = { value = 12500, threshold = 10000, rewardPending = true }
	env.FireEvent("UPDATE_FACTION")
	D.W.Settle(env)
	local rep = ns.Sources.Reputation()
	-- Blizzard_StatusTrackingBar/Shared/ReputationBar.lua:103-107.
	assert(rep.current == 12500 % 10000 + 10000 and rep.max == 10000, "keep overflow while a paragon reward waits")
	assert(ns.Bars.views.rep.text:GetText() == "Stormwind 125% \194\183 Reward ready", "show paragon progress and the waiting reward on the bar")
	game.paragon[72].rewardPending = false
	env.FireEvent("UPDATE_FACTION")
	D.W.Settle(env)
	assert(ns.Bars.views.rep.text:GetText() == "Stormwind 25%", "claiming the reward clears the indicator and wraps progress")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("percent rounding ok")
