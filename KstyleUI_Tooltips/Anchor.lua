-- Anchor.lua: the tooltip anchor element that Layout places and scales, and the hook that puts GameTooltip at it, lifted over a shown threat card or target of target in its column, or at the cursor.
local _, ns = ...

local K = KstyleUI
local Logic, Settings = ns.Logic, ns.Settings

local Anchor = {}
ns.Anchor = Anchor

local KEY = "tooltips.anchor"
Anchor.KEY = KEY
local LIFTS = { "meters.threat", "unitframes.targettarget" }
local COLUMN, REACH = 300, 240
Anchor.LIFTS, Anchor.COLUMN, Anchor.REACH = LIFTS, COLUMN, REACH

local FALLBACK = {
	label = K.L["Tooltip anchor"],
	width = 180,
	height = 24,
	position = { anchor = "BOTTOMRIGHT", x = -95, y = 454 },
}

local holder
local holderWidth, holderHeight
local hooked = false

function Anchor.Frame()
	return holder
end

local function Element()
	local layouts = K.Setup and K.Setup.Layouts
	local element = layouts and layouts.Element and layouts.Element(KEY)
	if element then
		return element.label, element.width, element.height, layouts.Default(KEY)
	end
	Settings.Log("the setup has no " .. KEY .. " element; the tooltip anchor uses its built-in footprint")
	local p = FALLBACK.position
	return FALLBACK.label, FALLBACK.width, FALLBACK.height, { anchor = p.anchor, x = p.x, y = p.y }
end

function Anchor.Build()
	if holder then
		return holder
	end
	local label, width, height, position = Element()
	holder = CreateFrame("Frame", nil, K.Scale.Root())
	holderWidth, holderHeight = width, height
	K.Widgets.Place(holder, KEY, position, { label = label, module = ns.MODULE, scalable = true, fields = { "anchor", "x", "y", "scale" } })
	Anchor.Resize()
	return holder
end

function Anchor.Resize()
	if holder then
		K.Widgets.Size(holder, holderWidth, holderHeight)
	end
end

function Anchor.Scale()
	if not holder then
		return 1
	end
	local scale = holder:GetScale()
	return Logic.IsNumber(scale) and scale or 1
end

function Anchor.Corner()
	local Layout = K.Layout
	if not (Layout and Layout.Rect and Layout.RootSize) then
		return "BOTTOMRIGHT"
	end
	local left, bottom, width, height = Layout.Rect(KEY)
	local rootWidth, rootHeight = Layout.RootSize()
	return Logic.Corner(left, bottom, width, height, rootWidth, rootHeight)
end

function Anchor.Lift(corner)
	local Layout = K.Layout
	if (corner ~= "BOTTOMRIGHT" and corner ~= "BOTTOMLEFT") or not (Layout and Layout.Rect and Layout.Element) then
		return 0
	end
	local left, bottom, width = Layout.Rect(KEY)
	if not (Logic.IsNumber(left) and Logic.IsNumber(bottom) and Logic.IsNumber(width)) then
		return 0
	end
	local rects = {}
	for _, key in ipairs(LIFTS) do
		local element = Layout.Element(key)
		local frame = element and element.frame
		local visible = frame and frame:IsVisible()
		if not Logic.IsSecret(visible) and visible == true then
			local l, b, w, h = Layout.Rect(key)
			if Logic.IsNumber(l) and Logic.IsNumber(b) and Logic.IsNumber(w) and Logic.IsNumber(h) then
				rects[#rects + 1] = { l, b, l + w, b + h }
			end
		end
	end
	local right = corner == "BOTTOMRIGHT" and left + width or left + COLUMN
	return Logic.Lift(bottom, right - COLUMN, right, rects, K.Tokens.Size("gapLarge"), REACH)
end

local function PlaceMinimap(tooltip, owner)
	local map = Minimap
	if not ns.active or tooltip ~= GameTooltip or not map or not Settings.Get("minimapAnchor") then
		return false
	end
	local element = K.Layout and K.Layout.Element and K.Layout.Element("minimap.main")
	local frame = element and element.frame
	owner = owner or (type(tooltip.GetOwner) == "function" and tooltip:GetOwner())
	local found = false
	while not Logic.IsSecret(owner) and owner do
		if owner == map or owner == MinimapCluster or owner == frame then
			found = true
			break
		end
		owner = type(owner.GetParent) == "function" and owner:GetParent() or nil
	end
	if not found or type(tooltip.SetAnchorType) ~= "function" then
		return false
	end
	local x = type(map.GetCenter) == "function" and map:GetCenter()
	local mapScale, screenScale = map:GetEffectiveScale(), UIParent:GetEffectiveScale()
	local width = UIParent:GetWidth()
	local right = true
	if Logic.IsNumber(x) and Logic.IsNumber(mapScale) and Logic.IsNumber(screenScale) and Logic.IsNumber(width) then
		right = x * mapScale >= width * screenScale / 2
	end
	local root, own = K.Scale.Root():GetEffectiveScale(), tooltip:GetEffectiveScale()
	local gap = 0
	if Logic.IsNumber(root) and Logic.IsNumber(own) and own > 0 then
		gap = K.Tokens.Size("gapMedium") * root / own
	end
	tooltip:SetAnchorType("ANCHOR_NONE")
	tooltip:ClearAllPoints()
	tooltip:SetPoint(right and "TOPRIGHT" or "TOPLEFT", map, right and "TOPLEFT" or "TOPRIGHT", right and -gap or gap, 0)
	return true
end

local function Place(tooltip, parent)
	if not ns.active or tooltip ~= GameTooltip then
		return
	end
	if PlaceMinimap(tooltip, parent) then
		return
	end
	local mode = Settings.Get("anchor")
	local cursor = mode == "cursor"
	if mode == "cursorOutOfCombat" then
		if type(InCombatLockdown) == "function" then
			local combat = InCombatLockdown()
			cursor = not Logic.IsSecret(combat) and not combat
		else
			Settings.LogOnce("combatAnchor", "InCombatLockdown is missing; tooltips use the placed anchor")
		end
	end
	if cursor then
		tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR_RIGHT", Settings.Get("cursorX"), Settings.Get("cursorY"))
		return
	end
	if not holder then
		return
	end
	local corner = Anchor.Corner()
	local lift = Anchor.Lift(corner)
	local root, own = K.Scale.Root():GetEffectiveScale(), tooltip:GetEffectiveScale()
	tooltip:ClearAllPoints()
	if lift > 0 and Logic.IsNumber(root) and Logic.IsNumber(own) and own > 0 then
		tooltip:SetPoint(corner, holder, corner, 0, lift * root / own)
	else
		tooltip:SetPoint(corner, holder, corner)
	end
end

function Anchor.IsHooked()
	return hooked
end

function Anchor.Hook()
	if hooked then
		return true
	end
	if type(GameTooltip_SetDefaultAnchor) ~= "function" then
		Settings.Log("GameTooltip_SetDefaultAnchor is missing; tooltips keep Blizzard's position")
		return false
	end
	hooked = true
	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
		K.Call(Place, tooltip, parent)
	end)
	if GameTooltip and type(GameTooltip.SetOwner) == "function" then
		hooksecurefunc(GameTooltip, "SetOwner", function(tooltip, owner)
			K.Call(PlaceMinimap, tooltip, owner)
		end)
		GameTooltip:HookScript("OnShow", function(tooltip)
			K.Call(PlaceMinimap, tooltip)
		end)
		if type(GameTooltip.SetMinimapMouseover) == "function" then
			hooksecurefunc(GameTooltip, "SetMinimapMouseover", function(tooltip)
				K.Call(PlaceMinimap, tooltip, Minimap)
			end)
		end
	end
	Settings.Log("GameTooltip's default anchor is hooked")
	return true
end
