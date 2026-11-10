-- test-nameplates-reference.lua: the owner's 2026-11-09 picture wins over the old pill, badge and cast-dedup defaults.
local N = dofile("Tools/regression/nameplates_env.lua")

for _, preset in ipairs({ "lumen", "compact", "tank", "healer" }) do
	local env, K, ns = N.New()
	K.Options.Write("Nameplates", "preset", preset)
	N.Add(env, "nameplate1", { name = "Shadowgale Poacher", powerMax = 200 })
	local plate = ns.Plates.Get("nameplate1")
	assert(ns.Plate.DEFAULT_WIDTH == 151.56 and ns.Plate.DEFAULT_HEIGHT == 13.78, "the reference fill is 151.56 by 13.78 root units")
	assert(plate.health.caps == nil and plate.health.chrome == nil, "the bar has no pill masks or rounded chrome")
	assert(not plate.health.lit:IsShown() and not plate.health.shade:IsShown(), "the kit's lit edge and shade stay off; the fill texture carries the ramp")
	assert(plate.health.keyline, "a square keyline surrounds the health bar")
	assert(plate.name:GetText() == "SHADOWGALE POACHER", "readable plate names use caps")
	assert((plate.name:GetFont()) == (K.Tokens.Font("names")), "default names use the kit's tighter tracked names face")
	local shadowX, shadowY = plate.name:GetShadowOffset()
	assert(shadowX > 0 and shadowY == -shadowX, "unoutlined names keep the kit's soft world-text shadow")
	assert(plate.name:GetJustifyH() == "CENTER", "the name is centred above the bar")
	local extent = ns.Stacking.Extent()
	assert(extent >= plate.name:GetWidth(), "the stacking footprint covers the cap's overhang")
	assert(not plate.level:IsShown(), "no level badge by default, in every preset")
	local source = plate.health.fillSource
	assert(source and N.SameColor(source[1], source[2], source[3], K.Tokens.Color("plateHostile")), "a caster's ramp is built on plateHostile")
	local gradient = N.Last(plate.health:GetStatusBarTexture(), "SetGradient")
	assert(gradient and gradient[1] == "VERTICAL", "the fill ramps vertically")
	local function byte(value)
		return math.floor(value * 255 + 0.5)
	end
	assert(byte(gradient[3].r) == 208 and byte(gradient[3].g) == 74 and byte(gradient[3].b) == 67, "the ramp's top is the picture's (208, 74, 67)")
	assert(byte(gradient[2].r) == 179 and byte(gradient[2].g) == 59 and byte(gradient[2].b) == 54, "the ramp's bottom is the picture's (179, 59, 54)")
	assert(not ns.Settings.Get("cast.hideOnTarget"), "the target's cast remains on its plate")
	N.Target(env, "nameplate1")
	local nr, ng, nb = plate.name:GetTextColor()
	assert(N.SameColor(nr, ng, nb, K.Tokens.Color("gilt")), "the selected name shares the outline's muted gold")
	assert((plate.name:GetFont()) == (K.Tokens.Font("names")), "the gold target name keeps the names face")
	local r, g, b = plate.health.keyline:GetVertexColor()
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
	local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(bar)
	local border = K.Widgets.Snap(bar, 1.15)
	local inset = K.Widgets.Snap(bar, 1.15)
	assert(N.Same(x, -inset - border) and N.Same(y, inset + border), "the target outline leaves the measured dark inset around the fill")
	local physical = border / pixel
	assert(physical >= 1 and N.Same(physical, math.floor(physical + 0.5)), "the measured outline snaps to whole physical pixels on every screen")
	local _, _, _, ix, iy = bar.rimGapFill:GetPoint(1)
	assert(N.Same(ix, -inset) and N.Same(iy, inset), "the dark inset spans all four sides inside the gold frame")
	local _, _, _, bx, by = bar.rimGapFill:GetPoint(2)
	assert(N.Same(bx, inset) and N.Same(by, -inset), "the dark inset is equal at the lower and right edges")
	local _, _, _, ox, oy = bar.keyline:GetPoint(2)
	assert(N.Same(ox, inset + border) and N.Same(oy, -inset - border), "the gold outline has the same inset on all four sides")
	local plate = ns.Plates.Get("nameplate1")
	local _, relative, relativePoint, _, castY = plate.cast:GetPoint(1)
	assert(relative == bar and relativePoint == "BOTTOMLEFT", "the cast is placed from the health bar")
	local castPixel = K.Widgets.Snap(plate.castBar, 1.15)
	local _, _, _, cx, cy = plate.castBar.keyline:GetPoint(1)
	assert(N.Same(cx, -castPixel) and N.Same(cy, castPixel), "the cast keeps its own measured dark border")
	local clear = -castY - bar.rimOutset - castPixel
	assert(N.Same(clear, K.Widgets.Snap(plate, 1.15)), "a measured clear gap separates the health and cast borders")
	local r, g, b = bar.keyline:GetVertexColor()
	assert(N.SameColor(r, g, b, K.Tokens.Color("gilt")), "the target outline stays gold after a kit restyle")
	env.FireEvent("UNIT_NAME_UPDATE", "nameplate1")
	r, g, b = plate.name:GetTextColor()
	assert(N.SameColor(r, g, b, K.Tokens.Color("gilt")), "a name update keeps the selected name gold")
	N.Target(env, nil)
	r, g, b = plate.name:GetTextColor()
	assert(N.SameColor(r, g, b, K.Tokens.Color("textEmphasis")), "an unselected name returns to warm white")
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
	assert(layouts.Default["nameplates.plate"].height == nil, "a saved height that is still the old 12 follows the picture")
	assert(layouts.Default["nameplates.plate"].y == 160, "the on-screen sample position is unchanged")
	assert(layouts.Custom["nameplates.plate"].width == 230 and layouts.Custom["nameplates.plate"].height == 16 and layouts.Custom["nameplates.plate"].x == 12, "a custom size and position are preserved")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("nameplates reference ok")
