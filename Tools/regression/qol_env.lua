-- qol_env.lua: load the core and KstyleUI_QoL into a stub environment with stand-ins for the game's loot, merchant, quest, CVar and error-frame APIs.
--
--   local Q = dofile("Tools/regression/qol_env.lua")
--   local env, K, ns = Q.New()        -- core booted, KstyleUI_QoL loaded, module still off
--   Q.Enable(env, K)                  -- switches the module on
--   env.FireEvent("LOOT_READY", true) -- drives a feature
--   Q.Calls(env, "LootSlot")          -- every call a stand-in recorded, as argument lists
--
-- The stand-ins read env tables a test fills in:
--   env._loot = { { locked = false }, ... }        GetNumLootItems, GetLootSlotInfo
--   env._cvars[name] = "value"                     C_CVar.GetCVar, C_CVar.SetCVar, GetCVarBool
--   env._modified[action] = true                   IsModifiedClick
--   env._modifiers.shift / .ctrl / .alt            IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown
--   env._repair = { can, cost, money, inGuild, guild, withdraw, bank }
--   env._items[id] = { icon, quality, cached }     C_Item.GetItemInfoInstant, GetItemIconByID, GetItemQualityByID; cached = false
--                                                   leaves the quality unknown until env._items[id].cached = true and ITEM_DATA_LOAD_RESULT
--   env.Release()                                  C_Timer.After with a delay waits for it; a zero delay runs with RunTimers
--   env._quest = { autoAccept, pvp, completable, choices, money, fromMap, areaTrigger,
--                  active, available, gossipActive, gossipAvailable }
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local Q = { W = W, CoreEnv = W.CoreEnv }

local files
function Q.Files()
	if not files then
		files = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_QoL/") then
				files[#files + 1] = path
			end
		end
		assert(#files > 0, "no KstyleUI_QoL files found")
	end
	return files
end

-- The error types Retail's own UIErrorsFrame never shows, with stand-in numbers.
Q.ERRORS = {
	"LE_GAME_ERR_ABILITY_COOLDOWN", "LE_GAME_ERR_SPELL_COOLDOWN", "LE_GAME_ERR_OUT_OF_RANGE",
	"LE_GAME_ERR_OUT_OF_POWER_DISPLAY", "LE_GAME_ERR_OUT_OF_MANA", "LE_GAME_ERR_OUT_OF_RAGE",
	"LE_GAME_ERR_OUT_OF_ENERGY", "LE_GAME_ERR_OUT_OF_FOCUS", "LE_GAME_ERR_OUT_OF_RUNIC_POWER",
	"LE_GAME_ERR_OUT_OF_COMBO_POINTS", "LE_GAME_ERR_OUT_OF_HOLY_POWER", "LE_GAME_ERR_OUT_OF_SOUL_SHARDS",
	"LE_GAME_ERR_OUT_OF_CHI", "LE_GAME_ERR_OUT_OF_PAIN", "LE_GAME_ERR_OUT_OF_HEALTH",
	"LE_GAME_ERR_OUT_OF_ARCANE_CHARGES", "LE_GAME_ERR_OUT_OF_LUNAR_POWER", "LE_GAME_ERR_OUT_OF_INSANITY",
	"LE_GAME_ERR_OUT_OF_RUNES", "LE_GAME_ERR_OUT_OF_FURY", "LE_GAME_ERR_OUT_OF_MAELSTROM",
	"LE_GAME_ERR_OUT_OF_ESSENCE",
}
Q.ANOTHER_IN_PROGRESS = 900
Q.QUEST_PROGRESS_INFO = 901

local function Recorder(env, name, result)
	return function(...)
		local list = env._calls[name]
		if not list then
			list = {}
			env._calls[name] = list
		end
		list[#list + 1] = { n = select("#", ...), ... }
		if type(result) == "function" then
			return result(...)
		end
		return result
	end
end
Q.Recorder = Recorder

function Q.Game(env)
	env._calls = {}
	env.CreateColor = function(r, g, b, a)
		return { r = r, g = g, b = b, a = a }
	end
	env._time = 100
	env.GetTime = function()
		return env._time
	end
	env.SetTime = function(t)
		env._time = t
	end

	env._held = {}
	local after = env.C_Timer.After
	env.C_Timer.After = function(delay, fn)
		if delay > 0 then
			env._held[#env._held + 1] = fn
			return
		end
		after(delay, fn)
	end
	function env.Release()
		local held = env._held
		env._held = {}
		for _, fn in ipairs(held) do
			fn()
		end
		env.RunTimers()
	end

	env._items = {}
	env.C_Item = env.C_Item or {}
	env.C_Item.GetItemInfoInstant = function(id)
		local item = env._items[id]
		if not item then
			return nil
		end
		return id, "Armor", "Leather", "INVTYPE_CHEST", item.icon, 4, 2
	end
	env.C_Item.GetItemIconByID = function(id)
		local item = env._items[id]
		return item and item.icon or nil
	end
	env.C_Item.GetItemQualityByID = function(id)
		local item = env._items[id]
		if not item or item.cached == false then
			return nil
		end
		return item.quality
	end
	env.C_Item.RequestLoadItemDataByID = Recorder(env, "RequestLoadItemDataByID")

	-- The client's own GlobalStrings table, build 1.60.1.70862 (enUS), for the loot lines the feed reads.
	env.LOOT_ITEM_SELF = "You receive loot: %s"
	env.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d"
	env.LOOT_ITEM_PUSHED_SELF = "You receive item: %s"
	env.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d"
	env.LOOT_ITEM_CREATED_SELF = "You create: %s."
	env.LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
	env.LOOT_ITEM_BONUS_ROLL_SELF = "You receive bonus loot: %s"
	env.LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE = "You receive bonus loot: %sx%d"
	env.LOOT_ITEM = "%s receives loot: %s."
	env.YOU_LOOT_MONEY = "You loot %s"
	env.YOU_LOOT_MONEY_GUILD = "You loot %s (%s deposited to guild bank)"
	env.LOOT_MONEY_SPLIT = "Your share of the loot is %s."
	env.GOLD_AMOUNT = "%d Gold"
	env.SILVER_AMOUNT = "%d Silver"
	env.COPPER_AMOUNT = "%d Copper"

	env._loot = {}
	env.GetNumLootItems = function()
		return #env._loot
	end
	env.GetLootSlotInfo = function(slot)
		local item = env._loot[slot]
		if not item then
			return nil
		end
		return 134400, "Item " .. slot, 1, nil, 1, item.locked == true, false, nil, true, false
	end
	env.LootSlot = Recorder(env, "LootSlot")

	env._cvars = { autoLootDefault = "1", cameraDistanceMaxZoomFactor = "1.9" }
	env.GetCVarBool = function(name)
		return env._cvars[name] == "1"
	end
	env.C_CVar = {
		GetCVar = function(name)
			return env._cvars[name]
		end,
		GetCVarInfo = function(name)
			local value = env._cvars[name]
			if value then return value, value, false, false, false, false, false end
		end,
		SetCVar = Recorder(env, "SetCVar", function(name, value)
			if env._refuseCVar then
				return false
			end
			local number = tonumber(value)
			env._cvars[name] = number and string.format("%.6f", number) or tostring(value)
			return true
		end),
	}
	env._modified = {}
	env.IsModifiedClick = function(action)
		return env._modified[action] == true
	end
	env.IsAltKeyDown = function()
		return env._modifiers.alt == true
	end

	env._repair = { can = true, cost = 0, money = 0, inGuild = false, guild = false, withdraw = 0, bank = 0 }
	env.CanMerchantRepair = function()
		return env._repair.can
	end
	env.GetRepairAllCost = function()
		return env._repair.cost, env._repair.cost > 0
	end
	env.GetMoney = function()
		return env._repair.money
	end
	env.IsInGuild = function()
		return env._repair.inGuild
	end
	env.CanGuildBankRepair = function()
		return env._repair.guild
	end
	env.GetGuildBankWithdrawMoney = function()
		return env._repair.withdraw
	end
	env.GetGuildBankMoney = function()
		return env._repair.bank
	end
	env.RepairAllItems = Recorder(env, "RepairAllItems")
	env.GetMoneyString = function(money)
		return "<" .. tostring(money) .. "c>"
	end

	env._quest = {
		autoAccept = false, pvp = false, completable = false, choices = 0, money = 0, fromMap = false, areaTrigger = false,
		active = {}, available = {}, gossipActive = {}, gossipAvailable = {},
	}
	local quest = function(key)
		return function()
			return env._quest[key]
		end
	end
	env.QuestGetAutoAccept = quest("autoAccept")
	env.QuestFlagsPVP = quest("pvp")
	env.IsQuestCompletable = quest("completable")
	env.GetNumQuestChoices = quest("choices")
	env.GetQuestMoneyToGet = quest("money")
	env.QuestIsFromAdventureMap = quest("fromMap")
	env.QuestIsFromAreaTrigger = quest("areaTrigger")
	env.AcceptQuest = Recorder(env, "AcceptQuest")
	env.AcknowledgeAutoAcceptQuest = Recorder(env, "AcknowledgeAutoAcceptQuest")
	env.CompleteQuest = Recorder(env, "CompleteQuest")
	env.GetQuestReward = Recorder(env, "GetQuestReward")
	env.SelectActiveQuest = Recorder(env, "SelectActiveQuest")
	env.SelectAvailableQuest = Recorder(env, "SelectAvailableQuest")
	env.GetNumActiveQuests = function()
		return #env._quest.active
	end
	env.GetActiveTitle = function(i)
		local entry = env._quest.active[i]
		return entry.title, entry.complete
	end
	env.GetNumAvailableQuests = function()
		return #env._quest.available
	end
	env.GetAvailableQuestInfo = function(i)
		return env._quest.available[i].trivial
	end
	env.C_GossipInfo = {
		GetActiveQuests = function()
			return env._quest.gossipActive
		end,
		GetAvailableQuests = function()
			return env._quest.gossipAvailable
		end,
		SelectActiveQuest = Recorder(env, "C_GossipInfo.SelectActiveQuest"),
		SelectAvailableQuest = Recorder(env, "C_GossipInfo.SelectAvailableQuest"),
	}

	for i, name in ipairs(Q.ERRORS) do
		env[name] = 100 + i
	end
	env.LE_GAME_ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS = Q.ANOTHER_IN_PROGRESS
	-- Forever's UIErrorsFrameOverrides.lua empties Retail's list down to this one type.
	env.BLACK_LISTED_MESSAGE_TYPES = { [Q.ANOTHER_IN_PROGRESS] = true }
	local errors = env.CreateFrame("MessageFrame", "UIErrorsFrame", env.UIParent)
	errors._blizzard = true
	function errors:SetMessageTypeEnabled(messageType, enabled)
		if messageType then
			env.BLACK_LISTED_MESSAGE_TYPES[messageType] = not enabled
		end
	end
	env.UIErrorsFrame = errors

	-- Notices, aids and chores: env._instance = { inside, kind }, env._raid, env._group, env._dead[unit],
	-- env._names[unit], env._unspent, env._durability[slot] = { now, max }, env._equipped[slot] = item id,
	-- env._items[id].equipLoc, env._logging; MovieFrame:FinishMovie, LoggingCombat, PlaySound and
	-- C_ChatInfo.SendChatMessage record their calls.
	env._instance, env._dead, env._names, env._durability, env._equipped = { false, "none" }, {}, {}, {}, {}
	env.IsInInstance = function() return env._instance[1], env._instance[2] end
	env.IsInRaid = function() return env._raid == true end
	env.IsInGroup = function() return env._group == true or env._raid == true end
	env.UnitIsDeadOrGhost = function(unit) return env._dead[unit] == true end
	env.UnitIsUnit = function(a, b) return a == b end
	local name = env.UnitName
	env.UnitName = function(unit) if env._names[unit] ~= nil then return env._names[unit] end return name(unit) end
	env.SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960 }
	env.PlaySound = Recorder(env, "PlaySound")
	env.C_ClassTalents = { HasUnspentTalentPoints = function() return env._unspent == true, 0, 0 end }
	env.GetInventoryItemDurability = function(slot)
		local entry = env._durability[slot]
		if entry then return entry[1], entry[2] end
	end
	env.GetInventoryItemID = function(_, slot) return env._equipped[slot] end
	local instant = env.C_Item.GetItemInfoInstant
	env.C_Item.GetItemInfoInstant = function(id)
		local item = env._items[id]
		if item and item.equipLoc then return id, "Weapon", "Thrown", item.equipLoc, item.icon, 2, 16 end
		return instant(id)
	end
	env.LoggingCombat = Recorder(env, "LoggingCombat", function(on)
		if on ~= nil then env._logging = on end
		return env._logging == true
	end)
	env.INSTANCE_RESET_SUCCESS = "%s has been reset."
	env.C_ChatInfo = env.C_ChatInfo or {}
	env.C_ChatInfo.SendChatMessage = Recorder(env, "SendChatMessage")
	local status = env.CreateFrame("Frame", "ActionStatus", env.UIParent)
	status._blizzard = true
	status:RegisterEvent("SCREENSHOT_SUCCEEDED")
	env.ActionStatus = status
	local movie = env.CreateFrame("Frame", "MovieFrame", env.UIParent)
	movie._blizzard = true
	movie:Hide()
	movie.FinishMovie = Recorder(env, "FinishMovie", function() movie:Hide() end)
	env.MovieFrame = movie
end

-- New(opts) -> env, KstyleUI, the module's addon table. opts: the widget_env options (saved, width,
-- height and so on); opts.setup(env) runs after the stand-ins are installed and before any file loads.
-- VARIABLES_LOADED fires after the files load, as the game sends it once the character's CVars are in;
-- opts.variables = false holds it back so a test can fire it later.
function Q.New(opts)
	opts = opts or {}
	local wanted = {}
	for key, value in pairs(opts) do
		wanted[key] = value
	end
	wanted.setup = function(env)
		Q.Game(env)
		if opts.setup then
			opts.setup(env)
		end
	end
	local env, K = W.New(wanted)
	Load(Q.Files(), env)
	if opts.variables ~= false and opts.boot ~= false then
		env.FireEvent("VARIABLES_LOADED")
		env.RunTimers()
	end
	return env, K, env._addons.KstyleUI_QoL
end

function Q.Enable(env, K)
	K.Modules.Enable("QoL")
	env.RunTimers()
end

function Q.Disable(env, K)
	K.Modules.Disable("QoL")
	env.RunTimers()
end

function Q.Write(env, K, key, value)
	K.Options.Write("QoL", key, value)
	env.RunTimers()
end

function Q.Calls(env, name)
	return env._calls[name] or {}
end

function Q.Reset(env)
	env._calls = {}
end

-- Muted(env) -> how many of Q.ERRORS the error frame hides.
function Q.Muted(env)
	local count = 0
	for _, name in ipairs(Q.ERRORS) do
		if env.BLACK_LISTED_MESSAGE_TYPES[env[name]] == true then
			count = count + 1
		end
	end
	return count
end

return Q
