-- test-nameplates-reference.lua: the owner's 2026-11-09 picture wins over the old pill, badge and cast-dedup defaults.
local N = dofile("Tools/regression/nameplates_env.lua")

for _, preset in ipairs({ "lumen", "compact", "tank", "healer" }) do
	local env, K, ns = N.New()
	K.Options.Write("Nameplates", "preset", preset)
	N.Add(env, "nameplate1", { name = "Shadowgale Poacher", powerMax = 200 })
	local plate = ns.Plates.Get("nameplate1")
	assert(ns.Plate.DEFAULT_WIDTH == 154 and ns.Plate.DEFAULT_HEIGHT == 12, "the reference health bar is 154 by 12 root units")
	assert(plate.health.caps == nil and plate.health.chrome == nil, "the bar has no pill masks or rounded chrome")
	assert(not plate.health.lit:IsShown() and not plate.health.shade:IsShown(), "the fill has no lit edge or gradient")
	assert(plate.health.keyline, "a square one-pixel keyline surrounds the health bar")
	assert(plate.name:GetText() == "SHADOWGALE POACHER", "readable plate names use caps")
	assert((plate.name:GetFont()) == (K.Tokens.Font("heading")), "names use the kit's heading face")
	assert(plate.name:GetJustifyH() == "CENTER", "the name is centred above the bar")
	local extent = ns.Stacking.Extent()
	assert(extent >= plate.name:GetWidth(), "the stacking footprint covers the cap's overhang")
	assert(not plate.level:IsShown(), "no level badge by default, in every preset")
	local r, g, b = plate.health:GetStatusBarColor()
	assert(N.SameColor(r, g, b, K.Tokens.Color("plateHostile")), "a caster's default fill stays flat red")
	assert(not ns.Settings.Get("cast.hideOnTarget"), "the target's cast remains on its plate")
	N.Target(env, "nameplate1")
	r, g, b = plate.health.keyline:GetVertexColor()
	assert(N.SameColor(r, g, b, K.Tokens.Color("gilt")), "the target outline uses gold")
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 136197, notInterruptible = false, secret = true })
	assert(plate.cast:IsVisible(), "the target's secret cast is visible")
	assert(plate.castBar.caps == nil and plate.castBar.chrome == nil, "the cast bar is square too")
	assert(not plate.castIcon:IsShown() and not plate.castName:IsShown() and not plate.castTime:IsShown(), "the reference cast is only a thin bar")
	assert(plate.castBar:GetHeight() == 6, "the cast bar is six root units tall")
	K.Options.Write("Nameplates", "level.show", true)
	assert(plate.level:IsShown(), "the level badge remains a setting")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, _, ns = N.New()
	N.Add(env, "nameplate1", { classification = "elite" })
	local plate = ns.Plates.Get("nameplate1")
	local point, relative, relativePoint = plate.marker:GetPoint(1)
	assert(point == "RIGHT" and relative == plate.health and relativePoint == "LEFT", "without a level badge the classification marker sits beside the bar, not above an invisible badge")
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 }, { 3456, 2234 } }) do
	local env, K, ns = N.New({ width = screen[1], height = screen[2] })
	N.Add(env, "nameplate1")
	N.Target(env, "nameplate1")
	local bar = ns.Plates.Get("nameplate1").health
	K.Widgets.RestyleAll()
	local _, _, _, x, y = bar.keyline:GetPoint(1)
	local border = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(bar)
	assert(N.Same(x, -border) and N.Same(y, border), "the square outline outsets the fill by exactly one physical pixel")
	assert(N.Same(border * K.Widgets.ScaleFactor(bar) / K.Scale.Pixel(1), 1), "the outline stays one physical pixel on each reference screen")
	local r, g, b = bar.keyline:GetVertexColor()
	assert(N.SameColor(r, g, b, K.Tokens.Color("gilt")), "the target outline stays gold after a kit restyle")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = N.New({ saved = {
		version = 9, profiles = { Default = {}, Custom = {} }, characters = {}, account = { setupSeen = true }, devlog = {},
		layouts = {
			Default = { ["nameplates.plate"] = { width = 175, height = 12, anchor = "CENTER", x = 0, y = 160 } },
			Custom = { ["nameplates.plate"] = { width = 230, height = 16, anchor = "TOP", x = 12, y = -60 } },
		},
	} })
	local layouts = K.Store.Data().layouts
	assert(layouts.Default["nameplates.plate"].width == 175, "an explicit saved width is not mistaken for the old default and overwritten")
	assert(layouts.Default["nameplates.plate"].y == 160, "the on-screen sample position is unchanged")
	assert(layouts.Custom["nameplates.plate"].width == 230 and layouts.Custom["nameplates.plate"].x == 12, "a custom size and position are preserved")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("nameplates reference ok")
