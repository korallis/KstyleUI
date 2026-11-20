-- Bindings.lua: mirrors the player's own Blizzard keybinds onto KstyleUI's buttons with override bindings, out of combat.
local _, ns = ...

local K = KstyleUI

local owner
local pending = false

local function EachKey(fn, ...)
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		if type(key) == "string" and key ~= "" and not ns.IsSecret(key) then
			fn(key)
		end
	end
end

function ns.FirstKey(name)
	if type(GetBindingKey) ~= "function" then
		return nil
	end
	local key = GetBindingKey(name)
	if ns.IsSecret(key) or type(key) ~= "string" then
		return nil
	end
	return key
end

local function BindingText(key)
	if type(GetBindingText) == "function" then
		local text = GetBindingText(key, true)
		if type(text) == "string" and not ns.IsSecret(text) then
			return text
		end
	end
	return key
end

function ns.UpdateHotkey(b)
	local def = b.kbar.def
	local text = ns.ShortKey(ns.FirstKey(def.binding .. b.index), BindingText)
	local unbound = ns.Config("bindingHints") and text == "" and b.kind == "action" and b.hasAction ~= false
	b.keyHasAction = b.hasAction
	b:SetHotkey(unbound and "-" or text)
	b.hotkey:SetAlpha(unbound and 0.4 or 1)
end

function ns.UpdateHotkeys()
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			for _, b in ipairs(bar.buttons) do
				ns.UpdateHotkey(b)
			end
		end
	end
end

local function Apply()
	pending = false
	if InCombatLockdown() and not ns.enabling then
		pending = true
		K.Combat.Queue(Apply)
		return
	end
	if type(ClearOverrideBindings) ~= "function" or type(SetOverrideBindingClick) ~= "function" or type(GetBindingKey) ~= "function" then
		ns.LogOnce("noBindings", "override binding functions are missing; Blizzard's bindings stay on Blizzard's hidden buttons")
		return
	end
	owner = owner or CreateFrame("Frame")
	ClearOverrideBindings(owner)
	if not ns.running or ns.gamepad then
		ns.UpdateHotkeys()
		return
	end
	local detected = K.Setup.Integrations.Detected("ActionBars")
	if #detected > 0 and not ns.Config("overlapBindings") then
		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(0, function()
				if not ns.running or ns.Config("overlapBindings") or not K.Store.Module("Integrations").notices then return end
				local account, unseen = K.Store.Account(), {}
				account.bindingNotices = account.bindingNotices or {}
				for _, addon in ipairs(K.Setup.Integrations.Detected("ActionBars")) do
					if not account.bindingNotices[addon] then unseen[#unseen + 1] = addon; account.bindingNotices[addon] = true end
				end
				if #unseen == 0 then return end
				K.Print(string.format(K.L["KstyleUI action bar bindings are off while %s is loaded. Turn Action bars off and on in settings to use KstyleUI's bindings."], table.concat(unseen, ", ")))
			end)
		end
		ns.UpdateHotkeys()
		return
	end
	local bound = 0
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar and bar:Shown() then
			for i = 1, bar.count do
				local name = bar.buttons[i]:GetName()
				EachKey(function(key)
					SetOverrideBindingClick(owner, false, key, name, "Keybind")
					bound = bound + 1
				end, GetBindingKey(def.binding .. i))
			end
		end
	end
	ns.LogOnce("bound" .. bound, "mirrored " .. bound .. " keybinds onto KstyleUI's buttons")
	ns.UpdateHotkeys()
end

function ns.ApplyBindings()
	if pending then
		return
	end
	Apply()
end
