-- test-appearance-levels.lua: the text size, the three motion levels and LibSharedMedia fonts, from Theme, Tokens and Motion up to the Appearance settings.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local W = dofile("Tools/regression/widget_env.lua")

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

local SHARED_FONT = "Interface\\AddOns\\SharedMedia_Test\\Fonts\\Handwriting.ttf"

local function sharedMedia(env)
	local lsm = {
		List = function(_, kind)
			if kind == "font" then
				return { "Handwriting" }
			end
			return {}
		end,
		Fetch = function(_, kind, key)
			if kind == "font" and key == "Handwriting" then
				return SHARED_FONT
			end
		end,
		Register = function()
			return true
		end,
	}
	env.LibStub = function(major)
		if major == "LibSharedMedia-3.0" then
			return lsm
		end
	end
end

-- Theme: the text size and font paths --------------------------------------------------------------

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local fired = 0
	K.Callbacks.Register("ThemeChanged", "test", function()
		fired = fired + 1
	end)
	local _, body = K.Tokens.Font("body")
	local _, world = K.Tokens.Font("world")
	assert(K.Theme.FontScale() == 1, "text is at its normal size by default")
	assert(K.Theme.SetFontScale(1.2) == true and fired == 1, "a new text size fires ThemeChanged")
	local _, scaled = K.Tokens.Font("body")
	assert(near(scaled, body * 1.2), "Tokens.Font scales UI text")
	local _, number = K.Tokens.Font("number")
	assert(near(number, K.Tokens.Size("number") * 1.2), "numbers scale with the text")
	local _, worldNow = K.Tokens.Font("world")
	assert(worldNow == world, "text over the 3D world keeps its own size")
	assert(K.Theme.SetFontScale(1.2) == true and fired == 1, "the same size fires nothing")
	assert(K.Theme.SetFontScale(5) == false and K.Theme.SetFontScale(0.1) == false, "a size outside 0.8 to 1.3 is refused")
	assert(K.Theme.SetFontScale(env.Secret(1)) == false and K.Theme.SetFontScale("1") == false, "a secret or a string is refused")
	assert(K.Theme.FontScale() == 1.2)

	assert(K.Theme.IsFontPath(SHARED_FONT) and K.Theme.IsFontPath("Fonts\\FRIZQT__.TTF"), "font file paths are recognised")
	assert(not K.Theme.IsFontPath("Comic") and not K.Theme.IsFontPath("Fonts\\a.png") and not K.Theme.IsFontPath("Fonts\\|cff.ttf"), "names, images and escapes are not font paths")
	assert(K.Theme.SetFontFace(SHARED_FONT) == true and fired == 2, "a font path is accepted as the face")
	assert(K.Tokens.Font("body") == SHARED_FONT, "Tokens.Font uses the path")
	assert(K.Tokens.Font("number"):find("SourceSans3", 1, true), "numbers keep Source Sans 3")
	assert(K.Theme.SetFontFace("Comic") == false and K.Tokens.Font("body") == SHARED_FONT, "an unknown name is still refused")
end

-- Motion: full, reduced and off ----------------------------------------------------------------------

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local Motion = K.Motion
	local box = { value = 0 }
	local function set(obj, v)
		obj.value = v
	end
	assert(Motion.Level() == "full" and Motion.ReducedMotion() == false, "motion is full by default")
	assert(Motion.SetLevel("reduced") == true and Motion.Level() == "reduced")
	assert(Motion.ReducedMotion() == true, "reduced motion skips movement")
	local handle = Motion.Tween(box, set, 0, 1, 0.2)
	assert(handle ~= nil and box.value == 0, "reduced motion still plays fades and other tweens")
	assert(Motion.SetLevel("off") == true and Motion.Level() == "off")
	assert(box.value == 1 and not Motion.IsPlaying(handle), "switching motion off finishes running tweens")
	assert(Motion.Tween(box, set, 0, 0.5, 0.2) == nil and box.value == 0.5, "with motion off a tween ends at once")
	assert(Motion.SetLevel("fast") == false and Motion.Level() == "off", "an unknown level is refused")
	assert(Motion.SetReducedMotion(false) == true and Motion.Level() == "full", "SetReducedMotion(false) is full motion")
	assert(Motion.SetReducedMotion(true) == true and Motion.Level() == "off", "SetReducedMotion(true) is motion off, as before")
end

-- Appearance: the settings and their rows ------------------------------------------------------------

do
	local env, K = CoreEnv.New({ setup = sharedMedia })
	CoreEnv.Boot(env)
	local defaults = K.Store.Defaults("Appearance")
	assert(defaults.motion == "full" and defaults.fontScale == 1 and defaults.reducedMotion == nil, "motion and text size replace the reduce-motion switch")
	local motion = K.Options.Row("Appearance", "motion")
	assert(motion and motion.type == "dropdown", "motion is a dropdown")
	local values = {}
	for i, option in ipairs(motion.options) do
		values[i] = option.value
	end
	assert(table.concat(values, "|") == "full|reduced|off", "motion offers full, reduced and off")
	local size = K.Options.Row("Appearance", "fontScale")
	assert(size and size.type == "slider" and size.min == 0.8 and size.max == 1.3, "the text size slider runs from 0.8 to 1.3")
	local font = K.Options.Row("Appearance", "font")
	assert(type(font.options) == "function", "the font list is built when it opens")
	local faces = font.options()
	assert(faces[1].value == "Lumen" and faces[2].value == "CinzelSemiBold" and faces[6].value == "SourceSans3Semibold" and faces[8].value == "InterSemiBold", "the Lumen set, then the bundled faces, come first")
	assert(faces[#faces].value == SHARED_FONT and faces[#faces].label == "Handwriting", "LibSharedMedia fonts follow")

	K.Options.Write("Appearance", "motion", "reduced")
	assert(K.Motion.Level() == "reduced", "the motion setting applies at once")
	K.Options.Write("Appearance", "fontScale", 1.1)
	assert(near(K.Theme.FontScale(), 1.1), "the text size applies at once")
	K.Options.Write("Appearance", "font", SHARED_FONT)
	assert(K.Theme.FontFace() == SHARED_FONT and K.Tokens.Font("body") == SHARED_FONT, "a LibSharedMedia font applies at once")
	K.Options.Write("Appearance", "font", "InterSemiBold")
	assert(K.Tokens.Font("body"):find("Inter%-SemiBold"), "a bundled face still applies by its key")
end

-- Saved values that are not allowed fall back; a saved font path is kept ------------------------------

do
	local saved = { version = 1, profiles = { Default = { Appearance = { motion = "fast", fontScale = 9, font = "Comic" } } } }
	local env, K = CoreEnv.New({ saved = saved })
	CoreEnv.Boot(env)
	assert(K.Motion.Level() == "full" and K.Appearance.Get("motion") == "full", "an unknown motion level falls back to full")
	assert(K.Theme.FontScale() == 1.3 and K.Appearance.Get("fontScale") == 1.3, "a text size out of range is clamped")
	assert(K.Theme.FontFace() == "Lumen", "an unknown face falls back to the default set")

	saved = { version = 1, profiles = { Default = { Appearance = { motion = "off", font = SHARED_FONT } } } }
	env, K = CoreEnv.New({ saved = saved })
	CoreEnv.Boot(env)
	assert(K.Motion.Level() == "off" and K.Theme.FontFace() == SHARED_FONT, "saved levels and font paths apply")
end

-- Saved data and profile strings from before the motion levels migrate --------------------------------

do
	local saved = { version = 1, profiles = { Default = { Appearance = { reducedMotion = true } }, Calm = { Appearance = { reducedMotion = false } } } }
	local env, K = CoreEnv.New({ saved = saved })
	CoreEnv.Boot(env)
	assert(env.KstyleUIDB.version == K.Store.DB_VERSION and K.Store.DB_VERSION >= 2, "the saved data is upgraded")
	assert(K.Motion.Level() == "off", "a saved reduce-motion switch becomes motion off")
	local appearance = K.Store.Module("Appearance")
	assert(appearance.reducedMotion == nil and appearance.motion == "off", "the old key is gone")
	assert(env.KstyleUIDB.profiles.Calm.Appearance.reducedMotion == nil, "every profile is upgraded")
	local text = assert(K.Store.Export())
	local ok, why = K.Store.Import(text)
	assert(ok, "the upgraded profile exports and imports again: " .. tostring(why))

	local old = CoreEnv.CraftLua({ kind = "KstyleUI profile", version = 1, name = "Old", settings = { Appearance = { reducedMotion = true } }, layout = {} })
	ok, why = K.Store.Import(old)
	assert(ok, "an older profile string imports: " .. tostring(why))
	assert(K.Store.Module("Appearance").motion == "off" and K.Motion.Level() == "off", "its reduce-motion switch becomes motion off")
end

-- The widget kit restyles when the motion level changes ------------------------------------------------

do
	local env, K = W.New()
	local restyles = 0
	K.Widgets.Track({
		Restyle = function()
			restyles = restyles + 1
		end,
	})
	K.Options.Write("Appearance", "motion", "reduced")
	assert(restyles == 1, "a motion change restyles the kit")
	assert(#env._errors == 0)
end

print("appearance levels ok")
