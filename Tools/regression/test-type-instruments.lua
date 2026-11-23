-- test-type-instruments.lua: the hub badge, meter row names and bag rims expose their original-look switches.
local AB = dofile("Tools/regression/actionbars_env.lua")
do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	env.RunTimers()
	local hub = ns.Slab.hub
	assert(hub.level:GetFont() == K.Tokens.Font("number"), "C2: hub level uses the number role")
	assert(hub.plaque:GetWidth() == K.Widgets.Snap(hub.plaque, 20), "C2: the hub badge grows to 20 units")
	K.Options.Write("ActionBars", "hubNumber", false)
	assert(hub.level:GetFont() == K.Tokens.Font("caption"), "C2 off: restore the caption-face badge")
	assert(hub.plaque:GetWidth() == K.Widgets.Snap(ns.Slab.frame, 18), "C2 off: restore the original root-snapped 18-unit badge")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
local M = dofile("Tools/regression/meters_env.lua")
do
	local env, K, ns = M.New()
	local list = ns.BarList.New(K.Scale.Root(), "damage", { width = 269, height = 158, block = true, columns = function() return { value = true, percent = true } end })
	list:SetRow(1, "Lightning Bolt", "SHAMAN", "friendly", 60, 100, "60", "60%")
	local row = list.rows[1]
	assert(row.name:GetFont() == (K.Tokens.Font("number")), "C3: meter row names share the Medallions number face (one typeface voice)")
	local before = { row.bar:GetStatusBarColor() }
	K.Options.Write("Meters", "instrumentNames", false)
	list:Restyle()
	assert(row.name:GetFont() == K.Tokens.Font("unit"), "C3 off: restore the original row-name face")
	local after = { row.bar:GetStatusBarColor() }
	for i = 1, 4 do assert(before[i] == after[i], "C3: preserve meter class colours") end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
local B = dofile("Tools/regression/bags_env.lua")
do
	local env, K, ns = B.New()
	local slot = ns.Slot.New(K.Scale.Root(), 1)
	ns.Slot.Update(slot, { empty = false, quality = 1, icon = 134829 }, nil, true)
	assert(B.W.SameRGB(slot.chrome.rim[1], K.Tokens.Color("slotRim")), "C4: low-quality bag rims use the quiet slot rim")
	ns.Slot.Update(slot, { empty = false, quality = 5, icon = 134829 }, 80, true)
	local r, g, b = slot.level:GetTextColor()
	local nr, ng, nb = K.Tokens.Color("legendary")
	assert(r == nr and g == ng and b == nb, "C4: item levels use the named quality palette")
	K.Options.Write("Bags", "qualityColors", false)
	ns.Slot.Paint(slot)
	ns.Slot.Update(slot, { empty = false, quality = 5, icon = 134829 }, 80, true)
	r, g, b = slot.level:GetTextColor()
	local lr, lg, lb = K.Theme.QualityColor(5, false)
	assert(r == lr and g == lg and b == lb, "C4 off: bag item-level colours restore the original palette too")
	ns.Slot.Update(slot, { empty = false, quality = 1, icon = 134829 }, nil, true)
	assert(B.W.SameRGB(slot.chrome.rim[1], K.Widgets.IconRim(ns.Settings.Accent())), "C4 off: restore the original accent rim")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("test-type-instruments: hub, meter names and bag rims with original-look switches")
