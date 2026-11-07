-- test-databars-sources.lua: the data bars read experience, reputation and honour from the game's API, guarded against missing functions and secret values.
local D = dofile("Tools/regression/databars_env.lua")

local function fresh(game, setup)
	local env, K, ns, g = D.New({ enable = false, game = game, setup = setup })
	return ns.Sources, g, env, K
end

local function eq(got, want, what)
	assert(got == want, string.format("%s: expected %s, got %s", what, tostring(want), tostring(got)))
end

-- Experience --------------------------------------------------------------------------------------

do
	local Sources = fresh()
	local xp = assert(Sources.XP(), "experience shows below the level cap")
	eq(xp.current, 12345, "current XP")
	eq(xp.max, 50000, "XP to level")
	eq(xp.rested, 8000, "rested XP")
	eq(xp.level, 38, "level")
	eq(xp.label, "Level 38", "the XP bar's name")
	eq(xp.restName, "Rested", "the rest state's name from the game")
end

do
	local Sources = fresh({ rested = false })
	eq(Sources.XP().rested, 0, "no rested XP when GetXPExhaustion has none")
end

do
	local Sources, game = fresh({ level = 60 })
	local xp, why = Sources.XP()
	eq(xp, nil, "no experience bar at the level cap")
	eq(why, "max level", "the reason")
	game.level = 59
	assert(Sources.XP(), "one level under the cap shows the bar")
	game.xpDisabled = true
	eq(select(2, Sources.XP()), "disabled", "a player who turned experience off sees no bar")
end

do
	local rule = true
	local Sources = fresh(nil, function(env)
		env.GameRulesUtil = { CanShowExperienceBar = function()
			return rule
		end }
	end)
	assert(Sources.XP(), "the game's own rule allows the bar")
	rule = false
	eq(Sources.XP(), nil, "the game's own rule hides the bar even below the cap")
end

do
	local Sources = fresh(nil, function(env)
		env.UnitXP = nil
	end)
	local xp, why = Sources.XP()
	eq(xp, nil, "no bar on a client without UnitXP")
	eq(why, "missing", "the reason")
end

do
	local Sources, game, env = fresh()
	game.xp = env.Secret(100)
	local xp, why = Sources.XP()
	eq(xp, nil, "a secret XP value is never compared or shown")
	eq(why, "secret", "the reason")
	game.xp, game.xpMax = 10, 0
	eq(select(2, Sources.XP()), "empty", "an empty range shows nothing")
end

-- Reputation ---------------------------------------------------------------------------------------

do
	local Sources = fresh()
	local rep = assert(Sources.Reputation(), "a watched faction shows")
	eq(rep.kind, "faction", "kind")
	eq(rep.current, 1500, "standing within the reaction")
	eq(rep.max, 6000, "the reaction's span")
	eq(rep.reaction, 5, "reaction")
	eq(rep.name, "Stormwind", "name")
	eq(rep.label, "Stormwind", "the bar's name is the faction's")
	eq(rep.standing, "Friendly", "the standing's name without the client's strings")
	eq(rep.capped, false, "not capped")
end

do
	local Sources = fresh(nil, function(env)
		env.GetText = function(token, sex)
			return token .. "/" .. tostring(sex)
		end
	end)
	eq(Sources.Reputation().standing, "FACTION_STANDING_LABEL5/2", "the client's own standing names win")
end

do
	local Sources = fresh({ faction = { factionID = 72, name = "Stormwind", reaction = 8, currentReactionThreshold = 42000, nextReactionThreshold = 42000, currentStanding = 42999 } })
	local rep = Sources.Reputation()
	eq(rep.capped, true, "exalted is capped")
	eq(rep.current, 1, "a capped bar is full")
	eq(rep.max, 1, "a capped bar is full")
end

do
	local Sources, game = fresh({ faction = false })
	eq(Sources.Reputation(), nil, "no bar without a watched faction")
	game.faction = { factionID = 0, name = "", reaction = 4, currentReactionThreshold = 0, nextReactionThreshold = 0, currentStanding = 0 }
	eq(Sources.Reputation(), nil, "faction 0 means none is watched")
end

do
	local Sources, game = fresh()
	game.friendship[72] = { friendshipFactionID = 72, standing = 2500, maxRep = 42000, reactionThreshold = 2100, nextThreshold = 4200, reaction = "Buddy", text = "", texture = 0, reversedColor = false }
	local rep = Sources.Reputation()
	eq(rep.kind, "friend", "a friendship")
	eq(rep.current, 400, "friendship standing within the rank")
	eq(rep.max, 2100, "the rank's span")
	eq(rep.standing, "Buddy", "the friendship rank's own name")
	game.friendship[72].nextThreshold = nil
	rep = Sources.Reputation()
	eq(rep.capped, true, "the last friendship rank is capped")
	eq(rep.current .. "/" .. rep.max, "1/1", "and full")
end

do
	local Sources, game = fresh()
	game.major[72] = { factionID = 72, name = "Stormwind", renownLevel = 4, renownReputationEarned = 1250, renownLevelThreshold = 2500, maxLevel = 20 }
	local rep = Sources.Reputation()
	eq(rep.kind, "major", "a renown faction")
	eq(rep.current, 1250, "renown earned")
	eq(rep.max, 2500, "renown threshold")
	eq(rep.level, 4, "renown level")
	eq(rep.standing, "Renown 4", "renown standing")
end

do
	local Sources, game = fresh()
	game.paragon[72] = { value = 12500, threshold = 10000 }
	local rep = Sources.Reputation()
	eq(rep.kind, "paragon", "a paragon faction")
	eq(rep.current, 2500, "paragon progress wraps at the threshold")
	eq(rep.max, 10000, "paragon threshold")
	eq(rep.rewardPending, false, "no reward waiting")
	game.paragon[72] = { value = 10000, threshold = 10000, rewardPending = true }
	rep = Sources.Reputation()
	eq(rep.current, 10000, "a waiting paragon reward fills the bar instead of wrapping to empty")
	eq(rep.rewardPending, true, "and says a reward waits")
end

do
	local Sources, game, env = fresh()
	game.faction.currentStanding = env.Secret(4500)
	local rep, why = Sources.Reputation()
	eq(rep, nil, "a secret standing is never compared")
	eq(why, "secret", "the reason")
end

-- Honour -------------------------------------------------------------------------------------------

do
	local Sources = fresh()
	local honor = assert(Sources.Honor(), "Forever's PvP rank shows as honour")
	eq(honor.kind, "rank", "kind")
	eq(honor.current, 400, "rank points earned")
	eq(honor.max, 1000, "rank threshold")
	eq(honor.level, 3, "rank")
	eq(honor.label, "Rank 3", "the bar's name")
end

do
	local Sources = fresh({ rank = { renownLevel = 14, renownReputationEarned = 0, renownLevelThreshold = 0, maxLevel = 14 } })
	local honor = Sources.Honor()
	eq(honor.capped, true, "the top rank is capped")
	eq(honor.current .. "/" .. honor.max, "1/1", "and full")
end

do
	local Sources = fresh({ rank = false, honor = 300, honorMax = 1000, honorLevel = 2 })
	local honor = assert(Sources.Honor(), "honour falls back to UnitHonor without the rank faction")
	eq(honor.kind, "honor", "kind")
	eq(honor.current, 300, "honour")
	eq(honor.max, 1000, "honour to the next level")
	eq(honor.label, "Honor level 2", "the bar's name")
end

do
	local Sources = fresh({ rank = false })
	local honor, why = Sources.Honor()
	eq(honor, nil, "no honour bar without rank or honour data")
	eq(why, "empty", "the reason")
end

do
	local Sources, game = fresh()
	eq(Sources.InPvP(), false, "not in PvP")
	game.battlefield = true
	eq(Sources.InPvP(), true, "a battleground is PvP")
	game.battlefield, game.worldPvP = false, true
	eq(Sources.InPvP(), true, "a world PvP zone is PvP")
end

do
	local Sources = fresh({ worldPvP = true }, function(env)
		env.C_PvP = nil
	end)
	eq(Sources.InPvP(), true, "world PvP still counts without C_PvP")
end

print("databars sources ok")
