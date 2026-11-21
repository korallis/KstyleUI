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
local function cast() local b = Quick.button; return b and b:IsShown() and b:GetAttribute("spell2") end

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
assert(cast() == DISENCHANT and Quick.button:GetAttribute("type2") == "spell", "Alt over a weapon offers Disenchant")
assert(Quick.button:GetAttribute("target-bag") == 0 and Quick.button:GetAttribute("target-slot") == 1, "aimed at that slot")
alt(false)
assert(not cast(), "releasing Alt removes it")

-- A locked box offers Pick Lock; a potion and an item that cannot be disenchanted offer nothing.
leave(1); alt(true); enter(3)
assert(cast() == PICK_LOCK and Quick.button:GetAttribute("target-slot") == 3, "a locked box offers Pick Lock")
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
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-bags-quick: ok")
