-- Quick.lua: Quick actions, off by default: holding Alt over a bag item that Disenchant or Pick Lock works on puts one secure cast button over the slot, set out of combat only; right-click casts, left-click still pins.
local _, ns = ...

local K = KstyleUI
local Data, Settings, L = ns.Data, ns.Settings, ns.L

local Quick = { on = false }
ns.Quick = Quick

local DISENCHANT, PICK_LOCK = 13262, 1804
local UNCOMMON, EPIC = 2, 4
local OWNER = "Bags.quick"
local OVERLAY_LEVEL = 10
local hovered, button
local probe = {}
local watched = setmetatable({}, { __mode = "k" })

local function Known(id)
	local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
	return ok and Data.Plain(known, "boolean") == true
end

local function Says(bag, slot, text)
	local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
	if type(text) ~= "string" or not ok or Data.IsSecret(data) or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
	for _, line in ipairs(data.lines) do
		if Data.Plain(line.leftText, "string") == text then return true end
	end
	return false
end

function Quick.Spell(bag, slot)
	if not (C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" and C_TooltipInfo and type(C_TooltipInfo.GetBagItem) == "function") then return nil end
	local record = Data.Read(bag, slot, probe)
	local quality = record.quality
	if not record.itemID or record.locked then return nil end
	if Data.BuiltinCategory(record) == "equipment" and quality and quality >= UNCOMMON and quality <= EPIC and Known(DISENCHANT)
		and not Says(bag, slot, ITEM_DISENCHANT_NOT_DISENCHANTABLE) then
		return DISENCHANT
	end
	if Known(PICK_LOCK) and Says(bag, slot, LOCKED) then return PICK_LOCK end
end

local function Detach()
	if button and not InCombatLockdown() then button:Hide() end
end

local function ShowTip(self)
	local spell = C_Spell and type(C_Spell.GetSpellName) == "function" and Data.Plain(C_Spell.GetSpellName(self.spell), "string")
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetBagItem(self.bag, self.slot)
	local r, g, b = K.Tokens.Color("accent")
	GameTooltip:AddLine(string.format(L["Alt-right-click: %s"], spell or ""), r, g, b)
	GameTooltip:Show()
end

local function Build()
	button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	Quick.button = button
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("useOnKeyDown", false)
	button:SetAttribute("type2", "spell")
	button:HookScript("OnEnter", ShowTip)
	button:HookScript("OnLeave", function()
		if type(GameTooltip_Hide) == "function" then GameTooltip_Hide() end
		hovered = nil
		Detach()
	end)
	button:HookScript("PostClick", function(self, mouse)
		if mouse == "LeftButton" and self.owner and self.owner.pin then self.owner.pin(self.owner) end
	end)
	button:Hide()
	return button
end

local function Gone(frame)
	if button and button.owner and button.owner.button == frame then
		hovered = nil
		Detach()
	end
end

local function Held(bag)
	for _, each in ipairs(Data.HeldBags()) do
		if each == bag then return true end
	end
	return false
end

local function Attach()
	local slot = hovered
	if not slot or InCombatLockdown() or Data.Plain(IsAltKeyDown(), "boolean") ~= true or not Held(slot.bag) then return end
	local spell = Quick.Spell(slot.bag, slot.id)
	if not spell or not K.Widgets.Cover(button or Build(), slot.button) then return end
	button:SetAttribute("spell2", spell)
	button:SetAttribute("target-bag", slot.bag)
	button:SetAttribute("target-slot", slot.id)
	button.owner, button.spell, button.bag, button.slot = slot, spell, slot.bag, slot.id
	button:SetFrameStrata(slot.button:GetFrameStrata())
	button:SetFrameLevel(slot.button:GetFrameLevel() + OVERLAY_LEVEL)
	if not watched[slot.button] then
		watched[slot.button] = true
		slot.button:HookScript("OnHide", Gone)
	end
	button:Show()
end

function Quick.Enter(slot)
	hovered = slot
	Attach()
end

function Quick.Leave()
	if button and button:IsShown() and button:IsMouseOver() then return end
	hovered = nil
	Detach()
end

local function OnModifier()
	if Data.Plain(IsAltKeyDown(), "boolean") == true then Attach() else Detach() end
end

function Quick.Sync(running)
	local want = running and Settings.Get("quickActions") == true
	if want == Quick.on then return end
	Quick.on = want
	if want then
		K.Events.Register(OWNER, "MODIFIER_STATE_CHANGED", OnModifier)
		K.Events.Register(OWNER, "PLAYER_REGEN_DISABLED", Detach)
	else
		K.Events.Unregister(OWNER, "MODIFIER_STATE_CHANGED")
		K.Events.Unregister(OWNER, "PLAYER_REGEN_DISABLED")
		hovered = nil
		Detach()
	end
end
