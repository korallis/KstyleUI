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
local FIGURE_INSET = 3
local DIM_ALPHA = 0.25
local EMPTY_FILL_ALPHA = 0.55
local JUNK_SIZE = 8
local SWIPE_ALPHA = 0.65
local OVERLAY_LEVEL = 2
local FALLBACK_FONT = "NumberFontNormal"
local NEW_ATLAS = "bags-glow-white"
local NEW_LOW, NEW_HIGH = 0.3, 1
local NEW_REST = 0.8
local STRIPE_LIFT = 0.06
local LIST_TEXT_GAP = 6
local LIST_FIGURE_ROOM = 36

local bySlotButton = setmetatable({}, { __mode = "k" })
local NONE = {}

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
	if slot.list then
		slot.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", slot.height - inset, inset - offset)
	else
		slot.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset - offset)
	end
end

local function EdgeColor(slot)
	local state = slot.state
	if state.coloured then
		local r, g, b = Theme.QualityColor(state.quality, Settings.Get("qualityColors"))
		return r, g, b, 1
	end
	if state.empty then
		return Widgets.Rgba("edgeInner")
	end
	if Settings.Get("qualityColors") then return Tokens.Color("slotRim") end
	return Widgets.IconRim(Accent())
end

function Slot.Paint(slot)
	local state = slot.state
	local hover, press = slot.hoverT or 0, slot.pressT or 0
	local r, g, b, a = EdgeColor(slot)
	local t = hover > press and hover or press
	if state.drop then
		t = 1
	end
	if t > 0 then
		local ar, ag, ab = Accent()
		r, g, b, a = Widgets.Mix(r, g, b, a, ar, ag, ab, 1, t)
	end
	if state.empty and t == 0 then
		slot.chrome:SetRim()
	else
		slot.chrome:SetRim(r, g, b, a)
	end
	if slot.stripe then
		local fr, fg, fb, fa = Widgets.Rgba("buttonFill", state.empty and EMPTY_FILL_ALPHA or 1)
		slot.chrome:SetFillRGBA(Widgets.Mix(fr, fg, fb, fa, 1, 1, 1, fa, STRIPE_LIFT))
	elseif state.empty then
		slot.chrome:SetFillRGBA(Widgets.Rgba("buttonFill", EMPTY_FILL_ALPHA))
	else
		slot.chrome:SetFillRGBA(Tokens.Color("buttonFill"))
	end
	slot.icon:SetAlpha(state.match and 1 or DIM_ALPHA)
	slot.icon:SetDesaturated(state.locked == true or state.junk == true and Settings.Get("desaturateJunk"))
	local textAlpha = state.match and 1 or DIM_ALPHA
	slot.count:SetAlpha(textAlpha)
	slot.level:SetAlpha(textAlpha)
	if slot.labeled then
		if slot.bind then slot.bind:SetAlpha(textAlpha) end
		if slot.set then slot.set:SetAlpha(textAlpha) end
		if slot.name then slot.name:SetAlpha(textAlpha) end
	end
	PlaceIcon(slot)
end

local function ApplyFont(text, path, size, flags)
	if not Widgets.ApplyFont(text, path, size, flags) then
		text:SetFontObject(FALLBACK_FONT)
		Widgets.TextShadow(text, flags)
		ns.Log("the slot font " .. tostring(path) .. " did not load; slot text uses " .. FALLBACK_FONT)
	end
end

function Slot.Style(slot)
	local crop = Settings.Get("iconZoom") / 100
	slot.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	local path, size, flags = Settings.Font()
	ApplyFont(slot.count, path, size, flags)
	ApplyFont(slot.level, path, size, flags)
	local swipe = Settings.Get("cooldownSwipeOnly")
	if swipe or slot.swipeOnly then
		slot.cooldown:SetHideCountdownNumbers(swipe)
		slot.swipeOnly = swipe
	end
	if slot.bind then ApplyFont(slot.bind, path, Settings.Get("labelSize"), flags) end
	if slot.set then ApplyFont(slot.set, path, Settings.Get("labelSize"), flags) end
	if slot.name then
		ApplyFont(slot.name, path, Settings.Get("listFontSize"), flags)
	end
	if slot.mark then
		local mark = Widgets.Snap(slot.button, Settings.Get("reagentMarkSize"))
		slot.mark:SetSize(mark, mark)
	end
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

local function Place(slot)
	local button, list = slot.button, slot.list
	local inset = Widgets.Snap(button, TEXT_INSET)
	local separate = Settings.Get("separateFigures")
	local figure = separate and Widgets.Snap(button, FIGURE_INSET) or inset
	local corner = separate and "TOPLEFT" or "BOTTOMLEFT"
	local edge, y = separate and "BOTTOM" or "TOP", separate and inset or -inset
	local text = slot.bind
	if text then
		text:ClearAllPoints()
		if list then
			text:SetPoint("RIGHT", slot.level, "LEFT", -Widgets.Snap(button, LIST_TEXT_GAP), 0)
		else
			text:SetPoint(edge .. "RIGHT", button, edge .. "RIGHT", -inset, y)
		end
	end
	text = slot.set
	if text then
		text:ClearAllPoints()
		text:SetPoint(edge .. "LEFT", button, edge .. "LEFT", inset, y)
		text:SetPoint(edge .. "RIGHT", button, edge .. "RIGHT", -inset, y)
	end
	text = slot.name
	if text then
		text:ClearAllPoints()
		text:SetPoint("LEFT", button, "LEFT", slot.height + Widgets.Snap(button, LIST_TEXT_GAP), 0)
		text:SetPoint("RIGHT", button, "RIGHT", -Widgets.Snap(button, LIST_FIGURE_ROOM), 0)
	end
	if slot.mark then
		slot.mark:ClearAllPoints()
		slot.mark:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset, inset)
	end
	slot.count:ClearAllPoints()
	slot.level:ClearAllPoints()
	if list then
		slot.count:SetPoint("RIGHT", button, "RIGHT", -inset, 0)
		slot.level:SetPoint("RIGHT", button, "RIGHT", -inset, 0)
	else
		slot.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -figure, figure)
		slot.level:SetPoint(corner, button, corner, figure, separate and -figure or figure)
	end
end

function Slot.Layout(slot, size, force, height)
	local button = slot.button
	if (slot.size == size and slot.rowHeight == height and not force) or not Widgets.MayMove(button) then
		return
	end
	slot.size, slot.rowHeight, slot.list, slot.height = size, height, height ~= nil, height or size
	slot.labeled = slot.labeled or slot.list
	Widgets.Size(button, size, slot.height)
	slot.inset = Widgets.Border(button) * ICON_INSET_LINES
	slot.placedOffset = nil
	local inset = Widgets.Snap(button, TEXT_INSET)
	Place(slot)
	local junkSize = Widgets.Snap(button, JUNK_SIZE)
	slot.junk:SetSize(junkSize, junkSize)
	slot.junk:ClearAllPoints()
	slot.junk:SetPoint("TOPRIGHT", button, slot.list and "TOPLEFT" or "TOPRIGHT", slot.list and slot.height - inset or -inset, -inset)
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

local function Region(slot, key, on)
	local region = slot[key]
	if on and not region then
		if key == "mark" then
			region = slot.overlay:CreateTexture(nil, "OVERLAY")
			region:SetTexture((Tokens.Texture("diamond")))
			Widgets.Tint(region, "capsGold")
		else
			region = Widgets.FontString(slot.overlay, "OVERLAY")
			region:SetWordWrap(false)
			region:SetJustifyH(key == "set" and "CENTER" or "LEFT")
			region:SetTextColor(Tokens.Color(key == "set" and "muted" or "textEmphasis"))
		end
		slot[key], slot.labeled = region, true
		Slot.Style(slot)
		Place(slot)
	end
	if region and slot[key .. "On"] ~= on then
		slot[key .. "On"] = on
		region:SetShown(on)
	end
	return region
end

local function Label(slot, key, text)
	local region = Region(slot, key, text ~= nil)
	if text then
		region:SetText(text)
	end
	return region
end

function Slot.SetStripe(slot, on)
	if slot.stripe ~= on then
		slot.stripe = on
		Slot.Paint(slot)
	end
end

function Slot.Update(slot, record, level, match, packed, extra, shownCount)
	local state = slot.state
	local empty = record.empty == true
	state.empty = empty
	if slot.dropTarget then
		state.drop = empty and type(packed) == "number" and ns.Data.CursorItem() ~= nil
		slot.dropTarget:SetShown(state.drop)
	end
	state.match = match ~= false
	state.locked = record.locked == true
	state.junk = record.junk == true
	state.quality = record.quality
	local quality = record.quality
	state.coloured = not empty and Settings.Get("showQuality") and quality ~= nil and quality >= Settings.Get("qualityMin")
	slot.icon:SetTexture(not empty and record.icon or nil)
	local count = shownCount or record.count
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
		slot.level:SetTextColor(Theme.QualityColor(quality, Settings.Get("qualityColors")))
		slot.level:Show()
	else
		slot.level:Hide()
	end
	slot.junk:SetShown(not empty and record.junk == true and Settings.Get("showJunk"))
	if extra or slot.labeled then
		extra = extra or NONE
		if extra.bind or slot.bind then
			Label(slot, "bind", not empty and extra.bind or nil)
		end
		if extra.set or slot.set then
			Label(slot, "set", not empty and not slot.list and extra.set or nil)
		end
		if slot.list or slot.name then
			local name = slot.list and not empty and record.name or nil
			if name and extra.set then
				name = name .. " \194\183 " .. extra.set
			end
			local nameText = Label(slot, "name", name)
			if name then
				nameText:SetTextColor(Theme.QualityColor(quality, Settings.Get("qualityColors")))
			end
		end
		if extra.mark or slot.mark then
			Region(slot, "mark", not empty and extra.mark == true)
		end
	end
	state.isNew = not empty and record.isNew == true
	SetGlow(slot, state.isNew and Settings.Get("showNewGlow"))
	Slot.Paint(slot)
end

function Slot.SetDrop(slot, on)
	if slot.state.drop ~= on then
		slot.state.drop = on
		if slot.dropTarget then
			slot.dropTarget:SetShown(on)
		end
		Slot.Paint(slot)
	end
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
	if ns.Quick.on then
		ns.Quick.Enter(slot)
	end
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
		if ns.Quick.on then
			ns.Quick.Leave()
		end
	end
end

local function OnMouseDown(button)
	local slot = bySlotButton[button]
	if slot then
		Motion.Tween(slot, SetPress, slot.pressT or 0, 1, Motion.Slides() and Tokens.Duration("hover") or 0, Tokens.Easing("hover"))
	end
end

local function OnMouseUp(button)
	local slot = bySlotButton[button]
	if slot then
		Motion.Tween(slot, SetPress, slot.pressT or 0, 0, Motion.Slides() and Tokens.Duration("hover") or 0, Tokens.Easing("hover"))
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
	local slot = { button = button, id = id, bag = opts.bag, pin = opts.pin, state = { empty = true, match = true }, record = {} }
	slot.chrome = Widgets.IconChrome(button)
	local maskPath = Tokens.Texture("iconMask")
	local icon = button:CreateTexture(nil, "ARTWORK")
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
	if opts.drop then
		local target = CreateFrame("Button", nil, overlay)
		target:SetAllPoints(button)
		target:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		target:RegisterForDrag("LeftButton")
		target:SetScript("OnClick", function(_, mouse)
			if mouse == "LeftButton" then
				opts.drop(slot.bag)
			end
		end)
		target:SetScript("OnReceiveDrag", function() opts.drop(slot.bag) end)
		bySlotButton[target] = slot
		target:HookScript("OnEnter", OnEnter)
		target:HookScript("OnLeave", OnLeave)
		target:HookScript("OnMouseDown", OnMouseDown)
		target:HookScript("OnMouseUp", OnMouseUp)
		target:Hide()
		slot.dropTarget = target
	end
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
	if opts.pin then
		button:HookScript("OnClick", function(_, mouse)
			if mouse == "LeftButton" and type(IsAltKeyDown) == "function" and ns.Data.Plain(IsAltKeyDown(), "boolean") then
				opts.pin(slot)
			end
		end)
	end
	Slot.Style(slot)
	return slot
end

local function HideTooltip()
	if type(GameTooltip_Hide) == "function" then
		GameTooltip_Hide()
	end
end

function Slot.NewBag(parent, id, pickup, tooltip)
	local slot = Slot.New(parent, id)
	local button = slot.button
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnClick", pickup)
	button:SetScript("OnDragStart", pickup)
	button:SetScript("OnReceiveDrag", pickup)
	button:HookScript("OnEnter", tooltip)
	button:HookScript("OnLeave", HideTooltip)
	return slot
end

function Slot.Row(panel, frame, slots, content, top, width)
	local size = Widgets.Snap(panel, Tokens.Size("rowHeight"))
	local gap = Widgets.Snap(panel, Tokens.Size("gapSmall"))
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	frame:SetSize(math.max(1, width), size)
	local x = 0
	for _, slot in ipairs(slots) do
		if slot.button:IsShown() then
			Slot.Layout(slot, size)
			slot.button:ClearAllPoints()
			slot.button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
			x = x + size + gap
		end
	end
	return top + size + Widgets.Snap(panel, Tokens.Size("gapMedium"))
end
