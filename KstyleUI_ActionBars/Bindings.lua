-- Bindings.lua: mirrors the player's own Blizzard keybinds onto KstyleUI's buttons with override bindings, out of combat, and shows a gamepad key as the game's button glyph while a gamepad is active.
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

local GLYPHS = {
	PAD1 = { "buttona", "buttoncrox", "face-b" }, PAD2 = { "buttonb", "buttoncircle", "face-a" },
	PAD3 = { "buttonx", "buttonsquare", "face-y" }, PAD4 = { "buttony", "buttontriangle", "face-x" },
	PADDUP = { "dpadup", "dpadup", "dpad-up" }, PADDDOWN = { "dpaddown", "dpaddown", "dpad-down" },
	PADDLEFT = { "dpadleft", "dpadleft", "dpad-left" }, PADDRIGHT = { "dpadright", "dpadright", "dpad-right" },
	PADLSHOULDER = { "trigger-lb", "triggerl1", "shoulder-l" }, PADRSHOULDER = { "trigger-rb", "triggerr1", "shoulder-r" },
	PADLTRIGGER = { "trigger-lt", "triggerl2", "zl" }, PADRTRIGGER = { "trigger-rt", "triggerr2", "zr" },
	PADLSTICK = { "stick-l3", "stickl3", "stick-l3" }, PADRSTICK = { "stick-r3", "stickr3", "stick-r3" },
	PADBACK = { "view", "touchpad", "minus" }, PADFORWARD = { "menu", "menu", "plus" },
	SHIFT = "PADLTRIGGER", CTRL = "PADRTRIGGER",
}
local XBOX, FAMILIES = { 1, "gamepad-xbox1-" }, { Shapes = { 2, "gamepad-ps-" }, Reverse = { 3, "gamepad-switch-128x-" } }

local function Atlas(names, family)
	local atlas = family[2] .. names[family[1]] .. "-normal"
	if type(C_Texture) == "table" and type(C_Texture.GetAtlasInfo) == "function" and C_Texture.GetAtlasInfo(atlas) then return atlas end
end

local function Glyphs(key, size)
	local pad, family = C_GamePad, XBOX
	if type(pad) == "table" and type(pad.GetActiveDeviceID) == "function" and type(pad.GetDeviceMappedState) == "function" then
		local state = pad.GetDeviceMappedState(pad.GetActiveDeviceID())
		local style = type(state) == "table" and state.labelStyle
		if not ns.IsSecret(style) and FAMILIES[style] then family = FAMILIES[style] end
	end
	local out = ""
	for part in key:gmatch("[^%-]+") do
		local names = GLYPHS[GLYPHS[part]] or GLYPHS[part]
		local atlas = type(names) == "table" and (Atlas(names, family) or Atlas(names, XBOX))
		if not atlas then return nil end
		out = out .. ("|A:%s:%d:%d|a"):format(atlas, size, size)
	end
	return out
end

local function PadKey(name)
	local found
	if type(GetBindingKey) == "function" and type(IsBindingForGamePad) == "function" then
		EachKey(function(key)
			local pad = IsBindingForGamePad(key)
			if not found and not ns.IsSecret(pad) and pad then found = key end
		end, GetBindingKey(name))
	end
	return found
end

function ns.UpdateHotkey(b)
	local name = b.kbar.def.binding .. b.index
	local pad = ns.padActive and ns.Config("padGlyphs") ~= false and PadKey(name)
	local glyphs = pad and Glyphs(pad, math.floor((select(2, b.hotkey:GetFont()) or 12) * 1.5 + 0.5))
	local text = glyphs or K.Widgets.ShortKey(ns.FirstKey(name), BindingText)
	local unbound = ns.Config("bindingHints") and text == "" and b.kind == "action" and b.hasAction ~= false
	b.keyHasAction = b.hasAction
	if glyphs then K.Widgets.SetText(b.hotkey, glyphs) else b:SetHotkey(unbound and "-" or text) end
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
	K.Widgets.SetActionKeys(ns.Button.KeyFor)
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
