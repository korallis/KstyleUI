-- gallery_bags.lua: the Bags module's frames in a filled state, each cropped as one frame of the gallery: the bag
-- window open at a banker and a merchant with items of every quality, stacks, an empty slot, a quest item, a new
-- item, a locked item and one on cooldown, its search box, Sort and Sell junk buttons and the free-slots and money
-- footer; a close crop of six slots; the bank window on the character bank with its Bank and Warband tabs, its
-- bank bag strip and the Buy tab button; and the options page's live preview on a plain holder.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene

local function at(frame, root, x, y)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
end

return Common.Run(function()
	local B = dofile("Tools/regression/bags_env.lua")
	local W = B.W
	local Item = B.Item
	local set = Common.IconSet()

	-- The backpack: one row that shows every slot state, then stacks, a quest item and a locked item.
	local quest = Item("key", { itemID = 5000, name = "Sealed Orders", icon = 134939, classID = 12, type = "Quest", subtype = "Quest" })
	local bags = {
		[0] = { size = 16, items = {
			[1] = Item("potion", { cooldown = { 0, 30 } }), [2] = Item("sword"), [3] = Item("helm"), [4] = Item("junk"),
			[5] = Item("ring"), [7] = Item("hearth"), [8] = Item("cloth"), [9] = quest, [10] = Item("greyNoValue"),
			[12] = Item("potion", { count = 2 }), [13] = Item("sword", { itemID = 1010, name = "Cutlass", icon = 135274 }),
		} },
		[1] = { size = 10, items = { [1] = Item("cloth", { count = 7 }), [2] = Item("junk", { count = 1 }), [4] = Item("potion", { count = 3 }) } },
		[2] = { size = 8, items = { [1] = Item("ring", { itemID = 1020, name = "Seal of Wrynn", icon = 133344, quality = 2, ilvl = 18 }), [8] = Item("hearth", { itemID = 6949, name = "Linen Bandage", icon = 134414, count = 12 }) } },
		[3] = { size = 6, items = { [1] = Item("cloth", { count = 20 }) } },
		[4] = { size = 6, items = {} },
		[-1] = { size = 4, items = { [1] = Item("key"), [2] = Item("key", { itemID = 3001, name = "Shadowforge Key", icon = 134237 }) } },
	}
	-- The bank: three character tabs and one Warband tab, two bank bags bought.
	local bank = {
		[6] = { size = 28, items = { [1] = Item("cloth"), [2] = Item("helm"), [3] = Item("ring"), [5] = Item("potion"), [8] = Item("sword"), [14] = Item("junk"), [15] = Item("cloth", { count = 20 }), [16] = Item("cloth", { count = 20 }) } },
		[7] = { size = 28, items = { [1] = Item("cloth", { count = 20 }), [2] = Item("cloth", { count = 20 }), [3] = Item("hearth"), [10] = Item("potion", { cooldown = { 0, 30 } }) } },
		[8] = { size = 28, items = { [28] = Item("key") } },
		[15] = { size = 28, items = { [1] = Item("ring") } },
	}
	local env, K, ns = B.New(Common.ScreenOpts({
		saved = Gallery.Saved({ Icons = Common.IconsSection(set) }),
		bags = bags,
		bank = bank,
		bankTabs = { [B.BANK.Character] = { 6, 7, 8 }, [B.BANK.Account] = { 15 } },
		bankBags = {
			[2] = Item("cloth", { itemID = 4500, name = "Traveler's Backpack", icon = 133633, count = 1, quality = 2 }),
			[3] = Item("cloth", { itemID = 4501, name = "Small Brown Pouch", icon = 133633, count = 1 }),
		},
		bankMax = 7,
		money = 1234567,
		setup = function(env)
			Common.InstallAddOns(env)
			Gallery.Setup(env)
			env._time = 10
			env.GetTime = function()
				return env._time
			end
		end,
	}))
	local root = K.Scale.Root()
	local frames = Gallery.Frames()
	local hover = {}

	env._new["0:3"] = true
	env._locked["0:13"] = true
	env.SetBank(true)
	env.RunTimers()
	env.SetMerchant(true)
	env.RunTimers()

	local Inventory, Bank = ns.Inventory, ns.Bank
	local inventory, bankWindow = Inventory.window, Bank.window
	assert(Inventory.IsOpen() and Bank.IsOpen(), "the bank visit opened both windows")
	assert(inventory.junkButton:IsShown(), "Sell junk shows at the merchant")
	at(inventory.panel, root, 40, 60)
	at(bankWindow.panel, root, 470, 60)

	local hovered = Inventory.Slot(0, 5)
	W.Enter(hovered.button)
	hover[hovered.button] = true

	-- The options preview on a plain holder, as the settings window's preview pane shows it.
	local holder = env.CreateFrame("Frame", nil, root)
	holder:SetSize(320, 150)
	at(holder, root, 1100, 60)
	local preview = K.Options.Preview("Bags")(holder)
	preview:SetAllPoints(holder)
	preview:Refresh()

	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()

	frames:Add(env, inventory.panel, {
		name = "bags_window", title = "Bag window", grade = "window", reference = "chat",
		caption = "The bag window at a banker and a merchant: a titled glass window with the search box and the Sell junk and Sort buttons on the button body, 46 bag slots on icon tiles (poor to epic rims, stacks, item levels, a junk dot, a new item's glow, a hovered rare, a locked grey item, a potion on cooldown, empty slots at a fainter body), the keyring under them, and the free-slot count and money footer.",
		match = "Window grade: the chat panel's surface fill, dark outer and light inner line, 12-unit chamfer and drop shadow; the slots inside are the button grade, with the quality colour where the mockup's action buttons wear the class rim.",
	})
	local row = {}
	for slotID = 1, 6 do
		row[#row + 1] = Inventory.Slot(0, slotID).button
	end
	frames:Add(env, nil, {
		name = "bags_slots", title = "Bag slots", grade = "button", reference = "actionbars", pad = 10,
		rect = assert(Gallery.Union(env, row), "the first six slots resolve"),
		caption = "Six slots of the backpack's first row: a potion stack on cooldown with the accent rim, an uncommon sword with its item level, a new epic helm with the pulsing glow, poor junk with the gold dot and its count, a rare ring under the mouse with the rim eased to the accent, and an empty slot with the plain grey hairline on the 55% body.",
		match = "Button grade: the #101214 body with the 3.5-unit chamfer and a one-border rim as the mockup's action buttons; the rim takes the item's quality colour instead of the class colour, and the slot has no bezel or shadow, as an aura tile.",
	})
	frames:Add(env, bankWindow.panel, {
		name = "bags_bank", title = "Bank window", grade = "window", reference = "tracker",
		caption = "The bank window on the character bank: the Bank and Warband tab strip, the search box with the Buy tab and Sort buttons, two bank bag slots in a strip under them, three purchased tabs' 84 slots in a 14-column grid, and the free-slot and money footer.",
		match = "Window grade as the mockup's tracker: surface fill, two-line edge, 12-unit chamfer and shadow; the tab strip, search box and buttons are the button body with the edgeInner hairline, and the slots the button grade.",
	})
	frames:Add(env, holder, {
		name = "bags_preview", title = "Bags preview", grade = "button", reference = "bufficons",
		caption = "The options page's live preview for Bags: the heading and eight sample slots drawn by the module's own slot code with the current settings (a stack, an uncommon, a new epic, a rare, junk, two commons and an empty slot); the preview draws no chrome of its own and sits in the options window's preview pane.",
		match = "Each sample slot is the button grade's body, chamfer and rim, as the mockup's buff icons; the plate behind them is the render's backdrop, not a panel, because the preview pane belongs to the Options module.",
	})

	local scene = Scene.Build(env, { time = env._time, hover = hover })
	scene.log[#scene.log + 1] = "icons: " .. (set and ("custom set " .. set) or "Blizzard's, with the sets standing in for icons the folder lacks")
	return frames:Finish(scene, env, K, "gallery bags")
end)
