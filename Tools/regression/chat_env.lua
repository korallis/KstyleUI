-- chat_env.lua: load the core and KstyleUI_Chat into a stub environment with stand-ins for Blizzard's chat frames.
--
--   local C = dofile("Tools/regression/chat_env.lua")
--   local env, K, ns = C.New()            -- core booted, KstyleUI_Chat loaded, module still off
--   K.Modules.Enable("Chat")
--   C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "hi", { sender = "Thargor", guid = "Player-1" })
--   C.Lines(env.ChatFrame1)              -- the chat frame's history, newest last
--
-- The stand-ins follow Blizzard_ChatFrameBase on the forever branch: ChatFrameUtil's message and
-- sender-name filter registries (a filter is skipped when an argument is secret, as canaccessvalue
-- does), ChatFrameMixin:AddMessage and ScrollingMessageFrame:TransformMessages, the chat tabs and
-- edit boxes, CHAT_FRAMES, the dock, EventRegistry and Menu.ModifyMenu. Every Blizzard object the
-- environment makes is listed in env._blizzard, so a test can check that no field was written.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local C = { W = W }

local chatFiles
function C.Files()
	if not chatFiles then
		chatFiles = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_Chat/") then
				chatFiles[#chatFiles + 1] = path
			end
		end
		assert(#chatFiles > 0, "no KstyleUI_Chat files found")
	end
	return chatFiles
end

local function pack(...)
	return { n = select("#", ...), ... }
end

local function anySecret(env, ...)
	for i = 1, select("#", ...) do
		if env.issecretvalue((select(i, ...))) then
			return true
		end
	end
	return false
end

-- Fields Blizzard code gives a chat frame, a tab or an edit box. A test compares against these.
local function blizzard(env, object)
	env._blizzard[#env._blizzard + 1] = object
	return object
end

local function newChatFrame(env, id, parent)
	local name = "ChatFrame" .. id
	local frame = blizzard(env, env.CreateFrame("ScrollingMessageFrame", name, parent or env.UIParent))
	frame:SetID(id)
	frame:SetSize(430, 120)
	frame.Background = blizzard(env, frame:CreateTexture(name .. "Background", "BACKGROUND"))
	env[name .. "Background"] = frame.Background
	-- FloatingChatFrame.xml: the background reaches 2 units past the sides, 3 above and 6 below the window.
	frame.Background:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 3)
	frame.Background:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 3)
	frame.Background:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -2, -6)
	frame.Background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -6)
	for _, piece in ipairs({ "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }) do
		env[name .. piece] = blizzard(env, frame:CreateTexture(name .. piece, "BORDER"))
	end
	frame._max = env._maxLines or 8
	frame._elements = {}
	frame._head = 0
	-- ScrollingMessageFrame keeps lines in a CircularBuffer: PushFront writes the slot after the head
	-- and wraps at the maximum, and TransformMessages walks the slots in array order, not by age.
	local function slot(self, index)
		local global = self._head - index + 1
		if global == 0 then
			return self._max
		end
		return (global - 1) % self._max + 1
	end
	function frame:AddMessage(message, r, g, b, ...)
		local insert = self._head + 1
		self._elements[insert] = pack(message, r, g, b, ...)
		self._head = insert % self._max
	end
	function frame:TransformMessages(predicate, transform)
		for i, entry in ipairs(self._elements) do
			if predicate(unpack(entry, 1, entry.n)) then
				self._elements[i] = pack(transform(unpack(entry, 1, entry.n)))
			end
		end
	end
	function frame:GetNumMessages()
		return #self._elements
	end
	function frame:GetMessageInfo(index)
		local entry = self._elements[slot(self, #self._elements - index + 1)]
		if entry then
			return unpack(entry, 1, entry.n)
		end
	end
	frame.historyBuffer = {
		CalculateElementIndex = function(_, index)
			return slot(frame, index)
		end,
	}
	local edit = blizzard(env, env.CreateFrame("EditBox", name .. "EditBox", frame))
	edit:SetSize(5, 32)
	edit.header = blizzard(env, edit:CreateFontString(name .. "EditBoxHeader", "ARTWORK", "ChatFontNormal"))
	for _, piece in ipairs({ "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }) do
		env[name .. "EditBox" .. piece] = blizzard(env, edit:CreateTexture(name .. "EditBox" .. piece, "BACKGROUND"))
	end
	frame.editBox = edit
	frame.ScrollBar = blizzard(env, env.CreateFrame("Frame", nil, frame))
	frame.ScrollBar:SetSize(8, 100)
	frame.ScrollToBottomButton = blizzard(env, env.CreateFrame("Button", nil, frame))
	frame.ScrollToBottomButton.Flash = blizzard(env, frame.ScrollToBottomButton:CreateTexture(nil, "OVERLAY"))
	frame.buttonFrame = blizzard(env, env.CreateFrame("Frame", name .. "ButtonFrame", frame))
	local tab = blizzard(env, env.CreateFrame("Button", name .. "Tab", env.UIParent))
	tab:SetID(id)
	-- ChatTabArtTemplate: a 64 by 32 button, 16-unit side pieces, the text centred 5 units below the middle.
	tab:SetSize(64, 32)
	tab.Text = blizzard(env, tab:CreateFontString(name .. "TabText", "OVERLAY", "GameFontNormalSmall"))
	tab.Text:SetPoint("CENTER", tab, "CENTER", 0, -5)
	for _, piece in ipairs({ "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft", "HighlightMiddle", "HighlightRight" }) do
		tab[piece] = blizzard(env, tab:CreateTexture(nil, "BACKGROUND"))
	end
	tab.Left:SetSize(16, 32)
	tab.Right:SetSize(16, 32)
	tab.glow = blizzard(env, tab:CreateTexture(name .. "TabGlow", "BORDER"))
	function tab:GetFontString()
		return self.Text
	end
	function tab:SetText(text)
		self.Text:SetText(text)
	end
	function tab:GetText()
		return self.Text:GetText()
	end
	tab:SetText(id == 1 and "General" or id == 2 and "Combat Log" or ("Chat " .. id))
	env.CHAT_FRAMES[#env.CHAT_FRAMES + 1] = name
	return frame
end

-- The format a CHAT_MSG event's line takes in the chat frame, close enough for the tests: the channel
-- link, the sender's player link around the decorated name, then the text.
local CHANNELS = {
	CHAT_MSG_GUILD = "|Hchannel:GUILD|h[Guild]|h ",
	CHAT_MSG_PARTY = "|Hchannel:PARTY|h[Party]|h ",
	CHAT_MSG_PARTY_LEADER = "|Hchannel:PARTY|h[Party Leader]|h ",
	CHAT_MSG_RAID_WARNING = "[Raid Warning] ",
}

-- Say(env, frame, event, text, opts) runs one chat event through the filters into the frame, as
-- ChatFrameMixin:MessageEventHandler does. opts: sender, guid, channel ("1. General - Zone").
-- Returns false when a filter discarded the line.
function C.Say(env, frame, event, text, opts)
	opts = opts or {}
	local sender, guid, channel = opts.sender or "Thargor", opts.guid or "Player-1-0001", opts.channel or ""
	local args = pack(text, sender, "", channel, sender, "", 0, 1, "General", 0, 42, guid)
	for _, filter in ipairs(env._messageFilters[event] or {}) do
		if not anySecret(env, unpack(args, 1, args.n)) then
			local results = pack(filter(frame, event, unpack(args, 1, args.n)))
			if results[1] then
				return false
			end
			if results[2] then
				args = pack(unpack(results, 2, results.n))
			end
		end
	end
	local name = args[2]
	for _, filter in ipairs(env._nameFilters) do
		if not env.issecretvalue(name) then
			local renamed = filter(event, name, unpack(args, 1, args.n))
			if renamed ~= nil then
				name = renamed
			end
		end
	end
	local prefix = CHANNELS[event] or ""
	if event == "CHAT_MSG_CHANNEL" then
		prefix = "|Hchannel:channel:1|h[" .. channel .. "]|h "
	end
	local line = prefix .. "|Hplayer:" .. sender .. ":42|h[" .. name .. "]|h: " .. args[1]
	-- MessageFormatter puts the game's timestamp in front: TimeUtil.BetterDate(showTimestamps, time()).
	local stamp = env._cvars.showTimestamps
	if type(stamp) == "string" and stamp ~= "none" then
		line = os.date(stamp, env.time()) .. line
	end
	frame:AddMessage(line, 1, 1, 1, 7, 1, 1, event, args, function() end)
	return true
end

-- Entries(frame) -> the frame's history as packed { message, r, g, b, ... } entries, oldest first.
function C.Entries(frame)
	local out = {}
	for i = 1, frame:GetNumMessages() do
		out[i] = pack(frame:GetMessageInfo(i))
	end
	return out
end

-- Lines(frame) -> the messages in the frame's history, oldest first.
function C.Lines(frame)
	local out = {}
	for i, entry in ipairs(C.Entries(frame)) do
		out[i] = entry[1]
	end
	return out
end

function C.Newest(frame)
	local entries = C.Entries(frame)
	return entries[#entries]
end

function C.Last(frame)
	local entry = C.Newest(frame)
	return entry and entry[1]
end

-- Fields(object) -> the set of the object's own string keys that do not start with "_".
function C.Fields(object)
	local out = {}
	for k in pairs(object) do
		if type(k) ~= "string" or k:sub(1, 1) ~= "_" then
			out[k] = true
		end
	end
	return out
end

-- Snapshot(env) and Check(env, snap, hooked): no field is written onto a Blizzard object, except the
-- methods hooksecurefunc wraps (hooked is a set of method names).
function C.Snapshot(env)
	local snap = {}
	for _, object in ipairs(env._blizzard) do
		snap[object] = C.Fields(object)
	end
	return snap
end

function C.Check(env, snap, hooked)
	for _, object in ipairs(env._blizzard) do
		local before = snap[object]
		if before then
			for k in pairs(C.Fields(object)) do
				if not (before[k] or (hooked and hooked[k])) then
					error("a field was written onto a Blizzard object: " .. tostring(k) .. " on " .. tostring(rawget(object, "_name") or rawget(object, "_type")), 2)
				end
			end
		end
		local name = rawget(object, "_name")
		for _, call in ipairs(object._calls) do
			if call.method == "SetScript" or call.method == "Hide" then
				error(call.method .. " on a Blizzard object " .. tostring(name), 2)
			end
		end
	end
end

-- Install(env) adds the Blizzard chat stand-ins before the core loads. opts.frames: how many chat
-- frames (default 3), opts.noFilters / opts.noTransform / opts.noEventRegistry / opts.noMenu /
-- opts.noSetCVar remove that API, as an older or changed client would.
function C.Install(env, opts)
	opts = opts or {}
	env._blizzard = {}
	env._messageFilters = {}
	env._nameFilters = {}
	env.date = os.date
	env.CHAT_FRAMES = {}
	env._cvars = { showTimestamps = "none" }
	env._cvarWrites = {}
	env.C_CVar = {
		GetCVar = function(name)
			return env._cvars[name]
		end,
	}
	-- SetCVar stores the value and fires CVAR_UPDATE inside the call, as the client does.
	-- env._cvarFilter(name, value) -> stored value lets a test model a client that changes or refuses a value.
	if not opts.noSetCVar then
		env.C_CVar.SetCVar = function(name, value)
			env._cvarWrites[#env._cvarWrites + 1] = { name = name, value = value }
			if env._cvarFilter then
				value = env._cvarFilter(name, value)
			end
			env._cvars[name] = value
			env.FireEvent("CVAR_UPDATE", name, value)
			return true
		end
	end
	env.RAID_CLASS_COLORS = {
		WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
		MAGE = { r = 0.25, g = 0.78, b = 0.92 },
		PRIEST = { r = 1, g = 1, b = 1 },
	}
	env._players = { ["Player-1-0001"] = "WARRIOR", ["Player-1-0002"] = "MAGE" }
	function env.GetPlayerInfoByGUID(guid)
		local class = env._players[guid]
		if class then
			return class:sub(1, 1) .. class:sub(2):lower(), class, "Human", "Human", 2, "Name", "Realm", 60
		end
	end
	if not opts.noFilters then
		local function remove(list, fn)
			for i = #list, 1, -1 do
				if list[i] == fn then
					table.remove(list, i)
				end
			end
		end
		env.ChatFrameUtil = {
			AddMessageEventFilter = function(event, fn)
				local list = env._messageFilters[event] or {}
				env._messageFilters[event] = list
				remove(list, fn)
				list[#list + 1] = fn
			end,
			RemoveMessageEventFilter = function(event, fn)
				remove(env._messageFilters[event] or {}, fn)
			end,
			AddSenderNameFilter = function(fn)
				remove(env._nameFilters, fn)
				env._nameFilters[#env._nameFilters + 1] = fn
			end,
			RemoveSenderNameFilter = function(fn)
				remove(env._nameFilters, fn)
			end,
		}
	end
	if not opts.noEventRegistry then
		local callbacks = {}
		env.EventRegistry = {
			RegisterCallback = function(self, event, fn, owner)
				callbacks[event] = callbacks[event] or {}
				callbacks[event][owner] = fn
			end,
			UnregisterCallback = function(self, event, owner)
				if callbacks[event] then
					callbacks[event][owner] = nil
				end
			end,
			TriggerEvent = function(self, event, ...)
				for owner, fn in pairs(callbacks[event] or {}) do
					fn(owner, ...)
				end
			end,
		}
		env._callbacks = callbacks
	end
	if not opts.noMenu then
		env._menus = {}
		env.Menu = {
			ModifyMenu = function(tag, fn)
				local list = env._menus[tag] or {}
				env._menus[tag] = list
				local entry = { fn = fn }
				list[#list + 1] = entry
				return {
					Unregister = function()
						entry.dead = true
					end,
				}
			end,
		}
	end
	env.GENERAL_CHAT_DOCK = blizzard(env, env.CreateFrame("Frame", "GeneralDockManager", env.UIParent))
	env.GENERAL_CHAT_DOCK.overflowButton = blizzard(env, env.CreateFrame("Button", "GeneralDockManagerOverflowButton", env.GENERAL_CHAT_DOCK))
	env.GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = {}
	for id = 1, opts.frames or 3 do
		local frame = newChatFrame(env, id)
		if id == 1 then
			frame.isDocked = 1
			env.DEFAULT_CHAT_FRAME = frame
			env.SELECTED_CHAT_FRAME = frame
			env.GENERAL_CHAT_DOCK.primary = frame
			env.GENERAL_CHAT_DOCK.selected = frame
		elseif id == 2 then
			frame.isDocked = 1
		end
		if frame.isDocked then
			table.insert(env.GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES, frame)
		end
		if opts.noTransform then
			frame.TransformMessages = nil
		end
	end
	-- Edit Mode's system mixin replaces ChatFrame1's SetPoint and ClearAllPoints with overrides that
	-- tell the Edit Mode manager, and keeps the widget methods as SetPointBase and ClearAllPointsBase.
	local primary = env.ChatFrame1
	if primary and not opts.noEditMode then
		env._editModeAnchors = 0
		primary.SetPointBase = primary.SetPoint
		primary.ClearAllPointsBase = primary.ClearAllPoints
		primary.SetPoint = function(self, ...)
			env._editModeAnchors = env._editModeAnchors + 1
			return self:SetPointBase(...)
		end
		primary.ClearAllPoints = function(self)
			env._editModeAnchors = env._editModeAnchors + 1
			return self:ClearAllPointsBase()
		end
		local manager = blizzard(env, env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent))
		manager:Hide()
		manager._calls = {}
		manager.IsEditModeActive = function()
			return env._editMode == true
		end
	end
	-- EditModeAnchor(env) re-anchors ChatFrame1 the way ApplySystemAnchor does, through the overrides.
	function env.EditModeAnchor()
		primary:ClearAllPoints()
		primary:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 32, 95)
	end
	function env.IsCombatLog(frame)
		return frame == env.ChatFrame2 and env._combatLog == true
	end
	function env.FCFDock_GetSelectedWindow(dock)
		return dock.selected
	end
	-- FCFDock_SetPrimary anchors the dock to the primary window's Background; FCFDock_OnPrimarySizeChanged
	-- marks the dock dirty and relays its tabs on the next frame. The stub counts the relays in env._dockResized
	-- and, when a scene gave C.Dock a measure, lays the tabs out again at the dock's new width.
	env._dockResized = 0
	function env.FCFDock_SetPrimary(dock, chatFrame)
		dock.primary = chatFrame
		dock:SetPoint("BOTTOMLEFT", chatFrame.Background, "TOPLEFT")
		dock:SetPoint("BOTTOMRIGHT", chatFrame.Background, "TOPRIGHT")
	end
	env.FCFDock_SetPrimary(env.GENERAL_CHAT_DOCK, env.GENERAL_CHAT_DOCK.primary)
	function env.FCFDock_OnPrimarySizeChanged(dock)
		env._dockResized = env._dockResized + 1
		if dock._measure then
			C.Dock(env, dock._measure)
		end
	end
	function env.FCF_OpenTemporaryWindow()
		local frame = newChatFrame(env, #env.CHAT_FRAMES + 1)
		frame.isTemporary = true
		frame.isDocked = 1
		table.insert(env.GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES, frame)
		return frame
	end
	function env.FCFTab_UpdateColors(tab, selected)
		tab._selected = selected and true or false
	end
	function env.FCF_SetWindowName(frame, name)
		env[frame:GetName() .. "Tab"]:SetText(name)
	end
	function env.FCF_DockFrame(frame)
		frame.isDocked = 1
	end
	function env.FCF_UnDockFrame(frame)
		frame.isDocked = nil
	end
	function env.FCF_SetChatWindowFontSize(_, frame, size)
		local path, _, flags = frame:GetFont()
		frame:SetFont(path, size, flags)
	end
end

-- Dock(env, measure) lays the dock and its tabs out the way FCFDock_UpdateTabs does on the forever branch: the
-- dock, 26 tall, sits on the primary window's Background; the primary tab is static, its text's width plus
-- PanelTemplates_TabResize's 20 units of sides, at the dock's bottom left; every other docked tab is dynamic,
-- 90 wide (FCFDock_CalculateTabSize's maximum, when they fit), one unit right of the one before. The stub font
-- strings have no metrics, so measure(text, size) -> width stands in for GetStringWidth.
function C.Dock(env, measure)
	local dock = env.GENERAL_CHAT_DOCK
	local primary = dock.primary
	dock._measure = measure
	if dock:GetNumPoints() == 0 then
		env.FCFDock_SetPrimary(dock, primary)
	end
	dock:SetHeight(26)
	-- FCFDock_CalculateTabSize: the dynamic tabs share the room right of the static tab, 90 each when they fit,
	-- else 60 at least with the overflow button taking the ones that do not; the dock's width is resolved from
	-- its anchors, as the game resolves it.
	local Geometry = dofile("Tools/regression/geometry.lua")
	local rect = Geometry.Rect(dock, env.UIParent)
	local dockWidth = rect and (rect.right - rect.left) or math.huge
	local statics, dynamics = {}, {}
	for _, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
		local tab = env[frame:GetName() .. "Tab"]
		local _, size = tab.Text:GetFont()
		tab._textWidth = measure(tab.Text:GetText() or "", size or 10)
		if frame == primary then
			statics[#statics + 1] = tab
		else
			dynamics[#dynamics + 1] = tab
		end
	end
	local staticWidth = 0
	for _, tab in ipairs(statics) do
		staticWidth = staticWidth + tab._textWidth + 20 + 1
	end
	local scroll = dockWidth - staticWidth
	local tabSize, whole = 90, #dynamics
	if #dynamics * 90 >= scroll then
		if math.floor(scroll / 60) <= #dynamics then
			scroll = scroll - 30 - 5
		end
		whole = math.min(math.floor(scroll / 60), #dynamics)
		tabSize = whole > 0 and scroll / whole or scroll
	end
	local previous
	for _, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
		local tab = env[frame:GetName() .. "Tab"]
		tab:ClearAllPoints()
		tab:SetParent(dock)
		if frame == primary then
			tab.Text:SetWidth(tab._textWidth)
			tab:SetWidth(tab._textWidth + 20)
			tab:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
			tab:Show()
		else
			tab.Text:SetWidth(math.max(1, tabSize - 20))
			tab:SetWidth(tabSize)
			tab:SetPoint("LEFT", previous, "RIGHT", 1, 0)
			whole = whole - 1
			tab:SetShown(whole >= 0)
		end
		env.FCFTab_UpdateColors(tab, frame == dock.selected)
		previous = tab
	end
end

-- OpenMenu(env, tag, owner) -> the entries KstyleUI added to Blizzard's menu with that tag, as
-- { { label, onClick } }, built the way Menu.ModifyMenu callbacks run.
function C.OpenMenu(env, tag, owner)
	local entries = {}
	local root = {
		CreateDivider = function() end,
		CreateButton = function(_, label, onClick)
			entries[#entries + 1] = { label = label, onClick = onClick }
		end,
	}
	for _, entry in ipairs(env._menus[tag] or {}) do
		if not entry.dead then
			entry.fn(owner, root, {})
		end
	end
	return entries
end

-- New(opts) -> env, KstyleUI, the KstyleUI_Chat addon table. The core loads its saved data, the
-- chat addon loads, then PLAYER_LOGIN fires: the order the game uses. opts.install takes the
-- Install options; opts.saved is KstyleUIDB.
function C.New(opts)
	opts = opts or {}
	local setup = opts.setup
	local env, K = W.New({
		saved = opts.saved,
		width = opts.width,
		height = opts.height,
		uiScale = opts.uiScale,
		boot = false,
		setup = function(e)
			C.Install(e, opts.install)
			if setup then
				setup(e)
			end
		end,
	})
	W.CoreEnv.LoadSaved(env)
	Load(C.Files(), env)
	W.CoreEnv.Login(env)
	env.RunTimers()
	return env, K, env._addons.KstyleUI_Chat
end

function C.Enable(env, K)
	K.Modules.Enable("Chat")
	env.RunTimers()
end

return C
