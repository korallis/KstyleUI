-- test-bags-figure-lanes.lua: stack counts and optional item levels keep separate corners and the title band covers its title.
local B = dofile("Tools/regression/bags_env.lua")
local Item = B.Item

for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 }, { 3456, 2234 } }) do
	local env, K, ns = B.New({ width = screen[1], height = screen[2], bags = {
		[0] = { size = 4, items = { [1] = Item("helm", { count = 12 }) } },
	} })
	env.ToggleAllBags()
	env.RunTimers()
	B.W.Settle(env)
	local slot = ns.Inventory.Slot(0, 1)
	local inset = K.Widgets.Snap(slot.button, 2)
	local point, relative, on, x, y = slot.level:GetPoint(1)
	assert(point == "TOPLEFT" and relative == slot.button and on == "TOPLEFT" and x == inset and y == -inset,
		"move bag item level to TOPLEFT with a 2-unit inset; reserve BOTTOMRIGHT for the stack count")
	point, relative, on, x, y = slot.count:GetPoint(1)
	assert(point == "BOTTOMRIGHT" and relative == slot.button and on == "BOTTOMRIGHT" and x == -inset and y == inset,
		"stack counts belong at BOTTOMRIGHT with a 2-unit inset")
	local panel = ns.Inventory.window.panel
	assert(panel.chrome.headerUnits == panel.titleBar:GetHeight(), "size the bag header band from the title bar height")
	assert(select(2, panel.titleText:GetFont()) == K.Widgets.FontSize(panel.titleText, 14), "the bag window title uses 14 units")
	K.Options.Write("Bags", "separateFigures", false)
	assert(slot.level:GetPoint(1) == "BOTTOMLEFT", "turning separate figures off restores the previous item-level corner")
	K.Options.Write("Bags", "readableHeaders", false)
	assert(panel.chrome.headerUnits == ns.Inventory.window.originalHeader, "turning readable headings off restores the previous header band")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("bags figure lanes ok")
