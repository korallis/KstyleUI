-- Button.lua: dresses each secure unit button a header makes: a plain content frame with the look, hooks that follow the unit, hover and the unit tooltip.
local _, ns = ...

local K = KstyleUI
local Style, Unit = ns.Style, ns.Unit

local Button = {}
ns.Button = Button

local contents = setmetatable({}, { __mode = "k" })

function Button.Content(button)
	return contents[button]
end

local function OnAttributeChanged(button, name, value)
	if name == "unit" then
		local f = contents[button]
		if f then
			Unit.Set(f, value)
		end
	end
end

local function OnShow(button)
	local f = contents[button]
	if f and f.unit and Unit.running then
		Unit.Refresh(f)
	end
end

local function OnEnter(button)
	local f = contents[button]
	if not f then
		return
	end
	Style.SetHovered(f, true)
	local tooltip = GameTooltip
	if f.unit and tooltip and GameTooltip_SetDefaultAnchor and tooltip.SetUnit then
		GameTooltip_SetDefaultAnchor(tooltip, button)
		tooltip:SetUnit(f.unit)
		tooltip:Show()
	end
end

local function OnLeave(button)
	local f = contents[button]
	if not f then
		return
	end
	Style.SetHovered(f, false)
	local tooltip = GameTooltip
	if tooltip and tooltip.IsOwned and tooltip:IsOwned(button) then
		tooltip:Hide()
	end
end

local function Clicks(button)
	button:RegisterForClicks("AnyUp")
end

function Button.Adopt(button, kind)
	local f = contents[button]
	if f then
		return f
	end
	f = CreateFrame("Frame", nil, button)
	f:SetAllPoints(button)
	Style.Build(f, kind)
	for _, hook in ipairs(Button.built) do
		hook(f)
	end
	f:SetScript("OnEvent", Unit.OnEvent)
	contents[button] = f
	f.owner = button
	Unit.Track(f)
	button:HookScript("OnAttributeChanged", OnAttributeChanged)
	button:HookScript("OnShow", OnShow)
	button:HookScript("OnEnter", OnEnter)
	button:HookScript("OnLeave", OnLeave)
	if InCombatLockdown() then
		K.Combat.Queue(function()
			Clicks(button)
		end)
	else
		Clicks(button)
	end
	Style.Apply(f)
	local unit = button:GetAttribute("unit")
	if unit then
		Unit.Set(f, unit)
	end
	return f
end

Button.built = {}
