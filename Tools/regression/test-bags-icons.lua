-- test-bags-icons.lua: bag slots show the custom icon set through the Icons service, follow a set change, and keep the game's icon for an item the set lacks.
local B = dofile("Tools/regression/bags_env.lua")
local W = B.W
local Item = B.Item

local POTION, SWORD = 134829, 135274
local A_PATH = "Interface\\AddOns\\KstyleUI_Icons\\Icons\\"
local DATA = { KstyleUI_Icons = { set = "A", icons = { [POTION] = A_PATH .. POTION .. ".png" } } }

local env, K, ns = B.New({
	bags = { [0] = { size = 4, items = { [1] = Item("potion"), [2] = Item("sword") } } },
	setup = function(env)
		env._loaded = {}
		env.C_AddOns = {
			LoadAddOn = function(name)
				env.KstyleUIIconData, env._loaded[name] = W.CoreEnv.DeepCopy(DATA[name]), true
				return true
			end,
			IsAddOnLoaded = function(name) return env._loaded[name] == true end,
		}
	end,
})
env.ToggleAllBags()
env.RunTimers()
W.Settle(env)
local Inventory = ns.Inventory
local potion, sword = Inventory.Slot(0, 1), Inventory.Slot(0, 2)
assert(W.LastCall(potion.icon, "SetTexture")[1] == POTION, "off: a slot shows the game's icon")

K.Options.Write("Icons", "set", "A")
K.Options.Write("Icons", "enabled", true)
env.RunTimers()
assert(W.LastCall(potion.icon, "SetTexture")[1] == A_PATH .. POTION .. ".png", "custom icons on: the open bag redraws its slots with set A's art")
local ar, ag, ab = K.Theme.Accent()
assert(W.SameRGB(potion.icon, ar, ag, ab), "set A is tinted in the class colour")
assert(W.LastCall(sword.icon, "SetTexture")[1] == SWORD and W.SameRGB(sword.icon, 1, 1, 1), "an item the set lacks keeps the game's icon, untinted")

B.Put(env, 0, 3, Item("potion"))
env.RunTimers()
assert(W.LastCall(Inventory.Slot(0, 3).icon, "SetTexture")[1] == A_PATH .. POTION .. ".png", "an item that arrives later shows the custom icon")
B.Put(env, 0, 3, nil)
env.RunTimers()
assert(W.LastCall(Inventory.Slot(0, 3).icon, "SetTexture")[1] == nil, "an emptied slot shows nothing")

K.Options.Write("Icons", "enabled", false)
env.RunTimers()
assert(W.LastCall(potion.icon, "SetTexture")[1] == POTION and W.SameRGB(potion.icon, 1, 1, 1), "custom icons off: the game's icon and colour return")
assert(#env._errors == 0, tostring(env._errors[1]))

print("bag icons ok")
