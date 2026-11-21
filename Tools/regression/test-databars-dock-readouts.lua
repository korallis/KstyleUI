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
				local on = view.slab.text:IsVisible()
				assert(not item.dot:IsShown() and view.xpRule:IsShown() == on and view.xpGlyph:IsShown() == on, "a gilt rule and the XP glyph join the dock readouts to the visible XP caption")
				if on then
					local step = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(view.frame)
					local gx, _, gw = Scene.Rect(env, view.xpGlyph)
					local rx = Scene.Rect(env, view.xpRule)
					local cx = Scene.Rect(env, view.slab.text)
					local bx, _, bw = Scene.Rect(env, view.zones.right)
					local _, _, width = Scene.Rect(env, view.frame)
					local scale = width / view.frame:GetWidth()
					assert(gx + gw < cx and rx < gx and math.abs(rx - (bx + bw)) <= 2 * step * scale, "the XP segment sits between the right zone's closing rule and the caption")
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
						local edge = zone == "right" and text == item.dot and view.slab.text:IsVisible() and captionX or bounds[zone][2]
						assert(tx >= bounds[zone][1] - 0.01 and tx + tw <= edge + 0.01, "dock " .. id .. " text crossed the " .. zone .. " wing: " .. tx .. "+" .. tw .. " outside " .. bounds[zone][1] .. ".." .. edge .. "; drop whole items instead of drawing behind the crest or past the wing")
						assert(not text:IsTruncated(), "never truncate a dock readout mid-item")
					end
				end
			else
				assert(not item.separator:IsShown(), id .. " overflows: hide its rule with its button")
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
	assert(not view.xpRule:IsShown() and view.xpGlyph:IsShown() == view.slab.text:IsVisible(), "a caption with no readout before it keeps its glyph but no rule")
	K.Options.Write("HudStyle", "style", "frames")
	for i, entry in ipairs(s.modules) do assert(entry.shown == (i <= 12), "the top bar retains its independent defaults; XP and the optional readouts after it stay off") end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
do
	local env, K, ns = D.New({ width = 1920, height = 1080, size = "auto", setup = D.Menus })
	local view = ns.Strip.view
	local function set(group, key, value) K.Options.Write(group, key, value) env.RunTimers() D.W.Settle(env) end
	local function layers() return tostring(view.frame:GetFrameStrata()) .. view.frame:GetFrameLevel() .. view.card:GetFrameLevel() end
	local top = layers()
	set("HudStyle", "style", "orbs")
	set("DataBars", "strip.placement", "dock")
	assert(view.slab and not view.chrome.visible and not (view.wing and view.wing.visible) and not (view.xpGlyph and view.xpGlyph:IsShown()) and layers() == top, "only the Medallions dock wears plates, glyph segments and the XP strip's layer")
	set("DataBars", "strip.placement", "top")
	set("HudStyle", "style", "medallions")
	local docked, holder = layers(), view.slab.holder
	holder.GetFrameLevel = function() return env.Secret(2) end
	ns.Strip.Refresh()
	holder.GetFrameLevel = nil
	assert(layers() == docked, "a restricted XP strip level keeps the dock's last safe layering")
	local list, wanted = {}, { fps = 1, spacer = 2, latency = 3, coords = 4 }
	for id, i in pairs(wanted) do list[i] = { id = id, shown = true, zone = "left" } end
	for _, entry in ipairs(ns.Settings().strip.dockModules) do
		if not wanted[entry.id] then list[#list + 1] = { id = entry.id, shown = false, zone = entry.zone } end
	end
	set("DataBars", "strip.dockModules", list)
	local items = view.items
	assert(items.fps.icon:IsShown() and items.coords.icon:IsShown() and not items.spacer.icon:IsShown(), "every readout shows its own glyph; the spacer shows none")
	assert(not items.spacer.separator:IsShown() and not items.latency.separator:IsShown() and items.coords.separator:IsShown(), "no gilt rule beside a spacer")
	local width = items.latency.button:GetWidth()
	set("DataBars", "strip.padding", 6)
	assert(math.abs(items.latency.button:GetWidth() - width - 12) < 0.5, "Readout padding widens each dock segment on both sides")
	set("DataBars", "strip.padding", 0)
	set("DataBars", "strip.hover", false)
	items.fps.button.hoverT = 1
	items.fps.button.Paint()
	assert(items.fps.hover:GetAlpha() == 0, "Hover highlight off keeps the dock segment unlit")
	set("DataBars", "strip.hover", true)
	local pane = env.CreateFrame("Frame", nil, env.UIParent)
	pane:SetSize(360, 250)
	local preview = ns.Preview(pane)
	for _, artwork in ipairs({ "plain", "forged" }) do
		set("DataBars", "strip.artwork", artwork)
		preview:Refresh()
		local sample = preview.strip
		assert(sample.chrome.visible and sample.chrome.materialOn == (artwork == "forged") and sample.items.fps.icon:IsVisible() and not sample.items.latency.dot:IsShown(), "the settings preview shows the dock's " .. artwork .. " plate and glyph segments")
	end
	set("DataBars", "strip.line", false)
	set("DataBars", "strip.placement", "rail")
	local fps = view.items.fps
	assert(not fps.icon:IsShown() and not fps.hover:IsShown() and not view.xpGlyph:IsShown() and not view.xpRule:IsShown(), "rail cells drop the dock's glyphs, highlight and rules")
	set("DataBars", "strip.line", true)
	set("DataBars", "strip.placement", "top")
	set("HudStyle", "style", "frames")
	assert(layers() == top, "leaving the dock restores the strip's strata and frame levels")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("databar dock readouts ok: defaults, whole-item suffix overflow, tooltip and wing bounds on four screens")
