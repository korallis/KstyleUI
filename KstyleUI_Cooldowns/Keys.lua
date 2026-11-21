-- Keys.lua: the key a cooldown's spell is bound to, read from the first action slot that holds it: the key of the KstyleUI action button that shows the slot while Action Bars runs, else Blizzard's binding for that slot's bar (the main bar's while its page shows it); and the spell an action slot holds, for mirrored presses.
local _, ns = ...

local K = KstyleUI
local Plain = ns.Plain

local Keys = {}
ns.Keys = Keys

local PER_PAGE = 12
local BARS = { [3] = "MULTIACTIONBAR3BUTTON", [4] = "MULTIACTIONBAR4BUTTON", [5] = "MULTIACTIONBAR2BUTTON", [6] = "MULTIACTIONBAR1BUTTON", [13] = "MULTIACTIONBAR5BUTTON", [14] = "MULTIACTIONBAR6BUTTON", [15] = "MULTIACTIONBAR7BUTTON" }
local found = {}

local function Ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok and Plain(a) ~= nil then return a, b end
end

local function MainPage()
	local bar = C_ActionBar
	if not bar then return nil end
	for _, kind in ipairs({ "Vehicle", "Override", "TempShapeshift" }) do
		local on = Ask(bar["Has" .. kind .. "ActionBar"])
		if on ~= false then return on and Ask(bar["Get" .. kind .. "BarIndex"]) or nil end
	end
	local page = Ask(bar.GetActionBarPage)
	if page ~= 1 then return page end
	local bonus = Ask(bar.HasBonusActionBar)
	if bonus ~= false then return bonus and Ask(bar.GetBonusBarIndex) or nil end
	return page
end

local function BindingText(key)
	local text = Ask(GetBindingText, key, true)
	return type(text) == "string" and text or key
end

local function Bound(command)
	local key = Ask(GetBindingKey, command)
	return key ~= "" and key or nil
end

local function Key(slot, main)
	local key = K.Widgets.ActionKey(slot)
	if key == nil then
		local page, index = math.floor((slot - 1) / PER_PAGE) + 1, (slot - 1) % PER_PAGE + 1
		key = page == main and Bound("ACTIONBUTTON" .. index) or BARS[page] and Bound(BARS[page] .. index)
	end
	if type(key) == "string" then return K.Widgets.ShortKey(key, BindingText) end
end

function Keys.For(spell)
	if type(Plain(spell)) ~= "number" then return nil end
	local key = found[spell]
	if key == nil then
		key = false
		local slots = Ask(C_ActionBar and C_ActionBar.FindSpellActionButtons, spell)
		if type(slots) == "table" then
			local main = MainPage()
			for _, slot in ipairs(slots) do
				key = type(Plain(slot)) == "number" and Key(slot, main) or false
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
	if type(Plain(slot)) ~= "number" then return nil end
	local kind, id = Ask(GetActionInfo, slot)
	if kind == "spell" and Plain(id) ~= nil then return id end
end
