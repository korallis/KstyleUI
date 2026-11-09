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
		fps = 144.2, latencyHome = 34, latencyWorld = 41, bandwidthIn = 1.5, bandwidthOut = 0.25,
		money = 1438217,
		durability = { [1] = { 96, 100 }, [5] = { 100, 100 }, [16] = { 80, 80 } },
		localTime = { hour = 14, min = 32, year = 2026, month = 11, day = 7, wday = 7 },
		realmHour = 9, realmMinute = 5,
	}
	for k, v in pairs(overrides or {}) do
		game[k] = copy(v)
	end
	env._game = game

	function env.CreateColor(r, g, b, a)
		return { r = r, g = g, b = b, a = a }
	end
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

	function env.GetFramerate()
		return game.fps
	end
	function env.GetNetStats()
		return game.bandwidthIn, game.bandwidthOut, game.latencyHome, game.latencyWorld
	end
	function env.GetMoney()
		return game.money
	end
	game.durabilityCalls = 0
	function env.GetInventoryItemDurability(slot)
		game.durabilityCalls = game.durabilityCalls + 1
		local d = game.durability[slot]
		if d then
			return d[1], d[2]
		end
	end
	function env.GetGameTime()
		return game.realmHour, game.realmMinute
	end
	game.dateCalls = {}
	function env.date(fmt)
		game.dateCalls[fmt] = (game.dateCalls[fmt] or 0) + 1
		if fmt == "*t" then
			return copy(game.localTime)
		elseif fmt == "%H" then
			return string.format("%02d", game.localTime.hour)
		elseif fmt == "%M" then
			return string.format("%02d", game.localTime.min)
		end
		return "Saturday 7 November"
	end
	return game
end

-- Targets(env) builds stand-ins for the Blizzard buttons the strip's secure clicks reach.
function D.Targets(env)
	for _, name in ipairs({ "MainMenuBarBackpackButton", "CharacterMicroButton", "GameTimeFrame" }) do
		env.CreateFrame("Button", name, env.UIParent)
	end
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

-- Forever's micro buttons in the order Camelot's GenerateButtonInfos adds them, each with the atlas of its glyph,
-- and the bag bar from left to right as Forever's bar grows left from the backpack.
D.MICRO = {
	{ "CharacterMicroButton" }, { "ProfessionMicroButton", "Professions" }, { "SpellbookMicroButton", "SpellbookAbilities" },
	{ "TalentMicroButton", "SpecTalents" }, { "LegacyMicroButton", "Legacy" }, { "QuestLogMicroButton", "Questlog" },
	{ "HousingMicroButton", "Housing" }, { "GuildMicroButton", "GuildCommunities" }, { "LFDMicroButton", "Groupfinder" },
	{ "CollectionsMicroButton", "Collections" }, { "EJMicroButton", "AdventureGuide" }, { "HelpMicroButton", "Help" },
	{ "StoreMicroButton", "Shop" }, { "MainMenuMicroButton", "GameMenu" },
}
D.KEYRING = -2
D.BAGS = {
	{ "KeyRingButton", D.KEYRING }, { "CharacterReagentBag0Slot", 5 }, { "CharacterBag3Slot", 4 }, { "CharacterBag2Slot", 3 },
	{ "CharacterBag1Slot", 2 }, { "CharacterBag0Slot", 1 }, { "MainMenuBarBackpackButton", 0 },
}

-- Menus(env, opts) -> game: stand-ins for Blizzard's micro menu (MicroMenuContainer > MicroMenu > the buttons,
-- Help hidden) and bag bar (BagsBar > BagSlotCluster > the slots, the reagent bag hidden), with the container,
-- inventory and portrait API the Menus part reads. opts.glyphs maps a micro button's name to a texture (a file
-- ID or path) its normal texture shows instead of Blizzard's atlas; opts.bags maps an inventory slot (31 to 35)
-- to the texture of the bag equipped there; opts.backpack and opts.keyring give those two buttons' icons.
-- game.free holds the free slots per bag, game.textures the bag textures by inventory slot.
function D.Menus(env, opts)
	opts = opts or {}
	local glyphs = opts.glyphs or {}
	local game = {
		free = { [0] = 4, [1] = 10, [2] = 0, [3] = 2, [4] = 6, [5] = 0, [D.KEYRING] = 0 }, slots = 16, cursor = false, calls = {},
		textures = opts.bags or { [31] = 1001, [32] = 1002, [33] = 1003 },
	}
	env._menus = game
	local container = env.CreateFrame("Frame", "MicroMenuContainer", env.UIParent)
	local menu = env.CreateFrame("Frame", "MicroMenu", container)
	for i, def in ipairs(D.MICRO) do
		local button = env._G[def[1]] or env.CreateFrame("Button", def[1], menu)
		button:SetParent(menu)
		button.layoutIndex = i
		button.callbacks = {}
		function button.RegisterCallback(self, event, fn, owner)
			self.callbacks[#self.callbacks + 1] = { event, fn, owner }
		end
		function button.TriggerEvent(self, event, ...)
			for _, callback in ipairs(self.callbacks) do
				if callback[1] == event then
					callback[2](callback[3], ...)
				end
			end
		end
		if def[2] then
			local normal = button:CreateTexture(nil, "ARTWORK")
			if glyphs[def[1]] then
				normal:SetTexture(glyphs[def[1]])
			else
				normal:SetAtlas("UI-HUD-MicroMenu-" .. def[2] .. "-Up")
			end
			button:SetNormalTexture(normal)
		end
	end
	env.HelpMicroButton:Hide()
	local bags = env.CreateFrame("Frame", "BagsBar", env.UIParent)
	local cluster = env.CreateFrame("Frame", "BagSlotCluster", bags)
	for _, def in ipairs(D.BAGS) do
		local name, bag = def[1], def[2]
		local button = env._G[name] or env.CreateFrame("Button", name, bags)
		button:SetParent(name:match("^Character") and cluster or bags)
		button:SetID(bag == D.KEYRING and D.KEYRING or 30 + bag)
		button.icon = button:CreateTexture(nil, "BORDER")
		if name == "KeyRingButton" then
			if opts.keyring then
				button.icon:SetTexture(opts.keyring)
			else
				button.icon:SetAtlas("UI-HUD-ActionBar-Keyring-Small")
			end
		elseif name == "MainMenuBarBackpackButton" then
			button.icon:SetTexture(opts.backpack or "Interface\\Icons\\ui-hud-actionbar-bag")
		else
			button.icon:SetTexture(game.textures[30 + bag] and 9000 + bag or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
		end
	end
	env.CharacterReagentBag0Slot:Hide()

	env.KEYRING_CONTAINER = D.KEYRING
	env.C_Container = {
		ContainerIDToInventoryID = function(bag)
			return 30 + bag
		end,
		GetContainerNumFreeSlots = function(bag)
			return game.free[bag] or 0
		end,
		GetContainerNumSlots = function()
			return game.slots
		end,
		CalculateTotalNumberOfFreeBagSlots = function()
			local total = 0
			for bag = 0, 5 do
				total = total + (game.free[bag] or 0)
			end
			return total
		end,
	}
	function env.GetInventoryItemTexture(_, slot)
		return game.textures[slot]
	end
	function env.GetInventoryItemLink(_, slot)
		if slot > 30 and slot <= 35 then
			return "[Bag " .. slot .. "]"
		end
	end
	function env.CursorHasItem()
		return game.cursor
	end
	function env.PutItemInBag(slot)
		game.calls[#game.calls + 1] = "PutItemInBag(" .. slot .. ")"
	end
	function env.PutItemInBackpack()
		game.calls[#game.calls + 1] = "PutItemInBackpack()"
	end
	function env.PutKeyInKeyRing()
		game.calls[#game.calls + 1] = "PutKeyInKeyRing()"
	end
	function env.PickupBagFromSlot(slot)
		game.calls[#game.calls + 1] = "PickupBagFromSlot(" .. slot .. ")"
	end
	if type(opts.portrait) == "function" then
		env.SetPortraitTexture = opts.portrait
	else
		function env.SetPortraitTexture(texture, unit)
			game.portraits = (game.portraits or 0) + 1
			texture._portrait = unit
		end
	end
	function env.UpdateMicroButtons() end
	function env.MicroButtonPulse() end
	function env.MicroButtonPulseStop() end
	function env.LoadMicroButtonTextures(button, name)
		button:GetNormalTexture():SetAtlas("UI-HUD-MicroMenu-" .. name .. "-Up")
	end
	function env.PaperDollItemSlotButton_Update() end
	function env.MainActionBar_InitializeGamepad()
		env.MicroMenu:Hide()
		env.BagsBar:Hide()
	end
	function env.MainActionBar_InitializeMKB()
		env.MicroMenu:Show()
		env.BagsBar:Show()
	end
	return game
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
			env._textWidth = D.TextWidth
			game = D.Game(env, opts.game)
			if opts.blizzard ~= false then
				D.Blizzard(env)
				D.Targets(env)
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

-- Metrics ---------------------------------------------------------------------------------------

-- The stub font strings have no glyph metrics of their own. New installs D.TextWidth as the environment's
-- env._textWidth, so GetUnboundedStringWidth answers each string's width from the kit fonts' real advances
-- (Tools/render/glyphs.lua, the table the renderer draws with) and IsTruncated fires for a string drawn
-- narrower than its text, as they do in the game.
local GLYPHS
local GLYPH_EM = { upper = 0.60, lower = 0.48, digit = 0.52, space = 0.22, other = 0.30 }

local function glyphTable(fontPath)
	if GLYPHS == nil then
		local ok, table_ = pcall(dofile, "Tools/render/glyphs.lua")
		GLYPHS = ok and type(table_) == "table" and table_ or {}
	end
	if type(fontPath) ~= "string" then
		return nil
	end
	local name = fontPath:gsub("\\", "/"):match("([^/]+)$") or fontPath
	return GLYPHS[(name:gsub("%.[^.]+$", ""))]
end

-- TextWidth(text, fontPath, size) -> the text's width in units, from the font's glyph advances.
function D.TextWidth(text, fontPath, size)
	local glyphs, em = glyphTable(fontPath), 0
	for i = 1, #text do
		local c = text:byte(i)
		local ch = text:sub(i, i)
		if glyphs and glyphs[c] then
			em = em + glyphs[c]
		elseif ch == " " then
			em = em + GLYPH_EM.space
		elseif ch:match("%u") then
			em = em + GLYPH_EM.upper
		elseif ch:match("%l") then
			em = em + GLYPH_EM.lower
		elseif ch:match("%d") then
			em = em + GLYPH_EM.digit
		else
			em = em + GLYPH_EM.other
		end
	end
	return em * size
end

return D
