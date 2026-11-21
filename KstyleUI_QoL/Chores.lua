-- Chores.lua: small switches: no screenshot notice, telling the group about an instance reset, the combat log inside chosen instances, skipping movies, hiding loot or achievement toasts, closing the loot rolls window after a delay, a Train all button, opening containers and unwrapping new mounts and toys; each touches the game only while its switch is on and undoes only what it did. A hook on LoggingCombat hands the log back to the player once anyone else starts or stops it; a movie skip waits only while Shift was up at its start and no skip setting changed.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER = "QoL.chores"
local SHOT = "SCREENSHOT_SUCCEEDED"

local TOASTS = { loot = { "SHOW_LOOT_TOAST", "SHOW_LOOT_TOAST_UPGRADE", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED", "LOOT_ITEM_ROLL_WON" }, achievements = { "ACHIEVEMENT_EARNED", "CRITERIA_EARNED" } }
local HOLD = { "MerchantFrame", "MailFrame", "BankFrame", "TradeFrame", "AuctionHouseFrame", "GuildBankFrame", "LootFrame" }

local muted, logging, hooked = false, false, false
local movieToken, rollsToken, logToken = 0, 0, 0
local LOG_GRACE = 30
local toasted, stuck, hooks = {}, {}, {}
local trainButton, opened

local function Screenshot()
	local frame = ActionStatus
	if type(frame) ~= "table" or type(frame.IsEventRegistered) ~= "function" then return end
	local want = ns.running and ns.Get("hideScreenshot")
	if want and not muted and ns.True(frame:IsEventRegistered(SHOT)) then
		frame:UnregisterEvent(SHOT)
		muted = true
	elseif not want and muted then
		frame:RegisterEvent(SHOT)
		muted = false
	end
end

local function Reset(_, text)
	if not ns.LootText.Matches("INSTANCE_RESET_SUCCESS", text) or ns.Ask(InCombatLockdown) ~= false then return end
	local channel = ns.Ask(IsInRaid) == true and "RAID" or ns.Ask(IsInGroup) == true and "PARTY"
	local send = C_ChatInfo and C_ChatInfo.SendChatMessage
	if channel and type(send) == "function" then send(text, channel) end
end

local function Check(now)
	if type(LoggingCombat) ~= "function" or type(IsInInstance) ~= "function" then return end
	if not hooked then
		hooked = true
		hooksecurefunc("LoggingCombat", function(on) if on ~= nil then logging = false end end)
	end
	local inside, kind = IsInInstance()
	local where = ns.Get("autoLogWhere")
	local want = ns.running and ns.Get("autoLog") and ns.True(inside) and not ns.IsSecret(kind) and (where == "all" or kind == where)
	if want then logToken = logToken + 1 end
	if want and not logging and not ns.True(LoggingCombat()) then
		LoggingCombat(true)
		logging = true
		if ns.Get("autoLogNotice") then K.Print(L["Combat log started."]) end
	elseif not want and logging then
		logToken = logToken + 1
		if not now and ns.running and ns.Get("autoLog") and ns.Get("autoLogDelay") and C_Timer and type(C_Timer.After) == "function" then
			local token = logToken
			C_Timer.After(LOG_GRACE, function() if token == logToken then Check(true) end end)
			return
		end
		LoggingCombat(false)
		logging = false
		if ns.Get("autoLogNotice") then K.Print(L["Combat log stopped."]) end
	end
end

local function Log()
	Check(false)
end

local function Toasts()
	local frame, mode = AlertFrame, ns.running and ns.Get("hideToasts") or "none"
	if type(frame) ~= "table" or type(frame.IsEventRegistered) ~= "function" then return end
	for kind, events in pairs(TOASTS) do
		local hide = mode == kind or mode == "both"
		for _, event in ipairs(events) do
			if hide and not toasted[event] and ns.True(frame:IsEventRegistered(event)) then
				frame:UnregisterEvent(event)
				toasted[event] = true
			elseif not hide and toasted[event] then
				frame:RegisterEvent(event)
				toasted[event] = nil
			end
		end
	end
end

local function Rolls(frame)
	rollsToken = rollsToken + 1
	local delay, token = ns.running and ns.Get("rollsClose") or 0, rollsToken
	if delay == 0 or not (C_Timer and type(C_Timer.After) == "function") then return end
	C_Timer.After(delay, function()
		if token == rollsToken and ns.True(frame:IsShown()) then frame:Hide() end
	end)
end

local function Hook(name, frame, fn)
	if not hooks[name] and type(frame) == "table" and type(frame.HookScript) == "function" then
		hooks[name] = true
		frame:HookScript("OnShow", fn)
	end
end

local function Confirm(movie)
	if not (ns.running and ns.Get("skipCinematics")) or ns.Get("skipAuto") or ns.Get("skipMode") == (movie and "cinematics" or "movies") then return end
	if movie and type(MovieFrame.FinishMovie) == "function" then MovieFrame:FinishMovie()
	elseif not movie and type(CinematicFrame_CancelCinematic) == "function" then CinematicFrame_CancelCinematic() end
end

local function Train()
	if ns.Ask(InCombatLockdown) ~= false or type(GetTrainerServiceInfo) ~= "function" or type(BuyTrainerService) ~= "function" then return end
	local money = ns.Number(ns.Ask(GetMoney)) or 0
	for i = ns.Number(ns.Ask(GetNumTrainerServices)) or 0, 1, -1 do
		local _, kind = GetTrainerServiceInfo(i)
		local cost = ns.Number(ns.Ask(GetTrainerServiceCost, i))
		if not ns.IsSecret(kind) and kind == "available" and cost and cost <= money then
			BuyTrainerService(i)
			money = money - cost
		end
	end
end

local function Trainer()
	local on, parent, anchor = ns.running and ns.Get("trainAll"), ClassTrainerFrame, ClassTrainerTrainButton
	if on and not trainButton and type(parent) == "table" and type(anchor) == "table" then
		trainButton = Widgets.Button(parent, { text = L["Train all"], onClick = Train })
		Widgets.Point(trainButton, "RIGHT", anchor, "LEFT", -Tokens.Size("gapSmall"), 0)
	end
	if trainButton then trainButton:SetShown(on) end
end

local function Warbound(id)
	local items = C_Item
	return ns.Get("openSkipWarbound") and type(items) == "table" and type(items.IsItemBindToAccount) == "function" and ns.True(items.IsItemBindToAccount(id))
end

local function Open()
	local bags = C_Container
	if not (ns.running and ns.Get("autoOpen")) or type(bags) ~= "table" or type(bags.GetContainerItemInfo) ~= "function" or type(bags.UseContainerItem) ~= "function"
		or type(bags.GetContainerNumSlots) ~= "function" or ns.Ask(InCombatLockdown) ~= false then return end
	for _, name in ipairs(HOLD) do
		local frame = _G[name]
		if type(frame) == "table" and ns.True(frame:IsShown()) then return end
	end
	if opened then
		local info = bags.GetContainerItemInfo(opened[1], opened[2])
		if type(info) == "table" and ns.Number(info.itemID) == opened[3] and ns.Number(info.stackCount) == opened[4] then stuck[opened[3]] = true end
		opened = nil
	end
	for bag = 0, ns.Number(NUM_BAG_SLOTS) or 4 do
		for slot = 1, ns.Number(bags.GetContainerNumSlots(bag)) or 0 do
			local info = bags.GetContainerItemInfo(bag, slot)
			local id = type(info) == "table" and ns.Number(info.itemID)
			if id and not stuck[id] and ns.True(info.hasLoot) and not ns.True(info.isLocked) and not Warbound(id) then
				opened = { bag, slot, id, ns.Number(info.stackCount) }
				bags.UseContainerItem(bag, slot)
				return
			end
		end
	end
end

local function Unwrap(event, id)
	local api = event == "NEW_MOUNT_ADDED" and C_MountJournal or C_ToyBoxInfo
	id = ns.Number(id)
	if id and type(api) == "table" and type(api.ClearFanfare) == "function" then api.ClearFanfare(id) end
end

local function Movie()
	movieToken = movieToken + 1
	local token = movieToken
	if not ns.Get("skipCinematics") or not ns.Get("skipAuto") or ns.Get("skipMode") == "cinematics" or ns.Ask(IsShiftKeyDown) ~= false or not (C_Timer and type(C_Timer.After) == "function") then return end
	C_Timer.After(ns.Get("skipDelay"), function()
		local frame = MovieFrame
		if token ~= movieToken or not ns.running or ns.Ask(IsShiftKeyDown) ~= false or ns.Ask(InCombatLockdown) ~= false then return end
		if type(frame) == "table" and type(frame.FinishMovie) == "function" and ns.True(frame:IsShown()) then frame:FinishMovie() end
	end)
end

local EVENTS = {
	{ "announceReset", { CHAT_MSG_SYSTEM = Reset } },
	{ "autoLog", { PLAYER_ENTERING_WORLD = Log, ZONE_CHANGED_NEW_AREA = Log } },
	{ "skipCinematics", { PLAY_MOVIE = Movie } },
	{ "trainAll", { TRAINER_SHOW = function() if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, Trainer) else Trainer() end end } },
	{ "autoOpen", { BAG_UPDATE_DELAYED = Open, LOOT_CLOSED = Open, MAIL_CLOSED = Open, MERCHANT_CLOSED = Open, BANKFRAME_CLOSED = Open, TRADE_CLOSED = Open,
		AUCTION_HOUSE_CLOSED = Open, PLAYER_REGEN_ENABLED = Open } },
	{ "autoUnwrap", { NEW_MOUNT_ADDED = Unwrap, NEW_TOY_ADDED = Unwrap } },
}

local function Sync()
	for _, entry in ipairs(EVENTS) do
		local on = ns.running and ns.Get(entry[1])
		for event, fn in pairs(entry[2]) do
			if on then K.Events.Register(OWNER, event, fn) else K.Events.Unregister(OWNER, event) end
		end
	end
	if muted or ns.Get("hideScreenshot") then Screenshot() end
	if logging or ns.Get("autoLog") then Log() end
	Toasts()
	if ns.running and ns.Get("rollsClose") > 0 then Hook("rolls", GroupLootHistoryFrame, Rolls) end
	if ns.running and ns.Get("skipCinematics") and not ns.Get("skipAuto") then
		Hook("cinematic", type(CinematicFrame) == "table" and CinematicFrame.closeDialog, function() Confirm(false) end)
		Hook("movie", type(MovieFrame) == "table" and MovieFrame.CloseDialog, function() Confirm(true) end)
	end
	Trainer()
	if not (ns.running and ns.Get("autoOpen")) then stuck, opened = {}, nil else Open() end
end

local KEYS = { hideScreenshot = true, announceReset = true, autoLog = true, autoLogWhere = true, skipCinematics = true, skipMode = true, skipDelay = true,
	autoLogDelay = true, skipAuto = true, hideToasts = true, rollsClose = true, trainAll = true, autoOpen = true, openSkipWarbound = true, autoUnwrap = true }

ns.AddPart({
	name = "chores",
	Start = Sync,
	Stop = function() movieToken, rollsToken = movieToken + 1, rollsToken + 1; Sync() end,
	Setting = function(key)
		if key == nil or key == "skipCinematics" or key == "skipMode" or key == "skipDelay" or key == "skipAuto" then movieToken = movieToken + 1 end
		if key == nil or key == "rollsClose" then rollsToken = rollsToken + 1 end
		if key == nil or KEYS[key] then Sync() end
	end,
})
