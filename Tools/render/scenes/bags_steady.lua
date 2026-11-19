-- bags_steady.lua: bags, reagent slots and bank before or after looting, selling and splitting stacks.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

return Common.Run(function()
	local B = dofile("Tools/regression/bags_env.lua")
	local Item = B.Item
	local env, K, ns = B.New(Common.ScreenOpts({
		saved = Gallery.Saved({ Bags = { compactBags = os.getenv("RENDER_COMPACT") == "1" } }),
		bags = {
			[0] = { size = 20, items = { Item("potion"), Item("sword"), Item("junk"), [10] = Item("helm") } },
			[1] = { size = 8, items = { [8] = Item("ring") } },
			[5] = { size = 12, items = { Item("cloth") } },
		},
		bank = { [6] = { size = 28, items = { Item("helm"), Item("cloth"), Item("junk"), [14] = Item("ring") } } },
		setup = function(e)
			Gallery.Setup(e)
			e.GetMoneyString = nil
		end,
	}))
	env.SetBank(true)
	env.SetMerchant(true)
	env.RunTimers()
	if os.getenv("RENDER_BAG_CHANGED") == "1" then
		for _, bag in ipairs({ 0, 5, 6 }) do
			B.Put(env, bag, 4, Item("ring"))
			B.Put(env, bag, 3, nil)
			B.Put(env, bag, 1, Item("potion", { count = 3 }))
			B.Put(env, bag, 2, Item("potion", { count = 2 }))
		end
	end
	env.RunTimers()
	B.W.Settle(env)
	local frames = Gallery.Frames()
	for i, win in ipairs({ ns.Bank.window, ns.Inventory.window }) do
		win.panel:ClearAllPoints()
		win.panel:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 60 + (i - 1) * 620, -80)
		frames:Add(env, win.panel, {
			name = i == 1 and "steady_bank" or "steady_bags", title = i == 1 and "Bank" or "Bags", grade = "window", reference = "chat",
			caption = "The same physical slots before or after looting, selling and splitting stacks.",
			match = "The shared bag window and slot builders keep the suite's frame, header, fonts and sockets.",
		})
	end
	return frames:Finish(Gallery.Build(env), env, K, "steady bags")
end)
