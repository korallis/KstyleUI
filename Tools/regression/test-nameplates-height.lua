-- test-nameplates-height.lua: the KSTY-44 bible sets the plate. At 1920x1080 and the shipped Interface size the
-- fill is the mock-up's 132 by 10 physical pixels, inside a one-pixel black edge and one more pixel of 45 percent
-- black, so the outer rect is 136 by 14. The edge stays one plus one physical pixels on every screen of the
-- nine-screen matrix. The bible's edge replaces the owner's picture's two-pixel border for plates (LEE-20's ruling
-- still holds for layout; the bible decides the bar's look, Lee, 2026-11-12).
local N = dofile("Tools/regression/nameplates_env.lua")

local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local REFERENCE = { width = 1920, height = 1080, uiScale = 768 / 1080, size = "default" }

local function pixels(K, bar, units)
	return units / (K.Scale.Pixel(1) / K.Widgets.ScaleFactor(bar))
end

local function borderPixels(K, bar)
	local _, _, _, x = bar.under.edgeHard:GetPoint(1)
	local _, _, _, hx = bar.under.edgeSoft:GetPoint(1)
	return pixels(K, bar, -x), pixels(K, bar, -hx)
end

do
	local env, K, ns = N.New(REFERENCE)
	N.Add(env, "nameplate1", { name = "Shadowgale Poacher", reaction = 2, health = 100, maxHealth = 100 })
	local bar = ns.Plates.Get("nameplate1").health
	local width, height = pixels(K, bar, env.Look(bar:GetWidth())), pixels(K, bar, env.Look(bar:GetHeight()))
	local edge, halo = borderPixels(K, bar)
	assert(math.abs(width - 132) < 0.01, "the fill is 132 physical pixels wide, got " .. tostring(width))
	assert(math.abs(height - 10) < 0.01, "the fill is 10 physical pixels tall, got " .. tostring(height))
	assert(math.abs(edge - 1) < 0.01 and math.abs(halo - 2) < 0.01, "a one-pixel black edge and one more of 45 percent black, got " .. tostring(edge) .. " and " .. tostring(halo))
	assert(math.abs(width + halo * 2 - 136) < 0.01 and math.abs(height + halo * 2 - 14) < 0.01, "the outer rect is 136 by 14")
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
		local edge, halo = borderPixels(K, bar)
		local where = string.format("%dx%d ui %s size %s", screen[1], screen[2], tostring(setup.uiScale), tostring(setup.size))
		local border = pixels(K, bar, K.Widgets.Border(bar))
		assert(math.abs(edge - border) < 0.01 and math.abs(halo - border * 2) < 0.01, "the edge is the kit's border, black then 45 percent black, at " .. where .. ", got " .. tostring(edge) .. " and " .. tostring(halo))
		assert(math.abs(edge - math.floor(edge + 0.5)) < 0.01 and edge >= 1, "on whole physical pixels at " .. where)
		assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	end
end

-- The bar is Widgets.UnitBar (KSTY-47): it shades any fill colour with colour-free overlays, so a plate hands it
-- the token itself, a secret class colour included, and never builds a ramp of its own.
do
	local env, K, ns = N.New()
	local function expect(bar, name, label)
		local r, g, b = K.Tokens.Color(name)
		assert(bar.unitBar, label .. " is the shared unit bar")
		assert(N.SameColor(r, g, b, bar:GetStatusBarColor()), label .. " takes its token as the fill colour")
	end
	N.Add(env, "nameplate1", { reaction = 4, canAttack = true })
	expect(ns.Plates.Get("nameplate1").health, "neutral", "a neutral plate")
	N.Add(env, "nameplate2", { canAttack = false, reaction = 5 })
	expect(ns.Plates.Get("nameplate2").health, "friendly", "a friendly plate")
	N.Add(env, "nameplate3", { tapped = true })
	expect(ns.Plates.Get("nameplate3").health, "textDisabled", "a tapped plate")
	N.Add(env, "nameplate4", { isPlayer = true, class = "MAGE", secretClass = true })
	local hidden = ns.Plates.Get("nameplate4").health
	assert(env.issecretvalue((hidden:GetStatusBarColor())), "a secret class colour reaches the status bar sink whole")
	assert(hidden.curve == nil, "and builds no low-health curve from a secret")
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

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1", { reaction = 2, health = 100, maxHealth = 100 })
	local plate = ns.Plates.Get("nameplate1")
	K.Options.Write("Nameplates", "health.texture", "Glass")
	assert(plate.health.unitBar and plate.health.cleanLit:IsShown(), "another bar texture keeps the unit bar's colour-free shading")
	K.Options.Write("Nameplates", "health.texture", "Flat")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("nameplates height: ok")
