-- gallery_bags_browse.lua: the bag window browsing another character: the picker set to a saved alt, that
-- character's bags and bank from KstyleUI's own account data as read-only tiles under the Lumen caps, and the
-- footer with their free slots and money.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

return Common.Run(function()
	local B = dofile("Tools/regression/bags_env.lua")
	local W = B.W
	local Item = B.Item
	local bags = {
		[0] = { size = 16, items = { [1] = Item("potion"), [2] = Item("sword"), [3] = Item("cloth") } },
	}
	local env, K, ns = B.New(Common.ScreenOpts({
		saved = Gallery.Saved({}),
		bags = bags,
		money = 1234567,
		player = "Valerin",
		realm = "Lordaeron",
		setup = function(env)
			Gallery.Setup(env)
			env.GetMoneyString = nil
		end,
	}))
	local root = K.Scale.Root()
	local frames = Gallery.Frames()

	-- A warrior this account played last week, as Alts.lua saves one.
	local saved = K.Store.Account().inventory
	saved.characters["Lordaeron-Thargor"] = {
		name = "Thargor", realm = "Lordaeron", class = "WARRIOR", seen = saved.characters["Lordaeron-Valerin"].seen,
		bags = { [1000] = 1, [1001] = 1, [118] = 9, [6948] = 1, [4306] = 20, [2000] = 4 },
		bank = { [1002] = 1, [4306] = 60, [118] = 15, [6949] = 12 },
		items = {
			[1000] = { icon = 135274, quality = 2, cat = "equipment", name = "Worn Shortsword" },
			[1001] = { icon = 133074, quality = 4, cat = "equipment", name = "Nightslayer Cover" },
			[1002] = { icon = 133344, quality = 3, cat = "equipment", name = "Band of Thorns" },
			[118] = { icon = 134829, quality = 1, cat = "consumables", name = "Minor Healing Potion" },
			[6948] = { icon = 134414, quality = 1, cat = "other", name = "Hearthstone" },
			[6949] = { icon = 134414, quality = 1, cat = "consumables", name = "Linen Bandage" },
			[4306] = { icon = 132905, quality = 1, cat = "tradeGoods", name = "Silk Cloth" },
			[2000] = { icon = 133723, quality = 0, cat = "junk", name = "Broken Fang" },
		},
		free = 31, total = 40, bankFree = 44, bankTotal = 52, money = 4518263,
	}

	env.ToggleAllBags()
	env.RunTimers()
	local win = ns.Inventory.window
	assert(win.picker:IsShown(), "the picker shows once another character is saved")
	assert(win.picker:SetValue("Lordaeron-Thargor"), "Thargor is one of the picker's options")
	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()
	win.panel:ClearAllPoints()
	win.panel:SetPoint("TOPLEFT", root, "TOPLEFT", 40, -60)
	assert(win.remote and win.remote.frame:IsShown(), "the saved view is up")

	frames:Add(env, win.panel, {
		name = "bags_browse", title = "Bag window, another character", grade = "window", reference = "chat",
		caption = "The bag window browsing a saved character: the picker in the header set to Thargor, his bags' items by category and then his bank on plain read-only tiles with the stack counts and quality rims, under the same Lumen caps, and the footer with his free slots and money from KstyleUI's own account data.",
		match = "Window grade as the live bag window: the chat panel's surface fill, two-line edge, 12-unit chamfer and drop shadow; the tiles are the button grade, as the live slots.",
	})
	local scene = Gallery.Build(env, { time = env._time })
	scene.log[#scene.log + 1] = "icons: set B's repaint for every file ID the pack has, else Blizzard's icon, as the installed pack shows them"
	return frames:Finish(scene, env, K, "gallery bags browse")
end)
