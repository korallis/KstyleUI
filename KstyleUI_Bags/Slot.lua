-- Slot.lua: one item slot: Blizzard's container item button dressed as a KstyleUI tile with quality, count, item level, junk, new and search states.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, Motion = K.Widgets, K.Tokens, K.Theme, K.Motion
local Settings = ns.Settings
local tostring = tostring

local Slot = {}
ns.Slot = Slot

Slot.TEMPLATE = "ContainerFrameItemButtonTemplate"

local ICON_INSET_LINES = 2
local TEXT_INSET = 2
local ICON_CROP = 0.07
local DIM_ALPHA = 0.25
local EMPTY_FILL_ALPHA = 0.55
local JUNK_SIZE = 8
local SWIPE_ALPHA = 0.65
local OVERLAY_LEVEL = 2
local FALLBACK_FONT = "NumberFontNormal"
local NEW_ATLAS = "bags-glow-white"
local NEW_LOW, NEW_HIGH = 0.3, 1
local NEW_REST = 0.8

local bySlotButton = setmetatable({}, { __mode = "k" })

local function Accent()
	return Settings.Accent()
end

local function PlaceIcon(slot)
	local button = slot.button
	if not Widgets.MayMove(button) then
		return
	end
	local offset = Widgets.Snap(button, Tokens.Size("pressOffset") * (slot.pressT or 0))
	if slot.placedOffset == offset and slot.placedInset == slot.inset then
		return
	end
	slot.placedOffset, slot.placedInset = offset, slot.inset
	local inset = slot.inset or 0
	slot.icon:ClearAllPoints()
	slot.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset - offset)
	slot.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset - offset)
end

local function EdgeColor(slot)
	local state = slot.state
	if state.coloured then
		local r, g, b = Theme.QualityColor(state.quality)
		return r, g, b, 1
	end
	if state.empty then
		return Widgets.Rgba("edgeInner")
	end
	return Widgets.IconRim(Accent())
end

function Slot.Paint(slot)
	local state = slot.state
	local hover, press = slot.hoverT or 0, slot.pressT or 0
	local r, g, b, a = EdgeColor(slot)
	local t = hover > press and hover or press
	if t > 0 then
		local ar, ag, ab = Accent()
		r, g, b, a = Widgets.Mix(r, g, b, a, ar, ag, ab, 1, t)
	end
	if state.empty and t == 0 then
		slot.chrome:SetRim()
	else
		slot.chrome:SetRim(r, g, b, a)
	end
	if state.empty then
		slot.chrome:SetFillRGBA(Widgets.Rgba("buttonFill", EMPTY_FILL_ALPHA))
	else
		slot.chrome:SetFillRGBA(Tokens.Color("buttonFill"))
	end
	slot.icon:SetAlpha(state.match and 1 or DIM_ALPHA)
	slot.icon:SetDesaturated(state.locked == true)
	local textAlpha = state.match and 1 or DIM_ALPHA
	slot.count:SetAlpha(textAlpha)
	slot.level:SetAlpha(textAlpha)
	PlaceIcon(slot)
end

local function ApplyFont(text)
	local path, size, flags = Settings.Font()
	if text:SetFont(path, size, flags) == false then
		text:SetFontObject(FALLBACK_FONT)
		ns.Log("the slot font " .. tostring(path) .. " did not load; slot text uses " .. FALLBACK_FONT)
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
end

function Slot.Style(slot)
	ApplyFont(slot.count)
	ApplyFont(slot.level)
	if slot.glow then
		slot.glow:Restyle()
	end
end

local Mark = {}
Mark.__index = Mark

function Mark:IsPlaying()
	return self.playing
end

function Mark:Restyle()
	local r, g, b = Accent()
	self.texture:SetVertexColor(r, g, b, 1)
	if not self.playing then
		return
	end
	if Motion.ReducedMotion() then
		self.pulse:Stop()
		self.texture:SetAlpha(NEW_REST)
	elseif not self.pulse:IsPlaying() then
		self.pulse:Play()
	end
end

function Mark:Start()
	if self.playing then
		return
	end
	self.playing = true
	self.texture:SetAlpha(NEW_HIGH)
	self.texture:Show()
	self:Restyle()
end

function Mark:Stop()
	if not self.playing then
		return
	end
	self.playing = false
	self.pulse:Stop()
	self.texture:Hide()
end

local function NewMark(slot)
	local overlay, icon = slot.overlay, slot.icon
	local texture = overlay:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints(icon)
	local atlases = C_Texture
	if atlases and atlases.GetAtlasInfo and atlases.GetAtlasInfo(NEW_ATLAS) then
		texture:SetAtlas(NEW_ATLAS)
	else
		texture:SetTexture((Tokens.Texture("glow")))
	end
	texture:SetBlendMode("ADD")
	local mask = overlay:CreateMaskTexture()
	mask:SetTexture(Tokens.Texture("iconMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	texture:AddMaskTexture(mask)
	texture:Hide()
	local pulse = texture:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(NEW_HIGH)
	fade:SetToAlpha(NEW_LOW)
	fade:SetDuration(Tokens.Duration("procPulse") / 2)
	fade:SetSmoothing("IN_OUT")
	return setmetatable({ texture = texture, mask = mask, pulse = pulse, playing = false }, Mark)
end

function Slot.Layout(slot, size, force)
	local button = slot.button
	if (slot.size == size and not force) or not Widgets.MayMove(button) then
		return
	end
	slot.size = size
	Widgets.Size(button, size, size)
	slot.inset = Widgets.Border(button) * ICON_INSET_LINES
	slot.placedOffset = nil
	local inset = Widgets.Snap(button, TEXT_INSET)
	slot.count:ClearAllPoints()
	slot.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
	slot.level:ClearAllPoints()
	slot.level:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset, inset)
	local junkSize = Widgets.Snap(button, JUNK_SIZE)
	slot.junk:SetSize(junkSize, junkSize)
	slot.junk:ClearAllPoints()
	slot.junk:SetPoint("TOPRIGHT", button, "TOPRIGHT", -inset, -inset)
	slot.chrome:Restyle()
	Slot.Paint(slot)
end

local function SetGlow(slot, on)
	if on then
		if not slot.glow then
			slot.glow = NewMark(slot)
		end
		slot.glow:Start()
	elseif slot.glow then
		slot.glow:Stop()
	end
end

function Slot.Update(slot, record, level, match, packed)
	local state = slot.state
	local empty = record.empty == true
	state.empty = empty
	state.match = match ~= false
	state.locked = record.locked == true
	state.quality = record.quality
	local quality = record.quality
	state.coloured = not empty and Settings.Get("showQuality") and quality ~= nil and quality >= Settings.Get("qualityMin")
	slot.icon:SetTexture(not empty and record.icon or nil)
	local count = record.count
	if empty and type(packed) == "number" and packed > 1 then
		slot.count:SetText(tostring(packed))
		slot.count:Show()
	elseif not empty and Settings.Get("showCount") and count and count > 1 then
		slot.count:SetText(tostring(count))
		slot.count:Show()
	else
		slot.count:Hide()
	end
	if level and Settings.Get("showItemLevel") then
		slot.level:SetText(tostring(level))
		slot.level:SetTextColor(Theme.QualityColor(quality))
		slot.level:Show()
	else
		slot.level:Hide()
	end
	slot.junk:SetShown(not empty and record.junk == true and Settings.Get("showJunk"))
	state.isNew = not empty and record.isNew == true
	SetGlow(slot, state.isNew and Settings.Get("showNewGlow"))
	Slot.Paint(slot)
end

function Slot.SetMatch(slot, match)
	slot.state.match = match ~= false
	Slot.Paint(slot)
end

function Slot.SetLocked(slot, locked)
	slot.state.locked = locked == true
	Slot.Paint(slot)
end

function Slot.SetCooldown(slot, start, duration, enable)
	start, duration, enable = ns.Data.Plain(start, "number"), ns.Data.Plain(duration, "number"), ns.Data.Plain(enable, "number")
	if start and duration and duration > 0 and enable ~= 0 then
		slot.cooldown:SetCooldown(start, duration)
	else
		slot.cooldown:Clear()
	end
end

function Slot.Unmark(slot)
	slot.state.isNew = false
	SetGlow(slot, false)
end

local function SetHover(slot, t)
	slot.hoverT = t
	Slot.Paint(slot)
end

local function SetPress(slot, t)
	slot.pressT = t
	Slot.Paint(slot)
end

local function OnEnter(button)
	local slot = bySlotButton[button]
	if not slot then
		return
	end
	Motion.Tween(slot, SetHover, slot.hoverT or 0, 1, Tokens.Duration("hover"), Tokens.Easing("hover"))
	if slot.state.isNew then
		Slot.Unmark(slot)
		local newItems = C_NewItems
		local bag = slot.bag
		if newItems and newItems.RemoveNewItem and bag then
			newItems.RemoveNewItem(bag, slot.id)
		end
	end
end

local function OnLeave(button)
	local slot = bySlotButton[button]
	if slot then
		Motion.Tween(slot, SetHover, slot.hoverT or 0, 0, Tokens.Duration("hover"), Tokens.Easing("hover"))
	end
end

local function OnMouseDown(button)
	local slot = bySlotButton[button]
	if slot then
		Motion.Tween(slot, SetPress, slot.pressT or 0, 1, Tokens.Duration("hover"), Tokens.Easing("hover"))
	end
end

local function OnMouseUp(button)
	local slot = bySlotButton[button]
	if slot then
		Motion.Tween(slot, SetPress, slot.pressT or 0, 0, Tokens.Duration("hover"), Tokens.Easing("hover"))
	end
end

local function Quiet(texture)
	if texture then
		texture:SetAlpha(0)
	end
end

function Slot.New(parent, id, opts)
	opts = opts or {}
	local button
	if opts.secure then
		button = CreateFrame("ItemButton", nil, parent, Slot.TEMPLATE)
	else
		button = CreateFrame("Button", nil, parent)
	end
	button:SetID(id)
	Quiet(button:GetNormalTexture())
	Quiet(button:GetPushedTexture())
	Quiet(button:GetHighlightTexture())
	local store = button.BattlepayItemTexture
	if store then
		store:Hide()
	end
	local slot = { button = button, id = id, bag = opts.bag, state = { empty = true, match = true }, record = {} }
	slot.chrome = Widgets.IconChrome(button)
	local maskPath = Tokens.Texture("iconMask")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = button:CreateMaskTexture()
	mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	slot.icon, slot.mask = icon, mask
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(icon)
	cooldown:SetSwipeTexture(maskPath)
	cooldown:SetSwipeColor(Widgets.Rgba("black", SWIPE_ALPHA))
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	slot.cooldown = cooldown
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints(button)
	overlay:SetFrameLevel(cooldown:GetFrameLevel() + OVERLAY_LEVEL)
	slot.overlay = overlay
	slot.count = Widgets.FontString(overlay, "OVERLAY")
	slot.count:SetTextColor(Tokens.Color("textEmphasis"))
	slot.count:Hide()
	slot.level = Widgets.FontString(overlay, "OVERLAY")
	slot.level:Hide()
	slot.junk = overlay:CreateTexture(nil, "OVERLAY")
	slot.junk:SetTexture((Tokens.Texture("dot")))
	Widgets.Tint(slot.junk, "neutral")
	slot.junk:Hide()
	bySlotButton[button] = slot
	button:HookScript("OnEnter", OnEnter)
	button:HookScript("OnLeave", OnLeave)
	button:HookScript("OnMouseDown", OnMouseDown)
	button:HookScript("OnMouseUp", OnMouseUp)
	Slot.Style(slot)
	return slot
end
