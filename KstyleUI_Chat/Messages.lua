-- Messages.lua: the chat's message pipeline: links and class-coloured names through Blizzard's chat filters, timestamps and short channel names on each new line, and the dialog that copies a clicked link.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Format, Windows = ns.Format, ns.Windows

local Messages = {}
ns.Messages = Messages

local URL_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
}
local LINK_EVENT = "SetItemRef"

local IsSecret = Format.IsSecret

local state = {
	active = false,
	settings = nil,
	opts = {},
	linkable = false,
	urls = false,
	names = false,
	urlsRegistered = false,
	namesRegistered = false,
	watching = false,
	pending = nil,
	out = nil,
	done = false,
	seen = 0,
	slot = nil,
	popup = nil,
}
local hooked = setmetatable({}, { __mode = "k" })
local logged = {}

local function Log(message)
	K.DevTest.Log(ns.NAME, message)
end

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function IsText(v)
	return not IsSecret(v) and type(v) == "string"
end

local function Match(message)
	local seen = state.seen + 1
	state.seen = seen
	if state.done or (state.slot and seen ~= state.slot) or not IsText(message) then
		return false
	end
	return message == state.pending
end

local function Replace(_, r, g, b, ...)
	state.done = true
	return state.out, r, g, b, ...
end

local function ReadGameTimestamps()
	local get = C_CVar and C_CVar.GetCVar
	if type(get) ~= "function" then
		return false
	end
	local ok, value = pcall(get, "showTimestamps")
	return ok and IsText(value) and value ~= "" and value ~= "none"
end

local function GameTimestamps()
	local cached = state.gameStamps
	if cached == nil then
		cached = ReadGameTimestamps() and true or false
		state.gameStamps = cached
	end
	return cached
end

local function OnCVar(_, name)
	if not IsText(name) or name:lower() == "showtimestamps" then
		state.gameStamps = nil
	end
end

local function NewestSlot(frame)
	local buffer = frame.historyBuffer
	if type(buffer) ~= "table" or type(buffer.CalculateElementIndex) ~= "function" then
		LogOnce("slot", "the chat history's layout is unknown; a line is matched by its text alone")
		return nil
	end
	local ok, slot = pcall(buffer.CalculateElementIndex, buffer, 1)
	if ok and not IsSecret(slot) and type(slot) == "number" then
		return slot
	end
	return nil
end

local function OnAddMessage(frame, message, _, _, _, _, _, _, event)
	if not state.active or not IsText(message) or Windows.IsCombatLog(frame) then
		return
	end
	local opts = state.opts
	opts.timestamp = opts.stamp
	if opts.stamp ~= "none" and GameTimestamps() then
		opts.timestamp = "none"
	end
	local out = Format.Decorate(message, IsText(event) and event or nil, opts)
	if out == message then
		return
	end
	if type(frame.TransformMessages) ~= "function" then
		LogOnce("transform", "TransformMessages is missing; lines keep the game's own timestamps and channel names")
		return
	end
	state.pending, state.out, state.done = message, out, false
	state.seen, state.slot = 0, NewestSlot(frame)
	frame:TransformMessages(Match, Replace)
	state.pending, state.out, state.slot = nil, nil, nil
end

local function HookFrame(frame)
	if hooked[frame] then
		return
	end
	if type(frame.AddMessage) ~= "function" then
		LogOnce("addmessage", "a chat window has no AddMessage; its lines are left alone")
		return
	end
	hooked[frame] = true
	hooksecurefunc(frame, "AddMessage", OnAddMessage)
end

local function URLFilter(_, _, message, ...)
	if not state.active or not state.urls or not IsText(message) then
		return false
	end
	local out = Format.Linkify(message, state.linkR, state.linkG, state.linkB)
	if out == message then
		return false
	end
	return false, out, ...
end

local function NameFilter(_, name, _, _, _, _, _, _, _, _, _, _, _, guid)
	if not state.active or not state.names or not IsText(name) or not IsText(guid) then
		return nil
	end
	if type(GetPlayerInfoByGUID) ~= "function" then
		return nil
	end
	local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
	if not ok or not IsText(class) then
		return nil
	end
	local r, g, b = K.Theme.Brighten(K.Theme.ClassColor(class))
	return Format.ColorName(name, r, g, b)
end

local function Util(add, remove)
	local util = ChatFrameUtil
	if type(util) ~= "table" or type(util[add]) ~= "function" or type(util[remove]) ~= "function" then
		return nil
	end
	return util
end

local function SetURLs(on)
	if on == state.urlsRegistered then
		return
	end
	local util = Util("AddMessageEventFilter", "RemoveMessageEventFilter")
	if not util then
		return
	end
	for _, event in ipairs(URL_EVENTS) do
		if on then
			util.AddMessageEventFilter(event, URLFilter)
		else
			util.RemoveMessageEventFilter(event, URLFilter)
		end
	end
	state.urlsRegistered = on
	LogOnce("urls", "links: Blizzard's message event filters")
end

local function SetNames(on)
	if on == state.namesRegistered then
		return
	end
	local util = Util("AddSenderNameFilter", "RemoveSenderNameFilter")
	if not util then
		return
	end
	if on then
		util.AddSenderNameFilter(NameFilter)
	else
		util.RemoveSenderNameFilter(NameFilter)
	end
	state.namesRegistered = on
end

local function OnLink(_, link)
	local url = Format.URL(link)
	if url then
		Messages.ShowURL(url)
	end
end

local function Select(box)
	local popup = state.popup
	if popup and popup:IsShown() and popup.editBox == box then
		box:HighlightText()
	end
end

function Messages.ShowURL(url)
	if state.popup then
		state.popup:Close()
	end
	local popup = K.Widgets.Popup({
		title = L["Copy link"],
		text = L["Press Ctrl+C to copy the link."],
		editBox = { text = url },
		buttons = { { label = L["Close"], primary = true } },
	})
	state.popup = popup
	local host = K.Widgets.DialogHost()
	if not state.selecting and host.editBox then
		state.selecting = true
		host.editBox:HookScript("OnEditFocusGained", Select)
	end
	C_Timer.After(0, function()
		local box = popup.editBox
		if box and popup:IsShown() then
			box:SetFocus()
			Select(box)
		end
	end)
	return popup
end

function Messages.Refresh(settings)
	state.settings = settings
	local opts = state.opts
	opts.channels, opts.numbers, opts.abbr = settings.channels, settings.numbers, settings.abbr
	opts.stamp, opts.timestampColor = settings.timestamp, settings.timestampColor
	state.linkR, state.linkG, state.linkB = ns.Accent(settings)
	state.urls = settings.urls == true and state.linkable
	state.names = settings.classNames == true
	if state.active then
		SetURLs(state.urls)
		SetNames(state.names)
	end
end

local function Probe()
	if not Util("AddMessageEventFilter", "RemoveMessageEventFilter") then
		LogOnce("filters", "ChatFrameUtil.AddMessageEventFilter is missing; web addresses stay plain text")
	end
	if not Util("AddSenderNameFilter", "RemoveSenderNameFilter") then
		LogOnce("names", "ChatFrameUtil.AddSenderNameFilter is missing; names keep the game's colours")
	end
end

function Messages.Start(settings)
	state.active = true
	state.gameStamps = nil
	K.Events.Register(ns.NAME, "CVAR_UPDATE", OnCVar)
	Probe()
	local registry = EventRegistry
	if type(registry) == "table" and type(registry.RegisterCallback) == "function" then
		registry:RegisterCallback(LINK_EVENT, OnLink, Messages)
		state.linkable = true
	else
		state.linkable = false
		LogOnce("registry", "EventRegistry is missing; links cannot be clicked, so web addresses stay plain text")
	end
	Messages.Refresh(settings)
	if not state.watching then
		state.watching = true
		Windows.Watch(HookFrame)
	end
end

function Messages.Stop()
	state.active = false
	SetURLs(false)
	SetNames(false)
	local registry = EventRegistry
	if state.linkable and type(registry) == "table" and type(registry.UnregisterCallback) == "function" then
		registry:UnregisterCallback(LINK_EVENT, Messages)
	end
	if state.popup then
		state.popup:Close()
	end
	state.popup = nil
end
