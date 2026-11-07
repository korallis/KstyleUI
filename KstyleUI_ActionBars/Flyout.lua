-- Flyout.lua: KstyleUI's own secure spell flyout: a flyout action opens its spells in a row beside its button, in combat too.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Icons = K.Widgets, K.Tokens, K.Icons

local Flyout = {}
ns.Flyout = Flyout

local MAX_SPELLS = 12
local AUTO_HIDE = 1
local MAX_SLOT = ns.MAX_SLOT

local OWNER_SNIPPET = ([[
	local page = self:GetParent():GetAttribute("actionpage") or 1
	local kind, id = GetActionInfo(self:GetID() + (page - 1) * 12)
	if kind ~= "flyout" then
		return
	end
	if not down then
		return false
	end
	if control:IsShown() and control:GetAttribute("owner") == self:GetName() then
		control:Hide()
		return false
	end
	control:Hide()
	local count = control:GetAttribute("flyout" .. id .. "n") or 0
	if count == 0 then
		return false
	end
	local size = self:GetWidth()
	local gap = control:GetAttribute("gap") or 0
	local direction = self:GetParent():GetAttribute("flyoutDirection") or "UP"
	local length = count * size + (count - 1) * gap
	control:ClearAllPoints()
	if direction == "DOWN" then
		control:SetPoint("TOP", self, "BOTTOM", 0, -gap)
	elseif direction == "LEFT" then
		control:SetPoint("RIGHT", self, "LEFT", -gap, 0)
	elseif direction == "RIGHT" then
		control:SetPoint("LEFT", self, "RIGHT", gap, 0)
	else
		control:SetPoint("BOTTOM", self, "TOP", 0, gap)
	end
	if direction == "LEFT" or direction == "RIGHT" then
		control:SetWidth(length)
		control:SetHeight(size)
	else
		control:SetWidth(size)
		control:SetHeight(length)
	end
	for i = 1, MAX_SPELLS do
		local button = control:GetFrameRef("button" .. i)
		if i <= count then
			local offset = (i - 1) * (size + gap)
			button:SetAttribute("spell", control:GetAttribute("flyout" .. id .. "s" .. i))
			button:SetWidth(size)
			button:SetHeight(size)
			button:ClearAllPoints()
			if direction == "DOWN" then
				button:SetPoint("TOP", control, "TOP", 0, -offset)
			elseif direction == "LEFT" then
				button:SetPoint("RIGHT", control, "RIGHT", -offset, 0)
			elseif direction == "RIGHT" then
				button:SetPoint("LEFT", control, "LEFT", offset, 0)
			else
				button:SetPoint("BOTTOM", control, "BOTTOM", 0, offset)
			end
			button:Show()
		else
			button:Hide()
		end
	end
	control:SetAttribute("owner", self:GetName())
	control:Show()
	control:RegisterAutoHide(AUTO_HIDE)
	control:AddToAutoHide(self)
	return false
]]):gsub("MAX_SPELLS", tostring(MAX_SPELLS)):gsub("AUTO_HIDE", tostring(AUTO_HIDE))

local SPELL_PRE = [[
	if not down then
		return nil, true
	end
]]
local SPELL_POST = [[
	control:Hide()
]]

local pending = false
local known = {}

local function SpellTexture(spell)
	local api = C_Spell
	if spell and not ns.IsSecret(spell) and api and type(api.GetSpellTexture) == "function" then
		return api.GetSpellTexture(spell)
	end
end

local function UpdateButtons(frame)
	for _, b in ipairs(Flyout.buttons) do
		local spell = b:GetAttribute("spell")
		local texture = SpellTexture(spell)
		if texture ~= nil then
			Icons.Apply(b.icon, texture)
		else
			b:SetIcon(nil)
		end
		local api = C_Spell
		local duration = spell and api and type(api.GetSpellCooldownDuration) == "function" and api.GetSpellCooldownDuration(spell)
		if duration then
			b:SetCooldownFromDuration(duration, ns.Button.SpellOnGlobalCooldown(api, spell))
		else
			b:ClearCooldown()
		end
	end
	ns.Flyout.shownFor = frame:GetAttribute("owner")
end

local function ShowTooltip(b)
	local tip = GameTooltip
	local spell = b:GetAttribute("spell")
	if not (tip and spell) or ns.IsSecret(spell) or type(tip.SetSpellByID) ~= "function" then
		return
	end
	if type(GameTooltip_SetDefaultAnchor) == "function" then
		GameTooltip_SetDefaultAnchor(tip, b)
	else
		tip:SetOwner(b, "ANCHOR_RIGHT")
	end
	tip:SetSpellByID(spell)
	b.tooltipShown = true
end

local function HideTooltip(b)
	local tip = GameTooltip
	if b.tooltipShown and tip and tip:GetOwner() == b then
		tip:Hide()
	end
	b.tooltipShown = false
end

function Flyout.Build()
	if Flyout.frame then
		return Flyout.frame
	end
	if type(SecureHandlerWrapScript) ~= "function" or type(SecureHandlerSetFrameRef) ~= "function" then
		ns.LogOnce("noFlyout", "SecureHandlerWrapScript is missing; flyout actions cannot open from KstyleUI's bars")
		return nil
	end
	local frame = CreateFrame("Frame", "KstyleUI_ActionBarsFlyout", K.Scale.Root(), "SecureHandlerBaseTemplate")
	frame:SetFrameStrata("HIGH")
	frame:SetSize(Tokens.Size("actionButton"), Tokens.Size("actionButton"))
	frame:SetAttribute("gap", Tokens.Size("actionGap"))
	frame:Hide()
	Flyout.frame, Flyout.buttons = frame, {}
	for i = 1, MAX_SPELLS do
		local b = Widgets.IconButton(frame, {
			name = "KstyleUI_ActionBarsFlyoutButton" .. i,
			template = "SecureActionButtonTemplate",
			silent = true,
		})
		b:SetAttribute("type", "spell")
		b:RegisterForClicks("AnyUp", "AnyDown")
		b:Hide()
		b:HookScript("OnEnter", ShowTooltip)
		b:HookScript("OnLeave", HideTooltip)
		SecureHandlerSetFrameRef(frame, "button" .. i, b)
		SecureHandlerWrapScript(b, "OnClick", frame, SPELL_PRE, SPELL_POST)
		Flyout.buttons[i] = b
	end
	frame:HookScript("OnShow", UpdateButtons)
	ns.flyout = Flyout
	return frame
end

function Flyout.Wrap(button)
	local frame = Flyout.frame
	if frame then
		SecureHandlerWrapScript(button, "OnClick", frame, OWNER_SNIPPET)
	end
end

local function Spells(id)
	local list = {}
	if type(GetFlyoutInfo) ~= "function" or type(GetFlyoutSlotInfo) ~= "function" then
		return list
	end
	local _, _, slots, isKnown = GetFlyoutInfo(id)
	if ns.IsSecret(slots) or type(slots) ~= "number" or ns.IsSecret(isKnown) or not isKnown then
		return list
	end
	local lastName
	for i = 1, slots do
		local spell, _, spellKnown, name = GetFlyoutSlotInfo(id, i)
		if not ns.IsSecret(spell) and type(spell) == "number" and not ns.IsSecret(spellKnown) and spellKnown then
			local plainName = not ns.IsSecret(name) and name or nil
			if plainName and plainName == lastName and #list > 0 then
				list[#list] = spell
			elseif #list < MAX_SPELLS then
				list[#list + 1] = spell
			end
			lastName = plainName
		end
	end
	return list
end

local function Store(id)
	local frame = Flyout.frame
	local list = Spells(id)
	frame:SetAttribute("flyout" .. id .. "n", #list)
	for i, spell in ipairs(list) do
		frame:SetAttribute("flyout" .. id .. "s" .. i, spell)
	end
	known[id] = true
end

local function FlyoutOf(slot)
	if type(GetActionInfo) ~= "function" or not ns.SlotValid(slot) then
		return nil
	end
	local kind, id = GetActionInfo(slot)
	if ns.IsSecret(kind) or ns.IsSecret(id) or kind ~= "flyout" or type(id) ~= "number" then
		return nil
	end
	return id
end
Flyout.FlyoutOf = FlyoutOf

function Flyout.Refresh()
	pending = false
	if not Flyout.frame then
		return
	end
	if InCombatLockdown() and not ns.enabling then
		pending = true
		K.Combat.Queue(Flyout.Refresh)
		return
	end
	local ids = {}
	local api = C_Flyout
	if api and type(api.GetNumFlyouts) == "function" and type(api.GetFlyoutID) == "function" then
		local count = api.GetNumFlyouts()
		if not ns.IsSecret(count) and type(count) == "number" then
			for i = 1, count do
				local id = api.GetFlyoutID(i)
				if not ns.IsSecret(id) and type(id) == "number" then
					ids[id] = true
				end
			end
		end
	end
	for slot = 1, MAX_SLOT do
		local id = FlyoutOf(slot)
		if id then
			ids[id] = true
		end
	end
	local stored = 0
	for id in pairs(ids) do
		Store(id)
		stored = stored + 1
	end
	ns.LogOnce("flyouts" .. stored, "flyouts ready: " .. stored)
end

function Flyout.SlotChanged(slot)
	if pending or not Flyout.frame then
		return
	end
	local id = FlyoutOf(slot)
	if id and not known[id] then
		Flyout.Refresh()
	end
end

function Flyout.QueueRefresh()
	if pending or not Flyout.frame then
		return
	end
	pending = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Flyout.Refresh)
	else
		Flyout.Refresh()
	end
end

function Flyout.Close()
	local frame = Flyout.frame
	if frame and not InCombatLockdown() then
		frame:Hide()
	end
end
