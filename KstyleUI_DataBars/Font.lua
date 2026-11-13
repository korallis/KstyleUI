-- Font.lua: the font, size and outline a player picks for a data bar's text, set on whole pixels with the soft shadow when there is no outline (Widgets.ApplyFont), or the world layer's outline with the shadow under it.
local _, ns = ...

local K, L = ns.K, ns.L
local Tokens, Theme, Widgets = K.Tokens, K.Theme, K.Widgets

local Font = {}
ns.Font = Font

local FALLBACK = "GameFontHighlightSmall"

Font.DEFAULT = "default"
Font.WORLD = "WORLD"
Font.MIN_SIZE, Font.MAX_SIZE, Font.STEP = 6, 24, 1
Font.OUTLINES = {
	{ value = Font.WORLD, label = L["Outline with a soft shadow"] },
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

function Font.Path(face, role)
	if K.Theme.FollowsKit(face) then
		return (Tokens.Font(role or "body"))
	end
	return face
end

function Font.Apply(text, face, size, outline, role)
	local world = outline == Font.WORLD
	local flags = world and "OUTLINE" or (outline == "OUTLINE" or outline == "THICKOUTLINE") and outline or ""
	local path = Font.Path(face, role)
	if not ns.IsNumber(size) or size <= 0 then
		size = Tokens.Size("body")
	end
	if not Widgets.ApplyFont(text, path, size * Theme.FontScale(), flags) then
		text:SetFontObject(FALLBACK)
		Widgets.TextShadow(text, flags)
		ns.LogOnce("font:" .. path, "the font " .. path .. " did not load; the text uses " .. FALLBACK)
	end
	if world then
		local offset = K.Scale.Border() / Widgets.ScaleFactor(text)
		text:SetShadowColor(Tokens.Color("textShadow"))
		text:SetShadowOffset(offset, -offset)
	end
end
