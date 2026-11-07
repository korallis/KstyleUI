-- Panel.lua: the chat's glass panel, a Layout element that holds Blizzard's main chat window, its tabs and its edit box.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Scale = K.Widgets, K.Tokens, K.Scale
local Format, Windows = ns.Format, ns.Windows
local max = math.max

local Panel = {}
ns.Panel = Panel

local KEY = "chat.main"
local STRATA = "BACKGROUND"
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 260, 120, 1000, 800
local DIVIDER_ALPHA = 0.25
local COPY_WIDTH, COPY_HEIGHT = 44, 18
local EDIT_MODE_EXIT = "EditMode.Exit"

local TAB_TEXT_RISE = 14
local BACKGROUND_RISE = 3
local EDIT_DROP = 2
local EDIT_HEIGHT = 32
local EDIT_LEFT = 5
local EDIT_PAST_SCROLLBAR = 8
local SCROLLBAR_WIDTH = 8

local TAB_TEXT_DROP = 12
local EDIT_TILE = 22
local EDIT_BOTTOM = 6

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
}
local logged = {}
local mirrored = setmetatable({}, { __mode = "k" })
local edits = setmetatable({}, { __mode = "k" })
local busy = false

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

function Panel.Column(frame, k)
	local column = ScrollWidth(frame) * k + Tokens.Size("gapSmall")
	local settings = state.settings
	if settings and settings.copyButton == true then
		column = max(column, COPY_WIDTH + Tokens.Size("gapSmall"))
	end
	return column
end

function Panel.Geometry(chat)
	local k = Ratio(chat, state.holder)
	local snap = Scale.Snap
	local pad = Tokens.Size("gapMedium")
	local tile = max(0, (EDIT_HEIGHT * k - EDIT_TILE) / 2)
	return {
		k = k,
		left = snap(pad),
		top = snap(TAB_TEXT_DROP + TAB_TEXT_RISE * k),
		right = snap(pad + Panel.Column(chat, k)),
		bottom = snap(EDIT_BOTTOM + (EDIT_DROP + EDIT_HEIGHT) * k - tile),
		divider = snap(TAB_TEXT_DROP + (TAB_TEXT_RISE - BACKGROUND_RISE) * k),
	}
end

function Panel.EditInsets(frame, docked)
	local k = Ratio(frame, state.holder)
	local vertical = max(0, (EDIT_HEIGHT - EDIT_TILE / k) / 2)
	local right = EDIT_PAST_SCROLLBAR
	if docked then
		right = ScrollWidth(frame) + EDIT_PAST_SCROLLBAR - Panel.Column(frame, k) / k
	end
	return { left = EDIT_LEFT, right = right, top = vertical, bottom = vertical }
end

function Panel.UndockedInsets(frame)
	local k = Ratio(frame, nil)
	local pad = Tokens.Size("gapMedium") / k
	return {
		left = -pad,
		right = -(ScrollWidth(frame) + pad),
		top = -(TAB_TEXT_RISE + TAB_TEXT_DROP / k),
		bottom = -(EDIT_DROP + EDIT_HEIGHT - max(0, (EDIT_HEIGHT - EDIT_TILE / k) / 2) + EDIT_BOTTOM / k),
	}
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
	local factor = 1
	if state.active and info.frame.isDocked and not Focused(box) then
		factor = state.alpha or 1
	end
	busy = true
	box:SetAlpha(info.wanted * factor)
	busy = false
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
		local function refocus(self)
			ApplyEdit(self, info)
		end
		box:HookScript("OnEditFocusGained", refocus)
		box:HookScript("OnEditFocusLost", refocus)
	end
	ApplyEdit(box, info)
end

local function SetChatAlpha(alpha)
	if state.alpha == alpha then
		return
	end
	state.alpha = alpha
	local dock = GENERAL_CHAT_DOCK
	if type(dock) == "table" and type(dock.SetAlpha) == "function" then
		dock:SetAlpha(alpha)
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

local function Mirror()
	local holder = state.holder
	if not state.active or not holder then
		return
	end
	local alpha = 0
	if holder:IsShown() then
		alpha = Number(holder:GetAlpha(), 0)
	end
	SetChatAlpha(alpha)
end

function Panel.Sync()
	state.alpha = nil
	Mirror()
end

local function PlaceDivider(g)
	local glass = state.glass
	local divider = glass.divider
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", glass, "TOPLEFT", g.left, -g.divider)
	divider:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -g.left, -g.divider)
	divider:SetHeight(Scale.Border())
	Widgets.Tint(divider, "text", DIVIDER_ALPHA)
	local copy = glass.copy
	copy:ClearAllPoints()
	copy:SetPoint("RIGHT", glass, "TOPRIGHT", -g.left, -TAB_TEXT_DROP)
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
	local clear = chat.ClearAllPointsBase or chat.ClearAllPoints
	local setPoint = chat.SetPointBase or chat.SetPoint
	state.placing = true
	clear(chat)
	setPoint(chat, "TOPLEFT", holder, "TOPLEFT", g.left / g.k, -g.top / g.k)
	setPoint(chat, "BOTTOMRIGHT", holder, "BOTTOMRIGHT", -g.right / g.k, g.bottom / g.k)
	state.placing = false
	state.waiting = false
	PlaceDivider(g)
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

local function OnEditModeExit()
	if state.active then
		Schedule()
	end
end

local function Paint(settings)
	local glass = state.glass
	local r, g, b = Tokens.Color("surface")
	glass.chrome:SetFillRGBA(r, g, b, settings.panelOpacity)
	glass.chrome:SetShadow(settings.shadow == true)
	glass.copy:SetShown(settings.copyButton == true)
end

local function FollowTab(_, alpha)
	local glass = state.glass
	if state.active and glass then
		glass.copy:SetAlpha(Number(alpha, 1))
	end
end

local function Build()
	local layouts = K.Setup.Layouts
	local spec = layouts.Element(KEY)
	local holder = CreateFrame("Frame", nil, Scale.Root())
	holder:SetFrameStrata(STRATA)
	Widgets.Size(holder, spec.width, spec.height)
	local glass = Widgets.Panel(holder, { strata = STRATA })
	glass:SetAllPoints(holder)
	glass:SetFixedFrameStrata(true)
	glass.divider = glass:CreateTexture(nil, "ARTWORK")
	glass.divider:SetTexture((Tokens.Texture("divider")))
	glass.copy = Widgets.Button(glass, {
		text = K.L["Copy"],
		width = COPY_WIDTH,
		height = COPY_HEIGHT,
		tooltip = K.L["Copy the selected chat window's text."],
		onClick = function()
			ns.Copy.Open()
		end,
	})
	for _, method in ipairs({ "Show", "Hide", "SetShown", "SetAlpha" }) do
		hooksecurefunc(holder, method, Mirror)
	end
	state.holder, state.glass = holder, glass
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

local function Watch(chat)
	if state.hooked or type(chat.SetPoint) ~= "function" then
		return
	end
	state.hooked = true
	hooksecurefunc(chat, "SetPoint", Schedule)
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
	Watch(chat)
	local registry = EventRegistry
	if type(registry) == "table" and type(registry.RegisterCallback) == "function" then
		registry:RegisterCallback(EDIT_MODE_EXIT, OnEditModeExit, Panel)
		state.editMode = true
	end
	Panel.Place()
	Mirror()
end

function Panel.Refresh(settings, key)
	state.settings = settings
	if not state.active or not state.holder then
		return
	end
	Paint(settings)
	if key == nil or key == "scale" or key == "copyButton" then
		Schedule()
	end
end

function Panel.Stop()
	state.active = false
	local registry = EventRegistry
	if state.editMode and type(registry) == "table" and type(registry.UnregisterCallback) == "function" then
		registry:UnregisterCallback(EDIT_MODE_EXIT, Panel)
	end
	state.editMode = false
	SetChatAlpha(1)
	if state.holder then
		state.holder:Hide()
	end
end
