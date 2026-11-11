-- test-ornament-tray-databars.lua: with a faction watched, the action bars and the data bars loaded together, the tray's finials and keystone keep 1 physical pixel from every data bar's drawn regions, stepping down a tier or dropping rather than covering the reputation bar, at Subtle and Full on five screens in DPS and on two in Tank and Healer.
local AB = dofile("Tools/regression/actionbars_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Scene = dofile("Tools/render/scene.lua")
local Common = dofile("Tools/render/scenes/_common.lua")

local function file(item)
	return item.file and tostring(item.file):match("Media/Textures/ForgedOrnaments/([^/]+)%.png$")
end

local function under(region, root)
	while region do
		if region == root then return true end
		region = type(region.GetParent) == "function" and region:GetParent() or nil
	end
	return false
end

local function gap(a, b)
	return math.max(b[1] - a[3], a[1] - b[3], b[2] - a[4], a[2] - b[4])
end

local CASES = {
	{ "DPS", "Full", 1280, 720 }, { "DPS", "Full", 1366, 768 }, { "DPS", "Full", 1920, 1080 }, { "DPS", "Full", 2560, 1440 },
	{ "DPS", "Full", 3456, 2234 }, { "DPS", "Subtle", 1920, 1080 }, { "Tank", "Full", 1280, 720 }, { "Tank", "Full", 1920, 1080 },
	{ "Healer", "Full", 1280, 720 }, { "Healer", "Full", 1920, 1080 },
}
local pieces, nearest, finials = 0, math.huge, {}
local oldScreen = rawget(_G, "RENDER_SCREEN")
for _, case in ipairs(CASES) do
	local layout, level, width, height = case[1], case[2], case[3], case[4]
	local label = string.format("%s %s %dx%d watching a faction", level, layout, width, height)
	rawset(_G, "RENDER_SCREEN", { width = width, height = height, uiScale = 768 / 1080 })
	local env, K, ns = AB.New({ width = width, height = height, setup = function(e)
		Common.ForceScreen(e)
		D.Game(e)
		D.Blizzard(e)
		D.Targets(e)
		e._textWidth = D.TextWidth
	end })
	Load(D.Files(), env)
	AB.Enable(env, K)
	K.Modules.Enable("DataBars")
	assert(K.Setup.Apply({ layout = layout, modules = { ActionBars = true, DataBars = true } }), label .. ": the preset applies")
	env.RunTimers()
	local widgets = K.Store.Module("Widgets")
	widgets.cardMaterial, widgets.ornaments = "ForgedBrackets", level
	K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
	env.RunTimers()
	local views = env._addons.KstyleUI_DataBars.Bars.views
	assert(views.rep and views.rep.holder:IsVisible(), label .. ": the reputation bar shows")
	local tray = ns.bars.bar1.ornament
	local scene = Scene.Build(env)
	local px = scene.screen.pixelsPerUnit
	local mine, bars = {}, {}
	for i = 1, tray.used do mine[tray.textures[i]] = true end
	for _, item in ipairs(scene.items) do
		if not file(item) then
			for id, view in pairs(views) do
				if under(item.object, view.holder) then
					local r = item.rect
					bars[#bars + 1] = { r[1] * px, r[2] * px, (r[1] + r[3]) * px, (r[2] + r[4]) * px, id, item }
				end
			end
		end
	end
	assert(#bars > 0, label .. ": the data bars draw")
	local names = {}
	for _, item in ipairs(scene.items) do
		if mine[item.object] then
			pieces = pieces + 1
			names[#names + 1] = file(item)
			local r = item.rect
			local box = { r[1] * px, r[2] * px, (r[1] + r[3]) * px, (r[2] + r[4]) * px }
			for _, bar in ipairs(bars) do
				if bar[4] > bar[2] and bar[3] > bar[1] then
					local g = gap(box, bar)
					nearest = math.min(nearest, g)
					assert(g >= 1 - 1e-3, string.format("%s: the tray's %s [%.1f %.1f %.1f %.1f] is %.2f px from the %s bar's %s [%.1f %.1f %.1f %.1f]",
						label, file(item), box[1], box[2], box[3], box[4], g, bar[5], tostring(bar[6].kind), bar[1], bar[2], bar[3], bar[4]))
				end
			end
		end
	end
	finials[#finials + 1] = label .. ": " .. table.concat(names, " ")
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
	collectgarbage("collect")
end
rawset(_G, "RENDER_SCREEN", oldScreen)
if os.getenv("TRAY_PIECES") then for _, line in ipairs(finials) do print(line) end end
print(string.format("ok with a faction watched the tray keeps 1 px from every data bar in %d cases (%d pieces, nearest %.2f px)", #CASES, pieces, nearest))
