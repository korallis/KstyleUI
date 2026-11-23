-- test-bags-figure-lanes.lua: stack counts and optional item levels keep separate corners and the title band covers its title.
local B = dofile("Tools/regression/bags_env.lua")
local Item = B.Item

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 3456, 2234 } }) do
	local env, K, ns = B.New({ width = screen[1], height = screen[2], bags = {
		[0] = { size = 4, items = { [1] = Item("helm", { count = 12 }) } },
	} })
	env.ToggleAllBags()
	env.RunTimers()
	B.W.Settle(env)
	local slot = ns.Inventory.Slot(0, 1)
	local inset = K.Widgets.Snap(slot.button, 3)
	local point, relative, on, x, y = slot.level:GetPoint(1)
	assert(point == "TOPLEFT" and relative == slot.button and on == "TOPLEFT" and x == inset and y == -inset,
		"move bag item level to TOPLEFT with a 3-unit inset, clear of the quality rim; reserve BOTTOMRIGHT for the stack count")
	point, relative, on, x, y = slot.count:GetPoint(1)
	assert(point == "BOTTOMRIGHT" and relative == slot.button and on == "BOTTOMRIGHT" and x == -inset and y == inset,
		"stack counts belong at BOTTOMRIGHT with a 3-unit inset")
	local badge = K.Widgets.Snap(slot.button, 2)
	point, relative, on, x, y = slot.junk:GetPoint(1)
	assert(point == "TOPRIGHT" and relative == slot.button and x == -badge and y == -badge,
		"only the item figures take the 3-unit inset; the junk dot and other badges keep TEXT_INSET's 2 units")
	local panel = ns.Inventory.window.panel
	panel.chrome:MeasureHeader()
	assert(panel.chrome.headerUnits == panel.titleBar:GetHeight(), "the readable band covers the whole title bar, though the title's gem measures a shallower one, got " .. tostring(panel.chrome.headerUnits))
	assert(select(2, panel.titleText:GetFont()) == K.Widgets.FontSize(panel.titleText, 14), "the bag window title uses 14 units")
	K.Options.Write("Bags", "separateFigures", false)
	assert(slot.level:GetPoint(1) == "BOTTOMLEFT", "turning separate figures off restores the previous item-level corner")
	point, relative, on, x, y = slot.count:GetPoint(1)
	assert(x == -badge and y == badge, "turning separate figures off restores the previous 2-unit figure inset")
	K.Options.Write("Bags", "readableHeaders", false)
	assert(panel.chrome.headerUnits == ns.Inventory.window.originalHeader, "turning readable headings off restores the previous header band")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A bag cooldown shows the swipe alone by default; off leaves the engine's countdown, its font and colour alone.
for _, hide in ipairs({ true, false }) do
	local saved = { version = 42, profiles = { Default = { Bags = { enabled = true, cooldownSwipeOnly = hide } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = B.New({ saved = saved, bags = { [0] = { size = 1, items = { [1] = Item("helm", { count = 12 }) } } } })
	env.ToggleAllBags()
	env.RunTimers()
	local cooldown = ns.Inventory.Slot(0, 1).cooldown
	local last = B.W.LastCall(cooldown, "SetHideCountdownNumbers")
	if hide then
		assert(last and last[1] == true, "Swipe-only cooldowns (cooldownSwipeOnly, on by default) hides the countdown numbers")
		K.Options.Write("Bags", "cooldownSwipeOnly", false)
		last = B.W.LastCall(cooldown, "SetHideCountdownNumbers")
		assert(last and last[1] == false, "turning Swipe-only cooldowns off gives the numbers back to the engine")
	else
		assert(last == nil, "with Swipe-only cooldowns off the slot never touches the engine's countdown")
	end
	local text = cooldown:GetCountdownFontString()
	assert(text:GetFont() == nil and #B.W.Calls(text, "SetTextColor") == 0, "the engine's countdown keeps its own font and colour")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("bags figure lanes ok")
