-- test-ornament-tray-gap.lua: with unit frames and action bars in one environment, the player block's Full end pieces keep clear of the tray, hooked pieces by half the block.
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
	return { l = region:GetLeft() * f / pixel, r = region:GetRight() * f / pixel, t = region:GetTop() * f / pixel, b = region:GetBottom() * f / pixel }
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
local function nearest()
	block:Restyle()
	local worst
	for i = 1, block.used do
		local name = file(block.textures[i])
		if name:find("^End") or name:find("^Arrow") or name:find("^Wing") then
			local a = rect(block.textures[i])
			for _, b in ipairs(trays) do
				local d = math.max(a.l - b.r, b.l - a.r, a.b - b.t, b.b - a.t, 0)
				if not worst or d < worst.gap then worst = { gap = d, name = name } end
			end
		end
	end
	assert(worst, "the player block places its end pieces")
	worst.hooked = not worst.name:find("Pointed", 1, true) and not worst.name:find("^Arrow") and not worst.name:find("^Wing")
	return worst
end
local half = math.floor((view.health:GetTop() - view.power:GetBottom()) * W.ScaleFactor(view.health) / pixel / 2)
local need = math.max(4 / pixel, 3)
local function fails(w)
	return w.gap < need or w.hooked and w.gap < half
end
local held = nearest()
assert(not fails(held), string.format("%s sits %.1f px from the tray; it needs %.1f, and %d when hooked", held.name, held.gap, need, half))
local rows = {}
for row in pairs(W.OrnamentRows) do
	rows[row] = true
end
for row in pairs(rows) do
	W.OrnamentRows[row] = nil
end
local blind = nearest()
for row in pairs(rows) do
	W.OrnamentRows[row] = true
end
block:Restyle()
assert(fails(blind), string.format("without the tray in the registry the end piece is %s at %.1f px, so this layout cannot show the avoidance", blind.name, blind.gap))
print(string.format("ok player end %s %.1f physical px from the tray (needs %.1f, hooked %d); without the registry %s at %.1f px fails", held.name, held.gap, need, half, blind.name, blind.gap))
