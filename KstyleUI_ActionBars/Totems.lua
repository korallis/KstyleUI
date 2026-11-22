-- Totems.lua: the shaman's Spirit Poles, KstyleUI's own secure totem bar in place of Blizzard's MultiCastActionBarFrame: four element sockets in the game's bar order (earth, fire, water, air) drop the chosen totem from its multi-cast action slot, right click fans out that element's totems to choose one (shift right click dismisses the totem), and each socket carries a crown spire that lights and burns down over the totem's life from the slot's own boolean and duration object, so Lua never reads a secret; Ghost Wolf and Call of the Elements (right click: Totemic Recall) ride as medals on the Medallions crest ring's shoulders, and the lone Ghost Wolf stance bar hides; without the crest Blizzard's bar stays.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects, L = K.Widgets, K.Tokens, K.Effects, K.L
local cos, sin, rad, max, min = math.cos, math.sin, math.rad, math.max, math.min
local IsSecret = Widgets.IsSecret

local Totems = {}
ns.Totems = Totems

local OWNER = "ActionBars.Totems"
local ELEMENTS = {
	{ slot = 2, name = "Earth", angle = 126, label = L["Earth totem"] },
	{ slot = 1, name = "Fire", angle = 102, label = L["Fire totem"] },
	{ slot = 3, name = "Water", angle = 78, label = L["Water totem"] },
	{ slot = 4, name = "Air", angle = 54, label = L["Air totem"] },
}
local CALL, RECALLS = 66842, { 36936, 437009 }
local SOCKET, RADIUS, SPIRE, SPIRE_LIFT, HALO = 26, 98, 34, 3, 1.5
local MEDAL, MEDAL_RADIUS, MEDAL_RISE, ICON = 26, 84, 32, 0.74
local FAN, FAN_STEP, FAN_SPAN, FAN_MAX = 26, 26, 150, 10
local FLARE_RISE, FLARE_FALL, IGNITE = 0.05, 0.4, 0.3

local OPEN = [[
	if button ~= "RightButton" or IsShiftKeyDown() then return nil end
	if control:IsShown() then
		control:Hide()
	else
		control:Show()
		control:RegisterAutoHide(1.5)
		control:AddToAutoHide(self)
	end
	return false
]]

local state = { sockets = {} }
Totems.state = state

local function Flag(v, secret)
	if IsSecret(v) then return secret end
	return v == true or v == 1
end

local function Supported()
	local index = C_ActionBar ~= nil and type(C_ActionBar.GetMultiCastBarIndex) == "function" and C_ActionBar.GetMultiCastBarIndex()
	return type(index) == "number" and not IsSecret(index) and index > 0 and type(GetMultiCastTotemSpells) == "function"
		and type(GetTotemInfo) == "function" and type(SecureHandlerWrapScript) == "function"
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
		local texture, _, _, spell = GetShapeshiftFormInfo(i)
		if not IsSecret(spell) and type(spell) == "number" then return i, spell, texture end
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

local function Bar(parent, color, blend)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetOrientation("VERTICAL")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	bar:SetStatusBarColor(Tokens.Color(color))
	bar.blend = blend
	return bar
end

local function Fade(target, from, to, duration, order)
	local group = target.anim or target:CreateAnimationGroup()
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	target.anim = group
	return a
end

local function Spire(parent, e)
	local s = CreateFrame("Frame", nil, parent)
	local color = "totem" .. e.name
	s.steel = s:CreateTexture(nil, "BACKGROUND")
	s.steel:SetAllPoints(s)
	s.gate = CreateFrame("Frame", nil, s)
	s.gate:SetAllPoints(s)
	s.glow = Bar(s.gate, color, "ADD")
	s.lit = Bar(s.gate, "white")
	local r, g, b = Tokens.Color(color)
	s.lit:SetStatusBarColor(0.55 + 0.45 * r, 0.55 + 0.45 * g, 0.55 + 0.45 * b)
	s.lit:SetAllPoints(s)
	s.core = Bar(s.gate, color, "ADD")
	s.core:SetAllPoints(s)
	local grow = s.gate:CreateAnimationGroup()
	local scale = grow:CreateAnimation("Scale")
	scale:SetScaleFrom(1, 0.1)
	scale:SetScaleTo(1, 1)
	scale:SetOrigin("BOTTOM", 0, 0)
	scale:SetDuration(IGNITE)
	scale:SetSmoothing("OUT")
	s.ignite = grow
	s.flareGate = CreateFrame("Frame", nil, s)
	s.flareGate:SetAllPoints(s)
	s.flareGate:SetFrameLevel(s.gate:GetFrameLevel() + 3)
	s.flare = CreateFrame("Frame", nil, s.flareGate)
	s.flare:SetAllPoints(s)
	s.flareArt = Art(s.flare, "ARTWORK", "glow", "totemCore", "ADD")
	s.flareArt:SetAllPoints(s.flare)
	Fade(s.flare, 0, 1, FLARE_RISE)
	Fade(s.flare, 1, 0, FLARE_FALL, 2)
	s.flare.anim:SetScript("OnFinished", function() s.flare:Hide() end)
	s.flare:Hide()
	s.rim = Art(s.gate, "OVERLAY", "medSlotChecked", color, "ADD")
	return s
end

function Totems.SetSpireAngle(s, angle, size)
	for key, kind in pairs({ steel = "Steel", flareArt = "Core" }) do
		s[key]:SetTexture((Tokens.Texture("pipSpire" .. kind .. angle)))
	end
	for key, kind in pairs({ lit = "", core = "Core", glow = "Glow" }) do
		s[key]:SetStatusBarTexture((Tokens.Texture("pipSpire" .. kind .. angle)))
		if s[key].blend then s[key]:GetStatusBarTexture():SetBlendMode(s[key].blend) end
	end
	s:SetSize(size, size)
	s.glow:ClearAllPoints()
	s.glow:SetPoint("CENTER", s, "CENTER", 0, 0)
	s.glow:SetSize(size * HALO, size * HALO)
end

local function PaintSpire(b, moving)
	local s, slot = b.spire, b.element.slot
	local have = GetTotemInfo(slot)
	Gate(s.gate, have)
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
	if moving then
		Gate(s.flareGate, have)
		s.flare:Show()
		s.flare.anim:Play()
		s.ignite:Play()
	end
end

local function PaintSocket(b)
	local api, slot = C_ActionBar, b.action
	local has = slot ~= nil and ns.SlotValid(slot) and Flag(api.HasAction(slot), true)
	b.hasAction = has
	b:SetIcon(has and api.GetActionTexture(slot) or nil)
	b.rune:SetShown(not has)
	local duration = has and type(api.GetActionCooldownDuration) == "function" and api.GetActionCooldownDuration(slot)
	if duration then
		local info = type(api.GetActionCooldown) == "function" and api.GetActionCooldown(slot)
		b:SetCooldownFromDuration(duration, type(info) == "table" and Flag(info.isOnGCD, false))
	else
		b:ClearCooldown()
	end
	local usable, noMana = true, false
	if has and type(api.IsUsableAction) == "function" then usable, noMana = api.IsUsableAction(slot) end
	usable, noMana = Flag(usable, true), Flag(noMana, false)
	b.lacksPower = not usable and noMana
	b:SetUsable(usable or noMana)
	ns.Button.ApplyTint(b)
	local kind, id
	if has and type(GetActionInfo) == "function" then kind, id = GetActionInfo(slot) end
	local chosen = not IsSecret(kind) and kind == "spell" and not IsSecret(id) and id or nil
	for _, f in ipairs(b.fan.buttons) do
		f:SetSelected(chosen ~= nil and f:GetAttribute("spell") == chosen)
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
	if state.call then
		state.call.icon:SetTexture(C_Spell and type(C_Spell.GetSpellTexture) == "function" and C_Spell.GetSpellTexture(CALL) or nil)
	end
end

local function PaintAll()
	for _, b in ipairs(state.sockets) do
		PaintSocket(b)
		PaintSpire(b, false)
	end
	PaintMedals()
end

local function SocketTooltip(tip, b)
	local _, id = GetActionInfo(b.action)
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

local function Fan(header, b)
	local fan = CreateFrame("Frame", nil, header, "SecureHandlerBaseTemplate")
	fan:SetFrameStrata("HIGH")
	fan:Hide()
	fan.buttons = {}
	for n = 1, FAN_MAX do
		local f = Widgets.Slot(fan, { template = "SecureActionButtonTemplate", size = FAN, silent = true })
		f.kind = "totem"
		f:RegisterForClicks("AnyUp")
		f:SetAttribute("useOnKeyDown", false)
		f:SetAttribute("type", "multispell")
		SecureHandlerWrapScript(f, "OnClick", fan, [[ return nil, true ]], [[ control:Hide() ]])
		Widgets.AttachTooltip(f, FanTooltip, "ANCHOR_TOP")
		f.shade = Art(f, "BACKGROUND", "glow", "black")
		f.shade:SetPoint("CENTER", f, "CENTER", 0, 0)
		f.shade:SetAlpha(0.85)
		if n == 1 then
			f.rune = Art(f.overlay, "OVERLAY", "totemRune" .. b.element.name, "totem" .. b.element.name)
			f.rune:SetAllPoints(f.icon)
		end
		fan.buttons[n] = ns.Socket.Decorate(f)
	end
	SecureHandlerWrapScript(b, "OnClick", fan, OPEN)
	return fan
end

local function Socket(header, i, e)
	local b = Widgets.Slot(header, { name = "KstyleUI_TotemSlot" .. i, template = "SecureActionButtonTemplate", size = SOCKET, silent = true })
	b.kind, b.element = "totem", e
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("useOnKeyDown", false)
	b:SetAttribute("type", "action")
	b:SetAttribute("type2", "destroytotem")
	b:SetAttribute("totem-slot", e.slot)
	b.rune = Art(b.overlay, "OVERLAY", "totemRune" .. e.name, "totem" .. e.name)
	b.rune:SetAllPoints(b.icon)
	b.rune:SetAlpha(0.55)
	b.tab = Art(b, "OVERLAY", "dot", "totem" .. e.name)
	b.fan = Fan(header, b)
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
	m.enamel = Art(m, "OVERLAY", "medEnamel", "steel")
	m.ring = Art(m, "OVERLAY", "medRing", "white")
	m.spirit = CreateFrame("Frame", nil, m)
	m.spirit:SetAllPoints(m)
	Art(m.spirit, "OVERLAY", "medEnamel", "totemSpirit", "ADD"):SetAllPoints(m.spirit)
	m.spirit:Hide()
	local hover = Art(m, "HIGHLIGHT", "glow", "white", "ADD")
	hover:SetAllPoints(m)
	hover:SetAlpha(0.35)
	for _, t in ipairs({ m.enamel, m.ring }) do t:SetAllPoints(m) end
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
	state.call = Medal(header, "KstyleUI_TotemCall", CallTooltip)
	state.call:SetAttribute("type", "spell")
	state.call:SetAttribute("spell", CALL)
	state.wolf = Medal(header, "KstyleUI_TotemWolf", WolfTooltip)
	state.wolf:SetAttribute("type", "spell")
end

local function Fill()
	local base = (C_ActionBar.GetMultiCastBarIndex() - 1) * ns.BUTTONS_PER_PAGE
	for _, b in ipairs(state.sockets) do
		local slot, spells = b.element.slot, Spells(b.element.slot)
		b.action, b.known = base + slot, #spells > 0
		b:SetAttribute("action", b.action)
		local count = min(FAN_MAX, #spells + 1)
		local step = min(FAN_STEP, FAN_SPAN / max(1, count - 1))
		b.fan.radius = (FAN + 4) / (2 * sin(rad(max(step, 1) / 2)))
		for n, f in ipairs(b.fan.buttons) do
			local spell = n == 1 and 0 or spells[n - 1]
			f:SetAttribute("action", b.action)
			f:SetAttribute("spell", spell)
			f:SetIcon(spell and spell ~= 0 and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell) or nil)
			f.angle = 90 + ((count - 1) / 2 - (n - 1)) * step
			f:SetShown(n <= count)
		end
	end
	state.call:SetAttribute("type2", Known(RECALLS) and "spell" or nil)
	state.call:SetAttribute("spell2", Known(RECALLS))
	state.call.known = Known({ CALL }) ~= nil
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
		b.opts.size = SOCKET
		b:Restyle()
		ns.Slab.Dress(b)
		local reach = half + SPIRE_LIFT + SPIRE / 2
		Totems.SetSpireAngle(b.spire, angle, Widgets.Snap(b.spire, SPIRE))
		Put(b.spire, hub, x + reach * cos(rad(angle)), y + reach * sin(rad(angle)))
		b.spire.rim:ClearAllPoints()
		b.spire.rim:SetAllPoints(b)
		b.tab:ClearAllPoints()
		b.tab:SetPoint("TOP", b, "BOTTOM", 0, -1)
		Widgets.Size(b.tab, SOCKET * 0.6, 3)
		local fan = b.fan
		Put(fan, b, 0, 0, 2 * fan.radius + FAN)
		for _, f in ipairs(fan.buttons) do
			Put(f, b, fan.radius * cos(rad(f.angle)), fan.radius * sin(rad(f.angle)), FAN)
			f.opts.size = FAN
			f:Restyle()
			ns.Slab.Dress(f)
			Widgets.Size(f.shade, FAN * 2.6, FAN * 2.6)
		end
	end
	state.call:SetShown(state.call.known)
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
end

local function OnSlot(_, slot)
	for _, b in ipairs(state.sockets) do
		if IsSecret(slot) or slot == nil or slot == 0 or b.action == slot then
			PaintSocket(b)
		end
	end
end

local function Listen(on)
	if on == state.listening then return end
	state.listening = on
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	if not on then return end
	Events.Register(OWNER, "PLAYER_TOTEM_UPDATE", OnTotem)
	Events.Register(OWNER, "ACTIONBAR_SLOT_CHANGED", OnSlot)
	for _, event in ipairs({ "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_USABLE" }) do
		Events.Register(OWNER, event, OnSlot)
	end
	for _, event in ipairs({ "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE" }) do
		Events.Register(OWNER, event, PaintMedals)
	end
	Events.Register(OWNER, "UPDATE_BINDINGS", Hotkeys)
	for _, event in ipairs({ "UPDATE_MULTI_CAST_ACTIONBAR", "SPELLS_CHANGED", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_ENTERING_WORLD" }) do
		Events.Register(OWNER, event, Totems.Update)
	end
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
		if state.header then state.header:Hide() end
		Listen(false)
	else
		if not state.header then Build() end
		Fill()
		Place()
		state.header:Show()
		Listen(true)
		Hotkeys()
		PaintAll()
	end
	Blizzard(on)
	if on ~= (was == true) and ns.bars.stance then
		ns.bars.stance:Apply()
	end
end

function Totems.TakesStance()
	return state.shown == true
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
	if on then
		K.Callbacks.Register("SettingChanged", OWNER, OnSetting)
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
