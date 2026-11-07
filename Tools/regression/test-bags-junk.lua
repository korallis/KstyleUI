-- test-bags-junk.lua: KstyleUI_Bags sells junk at a merchant, by button or automatically, only out of combat through Combat.Queue.
local B = dofile("Tools/regression/bags_env.lua")
local W = B.W
local Item = B.Item

local function Bags(junk)
	local items = {}
	for i = 1, junk or 3 do
		items[i] = Item("junk")
	end
	items[(junk or 3) + 1] = Item("hearth")
	items[(junk or 3) + 2] = Item("greyNoValue")
	items[(junk or 3) + 3] = Item("potion")
	return { [0] = { size = 20, items = items }, [1] = { size = 4, items = { [1] = Item("junk") } } }
end

local function New(opts)
	opts = opts or {}
	opts.bags = opts.bags or Bags(opts.junk)
	return B.New(opts)
end

local function Run(env)
	env.RunTimers()
	W.Settle(env)
end

local function Set(K, key, value)
	assert(K.Options.Write("Bags", key, value) ~= false, "writing " .. key)
end

local function Open(env)
	env.ToggleAllBags()
	Run(env)
end

local function Sold(env)
	local out = {}
	for _, call in ipairs(B.Calls(env, "UseContainerItem")) do
		out[#out + 1] = call[1] .. ":" .. call[2]
	end
	return out
end

-- Settings ----------------------------------------------------------------------------------------

do
	local _, K = New({ enable = false })
	local found
	for _, row in ipairs(K.Options.Get("Bags")) do
		if row.key == "autoSellJunk" then
			found = row
		end
	end
	assert(found and found.type == "toggle", "the settings page has a toggle for autoSellJunk")
	assert(K.Store.Defaults("Bags").autoSellJunk == false, "selling junk by itself is off by default")
end

-- The Sell junk button ------------------------------------------------------------------------------

do
	local env, _, ns = New({ merchant = true })
	Open(env)
	local button = ns.Inventory.window.junkButton
	assert(button and not button:IsShown(), "Sell junk hides away from a merchant")
	env.SetMerchant(true)
	Run(env)
	assert(button:IsShown(), "and shows at a merchant while there is junk")
	W.Click(button)
	Run(env)
	assert(B.Count(env, "SellAllJunkItems") == 1, "it asks the game to sell all junk")
	assert(#Sold(env) == 0, "and sells nothing item by item")
	env._junkCount = 0
	B.Put(env, 0, 1, nil)
	Run(env)
	assert(not button:IsShown(), "it hides when no junk is left")
	env.SetMerchant(false)
	Run(env)
	assert(not button:IsShown(), "and away from the merchant")
end

-- The fallback when the game cannot sell all junk ---------------------------------------------------

do
	local env, _, ns = New({ merchant = false, junk = 12 })
	Open(env)
	env.SetMerchant(true)
	Run(env)
	local button = ns.Inventory.window.junkButton
	assert(button:IsShown(), "the button counts junk itself without C_MerchantFrame")
	W.Click(button)
	local sold = Sold(env)
	assert(#sold == 10, "the first batch sells ten items, got " .. #sold)
	Run(env)
	sold = Sold(env)
	assert(#sold == 13, "the rest follow: twelve in the backpack and one in bag 1, got " .. #sold)
	for _, key in ipairs(sold) do
		assert(key ~= "0:13" and key ~= "0:14" and key ~= "0:15", "only poor items with a sell value are sold: " .. key)
	end
end

do
	local env, _, ns = New({ merchant = false, setup = function(e)
		e.C_Container.GetBackpackSellJunkDisabled = function()
			return true
		end
		e.Enum.BagSlotFlags = { ExcludeJunkSell = 64 }
		e.C_Container.GetBagSlotFlag = function()
			return false
		end
	end })
	env.SetMerchant(true)
	Run(env)
	ns.Junk.Sell()
	Run(env)
	local sold = Sold(env)
	assert(#sold == 1 and sold[1] == "1:1", "a bag excluded from junk selling keeps its junk")
end

do
	local env, _, ns = New({ merchant = false, junk = 12 })
	env.SetMerchant(true)
	Run(env)
	ns.Junk.Sell()
	assert(#Sold(env) == 10, "the first batch sells")
	env.SetMerchant(false)
	Run(env)
	assert(#Sold(env) == 10, "selling stops when the merchant closes")
end

-- Combat ------------------------------------------------------------------------------------------

do
	local env, _, ns = New({ merchant = false })
	env.SetMerchant(true)
	Run(env)
	env.SetCombat(true)
	ns.Junk.Sell()
	Run(env)
	assert(#Sold(env) == 0, "nothing sells in combat")
	assert(B.W.CoreEnv.Printed(env, "combat"), "and chat says it waits")
	env.SetCombat(false)
	Run(env)
	assert(#Sold(env) == 4, "the sale runs when combat ends")

	local env2, _, ns2 = New({ merchant = true })
	env2.SetMerchant(true)
	Run(env2)
	env2.SetCombat(true)
	ns2.Junk.Sell()
	env2.SetMerchant(false)
	env2.SetCombat(false)
	Run(env2)
	assert(B.Count(env2, "SellAllJunkItems") == 0, "a merchant that closed during combat gets nothing")
end

-- A sale belongs to one merchant visit --------------------------------------------------------------

do
	local env, _, ns = New({ merchant = true })
	env.SetMerchant(true)
	Run(env)
	env.SetCombat(true)
	ns.Junk.Sell()
	env.SetMerchant(false)
	env.SetMerchant(true)
	env.SetCombat(false)
	Run(env)
	assert(B.Count(env, "SellAllJunkItems") == 0, "a sale queued in combat does not run in a later merchant visit")

	local env2, _, ns2 = New({ merchant = false, junk = 12 })
	env2.SetMerchant(true)
	Run(env2)
	ns2.Junk.Sell()
	assert(#Sold(env2) == 10, "the first batch sells")
	env2.SetMerchant(false)
	env2.SetMerchant(true)
	Run(env2)
	assert(#Sold(env2) == 10, "the rest of a sale does not resume in a later visit")
end

-- Selling by itself -------------------------------------------------------------------------------

do
	local env, K = New({ merchant = true })
	env.SetMerchant(true)
	Run(env)
	assert(B.Count(env, "SellAllJunkItems") == 0, "nothing sells by itself while the setting is off")
	env.SetMerchant(false)
	Set(K, "autoSellJunk", true)
	env.SetMerchant(true)
	Run(env)
	assert(B.Count(env, "SellAllJunkItems") == 1, "with it on, junk sells when the merchant opens")
end

print("bags junk ok")
