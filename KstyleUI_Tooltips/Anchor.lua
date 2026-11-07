-- Anchor.lua: the tooltip anchor element that Layout places and scales, and the hook that puts GameTooltip at it or at the cursor.
local _, ns = ...

local K = KstyleUI
local Logic, Settings = ns.Logic, ns.Settings

local Anchor = {}
ns.Anchor = Anchor

local KEY = "tooltips.anchor"
Anchor.KEY = KEY

local FALLBACK = {
	label = K.L["Tooltip anchor"],
	width = 180,
	height = 24,
	position = { anchor = "BOTTOMRIGHT", x = -95, y = 454 },
}

local holder
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
	holder:SetSize(width, height)
	K.Widgets.Place(holder, KEY, position, { label = label, module = ns.MODULE, scalable = true })
	return holder
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

local function Place(tooltip, parent)
	if not ns.active or tooltip ~= GameTooltip then
		return
	end
	if Settings.Get("anchor") == "cursor" then
		tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR_RIGHT", Settings.Get("cursorX"), Settings.Get("cursorY"))
		return
	end
	if not holder then
		return
	end
	local corner = Anchor.Corner()
	tooltip:ClearAllPoints()
	tooltip:SetPoint(corner, holder, corner)
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
	Settings.Log("GameTooltip's default anchor is hooked")
	return true
end
