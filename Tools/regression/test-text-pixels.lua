-- test-text-pixels.lua: the nameplates and the data bars set their text through Widgets.ApplyFont, as the unit frames, chat and auras do (#210), so at the owner's 2383 x 1540 screen with UI scale 768/1080 and at 1080p every text size lands on a whole number of physical pixels and an unoutlined text's shadow sits one border down and right; the sizes stay within half a pixel of what each module asks for. The nine-screen matrix over the first half of the HUD modules and the bags, options, loot and setup surfaces runs here; test-text-pixels-hud.lua runs the other modules.
local N = dofile("Tools/regression/nameplates_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local P = dofile("Tools/regression/text_pixels_lib.lua")
local OWNER_UI_SCALE, SCREENS, SIZES, texts, check = P.OWNER_UI_SCALE, P.SCREENS, P.SIZES, P.texts, P.check

-- Nameplates: a plate at UIParent's scale and one a distance factor larger, each with its name, health text, a cast
-- with its spell text and a debuff with its count and timer.
for _, screen in ipairs(SCREENS) do
	for _, size in ipairs(SIZES) do
		local env, K, ns = N.New({ width = screen[1], height = screen[2], uiScale = OWNER_UI_SCALE, size = size })
		local where = string.format("nameplates at %dx%d, size %s", screen[1], screen[2], tostring(size))
		local counted, bases = 0, {}
		for i, factor in ipairs({ 1, 1.2 }) do
			local token = "nameplate" .. i
			bases[i] = N.Add(env, token, { name = "Kobold " .. i }, { scale = OWNER_UI_SCALE * factor })
			N.Debuffs(env, token, 2)
		end
		N.Settle(env)
		for i in ipairs(bases) do
			N.Cast(env, "nameplate" .. i, { name = "Fireball", duration = 3 })
		end
		N.Tick(env, 0.1)
		for i, base in ipairs(bases) do
			assert(ns.Plates.Get("nameplate" .. i), where .. ": the plate is styled")
			local list = texts(base)
			assert(#list >= 4, where .. ": the plate has its name, health, cast and aura texts, got " .. #list)
			for _, text in ipairs(list) do
				check(text, screen, K, where .. ", plate " .. i)
			end
			counted = counted + #list
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
		assert(counted > 0, where .. ": texts were checked")
	end
end

-- Data bars: the XP, reputation and honour lines' captions and the readout card's text, with a soft shadow and with a
-- thin outline. The texts checked are the ones the module made: those under the frames it created when it started.
for _, screen in ipairs(SCREENS) do
	for _, size in ipairs(SIZES) do
		for _, outline in ipairs({ "NONE", "OUTLINE" }) do
			local env, K = D.New({ width = screen[1], height = screen[2], uiScale = OWNER_UI_SCALE, size = size, enable = false })
			local where = string.format("data bars at %dx%d, size %s, outline %s", screen[1], screen[2], tostring(size), outline)
			for _, key in ipairs({ "xp", "rep", "honor", "strip" }) do
				K.Options.Write("DataBars", key .. ".outline", outline)
			end
			local first = #env._frames + 1
			K.Modules.Enable("DataBars")
			D.W.Settle(env)
			local list, seen = {}, {}
			for i = first, #env._frames do
				texts(env._frames[i], list, seen)
			end
			assert(#list >= 3, where .. ": the bars and the readout have their texts, got " .. #list)
			for _, text in ipairs(list) do
				check(text, screen, K, where)
			end
			assert(#env._errors == 0, tostring(env._errors[1]))
		end
	end
end

local measured = P.Run(true)
assert(measured > 2000, "the nine-screen matrix must measure the live modules, not an empty tree")
print("text pixels ok: " .. measured .. " live font sizes across nine screens and three requested sizes")
