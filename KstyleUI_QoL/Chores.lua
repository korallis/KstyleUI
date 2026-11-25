-- Chores.lua: small switches: no screenshot notice, telling the group about an instance reset, the combat log inside chosen instances, skipping movies, hiding loot or achievement toasts, closing the loot rolls window after a delay, opening containers, unwrapping new mounts and toys, and taking off the costume, food and toy transforms in TRANSFORMS; each touches the game only while its switch is on and undoes only what it did. A hook on LoggingCombat hands the log back to the player once anyone else starts or stops it, and the log's grace keeps its first deadline; a movie skip waits only while Shift was up at its start and no skip setting changed, and without Skip at once only Escape answers the movie's prompt. Containers open only when the game says they are unlocked and, while warbound ones are left, not warbound. A transform comes off only out of combat while the game shows auras, so one that lands in combat or while auras are secret comes off when combat ends or the restriction lifts.
local _, ns = ...

local K, L = ns.K, ns.L

local OWNER = "QoL.chores"
local SHOT = "SCREENSHOT_SUCCEEDED"
local UNDRESS = "QoL.transforms"
local GATES = { "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_ENTERING_WORLD" }
local TRANSFORMS = { [24708] = true, [24709] = true, [24710] = true, [24711] = true, [24712] = true, [24713] = true, [24723] = true, [24735] = true, [24736] = true,
	[8213] = true, [8219] = true, [8220] = true, [8221] = true, [8222] = true, [1252576] = true, [30167] = true, [435986] = true, [446098] = true, [446104] = true,
	[1213145] = true, [1214179] = true, [1214281] = true, [1214284] = true, [1220560] = true, [1220561] = true, [1220562] = true, [1220563] = true, [1220564] = true }

local TOASTS = { loot = { "SHOW_LOOT_TOAST", "SHOW_LOOT_TOAST_UPGRADE", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED", "LOOT_ITEM_ROLL_WON" }, achievements = { "ACHIEVEMENT_EARNED", "CRITERIA_EARNED" } }
local HOLD = { "MerchantFrame", "MailFrame", "BankFrame", "TradeFrame", "AuctionHouseFrame", "GuildBankFrame", "LootFrame" }

local muted, logging, hooked = false, false, false
local movieToken, rollsToken, logToken, waiting = 0, 0, 0
local LOG_GRACE = 30
local toasted, stuck, hooks = {}, {}, {}
local opened, pending
local listening = false

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
	local want = ns.running and ns.Get("autoLog") and ns.True(inside) and not ns.IsSecret(kind) and (where == "all" or kind == where or where == "both" and (kind == "raid" or kind == "party"))
	if want then logToken = logToken + 1 end
	if want and not logging and not ns.True(LoggingCombat()) then
		LoggingCombat(true)
		logging = true
		if ns.Get("autoLogNotice") then K.Print(L["Combat log started."]) end
	elseif not want and logging then
		if now ~= true and ns.running and ns.Get("autoLog") and ns.Get("autoLogDelay") and C_Timer and type(C_Timer.After) == "function" then
			if waiting ~= logToken then
				waiting = logToken
				local token = logToken
				C_Timer.After(LOG_GRACE, function() if token == logToken then Check(true) end end)
			end
			return
		end
		logToken = logToken + 1
		LoggingCombat(false)
		logging = false
		if ns.Get("autoLogNotice") then K.Print(L["Combat log stopped."]) end
	end
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

local function Hook(name, frame, fn, script)
	if not hooks[name] and type(frame) == "table" and type(frame.HookScript) == "function" then
		hooks[name] = true
		frame:HookScript(script or "OnShow", fn)
	end
end

local function Confirm(movie)
	if not (ns.running and ns.Get("skipCinematics")) or ns.Get("skipAuto") or ns.Get("skipMode") == (movie and "cinematics" or "movies") then return end
	if movie and type(MovieFrame.FinishMovie) == "function" then MovieFrame:FinishMovie()
	elseif not movie and type(CinematicFrame_CancelCinematic) == "function" then CinematicFrame_CancelCinematic() end
end

local function Warbound(id)
	return ns.Get("openSkipWarbound") and (type(C_Item) ~= "table" or ns.Ask(C_Item.IsItemBindToAccount, id) ~= false)
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
			if id and not stuck[id] and ns.True(info.hasLoot) and not ns.IsSecret(info.isLocked) and info.isLocked == false and not Warbound(id) then
				opened = { bag, slot, id, ns.Number(info.stackCount) }
				bags.UseContainerItem(bag, slot)
				return
			end
		end
	end
end

local function Unwrap(event, id)
	local api = _G[event == "NEW_MOUNT_ADDED" and "C_MountJournal" or "C_ToyBoxInfo"]
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

local function Landed(info)
	if ns.IsSecret(info) or type(info) ~= "table" or ns.IsSecret(info.isFullUpdate) or info.isFullUpdate then return true end
	local added = info.addedAuras
	if ns.IsSecret(added) then return true elseif type(added) ~= "table" then return false end
	for i = 1, #added do
		local aura = added[i]
		if ns.IsSecret(aura) or type(aura) == "table" and (ns.IsSecret(aura.spellId) or TRANSFORMS[aura.spellId]) then return true end
	end
	return false
end

local function Untransform(event, _, info)
	if event == "UNIT_AURA" and not Landed(info) or event ~= nil and event ~= "UNIT_AURA" and not pending then return end
	pending = true
	local auras, secrets = C_UnitAuras, C_Secrets
	if ns.Ask(InCombatLockdown) ~= false or type(CancelUnitBuff) ~= "function" or type(auras) ~= "table" or type(auras.GetBuffDataByIndex) ~= "function"
		or type(secrets) ~= "table" or select(2, pcall(ns.Ask, secrets.ShouldAurasBeSecret)) ~= false then return end
	pending = false
	local found, i = {}, 0
	repeat
		i = i + 1
		local aura = auras.GetBuffDataByIndex("player", i)
		if ns.IsSecret(aura) or type(aura) == "table" and ns.IsSecret(aura.spellId) then pending = true
		elseif type(aura) == "table" and TRANSFORMS[ns.Number(aura.spellId)] then found[#found + 1] = i end
	until type(aura) == "nil"
	for n = #found, 1, -1 do CancelUnitBuff("player", found[n], "HELPFUL") end
end

local function Transforms()
	local on = ns.running and ns.Get("hideTransforms") or false
	if on ~= listening then
		listening = on
		if on then
			for _, event in ipairs(GATES) do K.Events.Register(UNDRESS, event, Untransform) end
			K.Events.RegisterUnit(UNDRESS, "UNIT_AURA", Untransform, "player")
		else
			K.Events.UnregisterAll(UNDRESS)
		end
	end
	if on then Untransform() end
end

local EVENTS = {
	{ "announceReset", { CHAT_MSG_SYSTEM = Reset } },
	{ "autoLog", { PLAYER_ENTERING_WORLD = Check, ZONE_CHANGED_NEW_AREA = Check } },
	{ "skipCinematics", { PLAY_MOVIE = Movie } },
	{ "autoOpen", { BAG_UPDATE_DELAYED = Open, LOOT_CLOSED = Open, MAIL_CLOSED = Open, MERCHANT_CLOSED = Open, BANKFRAME_CLOSED = Open, TRADE_CLOSED = Open,
		AUCTION_HOUSE_CLOSED = Open, GUILDBANKFRAME_CLOSED = Open, PLAYER_REGEN_ENABLED = Open } },
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
	if logging or ns.Get("autoLog") then Check() end
	Toasts()
	if ns.running and ns.Get("rollsClose") > 0 then Hook("rolls", GroupLootHistoryFrame, Rolls) end
	if ns.running and ns.Get("skipCinematics") and not ns.Get("skipAuto") then
		Hook("cinematic", type(CinematicFrame) == "table" and CinematicFrame.closeDialog, function() Confirm(false) end)
		Hook("movie", MovieFrame, function(_, key) if ns.Ask(GetBindingFromClick, key) == "TOGGLEGAMEMENU" then Confirm(true) end end, "OnKeyUp")
	end
	if not (ns.running and ns.Get("autoOpen")) then stuck, opened = {}, nil else Open() end
end

local KEYS = { hideScreenshot = true, announceReset = true, autoLog = true, autoLogWhere = true, skipCinematics = true, skipMode = true, skipDelay = true,
	autoLogDelay = true, skipAuto = true, hideToasts = true, rollsClose = true, autoOpen = true, openSkipWarbound = true, autoUnwrap = true }

ns.AddPart({
	name = "chores",
	Start = function() Sync(); Transforms() end,
	Stop = function() movieToken, rollsToken = movieToken + 1, rollsToken + 1; Sync(); Transforms() end,
	Setting = function(key)
		if key == nil or key == "hideTransforms" then Transforms() end
		if key == nil or key == "skipCinematics" or key == "skipMode" or key == "skipDelay" or key == "skipAuto" then movieToken = movieToken + 1 end
		if key == nil or KEYS[key] then Sync() end
		if key == nil or key == "rollsClose" then
			local frame = GroupLootHistoryFrame
			if hooks.rolls and ns.True(frame:IsShown()) then Rolls(frame) else rollsToken = rollsToken + 1 end
		end
	end,
})
