-- SecureClick.lua: one shared secure button that, out of combat, covers the hovered minimap button and clicks Blizzard's own button for it.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets

local SecureClick = {}
ns.SecureClick = SecureClick

local OVERLAY_LEVEL = 5

local bound = setmetatable({}, { __mode = "k" })
local tooltips = setmetatable({}, { __mode = "k" })
local current
local active = false

local function Visual()
	return current
end

local function Hover(visual, on)
	if visual and type(visual.Paint) == "function" then
		Widgets.Hover(visual, on)
	end
end

local function Press(visual, down)
	if visual and type(visual.Paint) == "function" then
		Widgets.Press(visual, down)
	end
end

function SecureClick.Detach()
	local overlay = SecureClick.overlay
	if overlay and not InCombatLockdown() then
		overlay:Hide()
		overlay:ClearAllPoints()
	end
	current = nil
end

local function OverlayEnter()
	local visual = Visual()
	Hover(visual, true)
	local content = visual and tooltips[visual]
	if content then
		local tip = Widgets.Tooltip()
		tip:SetOwner(visual, "ANCHOR_RIGHT")
		K.Call(content, tip, visual)
		tip:Show()
	end
end

local function OverlayLeave()
	local visual = Visual()
	Hover(visual, false)
	Press(visual, false)
	local tip = Widgets.Tooltip()
	if visual and tip:IsOwned(visual) then
		tip:Hide()
	end
	SecureClick.Detach()
end

local function OverlayDown()
	Press(Visual(), true)
end

local function OverlayUp()
	Press(Visual(), false)
end

local function EnsureOverlay()
	local overlay = SecureClick.overlay
	if overlay then
		return overlay
	end
	if InCombatLockdown() then
		return nil
	end
	overlay = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	overlay:SetAttribute("type", "click")
	overlay:SetAttribute("useOnKeyDown", false)
	overlay:RegisterForClicks("AnyUp")
	overlay:HookScript("OnEnter", OverlayEnter)
	overlay:HookScript("OnLeave", OverlayLeave)
	overlay:HookScript("OnMouseDown", OverlayDown)
	overlay:HookScript("OnMouseUp", OverlayUp)
	overlay:Hide()
	SecureClick.overlay = overlay
	K.DevTest.Log("Minimap", "the secure click overlay is ready")
	return overlay
end

local function Attach(visual)
	if not active or InCombatLockdown() or visual:IsEnabled() == false then
		return
	end
	local resolve = bound[visual]
	local left, right = resolve()
	if not left then
		return
	end
	local overlay = EnsureOverlay()
	if not overlay then
		return
	end
	if not Widgets.Cover(overlay, visual) then
		return
	end
	current = visual
	overlay:SetAttribute("clickbutton1", left)
	overlay:SetAttribute("clickbutton2", right or left)
	local strata = visual:GetFrameStrata()
	if type(strata) == "string" then
		overlay:SetFrameStrata(strata)
	end
	overlay:SetFrameLevel(visual:GetFrameLevel() + OVERLAY_LEVEL)
	overlay:Show()
end

local function OnHide(visual)
	if current == visual then
		SecureClick.Detach()
	end
end

function SecureClick.Bind(visual, resolve, tooltip)
	if bound[visual] == nil then
		visual:HookScript("OnEnter", Attach)
		visual:HookScript("OnHide", OnHide)
	end
	bound[visual] = resolve
	tooltips[visual] = tooltip
end

function SecureClick.Targets(visual)
	local resolve = bound[visual]
	if resolve then
		return resolve()
	end
end

function SecureClick.SetActive(on)
	active = on == true
	if not active then
		SecureClick.Detach()
	end
end
