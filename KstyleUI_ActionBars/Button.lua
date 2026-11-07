-- Button.lua: one action, pet or stance button: a secure icon button from the widget kit, and every visual update it gets.
local _, ns = ...

local K = KstyleUI
local Widgets, Icons, Tokens = K.Widgets, K.Icons, K.Tokens

local Button = {}
ns.Button = Button

local TEXT_INSET = 2
local AUTOCAST_SIZE = 6
local ARROW_SIZE = 10
local ARROWS = {
	UP = { "TOP", math.pi },
	DOWN = { "BOTTOM", 0 },
	LEFT = { "LEFT", -math.pi / 2 },
	RIGHT = { "RIGHT", math.pi / 2 },
}

function Button.PlaceArrow(b, direction)
	local arrow = b.flyoutArrow
	local place = ARROWS[direction] or ARROWS.UP
	arrow:ClearAllPoints()
	arrow:SetPoint("CENTER", b, place[1])
	arrow:SetRotation(place[2])
end
local NOOP = ""

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
ns.IsSecret = IsSecret

local function Plain(v)
	if IsSecret(v) then
		return nil
	end
	return v
end

local function Flag(v, secretValue)
	if IsSecret(v) then
		return secretValue
	end
	return v == true
end

local function Log(message)
	K.DevTest.Log("ActionBars", message)
end
ns.Log = Log

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end
ns.LogOnce = LogOnce

local valid = {}

function ns.SlotValid(slot)
	local known = valid[slot]
	if known ~= nil then
		return known
	end
	local bar = C_ActionBar
	local ok = type(slot) == "number" and bar ~= nil and type(bar.HasAction) == "function" and pcall(bar.HasAction, slot)
	valid[slot] = ok == true
	if not ok then
		LogOnce("slot" .. tostring(slot), "slot " .. tostring(slot) .. " is not an action slot on this client; its button stays empty")
	end
	return valid[slot]
end

local function Config(b)
	return ns.Config(b.kbar.def.key)
end

local function RangeCheck(b, slot, on)
	local bar = C_ActionBar
	if bar and type(bar.EnableActionRangeCheck) == "function" then
		bar.EnableActionRangeCheck(slot, on)
	end
	b.rangeSlot = on and slot or nil
end

function Button.ApplyTint(b, force)
	local key
	if b.outOfRange then
		key = "rangeColor"
	elseif b.lacksPower then
		key = "powerColor"
	end
	if key == b.tintKey and not force then
		return
	end
	b.tintKey = key
	local color = key and ns.Config(key)
	if color then
		b:SetTint(color.r, color.g, color.b)
	else
		b:SetTint()
	end
end

function Button.UpdateAlpha(b)
	local shown = b.hasAction or b.kind == "stance" or ns.grid > 0
	if not shown then
		local cfg = Config(b)
		shown = cfg.showEmpty == true
	end
	b:SetAlpha(shown and 1 or 0)
end

local function CooldownInfo(bar, slot)
	if type(bar.GetActionCooldown) ~= "function" then
		return nil
	end
	local info = bar.GetActionCooldown(slot)
	return type(info) == "table" and info or nil
end

function Button.UpdateCooldown(b)
	if not b.hasAction then
		b:ClearCooldown()
		b:ClearChargeCooldown()
		return
	end
	local slot, bar = b.slot, C_ActionBar
	local info = CooldownInfo(bar, slot)
	local gcd = info ~= nil and Flag(info.isOnGCD, false)
	if type(bar.GetActionCooldownDuration) == "function" then
		local duration = bar.GetActionCooldownDuration(slot)
		if duration then
			b:SetCooldownFromDuration(duration, gcd)
		else
			b:ClearCooldown()
		end
	elseif info then
		LogOnce("cooldownPath", "C_ActionBar.GetActionCooldownDuration is missing; cooldowns use GetActionCooldown when it is not secret")
		local start, duration = Plain(info.startTime), Plain(info.duration)
		if type(start) == "number" and type(duration) == "number" and duration > 0 then
			b:SetCooldown(start, duration, gcd)
		else
			b:ClearCooldown()
		end
	end
	local charges = b.hasCharges and type(bar.GetActionCharges) == "function" and bar.GetActionCharges(slot)
	local active = type(charges) == "table" and Flag(charges.isActive, false)
	if active and type(bar.GetActionChargeDuration) == "function" then
		local duration = bar.GetActionChargeDuration(slot)
		if duration then
			b:SetChargeCooldownFromDuration(duration)
			return
		end
	end
	b:ClearChargeCooldown()
end

function Button.UpdateCount(b)
	local bar = C_ActionBar
	if b.hasAction and type(bar.GetActionDisplayCount) == "function" then
		b:SetCount(bar.GetActionDisplayCount(b.slot))
	else
		b:SetCount(nil)
	end
end

local function SetUsable(b, usable)
	if b.usable ~= usable then
		b:SetUsable(usable)
	end
end

function Button.UpdateUsable(b, usable, noPower)
	if not b.hasAction then
		b.lacksPower = false
		SetUsable(b, true)
		Button.ApplyTint(b)
		return
	end
	if usable == nil then
		usable, noPower = C_ActionBar.IsUsableAction(b.slot)
	end
	usable, noPower = Flag(usable, true), Flag(noPower, false)
	b.lacksPower = not usable and noPower
	SetUsable(b, usable or noPower)
	Button.ApplyTint(b)
end

function Button.UpdateRange(b, inRange, checksRange)
	local out = false
	if b.hasAction then
		if checksRange == nil then
			local bar = C_ActionBar
			if type(bar.IsActionInRange) == "function" then
				inRange = bar.IsActionInRange(b.slot)
				checksRange = not IsSecret(inRange) and inRange ~= nil
			end
		end
		out = Flag(checksRange, false) and not IsSecret(inRange) and inRange == false
	end
	if out ~= b.outOfRange then
		b.outOfRange = out
		Button.ApplyTint(b)
	end
end

function Button.UpdateState(b)
	local bar = C_ActionBar
	local on = false
	if b.hasAction then
		on = Flag(bar.IsCurrentAction(b.slot), false) or Flag(bar.IsAutoRepeatAction(b.slot), false)
	end
	if on ~= (b.selected == true) then
		b:SetSelected(on)
	end
end

function Button.SetProc(b, on)
	if on ~= (b.proc == true) then
		b:SetProc(on)
	end
end

function Button.UpdateProc(b)
	local id = b.spellID
	local overlay = C_SpellActivationOverlay
	local on = false
	if id and overlay and type(overlay.IsSpellOverlayed) == "function" then
		on = Flag(overlay.IsSpellOverlayed(id), false)
	end
	Button.SetProc(b, on)
end

function Button.UpdateMacroText(b)
	local bar, text = C_ActionBar, nil
	if b.hasAction and Config(b).macro and type(bar.UsesActionText) == "function" and Flag(bar.UsesActionText(b.slot), true) then
		text = bar.GetActionText(b.slot)
	end
	b.macroText:SetText(text or "")
end

local function SpellOf(slot)
	if type(GetActionInfo) ~= "function" then
		return nil
	end
	local actionType, id, subType = GetActionInfo(slot)
	if IsSecret(actionType) or IsSecret(id) or IsSecret(subType) then
		return nil
	end
	if actionType == "spell" or (actionType == "macro" and subType == "spell") then
		return id
	end
end

local function UpdateAction(b)
	local slot = b.slot
	local bar = C_ActionBar
	local has = slot ~= nil and ns.SlotValid(slot) and Flag(bar.HasAction(slot), true)
	b.hasAction = has
	if has then
		local texture = bar.GetActionTexture(slot)
		if IsSecret(texture) or texture ~= nil then
			Icons.Apply(b.icon, texture)
		else
			b:SetIcon(nil)
		end
		b.spellID = SpellOf(slot)
		b.isFlyout = ns.Flyout.FlyoutOf(slot) ~= nil
		local charges = type(bar.GetActionCharges) == "function" and bar.GetActionCharges(slot)
		local most = type(charges) == "table" and Plain(charges.maxCharges)
		b.hasCharges = type(most) == "number" and most > 1
	else
		b:SetIcon(nil)
		b.spellID, b.hasCharges, b.isFlyout = nil, false, false
	end
	local wantRange = has and b.index <= b.kbar.count and b.kbar:Shown()
	if b.rangeSlot and (not wantRange or b.rangeSlot ~= slot) then
		RangeCheck(b, b.rangeSlot, false)
	end
	if wantRange and b.rangeSlot ~= slot then
		RangeCheck(b, slot, true)
	end
	b.flyoutArrow:SetShown(b.isFlyout == true)
	Button.UpdateMacroText(b)
	Button.UpdateCount(b)
	Button.UpdateCooldown(b)
	Button.UpdateUsable(b)
	Button.UpdateRange(b)
	Button.UpdateState(b)
	Button.UpdateProc(b)
	Button.UpdateAlpha(b)
end

local function SpellOnGlobalCooldown(spell, spellID)
	if type(spell.GetSpellCooldown) ~= "function" then
		return false
	end
	local info = spell.GetSpellCooldown(spellID)
	return type(info) == "table" and Flag(info.isOnGCD, false)
end
Button.SpellOnGlobalCooldown = SpellOnGlobalCooldown

local function SpellCooldown(b, spellID, start, duration)
	local spell = C_Spell
	if spellID and not IsSecret(spellID) and spell and type(spell.GetSpellCooldownDuration) == "function" then
		local object = spell.GetSpellCooldownDuration(spellID)
		if object then
			b:SetCooldownFromDuration(object, SpellOnGlobalCooldown(spell, spellID))
		else
			b:ClearCooldown()
		end
		return
	end
	start, duration = Plain(start), Plain(duration)
	if type(start) == "number" and type(duration) == "number" and duration > 0 then
		b:SetCooldown(start, duration)
	else
		b:ClearCooldown()
	end
end

local function UpdatePet(b)
	local i = b.index
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID
	if type(GetPetActionInfo) == "function" then
		name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(i)
	end
	b.hasAction = IsSecret(name) or name ~= nil
	if Flag(isToken, false) and not IsSecret(texture) and type(texture) == "string" then
		texture = _G[texture]
	end
	if b.hasAction and (IsSecret(texture) or texture ~= nil) then
		Icons.Apply(b.icon, texture)
	else
		b:SetIcon(nil)
	end
	b.petSpell = Plain(spellID)
	b.autoCastAllowed = Flag(autoCastAllowed, false)
	b.autocast:SetShown(b.hasAction and Flag(autoCastEnabled, false))
	local selected = b.hasAction and Flag(isActive, false)
	if selected ~= (b.selected == true) then
		b:SetSelected(selected)
	end
	local usable = true
	if b.hasAction and type(GetPetActionSlotUsable) == "function" then
		usable = Flag(GetPetActionSlotUsable(i), true)
	end
	SetUsable(b, usable)
	if b.hasAction then
		local start, duration
		if type(GetPetActionCooldown) == "function" then
			start, duration = GetPetActionCooldown(i)
		end
		SpellCooldown(b, b.petSpell, start, duration)
	else
		b:ClearCooldown()
	end
	Button.UpdateAlpha(b)
end

local function UpdateStance(b)
	local i = b.index
	local texture, isActive, isCastable, spellID
	if type(GetShapeshiftFormInfo) == "function" then
		texture, isActive, isCastable, spellID = GetShapeshiftFormInfo(i)
	end
	b.hasAction = IsSecret(texture) or texture ~= nil
	if b.hasAction then
		Icons.Apply(b.icon, texture)
	else
		b:SetIcon(nil)
	end
	b.formSpell = Plain(spellID)
	local selected = b.hasAction and Flag(isActive, false)
	if selected ~= (b.selected == true) then
		b:SetSelected(selected)
	end
	SetUsable(b, not b.hasAction or Flag(isCastable, true))
	if b.hasAction then
		local start, duration
		if type(GetShapeshiftFormCooldown) == "function" then
			start, duration = GetShapeshiftFormCooldown(i)
		end
		SpellCooldown(b, b.formSpell, start, duration)
	else
		b:ClearCooldown()
	end
end

function Button.Update(b)
	local kind = b.kind
	if kind == "action" then
		UpdateAction(b)
	elseif kind == "pet" then
		UpdatePet(b)
	else
		UpdateStance(b)
	end
end

function Button.SetSlot(b, slot)
	if b.slot == slot then
		return false
	end
	b.slot = slot
	UpdateAction(b)
	return true
end

function Button.Release(b)
	if b.rangeSlot then
		RangeCheck(b, b.rangeSlot, false)
	end
end

local function TextFor(b, key)
	if key == "hotkey" then
		return b.hotkey
	elseif key == "count" then
		return b.count
	elseif key == "macro" then
		return b.macroText
	end
	return b.cooldown.GetCountdownFontString and b.cooldown:GetCountdownFontString()
end

function ns.StyleTextsFor(b, barKey)
	local cfg = ns.Config(barKey)
	local text = ns.Config("text")
	local scale = K.Theme.FontScale()
	for _, spec in ipairs(ns.TEXTS) do
		local fs = TextFor(b, spec.key)
		local style = text[spec.key]
		if fs and style then
			local rolePath, roleSize = Tokens.Font(spec.role)
			local path = style.font ~= "" and style.font or rolePath
			local size = (type(style.size) == "number" and style.size or roleSize) * scale
			local flags = ns.FontFlags(style.outline)
			if fs:SetFont(path, size, flags) == false and path ~= rolePath then
				fs:SetFont(rolePath, size, flags)
				LogOnce("font:" .. tostring(path), "the font " .. tostring(path) .. " did not load; the action bars use the interface font")
			end
			if flags == "" then
				fs:SetShadowColor(Tokens.Color("textShadow"))
				local offset = Tokens.Size("textShadowOffset")
				fs:SetShadowOffset(offset, -offset)
			else
				fs:SetShadowOffset(0, 0)
			end
		end
	end
	b.hotkey:SetShown(cfg.hotkey == true)
	b.count:SetShown(cfg.count ~= false)
	b.macroText:SetShown(cfg.macro == true)
	b.cooldown:SetHideCountdownNumbers(cfg.cooldown ~= true)
end

function Button.StyleTexts(b)
	ns.StyleTextsFor(b, b.kbar.def.key)
end

function Button.SetAccent(b, r, g, b2)
	b:SetAccent(r, g, b2)
	if b.autocast then
		if r then
			b.autocast:SetVertexColor(r, g, b2)
		else
			Widgets.Tint(b.autocast, "accent")
		end
	end
end

local function ShowTooltip(b)
	local mode = ns.Config("tooltips")
	if mode == "never" or (mode == "noCombat" and InCombatLockdown()) then
		return
	end
	local tip = GameTooltip
	if not (tip and b.hasAction) then
		return
	end
	if type(GameTooltip_SetDefaultAnchor) == "function" then
		GameTooltip_SetDefaultAnchor(tip, b)
	else
		tip:SetOwner(b, "ANCHOR_RIGHT")
	end
	if b.kind == "action" then
		tip:SetAction(b.slot)
	elseif b.kind == "pet" then
		tip:SetPetAction(b.index)
	else
		tip:SetShapeshift(b.index)
	end
	b.tooltipShown = true
end

local function HideTooltip(b)
	if not b.tooltipShown then
		return
	end
	b.tooltipShown = false
	local tip = GameTooltip
	if tip and tip:GetOwner() == b then
		tip:Hide()
	end
end

local function OnEnter(b)
	b.kbar:SetHovered(true)
	ShowTooltip(b)
end

local function OnLeave(b)
	b.kbar:SetHovered(false)
	HideTooltip(b)
end

local function MayPickUp()
	if InCombatLockdown() then
		return false
	end
	local locked = type(GetCVarBool) == "function" and GetCVarBool("lockActionBars")
	return not locked or (type(IsModifiedClick) == "function" and IsModifiedClick("PICKUPACTION") == true)
end

local function OnDragStart(b)
	if not MayPickUp() then
		return
	end
	HideTooltip(b)
	if b.kind == "action" and b.slot and ns.SlotValid(b.slot) then
		PickupAction(b.slot)
	elseif b.kind == "pet" then
		PickupPetAction(b.index)
	end
	Button.Update(b)
end

local function OnReceiveDrag(b)
	if InCombatLockdown() then
		return
	end
	if b.kind == "action" and b.slot and ns.SlotValid(b.slot) then
		PlaceAction(b.slot)
	elseif b.kind == "pet" and type(GetCursorInfo) == "function" and GetCursorInfo() == "petaction" then
		PickupPetAction(b.index)
	end
	Button.Update(b)
end

local function OnClick(b, mouse, down)
	Widgets.Press(b, down == true)
end

local function PostClick(b, mouse, down)
	if b.kind == "pet" and mouse == "RightButton" and not down and b.autoCastAllowed and b.petSpell then
		local spell = C_Spell
		if spell and type(spell.ToggleSpellAutoCast) == "function" then
			spell.ToggleSpellAutoCast(b.petSpell)
		end
	end
end

function Button.New(bar, index)
	local def = bar.def
	local cfg = ns.Config(def.key)
	local b = Widgets.IconButton(bar.header, {
		name = "KstyleUI_" .. def.name .. "Button" .. index,
		template = "SecureActionButtonTemplate",
		size = cfg.size,
		silent = true,
	})
	b.kbar, b.index, b.kind = bar, index, def.kind
	b.hasAction, b.outOfRange, b.lacksPower = false, false, false
	b:RegisterForClicks("AnyUp", "AnyDown")
	if def.kind == "action" then
		b:SetID(index)
		b:SetAttribute("type", "action")
		b:SetAttribute("useparent-actionpage", true)
		b:SetAttribute("checkselfcast", true)
		b:SetAttribute("checkfocuscast", true)
		b:SetAttribute("checkmouseovercast", true)
	elseif def.kind == "pet" then
		b:SetAttribute("type", "pet")
		b:SetAttribute("action", index)
		b:SetAttribute("type2", NOOP)
	end
	if def.kind ~= "stance" then
		b:RegisterForDrag("LeftButton", "RightButton")
		b:HookScript("OnDragStart", OnDragStart)
		b:HookScript("OnReceiveDrag", OnReceiveDrag)
	end
	local inset = Widgets.Snap(b, TEXT_INSET)
	local name = Widgets.Text(b.overlay, "caption", "textEmphasis")
	name:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", inset, inset)
	name:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
	name:SetJustifyH("CENTER")
	name:SetWordWrap(false)
	b.macroText = name
	if def.kind == "action" then
		local arrow = b.overlay:CreateTexture(nil, "OVERLAY")
		arrow:SetTexture((Tokens.Texture("glyphChevron")))
		arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
		Widgets.Tint(arrow, "textEmphasis")
		arrow:Hide()
		b.flyoutArrow = arrow
		ns.Flyout.Wrap(b)
	end
	if def.kind == "pet" then
		local mark = b.overlay:CreateTexture(nil, "OVERLAY")
		mark:SetTexture((Tokens.Texture("dot")))
		mark:SetSize(AUTOCAST_SIZE, AUTOCAST_SIZE)
		mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", inset, inset)
		Widgets.Tint(mark, "accent")
		mark:Hide()
		b.autocast = mark
	end
	b:HookScript("OnEnter", OnEnter)
	b:HookScript("OnLeave", OnLeave)
	b:HookScript("OnClick", OnClick)
	b:HookScript("PostClick", PostClick)
	return b
end
