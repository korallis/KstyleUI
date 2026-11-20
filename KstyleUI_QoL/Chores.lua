-- Chores.lua: small switches: no screenshot notice, telling the group about an instance reset, the combat log inside chosen instances, and skipping movies; each touches the game only while its switch is on and undoes only what it did.
local _, ns = ...

local K, L = ns.K, ns.L

local OWNER = "QoL.chores"
local SHOT = "SCREENSHOT_SUCCEEDED"

local muted, logging = false, false
local movieToken = 0

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
	if not ns.LootText.Matches("INSTANCE_RESET_SUCCESS", text) or ns.True(InCombatLockdown()) then return end
	local channel = ns.True(IsInRaid()) and "RAID" or ns.True(IsInGroup()) and "PARTY"
	local send = C_ChatInfo and C_ChatInfo.SendChatMessage
	if channel and type(send) == "function" then send(text, channel) end
end

local function Log()
	if type(LoggingCombat) ~= "function" then return end
	local inside, kind = IsInInstance()
	local where = ns.Get("autoLogWhere")
	local want = ns.running and ns.Get("autoLog") and ns.True(inside) and not ns.IsSecret(kind) and (where == "all" or kind == where)
	if want and not logging and not ns.True(LoggingCombat()) then
		LoggingCombat(true)
		logging = true
		if ns.Get("autoLogNotice") then K.Print(L["Combat log started."]) end
	elseif not want and logging then
		LoggingCombat(false)
		logging = false
		if ns.Get("autoLogNotice") then K.Print(L["Combat log stopped."]) end
	end
end

local function Movie()
	movieToken = movieToken + 1
	local token = movieToken
	if not ns.Get("skipCinematics") or ns.Get("skipMode") == "cinematics" then return end
	C_Timer.After(ns.Get("skipDelay"), function()
		local frame, shift, fight = MovieFrame, IsShiftKeyDown(), InCombatLockdown()
		if token ~= movieToken or not ns.running or ns.IsSecret(shift) or shift ~= false or ns.IsSecret(fight) or fight ~= false then return end
		if type(frame) == "table" and type(frame.FinishMovie) == "function" and ns.True(frame:IsShown()) then frame:FinishMovie() end
	end)
end

local EVENTS = {
	{ "announceReset", { CHAT_MSG_SYSTEM = Reset } },
	{ "autoLog", { PLAYER_ENTERING_WORLD = Log, ZONE_CHANGED_NEW_AREA = Log } },
	{ "skipCinematics", { PLAY_MOVIE = Movie } },
}

local function Sync()
	for _, entry in ipairs(EVENTS) do
		local on = ns.running and ns.Get(entry[1])
		for event, fn in pairs(entry[2]) do
			if on then K.Events.Register(OWNER, event, fn) else K.Events.Unregister(OWNER, event) end
		end
	end
	movieToken = movieToken + 1
	if muted or ns.Get("hideScreenshot") then Screenshot() end
	if logging or ns.Get("autoLog") then Log() end
end

local KEYS = { hideScreenshot = true, announceReset = true, autoLog = true, autoLogWhere = true, skipCinematics = true, skipMode = true, skipDelay = true }

ns.AddPart({
	name = "chores",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or KEYS[key] then Sync() end
	end,
})
