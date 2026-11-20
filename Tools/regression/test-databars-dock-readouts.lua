-- test-databars-dock-readouts.lua: dock defaults and whole-item overflow keep every readout inside the slab wings.
local D = dofile("Tools/regression/databars_env.lua")
local Fixture = dofile("Tools/regression/databars_readouts_fixture.lua")
local Scene = dofile("Tools/render/scene.lua")
local Load = dofile("Tools/regression/load_files.lua")

for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", setup = function(e) D.Menus(e); Fixture(e) end })
	Load({ "KstyleUI_ActionBars/TravelData.lua" }, env)
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	local s, view = ns.Settings().strip, ns.Strip.view
	assert(table.concat(view.order, ",") == "fps,latency,gold,durability,time", "the Medallions dock defaults to the original five readouts")
	local function captionSeparator()
		Scene.Build(env)
		for _, entry in ipairs(s.dockModules) do
			local item = view.items[entry.id]
			if entry.zone == "right" and item and item.button:IsShown() then
				assert(item.dot:IsShown() == view.slab.text:IsVisible(), "join the dock readouts to the visible XP caption with one middle dot")
				if item.dot:IsShown() then
					local _, size = item.dot:GetFont()
					local step = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(view.frame)
					local gap = K.Widgets.DotGap(size, step, ns.Strip.DOT_GAP_EM)
					local dx, _, dw = Scene.Rect(env, item.dot)
					local cx = Scene.Rect(env, view.slab.text)
					local _, _, width = Scene.Rect(env, view.frame)
					local scale = width / view.frame:GetWidth()
					local expected = cx - (K.Widgets.TextWidth(item.dot) / 2 + gap) * scale
					assert(math.abs(dx + dw / 2 - expected) <= step * scale, "the XP separator must use the same DotGap as the other readouts")
				end
				return
			end
		end
	end
	captionSeparator()
	for _, entry in ipairs(s.dockModules) do entry.shown = true end
	K.Options.Write("DataBars", "strip.dockModules", s.dockModules)
	local function check()
		captionSeparator()
		Scene.Build(env)
		local x, _, width = Scene.Rect(env, view.frame)
		local scale = width / view.frame:GetWidth()
		local layouts = K.Setup.Layouts
		local left = layouts.ActionBarFootprint("medallions", K.Scale.Aspect(), "actionbars.bar1")
		local right = layouts.ActionBarFootprint("medallions", K.Scale.Aspect(), "actionbars.bar2")
		local unit = width / (left + right + layouts.MEDALLIONS_HUB_GAP)
		local bounds = { left = { x, x + left * unit }, right = { x + (left + layouts.MEDALLIONS_HUB_GAP) * unit, x + width } }
		local captionX = Scene.Rect(env, view.slab.text)
		if view.slab.text:IsVisible() then bounds.right[2] = captionX - 6 * scale end
		local zones, dropped, last = {}, {}, {}
		for _, entry in ipairs(s.dockModules) do zones[entry.id] = entry.zone == "right" and "right" or "left" end
		local hiddenCount = 0
		for _, id in ipairs(view.order) do
			local item, zone = view.items[id], zones[id]
			if item.button:IsShown() then
				assert(not dropped[zone], "drop only a suffix of each wing in module-list order")
				last[zone] = item
				for _, text in ipairs({ item.value, item.label, item.dot }) do
					if text:IsShown() then
						local tx, _, tw = Scene.Rect(env, text)
						assert(tx >= bounds[zone][1] - 0.01 and tx + tw <= bounds[zone][2] + 0.01, "dock " .. id .. " text crossed the " .. zone .. " wing: " .. tx .. "+" .. tw .. " outside " .. bounds[zone][1] .. ".." .. bounds[zone][2] .. "; drop whole items instead of drawing behind the crest or past the wing")
						assert(not text:IsTruncated(), "never truncate a dock readout mid-item")
					end
				end
			else
				dropped[zone] = dropped[zone] or {}
				dropped[zone][#dropped[zone] + 1] = id
				hiddenCount = hiddenCount + 1
			end
		end
		assert(hiddenCount > 0, "the all-modules fixture must exercise dock overflow")
		for zone, ids in pairs(dropped) do
			if last[zone] then
				assert(table.concat(last[zone].hiddenReadouts, ",") == table.concat(ids, ","), "the last visible item lists the entire hidden suffix")
				ns.Strip.ShowTooltip(last[zone])
				local titles = {}
				for _, row in ipairs(K.Widgets.Tooltip().used) do local title = row.left:GetText(); if title then titles[title] = true end end
				for _, id in ipairs(ids) do assert(titles[ns.Strip.TITLES[id]], "the last visible tooltip must include hidden " .. id) end
			end
		end
	end
	check()
	ns.Strip.Refresh()
	check()
	K.Options.Write("DataBars", "xp.text", "none")
	check()
	K.Options.Write("DataBars", "xp.text", "percent")
	check()
	K.Options.Write("DataBars", "xp.fontSize", 20)
	K.Options.Write("DataBars", "xp.instrumentText", false)
	check()
	K.Options.Write("DataBars", "xp.instrumentText", true)
	K.Options.Write("DataBars", "xp.fontSize", 12)
	for _, entry in ipairs(s.dockModules) do entry.zone = "left" end
	K.Options.Write("DataBars", "strip.dockModules", s.dockModules)
	check()
	K.Options.Write("HudStyle", "style", "frames")
	for _, entry in ipairs(s.modules) do assert(entry.shown == (entry.id ~= "xp"), "the top bar retains its independent all-on defaults") end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("databar dock readouts ok: defaults, whole-item suffix overflow, tooltip and wing bounds on four screens")
