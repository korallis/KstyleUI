-- Totems.lua: the shaman's Spirit Poles, KstyleUI's own secure totem bar in place of Blizzard's MultiCastActionBarFrame: four element sockets in the game's bar order (earth, fire, water, air) drop the chosen totem from its multi-cast action slot, right click fans out that element's totems on a shallow arc between the crest's sockets and the cooldown row to choose one, one fan at a time (shift right click dismisses the totem), and each socket carries a crown spire that lights and burns down over the totem's life from the slot's own boolean and duration object, so Lua never reads a secret, and flickers through its last fifth at Full while the slot is readable; a chosen totem's icon rests at 82% until that totem is up, a fan unfolds from its socket over 0.12 s at Full and Calm, and with all four totems up the rune ring catches the shaman's class colour, a halo under the crest and the glyphs over it as on the hawks' ring, and breathes at Full; Ghost Wolf and Call of the Elements (right click: Totemic Recall) ride as medals on the Medallions crest ring's shoulders, the lone Ghost Wolf stance bar hides, and a vehicle or override bar hides the bar as it hides Blizzard's; without the crest Blizzard's bar stays.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects, L = K.Widgets, K.Tokens, K.Effects, K.L
local cos, sin, rad, deg, acos, max, min = math.cos, math.sin, math.rad, math.deg, math.acos, math.max, math.min
local IsSecret = Widgets.IsSecret

local Totems = {}
ns.Totems = Totems

local OWNER, LEARN = "ActionBars.Totems", "ActionBars.TotemsLearn"
local ELEMENTS = {
	{ slot = 2, name = "Earth", angle = 126, label = L["Earth totem"] },
	{ slot = 1, name = "Fire", angle = 102, label = L["Fire totem"] },
	{ slot = 3, name = "Water", angle = 78, label = L["Water totem"] },
	{ slot = 4, name = "Air", angle = 54, label = L["Air totem"] },
}
local CALL, RECALLS = 66842, { 36936, 437009 }
local SOCKET, RADIUS, SPIRE, SPIRE_LIFT, HALO = 26, 98, 34, 3, 1.5
local MEDAL, MEDAL_RADIUS, MEDAL_RISE, ICON = 26, 84, 32, 0.74
local FAN, FAN_RADIUS, FAN_DROP, FAN_STEP, FAN_SPAN = 26, 330, 200, 5.2, 32
local FLARE_RISE, FLARE_FALL, IGNITE = 0.05, 0.4, 0.3
local UNFOLD, FIFTH, IDLE_ICON, RING_HALO = 0.12, 0.2, 0.82, 1.6
local OVERRIDDEN = "[vehicleui][overridebar] hide; show"

local OPEN = [[
	if button ~= "RightButton" or IsShiftKeyDown() then return nil end
	local open = control:IsShown()
	for i = 1, 4 do control:GetFrameRef("fan" .. i):Hide() end
	if not open then
		control:Show()
		control:RegisterAutoHide(1.5)
		control:AddToAutoHide(self)
	end
	return false
]]

local state = { sockets = {} }
Totems.state = state

local function Supported()
	local index = C_ActionBar ~= nil and type(C_ActionBar.GetMultiCastBarIndex) == "function" and C_ActionBar.GetMultiCastBarIndex()
	return type(index) == "number" and not IsSecret(index) and index > 0 and type(GetMultiCastTotemSpells) == "function"
		and type(GetTotemInfo) == "function" and type(SecureHandlerWrapScript) == "function" and type(SecureHandlerSetFrameRef) == "function"
		and type(RegisterStateDriver) == "function"
end

local function Spells(slot)
	local list = { GetMultiCastTotemSpells(slot) }
	for i = #list, 1, -1 do
		if IsSecret(list[i]) or type(list[i]) ~= "number" then table.remove(list, i) end
	end
	return list
end

local function Known(ids)
	local book = C_SpellBook
	for _, id in ipairs(ids) do
		local known = book and type(book.IsSpellKnown) == "function" and book.IsSpellKnown(id)
		if not IsSecret(known) and known == true then return id end
	end
end

local function Wolf()
	if type(GetShapeshiftFormInfo) ~= "function" then return nil end
	for i = 1, ns.NumForms() do
		local spell = select(4, GetShapeshiftFormInfo(i))
		if not IsSecret(spell) and type(spell) == "number" then return i, spell end
	end
end

local function Wanted()
	local hub = ns.Slab.hub
	if not (state.enabled and ns.running and not ns.gamepad and ns.Config("totemBar") ~= false and ns.class == "SHAMAN" and hub and hub:IsShown() and Supported()) then
		return false
	end
	for _, e in ipairs(ELEMENTS) do
		if #Spells(e.slot) > 0 then return true end
	end
	return false
end

local function Gate(frame, value)
	frame:SetAlpha(1)
	if not IsSecret(value) then
		frame:SetShown(value == true)
	elseif frame.SetAlphaFromBoolean then
		frame:Show()
		frame:SetAlphaFromBoolean(value, 1, 0)
	else
		frame:Hide()
	end
end

local function Art(parent, layer, name, color, blend)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture((Tokens.Texture(name)))
	t:SetVertexColor(Tokens.Color(color))
	if blend then t:SetBlendMode(blend) end
	return t
end

local function Bar(parent, color, texture, blend)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetOrientation("VERTICAL")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	bar:SetStatusBarTexture((Tokens.Texture(texture)))
	if blend then bar:GetStatusBarTexture():SetBlendMode(blend) end
	bar:SetStatusBarColor(Tokens.Color(color))
	return bar
end

local function Fade(target, from, to, duration, order)
	target.anim = target.anim or target:CreateAnimationGroup()
	local a = target.anim:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	return a
end

local function Spire(parent, e)
	local s = CreateFrame("Frame", nil, parent)
	local color, angle = "totem" .. e.name, e.angle
	s.steel = s:CreateTexture(nil, "BACKGROUND")
	s.steel:SetTexture((Tokens.Texture("pipSpireSteel" .. angle)))
	s.steel:SetAllPoints(s)
	s.gate = CreateFrame("Frame", nil, s)
	s.gate:SetAllPoints(s)
	s.flicker = CreateFrame("Frame", nil, s.gate)
	s.flicker:SetAllPoints(s)
	Fade(s.flicker, 1, 0.4, 0.06)
	Fade(s.flicker, 0.4, 1, 0.08, 2)
	Fade(s.flicker, 1, 0.7, 0.05, 3)
	Fade(s.flicker, 0.7, 1, 0.06, 4):SetEndDelay(0.16)
	s.flicker.anim:SetLooping("REPEAT")
	s.glow = Bar(s.flicker, color, "pipSpireGlow" .. angle, "ADD")
	s.glow:SetPoint("CENTER", s, "CENTER", 0, 0)
	s.lit = Bar(s.flicker, "white", "pipSpire" .. angle)
	local r, g, b = Tokens.Color(color)
	s.lit:SetStatusBarColor(0.55 + 0.45 * r, 0.55 + 0.45 * g, 0.55 + 0.45 * b)
	s.lit:SetAllPoints(s)
	s.core = Bar(s.flicker, color, "pipSpireCore" .. angle, "ADD")
	s.core:SetAllPoints(s)
	s.ignite = s.gate:CreateAnimationGroup()
	local scale = s.ignite:CreateAnimation("Scale")
	scale:SetScaleFrom(1, 0.1)
	scale:SetScaleTo(1, 1)
	scale:SetOrigin("BOTTOM", 0, 0)
	scale:SetDuration(IGNITE)
	scale:SetSmoothing("OUT")
	s.flareGate = CreateFrame("Frame", nil, s)
	s.flareGate:SetAllPoints(s)
	s.flareGate:SetFrameLevel(s.gate:GetFrameLevel() + 3)
	s.flare = CreateFrame("Frame", nil, s.flareGate)
	s.flare:SetAllPoints(s)
	Art(s.flare, "ARTWORK", "pipSpireCore" .. angle, "totemCore", "ADD"):SetAllPoints(s.flare)
	Fade(s.flare, 0, 1, FLARE_RISE)
	Fade(s.flare, 1, 0, FLARE_FALL, 2)
	s.flare.anim:SetScript("OnFinished", function() s.flare:Hide() end)
	s.flare:Hide()
	s.rim = Art(s.gate, "OVERLAY", "medSlotChecked", color, "ADD")
	return s
end

local function Flicker(s, slot, have, start, duration)
	s.flicker.anim:Stop()
	if IsSecret(have) or IsSecret(start) or IsSecret(duration) or have ~= true or type(duration) ~= "number" or duration <= 0
		or type(GetTime) ~= "function" or not Effects.Allows("pulse") then
		s.fifth = nil
		return
	end
	local due = start + duration * (1 - FIFTH)
	if due <= GetTime() then
		s.fifth = nil
		s.flicker.anim:Play()
	elseif s.fifth ~= due and C_Timer and C_Timer.After then
		s.fifth = due
		C_Timer.After(due - GetTime(), function()
			if s.fifth ~= due then return end
			s.fifth = nil
			local up = GetTotemInfo(slot)
			if state.listening and not IsSecret(up) and up == true then s.flicker.anim:Play() end
		end)
	end
end

local function Rest(b)
	local have, id = b.have, b.active
	if not IsSecret(have) then
		local other = b.chosen and not IsSecret(id) and type(id) == "number" and id ~= b.chosen
		b.icon:SetAlpha(have == true and not other and 1 or IDLE_ICON)
	elseif b.icon.SetAlphaFromBoolean then
		b.icon:SetAlphaFromBoolean(have, 1, IDLE_ICON)
	end
end

local function PaintSpire(b, moving)
	local s, slot = b.spire, b.element.slot
	local have, _, start, duration, _, _, id = GetTotemInfo(slot)
	b.have, b.active = have, id
	Gate(s.gate, have)
	Rest(b)
	Flicker(s, slot, have, start, duration)
	local object = type(GetTotemDuration) == "function" and GetTotemDuration(slot)
	for _, bar in ipairs({ s.lit, s.core, s.glow }) do
		if object and bar.SetTimerDuration then
			local direction = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
			local interpolation = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
			bar:SetTimerDuration(object, interpolation, direction)
		else
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(1)
		end
	end
	s.flare.anim:Stop()
	s.flare:Hide()
	s.ignite:Stop()
	if moving and (IsSecret(have) or have == true) then
		Gate(s.flareGate, have)
		s.flare:Show()
		s.flare.anim:Play()
		s.ignite:Play()
	end
end

local function PaintSocket(b)
	local api, slot = C_ActionBar, b.slot
	local action = slot ~= nil and ns.SlotValid(slot) and api.HasAction(slot)
	local has = IsSecret(action) or action == true or action == 1
	b.hasAction = has
	if has then
		b:SetIcon(api.GetActionTexture(slot))
	else
		b:SetIcon(nil)
	end
	b.rune:SetShown(not has)
	local kind, id
	if has and type(GetActionInfo) == "function" then kind, id = GetActionInfo(slot) end
	local chosen = not IsSecret(kind) and kind == "spell" and not IsSecret(id) and id or nil
	if chosen ~= b.chosen then b.gcd = nil end
	b.chosen = chosen
	Rest(b)
	ns.Button.UpdateCooldown(b)
	ns.Button.UpdateUsable(b)
	for _, f in ipairs(b.fan.buttons) do
		f:SetSelected(chosen ~= nil and f:GetAttribute("spell") == chosen)
	end
end

local function PaintRing()
	local ring, breathe = state.ring, Effects.Allows("pulse")
	for i, b in ipairs(state.sockets) do
		Gate(ring[i], b.have)
		breathe = breathe and not IsSecret(b.have) and b.have == true
	end
	if breathe then
		if not ring.breath:IsPlaying() then ring.breath:Play() end
	else
		ring.breath:Stop()
	end
end

local function PaintMedals()
	local wolf = state.wolf
	local i = wolf and wolf.form
	if i then
		local texture, active = GetShapeshiftFormInfo(i)
		wolf.icon:SetTexture(texture)
		Gate(wolf.spirit, active)
	end
	if state.call and state.call.known then
		state.call.icon:SetTexture(C_Spell and type(C_Spell.GetSpellTexture) == "function" and C_Spell.GetSpellTexture(state.call.known) or nil)
	end
end

local function SocketTooltip(tip, b)
	local _, id = GetActionInfo(b.slot)
	local name = b.hasAction and not IsSecret(id) and C_Spell and type(C_Spell.GetSpellName) == "function" and C_Spell.GetSpellName(id)
	tip:AddTitle(type(name) == "string" and name or b.element.label)
	tip:AddLine(L["Left click: drop this totem"])
	tip:AddLine(L["Right click: choose a totem \194\183 Shift right click: dismiss it"])
end

local function FanTooltip(tip, f)
	local id = f:GetAttribute("spell")
	local name = id ~= 0 and C_Spell and type(C_Spell.GetSpellName) == "function" and C_Spell.GetSpellName(id)
	tip:AddTitle(type(name) == "string" and name or L["No totem"])
end

local function Choice(fan, e, first)
	local f = Widgets.Slot(fan, { template = "SecureActionButtonTemplate", size = FAN, silent = true })
	f.kind = "totem"
	f:RegisterForClicks("AnyUp")
	f:SetAttribute("useOnKeyDown", false)
	f:SetAttribute("type", "multispell")
	SecureHandlerWrapScript(f, "OnClick", fan, [[ return nil, true ]], [[ control:Hide() ]])
	Widgets.AttachTooltip(f, FanTooltip, "ANCHOR_TOP")
	Fade(f, 0, 1, UNFOLD, 2)
	f.from, f.to = f.anim:CreateAnimation("Translation"), f.anim:CreateAnimation("Translation")
	f.from:SetDuration(0)
	f.to:SetOrder(2)
	f.to:SetDuration(UNFOLD)
	f.to:SetSmoothing("OUT")
	f.shade = Art(f, "BACKGROUND", "glow", "black")
	f.shade:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.shade:SetAlpha(0.85)
	if first then
		f.rune = Art(f.overlay, "OVERLAY", "totemRune" .. e.name, "totem" .. e.name)
		f.rune:SetAllPoints(f.icon)
	end
	return ns.Socket.Decorate(f)
end

local function Unfold(fan)
	if Effects.Allows("flare") then
		for _, f in ipairs(fan.buttons) do f.anim:Play() end
	end
end

local function Socket(header, i, e)
	local b = Widgets.Slot(header, { name = "KstyleUI_TotemSlot" .. i, template = "SecureActionButtonTemplate", size = SOCKET, silent = true })
	b.kind, b.element = "totem", e
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("useOnKeyDown", false)
	b:SetAttribute("*type2", "destroytotem")
	b:SetAttribute("totem-slot", e.slot)
	b.rune = Art(b.overlay, "OVERLAY", "totemRune" .. e.name, "totem" .. e.name)
	b.rune:SetAllPoints(b.icon)
	b.rune:SetAlpha(0.55)
	b.tab = Art(b, "OVERLAY", "dot", "totem" .. e.name)
	b.fan = CreateFrame("Frame", nil, header, "SecureHandlerBaseTemplate")
	b.fan:SetFrameStrata("HIGH")
	b.fan:Hide()
	b.fan.buttons = {}
	b.fan:HookScript("OnShow", Unfold)
	SecureHandlerWrapScript(b, "OnClick", b.fan, OPEN)
	b.spire = Spire(header, e)
	Widgets.AttachTooltip(b, SocketTooltip, "ANCHOR_TOP")
	return ns.Socket.Decorate(b)
end

local function Medal(header, name, tooltip)
	local m = CreateFrame("Button", name, header, "SecureActionButtonTemplate")
	m:RegisterForClicks("AnyUp")
	m:SetAttribute("useOnKeyDown", false)
	m.shade = Art(m, "BACKGROUND", "glow", "black")
	m.shade:SetAlpha(0.7)
	m.icon = m:CreateTexture(nil, "ARTWORK")
	local mask = m:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("dot")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(m.icon)
	m.icon:AddMaskTexture(mask)
	Art(m, "OVERLAY", "medEnamel", "steel"):SetAllPoints(m)
	Art(m, "OVERLAY", "medRing", "white"):SetAllPoints(m)
	local hover = Art(m, "HIGHLIGHT", "glow", "white", "ADD")
	hover:SetAllPoints(m)
	hover:SetAlpha(0.35)
	Widgets.AttachTooltip(m, tooltip, "ANCHOR_TOP")
	return m
end

local function CallTooltip(tip)
	tip:AddTitle(L["Call of the Elements"])
	tip:AddLine(L["Left click: Call of the Elements \194\183 Right click: Totemic Recall"])
end

local function WolfTooltip(tip, m)
	local name = C_Spell and type(C_Spell.GetSpellName) == "function" and C_Spell.GetSpellName(m:GetAttribute("spell"))
	tip:AddTitle(type(name) == "string" and name or "")
end

local function Build()
	local header = CreateFrame("Frame", "KstyleUI_Totems", K.Scale.Root(), "SecureHandlerBaseTemplate")
	header:SetFrameStrata("MEDIUM")
	header:Hide()
	state.header = header
	for i, e in ipairs(ELEMENTS) do
		state.sockets[i] = Socket(header, i, e)
	end
	for _, a in ipairs(state.sockets) do
		for i, b in ipairs(state.sockets) do SecureHandlerSetFrameRef(a.fan, "fan" .. i, b.fan) end
	end
	local ring, parent = {}, header
	for i = 1, 5 do
		parent = CreateFrame("Frame", nil, parent)
		parent:SetAllPoints(header)
		if i == 1 then parent:SetFrameStrata(ns.Slab.STRATA) end
		ring[i] = parent
	end
	ring.halo = Art(parent, "BACKGROUND", "glow", "white", "ADD")
	ring.halo:SetPoint("CENTER", header, "CENTER", 0, 0)
	ring.glyphs = CreateFrame("Frame", nil, parent)
	ring.art = Art(ring.glyphs, "ARTWORK", "medRuneGlyphs", "white", "ADD")
	ring.art:SetAllPoints(header)
	Fade(parent, 1, ns.SlabEffects.CAP_LOW, ns.SlabEffects.CAP_BREATH):SetSmoothing("IN_OUT")
	ring.breath = parent.anim
	ring.breath:SetLooping("BOUNCE")
	state.ring = ring
	state.call = Medal(header, "KstyleUI_TotemCall", CallTooltip)
	state.call:SetAttribute("spell", CALL)
	local wolf = Medal(header, "KstyleUI_TotemWolf", WolfTooltip)
	wolf:SetAttribute("type", "spell")
	wolf.spirit = CreateFrame("Frame", nil, wolf)
	wolf.spirit:SetAllPoints(wolf)
	Art(wolf.spirit, "OVERLAY", "medEnamel", "totemSpirit", "ADD"):SetAllPoints(wolf.spirit)
	wolf.spirit:Hide()
	state.wolf = wolf
end

local function Fill()
	local base = (C_ActionBar.GetMultiCastBarIndex() - 1) * ns.BUTTONS_PER_PAGE
	for _, b in ipairs(state.sockets) do
		local e, fan = b.element, b.fan
		local spells = Spells(e.slot)
		b.slot, b.known = base + e.slot, #spells > 0
		b:SetAttribute("type", "action")
		b:SetAttribute("action", b.slot)
		local count = #spells + 1
		for n = #fan.buttons + 1, count do fan.buttons[n] = Choice(fan, e, n == 1) end
		local step = min(FAN_STEP, FAN_SPAN / max(1, count - 1))
		local half = (count - 1) * step / 2
		local aim = deg(acos(RADIUS * cos(rad(e.angle)) / FAN_RADIUS))
		local centre = max(90 - FAN_SPAN / 2 + half, min(90 + FAN_SPAN / 2 - half, aim))
		for n, f in ipairs(fan.buttons) do
			local spell = n == 1 and 0 or spells[n - 1]
			f:SetAttribute("action", b.slot)
			f:SetAttribute("spell", spell)
			f:SetIcon(spell and spell ~= 0 and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell) or nil)
			f.angle = centre + half - (n - 1) * step
			f:SetShown(n <= count)
		end
	end
	local call, recall = Known({ CALL }), Known(RECALLS)
	state.call:SetAttribute("*type1", call and "spell")
	state.call:SetAttribute("*type2", recall and "spell")
	state.call:SetAttribute("*spell2", recall)
	state.call.known = call or recall
	local form, spell = Wolf()
	state.wolf.form = form
	state.wolf:SetAttribute("spell", spell)
end

local function Put(frame, anchor, x, y, size)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", anchor, "CENTER", Widgets.Snap(frame, x), Widgets.Snap(frame, y))
	if size then Widgets.Size(frame, size, size) end
end

local function Place()
	local header, hub = state.header, ns.Slab.hub
	local own = header:GetParent():GetEffectiveScale()
	header:SetScale(own > 0 and hub:GetEffectiveScale() / own or 1)
	header:ClearAllPoints()
	header:SetAllPoints(hub)
	local half = SOCKET / 2
	for _, b in ipairs(state.sockets) do
		b:SetShown(b.known)
		b.spire:SetShown(b.known)
		local angle = b.element.angle
		local x, y = RADIUS * cos(rad(angle)), RADIUS * sin(rad(angle))
		Put(b, hub, x, y, SOCKET)
		b:Restyle()
		ns.Slab.Dress(b)
		local reach, size = half + SPIRE_LIFT + SPIRE / 2, Widgets.Snap(b.spire, SPIRE)
		b.spire:SetSize(size, size)
		b.spire.glow:SetSize(size * HALO, size * HALO)
		Put(b.spire, hub, x + reach * cos(rad(angle)), y + reach * sin(rad(angle)))
		b.spire.rim:ClearAllPoints()
		b.spire.rim:SetAllPoints(b)
		b.tab:ClearAllPoints()
		b.tab:SetPoint("TOP", b, "BOTTOM", 0, -1)
		Widgets.Size(b.tab, SOCKET * 0.6, 3)
		Put(b.fan, hub, 0, FAN_RADIUS - FAN_DROP - FAN)
		Widgets.Size(b.fan, 2 * FAN_RADIUS * sin(rad(FAN_SPAN / 2)) + 2 * FAN, 3 * FAN)
		for _, f in ipairs(b.fan.buttons) do
			local fx, fy = FAN_RADIUS * cos(rad(f.angle)), FAN_RADIUS * sin(rad(f.angle)) - FAN_DROP
			f.from:SetOffset(x - fx, y - fy)
			f.to:SetOffset(fx - x, fy - y)
			Put(f, hub, fx, fy, FAN)
			f:Restyle()
			ns.Slab.Dress(f)
			Widgets.Size(f.shade, FAN * 2.6, FAN * 2.6)
		end
	end
	for i = 1, 5 do state.ring[i]:SetFrameLevel(max(0, hub:GetFrameLevel() - 1)) end
	state.ring.glyphs:SetFrameLevel(hub:GetFrameLevel() + 1)
	Widgets.Size(state.ring.halo, ns.Slab.RING * RING_HALO, ns.Slab.RING * RING_HALO)
	local c = K.Theme.Palette("SHAMAN")
	for _, t in ipairs(c and { state.ring.halo, state.ring.art } or {}) do t:SetVertexColor(c.r, c.g, c.b) end
	state.call:SetShown(state.call.known ~= nil)
	state.wolf:SetShown(state.wolf.form ~= nil)
	for side, m in pairs({ [-1] = state.wolf, [1] = state.call }) do
		Put(m, hub, side * MEDAL_RADIUS * cos(rad(MEDAL_RISE)), MEDAL_RADIUS * sin(rad(MEDAL_RISE)), MEDAL)
		Widgets.Size(m.icon, MEDAL * ICON, MEDAL * ICON)
		m.icon:ClearAllPoints()
		m.icon:SetPoint("CENTER", m, "CENTER", 0, 0)
		Widgets.Size(m.shade, MEDAL * 1.9, MEDAL * 1.9)
		m.shade:SetPoint("CENTER", m, "CENTER", 0, 0)
	end
end

local function Hotkeys()
	for i, b in ipairs(state.sockets) do
		b:SetHotkey(Widgets.ShortKey(ns.FirstKey("CLICK KstyleUI_TotemSlot" .. i .. ":LeftButton")))
	end
end

local function OnTotem(_, slot)
	local moving = Effects.Allows("flare")
	for _, b in ipairs(state.sockets) do
		if IsSecret(slot) or b.element.slot == slot then
			PaintSpire(b, moving)
		end
	end
	PaintRing()
end

local function OnSlot(_, slot)
	for _, b in ipairs(state.sockets) do
		if IsSecret(slot) or slot == nil or slot == 0 or b.slot == slot then
			PaintSocket(b)
		end
	end
end

local function OnCooldown(event)
	for _, b in ipairs(state.sockets) do
		ns.Button.UpdateCooldown(b, event == "SPELL_UPDATE_COOLDOWN")
	end
end

local function OnUsable()
	for _, b in ipairs(state.sockets) do
		ns.Button.UpdateUsable(b)
	end
end

local function OnMotion()
	for _, b in ipairs(state.sockets) do PaintSpire(b, false) end
	PaintRing()
end

local function Listen(on)
	if on == state.listening then return end
	state.listening = on
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
	if not on then return end
	K.Callbacks.Register("EffectsLevelChanged", OWNER, OnMotion)
	Events.Register(OWNER, "PLAYER_TOTEM_UPDATE", OnTotem)
	Events.Register(OWNER, "ACTIONBAR_SLOT_CHANGED", OnSlot)
	Events.Register(OWNER, "ACTIONBAR_UPDATE_COOLDOWN", OnCooldown)
	Events.Register(OWNER, "SPELL_UPDATE_COOLDOWN", OnCooldown)
	Events.Register(OWNER, "ACTIONBAR_UPDATE_USABLE", OnUsable)
	for _, event in ipairs({ "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE" }) do
		Events.Register(OWNER, event, PaintMedals)
	end
	Events.Register(OWNER, "UPDATE_BINDINGS", Hotkeys)
end

local function Blizzard(on)
	if on ~= (state.hidBlizzard == true) then
		state.hidBlizzard = on
		if on then K.Safe.HideBlizzard(MultiCastActionBarFrame) else K.Safe.RestoreBlizzard(MultiCastActionBarFrame) end
	end
end

local function Apply()
	state.pending = false
	local on, was = Wanted(), state.shown
	state.shown = on
	if not on then
		local header = state.header
		if header then
			UnregisterStateDriver(header, "visibility")
			header:Hide()
			for _, b in ipairs(state.sockets) do
				b.fan:Hide()
				b:SetAttribute("type", nil)
			end
			state.call:SetAttribute("*type1", nil)
			state.call:SetAttribute("*type2", nil)
		end
		Listen(false)
	else
		if not state.header then Build() end
		Fill()
		Place()
		RegisterStateDriver(state.header, "visibility", OVERRIDDEN)
		Listen(true)
		Hotkeys()
		for _, b in ipairs(state.sockets) do PaintSocket(b) end
		OnMotion()
		PaintMedals()
	end
	Blizzard(on)
	if on ~= (was == true) and ns.bars.stance then
		ns.bars.stance:Apply()
	end
end

function Totems.Update()
	if state.pending then return end
	state.pending = true
	K.Combat.Queue(Apply)
end

local function OnSetting(_, module, key)
	if module == "ActionBars" and key == "totemBar" then Totems.Update() end
end

function Totems.SetEnabled(on)
	state.enabled = on
	if ns.class ~= "SHAMAN" then return end
	K.Events.UnregisterAll(LEARN)
	if on then
		K.Callbacks.Register("SettingChanged", OWNER, OnSetting)
		for _, event in ipairs({ "UPDATE_MULTI_CAST_ACTIONBAR", "SPELLS_CHANGED", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_ENTERING_WORLD" }) do
			K.Events.Register(LEARN, event, Totems.Update)
		end
	else
		K.Callbacks.Unregister("SettingChanged", OWNER)
	end
	Totems.Update()
end

_G["BINDING_NAME_CLICK KstyleUI_TotemSlot1:LeftButton"] = L["Earth totem"]
_G["BINDING_NAME_CLICK KstyleUI_TotemSlot2:LeftButton"] = L["Fire totem"]
_G["BINDING_NAME_CLICK KstyleUI_TotemSlot3:LeftButton"] = L["Water totem"]
_G["BINDING_NAME_CLICK KstyleUI_TotemSlot4:LeftButton"] = L["Air totem"]
_G["BINDING_NAME_CLICK KstyleUI_TotemCall:LeftButton"] = L["Call of the Elements"]
_G["BINDING_NAME_CLICK KstyleUI_TotemCall:RightButton"] = L["Totemic Recall"]
