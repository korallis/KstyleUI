-- Reload.lua: reload buttons whose clicks reach one shared secure macro button that runs /reload.
local _, ns = ...

local Widgets = ns.Widgets
local L = ns.L

local OVERLAY_LEVEL = 5
local EVENTS_OWNER = "Widgets.Reload"

local visuals = setmetatable({}, { __mode = "k" })
local overlay
local current
local watching = false

local function Detach()
	if overlay and not InCombatLockdown() then
		overlay:Hide()
		overlay:ClearAllPoints()
	end
	current = nil
end

local function OverlayEnter()
	if current then
		Widgets.Hover(current, true)
	end
end

local function OverlayLeave()
	local visual = current
	if visual then
		Widgets.Hover(visual, false)
		Widgets.Press(visual, false)
	end
	Detach()
end

local function OverlayDown()
	if current then
		Widgets.Press(current, true)
	end
end

local function OverlayUp()
	if current then
		Widgets.Press(current, false)
	end
end

local function OverlayPreClick()
	local visual = current
	if visual and visual.beforeReload then
		ns.Call(visual.beforeReload, visual)
	end
end

local function EnsureOverlay()
	if overlay then
		return overlay
	end
	if InCombatLockdown() then
		return nil
	end
	local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", "/reload")
	button:SetAttribute("useOnKeyDown", false)
	button:RegisterForClicks("AnyUp")
	button:HookScript("OnEnter", OverlayEnter)
	button:HookScript("OnLeave", OverlayLeave)
	button:HookScript("OnMouseDown", OverlayDown)
	button:HookScript("OnMouseUp", OverlayUp)
	button:HookScript("PreClick", OverlayPreClick)
	button:Hide()
	overlay = button
	Widgets.Log("the secure reload button is ready")
	return overlay
end

local function Attach(visual)
	if InCombatLockdown() or visual:IsEnabled() == false then
		return
	end
	local button = EnsureOverlay()
	if not button then
		return
	end
	if not Widgets.Cover(button, visual) then
		return
	end
	current = visual
	local strata = visual:GetFrameStrata()
	if type(strata) == "string" then
		button:SetFrameStrata(strata)
	end
	button:SetFrameLevel(visual:GetFrameLevel() + OVERLAY_LEVEL)
	button:Show()
end

local function OnHide(visual)
	if current == visual then
		Detach()
	end
end

local function Watch()
	if watching then
		return
	end
	watching = true
	ns.Events.Register(EVENTS_OWNER, "PLAYER_REGEN_DISABLED", function()
		Detach()
		for visual in pairs(visuals) do
			visual:Disable()
		end
	end)
	ns.Events.Register(EVENTS_OWNER, "PLAYER_REGEN_ENABLED", function()
		for visual in pairs(visuals) do
			visual:Enable()
		end
	end)
end

local function Fallback()
	ns.Print(L["Type /reload to reload the interface."])
	Widgets.LogOnce("reload-fallback", "a reload button was clicked without the secure button; asked the player to type /reload")
end

function Widgets.ReloadButton(parent, opts)
	opts = opts or {}
	local visual = Widgets.Button(parent, {
		text = opts.text or L["Reload"],
		primary = true,
		width = opts.width,
		height = opts.height,
		name = opts.name,
		tooltip = opts.tooltip,
		onClick = Fallback,
	})
	visual.isReload = true
	visual.beforeReload = opts.beforeReload
	visuals[visual] = true
	visual:HookScript("OnEnter", Attach)
	visual:HookScript("OnHide", OnHide)
	Watch()
	if InCombatLockdown() then
		visual:Disable()
	end
	return visual
end
