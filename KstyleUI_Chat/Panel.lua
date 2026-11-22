-- Panel.lua: the chat's panel, a Layout element that holds Blizzard's main chat window, its tabs and its edit box: a framed card, or in the Orbs HUD style bare text on a soft shadow, with tabs that show on hover.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Scale = K.Widgets, K.Tokens, K.Scale
local Format, Windows = ns.Format, ns.Windows
local max, min, floor, ceil = math.max, math.min, math.floor, math.ceil

local Panel = {}
ns.Panel = Panel

local KEY = "chat.main"
local STRATA = "BACKGROUND"
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 260, 120, 1000, 800
local RULE_ALPHA = 0.35
local CHAT_FILL = "medChatFill"
local SHADE_LOBES, SHADE_X, SHADE_Y, SHADE_W, SHADE_H, SHADE_ALPHA = { -0.2727, 0, 0.2727 }, 0.47, 0.563, 1.09, 2.38, 0.46
local BUTTON_SIZE, BUTTON_GLYPH, BUTTON_INSET = 20, 8, 22
local COPY_SQUARE = 5.5
local EDIT_MODE_EXIT = "EditMode.Exit"
local LAYOUT_CHANGED = "LayoutChanged"

local TAB_TEXT_RISE = 14
local TAB_ROW = 34
local BACKGROUND_RISE = 3
local EDIT_DROP = 2
local EDIT_HEIGHT = 32
local EDIT_LEFT = 5
local EDIT_PAST_SCROLLBAR = 8
local SCROLLBAR_WIDTH = 8
local SIDE_ROOM, SIDE_MIN = 35, 32
local COLUMN_WIDTH = 29
local ICONS = { channels = { "ChatFrameChannelButton" }, voice = { "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }, menu = { "ChatFrameMenuButton" } }

local STRIP_HEIGHT = 32
local EDIT_TILE = 22
local EDIT_BOTTOM = 6

local IDLE_OWNER = "ChatIdle"
local WAKE_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM",
}
local WAKE_GROUPS = {
	emotes = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" },
	skills = { "CHAT_MSG_SKILL", "CHAT_MSG_COMBAT_XP_GAIN" },
	reputation = { "CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_COMBAT_HONOR_GAIN" },
	loot = { "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_CURRENCY" },
	system = { "CHAT_MSG_SYSTEM" },
	achievements = { "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT" },
	npc = { "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_MONSTER_PARTY", "CHAT_MSG_RAID_BOSS_EMOTE", "CHAT_MSG_RAID_BOSS_WHISPER" },
}

local IsSecret = Format.IsSecret

local state = {
	active = false,
	holder = nil,
	glass = nil,
	chat = nil,
	settings = nil,
	placing = false,
	queued = false,
	waiting = false,
	editMode = false,
	alpha = nil,
	hooked = false,
	trimmed = false,
	bare = false,
	hover = false,
}
local logged = {}
local HookHover, SideAlpha
local mirrored = setmetatable({}, { __mode = "k" })
local edits = setmetatable({}, { __mode = "k" })
local busy = false
local kept, dragged, held = {}, {}, {}

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

local function Number(v, fallback)
	if IsSecret(v) or type(v) ~= "number" or v ~= v or v <= 0 then
		return fallback
	end
	return v
end

local function Pad()
	local glass = state.glass
	if glass then
		return glass.chrome:Inset("gapMedium")
	end
	return Widgets.WindowInset()
end

local function Ratio(chat, holder)
	local own = Number(chat:GetEffectiveScale(), nil)
	local root = Number((holder or Scale.Root()):GetEffectiveScale(), nil)
	if not own or not root then
		return 1
	end
	return own / root
end

local function ScrollWidth(frame)
	local bar = frame.ScrollBar
	if type(bar) ~= "table" or type(bar.GetWidth) ~= "function" then
		return SCROLLBAR_WIDTH
	end
	return Number(bar:GetWidth(), SCROLLBAR_WIDTH)
end

local function EditAlways()
	local settings = state.settings
	return settings ~= nil and settings.editBox == "always"
end

local function Tile()
	return Number(state.settings and state.settings.editHeight, EDIT_TILE)
end

local function Free(s, name)
	local spot = s.sideFree == true and type(s.sidePositions) == "table" and s.sidePositions[name]
	return type(spot) == "table" and type(spot.x) == "number" and type(spot.y) == "number" and spot or nil
end

local function Picks(s)
	local icons, ids, top, bottom, free = type(s.sideIcons) == "table" and s.sideIcons or {}, {}, {}, {}, {}
	for id in tostring(s.sideOrder):gmatch("%a+") do
		if ICONS[id] then ids[#ids + 1] = id end
	end
	for i, id in ipairs(ids) do
		for _, name in ipairs(icons[id] ~= false and ICONS[id] or {}) do
			local icon = _G[name]
			if type(icon) == "table" and type(icon.SetScale) == "function" and icon:IsShown() then
				local list = Free(s, name) and free or i == #ids and bottom or top
				list[#list + 1] = icon
			end
		end
	end
	return top, bottom, free
end

local function Tall(frame)
	local saved = kept[frame]
	return Number(frame:GetHeight(), 0) * Ratio(frame, state.holder) * (saved and saved.scale / saved.set or 1)
end

local function Fit(s, chat, k, height, top, foot, cap)
	local want = Number(s.sideScale, 1)
	if want <= 1 then
		return want
	end
	local above, below = Picks(s)
	local tall, n, friends = 0, #above + #below, QuickJoinToastButton
	for _, list in ipairs({ above, below }) do
		for _, icon in ipairs(list) do tall = tall + Tall(icon) end
	end
	if s.sideScroll == true and type(chat.ScrollToBottomButton) == "table" then
		tall, n = tall + Tall(chat.ScrollToBottomButton), n + 1
	end
	local lead = type(friends) == "table" and not (type(s.sideIcons) == "table" and s.sideIcons.friends == false) and Tall(friends) or 0
	local room = height - foot - n * max(0, tonumber(s.sideSpacing) or 2) * k
	return tall > 0 and max(1, min(want, (room - top) / tall, (room - cap) / (tall + lead))) or want
end

function Panel.Geometry(chat)
	local k = Ratio(chat, state.holder)
	local snap = Scale.Snap
	local pad = snap(Pad())
	local foot = pad
	if EditAlways() and not state.settings.inputOnTop then
		local tile = max(0, (EDIT_HEIGHT * k - Tile()) / 2)
		foot = snap(pad + (EDIT_DROP + EDIT_HEIGHT) * k - tile)
	end
	local divider = snap(max(Number(state.settings and state.settings.tabHeight, TAB_ROW), TAB_TEXT_RISE * k + BUTTON_SIZE / 2))
	local top = divider + (Widgets.Readability("chatTabs") and snap(12) or 0)
	if state.settings and state.settings.inputOnTop then top = top + snap((EDIT_HEIGHT + EDIT_DROP) * k) end
	local _, size = chat:GetFont()
	local height = state.holder and state.holder:GetHeight()
	local spacing
	if Number(size, 0) > 0 and Number(height, 0) > 0 then
		local gap = Number(type(chat.GetSpacing) == "function" and chat:GetSpacing(), 0)
		if state.settings and ns.Frames and ns.Frames.Pitch then
			local _, wantGap = ns.Frames.Pitch(state.settings)
			gap = Widgets.Snap(chat, wantGap)
		end
		local line, want = size * k, gap * k
		local room = height - top - foot
		local pixel = Scale.Pixel(1)
		local least = min(want, max(pixel, floor(want / pixel + 1e-6) * pixel))
		local fit = least
		for n = max(1, floor((room + least) / (line + least) + 1e-6)), 2, -1 do
			local spare = room - n * line
			local step = max(least, ceil(spare / n / pixel - 1e-6) * pixel)
			if (n - 1) * step <= spare + 1e-6 then
				fit = step
				break
			end
		end
		spacing = fit / k
	end
	local s = state.settings
	local scale = s and s.buttons and Fit(s, chat, k, Number(height, 0), top, foot, (s.tabsAbove and divider or 0) + pad) or 1
	local room = s and max(SIDE_MIN * max(1, scale), Number(s.sideWidth, SIDE_ROOM)) or SIDE_ROOM
	local side = s and s.buttons and room * k or 0
	local right = s and s.sideRight and side > 0
	local strip, apart = 0, 0
	if side > 0 and (s.sideStyle == "glass" or s.sideStyle == "bare") then
		strip = 2 * pad + side - (SIDE_ROOM - COLUMN_WIDTH) * k
		apart, side = strip + max(0, tonumber(s.sideGap) or 0), 0
	end
	local band = right and (side > 0 and side + SCROLLBAR_WIDTH * k or apart) or 0
	local left = pad + (right and 0 or side + apart)
	return {
		k = k,
		left = left,
		top = top,
		right = pad + band,
		band = band,
		rule = apart > 0 and pad + band or left + band,
		near = right and 0 or apart,
		far = right and apart or 0,
		strip = strip,
		room = room,
		scale = scale,
		bottom = foot,
		divider = divider,
		spacing = spacing,
	}
end

function Panel.EditInsets(frame)
	local k = Ratio(frame, state.holder)
	local vertical = max(0, (EDIT_HEIGHT - Tile() / k) / 2)
	return { left = EDIT_LEFT, right = EDIT_PAST_SCROLLBAR, top = vertical, bottom = vertical }
end

function Panel.UndockedInsets(frame)
	local k = Ratio(frame, nil)
	local pad = Pad() / k
	local bottom = -pad
	if EditAlways() then
		bottom = -(EDIT_DROP + EDIT_HEIGHT - max(0, (EDIT_HEIGHT - Tile() / k) / 2) + EDIT_BOTTOM / k)
	end
	return {
		left = -pad,
		right = -(ScrollWidth(frame) + pad),
		top = -(BACKGROUND_RISE + (state.settings and state.settings.tabsAbove and 0 or STRIP_HEIGHT / k)),
		bottom = bottom,
	}
end

function Panel.Bare(settings)
	settings = settings or state.settings
	return settings ~= nil and settings.framing == "bare"
end

function Panel.Holder()
	return state.holder
end

function Panel.Glass()
	return state.glass
end

function Panel.CopyButton()
	return state.glass and state.glass.copy
end

function Panel.MenuButton()
	return state.glass and state.glass.plus
end

function Panel.DockEnd()
	return state.glass and state.glass.dockEnd
end

local function Dock()
	local dock, chat = GENERAL_CHAT_DOCK, state.chat
	if type(dock) ~= "table" or type(dock.SetPoint) ~= "function" or not chat or dock.primary ~= chat or type(chat.Background) ~= "table" then
		return nil
	end
	return dock, chat.Background
end

local function RelayTabs(dock)
	if type(FCFDock_OnPrimarySizeChanged) == "function" then
		FCFDock_OnPrimarySizeChanged(dock)
	else
		LogOnce("dock-relay", "FCFDock_OnPrimarySizeChanged is missing; the tabs relay on Blizzard's next update")
	end
end

local function TrimDock()
	local dock = Dock()
	local glass = state.glass
	if not dock or not glass then
		return
	end
	local settings = state.settings
	local stop, last = glass.dockEnd, settings and settings.copyButton == true and glass.copy or glass.plus
	stop:ClearAllPoints()
	stop:SetPoint("TOPRIGHT", last, "TOPLEFT", -Widgets.Snap(stop, Tokens.Size("gapTiny")), 0)
	local g, k = Panel.Geometry(state.chat), Ratio(dock, state.holder)
	local x, y = g.left - 2 * k, -g.divider / 2 - 8.15 * k
	stop:SetPoint("BOTTOMLEFT", state.holder, "TOPLEFT", x, y)
	dock:SetPoint("BOTTOMLEFT", state.holder, "TOPLEFT", x / k, y / k)
	dock:SetPoint("BOTTOMRIGHT", stop, "BOTTOMRIGHT", 0, 0)
	RelayTabs(dock)
	if ns.Frames and ns.Frames.FitTabs then
		ns.Frames.FitTabs(dock)
	end
	LogOnce("dock", "the tab dock ends before the panel's glyphs, so Blizzard overflows the tabs that no longer fit")
end

local function RestoreDock()
	local dock, background = Dock()
	if dock and state.trimmed then
		dock:SetPoint("BOTTOMLEFT", background, "TOPLEFT", 0, 0)
		dock:SetPoint("BOTTOMRIGHT", background, "TOPRIGHT", 0, 0)
		RelayTabs(dock)
	end
	state.trimmed = false
end

function Panel.Status()
	local chat, holder = state.chat, state.holder
	if not chat then
		return false, "ChatFrame1 is missing"
	end
	local _, relative = chat:GetPoint(1)
	if not IsSecret(relative) and relative == holder then
		return true, "ChatFrame1 sits in the panel"
	end
	return false, "ChatFrame1 is outside the panel: Edit Mode is open or another addon moved it"
end

local function EditModeActive()
	local manager = EditModeManagerFrame
	if type(manager) ~= "table" or type(manager.IsEditModeActive) ~= "function" then
		return false
	end
	local active = manager:IsEditModeActive()
	return IsSecret(active) or active == true
end

local function Protected(frame)
	if type(frame.IsProtected) ~= "function" then
		return false
	end
	local protected = frame:IsProtected()
	return IsSecret(protected) or protected == true
end

local function Focused(box)
	if type(box.HasFocus) ~= "function" then
		return false
	end
	local focus = box:HasFocus()
	return IsSecret(focus) or focus == true
end

local function ApplyEdit(box, info)
	local factor, mouse = 1, true
	if state.active and not Focused(box) then
		if not EditAlways() then
			factor, mouse = 0, false
		elseif info.frame.isDocked then
			factor = state.alpha or 1
		end
	end
	busy = true
	box:SetAlpha(info.wanted * factor)
	busy = false
	if type(box.EnableMouse) == "function" then
		box:EnableMouse(mouse)
	end
end

local function EditAlpha(frame)
	local box = frame.editBox
	if type(box) ~= "table" or type(box.SetAlpha) ~= "function" then
		return
	end
	local info = edits[box]
	if not info then
		info = { frame = frame, wanted = Number(box:GetAlpha(), 1) }
		edits[box] = info
		hooksecurefunc(box, "SetAlpha", function(self, alpha)
			if not busy then
				info.wanted = Number(alpha, 1)
				ApplyEdit(self, info)
			end
		end)
		box:HookScript("OnEditFocusGained", function(self)
			ApplyEdit(self, info)
			state.typing = true
			Panel.Wake()
		end)
		box:HookScript("OnEditFocusLost", function(self)
			ApplyEdit(self, info)
			state.typing = false
			Panel.Wake()
		end)
	end
	ApplyEdit(box, info)
end

local function DockAlpha(alpha)
	if state.active and state.bare and not state.hover then
		return 0
	end
	return alpha
end

local function SetChatAlpha(alpha, force)
	if state.alpha == alpha and not force then
		return
	end
	state.alpha = alpha
	local dock = GENERAL_CHAT_DOCK
	if type(dock) == "table" and type(dock.SetAlpha) == "function" then
		dock:SetAlpha(DockAlpha(alpha))
	end
	for _, frame in ipairs(Windows.List()) do
		if state.active and frame.isDocked then
			frame:SetAlpha(alpha)
			mirrored[frame] = true
		elseif mirrored[frame] then
			frame:SetAlpha(1)
			mirrored[frame] = nil
		end
		EditAlpha(frame)
	end
end

local function IdleFactor()
	local s = state.settings
	if not state.faded or not s or s.idleFade ~= true then
		return 1
	end
	return 1 - min(1, Number(s.idleStrength, 0))
end

local function Mirror()
	local holder = state.holder
	if not state.active or not holder then
		return
	end
	local alpha, factor = 0, IdleFactor()
	if holder:IsShown() then
		alpha = Number(holder:GetAlpha(), 0)
	end
	SetChatAlpha(alpha * factor)
	if (state.factor or 1) ~= factor then
		state.factor = factor
		state.glass:SetAlpha(factor)
		Widgets.ColorSlice(state.shade, Widgets.Rgba("black", SHADE_ALPHA * factor))
		SideAlpha()
	end
end

local function Settle()
	state.idleTimer = false
	local s = state.settings
	if not state.active or not s or s.idleFade ~= true or state.faded then
		return
	end
	local left = state.idleAt - GetTime()
	if left > 0 then
		state.idleTimer = true
		C_Timer.After(left, Settle)
	elseif not state.hover and not state.typing then
		state.faded = true
		Mirror()
	end
end

function Panel.Wake()
	local s = state.settings
	if not state.active or not s or s.idleFade ~= true then
		return
	end
	local delay = Number(s.idleDelay, 15)
	state.idleAt = GetTime() + delay
	if state.faded then
		state.faded = false
		Mirror()
	end
	if not state.idleTimer then
		state.idleTimer = true
		C_Timer.After(delay, Settle)
	end
end

local function Idle()
	local s = state.settings
	local on = state.active and s ~= nil and s.idleFade == true
	local wake = s and type(s.idleWake) == "table" and s.idleWake or {}
	for _, event in ipairs(WAKE_EVENTS) do
		if on then K.Events.Register(IDLE_OWNER, event, Panel.Wake) else K.Events.Unregister(IDLE_OWNER, event) end
	end
	for key, events in pairs(WAKE_GROUPS) do
		for _, event in ipairs(events) do
			if on and wake[key] == true then K.Events.Register(IDLE_OWNER, event, Panel.Wake) else K.Events.Unregister(IDLE_OWNER, event) end
		end
	end
	state.faded = false
	Mirror()
	Panel.Wake()
end

function Panel.Spacing(frame)
	if state.active and not state.waiting and state.holder and (frame == state.chat or frame.isDocked) then
		return Panel.Geometry(frame).spacing
	end
end

function Panel.Sync()
	state.alpha = nil
	Mirror()
end

function Panel.PaintRule(divider)
	Widgets.Tint(divider, "gilt", RULE_ALPHA)
end

local function SyncHeader()
	local glass = state.glass
	local banded, above = Widgets.Medallions(), state.settings and state.settings.tabsAbove
	glass.divider:SetShown(not state.bare and not banded and not above)
	glass.chrome:SetHeader(banded and not above and state.headerUnits or nil)
end

local function PlaceGlass(g)
	local glass, holder = state.glass, state.holder
	local divider = glass.divider
	local top = state.settings.tabsAbove and -g.divider or 0
	if state.near ~= g.near or state.far ~= g.far or state.top ~= top then
		state.near, state.far, state.top = g.near, g.far, top
		glass:ClearAllPoints()
		glass:SetPoint("TOPLEFT", holder, "TOPLEFT", g.near, top)
		glass:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -g.far, 0)
	end
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", glass, "TOPLEFT", g.left - g.near, -g.divider)
	divider:SetPoint("TOPRIGHT", glass, "TOPRIGHT", g.far - g.rule, -g.divider)
	divider:SetHeight(Widgets.Border(divider))
	Panel.PaintRule(divider)
	state.headerUnits = g.divider + Widgets.Border(glass)
	SyncHeader()
	local y, host = -g.divider / 2, top < 0 and holder or glass
	local band = g.band - (host == glass and g.far or 0)
	glass.plus:ClearAllPoints()
	glass.plus:SetPoint("CENTER", host, "TOPRIGHT", -Widgets.Snap(glass.plus, BUTTON_INSET + band), Widgets.Snap(glass.plus, y))
	glass.copy:ClearAllPoints()
	glass.copy:SetPoint("CENTER", host, "TOPRIGHT", -Widgets.Snap(glass.copy, BUTTON_INSET + BUTTON_SIZE + Tokens.Size("gapTiny") + band), Widgets.Snap(glass.copy, y))
	local strip = Panel.strip
	if strip then
		local edge = state.settings.sideRight and "RIGHT" or "LEFT"
		strip:ClearAllPoints()
		strip:SetPoint("TOP" .. edge, holder, "TOP" .. edge, 0, top)
		strip:SetPoint("BOTTOM" .. edge, holder, "BOTTOM" .. edge, 0, 0)
		strip:SetWidth(max(1, g.strip))
	end
end

local function PlaceEdit(frame, k, over, own)
	local box, bar = frame.editBox, frame.ScrollBar
	if type(box) ~= "table" or type(box.SetPoint) ~= "function" or type(bar) ~= "table" then
		return
	end
	if state.active and state.settings.inputOnTop and own then
		box:ClearAllPoints()
		box:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -EDIT_LEFT, EDIT_DROP)
		box:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", EDIT_PAST_SCROLLBAR, EDIT_DROP)
		return
	end
	local y = -EDIT_DROP
	if over then
		y = EDIT_HEIGHT - max(0, (EDIT_HEIGHT - Tile() / k) / 2)
	end
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -EDIT_LEFT, y)
	if own then
		box:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", EDIT_PAST_SCROLLBAR, y)
		return
	end
	box:SetPoint("RIGHT", bar, "RIGHT", EDIT_PAST_SCROLLBAR, 0)
end

local sideBase, sideSet = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })

local function SideFrames()
	local list = {}
	for _, frame in pairs({ state.chat and state.chat.buttonFrame, ChatFrameMenuButton, ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton, QuickJoinToastButton, ChatAlertFrame, Panel.strip }) do
		if type(frame) == "table" and type(frame.SetAlpha) == "function" then
			list[#list + 1] = frame
		end
	end
	for _, window in ipairs(Windows.List()) do
		if kept[window.ScrollToBottomButton] then list[#list + 1] = window.ScrollToBottomButton end
	end
	return list
end

local function SideRule()
	local s = state.settings
	local on = state.active and s ~= nil and s.buttons == true
	return on and s.sideHover == true and not state.hover, on and IdleFactor() or 1
end

local function SideSet(frame, hide, factor, column)
	local alpha = frame:GetAlpha()
	if not IsSecret(alpha) and alpha ~= sideSet[frame] then
		sideBase[frame] = alpha
	end
	local scale = hide and 0 or (frame == column or frame:GetParent() == column) and 1 or factor
	busy = true
	if scale ~= 1 then
		sideSet[frame] = (sideBase[frame] or 1) * scale
		frame:SetAlpha(sideSet[frame])
	elseif sideSet[frame] ~= nil then
		frame:SetAlpha(sideBase[frame] or 1)
		sideSet[frame] = nil
	end
	busy = false
end

function SideAlpha()
	local hide, factor = SideRule()
	if not hide and factor == 1 and next(sideSet) == nil then
		return
	end
	local column = state.chat and state.chat.buttonFrame
	for _, frame in ipairs(SideFrames()) do
		SideSet(frame, hide, factor, column)
	end
end

local function Hold(button)
	if not busy and kept[button] and sideSet[button] ~= nil then
		SideSet(button, SideRule())
	end
end

local function Keep(frame, width)
	if not kept[frame] then
		local saved = { scale = frame:GetScale(), width = width and frame:GetWidth() }
		local secret = IsSecret(saved.scale) or IsSecret(saved.width)
		for i = 1, frame:GetNumPoints() do
			saved[i] = { frame:GetPoint(i) }
			for j = 1, 5 do secret = secret or IsSecret(saved[i][j]) end
		end
		if secret then
			return nil
		end
		saved.set = saved.scale
		kept[frame] = saved
	end
	return kept[frame]
end

local function Resize(frame, scale)
	local saved = Keep(frame)
	if saved and saved.set ~= saved.scale * scale then
		saved.set = saved.scale * scale
		frame:SetScale(saved.set)
	end
	return saved
end

local function Return(frame)
	local saved = kept[frame]
	kept[frame] = nil
	frame:ClearAllPoints()
	for _, point in ipairs(saved) do frame:SetPoint(unpack(point)) end
	frame:SetScale(saved.scale)
	if saved.width then frame:SetWidth(saved.width) end
	if saved.bar then saved.bar[1]:SetPoint(unpack(saved.bar, 2)) end
	if sideSet[frame] ~= nil then
		frame:SetAlpha(sideBase[frame] or 1)
		sideSet[frame] = nil
	end
end

local function Spot(icon, column, spot)
	local f = Number(column:GetEffectiveScale(), 1) / Number(icon:GetEffectiveScale(), 1)
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", column, "TOPLEFT", spot.x * f, spot.y * f)
end

local function Unpin(frame)
	local bar, button = frame.ScrollBar, frame.ScrollToBottomButton
	for i = 1, type(bar) == "table" and bar:GetNumPoints() or 0 do
		local p, rel, relp, x, y = bar:GetPoint(i)
		if not IsSecret(rel) and rel == button then
			kept[button].bar = { bar, p, rel, relp, x, y }
			bar:SetPoint(p, frame, "BOTTOMRIGHT", 0, 0)
		end
	end
end

local function Scrolls(column, on, scale)
	for _, frame in ipairs(Windows.List()) do
		local button = frame.ScrollToBottomButton
		if type(button) == "table" and on and frame.isDocked and Resize(button, scale) then
			button:ClearAllPoints()
			button:SetPoint("BOTTOM", column, "BOTTOM", 0, 0)
			Unpin(frame)
			if not held[button] then
				held[button] = true
				hooksecurefunc(button, "SetAlpha", Hold)
			end
		elseif kept[button] then
			Return(button)
		end
	end
	return on and kept[state.chat.ScrollToBottomButton] and state.chat.ScrollToBottomButton or nil
end

local function Stack(column, s, scale)
	local gap = max(0, tonumber(s.sideSpacing) or 2) / scale
	local top, bottom, free = Picks(s)
	for _, icon in ipairs(free) do
		if Resize(icon, scale) then Spot(icon, column, Free(s, icon:GetName())) end
	end
	local above = column
	for _, icon in ipairs(top) do
		if Resize(icon, scale) then
			icon:ClearAllPoints()
			icon:SetPoint("TOP", above, above == column and "TOP" or "BOTTOM", 0, above == column and 0 or -gap)
			above = icon
		end
	end
	local below = Scrolls(column, s.sideScroll == true, scale) or column
	for i = #bottom, 1, -1 do
		local icon = bottom[i]
		if Resize(icon, scale) then
			icon:ClearAllPoints()
			icon:SetPoint("BOTTOM", below, below == column and "BOTTOM" or "TOP", 0, below == column and 0 or gap)
			below = icon
		end
	end
end

local function DragStart(icon)
	local s = state.settings
	if not state.active or not s or s.sideFree ~= true or type(InCombatLockdown) ~= "function" or InCombatLockdown() or type(IsShiftKeyDown) ~= "function" or not IsShiftKeyDown() then
		return
	end
	state.moving = icon
	icon:SetMovable(true)
	icon:StartMoving()
end

local function DragStop(icon)
	if state.moving ~= icon then
		return
	end
	state.moving = nil
	icon:StopMovingOrSizing()
	icon:SetUserPlaced(false)
	icon:SetMovable(false)
	local column, name = state.chat.buttonFrame, icon:GetName()
	local x, y = icon:GetCenter()
	local values = { x, y, column:GetLeft(), column:GetTop(), icon:GetEffectiveScale(), column:GetEffectiveScale() }
	for i = 1, 6 do
		if IsSecret(values[i]) or type(values[i]) ~= "number" or not IsText(name) then
			return Panel.Schedule()
		end
	end
	local own, scale = values[5], values[6]
	local spots = {}
	for key, spot in pairs(state.settings.sidePositions) do spots[key] = spot end
	spots[name] = { x = floor((x * own - values[3] * scale) / scale + 0.5), y = floor((y * own - values[4] * scale) / scale + 0.5) }
	K.Options.Write(ns.NAME, "sidePositions", spots)
end

local function Draggable(on)
	for _, name in ipairs({ "QuickJoinToastButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "ChatFrameMenuButton" }) do
		local icon = _G[name]
		if type(icon) == "table" and type(icon.RegisterForDrag) == "function" and (dragged[icon] or false) ~= on then
			if dragged[icon] == nil then
				icon:HookScript("OnDragStart", DragStart)
				icon:HookScript("OnDragStop", DragStop)
			end
			dragged[icon] = on
			if on then icon:RegisterForDrag("LeftButton") else icon:RegisterForDrag() end
		end
	end
end

local function Release()
	for frame in pairs(kept) do Return(frame) end
	Draggable(false)
end

function Panel.Place()
	state.queued = false
	local holder, chat = state.holder, state.chat
	if not state.active or not holder or not chat then
		return false
	end
	if type(chat.IsForbidden) == "function" and chat:IsForbidden() == true then
		LogOnce("forbidden", "ChatFrame1 is forbidden; the panel stays empty")
		return false
	end
	if EditModeActive() then
		state.waiting = true
		LogOnce("editmode", "the main chat window waits for Edit Mode to close before it returns to the panel")
		return false
	end
	if InCombatLockdown() and Protected(chat) then
		K.Combat.Queue(Panel.Place)
		return false
	end
	local g = Panel.Geometry(chat)
	if type(chat.SetResizeBounds) == "function" then
		chat:SetResizeBounds(max(1, (MIN_WIDTH - g.left - g.right) / g.k), max(1, (MIN_HEIGHT - g.top - g.bottom) / g.k), (MAX_WIDTH - g.left - g.right) / g.k, (MAX_HEIGHT - g.top - g.bottom) / g.k)
	end
	if g.spacing and type(chat.SetSpacing) == "function" and Number(chat:GetSpacing(), 0) ~= g.spacing then
		chat:SetSpacing(g.spacing)
	end
	local clear = chat.ClearAllPointsBase or chat.ClearAllPoints
	local setPoint = chat.SetPointBase or chat.SetPoint
	local anchors = { TOPLEFT = { g.left / g.k, -g.top / g.k }, BOTTOMRIGHT = { -g.right / g.k, g.bottom / g.k } }
	state.placing = true
	clear(chat)
	setPoint(chat, "TOPLEFT", holder, "TOPLEFT", unpack(anchors.TOPLEFT))
	setPoint(chat, "BOTTOMRIGHT", holder, "BOTTOMRIGHT", unpack(anchors.BOTTOMRIGHT))
	state.placing = false
	state.anchors = anchors
	state.waiting = false
	local s = state.settings
	if s.buttons and type(chat.buttonFrame) == "table" and Keep(chat.buttonFrame, true) then
		local column, friends, icons = chat.buttonFrame, QuickJoinToastButton, s.sideIcons
		local side, x = s.sideRight and "RIGHT" or "LEFT", Scale.Snap(Pad()) / g.k
		local shown = type(friends) == "table" and not (type(icons) == "table" and icons.friends == false)
		if type(friends) == "table" then Resize(friends, g.scale) end
		local top = max(g.top / g.k, (s.tabsAbove and g.divider / g.k or 0) + x + (shown and Number(friends:GetHeight(), 0) * Ratio(friends, holder) / g.k or 0))
		x = side == "RIGHT" and -x or x
		column:ClearAllPoints()
		column:SetWidth(g.room - SIDE_ROOM + COLUMN_WIDTH)
		column:SetPoint("TOP" .. side, holder, "TOP" .. side, x, -top)
		column:SetPoint("BOTTOM" .. side, holder, "BOTTOM" .. side, x, g.bottom / g.k)
		for _, frame in ipairs({ ChatAlertFrame, friends }) do
			if type(frame) == "table" and Keep(frame) then
				frame:ClearAllPoints()
				frame:SetPoint("BOTTOM", column, "TOP", 0, 0)
			end
		end
		local spot = kept[friends] and Free(s, "QuickJoinToastButton")
		if spot then Spot(friends, column, spot) end
		Stack(column, s, g.scale)
		Draggable(s.sideFree == true)
		for _, frame in ipairs(SideFrames()) do
			HookHover(frame)
		end
	else
		Release()
	end
	SideAlpha()
	for _, frame in ipairs(Windows.List()) do
		local name = frame:GetName()
		HookHover(IsText(name) and _G[name .. "Tab"] or nil)
		PlaceEdit(frame, g.k, frame.isDocked ~= nil and not EditAlways(), frame.isDocked ~= nil)
		if frame ~= chat and frame.isDocked and g.spacing and type(frame.SetSpacing) == "function" then
			frame:SetSpacing(g.spacing)
		end
	end
	PlaceGlass(g)
	TrimDock()
	state.trimmed = true
	if chat.SetPointBase then
		LogOnce("place", "the main chat window sits in the panel through Edit Mode's SetPointBase")
	else
		LogOnce("place", "the main chat window sits in the panel through SetPoint; Edit Mode's override is missing")
	end
	return true
end

local function Schedule()
	if state.placing or not state.active or state.queued then
		return
	end
	state.queued = true
	C_Timer.After(0, Panel.Place)
end

local function OnSetPoint(_, point, relative, relativePoint, x, y)
	local plain = not (IsSecret(point) or IsSecret(relative) or IsSecret(relativePoint) or IsSecret(x) or IsSecret(y))
	local anchor = plain and state.anchors and type(point) == "string" and state.anchors[point]
	if anchor and relative == state.holder and relativePoint == point and type(x) == "number" and type(y) == "number"
		and math.abs(x - anchor[1]) < 0.001 and math.abs(y - anchor[2]) < 0.001 then
		return
	end
	Schedule()
end

local function OnEditModeExit()
	if state.active then
		Schedule()
	end
end

Panel.Schedule = Schedule

local function OnLayoutChanged(_, key)
	if state.active and key == KEY then
		Schedule()
	end
end

local hovered = setmetatable({}, { __mode = "k" })

function Panel.Rest()
	local glass = state.glass
	if not glass then
		return
	end
	local settings = state.settings
	local show = state.hover == true
	glass.plus:SetShown(show)
	glass.copy:SetShown(show and settings ~= nil and settings.copyButton == true)
	SideAlpha()
	if state.bare and state.alpha ~= nil then
		SetChatAlpha(state.alpha, true)
	end
end

local function Reveal()
	state.generation = (state.generation or 0) + 1
	state.hover = true
	Panel.Rest()
	Panel.Wake()
end

local function Conceal()
	local generation = (state.generation or 0) + 1
	state.generation = generation
	C_Timer.After(0, function()
		if state.generation ~= generation then
			return
		end
		state.hover = false
		Panel.Rest()
		Panel.Wake()
	end)
end

function HookHover(frame)
	if type(frame) ~= "table" or type(frame.HookScript) ~= "function" or hovered[frame] then
		return
	end
	hovered[frame] = true
	frame:HookScript("OnEnter", Reveal)
	frame:HookScript("OnLeave", Conceal)
end

local function Shade()
	local holder = state.holder
	local w, h = holder:GetWidth(), holder:GetHeight()
	for i, lobe in ipairs(state.shade) do
		lobe:ClearAllPoints()
		Widgets.Size(lobe, SHADE_W * w, SHADE_H * h)
		Widgets.Point(lobe, "CENTER", holder, "TOPLEFT", (SHADE_X + SHADE_LOBES[i]) * w, -SHADE_Y * h)
	end
end

local function Paint(settings)
	local glass = state.glass
	local bare = Panel.Bare(settings)
	state.bare = bare
	local r, g, b = Tokens.Color("surface")
	glass.chrome:SetSteelFill(CHAT_FILL)
	glass.chrome:SetFillRGBA(r, g, b, settings.panelOpacity)
	glass.chrome:SetShadow(settings.shadow == true)
	glass.chrome:SetShown(not bare)
	local strip, own = Panel.strip, settings.buttons == true and settings.sideStyle == "glass"
	if not strip and own then
		strip = Widgets.Panel(state.holder, { strata = STRATA, shape = "window" })
		strip:SetFixedFrameStrata(true)
		strip:EnableMouse(true)
		Panel.strip = strip
	end
	if strip then
		strip.chrome:SetSteelFill(CHAT_FILL)
		strip.chrome:SetFillRGBA(r, g, b, settings.panelOpacity)
		strip.chrome:SetShadow(settings.shadow == true)
		strip:SetShown(own and not bare)
	end
	SyncHeader()
	local shade = state.shade
	Shade()
	Widgets.ColorSlice(shade, Widgets.Rgba("black", SHADE_ALPHA * (state.factor or 1)))
	Widgets.ShowSlice(shade, bare)
	glass.copy:Paint()
	glass.plus:Paint()
	Panel.Rest()
	if state.alpha ~= nil then
		SetChatAlpha(state.alpha, true)
	end
end

local function FollowTab(tab, alpha)
	alpha = Widgets.Readability("chatTabs") and type(tab.GetAlpha) == "function" and tab:GetAlpha() or alpha
	local glass = state.glass
	if state.active and glass then
		glass.copy:SetAlpha(Number(alpha, 1))
		glass.plus:SetAlpha(Number(alpha, 1))
	end
end

local function OnSettings()
	K.Options.Open(ns.NAME)
end

local function OnCopy()
	ns.Copy.Open()
end

local function PaintGlyphButton(self)
	local r, g, b = Tokens.Color("text")
	if self:IsEnabled() == false then
		r, g, b = Tokens.Color("textDisabled")
	elseif state.settings then
		r, g, b = ns.Accent(state.settings)
	end
	local t = self.hoverT or 0
	r, g, b = r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
	for _, region in ipairs(self.tinted) do
		region:SetVertexColor(r, g, b, 1)
	end
	if Widgets.MayMove(self) then
		local offset = Widgets.PressOffset(self)
		if self.placedOffset ~= offset then
			self.placedOffset = offset
			self.art:SetPoint("CENTER", self, "CENTER", 0, -offset)
		end
	end
end

local function RestyleGlyphButton(self)
	if Widgets.MayMove(self) then
		Widgets.Size(self, BUTTON_SIZE, BUTTON_SIZE)
		Widgets.Size(self.art, BUTTON_GLYPH, BUTTON_GLYPH)
		self.placedOffset = nil
		if self.Shape then
			self:Shape()
		end
	end
	self:Paint()
end

local function GlyphButton(glass, onClick, tooltip)
	local button = CreateFrame("Button", nil, glass:GetParent())
	button:SetFrameLevel(glass:GetFrameLevel() + 1)
	button.art = CreateFrame("Frame", nil, button)
	button.tinted = {}
	button.onClick = onClick
	button.Paint, button.Restyle = PaintGlyphButton, RestyleGlyphButton
	Widgets.HookPointer(button)
	Widgets.AttachTooltip(button, tooltip)
	return button
end

local function PlusButton(glass)
	local button = GlyphButton(glass, OnSettings, K.L["Chat settings"])
	local glyph = button.art:CreateTexture(nil, "ARTWORK")
	glyph:SetTexture((Tokens.Texture("glyphClose")))
	glyph:SetAllPoints(button.art)
	glyph:SetRotation(math.pi / 4)
	button.glyph = glyph
	button.tinted[1] = glyph
	button:Restyle()
	return Widgets.Track(button)
end

local function Square(button, level, filled)
	local square = CreateFrame("Frame", nil, button.art)
	square:SetFrameLevel(button.art:GetFrameLevel() + level)
	if filled then
		square.fill = square:CreateTexture(nil, "BACKGROUND")
		square.fill:SetColorTexture(Tokens.Color("surface"))
		square.fill:SetAllPoints(square)
	end
	square.lines = {}
	for i = 1, 4 do
		local line = square:CreateTexture(nil, "ARTWORK")
		line:SetColorTexture(Tokens.Color("white"))
		square.lines[i] = line
		button.tinted[#button.tinted + 1] = line
	end
	return square
end

local function ShapeSquare(square, size, border)
	local top, bottom, left, right = square.lines[1], square.lines[2], square.lines[3], square.lines[4]
	square:SetSize(size, size)
	if square.fill then
		square.fill:SetVertexColor(Tokens.Color("surface"))
		square.fill:SetAlpha(1)
	end
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", square, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", square, "TOPRIGHT", 0, 0)
	top:SetHeight(border)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", square, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", square, "BOTTOMRIGHT", 0, 0)
	bottom:SetHeight(border)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", square, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", square, "BOTTOMLEFT", 0, 0)
	left:SetWidth(border)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", square, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", square, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(border)
end

local function ShapeCopy(self)
	local size, border = Widgets.Snap(self.art, COPY_SQUARE), Widgets.Border(self.art)
	ShapeSquare(self.back, size, border)
	ShapeSquare(self.front, size, border)
	self.back:ClearAllPoints()
	self.back:SetPoint("TOPLEFT", self.art, "TOPLEFT", 0, 0)
	self.front:ClearAllPoints()
	self.front:SetPoint("BOTTOMRIGHT", self.art, "BOTTOMRIGHT", 0, 0)
end

local function CopyButton(glass)
	local button = GlyphButton(glass, OnCopy, K.L["Copy the selected chat window's text."])
	button.back = Square(button, 1, false)
	button.front = Square(button, 2, true)
	button.Shape = ShapeCopy
	button:Restyle()
	return Widgets.Track(button)
end

local function Footprint(layouts)
	local Layout = K.Layout
	local preset = Layout and type(Layout.Setting) == "function" and Layout.Setting("preset")
	if type(preset) ~= "string" or not layouts.Get(preset) then
		preset = "DPS"
	end
	return layouts.Footprint(preset, KEY)
end

local function Build()
	local layouts = K.Setup.Layouts
	local spec = layouts.Element(KEY)
	local holder = CreateFrame("Frame", nil, Scale.Root())
	holder:SetFrameStrata(STRATA)
	Widgets.Size(holder, Footprint(layouts))
	local glass = Widgets.Panel(holder, { strata = STRATA, shape = "window" })
	glass:SetAllPoints(holder)
	state.near, state.far, state.top = 0, 0, 0
	glass:SetFixedFrameStrata(true)
	glass.divider = glass:CreateTexture(nil, "ARTWORK")
	glass.divider:SetColorTexture(Tokens.Color("white"))
	state.shade = {}
	for i = 1, #SHADE_LOBES do
		local lobe = holder:CreateTexture(nil, "BACKGROUND")
		lobe:SetTexture((Tokens.Texture("glow")))
		lobe:Hide()
		state.shade[i] = lobe
	end
	glass.plus = PlusButton(glass)
	glass.copy = CopyButton(glass)
	glass.dockEnd = CreateFrame("Frame", nil, glass)
	for _, method in ipairs({ "Show", "Hide", "SetShown", "SetAlpha" }) do
		hooksecurefunc(holder, method, Mirror)
	end
	state.holder, state.glass = holder, glass
	if type(holder.EnableMouse) == "function" then
		holder:EnableMouse(true)
	end
	HookHover(holder)
	holder:HookScript("OnSizeChanged", Shade)
	HookHover(glass)
	HookHover(glass.plus)
	HookHover(glass.copy)
	Widgets.Place(holder, KEY, layouts.Default(KEY), {
		label = spec.label,
		module = ns.NAME,
		resizable = true,
		minWidth = MIN_WIDTH,
		minHeight = MIN_HEIGHT,
		maxWidth = MAX_WIDTH,
		maxHeight = MAX_HEIGHT,
	})
	return holder
end

local function Reflow()
	if state.settings and state.settings.buttons then
		Schedule()
	end
end

local function Watch(chat)
	if state.hooked or type(chat.SetPoint) ~= "function" then
		return
	end
	state.hooked = true
	hooksecurefunc(chat, "SetPoint", OnSetPoint)
	chat:HookScript("OnSizeChanged", Schedule)
	state.holder:HookScript("OnSizeChanged", Schedule)
	if type(FCFDock_SetPrimary) == "function" then
		hooksecurefunc("FCFDock_SetPrimary", Schedule)
	end
	if type(FCF_UpdateScrollbarAnchors) == "function" then
		hooksecurefunc("FCF_UpdateScrollbarAnchors", function(frame)
			local saved = type(frame) == "table" and kept[frame.ScrollToBottomButton]
			if saved then
				saved.bar = nil
				Unpin(frame)
			end
		end)
	end
	if type(ChatAlertFrame) == "table" and type(ChatAlertFrame.UpdateAnchors) == "function" then
		hooksecurefunc(ChatAlertFrame, "UpdateAnchors", function()
			local spot = kept[QuickJoinToastButton] and Free(state.settings, "QuickJoinToastButton")
			if spot then Spot(QuickJoinToastButton, state.chat.buttonFrame, spot) end
		end)
	end
	for _, names in pairs(ICONS) do
		for _, name in ipairs(names) do
			local icon = _G[name]
			if type(icon) == "table" and type(icon.HookScript) == "function" then
				icon:HookScript("OnShow", Reflow)
				icon:HookScript("OnHide", Reflow)
			end
		end
	end
	if type(FCF_SavePositionAndDimensions) == "function" then
		hooksecurefunc("FCF_SavePositionAndDimensions", function(frame)
			if not state.active or frame ~= state.chat or state.placing or EditModeActive() then return end
			local root, g = Scale.Root(), Panel.Geometry(frame)
			local left, bottom, width, height = frame:GetRect()
			if IsSecret(left) or IsSecret(bottom) or IsSecret(width) or IsSecret(height) then return end
			if type(left) ~= "number" or type(bottom) ~= "number" or not Number(width, nil) or not Number(height, nil) then return end
			K.Layout.Update(KEY, {
				anchor = "BOTTOMLEFT", x = left * g.k - root:GetLeft() - g.left,
				y = bottom * g.k - root:GetBottom() - g.bottom,
				width = width * g.k + g.left + g.right, height = height * g.k + g.top + g.bottom,
			}, true)
		end)
	end
	local name = chat:GetName()
	local tab = IsText(name) and _G[name .. "Tab"] or nil
	if type(tab) == "table" and type(tab.SetAlpha) == "function" then
		hooksecurefunc(tab, "SetAlpha", FollowTab)
		FollowTab(tab, tab:GetAlpha())
	end
end

function Panel.Start(settings)
	state.active = true
	state.settings = settings
	state.alpha = nil
	local holder = state.holder or Build()
	holder:Show()
	Paint(settings)
	local chat = ChatFrame1
	if type(chat) ~= "table" or type(chat.GetEffectiveScale) ~= "function" then
		state.chat = nil
		LogOnce("missing", "ChatFrame1 is missing; the panel stays empty")
		return
	end
	state.chat = chat
	if not state.bounds and type(chat.GetResizeBounds) == "function" then
		state.bounds = { chat:GetResizeBounds() }
	end
	Watch(chat)
	HookHover(chat)
	K.Callbacks.Register(LAYOUT_CHANGED, Panel, OnLayoutChanged)
	local registry = EventRegistry
	if type(registry) == "table" and type(registry.RegisterCallback) == "function" then
		registry:RegisterCallback(EDIT_MODE_EXIT, OnEditModeExit, Panel)
		state.editMode = true
	end
	Panel.Place()
	Schedule()
	Idle()
end

local PLACE = {
	scale = true, theme = true, copyButton = true, editBox = true, fontSize = true, lineSpacing = true, framing = true, buttons = true,
	inputOnTop = true, tabHeight = true, editHeight = true, tabSpacing = true, tabFont = true, sideRight = true, sideWidth = true, sideHover = true,
	["sideIcons.friends"] = true, ["sideIcons.menu"] = true, ["sideIcons.channels"] = true, ["sideIcons.voice"] = true, sideStyle = true, sideGap = true,
	sideOrder = true, sideScale = true, sideSpacing = true, sideFree = true, sidePositions = true, sideScroll = true, tabsAbove = true,
}

function Panel.Refresh(settings, key)
	state.settings = settings
	if not state.active or not state.holder then
		return
	end
	Paint(settings)
	if key == nil or PLACE[key] then
		Schedule()
	end
	if key == nil or key == "editBox" then
		Panel.Sync()
	end
	if key == nil or key:sub(1, 4) == "idle" then
		Idle()
	end
end

function Panel.Stop()
	state.active = false
	Release()
	if state.bounds and state.chat then
		state.chat:SetResizeBounds(unpack(state.bounds))
		state.bounds = nil
	end
	local registry = EventRegistry
	if state.editMode and type(registry) == "table" and type(registry.UnregisterCallback) == "function" then
		registry:UnregisterCallback(EDIT_MODE_EXIT, Panel)
	end
	state.editMode = false
	K.Callbacks.Unregister(LAYOUT_CHANGED, Panel)
	Idle()
	SideAlpha()
	state.alpha = nil
	SetChatAlpha(1)
	RestoreDock()
	for _, frame in ipairs(Windows.List()) do
		PlaceEdit(frame, 1, false, false)
	end
	if state.holder then
		state.holder:Hide()
	end
end
