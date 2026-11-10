-- Button.lua: dresses an engine aura button as a plain square tile as the owner's picture draws it: the icon one border inside a one-pixel dark square rim, the timer under it in white in the body face on whole pixels (Widgets.ApplyFont), the stack count on a corner badge the engine shows from two applications, the engine's dispel plate on debuffs, and the engine bindings; a plain frame gets the same tile without the bindings, for the preview.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens

local Button = {}
ns.Button = Button

local ICON_CROP = 0.07
local ICON_INSET_LINES = 1
local TEXT_INSET = 1
local TIMER_LIFT = 0.5
local RIM_SUBLEVEL = 5
local DISPEL_SUBLEVEL = 7
local BADGE_PAD = 2
local BADGE_ALPHA = 0.6
local BADGE_LEVEL = 2
local MIN_APPLICATIONS = 2
local MAX_APPLICATIONS = 999
local CANCEL_CLICK = "RightButtonUp"

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

function Button.StyleText(text, spec, colorName)
	local flags = ns.Model.Flags(spec.outline)
	if not Widgets.ApplyFont(text, spec.font, spec.size, flags) then
		local path = Tokens.Font("number")
		Widgets.ApplyFont(text, path, spec.size, flags)
		LogOnce("font:" .. tostring(spec.font), "the font " .. tostring(spec.font) .. " did not load; aura text uses " .. tostring(path))
	end
	local ok = pcall(text.SetTextColor, text, Tokens.Color(colorName or "textEmphasis"))
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
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local over = CreateFrame("Frame", nil, skin)
	over:SetAllPoints(skin)
	over:SetFrameLevel(skin:GetFrameLevel() + BADGE_LEVEL)
	local badge = CreateFrame("StatusBar", nil, over)
	badge:SetStatusBarTexture((Tokens.Texture("barFlat")))
	badge:SetStatusBarColor(Widgets.Rgba("black", 0))
	badge:SetFrameLevel(over:GetFrameLevel())
	local plate = badge:CreateTexture(nil, "BACKGROUND")
	plate:SetAllPoints(badge)
	plate:SetColorTexture(Widgets.Rgba("black", BADGE_ALPHA))
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
		plate = plate,
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
	Button.StyleText(timer, ctx.timer, "timerText")
	Button.StyleText(count, ctx.count)
	timer:ClearAllPoints()
	count:ClearAllPoints()
	local text = Widgets.Snap(skin, TEXT_INSET)
	if ctx.timer.position == "inside" then
		timer:SetPoint("BOTTOM", skin, "BOTTOM", 0, inset + text)
	else
		timer:SetPoint("TOP", skin, "BOTTOM", 0, -Widgets.Snap(skin, ns.Model.TIMER_GAP - TIMER_LIFT))
	end
	count:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -inset, -inset)
	timer:SetJustifyH("CENTER")
	count:SetJustifyH("RIGHT")
	local pad = Widgets.Snap(skin, BADGE_PAD)
	badge:ClearAllPoints()
	badge:SetPoint("TOPLEFT", count, "TOPLEFT", -pad, pad)
	badge:SetPoint("BOTTOMRIGHT", count, "BOTTOMRIGHT", pad, -pad)
	entry.plate:SetColorTexture(Widgets.Rgba("black", BADGE_ALPHA))
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
	if ctx.group.cancel ~= nil then
		button:SetCancelAuraButtons(ctx.group.cancel and CANCEL_CLICK or nil)
	end
end

function Button.Style(entry, ctx)
	local button, skin = entry.button, entry.skin
	button:SetSize(ctx.width, ctx.height)
	skin:ClearAllPoints()
	skin:SetPoint("TOP", button, "TOP", 0, 0)
	skin:SetSize(ctx.icon, ctx.icon)
	local edge = ctx.edge
	Widgets.ColorSlice(entry.rim, edge[1], edge[2], edge[3], edge[4])
	Widgets.ShowSlice(entry.rim, true)
	local inset = Widgets.Border(skin) * ICON_INSET_LINES
	local icon = entry.icon
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
	icon:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
	PlaceTexts(entry, ctx, inset)
	if Engine(button) then
		Button.Bind(entry, ctx)
	end
end
