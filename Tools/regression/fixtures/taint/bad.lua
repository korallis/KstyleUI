-- bad.lua: one example of each taint-scan finding kind. Never loaded by the game.
local f = PlayerFrame
f:SetScript("OnShow", nil)
TargetFrame.unit = "focus"
UISpecialFrames[#UISpecialFrames + 1] = "KstyleUI_Window"
SetBinding("F", "JUMP")
local bar = CreateFrame("Frame")
bar:SetParent(UIParent)
local aura = C_UnitAuras.GetAuraDataByIndex("player", 1)
