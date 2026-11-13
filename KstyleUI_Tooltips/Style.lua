-- Style.lua: the quest card on each restyled tooltip (its material, edge, the heading's diamond and its one rule, the compare caption as a card heading), the fade in, the tooltip fonts, the item caption, line spacing and the tooltip scale; GILT_FALLBACK is the one switch to S1's gilt token.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Theme, Skin, Safe, Motion = K.Tokens, K.Widgets, K.Theme, K.Skin, K.Safe, K.Motion
local Logic, Settings = ns.Logic, ns.Settings
local max, min, abs = math.max, math.min, math.abs

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
local KIT_ROLES = { title = "heading", body = "body", small = "caption" }
Style.KIT_ROLES = KIT_ROLES
local function KitRole(role, semantic)
	if role == "title" then
		return Tokens.TypeDefault(semantic == "names" and "tooltipName" or "tooltipTitle")
	end
	return KIT_ROLES[role]
end
local GILT, GILT_FALLBACK = "gilt", "neutral"
Style.GILT_FALLBACK = GILT_FALLBACK
local DIVIDER_GAP = 1
local RULE_ALPHA = 0.5
local DIVIDER_SUBLEVEL = 7
local ICON_INSET = 9.5
local TEXT_MARGIN = 10
local TEXT_GAP = 11
local LINE_SPACING = 0.5
local ICON_LEVEL = 2
local ICON_CROP = 0.07
local BORDER_LINES = 2
local SPELL_EDGE_ALPHA = 0.5
local PLAIN_EDGE_ALPHA = 0.35
local COLOR_TOLERANCE = 0.02
local GEM_SIZE, GEM_GAP = 8, 7
Style.GEM_ROOM = GEM_SIZE + GEM_GAP
local HEADER_INSET, HEADER_HEIGHT, HEADER_GAP = 10, 19, 2

local skinned = {}
local savedFonts = {}
local savedScales = setmetatable({}, { __mode = "k" })

function Style.Gilt()
	local ok, r, g, b = pcall(Tokens.Color, GILT)
	if ok then
		return r, g, b
	end
	return Tokens.Color(GILT_FALLBACK)
end

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

local function Base(current, added)
	if current >= added then
		return current - added
	end
	return current
end

local function Pad(tooltip, glass, left)
	local right, bottom, _, top
	if type(tooltip.GetPadding) == "function" and type(tooltip.SetPadding) == "function" then
		right, bottom, _, top = tooltip:GetPadding()
	end
	if not (Logic.IsNumber(right) and Logic.IsNumber(bottom)) then
		Settings.LogOnce("padding", "a tooltip's padding was missing or secret; it shows no icon and docks no bar")
		return false
	end
	local added = glass.added or { right = 0, bottom = 0 }
	local reserve = glass.reserve or { right = 0, bottom = 0 }
	local room = glass.gemmed and Widgets.Snap(glass, Style.GEM_ROOM) or 0
	glass.padding = true
	tooltip:SetPadding(Base(right, added.right) + reserve.right, Base(bottom, added.bottom) + reserve.bottom, left + room, Logic.IsNumber(top) and top or 0)
	glass.padding = false
	glass.padded = left > 0 and left or nil
	glass.gemRoom = room > 0 and room or nil
	glass.added = { right = reserve.right, bottom = reserve.bottom }
	return true
end

local function Reserved(glass)
	local reserve = glass.reserve
	return reserve ~= nil and (reserve.right > 0 or reserve.bottom > 0)
end

local function HideIcon(tooltip, glass)
	if glass.icon then
		glass.icon:Hide()
	end
	if (glass.padded or glass.gemRoom or Reserved(glass)) and not Pad(tooltip, glass, 0) then
		glass.padded = nil
	end
end

local function Repad(tooltip)
	local glass = Style.Glass(tooltip)
	if not glass or glass.padding then
		return
	end
	glass.added = nil
	if (glass.padded or glass.gemmed or Reserved(glass)) and not Pad(tooltip, glass, glass.padded or 0) then
		HideIcon(tooltip, glass)
	end
end

function Style.Reserve(tooltip, right, bottom)
	local glass = Style.Glass(tooltip)
	if not glass then
		return false
	end
	glass.reserve = { right = right or 0, bottom = bottom or 0 }
	return Pad(tooltip, glass, glass.padded or 0)
end

local function ResetTitle(glass)
	local title = glass.titleLine
	if not title or type(GameTooltipHeaderText) ~= "table" then
		return
	end
	local r, g, b, a = title:GetTextColor()
	title:SetFontObject(GameTooltipHeaderText)
	title:SetShadowOffset(GameTooltipHeaderText:GetShadowOffset())
	title:SetShadowColor(GameTooltipHeaderText:GetShadowColor())
	if Logic.IsNumber(r) and Logic.IsNumber(g) and Logic.IsNumber(b) and Logic.IsNumber(a) then
		title:SetTextColor(r, g, b, a)
	end
end

local function Reset(tooltip)
	local glass = Style.Glass(tooltip)
	if glass then
		ResetTitle(glass)
		glass.title, glass.titleRole = nil, nil
		glass.chrome:SetEdge("edgeInner")
		glass.divider:Hide()
		glass.caption:Hide()
		glass.gem:Hide()
		glass.gemmed = nil
		HideIcon(tooltip, glass)
	end
end
Style.Reset = Reset

function Style.PaintGem(gem)
	local material = Tokens.Material(Widgets.Setting("cardMaterial"))
	gem:SetTexture((Tokens.Texture(material and material.gem or "diamond")))
	if material and material.rule then
		gem:SetVertexColor(Tokens.Color("materialGold"))
	else
		gem:SetVertexColor(Style.Gilt())
	end
end

local function Header(tooltip)
	local header = tooltip.CompareHeader
	local heading = type(header) == "table" and Safe.Side(header).tooltipsHeading
	if heading then
		return header, heading
	end
end

local function PlaceHeader(tooltip)
	local header, heading = Header(tooltip)
	if not header then
		return
	end
	local gem, caption = heading.gem, heading.caption
	Widgets.CapsSize(caption)
	Widgets.TextColor(caption, "capsGold")
	local side = Widgets.Snap(heading, GEM_SIZE)
	gem:SetSize(side, side)
	gem:ClearAllPoints()
	Widgets.Point(gem, "LEFT", heading, "LEFT", HEADER_INSET, 0)
	caption:ClearAllPoints()
	Widgets.Point(caption, "LEFT", gem, "RIGHT", GEM_GAP, 0)
	Style.PaintGem(gem)
	heading:ClearAllPoints()
	Widgets.Size(heading, 2 * HEADER_INSET + Style.GEM_ROOM + Widgets.TextWidth(caption, 0), HEADER_HEIGHT)
	heading:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, Widgets.Snap(heading, HEADER_GAP))
	heading.chrome:Restyle()
end

local function SkinParts(tooltip)
	local header = tooltip.CompareHeader
	if type(header) == "table" and type(header.Label) == "table" then
		Skin.Strip(header)
		header.Label:SetAlpha(0)
		local heading = CreateFrame("Frame", nil, header)
		heading.chrome = Widgets.Chrome(heading, { shape = "window", fill = "surface", shadow = false, popup = true })
		heading.gem = heading:CreateTexture(nil, "OVERLAY")
		heading.caption = Widgets.Text(heading, "caps", "capsGold")
		Safe.Side(header).tooltipsHeading = heading
		PlaceHeader(tooltip)
	end
	if type(tooltip.CloseButton) == "table" then
		Skin.CloseButton(tooltip.CloseButton)
	end
end

function Style.Measurable(tooltip)
	if Widgets.Restricted(tooltip) then
		return false
	end
	if type(tooltip.GetAnchorType) ~= "function" then
		return true
	end
	local anchor = tooltip:GetAnchorType()
	if Widgets.IsSecret(anchor) then
		return false
	end
	return type(anchor) ~= "string" or not anchor:find("^ANCHOR_CURSOR")
end

local function BuildFade(tooltip)
	if type(tooltip.CreateAnimationGroup) ~= "function" then
		Settings.LogOnce("fade", "Frame:CreateAnimationGroup is missing; tooltips show without the fade in")
		return nil
	end
	local group = tooltip:CreateAnimationGroup()
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetFromAlpha(0)
	alpha:SetToAlpha(1)
	alpha:SetDuration(Tokens.Duration("hover"))
	alpha:SetSmoothing("OUT")
	group:SetToFinalAlpha(true)
	return group
end

function Style.Fade(tooltip)
	local glass = Style.Glass(tooltip)
	return glass and glass.fade
end

local function FadeIn(tooltip)
	local fade = Style.Fade(tooltip)
	if not fade then
		return
	end
	fade:Stop()
	if not Motion.ReducedMotion() then
		fade:Play()
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
	local header = type(tooltip.CompareHeader) == "table" and tooltip.CompareHeader or nil
	glass.chrome = Widgets.Chrome(glass, { shape = "window", fill = "surface", shadow = header == nil, popup = true })
	local divider = glass:CreateTexture(nil, "BORDER", nil, DIVIDER_SUBLEVEL)
	divider:SetTexture((Tokens.Texture("divider")))
	divider:Hide()
	glass.divider = divider
	glass.caption = Widgets.FontString(glass, "OVERLAY")
	glass.caption:Hide()
	glass.gem = glass:CreateTexture(nil, "OVERLAY")
	glass.gem:Hide()
	glass.iconOwner = not NO_ICON[name]
	side.tooltips = glass
	skinned[#skinned + 1] = tooltip
	SkinParts(tooltip)
	glass.fade = BuildFade(tooltip)
	tooltip:HookScript("OnShow", FadeIn)
	tooltip:HookScript("OnHide", function()
		if glass.fade then
			glass.fade:Stop()
		end
	end)
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
	if not Logic.IsSecret(name) and type(name) == "string" then
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
	for _, pair in ipairs({ { NORMAL_FONT_COLOR, "text" }, { HIGHLIGHT_FONT_COLOR, "text" }, { GREEN_FONT_COLOR, "friendly" }, { RED_FONT_COLOR, "hostile" } }) do
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

function Style.PaintRule(rule)
	local material = Tokens.Material(Widgets.Setting("cardMaterial"))
	if material and material.rule then
		rule:SetTexture((Tokens.Texture(material.rule)))
		rule:SetVertexColor(Widgets.Rgba("materialGold", RULE_ALPHA))
	else
		rule:SetTexture((Tokens.Texture("ruleFade")))
		rule:SetVertexColor(Style.Gilt())
	end
end

local function PlaceRule(glass, line)
	local divider = glass.divider
	glass.ruleLine = line
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -Widgets.Snap(glass, DIVIDER_GAP))
	divider:SetPoint("RIGHT", glass, "RIGHT", -Widgets.Snap(glass, Tokens.Size("gapMedium")), 0)
	divider:SetHeight(Widgets.Border(glass))
	Style.PaintRule(divider)
	divider:Show()
end

function Style.PlaceGem(gem, title, role)
	local _, size = title:GetFont()
	if not Logic.IsNumber(size) then
		_, size = Style.FontSpec(role or "title")
	end
	local side = Widgets.Snap(gem:GetParent(), GEM_SIZE)
	gem:SetSize(side, side)
	gem:ClearAllPoints()
	Widgets.Point(gem, "CENTER", title, "TOPLEFT", -(GEM_GAP + GEM_SIZE / 2), -size / 2)
	Style.PaintGem(gem)
	gem:Show()
	return true
end

local function SetGem(tooltip, glass, title)
	local wanted = title ~= nil and glass.iconOwner and Style.PlaceGem(glass.gem, title) or nil
	if not wanted then
		glass.gem:Hide()
	end
	if wanted ~= glass.gemmed then
		glass.gemmed = wanted
		if not Pad(tooltip, glass, glass.padded or 0) then
			glass.gemmed = nil
			glass.gem:Hide()
		end
	end
end

local function PlaceDivider(glass, tooltip)
	local title = tooltip.TextLeft1 or Style.Line(tooltip, "left", 1)
	if type(title) ~= "table" then
		glass.divider:Hide()
		return
	end
	PlaceRule(glass, title)
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
	local size = Settings.Get("iconSize")
	if Style.Measurable(tooltip) then
		size = min(size, TextHeight(tooltip) or math.huge)
	end
	if not Settings.Get("icon") or Logic.IsSecret(fileID) or fileID == nil or not Pad(tooltip, glass, Widgets.Snap(glass, ICON_INSET) + size + TEXT_GAP - TEXT_MARGIN) then
		HideIcon(tooltip, glass)
		return
	end
	local icon = glass.icon or Style.IconTile(glass)
	glass.icon = icon
	Style.PlaceIcon(icon, tooltip, size)
	Style.PaintIcon(icon, quality, spell)
	icon.texture:SetTexture(fileID)
	icon:Show()
end

local function Muted(line, tr, tg, tb)
	local r, g, b = line:GetTextColor()
	if not (Logic.IsNumber(r) and Logic.IsNumber(g) and Logic.IsNumber(b)) then
		return false
	end
	return abs(r - tr) < COLOR_TOLERANCE and abs(g - tg) < COLOR_TOLERANCE and abs(b - tb) < COLOR_TOLERANCE
end

local function ShowsLevel(tooltip)
	for i = 2, Style.NumLines(tooltip) do
		local line = Style.Line(tooltip, "left", i)
		if type(line) == "table" and Logic.IsLevelLine(line:GetText()) then
			return true
		end
	end
	return false
end

local function CaptionFont(label)
	Style.StyleFont(label, "small")
	local path, size, flags = label:GetFont()
	local _, titleSize = Style.FontSpec("title")
	if Logic.IsNumber(size) and size > titleSize then
		Widgets.ApplyFont(label, path, titleSize, flags)
	end
end

local function TitleFont(tooltip, glass)
	if not glass.title then
		return
	end
	if glass.titleRole == "names" and Style.FollowsFont("title") and KitRole("title", "names") ~= KitRole("title")
		and type(GameTooltipHeaderText) == "table" and type(glass.title.SetFontObject) == "function" then
		Style.StyleFont(glass.title, "title", tooltip, "names")
		glass.titleLine = glass.title
	else
		ResetTitle(glass)
	end
end

function Style.SetTitleRole(tooltip, semantic)
	local glass = Style.Glass(tooltip)
	local title = glass and Style.Line(tooltip, "left", 1)
	if type(title) ~= "table" then
		return
	end
	glass.title, glass.titleRole = title, semantic
	TitleFont(tooltip, glass)
end

function Style.Title(tooltip, quality, level)
	local glass = Style.Glass(tooltip)
	local title = glass and Style.Line(tooltip, "left", 1)
	if type(title) ~= "table" then
		return
	end
	local rarity = Logic.IsNumber(quality) and _G["ITEM_QUALITY" .. quality .. "_DESC"] or nil
	if level ~= nil and ShowsLevel(tooltip) then
		level = nil
	end
	local caption = Logic.Caption(level, type(rarity) == "string" and rarity or nil)
	local text = Logic.TitleText(title:GetText(), caption ~= nil)
	if not text then
		Settings.LogOnce("title", "a tooltip title was secret or held escape codes; it keeps Blizzard's text")
		return
	end
	title:SetText(text)
	if not caption then
		return
	end
	if Logic.EdgeQuality(quality) then
		title:SetTextColor(Theme.QualityColor(quality))
	end
	local label = glass.caption
	CaptionFont(label)
	label:SetText(caption)
	Widgets.TextColor(label, "text")
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

local function PlaceItemBorder(frame, icon)
	local outset = Widgets.Border(frame) * BORDER_LINES
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
	frame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
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
	PlaceItemBorder(frame, icon)
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
	local header, heading = Header(tooltip)
	if header then
		Widgets.SetText(heading.caption, header.Label:GetText())
		PlaceHeader(tooltip)
	end
	local count = Style.NumLines(tooltip)
	local stats, footer
	if item and count >= 2 then
		stats, footer = Sections(tooltip, count)
	end
	if stats and Settings.Get("softColors") then
		local r, g, b = Settings.Accent()
		local tr, tg, tb = Tokens.Color("text")
		for i = stats, (footer or count + 1) - 1 do
			local line = Style.Line(tooltip, "left", i)
			if type(line) == "table" and Logic.IsStat(line:GetText()) and Muted(line, tr, tg, tb) then
				line:SetTextColor(r, g, b)
			end
		end
	end
	if not (Settings.Get("divider") and count >= 2) then
		glass.divider:Hide()
		SetGem(tooltip, glass, nil)
		return
	end
	PlaceDivider(glass, tooltip)
	SetGem(tooltip, glass, glass.divider:IsShown() and glass.ruleLine or nil)
end

function Style.FollowsFont(role)
	return Settings.Get("followFont") or Theme.FollowsKit(Settings.Get(role .. ".font"))
end

function Style.FontSpec(role, semantic)
	local path
	if Style.FollowsFont(role) then
		path = Tokens.Font(KitRole(role, semantic))
	else
		path = Settings.Get(role .. ".font")
	end
	local size = Settings.Get(role .. ".size") * Theme.FontScale()
	return path, size, Logic.Flags(Settings.Get(role .. ".outline"))
end

function Style.StyleFont(object, role, scaleFrame, semantic)
	local path, size, flags = Style.FontSpec(role, semantic)
	if not scaleFrame then
		if not Widgets.ApplyFont(object, path, size, flags) then
			local fallback = Tokens.Font(KitRole(role, semantic))
			Widgets.ApplyFont(object, fallback, size, flags)
			Settings.LogOnce("font:" .. tostring(path), "the font " .. tostring(path) .. " did not load; tooltips use KstyleUI's font")
		end
		return
	end
	local snapped = Widgets.FontSize(scaleFrame, size)
	if object:SetFont(path, snapped, flags) == false then
		local fallback = Tokens.Font(KitRole(role, semantic))
		object:SetFont(fallback, snapped, flags)
		Settings.LogOnce("font:" .. tostring(path), "the font " .. tostring(path) .. " did not load; tooltips use KstyleUI's font")
	end
	if flags == "" then
		local offset = Widgets.Border(scaleFrame)
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
			Style.StyleFont(object, role, skinned[1])
		else
			Settings.LogOnce("fontobject:" .. name, name .. " is missing on this client; its lines keep Blizzard's font")
		end
	end
	for _, tooltip in ipairs(skinned) do
		local glass = Style.Glass(tooltip)
		if glass then
			CaptionFont(glass.caption)
			TitleFont(tooltip, glass)
			PlaceHeader(tooltip)
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
	for _, tooltip in ipairs(skinned) do
		local glass = Style.Glass(tooltip)
		if glass then
			ResetTitle(glass)
		end
	end
end

local function EffectiveScale(frame)
	if type(frame) ~= "table" or type(frame.GetEffectiveScale) ~= "function" then
		return nil
	end
	return frame:GetEffectiveScale()
end

local function RestyleParts(tooltip)
	PlaceHeader(tooltip)
	local item = tooltip.ItemTooltip
	local frame = type(item) == "table" and Safe.Side(item).tooltipsBorder
	if frame then
		if type(item.Icon) == "table" and Widgets.MayMove(frame) then
			PlaceItemBorder(frame, item.Icon)
		end
		frame.chrome:Restyle()
	end
end

function Style.ApplyScale(elementScale)
	local scale = Logic.TooltipScale(EffectiveScale(K.Scale.Root()), EffectiveScale(UIParent), elementScale)
	for _, tooltip in ipairs(skinned) do
		if savedScales[tooltip] == nil then
			local own = tooltip:GetScale()
			savedScales[tooltip] = Logic.IsNumber(own) and own or 1
		end
		tooltip:SetScale(scale)
		RestyleParts(tooltip)
		local glass = Style.Glass(tooltip)
		if glass then
			glass.chrome:Restyle()
			if glass.divider:IsShown() and glass.ruleLine then
				PlaceRule(glass, glass.ruleLine)
			end
			if glass.gemmed and glass.ruleLine then
				Style.PlaceGem(glass.gem, glass.ruleLine)
				Pad(tooltip, glass, glass.padded or 0)
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
