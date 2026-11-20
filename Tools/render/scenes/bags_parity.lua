-- bags_parity.lua: the bag window with the parity options on: labels, sections, merged stacks, the reagent marker, the
-- bag strip and tracked currencies; RENDER_BAGS_LIST=1 shows the list view at a banker, RENDER_BAGS_DEFAULTS=1 no options
-- (with RENDER_BAGS_COMPACT=1, only Compact bags); RENDER_BAGS_OPTIONS=<key> opens the Options page at that row.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local B = dofile("Tools/regression/bags_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Item = B.Item

local TILES = {
	compactBags = true, recentItems = true, recentClear = true, mergeStacks = true, sectionValue = true, gearBySlot = true,
	compactGroups = true, splitSets = true, bindText = true, setNames = true, reagentMark = true, currencies = true,
	bagSlots = true, capSize = 12, maxHeight = 80,
}
local LIST = {
	compactBags = true, listView = true, splitTypes = true, sectionValue = true, nestExpansion = true, setNames = true,
	listLeft = 4, listRight = 4, reagentMark = true, bankNestExpansion = true,
}

return Common.Run(function()
	local list = os.getenv("RENDER_BAGS_LIST") == "1"
	local defaults = os.getenv("RENDER_BAGS_DEFAULTS") == "1"
	local bags = {
		[0] = { size = 16, items = {
			[1] = Item("potion", { count = 4 }), [2] = Item("sword", { bind = 2, equipLoc = "INVTYPE_WEAPON" }),
			[3] = Item("helm", { bound = true, equipLoc = "INVTYPE_HEAD", expansion = 1 }), [4] = Item("ring", { bound = true, equipLoc = "INVTYPE_FINGER" }),
			[5] = Item("cloth"), [6] = Item("cloth"), [7] = Item("junk"), [8] = Item("hearth"),
			[9] = Item("cloth", { itemID = 4338, name = "Mageweave Cloth", subtype = "Mageweave", icon = 132892, count = 12 }),
		} },
		[1] = { size = 10, items = { [1] = Item("cloth", { count = 7 }), [2] = Item("potion", { count = 3 }) } },
		[5] = { size = 8, items = { [1] = Item("cloth", { itemID = 2589, name = "Linen Cloth", subtype = "Cloth", count = 14, reagent = true }), [2] = Item("cloth", { itemID = 4338, name = "Mageweave Cloth", subtype = "Mageweave", icon = 132892, count = 5, reagent = true }) } },
		[-1] = { size = 4, items = { [1] = Item("key") } },
	}
	local bank = {
		[6] = { size = 14, items = { [1] = Item("helm", { itemID = 1101, expansion = 1 }), [2] = Item("sword", { itemID = 1003, name = "Rusty Blade" }), [3] = Item("cloth", { count = 20 }), [5] = Item("potion") } },
	}
	local env, K, ns = B.New(Common.ScreenOpts({
		saved = Gallery.Saved({}),
		bags = bags,
		bank = bank,
		money = 1234567,
		sets = { { name = "Tank", items = { 1000, 1002 } } },
		currencies = { { name = "Honor", quantity = 1250, iconFileID = 463448 }, { name = "Arena", quantity = 80, iconFileID = 133784 } },
		equippedBags = { [1] = { icon = 133633, quality = 1 }, [2] = { icon = 133633, quality = 2 }, [3] = { icon = 133633, quality = 1 }, [4] = { icon = 133633, quality = 1 }, [5] = { icon = 133633, quality = 3 } },
		setup = function(env)
			Gallery.Setup(env)
			env.GetMoneyString = nil
			env.INVTYPE_HEAD, env.INVTYPE_WEAPON, env.INVTYPE_FINGER = "Head", "One-Hand", "Finger"
			env.EXPANSION_NAME0, env.EXPANSION_NAME1 = "Classic", "Burning Crusade"
			env.C_AddOns = env.C_AddOns or {}
			env.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not env._addons.KstyleUI_Options then Load(O.Files(), env) end
				return true
			end
		end,
	}))
	if os.getenv("RENDER_BAGS_COMPACT") == "1" then
		assert(K.Options.Write("Bags", "compactBags", true) ~= false)
	end
	if not defaults then
		for key, value in pairs(list and LIST or TILES) do
			assert(K.Options.Write("Bags", key, value) ~= false, key .. " must write")
		end
	end
	env._new["0:1"] = true
	if list or defaults then
		env.SetBank(true)
	else
		env.ToggleAllBags()
	end
	env.RunTimers()
	assert(ns.Inventory.IsOpen() and ns.Bank.IsOpen() == (list or defaults), "the bags open, with the bank for the list view and defaults")
	local key = os.getenv("RENDER_BAGS_OPTIONS")
	if key then
		assert(K.Options.Open("Bags"))
		env.RunTimers()
		assert(K.Layout.Set("Options.Window", "height", 900))
		assert(K.Layout.Set("Options.Window", "anchor", "TOPLEFT"))
		assert(K.Layout.Set("Options.Window", "x", 28))
		assert(K.Layout.Set("Options.Window", "y", -28))
		env._addons.KstyleUI_Options.Window.Jump({ page = "Bags", module = "Bags", key = key })
		env.RunTimers()
		O.W.Settle(env)
	end
	local scene = Gallery.Build(env)
	local errors = Common.Errors(env, K)
	assert(not errors, errors)
	scene.log[#scene.log + 1] = "bags parity: " .. (defaults and "defaults" or list and "list view" or "tiles")
	return scene
end)
