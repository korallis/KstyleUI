-- good.lua: the guarded forms the taint scan accepts. Never loaded by the game.
local Combat = KstyleUI.Combat
Combat.Queue(function()
	SetBinding("F", "JUMP")
end)
KstyleUI.Safe.HideBlizzard(PlayerFrame)
hooksecurefunc(PlayerFrame, "Show", function(self) end)
PlayerFrame:HookScript("OnShow", function(self, button, text) end)
local bar = CreateFrame("Frame", nil, UIParent)
bar:SetPoint("CENTER", PlayerFrame, "CENTER")
bar:SetScript("OnEvent", function(self, event) end)
local labels = { text = "PlayerFrame:Hide()", button = 1 }
StaticPopupDialogs.KSTYLEUI_CONFIRM = { text = labels.text }
StaticPopupDialogs["KSTYLEUI_RELOAD"] = {}
SlashCmdList.KSTYLE = function() end
local function Reparent(frame, parent)
	if EditModeManagerFrame:IsShown() then
		return
	end
	frame:SetParent(parent)
end
if C_Secrets.ShouldAurasBeSecret() then
	return Reparent
end
local aura = C_UnitAuras.GetAuraDataByIndex("player", 1)
