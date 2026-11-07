-- Click.lua: one secure proxy button that carries a strip item's click to Blizzard's own button out of combat, so the click runs untainted.
local _, ns = ...

local K = ns.K
local Widgets = K.Widgets

local Click = {}
ns.Click = Click

local OVERLAY_LEVEL = 5
local TARGETS = {
	gold = { "MainMenuBarBackpackButton" },
	durability = { "CharacterMicroButton" },
	time = { "GameTimeFrame", "TimeManagerClockButton" },
}

local current

function Click.Target(id)
	local names = TARGETS[id]
	if not names then
		return nil
	end
	for _, name in ipairs(names) do
		local button = _G[name]
		if type(button) == "table" and type(button.Click) == "function" then
			local forbidden = type(button.IsForbidden) == "function" and button:IsForbidden()
			if forbidden ~= true then
				return button
			end
		end
	end
	return nil
end

function Click.Detach()
	local proxy = Click.proxy
	if proxy and not InCombatLockdown() then
		proxy:Hide()
		proxy:ClearAllPoints()
	end
	current = nil
end

function Click.Release(item)
	if current == item then
		ns.Strip.HideTooltip(item)
		Click.Detach()
	end
end

function Click.Covers(item)
	local proxy = Click.proxy
	if current ~= item or not proxy then
		return false
	end
	local shown = proxy:IsShown()
	return ns.IsSecret(shown) or shown == true
end

local function OnEnter()
	local item = current
	if item then
		Widgets.Hover(item.button, true)
		ns.Strip.ShowTooltip(item)
	end
end

local function OnLeave()
	local item = current
	if item then
		Widgets.Hover(item.button, false)
		Widgets.Press(item.button, false)
		ns.Strip.HideTooltip(item)
	end
	Click.Detach()
end

local function OnMouseDown()
	if current then
		Widgets.Press(current.button, true)
	end
end

local function OnMouseUp()
	if current then
		Widgets.Press(current.button, false)
	end
end

local function PostClick(_, mouse)
	local item = current
	if item and mouse == "RightButton" then
		local action = ns.Strip.ACTIONS[item.id]
		if action then
			K.Call(action, item, mouse)
		end
	end
end

local function Ensure()
	if Click.proxy then
		return Click.proxy
	end
	if InCombatLockdown() then
		return nil
	end
	local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("useOnKeyDown", false)
	button:HookScript("OnEnter", OnEnter)
	button:HookScript("OnLeave", OnLeave)
	button:HookScript("OnMouseDown", OnMouseDown)
	button:HookScript("OnMouseUp", OnMouseUp)
	button:HookScript("PostClick", PostClick)
	button:Hide()
	Click.proxy = button
	ns.Log("the secure click proxy is ready")
	return button
end

function Click.Attach(item)
	local target = Click.Target(item.id)
	if not target or InCombatLockdown() then
		return false
	end
	local button = Ensure()
	if not button then
		return false
	end
	if not K.Widgets.Cover(button, item.button) then
		return false
	end
	current = item
	button:SetAttribute("type1", "click")
	button:SetAttribute("clickbutton1", target)
	local strata = item.button:GetFrameStrata()
	if type(strata) == "string" and not ns.IsSecret(strata) then
		button:SetFrameStrata(strata)
	end
	button:SetFrameLevel(item.button:GetFrameLevel() + OVERLAY_LEVEL)
	button:Show()
	return true
end

ns.Listen("PLAYER_REGEN_DISABLED", Click.Detach)
