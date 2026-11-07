-- Style.lua: the glass panel, edge and title divider on each restyled tooltip, the tooltip fonts and the tooltip scale.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Theme, Skin, Safe = K.Tokens, K.Widgets, K.Theme, K.Skin, K.Safe
local Logic, Settings = ns.Logic, ns.Settings
local max = math.max

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

local ICON_OWNERS = {
	GameTooltip = { "ShoppingTooltip1", "ShoppingTooltip2" },
	ItemRefTooltip = { "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" },
}
local FONTS = { title = "GameTooltipHeaderText", body = "GameTooltipText", small = "GameTooltipTextSmall" }
local KIT_ROLES = { title = "heading", body = "body", small = "caption" }
local DIVIDER_GAP = 1
local DIVIDER_SUBLEVEL = 7
local ICON_GAP = 4
local ICON_CROP = 0.07
local BORDER_LINES = 2

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

local function Reset(tooltip)
	local glass = Style.Glass(tooltip)
	if glass then
		glass.chrome:SetEdge("edgeInner")
		glass.divider:Hide()
		if glass.icon then
			glass.icon:Hide()
		end
	end
end
Style.Reset = Reset

local function SkinParts(tooltip)
	local header = tooltip.CompareHeader
	if type(header) == "table" then
		Skin.Strip(header)
		Skin.Backdrop(header, { shape = "tile", fill = "raised", shadow = false })
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
	glass.comparers = ICON_OWNERS[name] and {} or nil
	side.tooltips = glass
	skinned[#skinned + 1] = tooltip
	SkinParts(tooltip)
	tooltip:HookScript("OnTooltipCleared", Reset)
	tooltip:HookScript("OnHide", Reset)
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
	for _, pair in ipairs({ { NORMAL_FONT_COLOR, "text" }, { HIGHLIGHT_FONT_COLOR, "textEmphasis" } }) do
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

local function PlaceDivider(glass, tooltip)
	local title = tooltip.TextLeft1 or Style.Line(tooltip, "left", 1)
	local divider = glass.divider
	if type(title) ~= "table" then
		divider:Hide()
		return
	end
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -Widgets.Snap(glass, DIVIDER_GAP))
	divider:SetPoint("RIGHT", glass, "RIGHT", -Widgets.Snap(glass, Tokens.Size("gapMedium")), 0)
	divider:SetHeight(Widgets.Border(glass))
	divider:SetVertexColor(Settings.Accent())
	divider:Show()
end

local function IconFrame(glass, tooltip)
	if glass.icon then
		return glass.icon
	end
	local icon = CreateFrame("Frame", nil, glass)
	icon.chrome = Widgets.Chrome(icon, { shape = "tile", fill = "raised", shadow = false })
	local texture = icon:CreateTexture(nil, "ARTWORK")
	texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = icon:CreateMaskTexture()
	mask:SetTexture(Tokens.Texture("iconMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
	icon.texture, icon.mask = texture, mask
	icon:Hide()
	glass.icon = icon
	return icon
end

local function PlaceIcon(icon, glass, tooltip)
	local size = Settings.Get("iconSize")
	Widgets.Size(icon, size, size)
	icon:ClearAllPoints()
	icon:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -Widgets.Snap(glass, ICON_GAP), 0)
	local inset = Widgets.Border(icon) * BORDER_LINES
	icon.texture:ClearAllPoints()
	icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
	icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
	icon.chrome:Restyle()
end

local function Comparing(glass)
	for _, other in ipairs(glass.comparers) do
		if other:IsShown() then
			return true
		end
	end
	return false
end

function Style.WatchComparison()
	for _, tooltip in ipairs(skinned) do
		local glass = Style.Glass(tooltip)
		local names = ICON_OWNERS[tooltip:GetName()]
		if glass and glass.comparers and names and #glass.comparers == 0 then
			for _, name in ipairs(names) do
				local other = _G[name]
				if type(other) == "table" and type(other.HookScript) == "function" then
					glass.comparers[#glass.comparers + 1] = other
					other:HookScript("OnShow", function()
						if glass.icon then
							glass.icon:Hide()
						end
					end)
				end
			end
		end
	end
end

function Style.Icon(tooltip, fileID)
	local glass = Style.Glass(tooltip)
	if not (glass and glass.comparers) then
		return
	end
	if not Settings.Get("icon") or Logic.IsSecret(fileID) or fileID == nil or Comparing(glass) then
		if glass.icon then
			glass.icon:Hide()
		end
		return
	end
	local icon = IconFrame(glass, tooltip)
	PlaceIcon(icon, glass, tooltip)
	local Icons = K.Icons
	if Icons and type(Icons.Apply) == "function" then
		Icons.Apply(icon.texture, fileID)
	else
		icon.texture:SetTexture(fileID)
	end
	icon:Show()
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
	frame.chrome = Widgets.Chrome(frame, { shape = "tile", fill = "raised", shadow = false })
	side.tooltipsBorder = frame
	hooksecurefunc(border, "SetVertexColor", function()
		PaintItemBorder(item)
	end)
	item:HookScript("OnShow", PaintItemBorder)
	PaintItemBorder(item)
	return frame
end

function Style.Divider(tooltip)
	local glass = Style.Glass(tooltip)
	if not glass then
		return
	end
	if Settings.Get("divider") and Style.NumLines(tooltip) >= 2 then
		PlaceDivider(glass, tooltip)
	else
		glass.divider:Hide()
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
			if glass.divider:IsShown() then
				PlaceDivider(glass, tooltip)
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
