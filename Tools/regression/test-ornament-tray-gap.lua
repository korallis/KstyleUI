-- test-ornament-tray-gap.lua: with unit frames and action bars in one environment at Full, the tray draws and the player block beside it draws no end piece or rail, as the unit frames carry no bar ornament (Lee, 2026-11-12); the tray's clearance from other bars is test-ornament-tray-databars.lua's.
rawset(_G, "RENDER_SCREEN", { width = 3456, height = 2234, uiScale = 768 / 1080 })
local Common = dofile("Tools/render/scenes/_common.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local env, K, ns = U.New(Common.ScreenOpts({
	setup = function(e)
		Common.ForceScreen(e)
		AB.InstallGame(e, { class = "WARRIOR" })
	end,
	before = function(e)
		local files = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_ActionBars/") then
				files[#files + 1] = path
			end
		end
		Load(files, e)
	end,
}))
AB.Enable(env, K)
for i = 1, 12 do
	env._game.slots[i] = { texture = 135489, type = "spell", id = 1000 + i }
	env._game.slots[60 + i] = { texture = 135489, type = "spell", id = 2000 + i }
end
local enabled = {}
for _, name in ipairs(K.Modules.List()) do
	enabled[name] = K.Modules.IsEnabled(name)
end
assert(enabled.UnitFrames and enabled.ActionBars, "both modules run in the one environment")
assert(K.Setup.Apply({ layout = "DPS", modules = enabled }), "the DPS layout applies")
env.RunTimers()
local widgets = K.Store.Module("Widgets")
widgets.cardMaterial, widgets.ornaments = "ForgedBrackets", "Full"
K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
env.RunTimers()

local W = K.Widgets
local view = ns.Frames.Get("player").views[1]
local block = view.health.ornament
local pixel = K.Scale.Pixel(1)
local function rect(region)
	local f = W.ScaleFactor(region)
	return { l = env.Look(region:GetLeft()) * f / pixel, r = env.Look(region:GetRight()) * f / pixel, t = env.Look(region:GetTop()) * f / pixel, b = env.Look(region:GetBottom()) * f / pixel }
end
local function file(texture)
	return tostring(texture:GetTexture()):match("([%w]+)%.png$") or ""
end
local trays = {}
for row in pairs(W.OrnamentRows) do
	for i = 1, row.used do
		if file(row.textures[i]):find("^Tray") then trays[#trays + 1] = rect(row.textures[i]) end
	end
end
assert(#trays > 0, "bar 1 and bar 2 place their tray")
block:Restyle()
assert(block.used == 0, "the player block beside the tray draws no ornament, not " .. block.used .. " pieces")
assert(#env._errors == 0, tostring(env._errors[1]))
print("ok the tray draws " .. #trays .. " finials beside a player block that draws no ornament")
