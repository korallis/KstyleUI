-- test-nameplates-height.lua: the owner's picture (acceptance 1, correction 2) sets the plate, not the target sigil.
-- A non-target fill is 264 by 24 physical pixels on the 3456 by 2234 panel, inside a two-physical-pixel border,
-- so the outer health rect is 268 by 28. The border stays two physical pixels on every screen of the nine-screen
-- matrix. The old rule that a plate match the sigil's health height is reversed by the picture.
local N = dofile("Tools/regression/nameplates_env.lua")

local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local REFERENCE = { width = 3456, height = 2234, uiScale = 768 / 1080, size = "default" }

local function pixels(K, bar, units)
	return units / (K.Scale.Pixel(1) / K.Widgets.ScaleFactor(bar))
end

local function borderPixels(K, bar)
	local _, _, _, x = bar.keyline:GetPoint(1)
	return pixels(K, bar, -x)
end

do
	local env, K, ns = N.New(REFERENCE)
	N.Add(env, "nameplate1", { name = "Shadowgale Poacher", reaction = 2, health = 100, maxHealth = 100 })
	local bar = ns.Plates.Get("nameplate1").health
	local width, height = pixels(K, bar, bar:GetWidth()), pixels(K, bar, bar:GetHeight())
	local border = borderPixels(K, bar)
	assert(math.abs(width - 264) < 0.01, "the fill is 264 physical pixels wide, got " .. tostring(width))
	assert(math.abs(height - 24) < 0.01, "the fill is 24 physical pixels tall, got " .. tostring(height))
	assert(math.abs(border - 2) < 0.01, "the border is two physical pixels, got " .. tostring(border))
	assert(math.abs(width + border * 2 - 268) < 0.01 and math.abs(height + border * 2 - 28) < 0.01, "the outer rect is 268 by 28")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

for _, screen in ipairs(SCREENS) do
	for _, setup in ipairs({
		{ uiScale = 1, size = 1 },
		{ uiScale = 768 / 1080, size = "default" },
	}) do
		local env, K, ns = N.New({
			width = screen[1], height = screen[2], uiScale = setup.uiScale, size = setup.size,
		})
		N.Add(env, "nameplate1", { reaction = 2 })
		local bar = ns.Plates.Get("nameplate1").health
		local border = borderPixels(K, bar)
		local where = string.format("%dx%d ui %s size %s", screen[1], screen[2], tostring(setup.uiScale), tostring(setup.size))
		assert(math.abs(border - 2) < 0.01, "the border stays two physical pixels at " .. where .. ", got " .. tostring(border))
		assert(math.abs(border - math.floor(border + 0.5)) < 0.01, "the border is a whole number of physical pixels at " .. where)
		assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	end
end

local function byte(value)
	return math.floor(value * 255 + 0.5)
end

local function stops(bar)
	local gradient = N.Last(bar:GetStatusBarTexture(), "SetGradient")
	assert(gradient and gradient[1] == "VERTICAL", "the fill ramps vertically")
	return gradient[3], gradient[2]
end

local TOP = { 208 / 195, 74 / 67, 67 / 61 }
local BOTTOM = { 179 / 195, 59 / 67, 54 / 61 }

do
	local env, K, ns = N.New()
	local function expectRatio(bar, r, g, b, label)
		local source = bar.fillSource
		assert(source and N.SameColor(source[1], source[2], source[3], r, g, b), label .. " keeps its token as the ramp's reference")
		local top, bottom = stops(bar)
		assert(byte(top.r) == byte(r * TOP[1]) and byte(top.g) == byte(g * TOP[2]) and byte(top.b) == byte(b * TOP[3]), label .. " top follows the picture's ratio")
		assert(byte(bottom.r) == byte(r * BOTTOM[1]) and byte(bottom.g) == byte(g * BOTTOM[2]) and byte(bottom.b) == byte(b * BOTTOM[3]), label .. " bottom follows the picture's ratio")
	end
	local function token(name)
		local r, g, b = K.Tokens.Color(name)
		return r, g, b
	end
	N.Add(env, "nameplate1", { reaction = 4, canAttack = true })
	local nr, ng, nb = token("neutral")
	expectRatio(ns.Plates.Get("nameplate1").health, nr, ng, nb, "a neutral plate")
	N.Add(env, "nameplate2", { canAttack = false, reaction = 5 })
	local fr, fg, fb = token("friendly")
	expectRatio(ns.Plates.Get("nameplate2").health, fr, fg, fb, "a friendly plate")
	N.Add(env, "nameplate3", { tapped = true })
	local tr, tg, tb = token("textDisabled")
	expectRatio(ns.Plates.Get("nameplate3").health, tr, tg, tb, "a tapped plate")
	N.Add(env, "nameplate4", { isPlayer = true, class = "MAGE", secretClass = true })
	local hidden = ns.Plates.Get("nameplate4").health
	local sr = hidden.fillSource and hidden.fillSource[1]
	assert(env.issecretvalue(sr), "a secret class colour is stored without arithmetic")
	local gradient = N.Last(hidden:GetStatusBarTexture(), "SetGradient")
	if gradient then
		assert(not env.issecretvalue(gradient[2].r) and not env.issecretvalue(gradient[3].r), "SetGradient never receives a secret colour")
	end
	local cr = hidden:GetStatusBarColor()
	assert(env.issecretvalue(cr), "the secret colour still reaches the status bar sink")
	assert(ns.Logic.Ramp(sr, hidden.fillSource[2], hidden.fillSource[3]) == nil, "the ramp rule refuses a secret colour")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, K = N.New({ saved = {
		version = 12,
		profiles = { Default = {}, Custom = {} },
		characters = {},
		account = { setupSeen = true },
		devlog = {},
		layouts = {
			Default = { ["nameplates.plate"] = { width = 154, height = 12 } },
			Custom = { ["nameplates.plate"] = { width = 154, height = 18, anchor = "CENTER", x = 4 } },
		},
	} })
	local layouts = K.Store.Data().layouts
	assert(layouts.Default["nameplates.plate"] == nil, "a plate still at the old 154 by 12 default follows the picture")
	local custom = layouts.Custom["nameplates.plate"]
	assert(custom.width == nil and custom.height == 18 and custom.x == 4, "only the old width is cleared when the height was chosen")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("nameplates height: ok")
