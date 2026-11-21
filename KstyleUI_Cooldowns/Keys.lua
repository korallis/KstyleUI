-- Keys.lua: the key a cooldown's spell is bound to, read from the first action slot that holds it and Blizzard's binding name for that slot's bar (the main bar's only while its page shows), and the spell an action slot holds, for mirrored presses.
local _, ns = ...

local K = KstyleUI

local Keys = {}
ns.Keys = Keys

local PER_PAGE = 12
local BARS = { [3] = "MULTIACTIONBAR3BUTTON", [4] = "MULTIACTIONBAR4BUTTON", [5] = "MULTIACTIONBAR2BUTTON", [6] = "MULTIACTIONBAR1BUTTON", [13] = "MULTIACTIONBAR5BUTTON", [14] = "MULTIACTIONBAR6BUTTON", [15] = "MULTIACTIONBAR7BUTTON" }
local found = {}

local function Plain(value)
	return value ~= nil and not ns.IsSecret(value)
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok and Plain(a) then return a, b end
end

local function MainPage()
	local bar = C_ActionBar
	if not bar then return nil end
	for _, kind in ipairs({ "Vehicle", "Override", "TempShapeshift" }) do
		local on = Ask(bar["Has" .. kind .. "ActionBar"])
		if on ~= false then return on and Ask(bar["Get" .. kind .. "BarIndex"]) or nil end
	end
	local page = Ask(bar.GetActionBarPage)
	if page == 1 and Ask(bar.HasBonusActionBar) then return Ask(bar.GetBonusBarIndex) end
	return page
end

local function BindingText(key)
	local text = Ask(GetBindingText, key, true)
	return type(text) == "string" and text or key
end

local function Key(slot, main)
	local page, index = math.floor((slot - 1) / PER_PAGE) + 1, (slot - 1) % PER_PAGE + 1
	local command = BARS[page] or page == main and "ACTIONBUTTON"
	local key = command and Ask(GetBindingKey, command .. index)
	if type(key) == "string" and key ~= "" then return K.Widgets.ShortKey(key, BindingText) end
end

function Keys.For(spell)
	if not Plain(spell) or type(spell) ~= "number" then return nil end
	local key = found[spell]
	if key == nil then
		key = false
		local slots = Ask(C_ActionBar and C_ActionBar.FindSpellActionButtons, spell)
		if type(slots) == "table" then
			local main = MainPage()
			for _, slot in ipairs(slots) do
				key = Plain(slot) and type(slot) == "number" and Key(slot, main) or false
				if key then break end
			end
		end
		found[spell] = key
	end
	return key or nil
end

function Keys.Reset()
	found = {}
end

function Keys.Spell(slot)
	if not Plain(slot) or type(slot) ~= "number" then return nil end
	local kind, id = Ask(GetActionInfo, slot)
	if kind == "spell" and Plain(id) then return id end
end
