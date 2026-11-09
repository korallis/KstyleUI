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

print("bags alts ok")
