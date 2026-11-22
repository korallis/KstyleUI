-- test-databars-rail.lua: Setup leaves automatic bar positions unsaved and Right rail restores the v0.2.6 readout.
local D = dofile("Tools/regression/databars_env.lua")
local Scene = dofile("Tools/render/scene.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", setup = D.Menus })
	local choice = K.Setup.NewChoice()
	assert(K.Setup.Apply(choice))
	env.RunTimers()
	local function rail()
		env.RunTimers()
		local view = ns.Strip.view
		assert(table.concat(view.order, ",") == "fps,latency,gold",
			"Right rail must default to v0.2.6 strip.slot1..5: fps, latency, gold, none, none")
		assert(ns.Settings().strip.menus == false,
			"Setup must keep strip.menus off while Right rail is selected")
		local p = K.Layout.Get("databars.strip")
		assert(p.anchor == "BOTTOMRIGHT" and p.x == -17 and p.y == 181,
			"Right rail must use the v0.2.6 default after Setup; do not save the automatic dock as a player position")
		local x, y, w, h = Scene.Rect(env, ns.Strip.view.frame)
		local rw, rh = K.Layout.RootSize()
		local pixel = K.Scale.Pixel(1)
		local left, bottom = K.Layout.Rect("databars.strip")
		assert(math.abs(left - (rw - 17 - p.width)) <= pixel and math.abs(bottom - 181) <= pixel,
			"Right rail must restore the v0.2.6 readout rectangle")
		assert(math.abs(p.width - 278) <= pixel and math.abs(p.height - 12) <= pixel,
			"Right rail must restore the v0.2.6 readout size after Setup: " .. p.width .. "x" .. p.height)
		assert(x and y and w > 0 and h > 0 and rh > 0)
	end
	K.Options.Write("DataBars", "strip.placement", "rail")
	rail()
	assert(K.Setup.Apply(choice))
	rail()
	env.FireEvent("PLAYER_LOGOUT")
	local saved = D.CoreEnv.DeepCopy(env.KstyleUIDB)
	env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", saved = saved, setup = D.Menus })
	rail()
	K.Options.Write("DataBars", "strip.placement", "dock")
	assert(K.Layout.Update("databars.strip", { anchor = "BOTTOM", x = 37, y = 300 }))
	K.Options.Write("DataBars", "strip.placement", "rail")
	local moved = K.Layout.Get("databars.strip")
	assert(moved.anchor == "BOTTOM" and moved.x == 37 and moved.y == 300,
		"Right rail must never clear a position the player moved by hand")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto" })
	K.Options.Write("DataBars", "strip.placement", "rail")
	local modules = D.CoreEnv.DeepCopy(ns.Settings().strip.railModules)
	for i, entry in ipairs(modules) do
		entry.shown, entry.zone = i <= 5, i % 2 == 0 and "left" or "centre"
	end
	K.Options.Write("DataBars", "strip.railModules", modules)
	local view = ns.Strip.view
	local function check(expectHidden)
		Scene.Build(env)
		local x, _, width = Scene.Rect(env, view.frame)
		local hidden, last = {}, nil
		for _, id in ipairs(view.order) do
			local item = view.items[id]
			if item.button:IsShown() then
				assert(#hidden == 0, "Right rail must keep a prefix of the module order and hide whole items from its end")
				last = item
				for _, text in ipairs({ item.value, item.label, item.dot }) do
					if text:IsShown() then
						local tx, _, tw = Scene.Rect(env, text)
						assert(tx >= x - 0.01 and tx + tw <= x + width + 0.01,
							"Right rail " .. id .. " text must stay inside its frame; hide whole overflowing readouts: " .. tx .. "+" .. tw .. " outside " .. x .. ".." .. (x + width))
						assert(not text:IsTruncated(), "Right rail must never truncate a readout mid-item")
					end
				end
			else
				hidden[#hidden + 1] = id
				assert(not item.dot:IsShown(), "hidden readouts must not leave separators behind")
			end
		end
		assert((#hidden > 0) == expectHidden, "exercise both overflowing and fitting rail readouts")
		if last and #hidden > 0 then
			assert(table.concat(last.hiddenReadouts, ",") == table.concat(hidden, ","))
			ns.Strip.ShowTooltip(last)
			local titles = {}
			for _, row in ipairs(K.Widgets.Tooltip().used) do titles[row.left:GetText() or ""] = true end
			for _, id in ipairs(hidden) do assert(titles[ns.Strip.TITLES[id]], "the tooltip must list hidden " .. id) end
		end
	end
	check(true)
	ns.Strip.Refresh()
	check(true)
	K.Options.Write("DataBars", "strip.fontSize", 20)
	check(true)
	assert(K.Layout.Update("databars.strip", { width = 1200 }))
	check(false)
	K.Options.Write("DataBars", "strip.placement", "dock")
	assert(table.concat(view.order, ",") == "fps,latency,gold,durability,time", "the dock's defaults must stay independent of rail choices")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("databars rail ok: v0.2.6 placement after Setup, rerun and reload on the owner screens; moved positions kept")
