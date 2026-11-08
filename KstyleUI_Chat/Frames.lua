-- Frames.lua: restyles Blizzard's chat windows in place: their art, tabs, edit boxes, scroll bars, fonts and buttons.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Skin, Safe = K.Widgets, K.Tokens, K.Skin, K.Safe
local Format, Windows, Panel = ns.Format, ns.Windows, ns.Panel
local floor, max, min = math.floor, math.max, math.min

local Frames = {}
ns.Frames = Frames

local OUTLINES = { none = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local EDIT_TEXTS = { "header", "headerSuffix", "languageHeader", "prompt", "NewcomerHint" }
local TAB_FILL_INSET = { left = 4, right = 4, top = 9, bottom = 1 }
local UNDERLINE_UNITS = 1
local UNDERLINE_GLOW_UNITS = 5
local UNDERLINE_GLOW_ALPHA = 0.25
local CHEVRON = 8
local PROBE_SIZE = 12
local FADE_DEFAULT = 120

local IsSecret = Format.IsSecret

local state = {
	active = false,
	settings = nil,
	watching = false,
	hooked = false,
	probe = nil,
	checked = nil,
	path = nil,
}
local styled = setmetatable({}, { __mode = "k" })
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

local function Whole(v, low, high, fallback)
	if IsSecret(v) or type(v) ~= "number" or v ~= v then
		return fallback
	end
	return min(high, max(low, floor(v + 0.5)))
end

local function Verify(path)
	if not IsText(path) or path == "" then
		return false
	end
	local probe = state.probe
	if not probe then
		local holder = CreateFrame("Frame")
		holder:Hide()
		probe = Widgets.FontString(holder, "ARTWORK")
		state.probe = probe
	end
	local ok, loaded = pcall(probe.SetFont, probe, path, PROBE_SIZE, "")
	return ok and loaded ~= false
end

local function FontPath(settings)
	local path = settings.font
	if path ~= state.checked then
		state.checked = path
		if Verify(path) then
			state.path = path
		else
			state.path = (Tokens.Font("body"))
			LogOnce("font:" .. tostring(path), "the chat font " .. tostring(path) .. " did not load; chat uses KstyleUI's body font")
		end
	end
	return state.path
end

function Frames.Fonts(settings)
	local s = settings or state.settings
	local path = FontPath(s)
	local flags = OUTLINES[s.fontOutline] or ""
	local size = Whole(s.fontSize, ns.FONT_MIN, ns.FONT_MAX, ns.defaults.fontSize)
	local tabSize = Whole(s.tabFontSize, ns.FONT_MIN, ns.FONT_MAX, ns.defaults.tabFontSize)
	return path, size, flags, tabSize
end

function Frames.ApplyFont(object, path, size, flags)
	if type(object) ~= "table" or type(object.SetFont) ~= "function" then
		return
	end
	object:SetFont(path, size, flags)
	if flags == "" then
		object:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		object:SetShadowOffset(offset, -offset)
	else
		object:SetShadowOffset(0, 0)
	end
end

local function TabOf(frame)
	local name = frame:GetName()
	if not IsText(name) then
		return nil
	end
	local tab = _G[name .. "Tab"]
	if type(tab) == "table" then
		return tab
	end
	return nil
end

local function TabText(tab)
	if type(tab.Text) == "table" then
		return tab.Text
	end
	if type(tab.GetFontString) == "function" then
		return tab:GetFontString()
	end
	return nil
end

local function IsSelected(frame)
	if not frame.isDocked then
		return true
	end
	local dock = GENERAL_CHAT_DOCK
	if type(FCFDock_GetSelectedWindow) == "function" and type(dock) == "table" then
		return FCFDock_GetSelectedWindow(dock) == frame
	end
	return frame == ChatFrame1
end

local function Accent()
	local r, g, b = ns.Accent(state.settings)
	return r, g, b, 1
end

local function PaintGlow(glow, r, g, b)
	if type(glow.SetGradient) == "function" and type(CreateColor) == "function" then
		glow:SetColorTexture(Tokens.Color("white"))
		glow:SetGradient("VERTICAL", CreateColor(r, g, b, UNDERLINE_GLOW_ALPHA), CreateColor(r, g, b, 0))
	else
		glow:SetColorTexture(r, g, b, UNDERLINE_GLOW_ALPHA / 2)
	end
end

local function PaintTab(parts)
	local settings = state.settings
	if not settings or not parts.underline then
		return
	end
	local style = settings.tabStyle
	local selected = parts.selected == true
	local r, g, b = Accent()
	local underlined = selected and style == "underline"
	parts.underline:SetVertexColor(r, g, b, 1)
	parts.underline:SetShown(underlined)
	if parts.chatGlow then
		PaintGlow(parts.chatGlow, r, g, b)
		parts.chatGlow:SetShown(underlined)
	end
	local fill = parts.backdrop
	if not fill and style == "filled" then
		fill = Skin.Backdrop(parts.frame, { shape = "tile", fill = "buttonFill", shadow = false, inset = TAB_FILL_INSET })
	end
	if fill then
		fill:SetShown(selected and style == "filled")
		if fill.chrome then
			fill.chrome:SetEdgeRGBA(Accent())
		end
	end
end

local function TabCase(tab)
	local text = tab:GetText()
	if not IsText(text) or not state.settings then
		return
	end
	local side = Safe.Side(tab)
	if state.settings.tabCase == "upper" then
		local upper = text:upper()
		if upper ~= text then
			side.chatName = text
			tab:SetText(upper)
		end
	elseif side.chatName and text == side.chatName:upper() then
		tab:SetText(side.chatName)
		side.chatName = nil
	end
end

local function LayoutTab(parts)
	local line, tab, glow = parts.underline, parts.frame, parts.chatGlow
	line:ClearAllPoints()
	line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
	line:SetHeight(Widgets.Snap(line, UNDERLINE_UNITS))
	glow:ClearAllPoints()
	glow:SetPoint("BOTTOMLEFT", line, "TOPLEFT", 0, 0)
	glow:SetPoint("BOTTOMRIGHT", line, "TOPRIGHT", 0, 0)
	glow:SetHeight(Widgets.Snap(glow, UNDERLINE_GLOW_UNITS))
end

local function StyleTab(frame, tab)
	local keep = {}
	if type(tab.glow) == "table" then
		keep[tab.glow] = true
	end
	Skin.Strip(tab, { keep = keep })
	local parts = Skin.Tab(tab)
	if not parts then
		return
	end
	if not parts.chatPaint then
		local paint, layout = parts.Paint, parts.Layout
		parts.chatPaint = true
		parts.chatGlow = parts.underline:GetParent():CreateTexture(nil, "OVERLAY", nil, -1)
		parts.Paint = function(self)
			paint(self)
			PaintTab(self)
		end
		parts.Layout = function(self)
			layout(self)
			LayoutTab(self)
		end
		LayoutTab(parts)
	end
	parts.selected = IsSelected(frame)
end

local function PaintEditFocus(box)
	local parts = Skin.Parts(box)
	local backdrop = parts and parts.backdrop
	if state.settings and backdrop and backdrop.chrome then
		backdrop.chrome:SetEdgeRGBA(Accent())
	end
end

local function StyleEdit(frame)
	local box = frame.editBox
	if type(box) ~= "table" or type(box.HookScript) ~= "function" then
		return
	end
	if Skin.EditBox(box, { inset = Panel.EditInsets(frame, frame.isDocked ~= nil) }) then
		box:HookScript("OnEditFocusGained", PaintEditFocus)
	end
end

local function StyleBottomButton(button)
	if type(button) ~= "table" or type(button.GetRegions) ~= "function" then
		return
	end
	local keep = {}
	if type(button.Flash) == "table" then
		keep[button.Flash] = true
	end
	Skin.Strip(button, { keep = keep, watch = false })
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints(button)
	local glyph = overlay:CreateTexture(nil, "OVERLAY")
	glyph:SetTexture((Tokens.Texture("glyphChevron")))
	glyph:SetPoint("CENTER", overlay, "CENTER")
	Widgets.Size(glyph, CHEVRON, CHEVRON)
	Widgets.Tint(glyph, "text")
end

local function Backdrop(frame)
	local parts = Skin.Parts(frame)
	local backdrop = parts and parts.backdrop
	if frame.isDocked then
		if backdrop then
			backdrop:Hide()
		end
		return
	end
	if not backdrop then
		backdrop = Skin.Backdrop(frame, { inset = Panel.UndockedInsets(frame) })
		if not backdrop then
			return
		end
	end
	backdrop.inset = Panel.UndockedInsets(frame)
	backdrop:Restyle()
	backdrop:Show()
	local s = state.settings
	local r, g, b = Tokens.Color("surface")
	backdrop.chrome:SetFillRGBA(r, g, b, s.panelOpacity)
	backdrop.chrome:SetShadow(s.shadow == true)
end

local function ApplyFrame(frame)
	local s = state.settings
	local path, size, flags, tabSize = Frames.Fonts()
	Frames.ApplyFont(frame, path, size, flags)
	if type(frame.SetFading) == "function" then
		frame:SetFading(s.fade == true)
	end
	if type(frame.SetSpacing) == "function" then
		frame:SetSpacing(Whole(s.lineSpacing, ns.SPACING_MIN, ns.SPACING_MAX, ns.defaults.lineSpacing))
	end
	if s.fade == true and type(frame.SetTimeVisible) == "function" then
		frame:SetTimeVisible(Whole(s.fadeTime, 1, math.huge, FADE_DEFAULT))
	end
	local box = frame.editBox
	if type(box) == "table" then
		Frames.ApplyFont(box, path, size, flags)
		for _, key in ipairs(EDIT_TEXTS) do
			local text = box[key]
			if type(text) == "table" and type(text.GetObjectType) == "function" and text:GetObjectType() == "FontString" then
				Frames.ApplyFont(text, path, size, flags)
			end
		end
		local parts = Skin.Parts(box)
		if parts and parts.backdrop then
			parts.backdrop.inset = Panel.EditInsets(frame, frame.isDocked ~= nil)
			parts.backdrop:Restyle()
		end
	end
	local tab = TabOf(frame)
	if tab then
		TabCase(tab)
		Frames.ApplyFont(TabText(tab), path, tabSize, flags)
		local parts = Skin.Parts(tab)
		if parts and parts.chatPaint then
			parts:Paint()
		end
	end
	Backdrop(frame)
end

local function Style(frame)
	if styled[frame] then
		return
	end
	styled[frame] = true
	Skin.Strip(frame, { watch = false })
	if type(frame.buttonFrame) == "table" then
		Skin.Strip(frame.buttonFrame, { watch = false })
	end
	if type(frame.ScrollBar) == "table" and type(frame.ScrollBar.GetRegions) == "function" then
		Skin.ScrollBar(frame.ScrollBar)
	end
	StyleBottomButton(frame.ScrollToBottomButton)
	StyleEdit(frame)
	local tab = TabOf(frame)
	if tab then
		StyleTab(frame, tab)
	end
	if state.active then
		ApplyFrame(frame)
		Panel.Sync()
	end
end

local function ApplyAll()
	if not state.active then
		return
	end
	for _, frame in ipairs(Windows.List()) do
		if styled[frame] then
			ApplyFrame(frame)
		end
	end
end

local function Buttons()
	local chat = ChatFrame1
	local column = type(chat) == "table" and chat.buttonFrame or nil
	if type(column) ~= "table" then
		return
	end
	if state.active and state.settings.buttons ~= true then
		Safe.HideBlizzard(column)
	else
		Safe.RestoreBlizzard(column)
	end
end

local function OnTabColors(tab, selected)
	local parts = Skin.Parts(tab)
	if parts and parts.chatPaint then
		parts.selected = selected and true or false
		parts:Paint()
	end
end

local function OnWindowName(frame)
	if type(frame) ~= "table" or not styled[frame] then
		return
	end
	local tab = TabOf(frame)
	if tab then
		Safe.Side(tab).chatName = nil
		TabCase(tab)
	end
end

local function OnDocking(frame)
	if state.active and type(frame) == "table" and styled[frame] then
		ApplyFrame(frame)
		Panel.Sync()
	end
end

local function OnFontSize(button, _, size)
	if not state.active then
		return
	end
	if size == nil and type(button) == "table" then
		size = button.value
	end
	size = Whole(size, ns.FONT_MIN, ns.FONT_MAX, nil)
	if size == nil then
		return
	end
	if size ~= state.settings.fontSize then
		K.Options.Write(ns.NAME, "fontSize", size)
	else
		ApplyAll()
	end
end

local HOOKS = {
	{ "FCFTab_UpdateColors", OnTabColors, "the selected tab keeps the game's look until it is clicked" },
	{ "FCF_SetWindowName", OnWindowName, "renamed tabs keep the case the player typed" },
	{ "FCF_DockFrame", OnDocking, "docking a window does not update its glass" },
	{ "FCF_UnDockFrame", OnDocking, "undocking a window does not update its glass" },
	{ "FCF_SetChatWindowFontSize", OnFontSize, "a size picked from the tab menu lasts until the next reload" },
}

local function Hook()
	if state.hooked then
		return
	end
	state.hooked = true
	for _, hook in ipairs(HOOKS) do
		if type(_G[hook[1]]) == "function" then
			hooksecurefunc(hook[1], hook[2])
		else
			Log(hook[1] .. " is missing; " .. hook[3])
		end
	end
end

local function OnChatWindows()
	C_Timer.After(0, function()
		Windows.Scan()
		ApplyAll()
	end)
end

function Frames.Start(settings)
	state.active = true
	state.settings = settings
	Hook()
	if not state.watching then
		state.watching = true
		Windows.Watch(Style)
	end
	ApplyAll()
	Buttons()
	K.Events.Register(ns.NAME, "UPDATE_CHAT_WINDOWS", OnChatWindows)
end

function Frames.Refresh(settings)
	state.settings = settings
	ApplyAll()
	Buttons()
end

function Frames.Stop()
	state.active = false
	Buttons()
end
