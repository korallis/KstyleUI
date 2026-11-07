-- databars_env.lua: load the core and KstyleUI_DataBars into a stub game whose experience, reputation, honour and Blizzard bars a test controls.
--
--   local D = dofile("Tools/regression/databars_env.lua")
--   local env, K, ns, game = D.New()      -- logged in, DataBars switched on and running
--   game.xp = 20000
--   env.FireEvent("PLAYER_XP_UPDATE")
--   D.W.Settle(env)                       -- run the value tweens to their end

local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local D = { W = W, CoreEnv = CoreEnv }
local FOLDER = "KstyleUI_DataBars"
D.FOLDER = FOLDER

-- Files() -> the module's Lua files in the order DataBars.xml loads them.
function D.Files()
	local out = {}
	for _, path in ipairs(TocFiles("%.lua$")) do
		if path:sub(1, #FOLDER + 1) == FOLDER .. "/" then
			out[#out + 1] = path
		end
	end
	return out
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = copy(v)
	end
	return out
end

-- Game(env, overrides) installs the game API the module reads. Each function reads the returned table,
-- so a test changes the game by changing a field and firing the event the game would fire.
function D.Game(env, overrides)
	local game = {
		level = 38, maxLevel = 60, xp = 12345, xpMax = 50000, rested = 8000, restState = 1, restName = "Rested",
		xpDisabled = false,
		faction = {
			factionID = 72, name = "Stormwind", reaction = 5, currentReactionThreshold = 3000,
			nextReactionThreshold = 9000, currentStanding = 4500,
		},
		friendship = {}, major = {}, paragon = {},
		rank = { renownLevel = 3, renownReputationEarned = 400, renownLevelThreshold = 1000, maxLevel = 14 },
		honor = 0, honorMax = 0, honorLevel = 0,
		battlefield = false, worldPvP = false,
		sex = 2,
	}
	for k, v in pairs(overrides or {}) do
		game[k] = copy(v)
	end
	env._game = game

	function env.UnitLevel(unit)
		return unit == "player" and game.level or 0
	end
	function env.UnitXP(unit)
		return unit == "player" and game.xp or 0
	end
	function env.UnitXPMax(unit)
		return unit == "player" and game.xpMax or 0
	end
	function env.GetXPExhaustion()
		return game.rested
	end
	function env.GetRestState()
		return game.restState, game.restName, 2
	end
	function env.IsXPUserDisabled()
		return game.xpDisabled
	end
	function env.GetMaxPlayerLevel()
		return game.maxLevel
	end
	function env.UnitSex()
		return game.sex
	end

	env.C_Reputation = {
		GetWatchedFactionData = function()
			return copy(game.faction)
		end,
		IsMajorFaction = function(id)
			return game.major[id] ~= nil
		end,
		IsFactionParagonForCurrentPlayer = function(id)
			return game.paragon[id] ~= nil
		end,
		GetFactionParagonInfo = function(id)
			local p = game.paragon[id]
			if p then
				return p.value, p.threshold, p.questID, p.rewardPending
			end
		end,
	}
	env.C_GossipInfo = {
		GetFriendshipReputation = function(id)
			return copy(game.friendship[id]) or { friendshipFactionID = 0, standing = 0, maxRep = 0, text = "", texture = 0, reaction = "", reactionThreshold = 0, reversedColor = false }
		end,
	}
	env.C_MajorFactions = {
		GetMajorFactionData = function(id)
			return copy(game.major[id])
		end,
		GetMajorFactionProgressionInfo = function(id)
			if id == 2800 then
				return copy(game.rank)
			end
		end,
	}
	function env.UnitHonor()
		return game.honor
	end
	function env.UnitHonorMax()
		return game.honorMax
	end
	function env.UnitHonorLevel()
		return game.honorLevel
	end
	env.C_PvP = {
		IsActiveBattlefield = function()
			return game.battlefield
		end,
	}
	function env.IsInActiveWorldPVP()
		return game.worldPvP
	end
	return game
end

-- Blizzard(env) builds stand-ins for Blizzard's status tracking bars: the manager, its two containers,
-- and mouse-enabled bars in each container, the experience bar with its exhaustion tick.
function D.Blizzard(env)
	local manager = env.CreateFrame("Frame", "StatusTrackingBarManager", env.UIParent)
	local containers = {}
	for i, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
		local container = env.CreateFrame("Frame", name, manager)
		container.bars = {}
		for index = 1, 3 do
			local bar = env.CreateFrame("Frame", nil, container)
			bar:EnableMouse(true)
			container.bars[index] = bar
		end
		local tick = env.CreateFrame("Frame", nil, container.bars[1])
		tick:EnableMouse(true)
		container.bars[1].ExhaustionTick = tick
		containers[i] = container
	end
	manager.barContainers = containers
	manager.MainStatusTrackingBarContainer, manager.SecondaryStatusTrackingBarContainer = containers[1], containers[2]
	return manager
end

-- New(opts) -> env, KstyleUI, the module's addon table, game. opts:
--   game       fields that replace the default game state
--   saved      KstyleUIDB as the game loads it
--   blizzard   false to leave out the Blizzard bar stand-ins
--   enable     false to leave DataBars switched off
--   setup      function(env, game) that runs before any addon file loads
function D.New(opts)
	opts = opts or {}
	local game
	local env, K = W.New({
		boot = false,
		saved = opts.saved,
		setup = function(env)
			game = D.Game(env, opts.game)
			if opts.blizzard ~= false then
				D.Blizzard(env)
			end
			if opts.setup then
				opts.setup(env, game)
			end
		end,
	})
	CoreEnv.LoadSaved(env)
	Load(D.Files(), env)
	CoreEnv.Login(env)
	if opts.enable ~= false then
		K.Modules.Enable("DataBars")
	end
	return env, K, env._addons[FOLDER], game
end

return D
