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

local FONTS = { title = "GameTooltipHeaderText", body = "GameTooltipText", small = "GameTooltipTextSmall" }
local KIT_ROLES = { title = "heading", body = "body", small = "caption" }
local DIVIDER_GAP = 1
local DIVIDER_SUBLEVEL = 7

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

local function Line(tooltip, side, index)
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
		SoftenRegion(Line(tooltip, "left", i), colors)
		SoftenRegion(Line(tooltip, "right", i), colors)
	end
end

local function PlaceDivider(glass, tooltip)
	local title = tooltip.TextLeft1 or Line(tooltip, "left", 1)
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

function Style.Decorate(tooltip)
	local glass = Style.Glass(tooltip)
	if not glass then
		return
	end
	if Settings.Get("softColors") then
		Style.Soften(tooltip)
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
