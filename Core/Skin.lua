-- Skin.lua: shared helpers that restyle Blizzard frames in place without tainting them.
local _, ns = ...

local Skin = {}
ns.Skin = Skin

local Tokens = ns.Tokens
local max = math.max

local CLOSE_GLYPH = 10
local CHEVRON_SIZE = 8
local UNDERLINE_UNITS = 2
local TRACK_UNITS = 2
local THUMB_UNITS = 4
local THUMB_ALPHA = 0.45
local CHECK_BOX = 16
local CHECK_MARK = 8
local LEVEL_ABOVE = 2

local WEAK = { __mode = "k" }
local hushed = setmetatable({}, WEAK)
local kept = setmetatable({}, WEAK)
local watched = setmetatable({}, WEAK)
local busy = false
local panelHooks = false

local WINDOW_ART = { "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "TitleContainer", "Inset", "Inset.NineSlice", "Inset.Bg" }
local SCROLL_ART = { "Background", "Track", "Track.Thumb", "Thumb", "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }

local function Log(message)
	ns.DevTest.Log("Skin", message)
end

local function W()
	return ns.Widgets
end

local function Usable(frame, name)
	if frame == nil then
		Log(name .. ": frame missing on this client; skipped")
		return false
	end
	if type(frame) ~= "table" then
		Log(name .. ": expected a frame, got a " .. type(frame))
		return false
	end
	if frame.IsForbidden and frame:IsForbidden() == true then
		Log(name .. ": the frame is forbidden; skipped")
		return false
	end
	return true
end

local function Locked(frame)
	if not InCombatLockdown() then
		return false
	end
	if type(frame.IsProtected) ~= "function" then
		return false
	end
	local protected = frame:IsProtected()
	if issecretvalue and issecretvalue(protected) then
		return true
	end
	return protected == true
end

local function Guard(name, fn)
	return function(frame, ...)
		if not Usable(frame, name) then
			return nil
		end
		if Locked(frame) then
			local n, args = select("#", ...), { ... }
			ns.Combat.Queue(function()
				fn(frame, unpack(args, 1, n))
			end)
			Log(name .. " waits for combat to end")
			return nil
		end
		return fn(frame, ...)
	end
end

local function Parts(frame)
	local side = ns.Safe.Side(frame)
	local parts = side.skin
	if not parts then
		parts = { frame = frame, kinds = {} }
		side.skin = parts
	end
	return parts
end

local function Track(parts)
	if not parts.tracked then
		parts.tracked = true
		W().Track(parts)
	end
end

local function Restyle(parts)
	if parts.Layout then
		parts:Layout()
	end
	if parts.Paint then
		parts:Paint()
	end
end

local function Rehush(texture)
	if busy then
		return
	end
	busy = true
	pcall(texture.SetAlpha, texture, 0)
	busy = false
end

local function Hush(texture)
	if hushed[texture] then
		return false
	end
	hushed[texture] = true
	texture:SetAlpha(0)
	hooksecurefunc(texture, "SetAlpha", Rehush)
	return true
end

local function IsTexture(region)
	return type(region) == "table" and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

local function StripOwn(frame)
	local keep = kept[frame]
	local count = 0
	for _, region in ipairs({ frame:GetRegions() }) do
		if IsTexture(region) and not (keep and keep[region]) and Hush(region) then
			count = count + 1
		end
	end
	return count
end

local function Resolve(frame, path)
	local node = frame
	for key in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

local StripFrame

local function StripAny(target)
	if IsTexture(target) then
		return Hush(target) and 1 or 0
	end
	if type(target) == "table" and type(target.GetRegions) == "function" then
		return StripFrame(target)
	end
	return 0
end

function StripFrame(frame, opts)
	opts = opts or {}
	if opts.keep then
		local keep = kept[frame] or {}
		for region in pairs(opts.keep) do
			keep[region] = true
		end
		kept[frame] = keep
	end
	local count = StripOwn(frame)
	if opts.watch ~= false and not watched[frame] then
		watched[frame] = true
		frame:HookScript("OnShow", StripOwn)
	end
	for _, child in ipairs(opts.children or {}) do
		local target = child
		if type(child) == "string" then
			target = Resolve(frame, child)
		end
		count = count + StripAny(target)
	end
	return count
end

local function Mark(frame, kind)
	Parts(frame).kinds[kind] = true
end

local function Overlay(frame)
	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints(frame)
	overlay:SetFrameLevel(frame:GetFrameLevel() + LEVEL_ABOVE)
	return overlay
end

local function OnEnter(frame)
	local parts = Parts(frame)
	W().Hover(parts, true)
end

local function OnLeave(frame)
	local parts = Parts(frame)
	W().Hover(parts, false)
end

local function OnState(frame)
	local parts = Parts(frame)
	if parts.Paint then
		parts:Paint()
	end
end

local function HookPointer(frame, parts)
	if parts.pointer then
		return
	end
	parts.pointer = true
	frame:HookScript("OnEnter", OnEnter)
	frame:HookScript("OnLeave", OnLeave)
	if type(frame.IsEnabled) == "function" then
		frame:HookScript("OnEnable", OnState)
		frame:HookScript("OnDisable", OnState)
	end
end

local function Enabled(frame)
	return type(frame.IsEnabled) ~= "function" or frame:IsEnabled() ~= false
end

local function Insets(frame, inset)
	local Widgets = W()
	if type(inset) == "table" then
		return Widgets.Snap(frame, inset.left or 0), Widgets.Snap(frame, inset.right or 0), Widgets.Snap(frame, inset.top or 0), Widgets.Snap(frame, inset.bottom or 0)
	end
	local v = Widgets.Snap(frame, inset or 0)
	return v, v, v, v
end

local function PlaceBackdrop(panel)
	local frame = panel.target or panel:GetParent()
	local left, right, top, bottom = Insets(panel, panel.inset)
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
	panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, bottom)
end

local function Backdrop(frame, opts)
	opts = opts or {}
	local parts = Parts(frame)
	if parts.backdrop then
		return parts.backdrop
	end
	local panel = CreateFrame("Frame", nil, frame)
	panel:SetFrameLevel(max(0, frame:GetFrameLevel() - 1))
	panel.inset, panel.target = opts.inset, opts.target
	panel.Restyle = PlaceBackdrop
	PlaceBackdrop(panel)
	if opts.icon then
		panel.chrome = W().IconChrome(panel, {})
	else
		panel.chrome = W().Chrome(panel, { shape = opts.shape or "panel", fill = opts.fill or "surface", shadow = opts.shadow, edge = opts.edge })
	end
	W().Track(panel)
	parts.backdrop = panel
	Mark(frame, "Backdrop")
	return panel
end

local function PaintClose(parts)
	local Widgets = W()
	if not Enabled(parts.frame) then
		Widgets.Tint(parts.glyph, "textDisabled")
	else
		parts.glyph:SetVertexColor(Widgets.MixTokens("text", 1, "textHover", 1, parts.hoverT or 0))
	end
end

local function LayoutClose(parts)
	W().Size(parts.glyph, CLOSE_GLYPH, CLOSE_GLYPH)
end

local function CloseButton(button)
	local parts = Parts(button)
	if parts.glyph then
		return parts.glyph
	end
	StripFrame(button)
	local overlay = Overlay(button)
	local glyph = overlay:CreateTexture(nil, "OVERLAY")
	glyph:SetTexture((Tokens.Texture("glyphClose")))
	glyph:SetPoint("CENTER", overlay, "CENTER")
	parts.glyph = glyph
	parts.Paint, parts.Layout, parts.Restyle = PaintClose, LayoutClose, Restyle
	HookPointer(button, parts)
	Restyle(parts)
	Track(parts)
	Mark(button, "CloseButton")
	return glyph
end

local function PaintTab(parts)
	local Widgets = W()
	local tab, text = parts.frame, parts.text
	parts.underline:SetShown(parts.selected == true)
	Widgets.Tint(parts.underline, "accent")
	if not text then
		return
	end
	if tab.isDisabled then
		Widgets.TextColor(text, "textDisabled")
	elseif parts.selected then
		text:SetTextColor(Widgets.MixTokens("textEmphasis", 1, "textHover", 1, parts.hoverT or 0))
	else
		text:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, parts.hoverT or 0))
	end
end

local function LayoutTab(parts)
	local Widgets = W()
	local line, tab = parts.underline, parts.frame
	local inset = Widgets.Snap(line, Tokens.Size("gapMedium"))
	line:ClearAllPoints()
	line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", inset, 0)
	line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -inset, 0)
	line:SetHeight(Widgets.Snap(line, UNDERLINE_UNITS))
end

local function HookPanelTemplates()
	if panelHooks then
		return
	end
	panelHooks = true
	local states = { PanelTemplates_SelectTab = true, PanelTemplates_DeselectTab = false, PanelTemplates_SetDisabledTabState = false }
	for name, selected in pairs(states) do
		if type(_G[name]) == "function" then
			hooksecurefunc(name, function(tab)
				local parts = type(tab) == "table" and ns.Safe.Side(tab).skin
				if parts and parts.kinds.Tab then
					parts.selected = selected
					parts:Paint()
				end
			end)
		else
			Log(name .. " is missing; skinned tabs cannot follow it")
		end
	end
end

local function Tab(tab)
	local parts = Parts(tab)
	if parts.kinds.Tab then
		return parts
	end
	StripFrame(tab)
	local overlay = Overlay(tab)
	parts.underline = overlay:CreateTexture(nil, "OVERLAY")
	parts.underline:SetTexture((Tokens.Texture("divider")))
	parts.text = tab.Text or (type(tab.GetFontString) == "function" and tab:GetFontString()) or nil
	parts.Paint, parts.Layout, parts.Restyle = PaintTab, LayoutTab, Restyle
	parts.kinds.Tab = true
	if type(tab.SetTabSelected) == "function" then
		parts.selected = tab.isSelected == true
		hooksecurefunc(tab, "SetTabSelected", function(_, selected)
			parts.selected = selected and true or false
			parts:Paint()
		end)
	else
		HookPanelTemplates()
		parts.selected = not Enabled(tab) and not tab.isDisabled
	end
	HookPointer(tab, parts)
	Restyle(parts)
	Track(parts)
	return parts
end

local function Tabs(frame)
	local list = {}
	if type(frame.Tabs) == "table" then
		for i, tab in ipairs(frame.Tabs) do
			list[i] = tab
		end
	elseif type(frame.numTabs) == "number" and type(frame.GetName) == "function" and frame:GetName() then
		for i = 1, frame.numTabs do
			list[i] = _G[frame:GetName() .. "Tab" .. i]
		end
	end
	local skinned = {}
	for _, tab in ipairs(list) do
		if Usable(tab, "Tabs") then
			Tab(tab)
			skinned[#skinned + 1] = tab
		end
	end
	local parts = Parts(frame)
	if skinned[1] and not parts.strip then
		local strip = CreateFrame("Frame", nil, frame)
		strip:SetFrameLevel(max(0, skinned[1]:GetFrameLevel() - 1))
		strip:SetPoint("TOPLEFT", skinned[1], "TOPLEFT")
		strip:SetPoint("BOTTOMRIGHT", skinned[#skinned], "BOTTOMRIGHT")
		strip.chrome = W().Chrome(strip, { shape = "tile", fill = "buttonFill", shadow = false })
		parts.strip = strip
	end
	Mark(frame, "Tabs")
	return #list
end

local function PaintScroll(parts)
	local Widgets = W()
	if parts.track then
		Widgets.Tint(parts.track, "track")
	end
	if parts.thumb then
		parts.thumb:SetVertexColor(Widgets.MixTokens("text", THUMB_ALPHA, "accent", 1, parts.hoverT or 0))
	end
	if parts.back then
		Widgets.Tint(parts.back, "text")
	end
	if parts.forward then
		Widgets.Tint(parts.forward, "text")
	end
end

local function LayoutScroll(parts)
	local Widgets = W()
	if parts.track then
		parts.track:SetWidth(Widgets.Snap(parts.track, TRACK_UNITS))
	end
	if parts.thumb then
		parts.thumb:SetWidth(Widgets.Snap(parts.thumb, THUMB_UNITS))
	end
	if parts.back then
		Widgets.Size(parts.back, CHEVRON_SIZE, CHEVRON_SIZE)
	end
	if parts.forward then
		Widgets.Size(parts.forward, CHEVRON_SIZE, CHEVRON_SIZE)
	end
end

local function Chevron(button, up)
	local overlay = Overlay(button)
	local chevron = overlay:CreateTexture(nil, "OVERLAY")
	chevron:SetTexture((Tokens.Texture("glyphChevron")))
	chevron:SetPoint("CENTER", overlay, "CENTER")
	if up then
		chevron:SetTexCoord(0, 1, 1, 0)
	else
		chevron:SetTexCoord(0, 1, 0, 1)
	end
	return chevron
end

local function ScrollBar(bar)
	local parts = Parts(bar)
	if parts.kinds.ScrollBar then
		return parts
	end
	local thumb = bar.Thumb or (type(bar.Track) == "table" and bar.Track.Thumb) or nil
	if not thumb and type(bar.GetThumbTexture) == "function" then
		thumb = bar:GetThumbTexture()
	end
	StripFrame(bar, { children = SCROLL_ART })
	if IsTexture(thumb) then
		Hush(thumb)
	end
	local overlay = Overlay(bar)
	local rail = type(bar.Track) == "table" and type(bar.Track.GetRegions) == "function" and bar.Track or bar
	local railLayer = rail == bar and overlay or Overlay(rail)
	parts.track = railLayer:CreateTexture(nil, "ARTWORK")
	parts.track:SetColorTexture(Tokens.Color("white"))
	parts.track:SetPoint("TOP", rail, "TOP")
	parts.track:SetPoint("BOTTOM", rail, "BOTTOM")
	if thumb then
		local thumbLayer = overlay
		if type(thumb.GetRegions) == "function" then
			thumbLayer = Overlay(thumb)
		end
		parts.thumb = thumbLayer:CreateTexture(nil, "OVERLAY")
		parts.thumb:SetColorTexture(Tokens.Color("white"))
		parts.thumb:SetPoint("TOP", thumb, "TOP")
		parts.thumb:SetPoint("BOTTOM", thumb, "BOTTOM")
		if type(thumb.HookScript) == "function" then
			thumb:HookScript("OnEnter", function()
				W().Hover(parts, true)
			end)
			thumb:HookScript("OnLeave", function()
				W().Hover(parts, false)
			end)
		end
	end
	local back = bar.Back or bar.ScrollUpButton
	local forward = bar.Forward or bar.ScrollDownButton
	if type(back) == "table" and type(back.GetRegions) == "function" then
		parts.back = Chevron(back, true)
	end
	if type(forward) == "table" and type(forward.GetRegions) == "function" then
		parts.forward = Chevron(forward, false)
	end
	parts.Paint, parts.Layout, parts.Restyle = PaintScroll, LayoutScroll, Restyle
	parts.kinds.ScrollBar = true
	Restyle(parts)
	Track(parts)
	return parts
end

local function EditBox(box, opts)
	opts = opts or {}
	local parts = Parts(box)
	if parts.kinds.EditBox then
		return parts.backdrop
	end
	local keep = {}
	if IsTexture(box.searchIcon) then
		keep[box.searchIcon] = true
	end
	StripFrame(box, { keep = keep })
	local panel = Backdrop(box, { shape = "tile", fill = "buttonFill", shadow = false, inset = opts.inset })
	box:HookScript("OnEditFocusGained", function()
		panel.chrome:SetEdge("accent")
	end)
	box:HookScript("OnEditFocusLost", function()
		panel.chrome:SetEdge("edgeInner")
	end)
	parts.kinds.EditBox = true
	return panel
end

local function PaintCheck(parts)
	local Widgets = W()
	local enabled = Enabled(parts.frame)
	parts.mark:SetShown(parts.checked == true)
	Widgets.Tint(parts.mark, enabled and "accent" or "textDisabled")
	if enabled then
		parts.box.chrome:SetEdgeRGBA(Widgets.MixTokens("edgeInner", 1, "accent", 1, parts.hoverT or 0))
	else
		parts.box.chrome:SetEdge("edgeInner")
	end
end

local function LayoutCheck(parts)
	local Widgets = W()
	Widgets.Size(parts.box, CHECK_BOX, CHECK_BOX)
	Widgets.Size(parts.mark, CHECK_MARK, CHECK_MARK)
end

local function CheckBox(check)
	local parts = Parts(check)
	if parts.kinds.CheckBox then
		return parts
	end
	StripFrame(check)
	local box = CreateFrame("Frame", nil, check)
	box:SetPoint("CENTER", check, "CENTER")
	box:SetFrameLevel(check:GetFrameLevel() + LEVEL_ABOVE)
	box.chrome = W().Chrome(box, { shape = "tile", fill = "buttonFill", shadow = false })
	local mark = box:CreateTexture(nil, "OVERLAY")
	mark:SetTexture((Tokens.Texture("chamferTile")))
	mark:SetPoint("CENTER", box, "CENTER")
	parts.box, parts.mark = box, mark
	parts.Paint, parts.Layout, parts.Restyle = PaintCheck, LayoutCheck, Restyle
	parts.kinds.CheckBox = true
	local function update()
		parts.checked = check:GetChecked() and true or false
		parts:Paint()
	end
	hooksecurefunc(check, "SetChecked", update)
	check:HookScript("OnClick", update)
	check:HookScript("OnShow", update)
	HookPointer(check, parts)
	parts.checked = check:GetChecked() and true or false
	Restyle(parts)
	Track(parts)
	return parts
end

local function PaintButton(parts)
	local Widgets = W()
	local enabled = Enabled(parts.frame)
	local hover = parts.hoverT or 0
	if enabled then
		parts.backdrop.chrome:SetEdgeRGBA(Widgets.MixTokens("edgeInner", 1, "accent", 1, hover))
	else
		parts.backdrop.chrome:SetEdge("edgeInner")
	end
	local text = parts.text
	if text then
		if enabled then
			text:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
		else
			Widgets.TextColor(text, "textDisabled")
		end
	end
end

local function Button(button, opts)
	opts = opts or {}
	local parts = Parts(button)
	if parts.kinds.Button then
		return parts.backdrop
	end
	StripFrame(button)
	Backdrop(button, { shape = "tile", fill = "buttonFill", shadow = false, inset = opts.inset })
	parts.text = type(button.GetFontString) == "function" and button:GetFontString() or nil
	if parts.text and opts.font then
		W().StyleText(parts.text, opts.font)
	end
	parts.Paint, parts.Restyle = PaintButton, Restyle
	parts.kinds.Button = true
	HookPointer(button, parts)
	button:HookScript("OnShow", OnState)
	Restyle(parts)
	Track(parts)
	return parts.backdrop
end

local function Text(text, role, colorName)
	W().StyleText(text, role or "body")
	if colorName then
		W().TextColor(text, colorName)
	end
	return text
end

local function Window(frame, opts)
	opts = opts or {}
	local parts = Parts(frame)
	if parts.kinds.Window then
		return parts.backdrop
	end
	StripFrame(frame, { children = WINDOW_ART })
	local panel = Backdrop(frame, { shape = "window", fill = "surface", shadow = true, inset = opts.inset })
	if type(frame.CloseButton) == "table" then
		CloseButton(frame.CloseButton)
	end
	local title = type(frame.TitleContainer) == "table" and frame.TitleContainer.TitleText or nil
	if not title and type(frame.GetTitleText) == "function" then
		title = frame:GetTitleText()
	end
	if title and opts.title ~= false then
		Text(title, "heading", "textEmphasis")
	end
	if opts.tabs ~= false and (type(frame.Tabs) == "table" or type(frame.numTabs) == "number") then
		Tabs(frame)
	end
	parts.kinds.Window = true
	return panel
end

Skin.Strip = Guard("Strip", StripFrame)
Skin.Backdrop = Guard("Backdrop", Backdrop)
Skin.CloseButton = Guard("CloseButton", CloseButton)
Skin.Tab = Guard("Tab", Tab)
Skin.Tabs = Guard("Tabs", Tabs)
Skin.ScrollBar = Guard("ScrollBar", ScrollBar)
Skin.EditBox = Guard("EditBox", EditBox)
Skin.CheckBox = Guard("CheckBox", CheckBox)
Skin.Button = Guard("Button", Button)
Skin.Window = Guard("Window", Window)
Skin.Text = Guard("Text", Text)

function Skin.IsSkinned(frame, kind)
	if type(frame) ~= "table" then
		return false
	end
	local parts = ns.Safe.Side(frame).skin
	return parts ~= nil and parts.kinds[kind] == true
end

function Skin.Parts(frame)
	if type(frame) ~= "table" then
		return nil
	end
	return ns.Safe.Side(frame).skin
end
