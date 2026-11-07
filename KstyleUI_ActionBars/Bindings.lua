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

function ns.UpdateHotkeys()
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			for i, b in ipairs(bar.buttons) do
				b:SetHotkey(ns.ShortKey(ns.FirstKey(def.binding .. i), BindingText))
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
	local bound = 0
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar and bar:Shown() then
			for i = 1, bar.count do
				local name = bar.buttons[i]:GetName()
				EachKey(function(key)
					SetOverrideBindingClick(owner, false, key, name, "LeftButton")
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
