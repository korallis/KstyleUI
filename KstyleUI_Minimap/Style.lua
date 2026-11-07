-- Style.lua: the minimap's accent colour and the font, size and outline of its texts.
local _, ns = ...

local K = KstyleUI
local Tokens = K.Tokens
local Settings = ns.Settings

local Style = {}
ns.Style = Style

local FALLBACK_FONT = "GameFontHighlightSmall"

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

function Style.Text(text, role, prefix, size)
	local rolePath = Tokens.Font(role)
	local font = Settings.Get(prefix .. ".font")
	local outline = Settings.Get(prefix .. ".outline")
	local scaled = (size or Settings.Get(prefix .. ".size")) * K.Theme.FontScale()
	local path = font ~= "" and font or rolePath
	if text:SetFont(path, scaled, outline) == false and text:SetFont(rolePath, scaled, outline) == false then
		text:SetFontObject(FALLBACK_FONT)
	end
	if outline == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
	return scaled
end
