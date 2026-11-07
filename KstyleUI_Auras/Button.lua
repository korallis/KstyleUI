-- Button.lua: dresses an engine aura button in the kit's chamfered icon tile and hands its icon, timer, stack count and dispel border to the engine.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens

local Button = {}
ns.Button = Button

local ICON_CROP = 0.07
local ICON_INSET_LINES = 2
local TEXT_INSET = 2
local TIMER_GAP = 1
local DISPEL_SUBLEVEL = 7
local CANCEL_CLICK = "RightButtonUp"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"

local logged = {}

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(ns.Model.MODULE, message)
	end
end

function Button.StyleText(text, spec, colorName)
	local flags = ns.Model.Flags(spec.outline)
	if text:SetFont(spec.font, spec.size, flags) == false then
		local path = Tokens.Font("number")
		text:SetFont(path, spec.size, flags)
		LogOnce("font:" .. tostring(spec.font), "the font " .. tostring(spec.font) .. " did not load; aura text uses " .. tostring(path))
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
	local ok = pcall(text.SetTextColor, text, Tokens.Color(colorName or "textEmphasis"))
	if not ok then
		LogOnce("color", "the engine holds an aura text's colour; it keeps the engine's colour")
	end
end

function Button.Create(button, hasDispel)
	local skin = CreateFrame("Frame", nil, button)
	local chrome = Widgets.Chrome(skin, { shape = "tile", fill = "raised", shadow = false })
	local restyleChrome = chrome.Restyle
	chrome.Restyle = function(self)
		if ns.Panel.Open() then
			return restyleChrome(self)
		end
		ns.Panel.Wait()
	end
	local icon = skin:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = skin:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("iconMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	local entry = {
		button = button,
		skin = skin,
		chrome = chrome,
		restyleChrome = restyleChrome,
		icon = icon,
		mask = mask,
		timer = skin:CreateFontString(nil, "OVERLAY"),
		count = skin:CreateFontString(nil, "OVERLAY"),
	}
	if hasDispel then
		entry.dispel = Widgets.NineSlice(skin, "chamferTile", "BORDER", DISPEL_SUBLEVEL)
		Widgets.ShowSlice(entry.dispel, false)
	end
	return entry
end

local function PlaceTexts(entry, ctx, inset)
	local skin, timer, count = entry.skin, entry.timer, entry.count
	Button.StyleText(timer, ctx.timer)
	Button.StyleText(count, ctx.count)
	timer:ClearAllPoints()
	count:ClearAllPoints()
	local text = Widgets.Snap(skin, TEXT_INSET)
	if ctx.timer.position == "inside" then
		timer:SetPoint("BOTTOM", skin, "BOTTOM", 0, inset + text)
		count:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -inset - text, -inset - text)
	else
		timer:SetPoint("TOP", skin, "BOTTOM", 0, -Widgets.Snap(skin, TIMER_GAP))
		count:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset - text, inset + text)
	end
	timer:SetJustifyH("CENTER")
	count:SetJustifyH("RIGHT")
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
	entry.restyleChrome(entry.chrome)
	local edge = ctx.edge
	entry.chrome:SetEdgeRGBA(edge[1], edge[2], edge[3], edge[4])
	local inset = Widgets.Border(skin) * ICON_INSET_LINES
	local icon = entry.icon
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
	icon:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
	if entry.dispel then
		local _, _, corner = Tokens.Texture("chamferTile")
		Widgets.LayoutSlice(entry.dispel, skin, corner, 0)
	end
	PlaceTexts(entry, ctx, inset)
	Button.Bind(entry, ctx)
end
