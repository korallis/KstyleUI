-- test-percent-rounding.lua: whole percentages follow Forever 9dc84f0's per-surface formulas, while restricted values keep their engine path.
local D = dofile("Tools/regression/databars_env.lua")
local cases = { 0, 0.4, 24.4, 24.5, 24.6, 99.6, 100, 114.6 }

do
	local _, _, ns = D.New({ enable = false })
	for _, pair in ipairs({ { 7000, 50000, 15 }, { 11, 20, 56 } }) do
		assert(ns.Format.Percent(pair[1], pair[2]) == pair[3], "divide before multiplying, exactly as Blizzard does")
	end
	for maximum = 1, 2000 do
		for current = 0, maximum do
			assert(ns.Format.Percent(current, maximum) == math.ceil(current / maximum * 100),
				"percentages must match Blizzard's division-first expression")
		end
	end
end

-- Blizzard_TextStatusBar/TextStatusBar.lua:181,191,197; ExpBarOverrides.lua:27.
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns, game = D.New({ width = screen[1], height = screen[2] })
	game.faction.currentReactionThreshold, game.faction.nextReactionThreshold = 0, 10000
	K.Options.Write("DataBars", "honor.show", "always")
	for _, percent in ipairs(cases) do
		local current, maximum = percent * 100, 10000
		local expected = math.ceil(current / maximum * 100)
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
	for _, pair in ipairs({ { 7000, 50000 }, { 11, 20 } }) do
		game.xp, game.xpMax, game.rested = pair[1], pair[2], pair[1]
		game.faction.currentStanding, game.faction.nextReactionThreshold = pair[1], pair[2]
		game.rank.renownReputationEarned, game.rank.renownLevelThreshold = pair[1], pair[2]
		env.FireEvent("PLAYER_XP_UPDATE", "player")
		env.FireEvent("UPDATE_FACTION")
		D.W.Settle(env)
		local percent = math.ceil(pair[1] / pair[2] * 100) .. "%"
		assert(ns.Bars.views.rep.text:GetText() == "Stormwind " .. percent, "reputation keeps Blizzard's operation order")
		assert(ns.Strip.VALUES.xp() == percent, "XP keeps Blizzard's operation order")
		assert(ns.Bars.views.honor.text:GetText():find(percent, 1, true), "honour keeps Blizzard's operation order")
	end
	game.faction.reaction = 8
	game.paragon[72] = { value = 12500, threshold = 10000, rewardPending = true }
	env.FireEvent("UPDATE_FACTION")
	D.W.Settle(env)
	local rep = ns.Sources.Reputation()
	-- Blizzard_StatusTrackingBar/Shared/ReputationBar.lua:103-107.
	assert(rep.current == 12500 % 10000 + 10000 and rep.max == 10000, "keep overflow while a paragon reward waits")
	local view = ns.Bars.views.rep
	assert(K.Options.Read("DataBars", "rep.rewardMarker") == true, "the reward marker defaults on")
	local option
	for _, row in ipairs(ns.Schema()) do
		if row.key == "rep.rewardMarker" then option = row end
	end
	assert(option and option.type == "toggle", "the reputation options expose the reward marker toggle")
	assert(view.text:GetText() == "Stormwind 125% \194\183 *", "mark a waiting reward with a compact asterisk")
	assert(not view.text:IsShown() and not view.plate:IsShown(), "a waiting reward respects hover-only text")
	D.W.Enter(view.holder)
	assert(view.text:IsShown() and view.plate:IsShown(), "hover reveals the same caption plate as the other bars")
	assert(view.plate:GetWidth() < view.holder:GetWidth(), "the pending reward caption must leave visible fill beside its plate")
	K.Options.Write("DataBars", "rep.rewardMarker", false)
	assert(view.text:GetText() == "Stormwind 125%", "turning off the reward marker preserves progress")
	K.Options.Write("DataBars", "rep.rewardMarker", true)
	assert(view.text:GetText() == "Stormwind 125% \194\183 *", "turning on the marker updates the pending caption")
	D.W.Leave(view.holder)
	assert(not view.text:IsShown(), "leaving hides the pending caption")
	K.Options.Write("DataBars", "rep.textHover", false)
	assert(view.text:IsShown(), "the player can keep the pending caption visible")
	K.Options.Write("DataBars", "rep.text", "none")
	assert(not view.text:IsShown() and not view.plate:IsShown(), "no text also hides the reward marker")
	K.Options.Write("DataBars", "rep.text", "labelPercent")
	K.Options.Write("DataBars", "rep.textHover", true)
	for _, style in ipairs({ "medallions", "orbs", "frames" }) do
		assert(not view.text:IsShown(), "pending reward respects hover text in " .. style)
		D.W.Enter(view.holder)
		assert(view.text:IsShown(), "hover reveals pending reward in " .. style)
		D.W.Leave(view.holder)
	end
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
	env.C_Reputation.IsFactionParagonForCurrentPlayer = nil
	assert(ns.Sources.Reputation().kind == "faction", "a missing paragon API keeps ordinary reputation")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("percent rounding ok")
