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

-- Build each module once, then drive live display and size changes through the real ScaleChanged callbacks.
-- Rebuilding the HUD on every screen exceeded the Lua 5.1 budget. The page renderer is not involved: these are
-- the font heights and shadows the addon actually passed to the stubs, before any canvas rounding.
local MATRIX = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local measured = 0
local function checkEnvironment(env, name)
	local K = env.KstyleUI
	if not K then
		return
	end
	env.SetQuiet(true)
	for _, screen in ipairs(MATRIX) do
		env.GetPhysicalScreenSize = function() return screen[1], screen[2] end
		local parentScale = env.UIParent:GetEffectiveScale()
		env.UIParent:SetSize(768 * screen[1] / screen[2] / parentScale, 768 / parentScale)
		env.FireEvent("DISPLAY_SIZE_CHANGED")
	for _, size in ipairs({ 0.6, K.Scale.DEFAULT_USER_SCALE, 1.5 }) do
		K.Scale.SetUserScale(size)
		env.RunTimers()
		local seen, count = {}, 0
		local function visit(object)
			if seen[object] then
				return
			end
			seen[object] = true
			local font = object._state.Font
			if object._fontFromAddon and font and type(font[2]) == "number" and object:IsVisible() then
				local k = object:GetEffectiveScale() * screen[2] / 768
				local where = string.format("%s at %dx%d, requested %.5f, applied %.5f", name, screen[1], screen[2], size, K.Scale.AppliedUserScale())
				assert(whole(font[2] * k), where .. ": font is fractional: " .. font[2] * k)
				local shadow = object._state.ShadowOffset
				if shadow then
					assert(whole(shadow[1] * k) and whole(shadow[2] * k), where .. ": shadow is fractional")
				end
				count = count + 1
			end
			for _, region in ipairs(object._regions) do
				visit(region)
			end
			for _, child in ipairs(object._kids) do
				visit(child)
			end
		end
		for _, frame in ipairs(env._frames) do
			visit(frame)
		end
		measured = measured + count
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
	end
	env.SetQuiet(false)
end

rawset(_G, "RENDER_SCENE_LIB", true)
rawset(_G, "STUB_FONT_ORIGINS", true)
do
	rawset(_G, "RENDER_SCREEN", { width = 2383, height = 1540 })
	local Common = dofile("Tools/render/scenes/_common.lua")
	local Hud = dofile("Tools/render/scenes/hud.lua")
	local opts = Hud.Options({ layout = "DPS" })
	opts.party = { { "Tank", "WARRIOR", 80, "TANK" }, { "Healer", "PRIEST", 70, "HEALER" }, { "Mage", "MAGE", 60, "DAMAGER" } }
	opts.trackerAnchor = Hud.StoryTracker("DPS", false)
	local names = Hud.Order()
	names[#names + 1], names[#names + 2] = "groupframes", "meters"
	for _, name in ipairs(names) do
		local envs = {}
		rawset(_G, "STUB_ENVS", envs)
		Hud.Module(name, opts)
		for _, env in ipairs(envs) do
			checkEnvironment(env, name)
		end
	end
	local B = dofile("Tools/regression/bags_env.lua")
	local benv = B.New({ setup = Common.ForceScreen })
	benv.OpenAllBags()
	checkEnvironment(benv, "bags")
	local O = dofile("Tools/regression/options_env.lua")
	local oenv, OK = O.New({ setup = Common.ForceScreen })
	OK.Options.Open("General")
	oenv.RunTimers()
	checkEnvironment(oenv, "options")
	local envs = {}
	rawset(_G, "STUB_ENVS", envs)
	local Skins = dofile("Tools/render/scenes/_skins.lua")
	Skins.Scene("loot")
	for _, env in ipairs(envs) do
		checkEnvironment(env, "loot skin")
	end
	local CoreEnv = dofile("Tools/regression/core_env.lua")
	local cenv, CK = CoreEnv.New({ size = "default", setup = Common.ForceScreen })
	CoreEnv.Boot(cenv)
	CK.Setup.ShowWindow()
	CK.Setup.Go(2)
	checkEnvironment(cenv, "setup preview")
	rawset(_G, "STUB_ENVS", nil)
	collectgarbage("collect")
end
rawset(_G, "RENDER_SCREEN", nil)
rawset(_G, "RENDER_SCENE_LIB", nil)
rawset(_G, "STUB_FONT_ORIGINS", nil)
assert(measured > 5000, "the nine-screen matrix must measure the live modules, not an empty tree")
print("text pixels ok: " .. measured .. " live font sizes across nine screens and three requested sizes")
