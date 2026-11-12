-- text_pixels_lib.lua: what test-text-pixels.lua and test-text-pixels-hud.lua share, so each file stays within the time budget: the whole-pixel and shadow checks, the nine-screen matrix, and the run over the HUD modules and the other surfaces.
local M = {}

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

local FIRST = { nameplates = true, chat = true, minimap = true, auras = true, databars = true, tracker = true }

M.UI_HEIGHT, M.OWNER_UI_SCALE, M.SCREENS, M.SIZES = UI_HEIGHT, OWNER_UI_SCALE, SCREENS, SIZES
M.whole, M.texts, M.check = whole, texts, check

function M.Run(first)
	rawset(_G, "RENDER_SCENE_LIB", true)
	rawset(_G, "STUB_FONT_ORIGINS", true)
	rawset(_G, "RENDER_SCREEN", { width = 2383, height = 1540 })
	local Common = dofile("Tools/render/scenes/_common.lua")
	local Hud = dofile("Tools/render/scenes/hud.lua")
	local opts = Hud.Options({ layout = "DPS" })
	opts.party = { { "Tank", "WARRIOR", 80, "TANK" }, { "Healer", "PRIEST", 70, "HEALER" }, { "Mage", "MAGE", 60, "DAMAGER" } }
	opts.trackerAnchor = Hud.StoryTracker("DPS", false)
	local names = Hud.Order()
	names[#names + 1], names[#names + 2] = "groupframes", "meters"
	for _, name in ipairs(names) do
		if (FIRST[name] or false) == first then
			local envs = {}
			rawset(_G, "STUB_ENVS", envs)
			Hud.Module(name, opts)
			for _, env in ipairs(envs) do
				checkEnvironment(env, name)
			end
		end
	end
	if first then
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
		CK.Setup.Go(3)
		checkEnvironment(cenv, "setup preview")
	end
	rawset(_G, "STUB_ENVS", nil)
	collectgarbage("collect")
	rawset(_G, "RENDER_SCREEN", nil)
	rawset(_G, "RENDER_SCENE_LIB", nil)
	rawset(_G, "STUB_FONT_ORIGINS", nil)
	return measured
end

return M
