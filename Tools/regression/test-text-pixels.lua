-- test-text-pixels.lua: the nameplates and the data bars set their text through Widgets.ApplyFont, as the unit frames, chat and auras do (#210), so at the owner's 2383 x 1540 screen with UI scale 768/1080 and at 1080p every text size lands on a whole number of physical pixels and an unoutlined text's shadow sits one border down and right; the sizes stay within half a pixel of what each module asks for.
local N = dofile("Tools/regression/nameplates_env.lua")
local D = dofile("Tools/regression/databars_env.lua")

local UI_HEIGHT = 768
local OWNER_UI_SCALE = 768 / 1080
local SCREENS = { { 2383, 1540 }, { 1920, 1080 } }
local SIZES = { "default", 1 }

local function whole(x)
	return math.abs(x - math.floor(x + 0.5)) < 1e-6
end

-- Every font string under frame that has a font set, with the frame it hangs from.
local function texts(frame, out, seen)
	out, seen = out or {}, seen or {}
	if seen[frame] then
		return out
	end
	seen[frame] = true
	for _, region in ipairs(frame._regions or {}) do
		if region._type == "FontString" and region._state.Font then
			out[#out + 1] = region
		end
	end
	for _, kid in ipairs(frame._kids or {}) do
		texts(kid, out, seen)
	end
	return out
end

local function check(text, screen, K, where)
	local _, size, flags = text:GetFont()
	assert(type(size) == "number" and size > 0, where .. ": the text has a size")
	local k = text:GetEffectiveScale() * screen[2] / UI_HEIGHT
	local name = tostring(text:GetText())
	assert(whole(size * k), string.format("%s: '%s' is %.3f px, not whole pixels", where, name, size * k))
	if (flags or "") == "" then
		local border = K.Scale.Border() * K.Scale.Root():GetEffectiveScale() * screen[2] / UI_HEIGHT
		local x, y = text:GetShadowOffset()
		assert(math.abs(x * k - border) < 1e-6 and math.abs(x + y) < 1e-6,
			string.format("%s: '%s' casts its shadow one border (%d px) down and right, got %.3f px", where, name, border, x * k))
	end
end

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

print("text pixels ok")
