-- Keys.lua: dialog keys, out of combat: Space continues a quest window and picks the first gossip or greeting choice, 1 to 9 pick the matching choice or reward, and Space clicks a shown popup's first button. The catcher takes the keyboard only while one of those windows is open and never in combat, and any key it does not act on passes through to the game.
local _, ns = ...

local K = ns.K

local OWNER = "QoL.keys"
local OPEN = { GOSSIP_SHOW = "gossip", QUEST_DETAIL = "detail", QUEST_PROGRESS = "progress", QUEST_COMPLETE = "complete", QUEST_GREETING = "greeting" }
local CLOSE = { GOSSIP_CLOSED = "gossip", QUEST_FINISHED = "quest" }

local catcher, hooked, fighting
local open = {}

local function Current()
	return open.quest or open.gossip
end

local function Calm()
	return not fighting and ns.Ask(InCombatLockdown) == false
end

local function Call(fn, ...)
	if type(fn) == "function" then
		fn(...)
		return true
	end
	return false
end

local function List(fn)
	local list = type(fn) == "function" and fn()
	return not ns.IsSecret(list) and type(list) == "table" and list or {}
end

local function Popup()
	for i = 1, 4 do
		local dialog = _G["StaticPopup" .. i]
		local button = type(dialog) == "table" and ns.True(dialog:IsShown()) and type(dialog.GetButton1) == "function" and dialog:GetButton1()
		if button and ns.True(button:IsShown()) and ns.True(button:IsEnabled()) then return button end
	end
end

local function Gossip(n)
	local gossip = C_GossipInfo
	if type(gossip) ~= "table" then return false end
	for _, pair in ipairs({ { "GetAvailableQuests", "SelectAvailableQuest" }, { "GetActiveQuests", "SelectActiveQuest" } }) do
		local list = List(gossip[pair[1]])
		if n <= #list then
			local id = type(list[n]) == "table" and ns.Number(list[n].questID)
			return id ~= nil and Call(gossip[pair[2]], id)
		end
		n = n - #list
	end
	local frame = GossipFrame
	local options = type(frame) == "table" and type(frame.gossipOptions) == "table" and frame.gossipOptions
	return options and options[n] ~= nil and type(frame.SelectGossipOption) == "function" and (frame:SelectGossipOption(n) or true) or false
end

local function Greeting(n)
	local active = ns.Number(ns.Ask(GetNumActiveQuests)) or 0
	if n <= active then return Call(SelectActiveQuest, n) end
	return n - active <= (ns.Number(ns.Ask(GetNumAvailableQuests)) or 0) and Call(SelectAvailableQuest, n - active)
end

local function Quest(window, n, space)
	if window == "detail" and n == 1 then
		return ns.True(ns.Ask(QuestGetAutoAccept)) and Call(AcknowledgeAutoAcceptQuest) or Call(AcceptQuest)
	elseif window == "progress" and n == 1 then
		return ns.True(ns.Ask(IsQuestCompletable)) and Call(CompleteQuest)
	elseif window == "complete" then
		local choices = ns.Number(ns.Ask(GetNumQuestChoices))
		if not choices then return false end
		if choices <= 1 then return n == 1 and Call(GetQuestReward, choices) end
		return not space and n <= choices and Call(GetQuestReward, n)
	end
	return false
end

local function Act(key)
	local space, n = key == "SPACE", tonumber(key)
	if space and ns.Get("confirmPopups") then
		local button = Popup()
		if button then button:Click(); return true end
	end
	local window = Current()
	if not window or not (space and ns.Get("dialogKeys") or n and n >= 1 and n <= 9 and ns.Get("numberKeys")) then return false end
	n = n or 1
	if window == "gossip" then return Gossip(n) elseif window == "greeting" then return Greeting(n) end
	return Quest(window, n, space)
end

local function Wanted()
	return ns.running and Calm() and (Current() ~= nil and (ns.Get("dialogKeys") or ns.Get("numberKeys")) or ns.Get("confirmPopups") and Popup() ~= nil)
end

local function Refresh()
	if not catcher then return end
	local want = Wanted() == true
	if want ~= catcher.taking then
		catcher.taking = want
		if Calm() then catcher:SetPropagateKeyboardInput(true) end
		catcher:EnableKeyboard(want)
	end
end

local function Key(self, key)
	if not Calm() then return end
	self:SetPropagateKeyboardInput(not (ns.running and Act(key)))
	Refresh()
end

local function Window(event)
	local kind = OPEN[event]
	if kind then open[kind == "gossip" and "gossip" or "quest"] = kind else open[CLOSE[event]] = nil end
	Refresh()
end

local function Fight(event)
	if event == "PLAYER_REGEN_DISABLED" and catcher and catcher.taking then
		catcher.taking = false
		catcher:SetPropagateKeyboardInput(true)
		catcher:EnableKeyboard(false)
	end
	fighting = event == "PLAYER_REGEN_DISABLED"
	Refresh()
end

function ns.KeyCatcher()
	return catcher
end

local function Sync()
	local on = ns.running and (ns.Get("dialogKeys") or ns.Get("numberKeys") or ns.Get("confirmPopups"))
	for event in pairs(OPEN) do
		if on then K.Events.Register(OWNER, event, Window) else K.Events.Unregister(OWNER, event) end
	end
	for event in pairs(CLOSE) do
		if on then K.Events.Register(OWNER, event, Window) else K.Events.Unregister(OWNER, event) end
	end
	for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
		if on then K.Events.Register(OWNER, event, Fight) else K.Events.Unregister(OWNER, event) end
	end
	if on and not catcher then
		catcher = CreateFrame("Frame", nil, UIParent)
		catcher.taking = false
		catcher:EnableKeyboard(false)
		catcher:SetScript("OnKeyDown", Key)
	end
	if on and ns.Get("confirmPopups") and not hooked and type(StaticPopup_Show) == "function" then
		hooked = true
		hooksecurefunc("StaticPopup_Show", Refresh)
	end
	if not on then open = {} end
	fighting = false
	Refresh()
end

ns.AddPart({
	name = "keys",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or key == "dialogKeys" or key == "numberKeys" or key == "confirmPopups" then Sync() end
	end,
})
