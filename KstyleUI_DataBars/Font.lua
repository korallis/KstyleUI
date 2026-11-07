-- Font.lua: the font, size and outline a player picks for a data bar's text, with the soft shadow when there is no outline.
local _, ns = ...

local K, L = ns.K, ns.L
local Tokens, Theme = K.Tokens, K.Theme

local Font = {}
ns.Font = Font

local FALLBACK = "GameFontHighlightSmall"

Font.DEFAULT = "default"
Font.MIN_SIZE, Font.MAX_SIZE, Font.STEP = 6, 24, 1
Font.OUTLINES = {
	{ value = "NONE", label = L["None, with a soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}

function Font.Faces()
	local out = { { value = Font.DEFAULT, label = L["Interface font"] } }
	for _, option in ipairs(K.Widgets.MediaOptions("font")) do
		out[#out + 1] = option
	end
	return out
end

function Font.Path(face)
	if type(face) ~= "string" or face == "" or face == Font.DEFAULT then
		return (Tokens.Font("body"))
	end
	return face
end

function Font.Apply(text, face, size, outline)
	local flags = (outline == "OUTLINE" or outline == "THICKOUTLINE") and outline or ""
	local path = Font.Path(face)
	if not ns.IsNumber(size) or size <= 0 then
		size = Tokens.Size("body")
	end
	if text:SetFont(path, size * Theme.FontScale(), flags) == false then
		text:SetFontObject(FALLBACK)
		ns.LogOnce("font:" .. path, "the font " .. path .. " did not load; the text uses " .. FALLBACK)
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
end
