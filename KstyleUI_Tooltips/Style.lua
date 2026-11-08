-- Style.lua: the glass panel, edge, accent rule and footer divider on each restyled tooltip, the tooltip fonts, line spacing and the tooltip scale.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Theme, Skin, Safe = K.Tokens, K.Widgets, K.Theme, K.Skin, K.Safe
local Logic, Settings = ns.Logic, ns.Settings
local max, min = math.max, math.min

local Style = {}
ns.Style = Style

Style.NAMES = {
	"GameTooltip",
	"ShoppingTooltip1",
	"ShoppingTooltip2",
	"ItemRefTooltip",
	"ItemRefShoppingTooltip1",
	"ItemRefShoppingTooltip2",
	"EmbeddedItemTooltip",
}

local NO_ICON = { EmbeddedItemTooltip = true }
local FONTS = { title = "GameTooltipHeaderText", body = "GameTooltipText", small = "GameTooltipTextSmall" }
local KIT_ROLES = { title = "body", body = "body", small = "caption" }
Style.KIT_ROLES = KIT_ROLES
local DIVIDER_GAP = 1
local DIVIDER_SUBLEVEL = 7
local ICON_INSET = 9.5
local TEXT_MARGIN = 10
local TEXT_GAP = 11
local LINE_SPACING = 0.5
local RULE_LENGTH = 56
local FOOTER_INSET = 13
local ICON_LEVEL = 2
local ICON_CROP = 0.07
local BORDER_LINES = 2
local SPELL_EDGE_ALPHA = 0.5
local PLAIN_EDGE_ALPHA = 0.35

local skinned = {}
local savedFonts = {}
local savedScales = setmetatable({}, { __mode = "k" })

function Style.Glass(tooltip)
	if type(tooltip) ~= "table" then
		return nil
	end
	return Safe.Side(tooltip).tooltips
end

function Style.Tooltips()
	return skinned
end

local function UseParentLevel(glass, tooltip)
	if type(glass.SetUsingParentLevel) == "function" then
		glass:SetUsingParentLevel(true)
		return
	end
	glass:SetFrameLevel(max(0, tooltip:GetFrameLevel() - 1))
	Settings.LogOnce("level", "Frame:SetUsingParentLevel is missing; the glass sits one level below each tooltip")
end

local function Pad(tooltip, glass, left)
	local right, bottom, _, top
	if type(tooltip.GetPadding) == "function" and type(tooltip.SetPadding) == "function" then
		right, bottom, _, top = tooltip:GetPadding()
	end
	if not (Logic.IsNumber(right) and Logic.IsNumber(bottom)) then
		Settings.LogOnce("padding", "a tooltip's padding was missing or secret; it shows no icon")
		return false
	end
	glass.padding = true
	tooltip:SetPadding(right, bottom, left, Logic.IsNumber(top) and top or 0)
	glass.padding = false
	glass.padded = left > 0 and left or nil
	return true
end

local function HideIcon(tooltip, glass)
	if glass.icon then
		glass.icon:Hide()
	end
	if glass.padded and not Pad(tooltip, glass, 0) then
		glass.padded = nil
	end
end

local function Repad(tooltip)
	local glass = Style.Glass(tooltip)
	if glass and glass.padded and not glass.padding and not Pad(tooltip, glass, glass.padded) then
		HideIcon(tooltip, glass)
	end
end

local function Reset(tooltip)
	local glass = Style.Glass(tooltip)
	if glass then
		glass.chrome:SetEdge("edgeInner")
		glass.divider:Hide()
		glass.footer:Hide()
		glass.caption:Hide()
		HideIcon(tooltip, glass)
	end
end
Style.Reset = Reset

local function SkinParts(tooltip)
	local header = tooltip.CompareHeader
	if type(header) == "table" then
		Skin.Strip(header)
		Skin.Backdrop(header, { shape = "tile", fill = "buttonFill", shadow = false })
		if type(header.Label) == "table" then
			Skin.Text(header.Label, "caption", "text")
		end
	end
	if type(tooltip.CloseButton) == "table" then
		Skin.CloseButton(tooltip.CloseButton)
	end
end

function Style.Skin(tooltip, name)
	local side = Safe.Side(tooltip)
	if side.tooltips then
		return side.tooltips
	end
	if type(tooltip.NineSlice) == "table" then
		Skin.Strip(tooltip.NineSlice)
	else
		Settings.Log(tostring(name) .. " has no NineSlice; its own border stays under the glass")
	end
	local glass = CreateFrame("Frame", nil, tooltip)
	UseParentLevel(glass, tooltip)
	glass:SetAllPoints(tooltip)
	glass.chrome = Widgets.Chrome(glass, { shape = "panel", fill = "surface", shadow = type(tooltip.CompareHeader) ~= "table" })
	local divider = glass:CreateTexture(nil, "BORDER", nil, DIVIDER_SUBLEVEL)
	divider:SetTexture((Tokens.Texture("divider")))
	divider:Hide()
	glass.divider = divider
	local footer = glass:CreateTexture(nil, "BORDER", nil, DIVIDER_SUBLEVEL)
	footer:SetTexture((Tokens.Texture("divider")))
	footer:Hide()
	glass.footer = footer
	glass.caption = Widgets.FontString(glass, "OVERLAY")
	glass.caption:Hide()
	glass.iconOwner = not NO_ICON[name]
	side.tooltips = glass
	skinned[#skinned + 1] = tooltip
	SkinParts(tooltip)
	for _, method in ipairs({ "SetPadding", "ClearPadding" }) do
		if glass.iconOwner and type(tooltip[method]) == "function" then
			hooksecurefunc(tooltip, method, Repad)
		end
	end
	tooltip:HookScript("OnTooltipCleared", Reset)
	tooltip:HookScript("OnHide", Reset)
	if type(tooltip.SetCustomLineSpacing) == "function" then
		tooltip:SetCustomLineSpacing(LINE_SPACING)
	else
		Settings.LogOnce("spacing", "GameTooltip:SetCustomLineSpacing is missing; lines keep Blizzard's spacing")
	end
	return glass
end

function Style.SetEdge(tooltip, r, g, b)
	local glass = Style.Glass(tooltip)
	if glass then
		glass.chrome:SetEdgeRGBA(r, g, b, 1)
	end
end

function Style.Line(tooltip, side, index)
	local getter = side == "left" and tooltip.GetLeftLine or tooltip.GetRightLine
	if type(getter) == "function" then
		return getter(tooltip, index)
	end
	local name = tooltip:GetName()
	if type(name) == "string" then
		return _G[name .. (side == "left" and "TextLeft" or "TextRight") .. index]
	end
end

function Style.NumLines(tooltip)
	if type(tooltip.NumLines) ~= "function" then
		return 0
	end
	local n = tooltip:NumLines()
	if not Logic.IsNumber(n) then
		return 0
	end
	return n
end

local palette

local function Palette()
	if palette then
		return palette
	end
	local colors = {}
	for _, pair in ipairs({ { NORMAL_FONT_COLOR, "text" }, { HIGHLIGHT_FONT_COLOR, "text" } }) do
		local color = pair[1]
		if type(color) == "table" and type(color.GetRGB) == "function" then
			local r, g, b = color:GetRGB()
			colors[#colors + 1] = { r, g, b, pair[2] }
		end
	end
	if #colors == 0 then
		Settings.LogOnce("palette", "NORMAL_FONT_COLOR and HIGHLIGHT_FONT_COLOR are missing; tooltip lines keep Blizzard's colours")
	end
	palette = colors
	return palette
end
Style.Palette = Palette

local function SoftenRegion(region, colors)
	if type(region) ~= "table" or type(region.GetTextColor) ~= "function" then
		return
	end
	local r, g, b = region:GetTextColor()
	local token = Logic.Soften(r, g, b, colors)
	if token then
		Widgets.TextColor(region, token)
	end
end

function Style.Soften(tooltip, from, colors)
	colors = colors or Palette()
	for i = from or 1, Style.NumLines(tooltip) do
		SoftenRegion(Style.Line(tooltip, "left", i), colors)
		SoftenRegion(Style.Line(tooltip, "right", i), colors)
	end
end

local function PlaceRule(glass, line, short)
	local divider = glass.divider
	local r, g, b = Settings.Accent()
	glass.ruleLine, glass.ruleShort = line, short
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -Widgets.Snap(glass, DIVIDER_GAP))
	if short then
		divider:SetWidth(Widgets.Snap(glass, RULE_LENGTH))
	else
		divider:SetPoint("RIGHT", glass, "RIGHT", -Widgets.Snap(glass, Tokens.Size("gapMedium")), 0)
	end
	divider:SetHeight(Widgets.Border(glass))
	divider:SetVertexColor(r, g, b)
	if short and type(divider.SetGradient) == "function" and type(CreateColor) == "function" then
		divider:SetColorTexture(Tokens.Color("white"))
		divider:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))
	else
		divider:SetTexture((Tokens.Texture("divider")))
	end
	divider:Show()
end

local function PlaceFooter(glass, line)
	local footer = glass.footer
	glass.footerLine = line
	local inset = Widgets.Snap(glass, FOOTER_INSET)
	footer:ClearAllPoints()
	footer:SetPoint("BOTTOMLEFT", line, "TOPLEFT", inset - TEXT_MARGIN - (glass.padded or 0), Widgets.Snap(glass, DIVIDER_GAP))
	footer:SetPoint("RIGHT", glass, "RIGHT", -inset, 0)
	footer:SetHeight(Widgets.Border(glass))
	footer:SetVertexColor(Widgets.Rgba("edgeFaint"))
	footer:Show()
end

local function PlaceDivider(glass, tooltip)
	local title = tooltip.TextLeft1 or Style.Line(tooltip, "left", 1)
	if type(title) ~= "table" then
		glass.divider:Hide()
		return
	end
	PlaceRule(glass, title, false)
end

local function Sections(tooltip, count)
	local texts = {}
	for i = 1, count do
		local line = Style.Line(tooltip, "left", i)
		if type(line) == "table" then
			texts[i] = line:GetText()
		end
	end
	return Logic.Sections(texts, count)
end

function Style.IconTile(parent)
	local icon = CreateFrame("Frame", nil, parent)
	icon.chrome = Widgets.IconChrome(icon)
	local texture = icon:CreateTexture(nil, "ARTWORK")
	texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = icon:CreateMaskTexture()
	mask:SetTexture(Tokens.Texture("iconMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
	icon.texture, icon.mask = texture, mask
	icon.glow = Widgets.Glow(icon, { kind = "selection", spread = Tokens.Size("gapSmall") })
	return icon
end

function Style.PlaceIcon(icon, panel, size)
	Widgets.Size(icon, size, size)
	icon:ClearAllPoints()
	local inset = Widgets.Snap(icon, ICON_INSET)
	icon:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -inset)
	local border = Widgets.Border(icon) * BORDER_LINES
	icon.texture:ClearAllPoints()
	icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", border, -border)
	icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -border, border)
	local level = panel:GetFrameLevel()
	if Logic.IsNumber(level) then
		icon:SetFrameLevel(level + ICON_LEVEL)
		icon.glow.holder:SetFrameLevel(level + ICON_LEVEL - 1)
	end
	icon.chrome:Restyle()
	icon.glow:Restyle()
end

function Style.PaintIcon(icon, quality, spell)
	local lit = Logic.EdgeQuality(quality)
	local r, g, b, a
	if lit then
		r, g, b = Theme.QualityColor(quality)
		a = 1
		icon.glow:SetColorRGB(r, g, b)
	elseif spell then
		r, g, b = Settings.Accent()
		a = SPELL_EDGE_ALPHA
	else
		r, g, b, a = Widgets.Rgba("text", PLAIN_EDGE_ALPHA)
	end
	icon.chrome:SetRim(r, g, b, a)
	icon.glow:SetIntensity(lit and 1 or 0)
end

local function TextHeight(tooltip)
	local height = -LINE_SPACING
	for i = 1, Style.NumLines(tooltip) do
		local line = Style.Line(tooltip, "left", i)
		local h = type(line) == "table" and line:GetStringHeight()
		if not Logic.IsNumber(h) then
			return nil
		end
		height = height + h + LINE_SPACING
	end
	return height > 0 and height or nil
end

function Style.Icon(tooltip, fileID, quality, spell)
	local glass = Style.Glass(tooltip)
	if not (glass and glass.iconOwner) then
		return
	end
	local size = min(Settings.Get("iconSize"), TextHeight(tooltip) or math.huge)
	if not Settings.Get("icon") or Logic.IsSecret(fileID) or fileID == nil or not Pad(tooltip, glass, Widgets.Snap(glass, ICON_INSET) + size + TEXT_GAP - TEXT_MARGIN) then
		HideIcon(tooltip, glass)
		return
	end
	local icon = glass.icon or Style.IconTile(glass)
	glass.icon = icon
	Style.PlaceIcon(icon, tooltip, size)
	Style.PaintIcon(icon, quality, spell)
	local Icons = K.Icons
	if Icons and type(Icons.Apply) == "function" then
		Icons.Apply(icon.texture, fileID)
	else
		icon.texture:SetTexture(fileID)
	end
	icon:Show()
end

local ownFonts

local function OwnFont(path)
	if not ownFonts then
		ownFonts = {}
		for _, face in ipairs(Tokens.MediaList("font")) do
			ownFonts[face.path] = true
		end
	end
	return ownFonts[path] == true
end

function Style.Title(tooltip, quality)
	local glass = Style.Glass(tooltip)
	local title = glass and Style.Line(tooltip, "left", 1)
	if type(title) ~= "table" then
		return
	end
	local caption = Logic.IsNumber(quality) and _G["ITEM_QUALITY" .. quality .. "_DESC"] or nil
	caption = type(caption) == "string" and caption or nil
	local text = Logic.TitleText(title:GetText(), caption ~= nil, OwnFont((Style.FontSpec("title"))))
	if not text then
		Settings.LogOnce("title", "a tooltip title was secret or held escape codes; it keeps Blizzard's text")
		return
	end
	title:SetText(text)
	if not caption then
		return
	end
	local r, g, b = Tokens.Color("text")
	if Logic.EdgeQuality(quality) then
		r, g, b = Theme.QualityColor(quality)
		title:SetTextColor(r, g, b)
	end
	local label = glass.caption
	Style.StyleFont(label, "small")
	local path, size, flags = label:GetFont()
	local _, titleSize = Style.FontSpec("title")
	if Logic.IsNumber(size) and size > titleSize then
		label:SetFont(path, titleSize, flags)
	end
	local upper = Logic.Upper(caption)
	label:SetText(OwnFont(path) and Logic.Tracked(upper) or upper)
	label:SetTextColor(r, g, b)
	label:ClearAllPoints()
	label:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", 0, 0)
	label:Show()
end

local function PaintItemBorder(item)
	local frame = Safe.Side(item).tooltipsBorder
	local border = item.IconBorder
	if not frame or type(border) ~= "table" then
		return
	end
	if border:IsShown() then
		local r, g, b = border:GetVertexColor()
		if Logic.IsNumber(r) and Logic.IsNumber(g) and Logic.IsNumber(b) then
			frame.chrome:SetEdgeRGBA(r, g, b, 1)
			return
		end
	end
	frame.chrome:SetEdge("edgeInner")
end

function Style.ItemBorder(item)
	if type(item) ~= "table" then
		return nil
	end
	local side = Safe.Side(item)
	if side.tooltipsBorder then
		return side.tooltipsBorder
	end
	local icon, border = item.Icon, item.IconBorder
	if type(icon) ~= "table" or type(border) ~= "table" then
		Settings.LogOnce("itemborder", "an embedded item frame has no Icon or IconBorder; it keeps Blizzard's border")
		return nil
	end
	local keep = {}
	for _, key in ipairs({ "Icon", "IconOverlay", "IconOverlay2" }) do
		if type(item[key]) == "table" then
			keep[item[key]] = true
		end
	end
	Skin.Strip(item, { keep = keep })
	local frame = CreateFrame("Frame", nil, item)
	local outset = Widgets.Border(frame) * BORDER_LINES
	frame:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
	frame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
	UseParentLevel(frame, item)
	frame.chrome = Widgets.Chrome(frame, { shape = "tile", fill = "buttonFill", shadow = false })
	side.tooltipsBorder = frame
	hooksecurefunc(border, "SetVertexColor", function()
		PaintItemBorder(item)
	end)
	item:HookScript("OnShow", PaintItemBorder)
	PaintItemBorder(item)
	return frame
end

function Style.Lines(tooltip, item)
	local glass = Style.Glass(tooltip)
	if not glass then
		return
	end
	local count = Style.NumLines(tooltip)
	local stats, footer
	if item and count >= 2 then
		stats, footer = Sections(tooltip, count)
	end
	if stats and Settings.Get("softColors") then
		local r, g, b = Settings.Accent()
		for i = stats, (footer or count + 1) - 1 do
			local line = Style.Line(tooltip, "left", i)
			if type(line) == "table" and Logic.IsStat(line:GetText()) then
				line:SetTextColor(r, g, b)
			end
		end
	end
	glass.footer:Hide()
	if not (Settings.Get("divider") and count >= 2) then
		glass.divider:Hide()
		return
	end
	if stats and stats > 1 then
		PlaceRule(glass, Style.Line(tooltip, "left", stats - 1), true)
	else
		PlaceDivider(glass, tooltip)
	end
	if footer and footer > 1 then
		PlaceFooter(glass, Style.Line(tooltip, "left", footer))
	end
end

function Style.FontSpec(role)
	local path
	if Settings.Get("followFont") then
		path = Tokens.Font(KIT_ROLES[role])
	else
		path = Settings.Get(role .. ".font")
	end
	local size = Settings.Get(role .. ".size") * Theme.FontScale()
	return path, size, Logic.Flags(Settings.Get(role .. ".outline"))
end

function Style.StyleFont(object, role)
	local path, size, flags = Style.FontSpec(role)
	if object:SetFont(path, size, flags) == false then
		local fallback = Tokens.Font(KIT_ROLES[role])
		object:SetFont(fallback, size, flags)
		Settings.LogOnce("font:" .. tostring(path), "the font " .. tostring(path) .. " did not load; tooltips use KstyleUI's font")
	end
	if flags == "" then
		local offset = Tokens.Size("textShadowOffset")
		object:SetShadowColor(Tokens.Color("textShadow"))
		object:SetShadowOffset(offset, -offset)
	else
		object:SetShadowOffset(0, 0)
	end
end

function Style.ApplyFonts()
	for role, name in pairs(FONTS) do
		local object = _G[name]
		if type(object) == "table" and type(object.SetFont) == "function" then
			if not savedFonts[name] then
				savedFonts[name] = { font = { object:GetFont() }, offset = { object:GetShadowOffset() }, color = { object:GetShadowColor() } }
			end
			Style.StyleFont(object, role)
		else
			Settings.LogOnce("fontobject:" .. name, name .. " is missing on this client; its lines keep Blizzard's font")
		end
	end
end

function Style.RestoreFonts()
	for name, saved in pairs(savedFonts) do
		local object = _G[name]
		if type(object) == "table" and type(saved.font[1]) == "string" then
			object:SetFont(saved.font[1], saved.font[2], saved.font[3] or "")
			if saved.offset[1] then
				object:SetShadowOffset(saved.offset[1], saved.offset[2])
			end
			if saved.color[1] then
				object:SetShadowColor(saved.color[1], saved.color[2], saved.color[3], saved.color[4])
			end
		end
		savedFonts[name] = nil
	end
end

local function EffectiveScale(frame)
	if type(frame) ~= "table" or type(frame.GetEffectiveScale) ~= "function" then
		return nil
	end
	return frame:GetEffectiveScale()
end

function Style.ApplyScale(elementScale)
	local scale = Logic.TooltipScale(EffectiveScale(K.Scale.Root()), EffectiveScale(UIParent), elementScale)
	for _, tooltip in ipairs(skinned) do
		if savedScales[tooltip] == nil then
			local own = tooltip:GetScale()
			savedScales[tooltip] = Logic.IsNumber(own) and own or 1
		end
		tooltip:SetScale(scale)
		local glass = Style.Glass(tooltip)
		if glass then
			glass.chrome:Restyle()
			if glass.divider:IsShown() and glass.ruleLine then
				PlaceRule(glass, glass.ruleLine, glass.ruleShort)
			end
			if glass.footer:IsShown() and glass.footerLine then
				PlaceFooter(glass, glass.footerLine)
			end
		end
	end
	return scale
end

function Style.RestoreScale()
	for tooltip, scale in pairs(savedScales) do
		tooltip:SetScale(scale)
		savedScales[tooltip] = nil
		local glass = Style.Glass(tooltip)
		if glass then
			glass.chrome:Restyle()
		end
	end
end
