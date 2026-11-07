-- bad.lua: one colour literal per kind. The colour lint must find each.
local frame = CreateFrame("Frame")
local text = frame:CreateFontString()
text:SetText("|cffff8000Legendary|r")
local hex = "#4fc3ff"
local bare = "b67cff"
local packed = 0xffd100
frame.bg:SetColorTexture(0.06, 0.06, 0.06, 0.88)
text:SetTextColor(1, 1, 1)
local tint = CreateColor(.2, .4, 1)
local fill = { r = 0.1, g = 0.8, b = 0.2 }
