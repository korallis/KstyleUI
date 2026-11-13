-- test-scale-auto.lua: the automatic pixel-perfect Interface size and its steps, the size migration, rescaling at runtime, and Widgets.Point, Widgets.Fill and the chrome landing on whole pixels.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local UI_HEIGHT = 768
local DEFAULT = 16 / 19

local function New(width, height, opts)
	opts = opts or {}
	local env, K = CoreEnv.New({
		width = width, height = height, uiScale = opts.uiScale or 768 / 1080, size = "auto", fit = true, saved = opts.saved,
		setup = function(e)
			e._physical = { width, height }
			e.GetPhysicalScreenSize = function()
				return e._physical[1], e._physical[2]
			end
		end,
	})
	CoreEnv.Boot(env)
	return env, K
end

local function perUnit(env, K)
	return env._physical[2] * K.Scale.Root():GetEffectiveScale() / UI_HEIGHT
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

local function whole(v)
	return near(v, math.floor(v + 0.5))
end

-- Auto picks, per screen, one unit = a whole number of pixels where that is within 12.5% of the default look and
-- fits; elsewhere the nearest sixteenth of a pixel per unit. The default look is 16 / 19 of the 1080-unit reference.
local WANT = {
	["5120x1440"] = 1, ["3440x1440"] = 1, ["2560x1440"] = 1, ["3840x1080"] = 13 / 16, ["1920x1080"] = 13 / 16,
	["3840x2160"] = 27 / 16, ["1280x720"] = 9 / 16, ["2383x1540"] = 19 * 1540 / (16 * 1080) * 1080 / 1540,
}
for _, screen in ipairs({ { 5120, 1440 }, { 3440, 1440 }, { 3840, 1080 }, { 2560, 1440 }, { 1920, 1080 }, { 3840, 2160 }, { 1280, 720 }, { 2383, 1540 }, { 3456, 2234 }, { 1366, 768 } }) do
	local env, K = New(screen[1], screen[2])
	local Scale = K.Scale
	local name = screen[1] .. "x" .. screen[2]
	local ppu = perUnit(env, K)
	assert(Scale.IsAuto() and K.Appearance.Get("uiScaleAuto") == true, name .. ": a new profile is on the automatic size")
	assert(whole(ppu * Scale.STEPS_PER_PIXEL), name .. ": one unit is a whole number of sixteenths of a pixel, got " .. ppu)
	assert(math.abs(Scale.AppliedUserScale() - DEFAULT) <= Scale.WHOLE_BAND * DEFAULT + 1e-9, name .. ": the size stays near the default look, got " .. Scale.AppliedUserScale())
	assert(Scale.AppliedUserScale() <= Scale.MaxUserScale() + 1e-9, name .. ": the automatic size fits the screen")
	assert(near(Scale.Border() * ppu, 1) and near(Scale.Pixel(1) * ppu, 1), name .. ": the border is exactly one physical pixel")
	if screen[2] == 1440 then
		assert(near(ppu, 1), name .. ": one unit is exactly one pixel at 1440 lines")
	end
	if WANT[name] and name ~= "2383x1540" then
		assert(near(ppu, WANT[name]), name .. ": " .. WANT[name] .. " px per unit, got " .. ppu)
	end
	assert(#env._errors == 0, name .. ": " .. tostring(env._errors[1]))
end

-- A chosen size snaps to the nearest step that fits; the slider steps in those sizes, and Auto comes back.
do
	local env, K = New(1920, 1080)
	local Scale = K.Scale
	assert(near(Scale.Step(), 1080 / (16 * 1080)), "at 1080 lines a step is a sixteenth of a pixel per unit")
	K.Options.Write("Appearance", "uiScaleAuto", false)
	K.Options.Write("Appearance", "uiScale", 0.9)
	assert(not Scale.IsAuto() and Scale.UserScale() == 0.9, "the chosen size is kept as chosen")
	assert(near(Scale.AppliedUserScale(), 0.875) and near(perUnit(env, K), 14 / 16), "0.9 applies as the nearest step, 14/16 px per unit")
	K.Options.Write("Appearance", "uiScale", 1.5)
	local ppu = perUnit(env, K)
	assert(Scale.AppliedUserScale() <= Scale.MaxUserScale() + 1e-9 and whole(ppu * 16), "a size over the fit takes the largest step that fits")
	K.Options.Write("Appearance", "uiScaleAuto", true)
	assert(Scale.IsAuto() and near(perUnit(env, K), 13 / 16), "Auto comes back to the automatic size")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Migration 27: a profile at the old default size, or with no size, takes Auto; a size the player chose stays chosen.
do
	local saved = {
		version = 20, account = { setupSeen = true }, layouts = {},
		profiles = {
			Untouched = { Appearance = { uiScale = DEFAULT, fontScale = 1.1 } },
			Chosen = { Appearance = { uiScale = 1 } },
			Empty = {},
		},
		characters = {},
	}
	local env, K = New(2560, 1440, { saved = saved })
	local profiles = env.KstyleUIDB.profiles
	assert(env.KstyleUIDB.version >= 27, "the saved data is upgraded")
	assert(profiles.Untouched.Appearance.uiScale == DEFAULT and profiles.Untouched.Appearance.uiScaleAuto == nil and profiles.Untouched.Appearance.fontScale == 1.1, "a profile at the old default size takes Auto, and keeps that size for when Auto is switched off")
	assert(profiles.Chosen.Appearance.uiScale == 1 and profiles.Chosen.Appearance.uiScaleAuto == false, "a chosen size is kept, with Auto off")
	assert(profiles.Empty.Appearance == nil, "a profile with no size stays empty and takes Auto")
	K.Store.SetProfile("Chosen")
	local ppu = perUnit(env, K)
	assert(not K.Scale.IsAuto() and whole(ppu * 16) and math.abs(K.Scale.AppliedUserScale() - math.min(1, K.Scale.MaxUserScale())) <= K.Scale.Step() / 2 + 1e-9, "the chosen size applies snapped to the nearest step, got " .. K.Scale.AppliedUserScale())
	K.Store.SetProfile("Untouched")
	assert(K.Scale.IsAuto() and near(perUnit(env, K), 1), "the untouched profile is pixel perfect at 1440 lines")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The display, the window, the game's UI scale and its CVars rescale the root; a CVar of something else does not.
-- In combat the rescale waits.
do
	local env, K = New(1920, 1080)
	local root = K.Scale.Root()
	env._physical = { 5120, 1440 }
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.RunTimers()
	assert(near(perUnit(env, K), 1), "a new display size rescales to its automatic size")
	env.UIParent._scale = 0.65
	env.FireEvent("CVAR_UPDATE", "Sound_MasterVolume", "0.5")
	assert(not near(perUnit(env, K), 1), "a CVar that is not the UI scale leaves the root alone")
	env.FireEvent("CVAR_UPDATE", "uiScale", "0.65")
	env.RunTimers()
	assert(near(perUnit(env, K), 1), "the game's UI scale CVar rescales the root to stay pixel perfect")
	env.UIParent._scale = 0.8
	env.FireEvent("UI_SCALE_CHANGED")
	assert(near(perUnit(env, K), 1), "UI_SCALE_CHANGED rescales the root")
	env._physical = { 1920, 1080 }
	root._scripts.OnSizeChanged(root)
	assert(near(perUnit(env, K), 13 / 16), "the window resizing the root rescales it")
	local rootScale = root:GetScale()
	env.SetCombat(true)
	env._physical = { 3840, 2160 }
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.FireEvent("CVAR_UPDATE", "useUiScale", "1")
	root._scripts.OnSizeChanged(root)
	assert(root:GetScale() == rootScale, "no SetScale on the root in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(near(perUnit(env, K), 27 / 16), "leaving combat applies the waiting rescale")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Widgets.Point and Widgets.Fill put edges on whole pixels at 13/16 px per unit, against a relative frame whose own
-- size is not whole; a protected frame in combat waits; a chrome on such an owner keeps its far corners whole.
do
	local env, K = New(1920, 1080)
	local W, root = K.Widgets, K.Scale.Root()
	local px = 1080 / 1080
	local function edges(region)
		local x, y, w, h = Scene.Rect(env, region)
		return x * px, y * px, (x + w) * px, (y + h) * px
	end
	local owner = env.CreateFrame("Frame", nil, root)
	owner:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	owner:SetSize(101.37, 40.2)
	local ol, ot = edges(owner)
	assert(whole(ol) and whole(ot), "the owner's corner is whole")
	local centre = owner:CreateTexture()
	W.Size(centre, 9.3, 7.1)
	W.Point(centre, "CENTER", owner, "CENTER", 0.4, 0)
	local l, t, r, b = edges(centre)
	assert(whole(l - ol) and whole(r - ol) and whole(t - ot) and whole(b - ot), "a centred texture lands on whole pixels, got " .. l .. " " .. t)
	local beside = owner:CreateTexture()
	W.Size(beside, 6, 6)
	W.Point(beside, "TOPLEFT", owner, "TOPRIGHT", 3.2, -1.7)
	l, t, r = edges(beside)
	assert(whole(l - ol) and whole(t - ot) and whole(r - ol), "a texture beside a fractional owner lands on whole pixels")
	local inside = owner:CreateTexture()
	W.Fill(inside, owner, 1.3, 2.2, 1.6, 0.9)
	l, t, r, b = edges(inside)
	assert(whole(l - ol) and whole(t - ot) and whole(r - ol) and whole(b - ot), "a fill inside a fractional owner lands on whole pixels")
	local text = owner:CreateFontString(nil, "OVERLAY")
	text:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	text:SetSize(40, 12)
	W.Point(text, "LEFT", owner, "LEFT", 4.4, 0)
	local tl, tt, _, tb = edges(text)
	assert(whole(tl - ol) and whole((tt + tb) / 2 - ot), "a text's anchor lands on a whole pixel")
	local chrome = W.Chrome(owner, { shape = "panel" })
	for _, slice in ipairs({ chrome.line, chrome.fill, chrome.rim }) do
		for _, piece in ipairs({ 1, 3, 7, 9 }) do
			l, t, r, b = edges(slice[piece])
			assert(whole(l - ol) and whole(t - ot) and whole(r - ol) and whole(b - ot), "every chrome corner lands on whole pixels")
		end
	end
	local secure = env.CreateFrame("Frame", nil, root)
	secure.IsProtected = function()
		return true
	end
	secure:SetSize(10, 10)
	env.SetCombat(true)
	W.Point(secure, "TOPLEFT", owner, "BOTTOMLEFT", 0.3, 0)
	assert(#secure._points == 0, "a protected frame is not moved in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(#secure._points == 1, "it moves when combat ends")
	l, t = edges(secure)
	assert(whole(l - ol) and whole(t - ot), "and lands on whole pixels")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("scale auto ok")
