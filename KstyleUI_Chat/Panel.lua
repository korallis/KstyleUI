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
local BUTTON_SIZE, BUTTON_GLYPH, BUTTON_INSET = 20, 8, 22
local COPY_SQUARE = 5.5
local DOCK_SIDE = 2
local EDIT_MODE_EXIT = "EditMode.Exit"
local LAYOUT_CHANGED = "LayoutChanged"

local TAB_TEXT_RISE = 14
local BACKGROUND_RISE = 3
local EDIT_DROP = 2
local EDIT_HEIGHT = 32
local EDIT_LEFT = 5
local EDIT_PAST_SCROLLBAR = 8
local SCROLLBAR_WIDTH = 8

local STRIP_HEIGHT = 32
local PAD = 16
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
	local centre = BUTTON_INSET
	local settings = state.settings
	if settings and settings.copyButton == true then
		centre = centre + BUTTON_SIZE + Tokens.Size("gapTiny")
	end
	return max(column, centre + BUTTON_SIZE / 2 + DOCK_SIDE * k - PAD)
end

local function EditAlways()
	local settings = state.settings
	return settings ~= nil and settings.editBox == "always"
end

local function PanelBottom()
	local _, bottom = K.Layout.Rect(KEY)
	return Number(bottom, 0)
end

function Panel.Geometry(chat)
	local k = Ratio(chat, state.holder)
	local snap = Scale.Snap
	local tile = max(0, (EDIT_HEIGHT * k - EDIT_TILE) / 2)
	local reach = (EDIT_DROP + EDIT_HEIGHT) * k - tile
	local bottom
	if EditAlways() then
		bottom = EDIT_BOTTOM + reach
	else
		bottom = max(PAD, reach + Tokens.Size("gapTiny") - PanelBottom())
	end
	return {
		k = k,
		left = snap(PAD),
		top = snap(STRIP_HEIGHT + BACKGROUND_RISE * k),
		right = snap(PAD + Panel.Column(chat, k)),
		bottom = snap(bottom),
		divider = snap(STRIP_HEIGHT),
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
	local pad = PAD / k
	local bottom = -pad
	if EditAlways() then
		bottom = -(EDIT_DROP + EDIT_HEIGHT - max(0, (EDIT_HEIGHT - EDIT_TILE / k) / 2) + EDIT_BOTTOM / k)
	end
	return {
		left = -pad,
		right = -(ScrollWidth(frame) + pad),
		top = -(BACKGROUND_RISE + STRIP_HEIGHT / k),
		bottom = bottom,
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

function Panel.MenuButton()
	return state.glass and state.glass.plus
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
	local y = -(g.top - TAB_TEXT_RISE * g.k)
	glass.plus:ClearAllPoints()
	glass.plus:SetPoint("CENTER", glass, "TOPRIGHT", -BUTTON_INSET, y)
	glass.copy:ClearAllPoints()
	glass.copy:SetPoint("CENTER", glass, "TOPRIGHT", -(BUTTON_INSET + BUTTON_SIZE + Tokens.Size("gapTiny")), y)
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

local function OnLayoutChanged(_, key)
	if state.active and key == KEY then
		Schedule()
	end
end

local function Paint(settings)
	local glass = state.glass
	local r, g, b = Tokens.Color("surface")
	glass.chrome:SetFillRGBA(r, g, b, settings.panelOpacity)
	glass.chrome:SetShadow(settings.shadow == true)
	glass.copy:SetShown(settings.copyButton == true)
	glass.copy:Paint()
	glass.plus:Paint()
end

local function FollowTab(_, alpha)
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
	local button = CreateFrame("Button", nil, glass)
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
	glass.plus = PlusButton(glass)
	glass.copy = CopyButton(glass)
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
	K.Callbacks.Register(LAYOUT_CHANGED, Panel, OnLayoutChanged)
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
	if key == nil or key == "scale" or key == "copyButton" or key == "editBox" then
		Schedule()
	end
	if key == nil or key == "editBox" then
		Panel.Sync()
	end
end

function Panel.Stop()
	state.active = false
	local registry = EventRegistry
	if state.editMode and type(registry) == "table" and type(registry.UnregisterCallback) == "function" then
		registry:UnregisterCallback(EDIT_MODE_EXIT, Panel)
	end
	state.editMode = false
	K.Callbacks.Unregister(LAYOUT_CHANGED, Panel)
	state.alpha = nil
	SetChatAlpha(1)
	if state.holder then
		state.holder:Hide()
	end
end
