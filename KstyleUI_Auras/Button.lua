-- Button.lua: dresses an engine aura button as a plain square tile as the owner's picture draws it: the icon one border inside a one-pixel dark square rim, the timer under it in the Medium timer face on whole pixels (Widgets.ApplyFont), the stack count in the tile's top right corner as world text (an outline and a soft shadow, no plate) on a badge the engine shows from two applications, the engine's dispel plate on debuffs, and the engine bindings; a plain frame gets the same tile without the bindings, for the preview.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens

local Button = {}
ns.Button = Button

local ICON_INSET_LINES = 1
local TEXT_INSET = 1
local TIMER_LIFT = 0.5
local RIM_SUBLEVEL = 5
local DISPEL_SUBLEVEL = 7
local BADGE_LEVEL = 2
local MIN_APPLICATIONS = 2
local MAX_APPLICATIONS = 999
local CANCEL_CLICK = "RightButtonUp"
local BESIDE_ICON = { TOPRIGHT = { "TOPRIGHT", "TOPLEFT", -1 }, TOPLEFT = { "TOPLEFT", "TOPRIGHT", 1 }, BOTTOMRIGHT = { "BOTTOMRIGHT", "BOTTOMLEFT", -1 }, BOTTOMLEFT = { "BOTTOMLEFT", "BOTTOMRIGHT", 1 }, CENTER = { "RIGHT", "LEFT", -1 } }

local logged = {}

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(ns.Model.MODULE, message)
	end
end

local function Engine(button)
	return type(button.SetIcon) == "function"
end

function Button.StyleText(text, spec, colorName, role, custom)
	local flags = ns.Model.Flags(spec.outline)
	local path = spec.font ~= "" and spec.font or Tokens.Font(role or "number")
	if not Widgets.ApplyFont(text, path, spec.size, flags) then
		path = Tokens.Font(role or "number")
		Widgets.ApplyFont(text, path, spec.size, flags)
		LogOnce("font:" .. tostring(spec.font), "the font " .. tostring(spec.font) .. " did not load; aura text uses " .. tostring(path))
	end
	local color = custom ~= false and spec.color
	local ok
	if color then
		ok = pcall(text.SetTextColor, text, color.r, color.g, color.b, 1)
	else
		ok = pcall(text.SetTextColor, text, Tokens.Color(colorName or "textEmphasis"))
	end
	if not ok then
		LogOnce("color", "the engine holds an aura text's colour; it keeps the engine's colour")
	end
end

function Button.Create(button, hasDispel)
	local skin = CreateFrame("Frame", nil, button)
	local rim = skin:CreateTexture(nil, "BORDER", nil, RIM_SUBLEVEL)
	rim:SetColorTexture(Widgets.Rgba("white"))
	rim:SetAllPoints(skin)
	local icon = skin:CreateTexture(nil, "ARTWORK")
	local over = CreateFrame("Frame", nil, skin)
	over:SetAllPoints(skin)
	over:SetFrameLevel(skin:GetFrameLevel() + BADGE_LEVEL)
	local badge = CreateFrame("StatusBar", nil, over)
	badge:SetStatusBarTexture((Tokens.Texture("barFlat")))
	badge:SetStatusBarColor(Widgets.Rgba("black", 0))
	badge:SetFrameLevel(over:GetFrameLevel())
	local fill = badge:GetStatusBarTexture()
	if fill then
		fill:SetAlpha(0)
	end
	local count = Widgets.FontString(badge, "OVERLAY")
	local entry = {
		button = button,
		skin = skin,
		over = over,
		rim = { rim },
		icon = icon,
		timer = Widgets.FontString(over, "OVERLAY"),
		count = count,
		badge = badge,
	}
	if hasDispel then
		local tint = skin:CreateTexture(nil, "BORDER", nil, DISPEL_SUBLEVEL)
		tint:SetColorTexture(Widgets.Rgba("white"))
		tint:SetAllPoints(skin)
		tint:Hide()
		entry.dispel = { tint }
	end
	return entry
end

local function PlaceTexts(entry, ctx, inset)
	local skin, timer, count, badge = entry.skin, entry.timer, entry.count, entry.badge
	Button.StyleText(timer, ctx.timer, "timerText", "timer")
	Button.StyleText(count, ctx.count)
	timer:ClearAllPoints()
	count:ClearAllPoints()
	local edge = inset + Widgets.Snap(skin, TEXT_INSET)
	local position = ctx.timer.position
	if position == "inside" then
		Widgets.Point(timer, "BOTTOM", skin, "BOTTOM", ctx.timer.x, edge + ctx.timer.y)
	elseif position == "top" then
		Widgets.Point(timer, "TOP", skin, "TOP", ctx.timer.x, -edge + ctx.timer.y)
	elseif position == "center" then
		Widgets.Point(timer, "CENTER", skin, "CENTER", ctx.timer.x, ctx.timer.y)
	else
		Widgets.Point(timer, "TOP", skin, "BOTTOM", ctx.timer.x, -(ns.Model.TIMER_GAP - TIMER_LIFT) + ctx.timer.y)
	end
	local shadow = Widgets.Border(skin)
	count:SetShadowColor(Tokens.Color("textShadow"))
	count:SetShadowOffset(shadow, -shadow)
	local corner = ctx.count.position
	local signs = ns.Model.CORNER_SIGNS[corner]
	Widgets.Point(count, corner, skin, corner, signs[1] * edge + ctx.count.x, signs[2] * edge + ctx.count.y)
	count:SetAlpha(ctx.count.shown and 1 or 0)
	timer:SetJustifyH("CENTER")
	count:SetJustifyH(signs[3])
	badge:ClearAllPoints()
	badge:SetAllPoints(skin)
end

local function BindTimer(entry, ctx)
	local button, timer = entry.button, entry.timer
	if ctx.timer.format == "none" then
		button:ClearDurationText()
		timer:Hide()
		return
	end
	timer:Show()
	button:SetDurationText(timer, ctx.timerOptions)
end

local function BindDispel(entry, ctx)
	local slice = entry.dispel
	if not slice then
		return
	end
	local button = entry.button
	button:ClearDispelTypeTextures()
	local typeIcon = entry.typeIcon
	if typeIcon and ctx.typeIconOptions then
		button:AddDispelTypeTexture(typeIcon, ctx.typeIconOptions)
	elseif typeIcon and entry.typeBound then
		typeIcon:Hide()
	end
	entry.typeBound = typeIcon ~= nil and ctx.typeIconOptions ~= nil
	if not (ctx.group.dispel and ctx.dispelOptions) then
		Widgets.ShowSlice(slice, false)
		return
	end
	for i = 1, #slice do
		button:AddDispelTypeTexture(slice[i], ctx.dispelOptions)
	end
end

function Button.Bind(entry, ctx)
	local button = entry.button
	button:SetIcon(entry.icon)
	BindTimer(entry, ctx)
	button:SetApplicationCount(entry.count)
	if type(button.SetApplicationBar) == "function" then
		button:SetApplicationBar(entry.badge, { minApplications = MIN_APPLICATIONS, maxApplications = MAX_APPLICATIONS })
	else
		LogOnce("badge", "CustomAuraButton has no SetApplicationBar; the stack badge stays hidden")
		entry.badge:Hide()
	end
	BindDispel(entry, ctx)
	if type(button.SetDurationCooldown) == "function" and type(button.ClearDurationCooldown) == "function" then
		if ctx.group.swipe and entry.swipe then button:SetDurationCooldown(entry.swipe) else button:ClearDurationCooldown() end
	end
	if ctx.group.cancel ~= nil then
		button:SetCancelAuraButtons(ctx.group.cancel and CANCEL_CLICK or nil)
	end
	local tooltips = ctx.group.tooltips
	if (entry.tooltips or "always") ~= tooltips and type(button.SetHideTooltipInCombat) == "function" and type(button.SetMouseMotionEnabled) == "function" then
		button:SetHideTooltipInCombat(tooltips == "noCombat")
		button:SetMouseMotionEnabled(tooltips ~= "never")
		entry.tooltips = tooltips
	end
	local cue, refresh = entry.cue, ctx.group.refresh
	if cue and (entry.cueBound == true) ~= refresh then
		if type(button.AddPandemicRegion) ~= "function" or type(button.RemovePandemicRegion) ~= "function" then
			LogOnce("pandemic", "CustomAuraButton has no pandemic regions; the refresh mark stays hidden")
		elseif refresh then
			button:AddPandemicRegion(cue)
			entry.cueBound = true
		else
			button:RemovePandemicRegion(cue)
			cue:Hide()
			entry.cueBound = false
		end
	end
end

local function Extras(entry, ctx, inset)
	local skin, group = entry.skin, ctx.group
	local corner = group.typeIcon
	if entry.dispel and corner and corner ~= "none" then
		entry.typeIcon = entry.typeIcon or entry.over:CreateTexture(nil, "OVERLAY")
		local signs, size = ns.Model.CORNER_SIGNS[corner], Widgets.Snap(skin, group.typeIconSize)
		entry.typeIcon:SetSize(size, size)
		entry.typeIcon:ClearAllPoints()
		Widgets.Point(entry.typeIcon, corner, skin, corner, signs[1] * inset, signs[2] * inset)
		local beside = ctx.count.shown and ctx.count.position == corner and BESIDE_ICON[corner]
		if beside then
			entry.count:ClearAllPoints()
			entry.count:SetPoint(beside[1], entry.typeIcon, beside[2], beside[3] * inset + ctx.count.x, ctx.count.y)
		end
	end
	if group.refresh and not entry.cue then
		local cue = entry.over:CreateTexture(nil, "OVERLAY")
		cue:SetColorTexture(Widgets.Rgba("capsGold", 0.8))
		cue:SetHeight(2)
		cue:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", 2, 0)
		cue:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -2, 0)
		cue:Hide()
		entry.cue = cue
	end
end

function Button.Style(entry, ctx)
	local button, skin = entry.button, entry.skin
	button:SetSize(ctx.width, ctx.height)
	skin:ClearAllPoints()
	skin:SetPoint("TOP", button, "TOP", 0, 0)
	skin:SetSize(ctx.icon, ctx.icon)
	local edge = ctx.edge
	if K.HudStyle.Current() == "medallions" and K.Store.Module(ns.Model.MODULE).medallionsIcons then edge = { Tokens.Color("medSocketRim") } end
	Widgets.ColorSlice(entry.rim, edge[1], edge[2], edge[3], edge[4])
	Widgets.ShowSlice(entry.rim, true)
	local inset = Widgets.Border(skin) * ICON_INSET_LINES
	local icon = entry.icon
	local crop = ctx.iconZoom
	icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
	icon:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
	if ctx.group.swipe and not entry.swipe then
		local swipe = CreateFrame("Cooldown", nil, skin, "CooldownFrameTemplate")
		swipe:SetDrawSwipe(true)
		swipe:SetHideCountdownNumbers(true)
		swipe:SetDrawEdge(false)
		swipe:SetDrawBling(false)
		swipe:SetSwipeColor(Widgets.Rgba("black", 0.65))
		entry.swipe = swipe
	end
	if entry.swipe then
		Widgets.Cover(entry.swipe, icon)
		local reverse = ctx.group.swipeReverse ~= false
		if entry.reverse ~= reverse then
			entry.swipe:SetReverse(reverse)
			entry.reverse = reverse
		end
		entry.swipe:SetShown(ctx.group.swipe)
	end
	PlaceTexts(entry, ctx, inset)
	Extras(entry, ctx, inset)
	if Engine(button) then
		Button.Bind(entry, ctx)
	end
end
