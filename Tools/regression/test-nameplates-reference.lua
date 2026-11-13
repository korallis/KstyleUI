-- test-nameplates-reference.lua: the KSTY-44 bible's plate (renders/KSTY-44/detail-nameplate-and-damage-numbers.jpg) wins over the owner's 2026-11-09 picture for plates: a clean bar, gilt brackets on the target, the level diamond and the effect over the bar's right end, in every preset and on every screen.
local N = dofile("Tools/regression/nameplates_env.lua")

for _, preset in ipairs({ "lumen", "compact", "tank", "healer" }) do
	local env, K, ns = N.New()
	K.Options.Write("Nameplates", "preset", preset)
	N.Add(env, "nameplate1", { name = "Shadowgale Poacher", powerMax = 200 })
	local plate = ns.Plates.Get("nameplate1")
	assert(ns.Plate.DEFAULT_WIDTH == 156.75 and ns.Plate.DEFAULT_HEIGHT == 11.875, "the bible's bar is 156.75 by 11.875 root units")
	assert(plate.ornament == nil, "a plate owns no ornament handle: no rail, end or cap on or around the bar")
	assert(plate.health.caps == nil and plate.health.chrome == nil, "the bar has no pill masks or rounded chrome")
	assert(plate.health.unitBar and plate.health.cleanLit, "the bar is the shared unit bar with its one-pixel top highlight")
	assert(plate.name:GetText() == "SHADOWGALE POACHER", "readable plate names use caps")
	assert((plate.name:GetFont()) == (K.Tokens.Font("names")), "default names use the kit's names face")
	local shadowX, shadowY = plate.name:GetShadowOffset()
	assert(shadowX > 0 and shadowY == -shadowX, "unoutlined names keep the kit's soft world-text shadow")
	assert(plate.name:GetJustifyH() == "CENTER", "the name is centred above the bar")
	local _, _, _, _, nameLift = plate.name:GetPoint(1)
	assert(math.abs(nameLift - K.Widgets.Snap(plate, ns.Plate.NAME_GAP)) < 1e-6, "the name sits the mock-up's gap above the bar")
	local withName = ns.Auras.Extent(plate)
	K.Options.Write("Nameplates", "name.show", false)
	local withoutName = ns.Auras.Extent(plate)
	K.Options.Write("Nameplates", "name.show", true)
	assert(math.abs(withName - withoutName - (ns.Plate.NAME_GAP + ns.Settings.Get("name.size") + K.Tokens.Size("gapMedium") - K.Tokens.Size("gapTiny"))) < 1e-6, "the effects start a clear gap above the name")
	local extent = ns.Stacking.Extent()
	assert(extent >= env.Look(plate.name:GetWidth()), "the stacking footprint covers the name's overhang")
	assert(plate.level:IsShown(), "the level diamond shows by default, in every preset")
	assert(not ns.Settings.Get("cast.hideOnTarget"), "the target's cast remains on its plate")
	assert(not plate.brackets:IsShown(), "no brackets before the plate is the target")
	N.Target(env, "nameplate1")
	assert(plate.brackets:IsShown(), "the target's plate shows its brackets")
	local nr, ng, nb = plate.name:GetTextColor()
	assert(N.SameColor(nr, ng, nb, K.Tokens.Color("textEmphasis")), "the target's name stays white, as the mock-up's")
	local edge = N.Last(plate.health.under.edgeHard, "SetColorTexture")
	assert(N.SameColor(edge[1], edge[2], edge[3], K.Tokens.Color("black")), "the target's bar keeps its black edge; the brackets mark it")
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 136197, notInterruptible = false, secret = true })
	assert(plate.cast:IsVisible(), "the target's secret cast is visible")
	assert(plate.castBar.caps == nil and plate.castBar.chrome == nil, "the cast bar is square too")
	assert(not plate.castIcon:IsShown() and not plate.castName:IsShown() and not plate.castTime:IsShown(), "the cast under the plate is only a thin bar")
	assert(env.Look(plate.castBar:GetHeight()) == 6, "the cast bar is six root units tall")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

for _, screen in ipairs({ { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 3456, 2234 } }) do
	local env, K, ns = N.New({ width = screen[1], height = screen[2] })
	N.Add(env, "nameplate1")
	N.Target(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local bar = plate.health
	K.Widgets.RestyleAll()
	local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(bar)
	local border = K.Widgets.Border(bar)
	local where = screen[1] .. "x" .. screen[2]
	local _, _, _, x, y = bar.under.edgeHard:GetPoint(1)
	assert(N.Same(x, -border) and N.Same(y, border), where .. ": the bar's black edge is the kit's border")
	local _, _, _, hx, hy = bar.under.edgeSoft:GetPoint(1)
	assert(N.Same(hx, -border * 2) and N.Same(hy, border * 2), where .. ": and as much again of 45 percent black outside it")
	local _, _, _, cx = plate.castBar.keyline:GetPoint(1)
	assert(N.Same(cx, -border), where .. ": the cast bar takes the same edge")
	local _, relative, relativePoint, _, castY = plate.cast:GetPoint(1)
	assert(relative == bar and relativePoint == "BOTTOMLEFT", where .. ": the cast is placed from the health bar")
	assert(N.Same(-castY, border * 2 + K.Widgets.Snap(plate, ns.Plate.FRAME_GAP)), where .. ": a clear gap separates the health and cast edges")
	for _, side in ipairs(plate.brackets.sides) do
		local stroke = env.Look(side.stroke:GetWidth())
		assert(stroke >= pixel - 1e-6, where .. ": a bracket's stroke is at least one physical pixel")
	end
	local r, g, b = plate.brackets.sides[1].stroke:GetVertexColor()
	assert(N.SameColor(r, g, b, K.Tokens.Color("giltLit")), where .. ": the brackets stay lit gilt after a kit restyle")
	env.FireEvent("UNIT_NAME_UPDATE", "nameplate1")
	N.Target(env, nil)
	assert(not plate.brackets:IsShown(), where .. ": clearing the target hides the brackets")
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
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

do
	local env, K, ns = N.New({ saved = {
		version = 20, characters = {}, account = { setupSeen = true }, devlog = {},
		profiles = {
			Default = { Nameplates = {
				enabled = true, name = { size = 12 }, level = { show = false, size = 16, outline = "OUTLINE" },
				debuffs = { size = 26, growthX = "RIGHT", showTime = true, textSize = 12 }, target = { color = {} },
			} },
			Custom = { Nameplates = {
				enabled = true, name = { size = 14 }, level = { show = true, size = 18 }, debuffs = { size = 32, growthX = "LEFT" },
				target = { color = { r = 0.9, g = 0.1, b = 0.1 } },
			} },
		},
		layouts = {
			Default = { ["nameplates.plate"] = { width = 151.56, height = 13.78 } },
			Custom = { ["nameplates.plate"] = { width = 200, height = 13.78, anchor = "TOP", x = 4, y = -20 } },
		},
	} })
	local data = K.Store.Data()
	local default, custom = data.profiles.Default.Nameplates, data.profiles.Custom.Nameplates
	local _ = default
	local get = ns.Settings.Get
	assert(get("name.size") == 16 and get("level.show") == true and get("level.size") == 13 and get("level.outline") == "NONE", "settings still at the old picture's defaults follow the bible")
	assert(get("debuffs.size") == 29 and get("debuffs.growthX") == "LEFT" and get("debuffs.showTime") == false and get("debuffs.textSize") == 13, "and so do the old effect defaults")
	local tr, tg, tb = K.Tokens.Color("giltLit")
	local target = get("target.color")
	assert(N.SameColor(target.r, target.g, target.b, tr, tg, tb), "an empty saved target colour reads the new default")
	assert(data.layouts.Default["nameplates.plate"] == nil, "a saved size still at the old 151.56 by 13.78 follows the bible's bar")
	assert(custom.name.size == 14 and custom.level.show == true and custom.level.size == 18 and custom.debuffs.size == 32, "a value the player chose is kept, got " .. tostring(custom.name.size) .. " " .. tostring(custom.level.show) .. " " .. tostring(custom.level.size) .. " " .. tostring(custom.debuffs.size))
	assert(custom.target.color.r == 0.9, "a custom target colour is kept")
	local entry = data.layouts.Custom["nameplates.plate"]
	assert(entry.width == 200 and entry.height == nil and entry.x == 4, "a custom width and position stay; only the old default height goes")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = N.New({ saved = {
		version = 20, characters = {}, account = { setupSeen = true }, devlog = {}, layouts = {},
		profiles = { Default = { Nameplates = { target = { color = { r = 0, g = 0, b = 0 } } } } },
	} })
	local r, g, b = K.Tokens.Color("gilt")
	local _ = env
	local probe = { profiles = { P = { Nameplates = { target = { color = { r = r, g = g, b = b } } } } }, layouts = {} }
	K.Store.migrations[26](probe)
	assert(probe.profiles.P.Nameplates.target.color == nil, "a target colour still at the old gilt default follows the bible's lit gilt")
	assert(K.Store.Data().profiles.Default.Nameplates.target.color.r == 0, "a black target colour is kept")
end

print("nameplates reference ok")
