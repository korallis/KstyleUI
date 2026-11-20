-- test-percent-rounding.lua: whole percentages follow Forever 9dc84f0's per-surface formulas, while restricted values keep their engine path.
local D = dofile("Tools/regression/databars_env.lua")
local cases = { 0, 0.4, 24.4, 24.5, 24.6, 99.6, 100, 114.6 }

-- Blizzard_TextStatusBar/TextStatusBar.lua:181,191,197; ExpBarOverrides.lua:27.
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns, game = D.New({ width = screen[1], height = screen[2] })
	game.faction.currentReactionThreshold, game.faction.nextReactionThreshold = 0, 10000
	K.Options.Write("DataBars", "honor.show", "always")
	for _, percent in ipairs(cases) do
		local current, maximum = percent * 100, 10000
		local expected = math.ceil(current * 100 / maximum)
		assert(ns.Format.Percent(current, maximum, true) == expected,
			"use the shared Blizzard whole-percent formula: " .. percent .. "% must show " .. expected .. "%")
		game.xp, game.xpMax, game.rested = current, maximum, current
		game.faction.currentStanding = current
		game.rank.renownReputationEarned, game.rank.renownLevelThreshold = current, maximum
		game.durability = { [1] = { current, maximum } }
		env.FireEvent("PLAYER_XP_UPDATE", "player")
		env.FireEvent("UPDATE_FACTION")
		env.FireEvent("UPDATE_INVENTORY_DURABILITY")
		D.W.Settle(env)
		local honor = ns.Sources.Honor()
		assert(ns.Format.Percent(honor.current, honor.max) == math.min(100, expected), "honour and rank progress share Blizzard's status-bar formula")
		assert(ns.Strip.VALUES.durability() == math.min(100, expected) .. "%", "custom durability text follows the shared status-bar formula")
		assert(ns.Bars.views.rep.text:GetText() == "Stormwind " .. math.min(100, expected) .. "%", "reputation uses the same rounding")
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
	assert(ns.Bars.views.rep.text:IsShown(), "a waiting reward remains visible without hovering")
	game.paragon[72].rewardPending = false
	env.FireEvent("UPDATE_FACTION")
	D.W.Settle(env)
	assert(ns.Bars.views.rep.text:GetText() == "Stormwind 25%", "claiming the reward clears the indicator and wraps progress")
	assert(not ns.Bars.views.rep.text:IsShown(), "claiming the reward restores hover-only text")
	for _, style in ipairs({ "percent", "valuePercent", "labelPercent", "shortPercent", "levelRested", "percentRested" }) do
		assert(ns.Format.BarText(style, 12500, 10000, "Stormwind", nil, nil, true):find("125%", 1, true), "every paragon percentage format preserves overflow")
	end
	for _, pending in ipairs({ false, true }) do
		for _, value in ipairs({ 0, 9999, 10000, 12500, 22500 }) do
			game.paragon[72] = { value = value, threshold = 10000, rewardPending = pending }
			assert(ns.Sources.Reputation().current == value % 10000 + (pending and 10000 or 0), "paragon wrap and reward boundaries match Blizzard")
		end
	end
	env.C_Reputation.IsFactionParagonForCurrentPlayer = function() return env.Secret(true) end
	local hidden, why = ns.Sources.Reputation()
	assert(hidden == nil and why == "secret", "never compare a secret paragon flag")
	env.C_Reputation.IsFactionParagonForCurrentPlayer = nil
	assert(ns.Sources.Reputation().kind == "faction", "a missing paragon API keeps ordinary reputation")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("percent rounding ok")
