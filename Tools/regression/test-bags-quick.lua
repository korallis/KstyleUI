-- test-bags-quick.lua: Quick actions: off by default (a v0.2.8 profile too); switched on, holding Alt over an item a known spell works on puts the secure cast button over the slot with Disenchant or Pick Lock aimed at it, never in combat, while left-click still pins; releasing Alt, leaving or switching off removes it.
local B = dofile("Tools/regression/bags_env.lua")
local Item = B.Item

local DISENCHANT, PICK_LOCK = 13262, 1804
local saved = { version = 42, profiles = { Default = { Bags = {} } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
local bags = { [0] = { size = 16, items = {
	[1] = Item("sword"), [2] = Item("potion"), [3] = Item("junk", { name = "Battered Junkbox", quality = 1 }), [4] = Item("helm", { itemID = 1003 }),
} } }
local env, K, ns = B.New({ saved = saved, bags = bags, setup = function(e)
	e._alt, e._known, e._tips = false, { [DISENCHANT] = true, [PICK_LOCK] = true }, { ["0:3"] = "Locked", ["0:4"] = "Cannot be disenchanted" }
	e.IsAltKeyDown = function() return e._alt end
	e.LOCKED, e.ITEM_DISENCHANT_NOT_DISENCHANTABLE = "Locked", "Cannot be disenchanted"
	e.C_SpellBook = { IsSpellKnown = function(id) return e._known[id] == true end }
	e.C_Spell = e.C_Spell or {}
	e.C_Spell.GetSpellName = function(id) return ({ [DISENCHANT] = "Disenchant", [PICK_LOCK] = "Pick Lock" })[id] end
	e.C_TooltipInfo = { GetBagItem = function(bag, slot) return { lines = { { leftText = e._tips[bag .. ":" .. slot] } } } end }
	rawset(e.GameTooltip, "SetBagItem", function() end)
end })
env.ToggleAllBags()
env.RunTimers()
local Quick = ns.Quick
local function write(key, value) assert(K.Options.Write("Bags", key, value) ~= false, key); env.RunTimers() end
local function slot(id) return ns.Inventory.Slot(0, id) end
local function enter(id) local s = slot(id); s.button:GetScript("OnEnter")(s.button); return s end
local function leave(id) local s = slot(id); s.button:GetScript("OnLeave")(s.button) end
local function alt(down) env._alt = down; env.FireEvent("MODIFIER_STATE_CHANGED", "LALT", down and 1 or 0) end
-- What an Alt-right-click on the button reads: SecureButton_GetModifiedAttribute's "alt-" prefix and "2" suffix lookup (SecureTemplates.lua:6-30, 119-126 at 9dc84f0).
local function dispatch(name)
	for _, key in ipairs({ "alt-" .. name .. "2", "*" .. name .. "2", "alt-" .. name .. "*", "*" .. name .. "*", name }) do
		local value = Quick.button:GetAttribute(key)
		if value ~= nil then return value end
	end
end
local function cast() local b = Quick.button; return b and b:IsShown() and dispatch("type") == "spell" and dispatch("spell") end

-- A v0.2.8 profile: off, and Alt over a weapon makes no button.
assert(K.Store.Module("Bags").quickActions == false and not Quick.on, "quick actions start off")
enter(1); alt(true)
assert(not Quick.button, "an off option builds no secure button")
alt(false); leave(1)

-- Switched on: Alt over an uncommon weapon aims Disenchant at it; without Alt nothing covers the slot.
write("quickActions", true)
enter(1)
assert(not cast(), "no Alt, no button")
alt(true)
assert(cast() == DISENCHANT, "Alt-right-click over a weapon casts Disenchant")
assert(dispatch("target-bag") == 0 and dispatch("target-slot") == 1, "aimed at that slot")
alt(false)
assert(not cast(), "releasing Alt removes it")

-- A locked box offers Pick Lock; a potion and an item that cannot be disenchanted offer nothing.
leave(1); alt(true); enter(3)
assert(cast() == PICK_LOCK and dispatch("target-slot") == 3, "a locked box offers Pick Lock")
leave(3); enter(2)
assert(not cast(), "a potion offers nothing")
leave(2); enter(4)
assert(not cast(), "an item that cannot be disenchanted offers nothing")
leave(4)

-- An unknown spell offers nothing.
env._known[DISENCHANT] = nil
enter(1)
assert(not cast(), "without Disenchant there is nothing to cast")
leave(1)
env._known[DISENCHANT] = true

-- Combat removes it as it starts and keeps it away.
enter(1)
assert(cast() == DISENCHANT, "back over the weapon")
env.SetCombat(true); env.RunTimers()
assert(not cast(), "combat removes the button")
alt(false); alt(true)
assert(not cast(), "and Alt in combat brings nothing")
env.SetCombat(false); env.RunTimers()
alt(false); alt(true)
assert(cast() == DISENCHANT, "after combat it works again")

-- Left-click still pins while the button covers the slot.
write("pins", true)
Quick.button:GetScript("PostClick")(Quick.button, "LeftButton")
env.RunTimers()
assert(ns.Data.Pins()[1000], "left-click pins the item under the button")

-- Closing the bags hides the slot, and the button goes with it even with the cursor still over it (the stubs run no OnHide, so the test runs the slot's).
Quick.button._mouseOver = true
env.ToggleAllBags(); env.RunTimers()
slot(1).button:GetScript("OnHide")(slot(1).button)
assert(not cast(), "closing the bags removes the button")
Quick.button._mouseOver = nil
env.ToggleAllBags(); env.RunTimers()
alt(false); alt(true); enter(1)
assert(cast() == DISENCHANT, "open again, it works")
-- Leaving the slot, or switching off, removes it; off, Alt brings nothing.
leave(1)
assert(not cast(), "leaving the slot removes it")
enter(1)
assert(cast() == DISENCHANT, "over the weapon again")
write("quickActions", false)
assert(not cast() and not Quick.on, "off removes the button")
alt(false); alt(true)
assert(not cast(), "and Alt brings nothing")

-- The PR #657 review's probes: the item under the button changes while Alt is held, and an unreadable tooltip.
write("quickActions", true)
enter(1)
assert(cast() == DISENCHANT, "back over the weapon with Alt held")
local function swap(name)
	bags[0].items[1] = Item(name)
	env.FireEvent("BAG_UPDATE", 0); env.FireEvent("BAG_UPDATE_DELAYED"); env.RunTimers()
end
swap("potion")
assert(not cast(), "a potion now in the slot under the button offers nothing")
swap("sword")
assert(cast() == DISENCHANT, "the weapon back in the slot offers Disenchant again")
leave(1)
local tooltip = env.C_TooltipInfo.GetBagItem
env.C_TooltipInfo.GetBagItem = function() return nil end
assert(Quick.Spell(0, 1) == nil and Quick.Spell(0, 4) == nil, "an unreadable tooltip offers nothing")
env.C_TooltipInfo.GetBagItem = function() return { lines = { { leftText = env.Secret("Cannot be disenchanted") } } } end
assert(Quick.Spell(0, 4) == nil, "a secret tooltip line offers nothing")
env.C_TooltipInfo.GetBagItem = tooltip
assert(Quick.Spell(0, 1) == DISENCHANT, "a readable tooltip offers it again")

-- The options preview shows the hint on its sample equipment, with no live cast button.
alt(false)
local hints = {}
rawset(env.GameTooltip, "AddLine", function(_, text) hints[#hints + 1] = text end)
local preview = K.Options.Preview("Bags")(env.CreateFrame("Frame", nil, K.Scale.Root()))
local function hover()
	hints = {}
	for _, s in ipairs(preview.slots) do
		if s.button:IsShown() then s.button:GetScript("OnEnter")(s.button); s.button:GetScript("OnLeave")(s.button) end
	end
	return hints
end
assert(hover()[1] == "Alt-right-click: Disenchant", "the preview's sample equipment shows the hint, got " .. tostring(hints[1]))
assert(not cast(), "and no cast button")
write("quickActions", false)
preview:Refresh()
assert(not hover()[1], "off, the preview shows no hint")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-bags-quick: ok")
