-- test-bags-alts.lua: KstyleUI_Bags counts each character's items from its bags and bank into KstyleUI's own saved data and shows the other characters' counts in item tooltips.
local B = dofile("Tools/regression/bags_env.lua")
local W = B.W
local Item, BANK = B.Item, B.BANK

local POTION, CLOTH, SWORD = 118, 4306, 1000

local function Bags()
	return {
		[0] = { size = 16, items = { [1] = Item("potion"), [2] = Item("sword"), [3] = Item("potion", { count = 3 }) } },
		[1] = { size = 8, items = { [1] = Item("cloth") } },
		[-1] = { size = 4, items = { [1] = Item("key") } },
	}
end

local function Bank()
	return {
		[6] = { size = 24, items = { [1] = Item("cloth", { count = 7 }), [2] = Item("helm") } },
		[15] = { size = 12, items = { [1] = Item("potion", { count = 2 }) } },
	}
end

local function Run(env)
	env.RunTimers()
	W.Settle(env)
end

local function Find(lines, text)
	for _, line in ipairs(lines) do
		if type(line[1]) == "string" and line[1]:find(text, 1, true) then
			return line
		end
	end
	return nil
end

-- Scanning: the bags count at Enable and on bag changes; the bank counts during a visit -----------------

do
	local env, K, ns = B.New({ bags = Bags(), bank = Bank(), bankTabs = { [BANK.Character] = { 6 }, [BANK.Account] = { 15 } }, player = "Valerin", realm = "Lordaeron" })
	assert(type(ns.Alts) == "table", "KstyleUI_Bags has an Alts table")
	local saved = K.Store.Account().inventory
	assert(type(saved) == "table" and type(saved.characters) == "table", "the counts live in KstyleUI's account data")
	local me = saved.characters["Lordaeron-Valerin"]
	assert(type(me) == "table" and me.name == "Valerin" and me.realm == "Lordaeron" and me.class == "HUNTER", "this character is recorded with name, realm and class")
	assert(me.bags[POTION] == 8 and me.bags[SWORD] == 1 and me.bags[CLOTH] == 20, "the bags count stacks per item, got " .. tostring(me.bags[POTION]))
	assert(me.bags[3000] == nil, "the keyring is not counted")
	assert(next(me.bank) == nil, "the bank is unknown until a visit")
	B.Put(env, 0, 2, nil)
	Run(env)
	assert(me.bags[SWORD] == nil, "an item that leaves the bags leaves the count")
	env.SetBank(true)
	Run(env)
	assert(me.bank[CLOTH] == 7 and me.bank[1001] == 1, "the bank counts the character bank's tabs during a visit")
	assert(saved.warband[POTION] == 2, "and the Warband bank once, for the account")
	env.SetBank(false)
	Run(env)
	assert(me.bank[CLOTH] == 7, "the bank counts stay after the visit")
	env.SetBank(true)
	Run(env)
	env._bank[6].items[3] = Item("potion", { count = 4 })
	env.FireEvent("PLAYERBANKSLOTS_CHANGED", 3)
	env.SetBank(false)
	assert(me.bank[POTION] == 4, "a bank change counts at once, so leaving the bank straight after keeps it")
	Run(env)
	env._bank[6].items[4] = Item("potion", { count = env.Secret(9) })
	env.SetBank(true)
	Run(env)
	assert(me.bank[POTION] == 4, "a stack whose count is secret is not counted as one")
	env.SetBank(false)
	Run(env)
	local secret = Item("cloth", { count = 4 })
	local info = env.C_Container.GetContainerItemInfo
	env.C_Container.GetContainerItemInfo = function(bag, slot)
		local record = info(bag, slot)
		if record and bag == 1 then
			record.itemID = env.Secret(record.itemID)
		end
		return record
	end
	B.Put(env, 1, 2, secret)
	Run(env)
	assert(me.bags[CLOTH] == nil, "a secret item ID is not counted and does not error")
	env.C_Container.GetContainerItemInfo = info
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Tooltips: other characters' counts, class coloured, with this character's bank -----------------------

do
	local saved = {
		version = 1,
		account = {
			inventory = {
				version = 1,
				characters = {
					["Lordaeron-Ayla"] = { name = "Ayla", realm = "Lordaeron", class = "MAGE", seen = 1700000000, bags = { [POTION] = 12 }, bank = { [POTION] = 5, [CLOTH] = 40 } },
					["Lordaeron-Brom"] = { name = "Brom", realm = "Lordaeron", class = "WARRIOR", seen = 1700000000, bags = { [SWORD] = 1 }, bank = {} },
					["Lordaeron-Old"] = { name = "Old", realm = "Lordaeron", class = "ROGUE", seen = 1600000000, bags = { [POTION] = 99 }, bank = {} },
				},
				warband = { [CLOTH] = 3 },
			},
		},
	}
	local env, K = B.New({ bags = Bags(), saved = saved, player = "Valerin", realm = "Lordaeron" })
	local lines = B.ItemTooltip(env, POTION)
	local ayla = Find(lines, "Ayla")
	assert(ayla, "a character holding the item gets a line")
	assert(ayla[2] and ayla[2]:find("12", 1, true) and ayla[2]:find("5", 1, true), "with her bag and bank counts, got " .. tostring(ayla[2]))
	local r, g, b = K.Theme.ClassColor("MAGE")
	assert(math.abs(ayla[3] - r) < 0.01 and math.abs(ayla[4] - g) < 0.01 and math.abs(ayla[5] - b) < 0.01, "the name is in her class colour")
	assert(not Find(lines, "Brom"), "a character without the item gets no line")
	assert(not Find(lines, "Valerin"), "this character's own bags are not repeated in the tooltip")
	assert(not Find(lines, "Old"), "a character not seen for 60 days is forgotten")
	assert(K.Store.Account().inventory.characters["Lordaeron-Old"] == nil, "and pruned from the saved data")
	lines = B.ItemTooltip(env, CLOTH)
	assert(Find(lines, "Ayla") and Find(lines, "Ayla")[2]:find("40", 1, true), "bank-only counts show too")
	local warband = Find(lines, "Warband")
	assert(warband and warband[2]:find("3", 1, true), "the Warband bank gets its own line")
	assert(#B.ItemTooltip(env, 9999) == 0, "an item nobody holds adds nothing")
	assert(#B.ItemTooltip(env, env.Secret(POTION)) == 0, "a secret item ID adds nothing and does not error")
	assert(K.Options.Write("Bags", "altCounts", false) ~= false, "the counts have a switch")
	assert(#B.ItemTooltip(env, POTION) == 0, "the switch turns the lines off")
	K.Options.Write("Bags", "altCounts", true)
	env.SetBank(true)
	Run(env)
	env.SetBank(false)
	lines = B.ItemTooltip(env, CLOTH)
	assert(not Find(lines, "Valerin"), "this character shows no line when its bank holds none")
	B.Put(env, 0, 4, Item("cloth", { count = 2 }))
	local bank = K.Store.Account().inventory.characters["Lordaeron-Valerin"].bank
	bank[CLOTH] = 6
	lines = B.ItemTooltip(env, CLOTH)
	local me = Find(lines, "Valerin")
	assert(me and me[2]:find("6", 1, true) and not me[2]:find("22", 1, true), "this character's line shows only its bank count, got " .. tostring(me and me[2]))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Without the tooltip processor the counts still scan, and the module says why there are no lines -----

do
	local env, K = B.New({
		bags = Bags(),
		setup = function(env)
			env.TooltipDataProcessor = nil
		end,
	})
	assert(K.Store.Account().inventory.characters["Realm-Tester"].bags[POTION] == 8, "the scan does not need the tooltip processor")
	local logged = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		logged = logged or (entry.module == "Bags" and entry.message:find("TooltipDataProcessor", 1, true) ~= nil)
	end
	assert(logged, "the devlog says the tooltip lines are unavailable")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Browsing: the scan keeps what each item is, and the bag window's picker shows a saved character read-only -----

do
	local env, K, ns = B.New({ bags = Bags(), bank = Bank(), bankTabs = { [BANK.Character] = { 6 }, [BANK.Account] = { 15 } }, player = "Valerin", realm = "Lordaeron" })
	local Alts = ns.Alts
	local saved = K.Store.Account().inventory
	local me = saved.characters["Lordaeron-Valerin"]
	assert(saved.version == Alts.VERSION and Alts.VERSION >= 2, "the store carries the version that added the item catalogue")
	local potion = me.items and me.items[POTION]
	assert(type(potion) == "table" and potion.icon == 134829 and potion.quality == 1 and potion.cat == "consumables" and potion.name == "Minor Healing Potion", "the scan keeps each item's icon, quality, category and name")
	assert(me.free == 24 - 4 and me.total == 24, "and the bags' free and total slots, got " .. tostring(me.free) .. "/" .. tostring(me.total))
	assert(type(me.money) == "number", "and the character's money")
	B.Put(env, 0, 2, nil)
	Run(env)
	assert(me.items[SWORD] == nil, "an item that leaves the bags leaves the catalogue")
	env.SetBank(true)
	Run(env)
	assert(me.items[1001] and me.items[1001].cat == "equipment", "the bank's items join the catalogue")
	assert(me.bankFree == 24 - 2 and me.bankTotal == 24, "with the bank's free and total slots")
	env.SetBank(false)
	Run(env)

	-- A character an earlier session saved.
	saved.characters["Lordaeron-Thargor"] = {
		name = "Thargor", realm = "Lordaeron", class = "WARRIOR", seen = me.seen,
		bags = { [POTION] = 4, [SWORD] = 1 }, bank = { [CLOTH] = 40 },
		items = {
			[POTION] = { icon = 134829, quality = 1, cat = "consumables", name = "Minor Healing Potion" },
			[SWORD] = { icon = 135274, quality = 2, cat = "equipment", name = "Worn Shortsword" },
			[CLOTH] = { icon = 132905, quality = 1, cat = "tradeGoods", name = "Silk Cloth" },
		},
		free = 10, total = 24, bankFree = 20, bankTotal = 24, money = 12345,
	}
	local list = Alts.Characters()
	assert(#list == 2 and list[1].own and list[1].key == "Lordaeron-Valerin" and list[2].name == "Thargor" and list[2].class == "WARRIOR", "the characters list this one first, then the others by name")
	local view = Alts.View("Lordaeron-Thargor")
	assert(view and #view.bags == 2 and #view.bank == 1, "a view lists the bags' items and the bank's")
	assert(view.bags[1].id == SWORD and view.bags[2].id == POTION, "in the categories' order: equipment before consumables")
	assert(view.bags[2].count == 4 and view.bank[1].count == 40, "with their counts")
	assert(Alts.View("Nobody") == nil, "an unknown key has no view")

	env.ToggleAllBags()
	Run(env)
	local win = ns.Inventory.window
	assert(win.picker and win.picker:IsShown(), "the bag window offers a character picker once another character is saved")
	assert(win.picker:GetValue() == "Lordaeron-Valerin", "set to this character")
	assert(win.picker:SetValue("Lordaeron-Thargor"), "Thargor is one of its options")
	Run(env)
	local remote = win.remote
	assert(remote and remote.frame:IsShown(), "picking Thargor shows the saved view")
	assert(not win.viewport:IsShown(), "and puts the live sections away")
	assert(#remote.tiles == 3, "one tile per saved item, got " .. tostring(#remote.tiles))
	local tile = remote.tiles[2]
	assert(tile.count:GetText() == "4" and tile.icon:GetTexture() == 134829, "a tile wears the item's icon and count")
	assert(tile.button._template == nil, "the tiles are plain buttons, never Blizzard's item buttons: nothing can be picked up")
	local caps = {}
	for _, group in ipairs(remote.groups) do
		if group.frame:IsShown() then
			caps[#caps + 1] = group.cap.label:GetText()
		end
	end
	assert(#caps == 3 and caps[1]:find("EQUIPMENT", 1, true) and caps[2]:find("CONSUMABLES", 1, true) and caps[3]:find("BANK", 1, true), "the view keeps the Lumen caps: the bags' categories, then the bank, got " .. table.concat(caps, ","))
	assert(win.free:GetText():find("10/24", 1, true), "the footer shows the saved character's free slots, got " .. tostring(win.free:GetText()))
	assert(win.money:GetText() == ns.Window.MoneyText(12345), "and their money")
	W.Enter(tile.button)
	assert(B.Count(env, "GameTooltip:SetItemByID") == 1 and B.Calls(env, "GameTooltip:SetItemByID")[1][1] == POTION, "a tile shows the item's tooltip by ID")
	W.Leave(tile.button)
	assert(win.panel:GetWidth() >= win.search:GetWidth(), "the window still hugs its controls")
	-- The live bags' actions rest while another character shows: Sort and Sell junk would act on this character's
	-- hidden bags, and this character's money events must not overwrite the saved balance.
	B.Put(env, 1, 2, Item("junk"))
	env.SetMerchant(true)
	Run(env)
	assert(not win.junkButton:IsShown(), "Sell junk stays hidden at a merchant while browsing")
	assert(win.sortButton:IsEnabled() == false, "and Sort is disabled")
	W.Click(win.sortButton)
	Run(env)
	assert(B.Count(env, "SortBags") == 0, "so nothing sorts this character's bags")
	env.FireEvent("PLAYER_MONEY")
	assert(win.money:GetText() == ns.Window.MoneyText(12345), "a money event keeps the saved character's balance on show")
	env.SetMerchant(false)
	Run(env)
	win.picker:SetValue("Lordaeron-Valerin")
	Run(env)
	assert(not remote.frame:IsShown() and win.viewport:IsShown(), "picking this character brings the live bags back")
	assert(win.sortButton:IsEnabled() ~= false, "and Sort works again")
	assert(#env._errors == 0, tostring(env._errors[1]))

	-- A character with hundreds of saved items never pushes the window off the screen: the view clips to the
	-- height budget and scrolls, as the live sections do, and a saved category the player has since removed
	-- counts toward the width as the Other row it is drawn in.
	local many = saved.characters["Lordaeron-Thargor"]
	for id = 20000, 20299 do
		many.bank[id] = 1
		many.items[id] = { icon = 134414, quality = 1, cat = "consumables", name = "Bandage " .. id }
	end
	for id = 30000, 30006 do
		many.bags[id] = 1
		many.items[id] = { icon = 134414, quality = 1, cat = "custom-gone", name = "Relic " .. id }
	end
	for id = 31000, 31006 do
		many.bags[id] = 1
		many.items[id] = { icon = 134414, quality = 1, cat = "custom-gone-too", name = "Relic " .. id }
	end
	win.picker:SetValue("Lordaeron-Thargor")
	Run(env)
	local screen = win:ScreenHeight()
	assert(win.panel:GetHeight() <= screen, "the window stays on a " .. screen .. " screen, got " .. win.panel:GetHeight())
	assert(remote.stackHeight > remote.viewHeight, "the saved view is taller than its clip and scrolls")
	local before = remote.scroll
	remote.frame:GetScript("OnMouseWheel")(remote.frame, -1)
	assert(remote.scroll > before, "the wheel scrolls the saved view")
	local other
	for _, group in ipairs(remote.groups) do
		if group.frame:IsShown() and group.cap.label:GetText():find("OTHER", 1, true) then
			other = group
		end
	end
	assert(other and #other.entries == 14, "the removed categories' items share one Other row, got " .. tostring(other and #other.entries))
	local Data = ns.Data
	local size, spacing = ns.Settings.Get("slotSize"), ns.Settings.Get("spacing")
	local pad = K.Widgets.WindowInset(win.panel)
	local columns = ns.Settings.Get("columns")
	assert(win.panel:GetWidth() == Data.Size(math.min(14, columns), 1, size, spacing) + 2 * pad, "and the window is as wide as that row, got " .. win.panel:GetWidth())
	assert(#env._errors == 0, tostring(env._errors[1]))

	local env2, _, ns2 = B.New({ bags = Bags(), player = "Valerin", realm = "Lordaeron" })
	env2.ToggleAllBags()
	Run(env2)
	assert(ns2.Inventory.window.picker == nil or not ns2.Inventory.window.picker:IsShown(), "with no other character saved, the window offers no picker")
end

print("bags alts ok")
