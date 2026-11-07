-- good.lua: colours from Tokens and values that only look like colours. The colour lint finds nothing.
local Tokens = KstyleUI.Tokens
local frame = CreateFrame("Frame")
local text = frame:CreateFontString()
frame.bg:SetColorTexture(Tokens.Color("surface"))
text:SetTextColor(Tokens.Color("text"))
text:SetText(string.format("|cff%02x%02x%02x%s|r", 255, 128, 0, "dynamic"))
text:SetText("|cnRED_FONT_COLOR:named colours are not literals|r")
frame:SetAlpha(0.5)
frame:SetPoint("CENTER", 1, 1)
local r, g, b = Tokens.Color("accent")
text:SetTextColor(r, g, b, 0.5)
local offset = { x = 1, y = 0.5 }
local triple = { 1, 0.5, 0 }
local fill = { r = r, g = g, b = b }
local id = 0x10
local key = "ff00ff00ff"
-- A comment may say SetVertexColor(1, 1, 1) or "#ffffff".
