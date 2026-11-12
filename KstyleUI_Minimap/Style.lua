-- Style.lua: the minimap's accent colour and the font, size and outline of its texts.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets = K.Tokens, K.Widgets
local Settings = ns.Settings

local Style = {}
ns.Style = Style

local FALLBACK_FONT = "GameFontHighlightSmall"
local WORLD = "world"

function Style.Accent()
	if Settings.Get("accent.source") == "custom" then
		local color = Settings.Get("accent.color")
		return color.r, color.g, color.b
	end
	return K.Theme.Accent()
end

function Style.Color(token)
	if token == "accent" then
		return Style.Accent()
	end
	local r, g, b = Tokens.Color(token)
	return r, g, b
end

local function WorldShadow(text)
	local offset = K.Scale.Border() / Widgets.ScaleFactor(text)
	text:SetShadowColor(Tokens.Color("textShadow"))
	text:SetShadowOffset(offset, -offset)
end

function Style.Text(text, role, prefix, size)
	local rolePath = Tokens.Font(role)
	local font = Settings.Get(prefix .. ".font")
	local outline = Settings.Get(prefix .. ".outline")
	local world = outline == WORLD
	if world then
		outline = "OUTLINE"
	end
	local scaled = (size or Settings.Get(prefix .. ".size")) * K.Theme.FontScale()
	local path = K.Theme.FollowsKit(font) and rolePath or font
	if not Widgets.ApplyFont(text, path, scaled, outline) and not Widgets.ApplyFont(text, rolePath, scaled, outline) then
		text:SetFontObject(FALLBACK_FONT)
		Widgets.TextShadow(text, outline)
	end
	if world then
		WorldShadow(text)
	end
	return scaled
end
