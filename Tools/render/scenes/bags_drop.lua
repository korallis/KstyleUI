-- bags_drop.lua: bags and bank with packed EMPTY tiles highlighted for a split stack on the cursor.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

return Common.Run(function()
	local B = dofile("Tools/regression/bags_env.lua")
	local env, K, ns = B.New(Common.ScreenOpts({
		saved = Gallery.Saved({}),
		bags = {
			[0] = { size = 20, items = { B.Item("potion"), B.Item("sword"), B.Item("cloth") } },
			[1] = { size = 20, items = {} },
			[2] = { size = 12, family = 32, items = {} },
		},
		bank = { [6] = { size = 28, items = { B.Item("helm"), B.Item("cloth") } } },
		setup = function(env)
			Gallery.Setup(env)
			env.GetMoneyString = nil
		end,
	}))
	env.SetBank(true)
	env.RunTimers()
	B.W.Settle(env)
	local held = B.Item("potion", { count = 2 })
	env.HoldItem(held)
	local root = K.Scale.Root()
	for i, win in ipairs({ ns.Bank.window, ns.Inventory.window }) do
		win.panel:ClearAllPoints()
		win.panel:SetPoint("TOPLEFT", root, "TOPLEFT", 80 + (i - 1) * 430, -80)
		assert(win.sections[1].groups.empty.order[1].state.drop, "the held stack highlights EMPTY")
	end
	local cursor = env.CreateFrame("Frame", nil, root)
	cursor:SetSize(32, 32)
	cursor:SetPoint("TOPLEFT", ns.Inventory.window.sections[1].groups.empty.order[1].button, "BOTTOMRIGHT", 8, -8)
	local icon = cursor:CreateTexture(nil, "OVERLAY")
	icon:SetAllPoints(cursor)
	icon:SetTexture(held.icon)
	local count = K.Widgets.Text(cursor, "body", "textEmphasis", "OVERLAY")
	count:SetPoint("BOTTOMRIGHT", cursor, "BOTTOMRIGHT", 0, 0)
	count:SetText(tostring(held.count))
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = "cursor: split potion stack held; both EMPTY drop targets highlighted"
	return scene
end)
