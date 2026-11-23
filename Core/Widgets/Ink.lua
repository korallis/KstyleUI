-- Ink.lua: linearised fill contrast, a feathered backing for text over the world, and a one-texture soft halo behind world names.
local _, ns = ...
local Widgets, Tokens = ns.Widgets, ns.Tokens

function Widgets.Readability(key)
	return not ns.Appearance or ns.Appearance.Readability(key)
end

local function Linear(value)
	return value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
end

function Widgets.InkLuminance(r, g, b)
	if Widgets.IsSecret(r) or Widgets.IsSecret(g) or Widgets.IsSecret(b)
		or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

function Widgets.InkFor(r, g, b)
	local luminance = Widgets.InkLuminance(r, g, b)
	local dark = luminance and luminance >= 0.19
	local ir, ig, ib = Tokens.Color(dark and "slabBottom" or "textEmphasis")
	return ir, ig, ib, dark and 0.92 or 1, dark and "" or "OUTLINE"
end

function Widgets.InkText(text, r, g, b)
	local ir, ig, ib, alpha, flags = Widgets.InkFor(r, g, b)
	local path, size = text:GetFont()
	Widgets.ApplyFont(text, path, size, flags)
	text:SetTextColor(ir, ig, ib, alpha)
	local sr, sg, sb = Tokens.Color(flags == "" and "textEmphasis" or "textShadow")
	text:SetShadowColor(sr, sg, sb, flags == "" and 0.25 or 0.85)
	local offset = Widgets.Snap(text, 1)
	text:SetShadowOffset(offset, -offset)
end

function Widgets.TextScrim(text, shown)
	shown = shown and Widgets.Readability("worldText")
	local slice = text.inkScrim
	if not slice and shown then
		slice = Widgets.NineSlice(text:GetParent(), "shadow", "BACKGROUND", -1)
		text.inkScrim = slice
		for _, texture in ipairs(slice) do
			texture.inkTextScrim = true
		end
		Widgets.ColorSlice(slice, Widgets.Rgba("black", 0.45))
	end
	if slice then
		Widgets.ShowSlice(slice, shown)
		if shown then
			Widgets.LayoutSlice(slice, text, 8, 4, 0, text, 6)
		end
	end
end

local HALO_PAD_X, HALO_PAD_Y = 6, 4

function Widgets.HaloAlpha(text, alpha)
	local halo = text.halo
	if halo and halo.on then halo:SetShown(Widgets.IsSecret(alpha) or alpha ~= 0) end
end

function Widgets.Halo(text, shown)
	shown = shown and Widgets.Readability("softBacking") or false
	local halo, parent = text.halo, text:GetParent()
	if not halo and shown and parent and parent.CreateTexture then
		halo = parent:CreateTexture(nil, "BACKGROUND", nil, -1)
		halo:SetTexture((Tokens.Texture("shadow")))
		halo:SetVertexColor(Tokens.Color("shadow"))
		text.halo = halo
	end
	if not halo then return end
	halo.on = shown
	if shown then
		local x, y = Widgets.Snap(text, HALO_PAD_X), Widgets.Snap(text, HALO_PAD_Y)
		halo:SetPoint("TOPLEFT", text, "TOPLEFT", -x, y)
		halo:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", x, -y)
		return Widgets.HaloAlpha(text, text:GetAlpha())
	end
	halo:Hide()
end
