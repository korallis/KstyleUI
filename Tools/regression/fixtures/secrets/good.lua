-- good.lua: the forms the secret lint accepts. Never loaded by the game.
local unit = "player"
local bar = CreateFrame("StatusBar")
local text = bar:CreateFontString()
bar:SetMinMaxValues(0, UnitHealthMax(unit))
bar:SetValue(UnitHealth(unit))
text:SetText(AbbreviateNumbers(UnitHealth(unit)))
text:SetFormattedText("%d%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
local hp = UnitHealth(unit)
if not issecretvalue(hp) and hp < 100 then
	text:SetText("low")
end
local power = UnitPower(unit)
if issecretvalue(power) then
	return
end
local half = power / 2
bar:SetValue(half)
